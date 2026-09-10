using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;
using Toybox.System;

class RepsEditor extends WatchUi.View {
    var handler;
    var numberFont;
    var title;
    var maximum;
    var width = 390;
    var keyRepeat;
    var digits as Lang.Array = [];
    var selected = 0;
    var oversized = false;
    function initialize(title, value, count, handler) {
        View.initialize();
        self.title = title;
        self.handler = handler;
        numberFont = WatchUi.loadResource(Rez.Fonts.RepTimer);
        maximum = count == 2 ? 99 : 9999;
        oversized = value > maximum;
        if (oversized) {
            value = maximum;
        }
        if (count == 2) { digits.add(value < 1 ? 1 : value); return; }
        var divisor = 1000;
        for (var i = 0; i < count; i += 1) {
            digits.add((value / divisor).toNumber() % 10);
            divisor = (divisor / 10).toNumber();
        }
    }
    function onHide() as Void {
        if (keyRepeat != null) {
            keyRepeat.stop();
        }
    }
    function value() {
        return GoalEntryValue.decode(false, digits);
    }
    function repeatStep() { return maximum == 99 ? 5 : 1; }
    function neighbor(delta) {
        var minimum = maximum == 99 ? 1 : 0;
        var count = maximum == 99 ? 99 : 10;
        return ((digits[selected] - minimum + delta) % count + count) % count + minimum;
    }
    function adjust(delta) as Void {
        digits[selected] = neighbor(delta);
        WatchUi.requestUpdate();
    }
    function save() {
        var reps = value();
        if (reps == 0) {
            workoutMessage("Enter at least 1 rep.");
            return false;
        }
        return handler.save(reps);
    }
    function onUpdate(dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        width = dc.getWidth();
        var x = width / 2;
        dc.drawText(
            x,
            60,
            Graphics.FONT_SMALL,
            title,
            Graphics.TEXT_JUSTIFY_CENTER
        );
        for (var i = 0; i < digits.size(); i += 1) {
            var center = x - (digits.size() - 1) * 28 + i * 56;
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                center,
                172,
                numberFont,
                digits[i].format("%d"),
                Graphics.TEXT_JUSTIFY_CENTER
            );
            if (i == selected) {
                dc.setColor(0x00dce5, Graphics.COLOR_TRANSPARENT);
                dc.fillRectangle(center - 20, 232, 40, 3);
                dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
                dc.drawText(
                    center,
                    115,
                    Graphics.FONT_SMALL,
                    neighbor(1).format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER
                );
                dc.drawText(
                    center,
                    258,
                    Graphics.FONT_SMALL,
                    neighbor(-1).format("%d"),
                    Graphics.TEXT_JUSTIFY_CENTER
                );
            }
            dc.setColor(0x00cc77, Graphics.COLOR_TRANSPARENT);
            dc.setPenWidth(4);
            dc.drawLine(width - 65, 99, width - 58, 106);
            dc.drawLine(width - 58, 106, width - 44, 87);
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            322,
            Graphics.FONT_XTINY,
            oversized
                ? "Max " + maximum.format("%d") + "; BACK keeps saved"
                : "START: next / save",
            Graphics.TEXT_JUSTIFY_CENTER
        );
    }
}
class RepsEditorDelegate extends WatchUi.BehaviorDelegate {
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
        if (editor.selected < editor.digits.size() - 1) {
            editor.selected += 1;
            WatchUi.requestUpdate();
        } else {
            finish();
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
    // Consume translated navigation events without applying the same press twice.
    function onPreviousPage() {
        return false;
    }
    function onNextPage() {
        return false;
    }
    function onBack() {
        editor.keyRepeat.stop();
        if (editor.selected > 0) {
            editor.selected -= 1;
            WatchUi.requestUpdate();
        } else {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
        }
        return true;
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
        var left = editor.width / 2 - editor.digits.size() * 28;
        if (y >= 172 && y <= 235 && x >= left && x < left + editor.digits.size() * 56) {
            editor.keyRepeat.stop();
            editor.selected = ((x - left) / 56).toNumber();
            WatchUi.requestUpdate();
        }
        return true;
    }
}

class GoalRepsEditor extends RepsEditor {
    function initialize(menu, value) {
        RepsEditor.initialize("TARGET REPS", value, 4, new GoalRepsSave(menu));
    }
}
class GoalRepsEditorDelegate extends RepsEditorDelegate {
    function initialize(editor) {
        RepsEditorDelegate.initialize(editor);
    }
}
class GoalRepsSave {
    var menu;
    function initialize(menu) {
        self.menu = menu;
    }
    function save(reps) {
        var goal = menu.view.workoutGoal as Lang.Dictionary;
        if (
            goal["enabled"] &&
            WorkoutGoal.interval(
                reps,
                goal["seconds"],
                menu.view.incrementAmount
            ) < 1
        ) {
            workoutMessage("Target too fast.\nAllow at least 1s per set.");
            return false;
        }
        menu.apply(reps, goal["seconds"], goal["enabled"]);
        return true;
    }
}
