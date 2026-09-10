# Rep Counter

A Garmin Connect IQ workout counter for the Forerunner 165 Music. Originally built for pull-ups, it can track other repetition-based exercises with configurable increments, rest timers, and vibration alerts.

The goal is to make workouts easy to track on the watch and keep a lasting record of progress. An unfinished workout resumes until explicitly finished, and completed workouts remain available in a scrollable history.

- Count reps and sets with a clear display and rest countdown.
- Browse or delete completed workouts.
- Export JSON backups and CSV reports, and restore JSON backups through the companion website.

## Workout modes

Choose a mode in Menu → Workout Settings → Workout Mode.

- **Fixed Rest:** press START after each completed set to record it and start the rest timer.
- **Fixed Interval (EMOM):** the first START begins the schedule without recording a set. Press START after completing each set; the countdown keeps its original schedule and vibrates at each boundary when vibration is enabled. Missed intervals never add sets automatically.

The timer setting shows Rest Time or Interval for the selected mode. Changing mode or interval stops the timer; START begins a fresh schedule. Completed sets stay recorded. DOWN undoes a set, or cancels a running interval before the first set. Finish Workout and Reset Workout stop the schedule.

An interval schedule resumes on reopening the app. Alerts run while the app is open; missed alerts are not replayed. JSON backups preserve the mode; restores keep timers stopped until you start again.

## Goal / Pacing

Before starting a workout, open Workout Settings > Goal / Pacing, set Target Reps and Target Time, review Required Pace, then turn Goal on. For example, 1,000 reps in 3 hours at 5 reps per set gives 200 sets at 54-second intervals.

Goal uses Fixed Interval. START begins the clock without recording a set; subsequent presses record completed sets. The screen shows ON PACE, reps ahead/behind, GOAL REACHED, or TIME UP. Reaching a target or deadline never finishes the workout automatically.

New targets support 1–9,999 reps and 1 second–23:59:59. Older saved rep targets remain readable. Sets round up to a whole set; intervals round down to whole seconds to meet the deadline. Targets requiring less than one second per set are rejected. Required Pace shows the resulting full-set total when selected.

Turn Goal off to change workout mode, reps per set, or the timer. Turning it off stops the timer and preserves recorded sets. Set up a new goal after finishing/resetting the current workout. Goal targets are saved in JSON backups; restored goals remain off. Past workout rows retain their existing format and do not store goal results.

Target Time, Rest Time, and Interval share an H:MM:SS editor. UP/DOWN adjusts the highlighted field; START advances and saves after seconds. BACK moves to the previous field or cancels from hours. Touch a field to select it, tap the upper/lower value to adjust, or tap the green check to save. Zero time is rejected. Editing a running Fixed Rest changes the next rest; changing an Interval stops the schedule until START.

## Development

Build `monkey.jungle` with the Garmin Connect IQ SDK for `fr165m`, using your own developer signing key. `tests.jungle` contains the watch regression tests.

The companion service is in `backup-web/`. With Node.js 22.13+ and pnpm installed, run `pnpm install` and `pnpm dev` there. See [Cloudflare setup](backup-web/CLOUDFLARE.md) for deployment and [data schema](DATA_SCHEMA.md) for storage details.

