import { PrismaPg } from '@prisma/adapter-pg';

import { PrismaClient } from './generated/client.js';

// Limit nawiązania połączenia: bez niego niedostępna baza trzymałaby próby w nieskończoność.
const CONNECT_TIMEOUT_MS = 5_000;

export type CorePrismaClient = PrismaClient;

export function createPrismaClient(databaseUrl: string): CorePrismaClient {
  const adapter = new PrismaPg({
    connectionString: databaseUrl,
    connectionTimeoutMillis: CONNECT_TIMEOUT_MS,
  });
  return new PrismaClient({ adapter });
}
