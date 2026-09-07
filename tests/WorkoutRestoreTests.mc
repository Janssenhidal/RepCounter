using Toybox.Lang;
using Toybox.Test;

function backupTestRecords() as Lang.Array {
    var backend = new MemoryWorkoutStorage();
    var store = new WorkoutStore(backend);
    store.finish(workoutTestSets(105), 210, 105);
    seedCurrentWorkout(backend, workoutTestSets(3));
    var export = new WorkoutBackup(store);
    var records = [];
    var record = export.next();
    while (record != null) { records.add(record); record = export.next(); }
    return records;
}

(:test)
function portableRestoreRoundTripAndSecondRestore(logger) {
    var raw = new MemoryWorkoutStorage();
    seedCurrentWorkout(raw, workoutTestSets(8));
    var records = backupTestRecords();
    for (var pass = 0; pass < 3; pass += 1) {
        var restore = new WorkoutRestore(raw);
        for (var i = 0; i < records.size(); i += 1) { restore.accept(records[i]); }
        // Data remains selected from the old namespace until the explicit commit.
        var old = new SelectedWorkoutStorage(raw, null);
        Test.assert(old.get("pullUps") == (pass == 0 ? 16 : 6));
        restore.commit();
        var selected = new SelectedWorkoutStorage(raw, null);
        var store = new WorkoutStore(selected);
        store.recover();
        Test.assert(selected.get("pullUps") == 6 && selected.get("totalSets") == 3);
        Test.assert(selected.get("incrementAmount") == 3 && selected.get("restDuration") == 90);
        Test.assert(selected.get("vibrationEnabled") == false);
        Test.assert(selected.get("restEndTime") == 0);
        Test.assert(store.count() == 1 && store.load(1).size() == 105);
        Test.assert((store.getSummary(1) as Lang.Dictionary)["reps"] == 210);
    }
    return true;
}

(:test)
function interruptedRestoreNeverSelectsPartialData(logger) {
    var records = backupTestRecords();
    for (var failure = 1; failure <= 24; failure += 1) {
        var raw = new MemoryWorkoutStorage();
        seedCurrentWorkout(raw, workoutTestSets(8));
        raw.failAt = raw.writes + failure;
        try {
            var restore = new WorkoutRestore(raw);
            for (var i = 0; i < records.size(); i += 1) { restore.accept(records[i]); }
            restore.commit();
        } catch (error) { }
        raw.failAt = -1;
        var selected = new SelectedWorkoutStorage(raw, null);
        var store = new WorkoutStore(selected);
        store.recover();
        if (selected.prefix.equals("")) { Test.assert(selected.get("pullUps") == 16 && store.count() == 0); }
        else { Test.assert(selected.get("pullUps") == 6 && store.load(1).size() == 105); }
        // A retry can clean the partial inactive slot and finish normally.
        var retry = new WorkoutRestore(raw);
        for (var i = 0; i < records.size(); i += 1) { retry.accept(records[i]); }
        retry.commit();
        Test.assert(new WorkoutStore(new SelectedWorkoutStorage(raw, null)).count() == 1);
    }
    return true;
}

(:test)
function invalidOrTruncatedRestoreCannotCommit(logger) {
    var records = backupTestRecords();
    var raw = new MemoryWorkoutStorage();
    seedCurrentWorkout(raw, workoutTestSets(8));
    var restore = new WorkoutRestore(raw);
    restore.accept(records[0]);
    var refused = false;
    try { restore.commit(); } catch (error) { refused = true; }
    Test.assert(refused && raw.get("backup.active.v1") == null);
    var broken = copyWorkoutTestValue(records[1]) as Lang.Dictionary;
    broken["offset"] = 99;
    refused = false;
    try { restore.accept(broken); } catch (error) { refused = true; }
    Test.assert(refused && raw.get("pullUps") == 16);
    return true;
}

(:test)
function portableRestoreUsesSerializedDeviceStorage(logger) {
    var raw = new DeviceTestWorkoutStorage();
    try {
        seedCurrentWorkout(raw, workoutTestSets(8));
        var records = backupTestRecords();
        var restore = new WorkoutRestore(raw);
        for (var i = 0; i < records.size(); i += 1) { restore.accept(records[i]); }
        restore.commit();
        var selected = new SelectedWorkoutStorage(raw, null);
        var reopened = new WorkoutStore(selected);
        reopened.recover();
        Test.assert(reopened.count() == 1 && reopened.load(1).size() == 105);
        Test.assert(selected.get("pullUps") == 6);
        // Normal future workouts are saved in the selected namespace too.
        reopened.finish(workoutTestSets(2), 4, 2);
        Test.assert(new WorkoutStore(new SelectedWorkoutStorage(raw, null)).count() == 2);
        Test.assert(raw.get("pullUps") == 16);
        raw.cleanup();
        return true;
    } catch (error) { raw.cleanup(); throw error; }
}
