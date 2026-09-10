using Toybox.Test;
using Toybox.Lang;

class DurationSaveSpy {
    var saved = -1;
    function initialize() {}
    function save(value) {
        saved = value;
        return true;
    }
}
(:test)
function durationEditorFieldsAndNavigation(logger) {
    var handler = new DurationSaveSpy();
    var editor = new DurationEditor(3661, handler);
    Test.assert(
        editor.fields[0] == 1 && editor.fields[1] == 1 && editor.fields[2] == 1
    );
    editor.fields = [0, 0, 0];
    editor.adjust(-1);
    Test.assert(editor.fields[0] == 23);
    editor.adjust(1);
    Test.assert(editor.fields[0] == 0);
    editor.selected = 1;
    editor.adjust(-1);
    Test.assert(editor.fields[1] == 59);
    editor.adjust(1);
    Test.assert(editor.fields[1] == 0);
    editor.selected = 2;
    editor.adjust(-1);
    Test.assert(editor.value() == 59);
    Test.assert(editor.previous() && editor.selected == 1);
    Test.assert(editor.previous() && editor.selected == 0);
    Test.assert(!editor.previous());
    Test.assert(handler.saved == -1);
    editor.fields = [23, 59, 59];
    Test.assert(editor.save() && handler.saved == 86399);
    Test.assert(
        !DurationText.valid(0) &&
            !DurationText.valid(86400) &&
            DurationText.valid(1)
    );
    Test.assert(DurationText.format(3661).equals("1:01:01"));
    Test.assert(DurationText.format(59).equals("00:59"));
    return true;
}
(:test)
function arbitraryRestAndIntervalSaving(logger) {
    var view = timerTestView();
    view.workoutMode = "fixedRest";
    view.recordSetAt(1000);
    var save = new RestTimeMenuDelegate(view, null);
    Test.assert(save.save(75));
    Test.assert(view.restDuration == 75 && view.restEndTime == 1060);
    Test.assert(view.workoutStore.storage.get("restDuration") == 75);
    view.recordSetAt(1020);
    Test.assert(view.restEndTime == 1095);
    Test.assert(!save.save(0) && view.restDuration == 75);
    Test.assert(save.save(3540));
    Test.assert(!save.save(3541) && view.restDuration == 3540);
    view.selectMode("fixedInterval");
    view.recordSetAt(2000);
    Test.assert(save.save(86399));
    Test.assert(view.restEndTime == 0 && view.totalSets == 2);
    view.recordSetAt(2100);
    Test.assert(view.restEndTime == 2100 + 86399);
    return true;
}
(:test)
function targetSecondsAndBackupRoundTrip(logger) {
    var view = timerTestView();
    var menu = new GoalMenu(view);
    var save = new GoalTimeSave(menu);
    Test.assert(save.save(1));
    Test.assert((view.workoutGoal as Lang.Dictionary)["seconds"] == 1);
    Test.assert(!save.save(0));
    Test.assert(save.save(86399));
    var export = new WorkoutBackup(view.workoutStore);
    var header = export.next() as Lang.Dictionary;
    var backend = new MemoryWorkoutStorage();
    var restore = new WorkoutRestore(backend);
    restore.accept(header);
    restore.accept(export.next() as Lang.Dictionary);
    restore.commit();
    var selected = new SelectedWorkoutStorage(backend, null);
    Test.assert(
        (AppData.preferences(selected)["goal"] as Lang.Dictionary)["seconds"] ==
            86399
    );
    return true;
}

(:test)
function restMinutesOnlyAndHoldRepeat(logger) {
    var handler = new DurationSaveSpy();
    var editor = new DurationEditor(5401, handler);
    editor.useMinutes();
    Test.assert(
        editor.selected == 1 && editor.fields[1] == 59 && editor.value() == 3540
    );
    Test.assert(!editor.previous());
    editor.selected = 2;
    Test.assert(editor.previous() && editor.selected == 1);
    editor.fields[1] = 0;
    editor.adjust(-1);
    Test.assert(editor.fields[1] == 59);
    editor.adjust(1);
    Test.assert(editor.fields[1] == 0);
    var repeat = new EditorKeyRepeat(editor);
    repeat.press(Toybox.WatchUi.KEY_UP);
    var began = repeat.began;
    Test.assert(editor.fields[1] == 1);
    repeat.advance(began + 499);
    Test.assert(editor.fields[1] == 1);
    repeat.advance(began + 500);
    Test.assert(editor.fields[1] == 2);
    repeat.advance(began + 1500);
    Test.assert(repeat.nextAt == began + 1600 && editor.fields[1] == 7);
    repeat.advance(began + 3000);
    Test.assert(repeat.nextAt == began + 3100 && editor.fields[1] == 12);
    repeat.release(Toybox.WatchUi.KEY_UP);
    var value = editor.value();
    repeat.advance(began + 5000);
    Test.assert(editor.value() == value);
    repeat.press(Toybox.WatchUi.KEY_DOWN);
    Test.assert(editor.value() == value - 60);
    repeat.stop();
    Test.assert(handler.saved == -1);
    return true;
}

(:test)
function editorButtonEventsChangeOnce(logger) {
    var saved = new DurationSaveSpy();
    var editor = new DurationEditor(51, saved);
    editor.useMinutes();
    editor.selected = 2;
    var input = new DurationEditorDelegate(editor);
    var down = Toybox.WatchUi.KEY_DOWN;
    var up = Toybox.WatchUi.KEY_UP;
    editor.keyRepeat.press(down);
    input.onNextPage();
    editor.keyRepeat.release(down);
    Test.assert(editor.value() == 50);
    Test.assert(editor.save() && saved.saved == 50);
    editor.keyRepeat.press(up);
    input.onPreviousPage();
    editor.keyRepeat.release(up);
    Test.assert(editor.value() == 51);
    editor.fields = [0, 50, 1];
    editor.keyRepeat.press(down);
    editor.keyRepeat.release(down);
    input.onNextPage();
    Test.assert(editor.value() == 3000);
    Test.assert(editor.save() && saved.saved == 3000);
    var view = timerTestView();
    var reps = new GoalRepsEditor(new GoalMenu(view), 1000);
    reps.selected = 3;
    var repsInput = new GoalRepsEditorDelegate(reps);
    reps.keyRepeat.press(up);
    repsInput.onPreviousPage();
    reps.keyRepeat.release(up);
    Test.assert(reps.value() == 1001);
    return true;
}

(:test)
function singleFieldRepsEditor(logger) {
    var view = timerTestView();
    var editor = new RepsEditor("REPS PER SET", 9, 2, new IncrementMenuDelegate(view, null));
    Test.assert(editor.digits.size() == 1 && editor.value() == 9);
    editor.adjust(90); Test.assert(editor.value() == 99);
    editor.adjust(1); Test.assert(editor.value() == 1);
    editor.adjust(-1); Test.assert(editor.value() == 99);
    Test.assert(editor.save() && view.incrementAmount == 99);
    var input = new RepsEditorDelegate(editor);
    input.dragAt(Toybox.WatchUi.DRAG_TYPE_START, 200);
    input.dragAt(Toybox.WatchUi.DRAG_TYPE_STOP, 164);
    Test.assert(editor.value() == 2);
    var target = new GoalRepsEditor(new GoalMenu(view), 1000);
    var repeat = new EditorKeyRepeat(target);
    target.selected = 3;
    repeat.press(Toybox.WatchUi.KEY_UP);
    repeat.advance(repeat.began + 1600);
    Test.assert(target.value() == 1002);
    repeat.release(Toybox.WatchUi.KEY_MENU);
    repeat.advance(repeat.began + 2000);
    Test.assert(target.value() == 1002 && repeat.direction == 0);
    repeat.press(Toybox.WatchUi.KEY_UP);
    repeat.advance(repeat.began + 10000);
    Test.assert(repeat.direction == 0 && target.value() == 1003);
    var whole = new EditorKeyRepeat(editor);
    whole.press(Toybox.WatchUi.KEY_UP);
    whole.advance(whole.began + 1600);
    Test.assert(editor.value() == 8);
    whole.stop();
    return true;
}

(:test)
function timeDragDistance(logger) {
    var editor = new DurationEditor(10, new DurationSaveSpy());
    editor.useMinutes(); editor.selected = 2;
    var input = new DurationEditorDelegate(editor);
    input.dragAt(Toybox.WatchUi.DRAG_TYPE_START, 250);
    input.dragAt(Toybox.WatchUi.DRAG_TYPE_CONTINUE, 241);
    Test.assert(editor.value() == 10);
    input.dragAt(Toybox.WatchUi.DRAG_TYPE_CONTINUE, 160);
    Test.assert(editor.value() == 15);
    input.dragAt(Toybox.WatchUi.DRAG_TYPE_STOP, 196);
    Test.assert(editor.value() == 13);
    input.swipeDirection(Toybox.WatchUi.SWIPE_UP);
    Test.assert(editor.value() == 13);
    input.dragAt(Toybox.WatchUi.DRAG_TYPE_START, 100);
    input.dragAt(Toybox.WatchUi.DRAG_TYPE_STOP, 118);
    Test.assert(editor.value() == 12);
    return true;
}

(:test)
function pickerTapsOnlySelectFields(logger) {
    var view = timerTestView();
    var reps = new GoalRepsEditor(new GoalMenu(view), 1000);
    var input = new GoalRepsEditorDelegate(reps);
    Test.assert(!input.onSelect());
    input.tapAt(195, 300); Test.assert(reps.selected == 0);
    input.tapAt(279, 200); Test.assert(reps.selected == 3);
    input.tapAt(111, 200); Test.assert(reps.selected == 0);
    input.tapAt(111, 115); Test.assert(reps.value() == 1000);
    var spy = new DurationSaveSpy();
    var time = new DurationEditor(60, spy); time.useMinutes();
    var controls = new DurationEditorDelegate(time);
    Test.assert(!controls.onSelect());
    controls.tapAt(265, 200); Test.assert(time.selected == 2);
    controls.tapAt(125, 200); Test.assert(time.selected == 1);
    controls.tapAt(195, 200); Test.assert(time.selected == 1);
    controls.tapAt(195, 300); Test.assert(spy.saved == -1);
    Test.assert((view.workoutGoal as Lang.Dictionary)["reps"] == 1000);
    return true;
}
