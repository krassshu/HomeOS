import { describe, expect, it } from 'vitest';

import { describeError, redactSecrets, SERVICE_NAME } from '../../../src/common/logging/logger.js';

const PASSWORD = 'sekret';
const DATABASE_URL = `postgresql://user:${PASSWORD}@host:5432/db`;

describe('redactSecrets', () => {
  it('replaces a postgresql:// URL with its credentials', () => {
    expect(redactSecrets(`connect failed for ${DATABASE_URL}`)).toBe(
      'connect failed for postgresql://[redacted]',
    );
  });

  it('replaces the postgres:// alias as well', () => {
    expect(redactSecrets(`postgres://user:${PASSWORD}@host:5432/db timed out`)).toBe(
      'postgres://[redacted] timed out',
    );
  });

  it('redacts every URL in the text, case-insensitively', () => {
    const text = `first ${DATABASE_URL} second POSTGRESQL://a:b@c/d`;

    expect(redactSecrets(text)).toBe(
      'first postgresql://[redacted] second POSTGRESQL://[redacted]',
    );
  });

  it('leaves text without URLs untouched', () => {
    expect(redactSecrets('plain message')).toBe('plain message');
  });
});

describe('describeError', () => {
  it('describes an Error with a redacted message', () => {
    const error = new Error(`could not connect to ${DATABASE_URL}`);

    expect(describeError(error)).toEqual({
      name: 'Error',
      message: 'could not connect to postgresql://[redacted]',
    });
  });

  it('carries over a string error code', () => {
    const error: Error & { code?: unknown } = new Error('refused');
    error.code = 'ECONNREFUSED';

    expect(describeError(error)).toEqual({
      name: 'Error',
      message: 'refused',
      code: 'ECONNREFUSED',
    });
  });

  it('ignores a non-string error code', () => {
    const error: Error & { code?: unknown } = new Error('refused');
    error.code = 42;

    expect(describeError(error)).toEqual({ name: 'Error', message: 'refused' });
  });

  it('keeps the custom error name', () => {
    class ProbeError extends Error {
      constructor() {
        super('probe failed');
        this.name = 'ProbeError';
      }
    }

    expect(describeError(new ProbeError())).toMatchObject({ name: 'ProbeError' });
  });

  it('describes a non-Error value as UnknownError', () => {
    expect(describeError('boom')).toEqual({ name: 'UnknownError', message: 'boom' });
    expect(describeError(undefined)).toEqual({ name: 'UnknownError', message: 'undefined' });
  });

  it('redacts URLs inside non-Error values too', () => {
    const described = describeError(`failed: ${DATABASE_URL}`);

    expect(described).toEqual({ name: 'UnknownError', message: 'failed: postgresql://[redacted]' });
    expect(JSON.stringify(described)).not.toContain(PASSWORD);
  });
});

describe('SERVICE_NAME', () => {
  it('is the public service identifier', () => {
    expect(SERVICE_NAME).toBe('homeintelcore-api');
  });
});
