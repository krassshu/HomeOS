import { Module } from '@nestjs/common';

import { DATABASE_PROBE } from '../../common/ports/database-probe.js';
import { PrismaService } from './prisma.service.js';

@Module({
  providers: [PrismaService, { provide: DATABASE_PROBE, useExisting: PrismaService }],
  exports: [DATABASE_PROBE],
})
export class PersistenceModule {}
