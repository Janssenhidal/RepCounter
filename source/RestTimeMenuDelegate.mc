using Toybox.WatchUi;

// Save adapter for both Fixed Rest and Fixed Interval.
class RestTimeMenuDelegate {
    var view;
    var settingsMenu;
    function initialize(view, settingsMenu) {
        self.view = view;
        self.settingsMenu = settingsMenu;
    }
    function save(value) {
        if (!DurationText.valid(value) || !view.ensureWorkoutReady()) {
            return false;
        }
        if (!view.isInterval() && value > 3540) {
            return false;
        }
        if (view.isInterval() && value != view.restDuration) {
            view.stopTimer();
        }
        view.workoutStore.storage.put("restDuration", value);
        view.restDuration = value;
        if (settingsMenu != null) {
            settingsMenu.updateItem(
                new WatchUi.MenuItem(
                    view.timerSettingLabel(),
                    DurationText.format(value),
                    :restTime,
                    {}
                ),
                2
            );
        }
        WatchUi.requestUpdate();
        return true;
    }
}
