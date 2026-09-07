import { validateBackup, csv } from './backup.mjs';

// Local prototype: memory only, one process, 15-minute lifetime; restart expires transfers.
// A deployment must replace this with shared expiring storage and edge rate limiting.
export class Transfers {
  constructor(now = () => Date.now()) {
    this.now = now;
    this.sessions = new Map();
    this.attempts = new Map();
  }
  secret() {
    return Array.from(crypto.getRandomValues(new Uint8Array(24)), (x) =>
      x.toString(16).padStart(2, '0'),
    ).join('');
  }
  prune() {
    for (const [key, s] of this.sessions)
      if (s.expires <= this.now()) this.sessions.delete(key);
  }
  handle(input, address = 'local') {
    this.prune();
    const action = input.action;
    if (action === 'create' || action === 'claim') {
      const old = this.attempts.get(address);
      const rate =
        old && old.until > this.now()
          ? old
          : { count: 0, until: this.now() + 60000 };
      if (++rate.count > 20) throw Error('Too many attempts. Wait a minute.');
      this.attempts.set(address, rate);
      for (const [key, r] of this.attempts)
        if (r.until <= this.now()) this.attempts.delete(key);
    }
    if (action === 'create') {
      if (this.sessions.size >= 32) throw Error('Transfer service is busy.');
      const code = this.secret().slice(0, 12).toUpperCase();
      const s = {
        code,
        watch: this.secret(),
        browser: null,
        expires: this.now() + 900000,
        records: [],
        bytes: 0,
        complete: false,
        restore: null,
        restored: false,
      };
      this.sessions.set(code, s);
      return { code, token: s.watch, expires: s.expires };
    }
    const s = this.sessions.get(input.code);
    if (!s) throw Error('Transfer not found or expired.');
    if (action === 'claim') {
      if (s.browser)
        throw Error('Code already paired. Start a new transfer on the watch.');
      s.browser = this.secret();
      return { token: s.browser, expires: s.expires };
    }
    const watch = input.token === s.watch;
    const browser = s.browser !== null && input.token === s.browser;
    if (!watch && !browser) throw Error('Transfer access denied.');
    if (action === 'status')
      return {
        complete: s.complete,
        records: s.records.length,
        restoreReady: !!s.restore,
        restored: s.restored,
      };
    if (action === 'record' && watch) {
      const encoded = JSON.stringify(input.record);
      if (encoded.length > 8192) throw Error('Record too large.');
      if (
        input.sequence < s.records.length &&
        JSON.stringify(s.records[input.sequence]) === encoded
      )
        return { next: input.sequence + 1 };
      if (s.complete || input.sequence !== s.records.length)
        throw Error('Unexpected record sequence.');
      if (s.bytes + encoded.length > 10 * 1024 * 1024)
        throw Error('Transfer exceeds the local 10 MB limit.');
      const record = structuredClone(input.record);
      if (record.kind === 'end') {
        validateBackup([...s.records, record]);
        s.complete = true;
      }
      s.records.push(record);
      s.bytes += encoded.length;
      return { next: s.records.length };
    }
    if (action === 'download' && browser && s.complete)
      return {
        filename: input.csv ? 'PullUpCounter.csv' : 'PullUpCounter.backup.json',
        content: input.csv
          ? csv(s.records)
          : JSON.stringify(s.records, null, 2),
      };
    if (action === 'upload' && browser) {
      if (s.restore)
        throw Error(
          'A restore is already staged. Start a new transfer to change it.',
        );
      if (JSON.stringify(input.records).length > 10 * 1024 * 1024)
        throw Error('Backup exceeds the local 10 MB limit.');
      const summary = validateBackup(input.records);
      s.restore = structuredClone(input.records);
      return summary;
    }
    if (action === 'restore-info' && watch && s.restore)
      return { ...validateBackup(s.restore), records: s.restore.length };
    if (action === 'restore-record' && watch && s.restore) {
      if (
        !Number.isInteger(input.sequence) ||
        input.sequence < 0 ||
        input.sequence >= s.restore.length
      )
        throw Error('Invalid record number.');
      return { record: s.restore[input.sequence] };
    }
    if (action === 'restored' && watch) {
      s.restored = true;
      return { ok: true };
    }
    if (action === 'close') {
      this.sessions.delete(s.code);
      return { ok: true };
    }
    throw Error('Action unavailable.');
  }
}
