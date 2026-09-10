using Toybox.WatchUi;
class WorkoutModeMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    function initialize(view) {
        Menu2InputDelegate.initialize();
        self.view = view;
    }
    function onSelect(item) as Void {
        var wasInterval = view.isInterval();
        view.selectMode(
            item.getId() == :fixedInterval ? "fixedInterval" : "fixedRest"
        );
        view.settingsMenu.updateItem(
            new WatchUi.MenuItem(
                "Workout Mode",
                view.modeLabel(),
                :workoutMode,
                {}
            ),
            0
        );
        var time = DurationText.format(view.restDuration);
        view.settingsMenu.updateItem(
            new WatchUi.MenuItem(view.timerSettingLabel(), time, :restTime, {}),
            2
        );
        if (wasInterval != view.isInterval()) {
            // Rebuild only the optional tail; preference row indexes stay stable.
            if (wasInterval) {
                view.settingsMenu.deleteItem(4);
            }
            if (view.totalSets >= 1) {
                view.settingsMenu.deleteItem(4);
            }
            if (view.isInterval()) {
                view.settingsMenu.addItem(
                    new WatchUi.MenuItem("Goal / Pacing", "Off", :goal, {})
                );
            }
            if (view.totalSets >= 1) {
                view.settingsMenu.addItem(
                    new WatchUi.MenuItem(
                        "Reset Workout",
                        null,
                        :resetCounter,
                        {}
                    )
                );
            }
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
