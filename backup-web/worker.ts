import handler from 'vinext/server/fetch-handler';
import { transferRequest, type BackupEnv } from './lib/cloudflare-transfer';
export { BackupTransferObject } from './lib/cloudflare-transfer';

const worker = {
  async fetch(request: Request, env: BackupEnv, ctx: ExecutionContext) {
    if (new URL(request.url).pathname === '/api/transfer') {
      if (request.method !== 'POST')
        return Response.json(
          { error: 'Use POST.' },
          {
            status: 405,
            headers: { Allow: 'POST', 'Cache-Control': 'no-store' },
          },
        );
      return transferRequest(request, env);
    }
    return handler.fetch(request, env, ctx);
  },
};

export default worker;
