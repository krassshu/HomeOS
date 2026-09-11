import { describe, expect, it } from 'vitest';

import {
  CORRELATION_ID_HEADER,
  getCorrelationId,
  resolveCorrelationId,
  runWithCorrelationId,
} from '../../../src/common/correlation/correlation-context.js';

const UUID_V4_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/;

describe('resolveCorrelationId', () => {
  it('uses the header name x-correlation-id', () => {
    expect(CORRELATION_ID_HEADER).toBe('x-correlation-id');
  });

  it('accepts a well-formed incoming value', () => {
    expect(resolveCorrelationId('req-2026.09:abc_ABC')).toBe('req-2026.09:abc_ABC');
  });

  it('accepts a value of exactly 128 characters', () => {
    const value = 'a'.repeat(128);

    expect(resolveCorrelationId(value)).toBe(value);
  });

  it('takes the first element when the header arrives as an array', () => {
    expect(resolveCorrelationId(['first-id', 'second-id'])).toBe('first-id');
  });

  it.each([
    ['undefined', undefined],
    ['empty string', ''],
    ['empty array', []],
    ['longer than 128 characters', 'a'.repeat(129)],
    ['whitespace inside', 'abc def'],
    ['newline inside', 'abc\ndef'],
    ['forbidden characters', 'abc/def?x=1'],
    ['non-ascii characters', 'żółw-1'],
  ])('generates a UUID v4 for %s', (_label, incoming) => {
    const resolved = resolveCorrelationId(incoming);

    expect(resolved).toMatch(UUID_V4_PATTERN);
  });

  it('generates a fresh UUID on every fallback', () => {
    expect(resolveCorrelationId(undefined)).not.toBe(resolveCorrelationId(undefined));
  });
});

describe('correlation context', () => {
  it('returns undefined outside of a correlation scope', () => {
    expect(getCorrelationId()).toBeUndefined();
  });

  it('exposes the correlation id inside runWithCorrelationId', () => {
    const seen = runWithCorrelationId('ctx-1', () => getCorrelationId());

    expect(seen).toBe('ctx-1');
    expect(getCorrelationId()).toBeUndefined();
  });

  it('propagates the correlation id across awaits', async () => {
    const seen = await runWithCorrelationId('ctx-async', async () => {
      await new Promise<void>((resolve) => setTimeout(resolve, 1));
      return getCorrelationId();
    });

    expect(seen).toBe('ctx-async');
  });

  it('keeps nested scopes isolated', () => {
    const seen = runWithCorrelationId('outer', () => {
      const inner = runWithCorrelationId('inner', () => getCorrelationId());
      return { inner, outer: getCorrelationId() };
    });

    expect(seen).toEqual({ inner: 'inner', outer: 'outer' });
  });
});
