'use client';
import { useCallback, useEffect, useState } from 'react';
import { validateBackup, csv } from '../lib/backup.mjs';

type Reply = {
  error?: string;
  token: string;
  filename: string;
  content: string;
  complete: boolean;
  records: number;
  restoreReady: boolean;
  restored: boolean;
};
export default function Home() {
  const [code, setCode] = useState('');
  const [token, setToken] = useState('');
  const [status, setStatus] = useState({
    complete: false,
    records: 0,
    restoreReady: false,
    restored: false,
  });
  const [message, setMessage] = useState('');
  const [busy, setBusy] = useState(false);
  const [backup, setBackup] = useState<unknown[] | null>(null);
  const [summary, setSummary] = useState<{
    workouts: number;
    currentSets: number;
    completedSets: number;
  } | null>(null);
  const api = useCallback(
    async (action: string, extra: Record<string, unknown> = {}) => {
      const response = await fetch('/api/transfer', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          action,
          code: code.replace(/\s/g, '').toUpperCase(),
          token,
          ...extra,
        }),
      });
      const data = (await response.json()) as Reply;
      if (!response.ok) throw Error(data.error || 'Transfer failed.');
      return data;
    },
    [code, token],
  );
  async function run(fn: () => Promise<void>) {
    setBusy(true);
    setMessage('');
    try {
      await fn();
    } catch (error) {
      setMessage(
        error instanceof Error ? error.message : 'Something went wrong.',
      );
    } finally {
      setBusy(false);
    }
  }
  useEffect(() => {
    if (!token) return;
    let disposed = false;
    const refresh = () =>
      api('status')
        .then((data) => {
          if (!disposed) setStatus(data);
        })
        .catch((error) => {
          if (!disposed) setMessage(error.message);
        });
    void refresh();
    const timer = setInterval(refresh, 5000);
    return () => {
      disposed = true;
      clearInterval(timer);
    };
  }, [token, api]);
  function save(name: string, content: string) {
    const url = URL.createObjectURL(
      new Blob([content], {
        type: name.endsWith('.csv')
          ? 'text/csv;charset=utf-8'
          : 'application/json',
      }),
    );
    const link = document.createElement('a');
    link.href = url;
    link.download = name;
    link.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  return (
    <main className="backup-shell">
      <header>
        <span className="brand">REP COUNTER</span>
        <span className="badge">BACKUP & RESTORE</span>
      </header>
      <h1>
        Your workouts.
        <br />
        <span>A copy you keep.</span>
      </h1>
      <p className="intro">
        Save your history, open it in a spreadsheet, or put a backup back on
        your watch.
      </p>
      <div className="notice">
        Keep Garmin Connect running on your paired phone and leave the watch app
        open during transfers.
      </div>
      <section>
        <div className="step">01</div>
        <div className="content">
          <h2>Connect your watch</h2>
          <p>
            Open <strong>Settings → Backup / Export</strong> on the watch, then
            enter its code. Keep the watch app open.
          </p>
          <form
            onSubmit={(event) => {
              event.preventDefault();
              void run(async () => {
                const data = await api('claim');
                setToken(data.token);
              });
            }}
          >
            <label htmlFor="code">Watch code</label>
            <div className="form-row">
              <input
                id="code"
                value={code}
                disabled={!!token}
                onChange={(event) => setCode(event.target.value)}
                placeholder="ABC123 DEF456"
                autoComplete="off"
                maxLength={13}
                required
                pattern="[A-Fa-f0-9 ]{12,13}"
              />
              <button disabled={busy || !!token}>
                {token ? 'Connected' : 'Connect'}
              </button>
            </div>
          </form>
          {token && (
            <p className="status">
              {status.complete
                ? 'Backup received and checked.'
                : `Receiving backup · ${status.records} records`}{' '}
              Transfers expire after 15 minutes.
            </p>
          )}
        </div>
      </section>
      <section>
        <div className="step">02</div>
        <div className="content">
          <h2>Save a copy</h2>
          <p>
            A backup includes completed workouts, the current workout and
            settings. CSV is for viewing your sets in a spreadsheet.
          </p>
          <div className="buttons">
            <button
              disabled={!status.complete || busy}
              onClick={() =>
                void run(async () => {
                  const data = await api('download');
                  save(data.filename, data.content);
                })
              }
            >
              Download backup
            </button>
            <button
              className="secondary"
              disabled={!status.complete || busy}
              onClick={() =>
                void run(async () => {
                  const data = await api('download', { csv: true });
                  save(data.filename, data.content);
                })
              }
            >
              Download CSV
            </button>
          </div>
        </div>
      </section>
      <section>
        <div className="step">03</div>
        <div className="content">
          <h2>Open a saved backup</h2>
          <p>
            Choose a backup to check its contents, convert it to CSV, or restore
            it. CSV files cannot be restored.
          </p>
          <label htmlFor="backup">Choose .backup.json file</label>
          <input
            id="backup"
            type="file"
            accept=".json,application/json"
            onChange={(event) => {
              const file = event.target.files?.[0];
              setBackup(null);
              setSummary(null);
              if (file)
                void run(async () => {
                  if (file.size > 10 * 1024 * 1024)
                    throw Error('Backups up to 10 MB are supported.');
                  const data = JSON.parse(await file.text());
                  const checked = validateBackup(data);
                  setBackup(data);
                  setSummary(checked);
                });
            }}
          />
          {summary && (
            <div className="summary">
              <strong>{summary.workouts} completed workouts</strong>
              <span>
                {summary.completedSets} sets across completed workouts
              </span>
              {summary.currentSets > 0 && (
                <span>
                  {summary.currentSets} sets in the unfinished workout
                </span>
              )}
            </div>
          )}
          <div className="buttons">
            <button
              className="secondary"
              disabled={!backup || busy}
              onClick={() => backup && save('PullUpCounter.csv', csv(backup))}
            >
              Convert to CSV
            </button>
            <button
              disabled={!backup || !token || busy || status.restoreReady}
              onClick={() =>
                void run(async () => {
                  await api('upload', { records: backup });
                  setStatus(await api('status'));
                  setMessage(
                    'On the watch, open MENU and confirm Replace history.',
                  );
                })
              }
            >
              Send to watch for review
            </button>
          </div>
          <p className="fine">
            Restoring replaces history and settings; it does not merge workouts.
            The watch asks you to confirm. An active rest timer is reset.
          </p>
          {status.restored && (
            <p className="status">
              The watch confirmed that the restore completed.
            </p>
          )}
        </div>
      </section>
      <output aria-live="polite" className="message">
        {message}
      </output>
      <footer>
        Transfers expire after 15 minutes and are removed from active storage.
        Cloudflare may retain platform recovery copies. Keep downloaded backups
        somewhere safe.
      </footer>
    </main>
  );
}
