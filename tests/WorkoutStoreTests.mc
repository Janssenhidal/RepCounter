using Toybox.Lang;
using Toybox.Test;
using Toybox.Application;

function copyWorkoutTestValue(value) {
    if (value instanceof Lang.Array) {
        var result = [];
        var array = value as Lang.Array;
        for (var i = 0; i < array.size(); i += 1) { result.add(copyWorkoutTestValue(array[i])); }
        return result;
    }
    if (value instanceof Lang.Dictionary) {
        var result = {};
        var dictionary = value as Lang.Dictionary;
        var keys = dictionary.keys();
        for (var i = 0; i < keys.size(); i += 1) { result[keys[i]] = copyWorkoutTestValue(dictionary[keys[i]]); }
        return result;
    }
    return value;
}

class MemoryWorkoutStorage extends WorkoutStorage {
    var values as Lang.Dictionary = {};
    var writes = 0;
    var failAt = -1;
    function initialize() { WorkoutStorage.initialize(); }
    function get(key) { return copyWorkoutTestValue(values[key]); }
    function checkFailure() {
        writes += 1;
        if (writes == failAt) { throw new Lang.StorageFullException("Injected storage failure"); }
    }
    function put(key, value) { checkFailure(); values[key] = copyWorkoutTestValue(value); }
    function remove(key) { checkFailure(); values.remove(key); }
}

function workoutTestSets(count) as Lang.Array {
    var sets = [];
    for (var i = 0; i < count; i += 1) {
        sets.add({ "setNumber" => i + 1, "counter" => (i + 1) * 2,
            "increment" => 2, "rest" => 45, "timestamp" => 1700000000 + i * 60 });
    }
    return sets;
}

function seedCurrentWorkout(backend as WorkoutStorage, sets as Lang.Array) {
    backend.put("history", sets);
    backend.put("pullUps", sets.size() * 2);
    backend.put("totalSets", sets.size());
    backend.put("restEndTime", 1700010000);
    backend.put("incrementAmount", 3);
    backend.put("restDuration", 90);
    backend.put("vibrationEnabled", false);
}

(:test)
function legacyCurrentWorkoutSurvivesRecovery(logger) {
    var backend = new MemoryWorkoutStorage();
    var sets = workoutTestSets(4);
    seedCurrentWorkout(backend, sets);
    var store = new WorkoutStore(backend);
    store.recover();
    Test.assert(store.before(store.nextId(), 10000).size() == 0);
    Test.assert((backend.get("history") as Lang.Array).size() == 4);
    Test.assert(backend.get("pullUps") == 8);
    Test.assert(backend.get("restEndTime") == 1700010000);
    Test.assert(backend.get(store.INDEX_KEY) == null);
    return true;
}

(:test)
function finishRoundTripAndReopen(logger) {
    var backend = new MemoryWorkoutStorage();
    var sets = workoutTestSets(205);
    seedCurrentWorkout(backend, sets);
    var store = new WorkoutStore(backend);
    Test.assert(store.finish(sets, 410, 205));
    store = new WorkoutStore(backend);
    store.recover();
    var summaries = store.before(store.nextId(), 10000);
    var summary = summaries[0] as Lang.Dictionary;
    Test.assert(summary["chunks"] == 3);
    Test.assert(summary["reps"] == 410);
    var loaded = store.load(summary["id"]);
    Test.assert(loaded.size() == sets.size());
    for (var i = 0; i < loaded.size(); i += 1) {
        var expected = sets[i] as Lang.Dictionary;
        var actual = loaded[i] as Lang.Dictionary;
        var keys = expected.keys();
        for (var k = 0; k < keys.size(); k += 1) { Test.assert(expected[keys[k]] == actual[keys[k]]); }
    }
    Test.assert((backend.get("history") as Lang.Array).size() == 0);
    Test.assert(backend.get("pullUps") == 0);
    Test.assert(backend.get("totalSets") == 0);
    Test.assert(backend.get("restEndTime") == 0);
    Test.assert(backend.get("incrementAmount") == 3);
    Test.assert(backend.get("restDuration") == 90);
    Test.assert(backend.get("vibrationEnabled") == false);
    return true;
}

(:test)
function emptyWorkoutIsNotArchived(logger) {
    var backend = new MemoryWorkoutStorage();
    var store = new WorkoutStore(backend);
    Test.assert(!store.finish([], 0, 0));
    Test.assert(!store.finish(workoutTestSets(1), 2, 0));
    Test.assert(!store.finish(workoutTestSets(1), 0, 1));
    Test.assert(!store.finish([], 2, 1));
    Test.assert(store.before(store.nextId(), 10000).size() == 0);
    Test.assert(backend.writes == 0);
    return true;
}

(:test)
function retainBeyond100AndDelete(logger) {
    var backend = new MemoryWorkoutStorage();
    var store = new WorkoutStore(backend);
    var sets = workoutTestSets(1);
    for (var i = 0; i < 101; i += 1) { store.finish(sets, 2, 1); }
    var summaries = store.before(store.nextId(), 10000);
    Test.assert(summaries.size() == 101);
    Test.assert((summaries[0] as Lang.Dictionary)["id"] == 101);
    Test.assert((summaries[100] as Lang.Dictionary)["id"] == 1);
    Test.assert(backend.get(store.chunkKey(1, 0)) != null);
    seedCurrentWorkout(backend, sets);
    store.deleteWorkout(51);
    Test.assert(store.count() == 100);
    Test.assert(backend.get(store.chunkKey(51, 0)) == null);
    Test.assert((backend.get("history") as Lang.Array).size() == 1);
    Test.assert(backend.get("pullUps") == 2);
    store.deleteWorkout(51);
    Test.assert(store.count() == 100);
    return true;
}

(:test)
function interruptedFinishRecoversWithoutLostOrDuplicateSets(logger) {
    // Exercise every write in a two-chunk finish, including the commit and current reset.
    for (var failure = 1; failure <= 10; failure += 1) {
        var backend = new MemoryWorkoutStorage();
        var sets = workoutTestSets(101);
        seedCurrentWorkout(backend, sets);
        backend.writes = 0;
        backend.failAt = failure;
        var store = new WorkoutStore(backend);
        try { store.finish(sets, 202, 101); } catch (error) { }
        backend.failAt = -1;
        store = new WorkoutStore(backend);
        store.recover();
        store.recover();
        var saved = backend.get("history") as Lang.Array;
        var summaries = store.before(store.nextId(), 10000);
        if (failure <= 5) {
            Test.assert(saved.size() == 101);
            Test.assert(summaries.size() == 0);
            Test.assert(backend.get(store.chunkKey(1, 0)) == null);
            Test.assert(backend.get(store.chunkKey(1, 1)) == null);
            store.finish(saved, 202, 101);
        } else {
            Test.assert(saved.size() == 0);
            Test.assert(summaries.size() == 1);
        }
        Test.assert(store.before(store.nextId(), 10000).size() == 1);
        Test.assert(store.load(1).size() == 101);
    }
    return true;
}

(:test)
function interruptedDeletionRecovers(logger) {
    for (var failure = 1; failure <= 5; failure += 1) {
        var backend = new MemoryWorkoutStorage();
        var store = new WorkoutStore(backend);
        store.finish(workoutTestSets(101), 202, 101);
        backend.writes = 0;
        backend.failAt = failure;
        try { store.deleteWorkout(1); } catch (error) { }
        backend.failAt = -1;
        store = new WorkoutStore(backend);
        store.recover();
        if (failure == 1) { Test.assert(store.load(1).size() == 101); }
        else {
            Test.assert(store.before(store.nextId(), 10000).size() == 0);
            Test.assert(backend.get(store.chunkKey(1, 0)) == null);
            Test.assert(backend.get(store.chunkKey(1, 1)) == null);
        }
    }
    return true;
}

// Use a separate namespace, never the real current workout or archive keys.
class DeviceTestWorkoutStorage extends WorkoutStorage {
    var keys as Lang.Array = [];
    function initialize() { WorkoutStorage.initialize(); }
    function get(key) { return Application.Storage.getValue("workoutTest." + key); }
    function put(key, value) {
        if (keys.indexOf(key) < 0) { keys.add(key); }
        Application.Storage.setValue("workoutTest." + key, value);
    }
    function remove(key) { Application.Storage.deleteValue("workoutTest." + key); }
    function cleanup() {
        for (var i = 0; i < keys.size(); i += 1) { remove(keys[i]); }
    }
}

(:test)
function actualDeviceStorage100Workouts(logger) {
    var backend = new DeviceTestWorkoutStorage();
    try {
        var store = new WorkoutStore(backend);
        var sets = workoutTestSets(20);
        for (var i = 0; i < 100; i += 1) { store.finish(sets, 40, 20); }
        Test.assert(store.before(store.nextId(), 10000).size() == 100);
        Test.assert(store.load(1).size() == 20);
        Test.assert(store.load(100).size() == 20);
        store.finish(sets, 40, 20);
        Test.assert(store.count() == 101);
        Test.assert(backend.get(store.chunkKey(1, 0)) != null);
        backend.cleanup();
        return true;
    } catch (error) { backend.cleanup(); throw error; }
}

(:test)
function workoutListCurrentFirstAndNewestCompletedFirst(logger) {
    var backend = new MemoryWorkoutStorage();
    var store = new WorkoutStore(backend);
    store.finish(workoutTestSets(2), 4, 2);
    store.finish(workoutTestSets(3), 6, 3);
    var main = new PullUpCounterView();
    main.workoutStore = store;
    main.history = workoutTestSets(4);
    main.pullUps = 8;
    main.totalSets = 4;
    var menu = new WorkoutHistoryMenu(main);
    Test.assert(menu.itemCount == 3);
    Test.assert(menu.getItem(0).getId() == :current);
    Test.assert(menu.getItem(0).getSubLabel().equals("8 reps / 4 sets"));
    Test.assert(menu.getItem(1).getId() == 2);
    Test.assert(menu.getItem(1).getSubLabel().equals("6 reps / 3 sets"));
    Test.assert(menu.getItem(2).getId() == 1);
    var currentDetail = new HistoryView(main.history);
    Test.assert(currentDetail.history == main.history);
    Test.assert(currentDetail instanceof Toybox.WatchUi.CustomMenu);
    var setDelegate = new HistoryDelegate(currentDetail);
    Test.assert(setDelegate instanceof Toybox.WatchUi.Menu2InputDelegate);
    Test.assert(!(setDelegate has :onSwipe));
    setDelegate.onSelect(currentDetail.getItem(0));
    Test.assert(main.history.size() == 4);
    var completedDetail = new HistoryView(store.load(2));
    completedDetail.setFooter(new HistoryDeleteLabel());
    Test.assert(completedDetail.history.size() == 3);
    Test.assert(main.history.size() == 4);
    store.deleteWorkout(2);
    menu.refresh();
    Test.assert(menu.itemCount == 2);
    Test.assert(menu.getItem(0).getId() == :current);
    Test.assert(menu.getItem(1).getId() == 1);
    Test.assert(main.pullUps == 8);
    return true;
}

function seedLegacyWorkoutArchive(backend as WorkoutStorage) {
    var summaries = [];
    for (var id = 99; id <= 101; id += 1) {
        summaries.add({ "id" => id, "start" => 1700000000 + id, "end" => 1700001000 + id,
            "reps" => 2, "sets" => 1, "chunks" => 1 });
        backend.put("workout.v1." + id.format("%d") + ".0", [[1, 2, 2, 45, 1700000000 + id]]);
    }
    backend.put("workouts.v1", { "version" => 1, "nextId" => 102,
        "workouts" => summaries, "writing" => null, "clearCurrent" => false, "garbage" => [] });
    seedCurrentWorkout(backend, workoutTestSets(4));
}

(:test)
function legacyArchiveMigrationAndInterruptedMigration(logger) {
    for (var failure = 1; failure <= 4; failure += 1) {
        var backend = new MemoryWorkoutStorage();
        seedLegacyWorkoutArchive(backend);
        backend.writes = 0;
        backend.failAt = failure;
        var store = new WorkoutStore(backend);
        try { store.recover(); } catch (error) { }
        backend.failAt = -1;
        store = new WorkoutStore(backend);
        store.recover();
        store.recover();
        Test.assert(store.count() == 3);
        Test.assert(store.nextId() == 102);
        Test.assert(store.readPage(0).size() == 2);
        Test.assert(store.readPage(1).size() == 1);
        Test.assert(store.load(99).size() == 1);
        Test.assert(store.load(101).size() == 1);
        Test.assert((backend.get("history") as Lang.Array).size() == 4);
        Test.assert(backend.get("pullUps") == 8);
        Test.assert(backend.get("restEndTime") == 1700010000);
        store.finish(workoutTestSets(1), 2, 1);
        Test.assert(store.count() == 4);
        Test.assert(store.load(102).size() == 1);
    }
    return true;
}

(:test)
function migrationCompletesPreviouslyCommittedFinish(logger) {
    var backend = new MemoryWorkoutStorage();
    seedLegacyWorkoutArchive(backend);
    var legacy = backend.get("workouts.v1") as Lang.Dictionary;
    legacy["clearCurrent"] = true;
    backend.put("workouts.v1", legacy);
    var store = new WorkoutStore(backend);
    store.recover();
    Test.assert(store.count() == 3);
    Test.assert(store.load(101).size() == 1);
    Test.assert((backend.get("history") as Lang.Array).size() == 0);
    Test.assert(backend.get("pullUps") == 0);
    return true;
}

(:test)
function continuousHistoryAcrossGroupsWithBoundedMenu(logger) {
    var backend = new MemoryWorkoutStorage();
    var store = new WorkoutStore(backend);
    for (var id = 1; id <= 350; id += 1) { store.finish(workoutTestSets(1), 2, 1); }
    Test.assert(store.count() == 350);
    Test.assert(store.readPage(0).size() == 100);
    Test.assert(store.readPage(3).size() == 50);
    Test.assert(store.load(1).size() == 1);
    var main = new PullUpCounterView();
    main.workoutStore = store;
    main.history = workoutTestSets(1);
    main.totalSets = 1;
    main.pullUps = 2;
    var menu = new WorkoutHistoryMenu(main);
    var menuDelegate = new WorkoutHistoryMenuDelegate(menu);
    Test.assert(menu.itemCount == 101);
    Test.assert(menu.getItem(1).getId() == 350);
    menuDelegate.onNextPage();
    Test.assert(menu.itemCount == 201);
    Test.assert(menu.getItem(200).getId() == 151);
    menuDelegate.onNextPage();
    Test.assert(menu.itemCount == 200);
    Test.assert(menu.getItem(0).getId() == 250);
    Test.assert(menu.getItem(199).getId() == 51);
    menuDelegate.onNextPage();
    Test.assert(menu.itemCount == 200);
    Test.assert(menu.getItem(199).getId() == 1);
    menuDelegate.onPreviousPage();
    menuDelegate.onPreviousPage();
    Test.assert(menu.atNewest);
    Test.assert(menu.getItem(0).getId() == :current);
    Test.assert(menu.getItem(1).getId() == 350);
    // Removing every workout from one storage group must not create a visible gap.
    for (var id = 101; id <= 200; id += 1) { store.deleteWorkout(id); }
    Test.assert(store.readPage(1).size() == 0);
    var older = store.before(201, 100);
    Test.assert(older.size() == 100);
    Test.assert((older[0] as Lang.Dictionary)["id"] == 100);
    Test.assert((older[99] as Lang.Dictionary)["id"] == 1);
    var newer = store.after(100, 100);
    Test.assert((newer[99] as Lang.Dictionary)["id"] == 201);
    Test.assert(store.count() == 250);
    return true;
}

