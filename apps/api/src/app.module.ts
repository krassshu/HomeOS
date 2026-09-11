import { Module } from '@nestjs/common';
import type { DynamicModule } from '@nestjs/common';

import { ConfigModule } from './config/config.module.js';
import type { AppConfig } from './config/app-config.js';
import { HealthModule } from './health/health.module.js';

@Module({})
export class AppModule {
  static forRoot(config: AppConfig): DynamicModule {
    return {
      module: AppModule,
      imports: [ConfigModule.forRoot(config), HealthModule],
    };
  }
}
