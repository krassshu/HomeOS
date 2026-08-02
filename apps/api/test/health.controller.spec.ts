import { Test } from '@nestjs/testing';
import { describe, expect, it } from 'vitest';

import { HealthController } from '../src/health/health.controller.js';

describe('HealthController', () => {
  it('returns the API liveness state', async () => {
    const moduleRef = await Test.createTestingModule({
      controllers: [HealthController],
    }).compile();

    const controller = moduleRef.get(HealthController);

    expect(controller.getLiveness()).toEqual({
      service: 'homeos-api',
      status: 'ok',
    });
  });
});
