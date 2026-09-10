using Toybox.WatchUi;
using Toybox.Application;

class PullUpCounterMenuDelegate extends WatchUi.Menu2InputDelegate {
    var view;

    function initialize(view) {
        Menu2InputDelegate.initialize();
        self.view = view;
    }

    function onSelect(item) as Void {
        if (
            item.getId() != :backup &&
            item.getId() != :data &&
            !view.ensureWorkoutReady()
        ) {
            return;
        }
        if (
            (view.workoutGoal as Toybox.Lang.Dictionary)["enabled"] &&
            (item.getId() == :workoutMode ||
                item.getId() == :increment ||
                item.getId() == :restTime)
        ) {
            workoutMessage("Turn off Goal / Pacing\nto change these settings.");
            return;
        }
        if (item.getId() == :goal) {
            var goalMenu = new GoalMenu(view);
            WatchUi.pushView(
                goalMenu,
                new GoalMenuDelegate(view, goalMenu),
                WatchUi.SLIDE_LEFT
            );
        } else if (item.getId() == :workoutSettings) {
            var menu = new WatchUi.Menu2({ :title => "Workout Settings" });
            menu.addItem(
                new WatchUi.MenuItem(
                    "Workout Mode",
                    view.modeLabel(),
                    :workoutMode,
                    {}
                )
            );
            menu.addItem(
                new WatchUi.MenuItem(
                    "Reps per Set",
                    view.incrementAmount.format("%d"),
                    :increment,
                    {}
                )
            );
            var restText = DurationText.format(view.restDuration);
            menu.addItem(
                new WatchUi.MenuItem(
                    view.timerSettingLabel(),
                    restText,
                    :restTime,
                    {}
                )
            );
            if (view.isInterval()) {
                menu.addItem(
                    new WatchUi.MenuItem(
                        "Goal / Pacing",
                        (view.workoutGoal as Toybox.Lang.Dictionary)["enabled"]
                            ? "On"
                            : "Off",
                        :goal,
                        {}
                    )
                );
            }
            if (view.totalSets >= 1) {
                menu.addItem(
                    new WatchUi.MenuItem(
                        "Reset Workout",
                        null,
                        :resetCounter,
                        {}
                    )
                );
            }
            // Setting pickers update this submenu when returning from a selection.
            view.settingsMenu = menu;
            WatchUi.pushView(
                menu,
                new PullUpCounterMenuDelegate(view),
                WatchUi.SLIDE_LEFT
            );
        } else if (item.getId() == :general) {
            var menu = new WatchUi.Menu2({:title => "General"});
            menu.addItem(new WatchUi.MenuItem("Vibration", view.vibrationEnabled ? "On" : "Off", :vibration, {}));
            menu.addItem(new WatchUi.MenuItem("Theme", AppTheme.label(), :theme, {}));
            WatchUi.pushView(menu, new GeneralMenuDelegate(view, menu), WatchUi.SLIDE_LEFT);
        } else if (item.getId() == :data) {
            var menu = new WatchUi.Menu2({ :title => "Data" });
            menu.addItem(
                new WatchUi.MenuItem("Backup / Export", null, :backup, {})
            );
            WatchUi.pushView(
                menu,
                new PullUpCounterMenuDelegate(view),
                WatchUi.SLIDE_LEFT
            );
        } else if (item.getId() == :backup) {
            if (BackupConfig.URL.equals("")) {
                workoutMessage("Backup service\nnot configured yet.");
                return;
            }
            try {
                var transfer = new BackupTransfer(view);
                WatchUi.pushView(
                    transfer,
                    new BackupTransferDelegate(transfer),
                    WatchUi.SLIDE_UP
                );
            } catch (error) {
                workoutMessage("Cannot start backup.");
            }
        } else if (item.getId() == :workoutMode) {
            var menu = new WatchUi.Menu2({ :title => "Workout Mode" });
            menu.addItem(
                new WatchUi.MenuItem("Fixed Rest", null, :fixedRest, {})
            );
            menu.addItem(
                new WatchUi.MenuItem(
                    "Fixed Interval",
                    "EMOM",
                    :fixedInterval,
                    {}
                )
            );
            WatchUi.pushView(
                menu,
                new WorkoutModeMenuDelegate(view),
                WatchUi.SLIDE_LEFT
            );
        } else if (item.getId() == :increment) {
            var editor = new RepsEditor(
                "REPS PER SET",
                view.incrementAmount,
                2,
                new IncrementMenuDelegate(view, view.settingsMenu)
            );
            WatchUi.pushView(
                editor,
                new RepsEditorDelegate(editor),
                WatchUi.SLIDE_LEFT
            );
        } else if (item.getId() == :restTime) {
            var editor = new DurationEditor(
                view.restDuration,
                new RestTimeMenuDelegate(view, view.settingsMenu)
            );
            if (!view.isInterval()) {
                editor.useMinutes();
            }
            WatchUi.pushView(
                editor,
                new DurationEditorDelegate(editor),
                WatchUi.SLIDE_LEFT
            );
        } else if (item.getId() == :history) {
            if (!view.ensureWorkoutReady()) {
                return;
            }
            try {
                var historyMenu = new WorkoutHistoryMenu(view);
                WatchUi.pushView(
                    historyMenu,
                    new WorkoutHistoryMenuDelegate(historyMenu),
                    WatchUi.SLIDE_LEFT
                );
            } catch (error) {
                workoutMessage("Cannot open history.\nPlease try again.");
            }
        } else if (item.getId() == :finishWorkout) {
            if (view.finishWorkout()) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
            }
        } else if (item.getId() == :resetCounter) {
            view.resetCounter();

            // Return to the counter so the next menu reflects the empty workout.
            WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
            WatchUi.popView(WatchUi.SLIDE_DOWN);
        }
    }
}
