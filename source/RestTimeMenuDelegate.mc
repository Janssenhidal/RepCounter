using Toybox.WatchUi;
using Toybox.Application;

class RestTimeMenuDelegate extends WatchUi.Menu2InputDelegate {

    var view;
    var settingsMenu;

    function initialize(view, settingsMenu) {
        Menu2InputDelegate.initialize();

        self.view = view;
        self.settingsMenu = settingsMenu;
    }

    function onSelect(item) as Void {

        var id = item.getId();

        if (id == :rest15) {
            view.restDuration = 15;
        } else if (id == :rest30) {
            view.restDuration = 30;
        } else if (id == :rest45) {
            view.restDuration = 45;
        } else if (id == :rest60) {
            view.restDuration = 60;
        } else if (id == :rest75) {
            view.restDuration = 75;
        } else if (id == :rest90) {
            view.restDuration = 90;
        } else if (id == :rest120) {
            view.restDuration = 120;
        } else if (id == :rest180) {
            view.restDuration = 180;
        }

        view.workoutStore.storage.put(
            "restDuration",
            view.restDuration
        );

        var minutes =
            view.restDuration / 60;

        var seconds =
            view.restDuration % 60;

        var restText =
            minutes.format("%d")
            + ":"
            + seconds.format("%02d");

        // Replace Rest Time item in Settings
        var updatedItem = new WatchUi.MenuItem(
            "Rest Time",
            restText,
            :restTime,
            {}
        );

        settingsMenu.updateItem(
            updatedItem,
            1
        );

        WatchUi.popView(
            WatchUi.SLIDE_RIGHT
        );
    }
}
