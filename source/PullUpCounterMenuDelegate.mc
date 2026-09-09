using Toybox.WatchUi;
using Toybox.Application;

class PullUpCounterMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        self.view = view;
    }

    function onSelect(item) as Void {
        if (item.getId() != :backup && item.getId() != :data && !view.ensureWorkoutReady()) { return; }
        if (item.getId() == :workoutSettings) {
            var menu = new WatchUi.Menu2({ :title => "Workout Settings" });
            menu.addItem(new WatchUi.MenuItem("Reps per Set", view.incrementAmount.format("%d"), :increment, {}));
            var restText = (view.restDuration / 60).format("%d") + ":" + (view.restDuration % 60).format("%02d");
            menu.addItem(new WatchUi.MenuItem("Rest Time", restText, :restTime, {}));
            menu.addItem(new WatchUi.MenuItem("Vibration", view.vibrationEnabled ? "On" : "Off", :vibration, {}));
            if (view.totalSets >= 1) {
                menu.addItem(new WatchUi.MenuItem("Reset Workout", null, :resetCounter, {}));
            }
            // Setting pickers update this submenu when returning from a selection.
            view.settingsMenu = menu;
            WatchUi.pushView(menu, new PullUpCounterMenuDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (item.getId() == :data) {
            var menu = new WatchUi.Menu2({ :title => "Data" });
            menu.addItem(new WatchUi.MenuItem("Backup / Export", null, :backup, {}));
            WatchUi.pushView(menu, new PullUpCounterMenuDelegate(view), WatchUi.SLIDE_LEFT);
        } else if (item.getId() == :backup) {
            if (BackupConfig.URL.equals("")) {
                workoutMessage("Backup service\nnot configured yet.");
                return;
            }
            try {
                var transfer = new BackupTransfer(view);
                WatchUi.pushView(transfer, new BackupTransferDelegate(transfer), WatchUi.SLIDE_UP);
            } catch (error) { workoutMessage("Cannot start backup."); }
        } else if (item.getId() == :increment) {
            var menu = new WatchUi.Menu2({
                :title => "Reps per Set",
            });

            menu.addItem(new WatchUi.MenuItem("1", null, :inc1, {}));

            menu.addItem(new WatchUi.MenuItem("2", null, :inc2, {}));

            menu.addItem(new WatchUi.MenuItem("3", null, :inc3, {}));

            menu.addItem(new WatchUi.MenuItem("4", null, :inc4, {}));

            menu.addItem(new WatchUi.MenuItem("5", null, :inc5, {}));

            WatchUi.pushView(
                menu,
                new IncrementMenuDelegate(view, view.settingsMenu),
                WatchUi.SLIDE_LEFT
            );
        } else if (item.getId() == :restTime) {
            var menu = new WatchUi.Menu2({
                :title => "Rest Time",
            });

            menu.addItem(new WatchUi.MenuItem("15 seconds", null, :rest15, {}));

            menu.addItem(new WatchUi.MenuItem("30 seconds", null, :rest30, {}));

            menu.addItem(new WatchUi.MenuItem("45 seconds", null, :rest45, {}));

            menu.addItem(new WatchUi.MenuItem("1:00", null, :rest60, {}));

            menu.addItem(new WatchUi.MenuItem("1:15", null, :rest75, {}));

            menu.addItem(new WatchUi.MenuItem("1:30", null, :rest90, {}));

            menu.addItem(new WatchUi.MenuItem("2:00", null, :rest120, {}));

            menu.addItem(new WatchUi.MenuItem("3:00", null, :rest180, {}));

            WatchUi.pushView(
                menu,
                new RestTimeMenuDelegate(view, view.settingsMenu),
                WatchUi.SLIDE_LEFT
            );
        } else if (item.getId() == :vibration) {
            view.vibrationEnabled = !view.vibrationEnabled;

            view.workoutStore.storage.put(
                "vibrationEnabled",
                view.vibrationEnabled
            );

            var updatedItem = new WatchUi.MenuItem(
                "Vibration",
                view.vibrationEnabled ? "On" : "Off",
                :vibration,
                {}
            );
            view.settingsMenu.updateItem(updatedItem, 2);
        } else if (item.getId() == :history) {
            if (!view.ensureWorkoutReady()) { return; }
            try {
                var historyMenu = new WorkoutHistoryMenu(view);
                WatchUi.pushView(historyMenu, new WorkoutHistoryMenuDelegate(historyMenu), WatchUi.SLIDE_LEFT);
            } catch (error) { workoutMessage("Cannot open history.\nPlease try again."); }
        } else if (item.getId() == :finishWorkout) {
            if (view.finishWorkout()) { WatchUi.popView(WatchUi.SLIDE_DOWN); }
        } else if (item.getId() == :resetCounter) {
            view.resetCounter();

            // Return to the counter so the next menu reflects the empty workout.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }
}


