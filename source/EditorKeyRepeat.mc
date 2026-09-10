using Toybox.WatchUi;
using Toybox.Timer;
using Toybox.System;

// Shared physical-button repeat for numeric editors. Single taps change once.
class EditorKeyRepeat {
    var editor; var timer; var direction = 0; var began = 0; var nextAt = 0;
    function initialize(editor) { self.editor = editor; timer = new Timer.Timer(); }
    function press(key) {
        if (key != WatchUi.KEY_UP && key != WatchUi.KEY_DOWN) { stop(); return false; }
        var delta = key == WatchUi.KEY_UP ? 1 : -1;
        if (direction == delta) { return true; }
        stop(); direction = delta; began = System.getTimer(); nextAt = began + 500;
        editor.adjust(direction);
        timer.start(method(:tick), 100, true);
        return true;
    }
    function release(key) {
        // Long presses can be released under a different logical key (e.g. MENU).
        var active = direction != 0;
        stop(); return active || key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN;
    }
    function tick() as Void { advance(System.getTimer()); }
    function advance(now) as Void {
        if (direction == 0 || now < nextAt) { return; }
        var elapsed = now - began;
        // Fail safe when firmware takes a shortcut and omits the release event.
        if (elapsed >= 10000) { stop(); return; }
        editor.adjust(direction * (elapsed >= 1500 ? editor.repeatStep() : 1));
        nextAt = now + (elapsed >= 1500 ? 100 : 200);
    }
    function stop() as Void { timer.stop(); direction = 0; }
}
