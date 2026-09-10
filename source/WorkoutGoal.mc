using Toybox.Lang;

module WorkoutGoal {
    function defaults() as Lang.Dictionary { return { "enabled" => false, "reps" => 1000, "seconds" => 10800 }; }
    function validate(value) as Lang.Dictionary {
        if (value == null) { return defaults(); }
        if (!(value instanceof Lang.Dictionary)) { throw new Lang.InvalidValueException("Invalid goal"); }
        if (!(value["enabled"] instanceof Lang.Boolean) || !(value["reps"] instanceof Lang.Number) ||
            !(value["seconds"] instanceof Lang.Number) || value["reps"] < 1 || value["reps"] > 99999 ||
            value["seconds"] < 1 || value["seconds"] > 86399) {
            throw new Lang.InvalidValueException("Invalid goal");
        }
        return value as Lang.Dictionary;
    }
    function sets(reps, increment) { return ((reps - 1) / increment).toNumber() + 1; }
    function interval(reps, seconds, increment) { return (seconds / sets(reps, increment)).toNumber(); }
    function status(goal as Lang.Dictionary, increment, start, now, reps) {
        if (start == 0) { return "GOAL " + goal["reps"].format("%d"); }
        if (reps >= goal["reps"]) { return "GOAL REACHED"; }
        var elapsed = now - start;
        if (elapsed >= goal["seconds"]) { return "TIME UP"; }
        if (elapsed < 0) { elapsed = 0; }
        var period = interval(goal["reps"], goal["seconds"], increment);
        var expected = (elapsed / period).toNumber() * increment;
        if (expected > goal["reps"]) { expected = goal["reps"]; }
        var difference = reps - expected;
        if (difference == 0) { return "ON PACE"; }
        return (difference > 0 ? difference : -difference).format("%d") + (difference > 0 ? " REPS AHEAD" : " REPS BEHIND");
    }
}
