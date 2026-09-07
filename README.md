# Rep Counter

A Garmin Connect IQ workout counter for the Forerunner 165 Music. Originally built for pull-ups, it can track other repetition-based exercises with configurable increments, rest timers, and vibration alerts.

The goal is to make workouts easy to track on the watch and keep a lasting record of progress. An unfinished workout resumes until explicitly finished, and completed workouts remain available in a scrollable history.

- Count reps and sets with a clear display and rest countdown.
- Browse or delete completed workouts.
- Export JSON backups and CSV reports, and restore JSON backups through the companion website.

## Development

Build `monkey.jungle` with the Garmin Connect IQ SDK for `fr165m`, using your own developer signing key. `tests.jungle` contains the watch regression tests.

The companion service is in `backup-web/`. With Node.js 22.13+ and pnpm installed, run `pnpm install` and `pnpm dev` there. See [Cloudflare setup](backup-web/CLOUDFLARE.md) for deployment and [data schema](DATA_SCHEMA.md) for storage details.

