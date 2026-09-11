import { Module } from '@nestjs/common';

import { PersistenceModule } from '../infrastructure/persistence/persistence.module.js';
import { HealthController } from './health.controller.js';
import { ReadinessService } from './readiness.service.js';

// Health zna tylko port DATABASE_PROBE; implementację dostarcza PersistenceModule.
@Module({
  imports: [PersistenceModule],
  controllers: [HealthController],
  providers: [ReadinessService],
})
export class HealthModule {}
