using Toybox.WatchUi;

class HistoryDelegate extends WatchUi.Menu2InputDelegate {
    var view as HistoryView;
    function initialize(historyView as HistoryView) {
        Menu2InputDelegate.initialize();
        view = historyView;
    }
    function onSelect(item) as Void { }
    function onWrap(key) { return true; }
}