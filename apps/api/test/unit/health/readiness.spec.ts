import { Logger } from '@nestjs/common';
import { afterAll, afterEach, beforeAll, describe, expect, it, vi } from 'vitest';

import type { DatabaseProbe } from '../../../src/common/ports/database-probe.js';
import { ReadinessService } from '../../../src/health/readiness.service.js';
import {
  createTestConfig,
  TEST_DATABASE_PASSWORD,
  TEST_DATABASE_URL,
} from '../../support/test-config.js';

const READINESS_TIMEOUT_MS = 200;

function createService(ping: DatabaseProbe['ping']): { service: ReadinessService } {
  const probe: DatabaseProbe = { ping };
  const config = createTestConfig({ readinessTimeoutMs: READINESS_TIMEOUT_MS });
  return { service: new ReadinessService(probe, config) };
}

describe('ReadinessService', () => {
  const warnSpy = vi.spyOn(Logger.prototype, 'warn').mockImplementation(() => undefined);

  beforeAll(() => {
    Logger.overrideLogger(false);
  });

  afterEach(() => {
    warnSpy.mockClear();
    vi.useRealTimers();
  });

  afterAll(() => {
    warnSpy.mockRestore();
  });

  it('reports ok when the probe resolves', async () => {
    const { service } = createService(vi.fn().mockResolvedValue(undefined));

    await expect(service.check()).resolves.toEqual({
      status: 'ok',
      checks: { database: 'up' },
    });
    expect(warnSpy).not.toHaveBeenCalled();
  });

  it('reports unavailable without leaking the error when the probe rejects', async () => {
    const failure = new Error(`connection refused: ${TEST_DATABASE_URL}`);
    const { service } = createService(vi.fn().mockRejectedValue(failure));

    const result = await service.check();

    expect(result).toEqual({ status: 'unavailable', checks: { database: 'down' } });
    const serialized = JSON.stringify(result);
    expect(serialized).not.toContain(TEST_DATABASE_PASSWORD);
    expect(serialized).not.toContain('connection refused');
    expect(serialized).not.toContain('postgresql://');
  });

  it('logs only a redacted reason for a failed probe', async () => {
    const failure = new Error(`connection refused: ${TEST_DATABASE_URL}`);
    const { service } = createService(vi.fn().mockRejectedValue(failure));

    await service.check();

    expect(warnSpy).toHaveBeenCalledTimes(1);
    const logged = JSON.stringify(warnSpy.mock.calls[0]);
    expect(logged).toContain('postgresql://[redacted]');
    expect(logged).not.toContain(TEST_DATABASE_PASSWORD);
  });

  it('reports unavailable when the probe hangs past the timeout', async () => {
    vi.useFakeTimers();
    const { service } = createService(() => new Promise<never>(() => undefined));

    const pending = service.check();
    await vi.advanceTimersByTimeAsync(READINESS_TIMEOUT_MS - 1);
    // Tuż przed limitem readiness nadal czeka na sondę.
    let settled = false;
    void pending.then(() => {
      settled = true;
    });
    await Promise.resolve();
    expect(settled).toBe(false);

    await vi.advanceTimersByTimeAsync(1);

    await expect(pending).resolves.toEqual({
      status: 'unavailable',
      checks: { database: 'down' },
    });
    const logged = JSON.stringify(warnSpy.mock.calls[0]);
    expect(logged).toContain('ReadinessTimeoutError');
    expect(logged).toContain(`timed out after ${READINESS_TIMEOUT_MS} ms`);
  });
});
