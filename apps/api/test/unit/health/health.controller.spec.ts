import { Logger, ServiceUnavailableException } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { afterAll, beforeAll, beforeEach, describe, expect, it, vi } from 'vitest';

import { DATABASE_PROBE } from '../../../src/common/ports/database-probe.js';
import type { DatabaseProbe } from '../../../src/common/ports/database-probe.js';
import { APP_CONFIG } from '../../../src/config/config.module.js';
import { HealthController } from '../../../src/health/health.controller.js';
import { ReadinessService } from '../../../src/health/readiness.service.js';
import {
  createTestConfig,
  TEST_DATABASE_PASSWORD,
  TEST_DATABASE_URL,
} from '../../support/test-config.js';

describe('HealthController', () => {
  const ping = vi.fn<DatabaseProbe['ping']>();
  const probe: DatabaseProbe = { ping };
  let controller: HealthController;

  beforeAll(async () => {
    Logger.overrideLogger(false);
    const moduleRef = await Test.createTestingModule({
      controllers: [HealthController],
      providers: [
        ReadinessService,
        { provide: DATABASE_PROBE, useValue: probe },
        { provide: APP_CONFIG, useValue: createTestConfig({ readinessTimeoutMs: 200 }) },
      ],
    }).compile();
    controller = moduleRef.get(HealthController);
  });

  beforeEach(() => {
    ping.mockReset();
  });

  afterAll(() => {
    Logger.overrideLogger(true);
  });

  it('reports liveness without touching the database', () => {
    expect(controller.getLiveness()).toEqual({ service: 'homeintelcore-api', status: 'ok' });
    expect(ping).not.toHaveBeenCalled();
  });

  it('reports full readiness when the database probe succeeds', async () => {
    ping.mockResolvedValue(undefined);

    await expect(controller.getReadiness()).resolves.toEqual({
      service: 'homeintelcore-api',
      status: 'ok',
      checks: { database: 'up' },
    });
    expect(ping).toHaveBeenCalledTimes(1);
  });

  it('throws ServiceUnavailableException with an anonymous body when the probe fails', async () => {
    ping.mockRejectedValue(new Error(`DATABASE_URL rejected: ${TEST_DATABASE_URL}`));

    const thrown: unknown = await controller.getReadiness().then(
      () => undefined,
      (error: unknown) => error,
    );

    expect(thrown).toBeInstanceOf(ServiceUnavailableException);
    const exception = thrown as ServiceUnavailableException;
    expect(exception.getStatus()).toBe(503);
    expect(exception.getResponse()).toEqual({
      service: 'homeintelcore-api',
      status: 'unavailable',
      checks: { database: 'down' },
    });

    const serialized = JSON.stringify(exception.getResponse());
    expect(serialized).not.toContain('DATABASE_URL');
    expect(serialized).not.toContain(TEST_DATABASE_PASSWORD);
    expect(serialized).not.toContain('postgresql://');
  });
});
