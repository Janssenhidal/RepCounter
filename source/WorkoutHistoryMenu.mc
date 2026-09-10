using Toybox.Lang;
using Toybox.Time;
using Toybox.Time.Gregorian;
using Toybox.WatchUi;

function workoutDate(timestamp) as Lang.String {
    var date = Gregorian.info(new Time.Moment(timestamp), Time.FORMAT_SHORT);
    return (
        date.day.format("%02d") +
        "/" +
        date.month.format("%02d") +
        "/" +
        date.year.format("%04d") +
        " " +
        date.hour.format("%02d") +
        ":" +
        date.min.format("%02d")
    );
}

function workoutTotals(reps, sets) as Lang.String {
    return reps.format("%d") + " reps / " + sets.format("%d") + " sets";
}

function workoutMessage(message as Lang.String) as Void {
    var menu = new WatchUi.Menu2({ :title => message });
    menu.addItem(new WatchUi.MenuItem("OK", null, :ok, {}));
    WatchUi.pushView(menu, new WorkoutMessageDelegate(), WatchUi.SLIDE_UP);
}

class WorkoutMessageDelegate extends WatchUi.Menu2InputDelegate {
    function initialize() {
        Menu2InputDelegate.initialize();
    }
    function onSelect(item) as Void {
        WatchUi.popView(WatchUi.SLIDE_DOWN);
    }
}

class WorkoutHistoryMenu extends WatchUi.Menu2 {
    var mainView as PullUpCounterView;
    var itemCount = 0;
    var visible as Lang.Array = [];
    var atNewest = true;

    function initialize(view as PullUpCounterView) {
        Menu2.initialize({ :title => "Workouts" });
        mainView = view;
        refresh();
    }

    function refresh() as Void {
        visible = mainView.workoutStore.before(
            mainView.workoutStore.nextId(),
            100
        );
        atNewest = true;
        rebuild(null);
    }

    function rebuild(anchor) as Void {
        while (itemCount > 0) {
            deleteItem(0);
            itemCount -= 1;
        }
        if (atNewest && mainView.totalSets > 0 && mainView.history.size() > 0) {
            var currentTitle = "Current";
            if (mainView.history.size() > 0) {
                var first = mainView.history[0] as Lang.Dictionary;
                currentTitle += " - " + workoutDate(first["timestamp"]);
            }
            addItem(
                new WatchUi.MenuItem(
                    currentTitle,
                    workoutTotals(mainView.pullUps, mainView.totalSets),
                    :current,
                    {}
                )
            );
            itemCount += 1;
        }
        var anchorIndex = 0;
        for (var i = 0; i < visible.size(); i += 1) {
            var summary = visible[i] as Lang.Dictionary;
            if (summary["id"] == anchor) {
                anchorIndex = itemCount;
            }
            addItem(
                new WatchUi.MenuItem(
                    workoutDate(summary["start"]),
                    workoutTotals(summary["reps"], summary["sets"]),
                    summary["id"],
                    {}
                )
            );
            itemCount += 1;
        }
        if (itemCount == 0) {
            addItem(new WatchUi.MenuItem("No workouts yet", null, :empty, {}));
            itemCount = 1;
        }
        setFocus(anchorIndex);
    }

    function older() as Lang.Boolean {
        if (visible.size() == 0) {
            return true;
        }
        var anchor = (visible[visible.size() - 1] as Lang.Dictionary)["id"];
        var batch = mainView.workoutStore.before(anchor, 100);
        if (batch.size() == 0) {
            return true;
        }
        visible.addAll(batch);
        if (visible.size() > 200) {
            visible = visible.slice(visible.size() - 200, visible.size());
            atNewest = false;
        }
        rebuild(anchor);
        return true;
    }

    function newer() as Lang.Boolean {
        if (atNewest || visible.size() == 0) {
            return true;
        }
        var anchor = (visible[0] as Lang.Dictionary)["id"];
        var batch = mainView.workoutStore.after(anchor, 100);
        batch.addAll(visible);
        visible = batch.size() > 200 ? batch.slice(0, 200) : batch;
        var first = (visible[0] as Lang.Dictionary)["id"];
        atNewest = mainView.workoutStore.after(first, 1).size() == 0;
        rebuild(anchor);
        return true;
    }
}

class WorkoutHistoryMenuDelegate extends WatchUi.Menu2InputDelegate {
    var menu as WorkoutHistoryMenu;
    function initialize(historyMenu as WorkoutHistoryMenu) {
        Menu2InputDelegate.initialize();
        menu = historyMenu;
    }
    function onNextPage() {
        try {
            return menu.older();
        } catch (error) {
            workoutMessage("Cannot load older workouts.\nPlease try again.");
            return true;
        }
    }
    function onPreviousPage() {
        try {
            return menu.newer();
        } catch (error) {
            workoutMessage("Cannot load newer workouts.\nPlease try again.");
            return true;
        }
    }
    function onWrap(key) {
        return true;
    }
    function onSelect(item) as Void {
        var id = item.getId();
        if (id == :empty) {
            return;
        }
        if (id == :current) {
            var currentView = new HistoryView(menu.mainView.history);
            WatchUi.pushView(
                currentView,
                new HistoryDelegate(currentView),
                WatchUi.SLIDE_LEFT
            );
        } else {
            try {
                var detail = new HistoryView(
                    menu.mainView.workoutStore.load(id)
                );
                detail.setFooter(new HistoryDeleteLabel());
                WatchUi.pushView(
                    detail,
                    new CompletedWorkoutDelegate(detail, menu, id),
                    WatchUi.SLIDE_LEFT
                );
            } catch (error) {
                workoutMessage("Cannot open workout.\nPlease try again.");
            }
        }
    }
}

class CompletedWorkoutDelegate extends HistoryDelegate {
    var historyMenu as WorkoutHistoryMenu;
    var workoutId;
    function initialize(detail, menu as WorkoutHistoryMenu, id) {
        HistoryDelegate.initialize(detail);
        historyMenu = menu;
        workoutId = id;
    }
    function onFooter() as Void {
        onMenu();
    }
    function onMenu() {
        var menu = new WatchUi.Menu2({ :title => "Delete this workout?" });
        menu.addItem(new WatchUi.MenuItem("Cancel", null, :cancel, {}));
        menu.addItem(new WatchUi.MenuItem("Delete", null, :delete, {}));
        WatchUi.pushView(
            menu,
            new WorkoutDeleteDelegate(historyMenu, workoutId),
            WatchUi.SLIDE_UP
        );
        return true;
    }
}

class WorkoutDeleteDelegate extends WatchUi.Menu2InputDelegate {
    var historyMenu as WorkoutHistoryMenu;
    var workoutId;
    function initialize(menu as WorkoutHistoryMenu, id) {
        Menu2InputDelegate.initialize();
        historyMenu = menu;
        workoutId = id;
    }
    function onSelect(item) as Void {
        if (item.getId() == :cancel) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return;
        }
        if (item.getId() != :delete) { return; }
        try {
            historyMenu.mainView.workoutStore.deleteWorkout(workoutId);
            historyMenu.refresh();
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        } catch (error) {
            workoutMessage("Could not delete.\nPlease try again.");
        }
    }
}
