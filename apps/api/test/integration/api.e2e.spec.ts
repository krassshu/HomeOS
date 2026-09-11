import { randomBytes } from 'node:crypto';

import { PostgreSqlContainer } from '@testcontainers/postgresql';
import type { StartedPostgreSqlContainer } from '@testcontainers/postgresql';
import { afterAll, beforeAll, describe, expect, it } from 'vitest';

import { ConfigValidationError } from '../../src/config/app-config.js';
import { createPrismaClient } from '../../src/infrastructure/persistence/prisma-client.factory.js';
import { startTestApp } from '../support/test-app.js';
import type { TestApp } from '../support/test-app.js';

// Obraz przypięty digestem (multi-arch), pobrany lokalnie; Testcontainers mapuje losowy port.
const POSTGRES_IMAGE =
  'docker.io/library/postgres:18@sha256:3a82e1f56c8f0f5616a11103ac3d47e632c3938698946a7ad26da0df1334744a';

const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
const SERVICE = 'homeintelcore-api';

const LIVE_READINESS_TIMEOUT_MS = 2000;
const DOWN_READINESS_TIMEOUT_MS = 500;
// Port 1 na loopbacku nic nie nasłuchuje: połączenie odmawia natychmiast, bez sieci.
const DOWN_PASSWORD = 'hic-down-secret';
const DOWN_DATABASE_URL = `postgresql://hic_nobody:${DOWN_PASSWORD}@127.0.0.1:1/hic_down`;

// Losowe poświadczenia tylko dla kontenera testowego; nigdy nie trafiają na stdout.
const DB_USER = `hic_${randomBytes(4).toString('hex')}`;
const DB_PASSWORD = randomBytes(18).toString('base64url');
const DB_NAME = 'hic_e2e';

function expectNoDatabaseSecrets(text: string, forbidden: readonly string[]): void {
  for (const fragment of ['DATABASE_URL', 'postgresql://', 'postgres://', ...forbidden]) {
    expect(text).not.toContain(fragment);
  }
}

describe('Core API over HTTP with PostgreSQL 18 (Testcontainers)', () => {
  let container: StartedPostgreSqlContainer | undefined;
  let containerStopped = false;
  let liveApp: TestApp | undefined;
  let downApp: TestApp | undefined;
  let databaseUrl = '';

  beforeAll(async () => {
    container = await new PostgreSqlContainer(POSTGRES_IMAGE)
      .withDatabase(DB_NAME)
      .withUsername(DB_USER)
      .withPassword(DB_PASSWORD)
      .start();
    databaseUrl = container.getConnectionUri();

    liveApp = await startTestApp({
      DATABASE_URL: databaseUrl,
      NODE_ENV: 'test',
      LOG_LEVEL: 'warn',
      READINESS_TIMEOUT_MS: String(LIVE_READINESS_TIMEOUT_MS),
    });
    downApp = await startTestApp({
      DATABASE_URL: DOWN_DATABASE_URL,
      NODE_ENV: 'test',
      LOG_LEVEL: 'warn',
      READINESS_TIMEOUT_MS: String(DOWN_READINESS_TIMEOUT_MS),
    });
  });

  afterAll(async () => {
    // Każde sprzątanie osobno: awaria jednego nie może zostawić kontenera ani portu.
    const results = await Promise.allSettled([
      liveApp?.close() ?? Promise.resolve(),
      downApp?.close() ?? Promise.resolve(),
      containerStopped || container === undefined ? Promise.resolve() : container.stop(),
    ]);
    const failed = results.find((result) => result.status === 'rejected');
    if (failed !== undefined && failed.status === 'rejected') {
      throw new Error('e2e cleanup failed', { cause: failed.reason });
    }
  });

  function requireApp(app: TestApp | undefined): TestApp {
    if (app === undefined) throw new Error('test app not started');
    return app;
  }

  it('reports readiness 200 with a generated correlation id when the database is up', async () => {
    const response = await fetch(`${requireApp(liveApp).baseUrl}/health/ready`);

    expect(response.status).toBe(200);
    expect(response.headers.get('content-type')).toContain('application/json');
    expect(response.headers.get('x-correlation-id')).toMatch(UUID_PATTERN);
    await expect(response.json()).resolves.toEqual({
      service: SERVICE,
      status: 'ok',
      checks: { database: 'up' },
    });
  });

  it('echoes a client-supplied x-correlation-id', async () => {
    const response = await fetch(`${requireApp(liveApp).baseUrl}/health/ready`, {
      headers: { 'x-correlation-id': 'e2e-ready-42' },
    });

    expect(response.status).toBe(200);
    expect(response.headers.get('x-correlation-id')).toBe('e2e-ready-42');
  });

  it('replaces an unsafe x-correlation-id with a generated one', async () => {
    const response = await fetch(`${requireApp(liveApp).baseUrl}/health/live`, {
      headers: { 'x-correlation-id': 'not safe/at all' },
    });

    expect(response.status).toBe(200);
    expect(response.headers.get('x-correlation-id')).toMatch(UUID_PATTERN);
  });

  it('runs PostgreSQL 18 with native uuidv7() through the Prisma pg adapter', async () => {
    const client = createPrismaClient(databaseUrl);
    try {
      const [uuidRow] = await client.$queryRaw<
        { version: number }[]
      >`SELECT uuid_extract_version(uuidv7()) AS version`;
      const [versionRow] = await client.$queryRaw<{ version: string }[]>`SELECT version()`;

      expect(uuidRow?.version).toBe(7);
      expect(versionRow?.version).toMatch(/^PostgreSQL 18/);
    } finally {
      await client.$disconnect();
    }
  });

  it('reports liveness 200 regardless of the database', async () => {
    for (const app of [requireApp(liveApp), requireApp(downApp)]) {
      const response = await fetch(`${app.baseUrl}/health/live`);

      expect(response.status).toBe(200);
      await expect(response.json()).resolves.toEqual({ service: SERVICE, status: 'ok' });
    }
  });

  it('answers unknown routes with a JSON 404 carrying the correlation id', async () => {
    const response = await fetch(`${requireApp(liveApp).baseUrl}/does-not-exist`, {
      headers: { 'x-correlation-id': 'e2e-404' },
    });

    expect(response.status).toBe(404);
    await expect(response.json()).resolves.toMatchObject({
      statusCode: 404,
      correlationId: 'e2e-404',
    });
  });

  it('refuses to build the application on invalid configuration before listening', async () => {
    await expect(startTestApp({})).rejects.toBeInstanceOf(ConfigValidationError);
  });

  it('reports readiness 503 within the timeout when the database is unreachable', async () => {
    const app = requireApp(downApp);
    const startedAt = performance.now();
    const response = await fetch(`${app.baseUrl}/health/ready`);
    const elapsedMs = performance.now() - startedAt;

    expect(response.status).toBe(503);
    expect(elapsedMs).toBeLessThan(DOWN_READINESS_TIMEOUT_MS + 1000);
    expect(response.headers.get('content-type')).toContain('application/json');

    const raw = await response.text();
    expect(JSON.parse(raw)).toEqual({
      service: SERVICE,
      status: 'unavailable',
      checks: { database: 'down' },
      correlationId: expect.stringMatching(UUID_PATTERN) as string,
    });
    expectNoDatabaseSecrets(raw, [DOWN_PASSWORD, 'hic_nobody', '127.0.0.1:1', 'localhost']);

    const live = await fetch(`${app.baseUrl}/health/live`);
    expect(live.status).toBe(200);
  });

  it('degrades readiness to 503 after the database container stops, liveness stays 200', async () => {
    const app = requireApp(liveApp);
    if (container === undefined) throw new Error('container not started');
    const mappedPort = container.getPort();
    await container.stop();
    containerStopped = true;

    const startedAt = performance.now();
    const response = await fetch(`${app.baseUrl}/health/ready`);
    const elapsedMs = performance.now() - startedAt;

    expect(response.status).toBe(503);
    expect(elapsedMs).toBeLessThan(LIVE_READINESS_TIMEOUT_MS + 1000);

    const raw = await response.text();
    expect(JSON.parse(raw)).toMatchObject({
      service: SERVICE,
      status: 'unavailable',
      checks: { database: 'down' },
    });
    expectNoDatabaseSecrets(raw, [DB_PASSWORD, DB_USER, 'localhost', `127.0.0.1:${mappedPort}`]);

    const live = await fetch(`${app.baseUrl}/health/live`);
    expect(live.status).toBe(200);
  });
});
