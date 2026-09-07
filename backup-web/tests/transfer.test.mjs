import test from 'node:test';
import assert from 'node:assert/strict';
import { Transfers } from '../lib/transfer.mjs';
import { validateBackup, csv } from '../lib/backup.mjs';
const records = () => [
  {
    kind: 'header',
    format: 'pullupcounter.backup',
    version: 1,
    created: 1700000000,
    workouts: 1,
    settings: { increment: 2, rest: 45, vibration: true },
    current: { reps: 0, sets: 0, rows: 0 },
  },
  {
    kind: 'workout',
    id: 1,
    start: 1700000000,
    end: 1700000060,
    reps: 4,
    sets: 2,
    rows: 2,
  },
  {
    kind: 'rows',
    id: 1,
    offset: 0,
    rows: [
      [1, 2, 2, 45, 1700000000],
      [2, 4, 2, 45, 1700000060],
    ],
  },
  { kind: 'end' },
];
test('authenticated backup, retry, CSV and restore round trip', () => {
  const service = new Transfers();
  const watch = service.handle({ action: 'create' });
  const browser = service.handle({ action: 'claim', code: watch.code });
  const call = (action, extra = {}, token = watch.token) =>
    service.handle({ action, code: watch.code, token, ...extra });
  assert.throws(() => call('download', {}, browser.token));
  records().forEach((record, sequence) => {
    assert.equal(call('record', { record, sequence }).next, sequence + 1);
    assert.equal(call('record', { record, sequence }).next, sequence + 1);
  });
  assert.deepEqual(
    JSON.parse(call('download', {}, browser.token).content),
    records(),
  );
  assert.match(
    call('download', { csv: true }, browser.token).content,
    /14\/11\/2023/,
  );
  call('upload', { records: records() }, browser.token);
  assert.equal(call('restore-info').workouts, 1);
  assert.deepEqual(
    call('restore-record', { sequence: 2 }).record,
    records()[2],
  );
  assert.throws(() =>
    call('record', { sequence: 4, record: {} }, browser.token),
  );
  assert.throws(() => call('download', {}, 'wrong'));
  call('restored');
  assert.equal(call('status', {}, browser.token).restored, true);
});
test('rejects incomplete, corrupt, incompatible and duplicate data', () => {
  assert.throws(() => validateBackup(records().slice(0, -1)));
  for (const mutate of [
    (r) => (r[0].version = 2),
    (r) => (r[0].workouts = 2),
    (r) => (r[2].offset = 1),
    (r) => (r[2].rows[1][1] = 99),
    (r) => (r[2].rows[0][2] = '=cmd'),
    (r) => r.splice(2, 0, r[2]),
  ]) {
    const input = records();
    mutate(input);
    assert.throws(() => validateBackup(input));
  }
  assert.equal(csv(records()).split('\r\n').length, 4);
});
test('expired codes, single claim and rate limit', () => {
  let time = 0;
  const service = new Transfers(() => time);
  const watch = service.handle({ action: 'create' });
  service.handle({ action: 'claim', code: watch.code });
  assert.throws(() => service.handle({ action: 'claim', code: watch.code }));
  time = 900001;
  assert.throws(() =>
    service.handle({ action: 'status', code: watch.code, token: watch.token }),
  );
  for (let i = 0; i < 20; i++) {
    try {
      service.handle({ action: 'claim', code: 'absent' });
    } catch {}
  }
  assert.throws(() => service.handle({ action: 'create' }), /Too many/);
});
