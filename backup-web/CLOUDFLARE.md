# Cloudflare backup service

Live webpage: https://backup.execureach.co/
API: https://backup.execureach.co/api/transfer
Worker: garmin-backup
Alternative URL: https://garmin-backup.janssen-schembri.workers.dev

## Deploy future webpage/service changes

From backup-web:

    pnpm exec wrangler login
    pnpm install
    pnpm test
    pnpm build
    pnpm exec wrangler deploy --config dist/server/wrangler.json

The login is only needed when not already signed in. Deploy the generated
configuration after building, rather than deploying the unbuilt source directly.
The custom domain and SQLite Durable Object binding are in wrangler.jsonc.
Keep the existing migration tag and class name when making ordinary updates.
Changing the watch app requires a separate Connect IQ build/update.

## Storage

Each transfer uses a separate Durable Object with SQLite-backed records and
metadata. The pairing token, export, staged restore and completion state survive
Worker instance changes. Record writes and metadata updates are transactional.
Pairing attempts are rate limited per IP address. Hashes used for those limits
expire after a minute. Transfer codes are random and browser claims are one-use.
Transfers are inaccessible after 15 minutes. A Durable Object alarm removes
active storage; Cloudflare platform recovery copies may remain under its
retention policies. Downloaded files are the user's long-term backup.

The webpage and the watch use the same protocol as local testing. The local
server now uses local Durable Object storage instead of the old memory-only
route. Restarting a local server does not necessarily clear its transfer data;
expiry still applies. Local development binds to 127.0.0.1:3000.

## Validation performed

- TypeScript, authored-code lint and build passed.
- Five service/persistence tests passed, including reopening storage in a fresh
  instance for each request and rolling back an injected disk-write failure.
- Built Worker passed a local HTTP backup/restore test.
- Live custom-domain API passed the same synthetic-data test. The test transfer
  was closed afterward. No real watch workouts were uploaded by these tests.
- Homepage returns the backup interface instead of the previous Hello World app.

A physical Garmin watch/phone test and actual Connect IQ Store update testing
remain separate checks. No watch installation was performed during deployment.
