import { Transfers } from './transfer.mjs';

// One durable object owns one pairing code. Records are persisted separately,
// so receiving a set batch never rewrites the entire backup.
export class PersistentTransfers {
  constructor(sql, transaction, now = () => Date.now()) {
    this.sql = sql;
    this.transaction = transaction;
    this.now = now;
    this.engine = null;
    sql.exec(
      'CREATE TABLE IF NOT EXISTS session (id INTEGER PRIMARY KEY, value TEXT NOT NULL)',
    );
    sql.exec(
      'CREATE TABLE IF NOT EXISTS records (kind TEXT NOT NULL, seq INTEGER NOT NULL, value TEXT NOT NULL, PRIMARY KEY (kind, seq))',
    );
  }
  load() {
    if (this.engine) return this.engine;
    const engine = new Transfers(this.now);
    const row = this.sql
      .exec('SELECT value FROM session WHERE id = 1')
      .toArray()[0];
    if (row) {
      const s = JSON.parse(row.value);
      s.records = this.sql
        .exec("SELECT value FROM records WHERE kind = 'export' ORDER BY seq")
        .toArray()
        .map((row) => JSON.parse(row.value));
      s.restore = s.hasRestore
        ? this.sql
            .exec(
              "SELECT value FROM records WHERE kind = 'restore' ORDER BY seq",
            )
            .toArray()
            .map((row) => JSON.parse(row.value))
        : null;
      delete s.hasRestore;
      engine.sessions.set(s.code, s);
    }
    this.engine = engine;
    return engine;
  }
  clear() {
    this.sql.exec('DELETE FROM records');
    this.sql.exec('DELETE FROM session');
    this.engine = null;
  }
  handle(input) {
    const engine = this.load();
    let s = engine.sessions.values().next().value;
    if (s && s.expires <= this.now()) {
      this.transaction(() => this.clear());
      throw Error('Transfer not found or expired.');
    }
    if (input.action === 'create' && s) throw Error('Transfer already exists.');
    try {
      const result = engine.handle(input);
      if (input.action === 'create') {
        s = engine.sessions.get(result.code);
        engine.sessions.delete(result.code);
        s.code = input.code;
        engine.sessions.set(s.code, s);
        result.code = s.code;
      } else {
        s = engine.sessions.get(input.code);
      }
      if (input.action === 'close') {
        this.transaction(() => this.clear());
        return { result, expires: null };
      }
      if (!s) throw Error('Transfer not found or expired.');
      const mutates = [
        'create',
        'claim',
        'record',
        'upload',
        'restored',
      ].includes(input.action);
      if (mutates)
        this.transaction(() => {
          if (input.action === 'record') {
            this.sql.exec(
              "INSERT OR REPLACE INTO records(kind, seq, value) VALUES ('export', ?, ?)",
              input.sequence,
              JSON.stringify(s.records[input.sequence]),
            );
          }
          if (input.action === 'upload') {
            s.restore.forEach((record, seq) =>
              this.sql.exec(
                "INSERT INTO records(kind, seq, value) VALUES ('restore', ?, ?)",
                seq,
                JSON.stringify(record),
              ),
            );
          }
          const { records: _records, restore, ...metadata } = s;
          this.sql.exec(
            'INSERT OR REPLACE INTO session(id, value) VALUES (1, ?)',
            JSON.stringify({ ...metadata, hasRestore: restore !== null }),
          );
        });
      // Garmin only needs the pairing token; avoid millisecond-sized JSON integers.
      if ('expires' in result) result.expires = Math.floor(s.expires / 1000);
      return { result, expires: s.expires };
    } catch (error) {
      // If persistence failed, discard speculative memory state before another request.
      this.engine = null;
      throw error;
    }
  }
}
