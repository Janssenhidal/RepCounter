import Toybox.Graphics;
import Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;

class PullUpCounterView extends WatchUi.View {
    var pullUps = 0;
    var restSeconds = 0;
    var incrementAmount = 2;
    var restDuration = 45;
    var settingsMenu = null;
    var restEndTime = 0;
    var history as Lang.Array = [];
    var totalSets = 0;
    var vibrationEnabled = true;
    var background;
    var workoutStore as WorkoutStore;
    var workoutReady = true;

    function initialize() {
        View.initialize();

        workoutStore = new WorkoutStore(new WorkoutStorage());
        background = WatchUi.loadResource(Rez.Drawables.background);
        workoutReady = false;
        try {
            workoutStore = new WorkoutStore(
                new SelectedWorkoutStorage(new WorkoutStorage(), null)
            );
            workoutStore.recover();
            reloadSettings();
            reloadCurrentWorkout();
            workoutReady = true;
        } catch (error) {
            // Keep existing storage untouched and block edits until reads recover.
            workoutReady = false;
        }
    }

    function reloadSettings() as Void {
        var preferences = AppData.preferences(workoutStore.storage);
        incrementAmount = preferences["increment"];
        restDuration = preferences["rest"];
        vibrationEnabled = preferences["vibration"];
    }
    function onLayout(dc as Dc) as Void {}

    function onShow() as Void {}

    function onUpdate(dc) as Void {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();

        dc.drawBitmap(0, 0, background);
        if (!workoutReady) {
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 - 30,
                Graphics.FONT_SMALL,
                "Data unavailable",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            dc.drawText(
                dc.getWidth() / 2,
                dc.getHeight() / 2 + 8,
                Graphics.FONT_XTINY,
                "Press START to retry",
                Graphics.TEXT_JUSTIFY_CENTER
            );
            return;
        }

        var centerX = dc.getWidth() / 2;
        var centerY = dc.getHeight() / 2;
        var cyan = 0x40d6d6;
        var align = Graphics.TEXT_JUSTIFY_CENTER;
        dc.setColor(cyan, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, 35, Graphics.FONT_XTINY, "REPS", align);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var countText = pullUps.format("%d");
        var countFont = Graphics.FONT_NUMBER_HOT;
        if (
            dc.getTextWidthInPixels(countText, countFont) >
            dc.getWidth() - 80
        ) {
            countFont = Graphics.FONT_NUMBER_MEDIUM;
        }
        dc.drawText(centerX, 75, countFont, countText, align);
        dc.setColor(cyan, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            centerX,
            197,
            Graphics.FONT_XTINY,
            "SET " + totalSets.format("%d"),
            align
        );

        // Dim track remains visible; the cyan arc counts down during rest.
        dc.setPenWidth(4);
        dc.setColor(0x123838, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(centerX, centerY, centerX - 8);
        dc.setColor(cyan, Graphics.COLOR_TRANSPARENT);
        if (restSeconds > 0) {
            var progress = (restSeconds * 359) / restDuration;
            if (progress > 359) {
                progress = 359;
            }
            dc.drawArc(
                centerX,
                centerY,
                centerX - 8,
                Graphics.ARC_CLOCKWISE,
                90,
                90 - progress
            );
            var timerText =
                (restSeconds / 60).format("%02d") +
                ":" +
                (restSeconds % 60).format("%02d");
            dc.drawText(centerX, 232, Graphics.FONT_LARGE, timerText, align);
            dc.drawText(centerX, 279, Graphics.FONT_XTINY, "REST", align);
        } else {
            dc.drawText(centerX, 240, Graphics.FONT_MEDIUM, "READY", align);
        }
        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var settingsText =
            "+" +
            incrementAmount.format("%d") +
            " / " +
            restDuration.format("%d") +
            "s REST";
        dc.drawText(centerX, 322, Graphics.FONT_XTINY, settingsText, align);
    }
    function onHide() as Void {}

    function addPullUps() as Void {
        if (!ensureWorkoutReady()) {
            return;
        }
        pullUps += incrementAmount;
        restSeconds = restDuration;

        restEndTime = Time.now().value() + restDuration;

        totalSets += 1;

        var setEntry = {
            "setNumber" => totalSets,
            "counter" => pullUps,
            "increment" => incrementAmount,
            "rest" => restDuration,
            "timestamp" => Time.now().value(),
        };

        history.add(setEntry);

        // Keep only the latest 500 sets
        if (history.size() > 500) {
            history.remove(0);
        }

        workoutStore.storage.put("totalSets", totalSets);

        workoutStore.storage.put("pullUps", pullUps);

        workoutStore.storage.put("restEndTime", restEndTime);

        workoutStore.storage.put("history", history);

        WatchUi.requestUpdate();
    }

    function undoPullUps() as Void {
        if (!ensureWorkoutReady()) {
            return;
        }
        if (history.size() > 0) {
            // Remove the latest history entry
            history = history.slice(0, history.size() - 1);

            totalSets -= 1;

            if (totalSets < 0) {
                totalSets = 0;
            }

            // Restore the counter to the previous recorded total
            if (history.size() > 0) {
                var lastEntry = history[history.size() - 1] as Lang.Dictionary;

                pullUps = lastEntry["counter"];
            } else {
                pullUps = 0;
            }

            workoutStore.storage.put("pullUps", pullUps);

            workoutStore.storage.put("totalSets", totalSets);

            workoutStore.storage.put("history", history);

            WatchUi.requestUpdate();
        }
    }

    function resetCounter() as Void {
        if (!ensureWorkoutReady()) {
            return;
        }
        pullUps = 0;
        restSeconds = 0;
        restEndTime = 0;
        totalSets = 0;
        history = [];

        workoutStore.storage.put("pullUps", pullUps);

        workoutStore.storage.put("restEndTime", 0);

        workoutStore.storage.put("totalSets", 0);

        workoutStore.storage.put("history", history);

        WatchUi.requestUpdate();
    }

    function tick() as Void {
        if (!workoutReady) {
            return;
        }
        if (restEndTime > 0) {
            var remaining = restEndTime - Time.now().value();

            if (remaining > 0) {
                restSeconds = remaining;
            } else {
                restSeconds = 0;
                restEndTime = 0;

                workoutStore.storage.put("restEndTime", 0);
            }

            WatchUi.requestUpdate();
        }
    }

    function reloadCurrentWorkout() as Void {
        var saved = AppData.session(workoutStore.storage);
        history = saved["sets"] as Lang.Array;
        pullUps = saved["currentCounter"];
        totalSets = saved["totalSets"];
        restEndTime = saved["restEndTime"];
        restSeconds = restEndTime - Time.now().value();
        if (restSeconds < 0) {
            restSeconds = 0;
        }
        WatchUi.requestUpdate();
    }

    function ensureWorkoutReady() as Lang.Boolean {
        if (workoutReady) {
            return true;
        }
        try {
            workoutStore = new WorkoutStore(
                new SelectedWorkoutStorage(new WorkoutStorage(), null)
            );
            workoutStore.recover();
            reloadSettings();
            reloadCurrentWorkout();
            workoutReady = true;
            return true;
        } catch (error) {
            workoutMessage("History unavailable.\nPlease reopen the app.");
            return false;
        }
    }

    function finishWorkout() as Lang.Boolean {
        if (!ensureWorkoutReady()) {
            return false;
        }
        if (history.size() == 0 || totalSets <= 0 || pullUps <= 0) {
            workoutMessage("No sets to finish.");
            return false;
        }
        try {
            workoutStore.finish(history, pullUps, totalSets);
            reloadCurrentWorkout();
            return true;
        } catch (error) {
            // Recover before allowing more sets, to avoid duplicating a committed workout.
            workoutReady = false;
            try {
                workoutStore.recover();
                reloadCurrentWorkout();
                workoutReady = true;
                if (history.size() == 0) {
                    return true;
                }
            } catch (recoveryError) {}
            workoutMessage(
                "Could not finish.\nCheck History and retry.\nIf full, delete old workouts."
            );
            return false;
        }
    }
}
