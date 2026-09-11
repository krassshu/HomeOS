import { Inject, Injectable, Logger } from '@nestjs/common';
import type { OnModuleDestroy } from '@nestjs/common';

import { APP_CONFIG } from '../../config/config.module.js';
import type { AppConfig } from '../../config/app-config.js';
import type { DatabaseProbe } from '../../common/ports/database-probe.js';
import { createPrismaClient } from './prisma-client.factory.js';
import type { CorePrismaClient } from './prisma-client.factory.js';

@Injectable()
export class PrismaService implements DatabaseProbe, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);
  private readonly client: CorePrismaClient;

  constructor(@Inject(APP_CONFIG) config: AppConfig) {
    // Klient łączy się leniwie: start API nie zależy od dostępności bazy.
    this.client = createPrismaClient(config.databaseUrl);
  }

  async ping(): Promise<void> {
    await this.client.$queryRaw`SELECT 1`;
  }

  async onModuleDestroy(): Promise<void> {
    await this.client.$disconnect();
    this.logger.log('database client disconnected');
  }
}
