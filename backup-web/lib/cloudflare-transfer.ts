import { DurableObject } from 'cloudflare:workers';
import { PersistentTransfers } from './persistent-transfers.mjs';

export type BackupEnv = {
  BACKUP_TRANSFERS: DurableObjectNamespace<BackupTransferObject>;
};
const headers = {
  'Cache-Control': 'no-store',
  'X-Content-Type-Options': 'nosniff',
};

export async function readJson(request: Request) {
  const reader = request.body?.getReader();
  if (!reader) throw Error('Missing request body.');
  const parts: Uint8Array[] = [];
  let size = 0;
  while (true) {
    const { done, value } = await reader.read();
    if (done) break;
    size += value.byteLength;
    if (size > 11 * 1024 * 1024) {
      await reader.cancel();
      throw Error('Request too large.');
    }
    parts.push(value);
  }
  const body = new Uint8Array(size);
  let offset = 0;
  for (const part of parts) {
    body.set(part, offset);
    offset += part.length;
  }
  return JSON.parse(new TextDecoder().decode(body));
}

export class BackupTransferObject extends DurableObject<BackupEnv> {
  private transfers: PersistentTransfers | null = null;
  async fetch(request: Request) {
    return this.ctx.blockConcurrencyWhile(async () => {
      try {
        if (new URL(request.url).pathname === '/limit') {
          const now = Date.now();
          const saved = await this.ctx.storage.get<{
            until: number;
            count: number;
          }>('rate');
          const rate =
            saved && saved.until > now
              ? saved
              : { until: now + 60000, count: 0 };
          rate.count++;
          await this.ctx.storage.put('rate', rate);
          await this.ctx.storage.setAlarm(rate.until);
          return Response.json(
            { ok: rate.count <= 20 },
            { status: rate.count <= 20 ? 200 : 429, headers },
          );
        }
        this.transfers ??= new PersistentTransfers(
          this.ctx.storage.sql,
          (fn: () => void) => this.ctx.storage.transactionSync(fn),
        );
        const input = await readJson(request);
        const { result, expires } = this.transfers.handle(input);
        if (expires) await this.ctx.storage.setAlarm(expires);
        else {
          await this.ctx.storage.deleteAll();
          await this.ctx.storage.deleteAlarm();
          this.transfers = null;
        }
        return Response.json(result, { headers });
      } catch (error) {
        // Invalid-code probes must not leave idle durable storage indefinitely.
        if (!(await this.ctx.storage.getAlarm()))
          await this.ctx.storage.setAlarm(Date.now() + 60000);
        return Response.json(
          {
            error: error instanceof Error ? error.message : 'Transfer failed.',
          },
          { status: 400, headers },
        );
      }
    });
  }
  async alarm() {
    await this.ctx.storage.deleteAll();
    this.transfers = null;
  }
}

export async function transferRequest(request: Request, env: BackupEnv) {
  try {
    const url = new URL(request.url);
    const origin = request.headers.get('origin');
    if (origin && origin !== url.origin)
      throw Error('Cross-origin request denied.');
    const input = await readJson(request);
    const actions = [
      'create',
      'claim',
      'status',
      'record',
      'download',
      'upload',
      'restore-info',
      'restore-record',
      'restored',
      'close',
    ];
    if (!input || !actions.includes(input.action))
      throw Error('Unknown transfer action.');
    if (input.action === 'create' || input.action === 'claim') {
      const ip = request.headers.get('CF-Connecting-IP') || 'local';
      const digest = await crypto.subtle.digest(
        'SHA-256',
        new TextEncoder().encode(ip),
      );
      const key = Array.from(new Uint8Array(digest), (x) =>
        x.toString(16).padStart(2, '0'),
      ).join('');
      const limiter = env.BACKUP_TRANSFERS.get(
        env.BACKUP_TRANSFERS.idFromName('rate:' + key),
      );
      const limited = await limiter.fetch('https://internal/limit', {
        method: 'POST',
      });
      if (!limited.ok)
        return Response.json(
          { error: 'Too many attempts. Wait a minute.' },
          { status: 429, headers },
        );
    }
    if (input.action === 'create') {
      input.code = Array.from(crypto.getRandomValues(new Uint8Array(6)), (x) =>
        x.toString(16).padStart(2, '0'),
      )
        .join('')
        .toUpperCase();
    }
    if (typeof input.code !== 'string' || !/^[A-F0-9]{12}$/.test(input.code))
      throw Error('Enter the 12-character watch code.');
    const object = env.BACKUP_TRANSFERS.get(
      env.BACKUP_TRANSFERS.idFromName('transfer:' + input.code),
    );
    return object.fetch('https://internal/session', {
      method: 'POST',
      body: JSON.stringify(input),
      headers: { 'Content-Type': 'application/json' },
    });
  } catch (error) {
    return Response.json(
      { error: error instanceof Error ? error.message : 'Transfer failed.' },
      { status: 400, headers },
    );
  }
}
