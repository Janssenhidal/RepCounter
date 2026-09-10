using Toybox.Lang;
using Toybox.WatchUi;

module AppTheme {
    var selected = "cyan";
    function normalize(value) {
        if (value instanceof Lang.String && (value.equals("orange") || value.equals("red"))) { return value; }
        return "cyan";
    }
    function color() {
        return selected.equals("orange") ? 0xff9500 : selected.equals("red") ? 0xff4545 : 0x00dce5;
    }
    function label() { return selected.equals("orange") ? "Orange" : selected.equals("red") ? "Red" : "Cyan"; }
}
class GeneralMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view; var menu;
    function initialize(view, menu) { Menu2InputDelegate.initialize(); self.view = view; self.menu = menu; }
    function onSelect(item) as Void {
        if (item.getId() == :vibration) {
            view.vibrationEnabled = !view.vibrationEnabled;
            view.workoutStore.storage.put("vibrationEnabled", view.vibrationEnabled);
            menu.updateItem(new WatchUi.MenuItem("Vibration", view.vibrationEnabled ? "On" : "Off", :vibration, {}), 0);
        } else {
            var choices = new WatchUi.Menu2({:title => "Theme"});
            choices.addItem(new WatchUi.MenuItem("Cyan", null, "cyan", {}));
            choices.addItem(new WatchUi.MenuItem("Orange", null, "orange", {}));
            choices.addItem(new WatchUi.MenuItem("Red", null, "red", {}));
            WatchUi.pushView(choices, new ThemeMenuDelegate(view, menu), WatchUi.SLIDE_LEFT);
        }
    }
}
class ThemeMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view; var menu;
    function initialize(view, menu) { Menu2InputDelegate.initialize(); self.view = view; self.menu = menu; }
    function onSelect(item) as Void {
        var value = AppTheme.normalize(item.getId());
        view.workoutStore.storage.put("theme", value);
        AppTheme.selected = value;
        menu.updateItem(new WatchUi.MenuItem("Theme", AppTheme.label(), :theme, {}), 1);
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        WatchUi.requestUpdate();
    }
}
