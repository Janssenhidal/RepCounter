using Toybox.WatchUi;
using Toybox.Application;

class IncrementMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    var settingsMenu;

    function initialize(view, settingsMenu) {
        Menu2InputDelegate.initialize();

        self.view = view;
        self.settingsMenu = settingsMenu;
    }

    function onSelect(item) as Void {
        var id = item.getId();

        if (id == :inc1) {
            view.incrementAmount = 1;
        } else if (id == :inc2) {
            view.incrementAmount = 2;
        } else if (id == :inc3) {
            view.incrementAmount = 3;
        } else if (id == :inc4) {
            view.incrementAmount = 4;
        } else if (id == :inc5) {
            view.incrementAmount = 5;
        }

        view.workoutStore.storage.put("incrementAmount", view.incrementAmount);

        // Refresh Reps per Set in Workout Settings
        var updatedItem = new WatchUi.MenuItem(
            "Reps per Set",
            view.incrementAmount.format("%d"),
            :increment,
            {}
        );

        settingsMenu.updateItem(updatedItem, 0);

        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }
}
