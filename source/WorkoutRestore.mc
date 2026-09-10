using Toybox.Lang;

// The root pointer is the only commit write. Legacy keys remain active until then.
class SelectedWorkoutStorage extends WorkoutStorage {
    var raw as WorkoutStorage;
    var prefix as Lang.String;
    function initialize(backend as WorkoutStorage, selected) {
        WorkoutStorage.initialize();
        raw = backend;
        var saved = selected == null ? raw.get("backup.active.v1") : selected;
        prefix = saved == null ? "" : saved as Lang.String;
        if (
            !(
                prefix.equals("") ||
                prefix.equals("backup.a.") ||
                prefix.equals("backup.b.")
            )
        ) {
            throw new Lang.InvalidValueException("Invalid backup pointer");
        }
    }
    function get(key) {
        return raw.get(prefix + key);
    }
    function put(key, value) {
        raw.put(prefix + key, value);
    }
    function remove(key) {
        raw.remove(prefix + key);
    }
}

class WorkoutRestore {
    var raw as WorkoutStorage;
    var target as SelectedWorkoutStorage;
    var store as WorkoutStore;
    var header as Lang.Dictionary = {};
    var item as Lang.Dictionary = {};
    var buffer as Lang.Array = [];
    var current as Lang.Array = [];
    var offset = 0;
    var lastSet = 0;
    var lastReps = 0;
    var count = 0;
    var lastId = 0;
    var started = false;
    var complete = false;

    function initialize(backend as WorkoutStorage) {
        raw = backend;
        var active = new SelectedWorkoutStorage(raw, null);
        target = new SelectedWorkoutStorage(
            raw,
            active.prefix.equals("backup.a.") ? "backup.b." : "backup.a."
        );
        store = new WorkoutStore(target);
        // Discard only the inactive slot, including any interrupted staged workout.
        store.recover();
        var entries = store.before(store.nextId(), 1);
        while (entries.size() > 0) {
            store.deleteWorkout((entries[0] as Lang.Dictionary)["id"]);
            entries = store.before(store.nextId(), 1);
        }
        target.put(store.INDEX_KEY, store.emptyIndex(1, 0));
    }
    function require(ok) as Void {
        if (!ok) {
            throw new Lang.InvalidValueException(
                "Invalid or incomplete backup"
            );
        }
    }
    function number(value, minimum) as Void {
        require(value instanceof Lang.Number);
        require(value >= minimum);
    }
    function beginItem(value as Lang.Dictionary) as Void {
        number(value["reps"], 0);
        number(value["sets"], 0);
        number(value["rows"], 0);
        require(value["rows"] <= value["sets"]);
        item = value;
        offset = 0;
        lastSet = 0;
        lastReps = 0;
        buffer = [];
    }
    function finishItem() as Void {
        require(offset == item["rows"]);
        require(lastSet == item["sets"] && lastReps == item["reps"]);
        if (lastId == 0) {
            target.put("history", current);
            return;
        }
        if (buffer.size() > 0) {
            target.put(
                store.chunkKey(lastId, (offset - 1) / store.CHUNK_SIZE),
                buffer
            );
            buffer = [];
        }
        var index = store.readIndex();
        var summary = index["writing"] as Lang.Dictionary;
        store.putSummary(summary);
        index["writing"] = null;
        index["count"] = count;
        index["nextId"] = lastId + 1;
        target.put(store.INDEX_KEY, index);
    }
    function accept(record as Lang.Dictionary) as Void {
        require(!complete);
        var kind = record["kind"];
        require(kind instanceof Lang.String);
        if (!started) {
            require(
                kind.equals("header") &&
                    record["format"].equals("pullupcounter.backup") &&
                    record["version"] == 1
            );
            number(record["created"], 0);
            number(record["workouts"], 0);
            var settings = record["settings"] as Lang.Dictionary;
            number(settings["increment"], 1);
            number(settings["rest"], 1);
            require(settings["vibration"] instanceof Lang.Boolean);
            var mode = settings["mode"];
            if (mode == null) {
                mode = "fixedRest";
            }
            require(mode instanceof Lang.String);
            require(mode.equals("fixedRest") || mode.equals("fixedInterval"));
            target.put("workoutMode", mode);
            var goal = WorkoutGoal.validate(settings["goal"]);
            // Keep the target, but require an explicit fresh start after restoring.
            goal = {
                "enabled" => false,
                "reps" => goal["reps"],
                "seconds" => goal["seconds"],
            };
            target.put("workoutGoal", goal);
            target.put("goalStart", 0);
            header = record;
            beginItem(record["current"] as Lang.Dictionary);
            target.put("incrementAmount", settings["increment"]);
            target.put("restDuration", settings["rest"]);
            target.put("vibrationEnabled", settings["vibration"]);
            target.put("theme", AppTheme.normalize(settings["theme"]));
            target.put("pullUps", item["reps"]);
            target.put("totalSets", item["sets"]);
            // A restored workout resumes without an obsolete rest timer.
            target.put("restEndTime", 0);
            started = true;
            return;
        }
        if (kind.equals("workout")) {
            finishItem();
            number(record["id"], lastId + 1);
            number(record["start"], 0);
            number(record["end"], record["start"]);
            require(record["id"] < 2147483647);
            lastId = record["id"];
            count += 1;
            require(count <= header["workouts"]);
            beginItem(record);
            require(item["rows"] > 0 && item["reps"] > 0);
            var index = store.readIndex();
            index["writing"] = {
                "id" => lastId,
                "start" => item["start"],
                "end" => item["end"],
                "reps" => item["reps"],
                "sets" => item["sets"],
                "chunks" => (item["rows"] + 99) / 100,
            };
            target.put(store.INDEX_KEY, index);
        } else if (kind.equals("rows")) {
            require(record["id"] == lastId && record["offset"] == offset);
            var rows = record["rows"] as Lang.Array;
            require(
                rows.size() > 0 &&
                    rows.size() <= 25 &&
                    offset + rows.size() <= item["rows"]
            );
            for (var i = 0; i < rows.size(); i += 1) {
                var row = rows[i] as Lang.Array;
                require(row.size() == 5);
                for (var j = 0; j < 5; j += 1) {
                    number(row[j], j < 3 ? 1 : 0);
                }
                if (offset > 0) {
                    require(
                        row[0] == lastSet + 1 && row[1] == lastReps + row[2]
                    );
                }
                lastSet = row[0];
                lastReps = row[1];
                offset += 1;
                if (lastId == 0) {
                    current.add(AppData.decodeSet(row));
                } else {
                    buffer.add(row);
                    if (buffer.size() == 100) {
                        target.put(
                            store.chunkKey(lastId, (offset - 1) / 100),
                            buffer
                        );
                        buffer = [];
                    }
                }
            }
        } else if (kind.equals("end")) {
            finishItem();
            require(count == header["workouts"]);
            complete = true;
        } else {
            require(false);
        }
    }
    function commit() as Void {
        require(complete);
        // On failure the old prefix is still authoritative. Nothing is erased first.
        raw.put("backup.active.v1", target.prefix);
    }
}
