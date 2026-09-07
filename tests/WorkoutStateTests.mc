using Toybox.Test;
using Toybox.Lang;
class UnreadableWorkoutStorage extends MemoryWorkoutStorage {
    function initialize() { MemoryWorkoutStorage.initialize(); }
    function get(key) { throw new Lang.InvalidValueException("Unreadable data"); }
}
(:test)
function invalidStartupDataIsReadOnly(logger) {
    var backend = new MemoryWorkoutStorage();
    seedCurrentWorkout(backend, workoutTestSets(2));
    var before = backend.writes;
    Test.assert(readWorkoutState(backend)["pullUps"] == 4);
    Test.assert(backend.writes == before);
    backend.put("pullUps", "corrupt"); before = backend.writes;
    var rejected = false;
    try { readWorkoutState(backend); } catch (error) { rejected = true; }
    Test.assert(rejected && backend.writes == before);
    var unreadable = new UnreadableWorkoutStorage();
    rejected = false;
    try { readWorkoutState(unreadable); } catch (error) { rejected = true; }
    Test.assert(rejected && unreadable.writes == 0);
    return true;
}

(:test)
function appDataPreservesLegacySchema(logger) {
    var backend = new MemoryWorkoutStorage();
    var preferences = AppData.preferences(backend);
    Test.assert(preferences["increment"] == 2 && preferences["rest"] == 45 && preferences["vibration"]);
    seedCurrentWorkout(backend, workoutTestSets(2));
    var before = backend.writes;
    var session = AppData.session(backend);
    preferences = AppData.preferences(backend);
    Test.assert(session["currentCounter"] == 4 && session["totalSets"] == 2);
    Test.assert(preferences["increment"] == 3 && preferences["rest"] == 90 && !preferences["vibration"]);
    var sets = session["sets"] as Lang.Array;
    var entry = sets[0] as Lang.Dictionary;
    var decoded = AppData.decodeSet(AppData.encodeSet(entry));
    var fields = ["setNumber", "counter", "increment", "rest", "timestamp"];
    for (var i = 0; i < fields.size(); i += 1) { Test.assert(decoded[fields[i]] == entry[fields[i]]); }
    Test.assert(backend.writes == before);
    backend.put("incrementAmount", 0);
    var rejected = false;
    try { AppData.preferences(backend); } catch (error) { rejected = true; }
    Test.assert(rejected);
    return true;
}

