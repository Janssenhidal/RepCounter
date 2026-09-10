using Toybox.Lang;
using Toybox.Time;

// Transport-neutral records. No Garmin storage keys or dictionary internals escape.
// Call while the workout UI is paused; one call returns at most 25 set rows.
class WorkoutBackup {
    const ROWS = 25;
    var store as WorkoutStore;
    var phase = 0;
    var cursor = 0;
    var summary as Lang.Dictionary = {};
    var offset = 0;
    var rowCount = 0;
    var active as Lang.Array;

    function initialize(source as WorkoutStore) {
        store = source;
        store.recover();
        var value = store.storage.get("history");
        active = value == null ? [] : value as Lang.Array;
    }

    function setting(key, fallback) {
        var value = store.storage.get(key);
        return value == null ? fallback : value;
    }

    function next() as Lang.Dictionary or Null {
        if (phase == 0) {
            phase = 1;
            return { "kind" => "header", "format" => "pullupcounter.backup", "version" => 1,
                "created" => Time.now().value(), "workouts" => store.count(),
                "settings" => { "increment" => setting("incrementAmount", 2),
                    "rest" => setting("restDuration", 45), "vibration" => setting("vibrationEnabled", true),
                    "theme" => AppTheme.normalize(store.storage.get("theme")),
                    "mode" => setting("workoutMode", "fixedRest"),
                    "goal" => WorkoutGoal.validate(store.storage.get("workoutGoal")) },
                "current" => { "reps" => setting("pullUps", 0), "sets" => setting("totalSets", 0),
                    "rows" => active.size() } };
        }
        if (phase == 1) {
            if (offset < active.size()) {
                var rows = [];
                var start = offset;
                while (offset < active.size() && rows.size() < ROWS) {
                    var entry = active[offset] as Lang.Dictionary;
                    rows.add(AppData.encodeSet(entry));
                    offset += 1;
                }
                return { "kind" => "rows", "id" => 0, "offset" => start, "rows" => rows };
            }
            phase = 2;
        }
        if (phase == 2) {
            var entries = store.after(cursor, 1);
            if (entries.size() == 0) { phase = 4; return { "kind" => "end" }; }
            summary = entries[0] as Lang.Dictionary;
            cursor = summary["id"];
            offset = 0;
            // Actual retained row count is distinct from the lifetime set total.
            var tail = store.storage.get(store.chunkKey(cursor, summary["chunks"] - 1)) as Lang.Array;
            rowCount = (summary["chunks"] - 1) * store.CHUNK_SIZE + tail.size();
            phase = 3;
            return { "kind" => "workout", "id" => cursor, "start" => summary["start"],
                "end" => summary["end"], "reps" => summary["reps"], "sets" => summary["sets"], "rows" => rowCount };
        }
        if (phase == 3) {
            var chunk = store.storage.get(store.chunkKey(cursor, offset / store.CHUNK_SIZE)) as Lang.Array;
            var start = offset;
            var rows = [];
            while (offset < rowCount && rows.size() < ROWS) {
                rows.add(chunk[offset % store.CHUNK_SIZE]);
                offset += 1;
            }
            if (offset == rowCount) { phase = 2; }
            return { "kind" => "rows", "id" => cursor, "offset" => start, "rows" => rows };
        }
        return null;
    }
}


