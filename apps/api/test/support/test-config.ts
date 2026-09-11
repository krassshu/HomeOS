import type { AppConfig } from '../../src/config/app-config.js';

export const TEST_DATABASE_PASSWORD = 'sekret-haslo';
export const TEST_DATABASE_URL = `postgresql://core:${TEST_DATABASE_PASSWORD}@db.internal:5432/homeintelcore`;

// Gotowa, poprawna konfiguracja do testów jednostkowych; nadpisujemy tylko to, co bada test.
export function createTestConfig(overrides: Partial<AppConfig> = {}): AppConfig {
  return {
    environment: 'test',
    host: '127.0.0.1',
    port: 0,
    databaseUrl: TEST_DATABASE_URL,
    logLevel: 'warn',
    readinessTimeoutMs: 200,
    shutdownTimeoutMs: 1000,
    ...overrides,
  };
}
