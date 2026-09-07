import test from 'node:test';
import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import { PersistentTransfers } from '../lib/persistent-transfers.mjs';

function fixture() {
  const db = new DatabaseSync(':memory:');
  let fail = false,
    now = 1000;
  const sql = {
    exec(query, ...args) {
      if (fail && query.startsWith('INSERT'))
        throw Error('Injected disk failure');
      const stmt = db.prepare(query);
      const rows = query.startsWith('SELECT')
        ? stmt.all(...args)
        : (stmt.run(...args), []);
      return { toArray: () => rows };
    },
  };
  const transaction = (fn) => {
    db.exec('BEGIN');
    try {
      const result = fn();
      db.exec('COMMIT');
      return result;
    } catch (e) {
      db.exec('ROLLBACK');
      throw e;
    }
  };
  const open = () => new PersistentTransfers(sql, transaction, () => now);
  return {
    db,
    open,
    fail: (value) => (fail = value),
    time: (value) => (now = value),
  };
}
const records = [
  {
    kind: 'header',
    format: 'pullupcounter.backup',
    version: 1,
    created: 1000,
    workouts: 0,
    settings: { increment: 2, rest: 45, vibration: true },
    current: { reps: 2, sets: 1, rows: 1 },
  },
  { kind: 'rows', id: 0, offset: 0, rows: [[1, 2, 2, 45, 1000]] },
  { kind: 'end' },
];
test('pairing, backup and restore survive a fresh instance on every request', () => {
  const f = fixture(),
    code = 'ABCDEF123456';
  const watch = f.open().handle({ action: 'create', code }).result;
  const browser = f.open().handle({ action: 'claim', code }).result;
  const call = (action, extra = {}, token = watch.token) =>
    f.open().handle({ action, code, token, ...extra }).result;
  records.forEach((record, sequence) => call('record', { record, sequence }));
  assert.deepEqual(
    JSON.parse(call('download', {}, browser.token).content),
    records,
  );
  call('upload', { records }, browser.token);
  assert.equal(call('restore-info').records, 3);
  assert.deepEqual(call('restore-record', { sequence: 1 }).record, records[1]);
  call('restored');
  assert.equal(call('status', {}, browser.token).restored, true);
  call('close');
  assert.throws(() => call('status'));
  f.db.close();
});
test('failed persistence rolls back and retries without a duplicated record', () => {
  const f = fixture(),
    code = 'ABCDEF123456',
    service = f.open();
  const watch = service.handle({ action: 'create', code }).result;
  const request = {
    action: 'record',
    code,
    token: watch.token,
    sequence: 0,
    record: records[0],
  };
  f.fail(true);
  assert.throws(() => service.handle(request));
  f.fail(false);
  assert.equal(service.handle(request).result.next, 1);
  assert.equal(f.open().handle(request).result.next, 1);
  assert.equal(
    f.open().handle({ action: 'status', code, token: watch.token }).result
      .records,
    1,
  );
  f.time(901001);
  assert.throws(() =>
    f.open().handle({ action: 'status', code, token: watch.token }),
  );
  assert.equal(f.db.prepare('SELECT count(*) AS n FROM records').get().n, 0);
  f.db.close();
});
