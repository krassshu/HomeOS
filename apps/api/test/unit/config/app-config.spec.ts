import { describe, expect, it } from 'vitest';

import { ConfigValidationError, loadAppConfig } from '../../../src/config/app-config.js';
import type { EnvSource } from '../../../src/config/app-config.js';

const PASSWORD = 'sekret-haslo';
const VALID_DATABASE_URL = `postgresql://core:${PASSWORD}@db.internal:5432/homeintelcore`;

function captureValidationError(env: EnvSource): ConfigValidationError {
  try {
    loadAppConfig(env);
  } catch (error: unknown) {
    if (error instanceof ConfigValidationError) return error;
    throw error;
  }
  throw new Error('expected loadAppConfig to throw ConfigValidationError');
}

describe('loadAppConfig', () => {
  it('returns a typed config with defaults when only DATABASE_URL is set', () => {
    const config = loadAppConfig({ DATABASE_URL: VALID_DATABASE_URL });

    expect(config).toEqual({
      environment: 'development',
      host: '127.0.0.1',
      port: 3000,
      databaseUrl: VALID_DATABASE_URL,
      logLevel: 'info',
      readinessTimeoutMs: 2000,
      shutdownTimeoutMs: 10000,
    });
  });

  it('applies explicit values over defaults', () => {
    const config = loadAppConfig({
      DATABASE_URL: VALID_DATABASE_URL,
      NODE_ENV: 'test',
      HOST: '0.0.0.0',
      PORT: '4100',
      LOG_LEVEL: 'debug',
      READINESS_TIMEOUT_MS: '500',
      SHUTDOWN_TIMEOUT_MS: '1500',
    });

    expect(config).toMatchObject({
      environment: 'test',
      host: '0.0.0.0',
      port: 4100,
      logLevel: 'debug',
      readinessTimeoutMs: 500,
      shutdownTimeoutMs: 1500,
    });
  });

  it('rejects a missing DATABASE_URL', () => {
    const error = captureValidationError({});

    expect(error.problems).toEqual(['DATABASE_URL is required']);
    expect(error.message).toContain('DATABASE_URL is required');
  });

  it('rejects an empty DATABASE_URL', () => {
    expect(captureValidationError({ DATABASE_URL: '' }).problems).toEqual([
      'DATABASE_URL is required',
    ]);
  });

  it.each(['__GENERATED_BY_DEV_SETUP__', '__SET_ME__'])(
    'rejects the %s placeholder inside DATABASE_URL',
    (placeholder) => {
      const error = captureValidationError({
        DATABASE_URL: `postgresql://core:${placeholder}@127.0.0.1:5432/homeintelcore`,
      });

      expect(error.problems).toHaveLength(1);
      expect(error.problems[0]).toContain('placeholder');
    },
  );

  it('rejects a non-postgresql scheme', () => {
    const error = captureValidationError({
      DATABASE_URL: `mysql://core:${PASSWORD}@db.internal:3306/homeintelcore`,
    });

    expect(error.problems).toEqual(['DATABASE_URL must use the postgresql:// scheme']);
  });

  it('accepts the postgres:// scheme alias', () => {
    expect(() =>
      loadAppConfig({ DATABASE_URL: `postgres://core:${PASSWORD}@db.internal:5432/core` }),
    ).not.toThrow();
  });

  it('rejects a DATABASE_URL that is not a URL', () => {
    expect(captureValidationError({ DATABASE_URL: 'not a url' }).problems).toEqual([
      'DATABASE_URL is not a valid URL',
    ]);
  });

  it('rejects a DATABASE_URL without a database name', () => {
    const error = captureValidationError({
      DATABASE_URL: `postgresql://core:${PASSWORD}@db.internal:5432/`,
    });

    expect(error.problems).toEqual(['DATABASE_URL must include a database name']);
  });

  it('rejects a DATABASE_URL with an out-of-range port', () => {
    const error = captureValidationError({
      DATABASE_URL: `postgresql://core:${PASSWORD}@db.internal:70000/core`,
    });

    expect(error.problems).toEqual(['DATABASE_URL is not a valid URL']);
  });

  it.each([
    ['PORT', 'abc', 'PORT must be an integer between 1 and 65535'],
    ['PORT', '70000', 'PORT must be an integer between 1 and 65535'],
    ['PORT', '0', 'PORT must be an integer between 1 and 65535'],
    ['LOG_LEVEL', 'loud', 'LOG_LEVEL must be one of: fatal, error, warn, info, debug, trace'],
    ['NODE_ENV', 'staging', 'NODE_ENV must be one of: development, test, production'],
    ['HOST', '127.0.0.1 ', 'HOST must not contain whitespace'],
    ['READINESS_TIMEOUT_MS', '1', 'READINESS_TIMEOUT_MS must be an integer between 100 and 60000'],
    [
      'SHUTDOWN_TIMEOUT_MS',
      '999',
      'SHUTDOWN_TIMEOUT_MS must be an integer between 1000 and 300000',
    ],
  ])('rejects %s=%s', (name, value, problem) => {
    const error = captureValidationError({ DATABASE_URL: VALID_DATABASE_URL, [name]: value });

    expect(error.problems).toEqual([problem]);
  });

  it('collects several problems into one error', () => {
    const error = captureValidationError({
      DATABASE_URL: VALID_DATABASE_URL,
      PORT: 'abc',
      LOG_LEVEL: 'loud',
      READINESS_TIMEOUT_MS: '1',
    });

    expect(error.name).toBe('ConfigValidationError');
    expect(error.problems).toEqual([
      'PORT must be an integer between 1 and 65535',
      'LOG_LEVEL must be one of: fatal, error, warn, info, debug, trace',
      'READINESS_TIMEOUT_MS must be an integer between 100 and 60000',
    ]);
    expect(error.message).toBe(
      'Invalid configuration:\n' +
        '- PORT must be an integer between 1 and 65535\n' +
        '- LOG_LEVEL must be one of: fatal, error, warn, info, debug, trace\n' +
        '- READINESS_TIMEOUT_MS must be an integer between 100 and 60000',
    );
  });

  it('never quotes the password or the URL in validation messages', () => {
    const badUrls = [
      `mysql://core:${PASSWORD}@db.internal:3306/core`,
      `postgresql://core:${PASSWORD}@db.internal:5432/`,
      `postgresql://core:${PASSWORD}@db.internal:70000/core`,
      `postgresql://core:${PASSWORD}__SET_ME__@db.internal:5432/core`,
      `postgresql://core:${PASSWORD}@/core`,
    ];

    for (const databaseUrl of badUrls) {
      const error = captureValidationError({ DATABASE_URL: databaseUrl, PORT: 'abc' });
      const texts = [error.message, ...error.problems];

      expect(error.problems.length).toBeGreaterThanOrEqual(2);
      for (const text of texts) {
        expect(text).not.toContain(PASSWORD);
        expect(text).not.toContain(databaseUrl);
        expect(text).not.toContain('db.internal');
      }
    }
  });
});
