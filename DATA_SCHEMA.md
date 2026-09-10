# App data schema

AppData.mc is the shared boundary for reading preferences and the active session,
and for converting set records between named fields and compact storage rows.
SCHEMA_VERSION = 1 describes this logical model, not a new on-disk format.

- preferences: increment (default 2), rest in seconds (45), vibration (true), mode (fixedRest by default).
- session: currentCounter, totalSets, restEndTime (epoch seconds), sets[].
- set: setNumber, counter (cumulative reps), increment (reps added), rest
  (seconds), timestamp (epoch seconds).
- completed history: WorkoutStore pages of workout summaries, each referring to
  chunks of sets. Summaries contain id, start, end, reps, sets, and chunks.

Current totals belong to the session. There is no separately stored global
statistics cache: adding one would require transactional updates for finish,
delete, migration, and restore. Completed-workout statistics can be derived from
paged summaries when a feature needs them. Empty sessions remain hidden.

Compatibility

Existing preference and session keys remain unchanged. Completed history retains
its v2 paged index and compact v1 set chunks. Portable JSON remains backup format
v1, including the established row order:
[setNumber, counter, increment, rest, timestamp]. CSV export is unchanged.

The logical schema is deliberately not one giant serialized AppData object.
Workout history remains paged so it does not grow past a single storage value's
size limit or require loading the entire archive into watch memory.

The optional workoutMode storage key is fixedRest or fixedInterval. Missing keys
and old backups default to fixedRest. Portable v1 headers include an optional
settings.mode; the existing service retains this field without a deployment.
restEndTime is the next interval boundary in interval mode. Boundaries advance
by whole configured intervals, including after reopening, without adding sets.
Changing mode/interval clears the timer; finish/reset and restores also clear it.
The set row's rest field remains the configured duration in seconds; historical
rows do not record a mode and their existing display/CSV format is unchanged.

No migration or data rewrite is needed for this change. Future storage or
transport version changes must have explicit migration/compatibility tests.
Existing restore validation and atomic namespace selection remain in place.

Validation: 19 Garmin simulator tests passed, including legacy data, interrupted
finish/delete/migration/restore, more than 100 workouts, portable backup round
trips, and read-only schema loading. Visual inspection used a separate app ID
and synthetic sets; it did not send watch data to the backup service.

Goal / Pacing

workoutGoal is an optional dictionary: enabled (false by default), reps (1..99999),
seconds (1..86399). Defaults are 1000 reps in 10800 seconds, disabled. goalStart
is an optional epoch second (0 when stopped); the active schedule and goal start
resume across app restarts. Finish/reset clear goalStart along with the timer.
Goal setup requires an empty, stopped workout; disabling preserves recorded sets.
Goal pace is floor(seconds / ceil(reps / increment)), minimum 1 second per set.
The status compares completed reps with sets due on that schedule.
Portable backup v1 settings optionally include goal. Restore validates its target
and disables it, clearing goalStart. Missing fields use disabled defaults.
Archive row format and CSV remain unchanged; historical goal results are not stored.

The shared time editor accepts 1..86399 seconds for goal duration, rest, and interval.
These use the existing integer-second storage and backup fields; no migration is required.
