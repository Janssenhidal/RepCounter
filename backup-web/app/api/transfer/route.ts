import { env } from 'cloudflare:workers';
import {
  transferRequest,
  type BackupEnv,
} from '../../../lib/cloudflare-transfer';
export async function POST(request: Request) {
  return transferRequest(request, env as unknown as BackupEnv);
}
