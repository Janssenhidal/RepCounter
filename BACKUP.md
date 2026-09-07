> Updated 7 September 2026: the companion is deployed at
> https://backup.execureach.co/ and the watch is configured for its HTTPS API.
> See backup-web/CLOUDFLARE.md for current deployment/storage instructions.
> The local-only and memory-only descriptions below document the earlier
> prototype and are superseded by that deployment guide.
# Wireless backup prototype

Status: local development only. No service is deployed and the default watch
service address is intentionally empty. Settings > Backup / Export explains
that the service is not configured until an address is supplied.

## What is implemented

- Watch export streams a version-1 JSON record sequence: header, current set
  rows, completed workout summaries and rows, then an end marker. Each row
  record contains at most 25 sets. The current workout and settings are included.
- The companion webpage pairs using the watch's temporary code, downloads a
  validated backup or CSV, and accepts a backup for restoration.
- Restore requires confirmation on the watch. It writes into an inactive
  storage namespace, validates records and totals, and selects the replacement
  with one final pointer write. Failed/cancelled transfers do not select the
  staged data. Repeating a restore cleans the inactive slot first.
- Normal startup continues to use the original legacy keys until the first
  successful portable restore. Settings and workout writes then use the selected
  namespace. Keep this selection behavior in all future releases.
- Startup storage read errors display Data unavailable and block editing rather
  than presenting editable zero totals. This does not establish the cause of the
  earlier physical-watch crash, and cannot prevent firmware-level data resets.

## Run the local companion

In backup-web, with Node >=22.13 and pnpm installed:

    pnpm install
    pnpm dev

Open the Local URL printed by the server (tested: http://localhost:3000).
For simulator network testing, set BackupConfig.URL in source/BackupTransfer.mc
to http://localhost:3000/api/transfer and rebuild for fr165m. Keep that change
out of watch-release builds. The physical watch cannot reach this computer
through a phone using localhost. A reachable HTTPS endpoint is required there.

On the watch/simulator: Settings > Backup / Export. Enter the displayed code
on the webpage. After export completes, download the backup or CSV. To restore,
select the JSON backup on the webpage, send it for review, then use MENU on the
watch and choose Replace. BACK cancels an unfinished transfer.

## Data and limits

- Restoring replaces history and settings; it does not merge workouts. Rest
  timers are reset to zero on restore. Set timestamps are preserved.
- CSV contains one row per retained set, including the active workout, with
  explicitly UTC dates in DD/MM/YYYY format. JSON is required for restoration.
- This format cannot import Garmin DAT/IDX/IMT files. Keep raw snapshots separate.
- Staging needs space for both existing and incoming data. Storage-full errors
  keep the original selection. The previous namespace is retained; the next
  restore reuses the inactive a/b slot. Original legacy keys remain on disk.
- Local service sessions expire after 15 minutes and are removed on subsequent
  requests, or immediately when the process exits. No server files are written.
  The prototype accepts at most 32 sessions and 10 MB per upload/export.
- Browser refresh loses its pairing token; start a new watch transfer to reconnect.
- Do not expose this local prototype publicly: shared expiring storage, production
  HTTPS, deployment-wide rate limits and privacy documentation are still needed.

## Verification

- 18 Garmin simulator tests passed: legacy history/migration, export, repeated
  restore, injected interrupted-write failures and invalid startup data.
- Local service unit tests cover authentication, sequence/retry, CSV, invalid
  backups, expiry and rate limits. HTTP smoke test uses synthetic records.
- Companion build, TypeScript check and lint for app/lib/tests pass. Unused
  scaffold UI components are excluded from the project's lint command.
- Physical-watch wireless transfer, phone compatibility and an actual Connect IQ
  Store update are not yet tested. No code or data was installed on the watch.

Service tests: pnpm test. HTTP integration: node tests/http-smoke.mjs with the
local server running. Garmin tests: compile tests.jungle with -t for fr165m,
then run the resulting test PRG using the SDK's monkeydo test runner.

Always retain the manifest app ID, signing key and PRG filename across updates.
Downgrading to a build without selected-namespace support after a portable
restore can show stale legacy data; it is not a supported recovery operation.


