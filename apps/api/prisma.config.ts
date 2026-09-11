import { existsSync } from 'node:fs';
import path from 'node:path';

import { defineConfig } from 'prisma/config';

// Prisma CLI nie wczytuje .env samo; lokalna konfiguracja leży w root repo.
const rootEnvFile = path.resolve(import.meta.dirname, '../../.env');
if (existsSync(rootEnvFile)) {
  process.loadEnvFile(rootEnvFile);
}

// validate/generate nie potrzebują bazy; URL jest wymagany dopiero przez migrate.
const databaseUrl = process.env.DATABASE_URL;

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  ...(databaseUrl === undefined ? {} : { datasource: { url: databaseUrl } }),
});
