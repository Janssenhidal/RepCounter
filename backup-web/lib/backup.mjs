// Shared by the local service and tests. Public backups contain records, not storage keys.
export function integer(value, min = 0) {
  if (!Number.isSafeInteger(value) || value < min || value > 2147483647)
    throw Error('Invalid number in backup.');
  return value;
}
export function validateBackup(records) {
  if (!Array.isArray(records) || records.length < 2)
    throw Error('Incomplete backup.');
  const h = records[0];
  if (
    h.kind !== 'header' ||
    h.format !== 'pullupcounter.backup' ||
    h.version !== 1
  )
    throw Error('Unsupported backup version.');
  integer(h.created);
  integer(h.workouts);
  integer(h.settings?.increment, 1);
  integer(h.settings?.rest, 1);
  if (typeof h.settings?.vibration !== 'boolean')
    throw Error('Invalid settings.');
  let target = { ...h.current, id: 0 },
    offset = 0,
    count = 0,
    completedSets = 0,
    lastId = 0,
    previous;
  const checkTarget = () => {
    integer(target.reps);
    integer(target.sets);
    integer(target.rows);
    if (target.rows > target.sets) throw Error('Invalid set count.');
  };
  const finishTarget = () => {
    if (offset !== target.rows) throw Error('Missing set rows.');
    if (
      previous &&
      (previous[0] !== target.sets || previous[1] !== target.reps)
    )
      throw Error('Totals do not match sets.');
    if (!previous && (target.sets || target.reps))
      throw Error('Missing workout data.');
  };
  checkTarget();
  for (let i = 1; i < records.length; i++) {
    const r = records[i];
    if (r.kind === 'workout') {
      finishTarget();
      integer(r.id, lastId + 1);
      integer(r.start);
      integer(r.end);
      if (r.end < r.start) throw Error('Invalid workout dates.');
      target = r;
      lastId = r.id;
      count++;
      offset = 0;
      previous = undefined;
      checkTarget();
      if (!r.rows || !r.reps || !r.sets) throw Error('Empty saved workout.');
      completedSets += r.sets;
    } else if (r.kind === 'rows') {
      if (
        r.id !== target.id ||
        r.offset !== offset ||
        !Array.isArray(r.rows) ||
        !r.rows.length ||
        r.rows.length > 25
      )
        throw Error('Missing, duplicate or misplaced set rows.');
      for (const row of r.rows) {
        if (!Array.isArray(row) || row.length !== 5)
          throw Error('Invalid set row.');
        row.forEach((v, j) => integer(v, j < 3 ? 1 : 0));
        if (
          previous &&
          (row[0] !== previous[0] + 1 || row[1] !== previous[1] + row[2])
        )
          throw Error('Inconsistent set progression.');
        previous = row;
        offset++;
      }
      if (offset > target.rows) throw Error('Too many rows.');
    } else if (r.kind === 'end' && i === records.length - 1) {
      finishTarget();
      if (count !== h.workouts) throw Error('Missing workouts.');
      return {
        workouts: count,
        completedSets,
        currentSets: h.current.sets,
        created: h.created,
      };
    } else throw Error('Invalid or incomplete record sequence.');
  }
  throw Error('Incomplete backup.');
}
export function csv(records) {
  validateBackup(records);
  const lines = [
    'workout_id,status,date_utc,time_utc,set,reps_added,total_reps,rest_seconds',
  ];
  for (const r of records)
    if (r.kind === 'rows')
      for (const row of r.rows) {
        const date = new Date(row[4] * 1000).toISOString();
        lines.push(
          [
            r.id,
            r.id === 0 ? 'current' : 'completed',
            `${date.slice(8, 10)}/${date.slice(5, 7)}/${date.slice(0, 4)}`,
            date.slice(11, 19),
            row[0],
            row[2],
            row[1],
            row[3],
          ].join(','),
        );
      }
  return lines.join('\r\n') + '\r\n';
}
