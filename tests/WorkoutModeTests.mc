using Toybox.Test;
using Toybox.Lang;

(:test)
function workoutModeDefaultsAndBackup(logger) {
    var backend = new MemoryWorkoutStorage();
    Test.assert(AppData.preferences(backend)["mode"].equals("fixedRest"));
    backend.put("workoutMode", "fixedInterval");
    Test.assert(AppData.preferences(backend)["mode"].equals("fixedInterval"));
    var backup = new WorkoutBackup(new WorkoutStore(backend));
    var header = backup.next() as Lang.Dictionary;
    Test.assert(
        (header["settings"] as Lang.Dictionary)["mode"].equals("fixedInterval")
    );
    var restored = new MemoryWorkoutStorage();
    var restore = new WorkoutRestore(restored);
    restore.accept(header);
    restore.accept(backup.next() as Lang.Dictionary);
    restore.commit();
    Test.assert(
        AppData.preferences(new SelectedWorkoutStorage(restored, null))[
            "mode"
        ].equals("fixedInterval")
    );
    // An old backup must reset the mode rather than reuse an inactive slot's value.
    (header["settings"] as Lang.Dictionary).remove("mode");
    restore = new WorkoutRestore(restored);
    restore.accept(header);
    restore.accept({ "kind" => "end" });
    restore.commit();
    Test.assert(
        AppData.preferences(new SelectedWorkoutStorage(restored, null))[
            "mode"
        ].equals("fixedRest")
    );
    return true;
}

function timerTestView() {
    var view = new PullUpCounterView();
    view.workoutStore = new WorkoutStore(new MemoryWorkoutStorage());
    view.workoutReady = true;
    view.pullUps = 0;
    view.totalSets = 0;
    view.history = [];
    view.restEndTime = 0;
    view.restSeconds = 0;
    view.restDuration = 60;
    view.incrementAmount = 5;
    view.workoutMode = "fixedInterval";
    return view;
}

(:test)
function intervalStartsWithoutSetAndKeepsCadence(logger) {
    var view = timerTestView();
    view.recordSetAt(1000);
    Test.assert(
        view.totalSets == 0 && view.pullUps == 0 && view.history.size() == 0
    );
    Test.assert(view.restEndTime == 1060);
    view.recordSetAt(1020);
    Test.assert(
        view.totalSets == 1 && view.pullUps == 5 && view.restSeconds == 40
    );
    Test.assert(view.restEndTime == 1060);
    Test.assert(view.tickAt(1060));
    Test.assert(view.restEndTime == 1120 && view.restSeconds == 60);
    Test.assert(!view.tickAt(1061));
    view.recordSetAt(1080);
    Test.assert(
        view.totalSets == 2 &&
            view.restEndTime == 1120 &&
            view.restSeconds == 40
    );
    Test.assert(view.tickAt(1250));
    Test.assert(view.restEndTime == 1300 && view.totalSets == 2);
    view.undoPullUps();
    Test.assert(view.totalSets == 1 && view.restEndTime == 1300);
    view.resetCounter();
    Test.assert(view.totalSets == 0 && view.restEndTime == 0);
    return true;
}

(:test)
function fixedRestStillRestartsAfterEachSet(logger) {
    var view = timerTestView();
    view.workoutMode = "fixedRest";
    view.recordSetAt(1000);
    Test.assert(view.totalSets == 1 && view.restEndTime == 1060);
    view.recordSetAt(1020);
    Test.assert(
        view.totalSets == 2 &&
            view.restEndTime == 1080 &&
            view.restSeconds == 60
    );
    Test.assert(view.tickAt(1080));
    Test.assert(view.restEndTime == 0 && view.restSeconds == 0);
    Test.assert(!view.tickAt(1081));
    return true;
}

(:test)
function modeChangeAndEmptyIntervalCancel(logger) {
    var view = timerTestView();
    view.recordSetAt(1000);
    view.undoPullUps();
    Test.assert(view.restEndTime == 0 && view.totalSets == 0);
    view.recordSetAt(2000);
    view.recordSetAt(2020);
    view.selectMode("fixedRest");
    Test.assert(view.restEndTime == 0 && view.totalSets == 1);
    Test.assert(view.timerSettingLabel().equals("Rest Time"));
    view.selectMode("fixedInterval");
    Test.assert(view.timerSettingLabel().equals("Interval"));
    view.recordSetAt(3000);
    Test.assert(view.totalSets == 1 && view.restEndTime == 3060);
    return true;
}

(:test)
function intervalReopensOnOriginalSchedule(logger) {
    var view = timerTestView();
    var now = Toybox.Time.now().value();
    view.recordSetAt(now - 150);
    view.reloadCurrentWorkout();
    Test.assert(view.restSeconds > 0 && view.restSeconds <= 30);
    Test.assert(view.restEndTime == now + 30);
    Test.assert(view.totalSets == 0 && view.history.size() == 0);
    view.recordSetAt(now + 10);
    Test.assert(view.totalSets == 1 && view.restEndTime == now + 30);
    Test.assert(view.finishWorkout());
    Test.assert(view.restEndTime == 0 && view.totalSets == 0);
    return true;
}
