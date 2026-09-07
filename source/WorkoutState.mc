using Toybox.Lang;

// Read and validate before changing the view. Missing keys retain legacy defaults.
function readWorkoutState(backend as WorkoutStorage) as Lang.Dictionary {
    var result = {};
    var keys = ["pullUps", "totalSets", "restEndTime"];
    for (var i = 0; i < keys.size(); i += 1) {
        var value = backend.get(keys[i]);
        if (value == null) { value = 0; }
        if (!(value instanceof Lang.Number) || value < 0) {
            throw new Lang.InvalidValueException("Invalid current workout");
        }
        result[keys[i]] = value;
    }
    var saved = backend.get("history");
    if (saved == null) { saved = []; }
    if (!(saved instanceof Lang.Array)) { throw new Lang.InvalidValueException("Invalid history"); }
    var history = saved as Lang.Array;
    var fields = ["setNumber", "counter", "increment", "rest", "timestamp"];
    for (var i = 0; i < history.size(); i += 1) {
        if (!(history[i] instanceof Lang.Dictionary)) { throw new Lang.InvalidValueException("Invalid set"); }
        var entry = history[i] as Lang.Dictionary;
        for (var j = 0; j < fields.size(); j += 1) {
            var value = entry[fields[j]];
            if (!(value instanceof Lang.Number) || value < 0) { throw new Lang.InvalidValueException("Invalid set value"); }
        }
    }
    result["history"] = history;
    return result;
}
