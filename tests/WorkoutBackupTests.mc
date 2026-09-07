using Toybox.Test;
using Toybox.Lang;

(:test)
function backupStreamsCompleteArchive(logger) {
    var backend = new MemoryWorkoutStorage();
    var store = new WorkoutStore(backend);
    seedCurrentWorkout(backend, workoutTestSets(205));
    store.finish(workoutTestSets(205), 410, 205);
    seedCurrentWorkout(backend, workoutTestSets(3));
    var original = copyWorkoutTestValue(backend.values) as Lang.Dictionary;
    var writes = backend.writes;
    var backup = new WorkoutBackup(store);
    var header = backup.next() as Lang.Dictionary;
    Test.assert(header["format"].equals("pullupcounter.backup"));
    Test.assert(header["version"] == 1);
    Test.assert(header["workouts"] == 1);
    Test.assert((header["settings"] as Lang.Dictionary)["increment"] == 3);
    var rows = 0;
    var currentRows = 0;
    var summaries = 0;
    var ended = false;
    var record = backup.next();
    while (record != null) {
        if (record["kind"].equals("rows")) {
            var data = record["rows"] as Lang.Array;
            Test.assert(data.size() <= 25);
            if (record["id"] == 0) { currentRows += data.size(); }
            else {
                Test.assert(record["offset"] == rows);
                for (var i = 0; i < data.size(); i += 1) {
                    Test.assert((data[i] as Lang.Array)[0] == rows + i + 1);
                    Test.assert((data[i] as Lang.Array)[1] == (rows + i + 1) * 2);
                }
                rows += data.size();
            }
        } else if (record["kind"].equals("workout")) {
            summaries += 1;
            Test.assert(record["rows"] == 205);
        } else { Test.assert(record["kind"].equals("end")); ended = true; }
        record = backup.next();
    }
    Test.assert(rows == 205 && currentRows == 3 && summaries == 1 && ended);
    Test.assert(backend.writes == writes);
    Test.assert(backend.get("pullUps") == original["pullUps"]);
    return true;
}

(:test)
function backupEmptyAndDeletedWorkouts(logger) {
    var backend = new MemoryWorkoutStorage();
    var store = new WorkoutStore(backend);
    var backup = new WorkoutBackup(store);
    Test.assert((backup.next() as Lang.Dictionary)["workouts"] == 0);
    Test.assert((backup.next() as Lang.Dictionary)["kind"].equals("end"));
    Test.assert(backup.next() == null);
    for (var i = 0; i < 3; i += 1) { store.finish(workoutTestSets(1), 2, 1); }
    store.deleteWorkout(2);
    backup = new WorkoutBackup(store);
    Test.assert((backup.next() as Lang.Dictionary)["workouts"] == 2);
    var ids = [];
    var record = backup.next();
    while (record != null) {
        if (record["kind"].equals("workout")) { ids.add(record["id"]); }
        record = backup.next();
    }
    Test.assert(ids.size() == 2 && ids[0] == 1 && ids[1] == 3);
    return true;
}


