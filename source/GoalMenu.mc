using Toybox.WatchUi;
using Toybox.Graphics;
using Toybox.Lang;

class GoalMenu extends WatchUi.Menu2 {
    var view;
    function initialize(view) {
        Menu2.initialize({ :title => "Goal / Pacing" });
        self.view = view;
        addItem(new WatchUi.MenuItem("Goal", null, :enabled, {}));
        addItem(new WatchUi.MenuItem("Target Reps", null, :target, {}));
        addItem(new WatchUi.MenuItem("Target Time", null, :duration, {}));
        addItem(new WatchUi.MenuItem("Required Pace", null, :pace, {}));
        refresh();
    }
    function refresh() as Void {
        var goal = view.workoutGoal as Lang.Dictionary;
        var seconds = goal["seconds"];
        updateItem(
            new WatchUi.MenuItem(
                "Goal",
                goal["enabled"] ? "On" : "Off",
                :enabled,
                {}
            ),
            0
        );
        updateItem(
            new WatchUi.MenuItem(
                "Target Reps",
                goal["reps"].format("%d"),
                :target,
                {}
            ),
            1
        );
        updateItem(
            new WatchUi.MenuItem(
                "Target Time",
                DurationText.format(seconds),
                :duration,
                {}
            ),
            2
        );
        var interval = WorkoutGoal.interval(
            goal["reps"],
            seconds,
            view.incrementAmount
        );
        var pace =
            interval < 1
                ? "Target too fast"
                : view.incrementAmount.format("%d") +
                  " reps / " +
                  interval.format("%d") +
                  "s";
        updateItem(new WatchUi.MenuItem("Required Pace", pace, :pace, {}), 3);
        if (view.settingsMenu != null) {
            view.settingsMenu.updateItem(
                new WatchUi.MenuItem(
                    "Goal / Pacing",
                    goal["enabled"] ? "On" : "Off",
                    :goal,
                    {}
                ),
                4
            );
            view.settingsMenu.updateItem(
                new WatchUi.MenuItem(
                    "Workout Mode",
                    view.modeLabel(),
                    :workoutMode,
                    {}
                ),
                0
            );
            var time =
                DurationText.format(view.restDuration);
            view.settingsMenu.updateItem(
                new WatchUi.MenuItem(
                    view.timerSettingLabel(),
                    time,
                    :restTime,
                    {}
                ),
                2
            );
        }
    }
    function apply(reps, seconds, enabled) as Void {
        var value = WorkoutGoal.validate({
            "reps" => reps,
            "seconds" => seconds,
            "enabled" => enabled,
        });
        var interval = WorkoutGoal.interval(
            reps,
            seconds,
            view.incrementAmount
        );
        if (enabled && interval < 1) {
            throw new Lang.InvalidValueException("Pace below one second");
        }
        // Disable first so interrupted multi-key preference changes remain readable.
        view.saveGoal({
            "reps" => reps,
            "seconds" => seconds,
            "enabled" => false,
        });
        view.stopTimer();
        if (enabled) {
            view.selectMode("fixedInterval");
            view.workoutStore.storage.put("restDuration", interval);
            view.restDuration = interval;
        }
        view.saveGoal(value);
        refresh();
    }
}

class GoalMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view;
    var menu;
    function initialize(view, menu) {
        Menu2InputDelegate.initialize();
        self.view = view;
        self.menu = menu;
    }
    function onSelect(item) as Void {
        var goal = view.workoutGoal as Lang.Dictionary;
        if (item.getId() == :pace) {
            var sets = WorkoutGoal.sets(goal["reps"], view.incrementAmount);
            workoutMessage(
                sets.format("%d") +
                    " sets / " +
                    (sets * view.incrementAmount).format("%d") +
                    " reps\nWhole-second intervals.\nFinish workout manually."
            );
            return;
        }
        if (item.getId() == :enabled && goal["enabled"]) {
            menu.apply(goal["reps"], goal["seconds"], false);
            return;
        }
        if (view.totalSets > 0 || view.restEndTime > 0) {
            workoutMessage(
                "Finish or reset workout\nbefore setting a new goal."
            );
            return;
        }
        if (item.getId() == :enabled) {
            if (
                WorkoutGoal.interval(
                    goal["reps"],
                    goal["seconds"],
                    view.incrementAmount
                ) < 1
            ) {
                workoutMessage("Target too fast.\nAllow at least 1s per set.");
                return;
            }
            menu.apply(goal["reps"], goal["seconds"], true);
        } else {
            var time = item.getId() == :duration;
            if (!time) {
                var editor = new GoalRepsEditor(menu, goal["reps"]);
                WatchUi.pushView(editor, new GoalRepsEditorDelegate(editor), WatchUi.SLIDE_LEFT);
                return;
            }
            var timeEditor = new DurationEditor(goal["seconds"], new GoalTimeSave(menu));
            WatchUi.pushView(timeEditor, new DurationEditorDelegate(timeEditor), WatchUi.SLIDE_LEFT);
        }
    }
}

module GoalEntryValue {
    function decode(time, values as Lang.Array) {
        if (time) { return values[0] * 3600 + values[2] * 60; }
        var value = 0;
        for (var i = 0; i < values.size(); i += 1) { value = value * 10 + values[i]; }
        return value;
    }
}
class GoalTimeSave {
    var menu;
    function initialize(menu) { self.menu = menu; }
    function save(seconds) {
        if (!DurationText.valid(seconds)) { return false; }
        var goal = menu.view.workoutGoal as Lang.Dictionary;
        if (goal["enabled"] && WorkoutGoal.interval(goal["reps"], seconds, menu.view.incrementAmount) < 1) {
            workoutMessage("Target too fast.\nAllow at least 1s per set."); return false;
        }
        menu.apply(goal["reps"], seconds, goal["enabled"]);
        return true;
    }
}
