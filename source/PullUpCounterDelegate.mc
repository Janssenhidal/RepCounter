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
        var menu = new WatchUi.Menu2({ :title => "Menu" });
        menu.addItem(
            new WatchUi.MenuItem("Workout Settings", null, :workoutSettings, {})
        );
        if (view.totalSets >= 1) {
            menu.addItem(
                new WatchUi.MenuItem("Finish Workout", null, :finishWorkout, {})
            );
        }
        menu.addItem(new WatchUi.MenuItem("History", null, :history, {}));
        menu.addItem(new WatchUi.MenuItem("Data", null, :data, {}));

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
