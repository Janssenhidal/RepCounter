using Toybox.Test;
using Toybox.Lang;

(:test)
function goalPaceAndRounding(logger) {
    Test.assert(WorkoutGoal.sets(1000, 5) == 200);
    Test.assert(WorkoutGoal.interval(1000, 10800, 5) == 54);
    Test.assert(WorkoutGoal.sets(1001, 5) == 201);
    Test.assert(WorkoutGoal.interval(1001, 10800, 5) == 53);
    Test.assert(WorkoutGoal.interval(99999, 60, 1) == 0);
    var goal = WorkoutGoal.defaults();
    Test.assert(WorkoutGoal.status(goal, 5, 1000, 1053, 0).equals("ON PACE"));
    Test.assert(WorkoutGoal.status(goal, 5, 1000, 1054, 0).equals("5 REPS BEHIND"));
    Test.assert(WorkoutGoal.status(goal, 5, 1000, 1054, 10).equals("5 REPS AHEAD"));
    Test.assert(WorkoutGoal.status(goal, 5, 1000, 11800, 995).equals("TIME UP"));
    Test.assert(WorkoutGoal.status(goal, 5, 1000, 11800, 1000).equals("GOAL REACHED"));
    return true;
}
(:test)
function goalStartResumeAndExplicitFinish(logger) {
    var view = timerTestView();
    view.workoutStore.storage.put("incrementAmount", 5);
    view.workoutStore.storage.put("workoutMode", "fixedInterval");
    var menu = new GoalMenu(view);
    menu.apply(1000, 10800, true);
    Test.assert(view.isInterval() && view.restDuration == 54 && (view.workoutGoal as Lang.Dictionary)["enabled"]);
    var now = Toybox.Time.now().value();
    view.recordSetAt(now);
    Test.assert(view.goalStart == now && view.totalSets == 0);
    view.recordSetAt(now + 20);
    Test.assert(view.totalSets == 1 && view.restEndTime == now + 54);
    view.reloadSettings(); view.reloadCurrentWorkout();
    Test.assert(view.goalStart == now && (view.workoutGoal as Lang.Dictionary)["enabled"]);
    view.tickAt(now + 10800);
    Test.assert(view.totalSets == 1 && view.workoutStore.count() == 0 && view.restEndTime > 0);
    Test.assert(view.finishWorkout());
    Test.assert(view.goalStart == 0 && view.totalSets == 0 && view.workoutStore.count() == 1);
    return true;
}
(:test)
function goalBackupAndLegacyDefaults(logger) {
    var view = timerTestView();
    new GoalMenu(view).apply(1000, 10800, true);
    var backup = new WorkoutBackup(view.workoutStore);
    var header = backup.next() as Lang.Dictionary;
    var backend = new MemoryWorkoutStorage();
    var restore = new WorkoutRestore(backend);
    restore.accept(header); restore.accept(backup.next() as Lang.Dictionary); restore.commit();
    var settings = AppData.preferences(new SelectedWorkoutStorage(backend, null));
    var goal = settings["goal"] as Lang.Dictionary;
    Test.assert(goal["reps"] == 1000 && goal["seconds"] == 10800 && !goal["enabled"]);
    Test.assert(((header["settings"] as Lang.Dictionary)["goal"] as Lang.Dictionary)["enabled"]);
    var defaults = AppData.preferences(new MemoryWorkoutStorage())["goal"] as Lang.Dictionary;
    Test.assert(!defaults["enabled"]);
    return true;
}

(:test)
function goalPickersAndDisablePreserveSets(logger) {
    var view = timerTestView();
    var menu = new GoalMenu(view);
    var reps = new GoalRepsEditor(menu, 1000);
    var time = new DurationEditor(10800, new GoalTimeSave(menu));
    Test.assert(reps != null && time != null);
    Test.assert(GoalEntryValue.decode(false, [0, 1, 0, 0, 0]) == 1000);
    Test.assert(GoalEntryValue.decode(false, [9, 9, 9, 9, 9]) == 99999);
    Test.assert(GoalEntryValue.decode(false, [0, 0, 0, 0, 1]) == 1);
    Test.assert(GoalEntryValue.decode(false, [0, 0, 0, 0, 0]) == 0);
    Test.assert(GoalEntryValue.decode(true, [3, null, 0]) == 10800);
    Test.assert(GoalEntryValue.decode(true, [23, null, 59]) == 86340);
    Test.assert((view.workoutGoal as Lang.Dictionary)["reps"] == 1000);
    menu.apply(1001, 10800, true);
    Test.assert(view.restDuration == 53);
    view.recordSetAt(1000); view.recordSetAt(1020);
    menu.apply(1001, 10800, false);
    Test.assert(view.totalSets == 1 && view.pullUps == 5 && view.restEndTime == 0);
    Test.assert(!(view.workoutGoal as Lang.Dictionary)["enabled"]);
    return true;
}

(:test)
function fourDigitGoalEditor(logger) {
    var view = timerTestView();
    var menu = new GoalMenu(view);
    var editor = new GoalRepsEditor(menu, 1000);
    Test.assert(editor.digits.size() == 4 && editor.value() == 1000);
    editor.selected = 3;
    var input = new GoalRepsEditorDelegate(editor);
    input.onBack(); Test.assert(editor.selected == 2);
    input.onBack(); Test.assert(editor.selected == 1);
    input.onBack(); Test.assert(editor.selected == 0);
    editor.selected = 3; editor.adjust(-1);
    Test.assert(editor.value() == 1009);
    editor.adjust(1); Test.assert(editor.value() == 1000);
    editor.selected = 0; editor.adjust(1);
    Test.assert(editor.value() == 2000);
    Test.assert((view.workoutGoal as Lang.Dictionary)["reps"] == 1000);
    Test.assert(editor.save());
    Test.assert((view.workoutGoal as Lang.Dictionary)["reps"] == 2000);
    var old = new GoalRepsEditor(menu, 50000);
    Test.assert(old.oversized && old.value() == 9999);
    Test.assert((view.workoutGoal as Lang.Dictionary)["reps"] == 2000);
    return true;
}
