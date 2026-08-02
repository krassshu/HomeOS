import { Controller, Get } from '@nestjs/common';

export interface HealthResponse {
  service: 'homeos-api';
  status: 'ok';
}

@Controller('health')
export class HealthController {
  @Get('live')
  getLiveness(): HealthResponse {
    return {
      service: 'homeos-api',
      status: 'ok',
    };
  }
}
