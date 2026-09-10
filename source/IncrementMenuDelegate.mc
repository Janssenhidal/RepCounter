using Toybox.WatchUi;

// Save adapter for the shared two-digit reps editor.
class IncrementMenuDelegate {
    var view;
    var settingsMenu;
    function initialize(view, settingsMenu) {
        self.view = view;
        self.settingsMenu = settingsMenu;
    }
    function save(value) {
        if (value < 1 || value > 99 || !view.ensureWorkoutReady()) { return false; }
        view.workoutStore.storage.put("incrementAmount", value);
        view.incrementAmount = value;
        if (settingsMenu != null) {
            settingsMenu.updateItem(new WatchUi.MenuItem("Reps per Set", value.format("%d"), :increment, {}), 1);
        }
        WatchUi.requestUpdate();
        return true;
    }
}
