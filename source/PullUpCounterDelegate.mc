using Toybox.WatchUi;

class PullUpCounterDelegate extends WatchUi.BehaviorDelegate {
    var view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        self.view = view;
    }

    function onKey(keyEvent) {
        var key = keyEvent.getKey();
        if (!view.workoutReady) {
            if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_DOWN) {
                view.ensureWorkoutReady();
                WatchUi.requestUpdate();
                return true;
            }
            return false;
        }

        if (key == WatchUi.KEY_ENTER) {
            view.addPullUps();
            return true;
        }

        if (key == WatchUi.KEY_DOWN) {
            view.undoPullUps();
            return true;
        }

        return false;
    }

    function onMenu() {
        var minutes = view.restDuration / 60;
        var seconds = view.restDuration % 60;

        var restText = minutes.format("%d") + ":" + seconds.format("%02d");

        var menu = new WatchUi.Menu2({
            :title => "Settings",
        });

        menu.addItem(
            new WatchUi.MenuItem(
                "Increment",
                view.incrementAmount.format("%d"),
                :increment,
                {}
            )
        );

        menu.addItem(
            new WatchUi.MenuItem("Rest Time", restText, :restTime, {})
        );

        menu.addItem(
            new WatchUi.MenuItem(
                "Vibration",
                view.vibrationEnabled ? "On" : "Off",
                :vibration,
                {}
            )
        );

        menu.addItem(
            new WatchUi.MenuItem("Finish Workout", null, :finishWorkout, {})
        );

        menu.addItem(
            new WatchUi.MenuItem(
                "History",
                "Current + completed",
                :history,
                {}
            )
        );

        menu.addItem(
            new WatchUi.MenuItem("Reset Counter", null, :resetCounter, {})
        );

        menu.addItem(new WatchUi.MenuItem("Backup / Export", "Wireless transfer", :backup, {}));
        view.settingsMenu = menu;

        WatchUi.pushView(
            menu,
            new PullUpCounterMenuDelegate(view),
            WatchUi.SLIDE_UP
        );

        return true;
    }

    function historyCountText(count) {
        return count.format("%d") + " sets";
    }
}
