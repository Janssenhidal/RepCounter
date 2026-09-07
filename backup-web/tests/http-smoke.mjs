import assert from 'node:assert/strict';
const url = process.env.BACKUP_TEST_URL || 'http://localhost:3000/api/transfer';
async function request(data) {
  const response = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(data),
  });
  const result = await response.json();
  assert.equal(response.status, 200, JSON.stringify(result));
  return result;
}
const watch = await request({ action: 'create' });
const browser = await request({ action: 'claim', code: watch.code });
const records = [
  {
    kind: 'header',
    format: 'pullupcounter.backup',
    version: 1,
    created: 1700000000,
    workouts: 0,
    settings: { increment: 2, rest: 45, vibration: true },
    current: { reps: 2, sets: 1, rows: 1 },
  },
  { kind: 'rows', id: 0, offset: 0, rows: [[1, 2, 2, 45, 1700000000]] },
  { kind: 'end' },
];
for (let sequence = 0; sequence < records.length; sequence++)
  await request({
    action: 'record',
    code: watch.code,
    token: watch.token,
    sequence,
    record: records[sequence],
  });
const download = await request({
  action: 'download',
  code: watch.code,
  token: browser.token,
});
assert.deepEqual(JSON.parse(download.content), records);
await request({
  action: 'upload',
  code: watch.code,
  token: browser.token,
  records,
});
const info = await request({
  action: 'restore-info',
  code: watch.code,
  token: watch.token,
});
assert.equal(info.records, 3);
for (let sequence = 0; sequence < 3; sequence++)
  assert.deepEqual(
    (
      await request({
        action: 'restore-record',
        code: watch.code,
        token: watch.token,
        sequence,
      })
    ).record,
    records[sequence],
  );
await request({ action: 'close', code: watch.code, token: watch.token });
console.log(
  'HTTP export, download, restore upload and record retrieval passed (synthetic data).',
);
