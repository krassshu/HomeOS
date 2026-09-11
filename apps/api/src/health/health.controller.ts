import { Controller, Get, Inject, ServiceUnavailableException } from '@nestjs/common';

import { SERVICE_NAME } from '../common/logging/logger.js';
import { ReadinessService } from './readiness.service.js';
import type { ReadinessResult } from './readiness.service.js';

export interface LivenessResponse {
  readonly service: typeof SERVICE_NAME;
  readonly status: 'ok';
}

export interface ReadinessResponse extends ReadinessResult {
  readonly service: typeof SERVICE_NAME;
}

@Controller('health')
export class HealthController {
  constructor(@Inject(ReadinessService) private readonly readiness: ReadinessService) {}

  // Liveness mówi tylko, że proces odpowiada; celowo nie dotyka bazy.
  @Get('live')
  getLiveness(): LivenessResponse {
    return { service: SERVICE_NAME, status: 'ok' };
  }

  @Get('ready')
  async getReadiness(): Promise<ReadinessResponse> {
    const result = await this.readiness.check();
    const response: ReadinessResponse = { service: SERVICE_NAME, ...result };
    if (result.status !== 'ok') {
      throw new ServiceUnavailableException(response);
    }
    return response;
  }
}
