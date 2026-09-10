using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;

module DurationText {
    function format(seconds) {
        var tail =
            ((seconds % 3600) / 60).format("%02d") +
            ":" +
            (seconds % 60).format("%02d");
        return seconds >= 3600
            ? (seconds / 3600).format("%d") + ":" + tail
            : tail;
    }
    function valid(seconds) {
        return seconds >= 1 && seconds <= 86399;
    }
}

// Shared draft editor: storage is changed only by the supplied save handler.
class DurationEditor extends WatchUi.View {
    var handler;
    var timeFont;
    var fields as Lang.Array;
    var selected = 0;
    var width = 390;
    var limited = false;
    var minutesOnly = false;
    var keyRepeat;
    function initialize(value, handler) {
        View.initialize();
        self.handler = handler;
        timeFont = WatchUi.loadResource(Rez.Fonts.RepTimer);
        limited = value > 86399;
        if (limited) {
            value = 86399;
        }
        fields = [
            (value / 3600).toNumber(),
            ((value % 3600) / 60).toNumber(),
            value % 60,
        ];
    }
    function useMinutes() as Void {
        minutesOnly = true;
        fields[1] += fields[0] * 60;
        fields[0] = 0;
        selected = 1;
        if (value() > 3540) {
            fields[1] = 59;
            fields[2] = 0;
            limited = true;
        }
    }
    function onHide() as Void {
        if (keyRepeat != null) {
            keyRepeat.stop();
        }
    }
    function repeatStep() { return 5; }
    function fieldCount() {
        return minutesOnly && selected == 2 && fields[1] == 59
            ? 1
            : selected == 0
              ? 24
              : 60;
    }
    function value() {
        return fields[0] * 3600 + fields[1] * 60 + fields[2];
    }
    function adjust(delta) as Void {
        var count = fieldCount();
        fields[selected] =
            (((fields[selected] + delta) % count) + count) % count;
        if (minutesOnly && fields[1] == 59) {
            fields[2] = 0;
        }
        WatchUi.requestUpdate();
    }
    function previous() {
        if (selected == (minutesOnly ? 1 : 0)) {
            return false;
        }
        selected -= 1;
        WatchUi.requestUpdate();
        return true;
    }
    function save() {
        if (!DurationText.valid(value())) {
            workoutMessage("Enter at least 1 second.");
            return false;
        }
        return handler.save(value());
    }
    function onUpdate(dc) as Void {
        width = dc.getWidth();
        var x = width / 2;
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var titles = ["Set Hours", "Set Minutes", "Set Seconds"];
        ScreenStyle.title(dc, titles[selected]);
        var centers = minutesOnly ? [0, x - 70, x + 70] : [x - 94, x, x + 94];
        for (var i = minutesOnly ? 1 : 0; i < 3; i += 1) {
            var text = fields[i].format(i == 0 ? "%d" : "%02d");
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                centers[i],
                172,
                timeFont,
                text,
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        if (minutesOnly) {
            dc.drawText(x, 172, timeFont, ":", Graphics.TEXT_JUSTIFY_CENTER);
        } else {
            dc.drawText(
                x - 47,
                172,
                timeFont,
                ":",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.drawText(
                x + 47,
                172,
                timeFont,
                ":",
                Graphics.TEXT_JUSTIFY_CENTER
            );
        }
        var center = centers[selected];
        var count = fieldCount();
        dc.setColor(AppTheme.color(), Graphics.COLOR_TRANSPARENT);
        dc.fillRectangle(center - 30, 232, 60, 3);
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            center,
            115,
            Graphics.FONT_SMALL,
            ((fields[selected] + 1) % count).format(
                selected == 0 ? "%d" : "%02d"
            ),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.drawText(
            center,
            258,
            Graphics.FONT_SMALL,
            ((fields[selected] + count - 1) % count).format(
                selected == 0 ? "%d" : "%02d"
            ),
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.drawText(
            x,
            322,
            Graphics.FONT_XTINY,
            limited
                ? minutesOnly
                    ? "59:00 max; BACK cancels"
                    : "23:59:59 max; BACK cancels"
                : "START: next / save",
            Graphics.TEXT_JUSTIFY_CENTER
        );
        dc.setColor(0x00cc77, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawLine(width - 65, 99, width - 58, 106);
        dc.drawLine(width - 58, 106, width - 44, 87);
    }
}
class DurationEditorDelegate extends WatchUi.BehaviorDelegate {
    var editor;
    var dragging = false;
    var dragY = 0;
    var dragRemainder = 0;
    var suppressTouchUntil = -1;
    function initialize(editor) {
        BehaviorDelegate.initialize();
        self.editor = editor;
        editor.keyRepeat = new EditorKeyRepeat(editor);
    }
    function finish() as Void {
        editor.keyRepeat.stop();
        if (editor.save()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
    }
    // Fall through to onTap/onKey: a generic tap must never advance or save.
    function onSelect() { return false; }
    function selectNext() {
        editor.keyRepeat.stop();
        if (editor.selected < 2) {
            editor.selected += 1;
            WatchUi.requestUpdate();
        } else {
            finish();
        }
        return true;
    }
    function onBack() {
        editor.keyRepeat.stop();
        if (!editor.previous()) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
    }
    function onKeyPressed(event) {
        return editor.keyRepeat.press(event.getKey());
    }
    function onKeyReleased(event) {
        return editor.keyRepeat.release(event.getKey());
    }
    function onKey(event) {
        var key = event.getKey();
        if (key == WatchUi.KEY_UP || key == WatchUi.KEY_DOWN) {
            return true;
        }
        if (key == WatchUi.KEY_ENTER) {
            return selectNext();
        }
        if (key == WatchUi.KEY_ESC) {
            return onBack();
        }
        return false;
    }
    function onMenu() {
        return true;
    }
    // Physical UP/DOWN already change the value in onKeyPressed/hold repeat.
    // Let navigation fall through to onKey/onSwipe so touch and buttons stay distinct.
    function onPreviousPage() {
        return false;
    }
    function onNextPage() {
        return false;
    }
    function onDrag(event) {
        return dragAt(event.getType(), event.getCoordinates()[1]);
    }
    function dragAt(type, y) {
        editor.keyRepeat.stop();
        if (type == WatchUi.DRAG_TYPE_START) {
            dragging = true;
            dragY = y;
            dragRemainder = 0;
        } else if (dragging) {
            dragRemainder += dragY - y;
            dragY = y;
            var steps = (dragRemainder / 18).toNumber();
            if (steps != 0) {
                editor.adjust(steps);
                dragRemainder -= steps * 18;
            }
        }
        // Some firmware also emits a swipe/tap when the drag ends.
        suppressTouchUntil = System.getTimer() + 200;
        if (type == WatchUi.DRAG_TYPE_STOP) { dragging = false; }
        return true;
    }
    function onSwipe(event) {
        return swipeDirection(event.getDirection());
    }
    function swipeDirection(direction) {
        if (dragging || System.getTimer() <= suppressTouchUntil) { return true; }
        if (direction != WatchUi.SWIPE_UP && direction != WatchUi.SWIPE_DOWN) {
            return false;
        }
        editor.keyRepeat.stop();
        editor.adjust(direction == WatchUi.SWIPE_UP ? 1 : -1);
        return true;
    }
    function onTap(event) {
        var p = event.getCoordinates();
        return tapAt(p[0], p[1]);
    }
    function tapAt(x, y) {
        if (dragging || System.getTimer() <= suppressTouchUntil) { return true; }
        if (x >= editor.width - 85 && x <= editor.width - 25 && y >= 70 && y < 115) {
            finish();
            return true;
        }
        var center = editor.width / 2;
        var centers = editor.minutesOnly ? [0, center - 70, center + 70] : [center - 94, center, center + 94];
        if (y >= 172 && y <= 235) {
            for (var i = editor.minutesOnly ? 1 : 0; i < 3; i += 1) {
                if (x >= centers[i] - 35 && x <= centers[i] + 35) {
                    editor.keyRepeat.stop();
                    editor.selected = i;
                    WatchUi.requestUpdate();
                    break;
                }
            }
        }
        return true;
    }
}
