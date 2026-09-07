using Toybox.Lang;

// Logical schema only: do not serialize the entire archive into one storage value.
// Disk keys and portable backup v1 remain compatible with existing installations.
module AppData {
    const SCHEMA_VERSION = 1;

    function preferences(backend as WorkoutStorage) as Lang.Dictionary {
        var increment = backend.get("incrementAmount");
        var rest = backend.get("restDuration");
        var vibration = backend.get("vibrationEnabled");
        if (increment == null) { increment = 2; }
        if (rest == null) { rest = 45; }
        if (vibration == null) { vibration = true; }
        if (!(increment instanceof Lang.Number) || increment <= 0 ||
            !(rest instanceof Lang.Number) || rest <= 0 ||
            !(vibration instanceof Lang.Boolean)) {
            throw new Lang.InvalidValueException("Invalid preferences");
        }
        return { "increment" => increment, "rest" => rest, "vibration" => vibration };
    }

    function session(backend as WorkoutStorage) as Lang.Dictionary {
        var saved = readWorkoutState(backend);
        return { "currentCounter" => saved["pullUps"], "totalSets" => saved["totalSets"],
            "restEndTime" => saved["restEndTime"], "sets" => saved["history"] };
    }

    // Stable compact row order shared by archive storage and portable backups.
    function encodeSet(entry as Lang.Dictionary) as Lang.Array {
        return [entry["setNumber"], entry["counter"], entry["increment"], entry["rest"], entry["timestamp"]];
    }
    function decodeSet(row as Lang.Array) as Lang.Dictionary {
        return { "setNumber" => row[0], "counter" => row[1], "increment" => row[2],
            "rest" => row[3], "timestamp" => row[4] };
    }
}
