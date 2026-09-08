import Toybox.Graphics;
import Toybox.WatchUi;
using Toybox.Application;
using Toybox.Lang;
using Toybox.Time;
using Toybox.Math;

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
    var numberFont;
    var timerFont;
    var labelFont;
    var footerFont;
    var workoutStore as WorkoutStore;
    var workoutReady = true;

    function initialize() {
        View.initialize();

        workoutStore = new WorkoutStore(new WorkoutStorage());
        numberFont = WatchUi.loadResource(Rez.Fonts.RepNumber);
        timerFont = WatchUi.loadResource(Rez.Fonts.RepTimer);
        labelFont = WatchUi.loadResource(Rez.Fonts.RepLabel);
        footerFont = WatchUi.loadResource(Rez.Fonts.RepFooter);
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

        var x = dc.getWidth() / 2;
        var y = dc.getHeight() / 2;
        var radius = x - 23;
        var cyan = 0x00dce5;
        dc.setColor(0x586467, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawCircle(x, y, x - 6);
        // The track runs from bottom-left over the top to bottom-right.
        var ringStart = 240;
        var ringSweep = 300;
        roundedRestArc(dc, x, y, radius, ringStart, ringSweep, 0x202b2d);
        if (restSeconds > 0 && restDuration > 0) {
            var sweep = (restSeconds.toFloat() / restDuration) * ringSweep;
            if (sweep > ringSweep) {
                sweep = ringSweep;
            }
            // Clear elapsed time from the left, keeping the cyan end at bottom-right.
            var countdownStart = ringStart - (ringSweep - sweep);
            roundedRestArc(dc, x, y, radius, countdownStart, sweep, cyan);
        }
        var align = Graphics.TEXT_JUSTIFY_CENTER;
        dc.setColor(cyan, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, 68, labelFont, "REPS", align);
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        var text = pullUps.format("%d");
        var font = numberFont;
        if (dc.getTextWidthInPixels(text, font) > dc.getWidth() - 100) {
            font = timerFont;
        }
        if (dc.getTextWidthInPixels(text, font) > dc.getWidth() - 100) {
            font = labelFont;
        }
        dc.drawText(
            x,
            102 + (116 - dc.getFontHeight(font)) / 2,
            font,
            text,
            align
        );
        dc.setColor(cyan, Graphics.COLOR_TRANSPARENT);
        dc.drawText(x, 232, labelFont, "SET " + totalSets.format("%d"), align);
        if (restSeconds > 0) {
            var timer =
                (restSeconds / 60).format("%02d") +
                ":" +
                (restSeconds % 60).format("%02d");
            var restFont = timerFont;
            if (
                dc.getTextWidthInPixels(timer, restFont) >
                dc.getWidth() - 100
            ) {
                restFont = labelFont;
            }
            dc.drawText(x, 260, restFont, timer, align);
            dc.drawText(x, 311, labelFont, "REST", align);
        } else {
            dc.drawText(x, 280, labelFont, "READY", align);
        }
        dc.setColor(0xaaaaaa, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            x,
            344,
            footerFont,
            "+" +
                incrementAmount.format("%d") +
                " / " +
                restDuration.format("%d") +
                "s REST",
            align
        );
    }

    function roundedRestArc(dc, x, y, radius, start, sweep, color) as Void {
        dc.setColor(color, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(13);
        dc.drawArc(
            x,
            y,
            radius,
            Graphics.ARC_CLOCKWISE,
            start,
            (start - sweep + 360).toNumber() % 360
        );
        var startRadians = (start * Math.PI) / 180;
        dc.fillCircle(
            x + radius * Math.cos(startRadians),
            y - radius * Math.sin(startRadians),
            6
        );
        var radians = ((start - sweep) * Math.PI) / 180;
        dc.fillCircle(
            x + radius * Math.cos(radians),
            y - radius * Math.sin(radians),
            6
        );
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
