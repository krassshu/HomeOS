import type { AddressInfo } from 'node:net';

import type { INestApplication } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { pino } from 'pino';
import type { Logger } from 'pino';

import { AppModule } from '../../src/app.module.js';
import { createRequestContextMiddleware } from '../../src/common/correlation/request-context.middleware.js';
import { SafeExceptionFilter } from '../../src/common/http/safe-exception.filter.js';
import { loadAppConfig } from '../../src/config/app-config.js';
import type { EnvSource } from '../../src/config/app-config.js';

export interface TestApp {
  readonly app: INestApplication;
  readonly baseUrl: string;
  readonly port: number;
  close(): Promise<void>;
}

// Ten sam skład co bootstrap w main.ts, ale na cichym pino i losowym porcie 127.0.0.1.
export async function startTestApp(env: EnvSource, logger?: Logger): Promise<TestApp> {
  const config = loadAppConfig(env);
  const rootLogger = logger ?? pino({ level: 'silent' });

  const app = await NestFactory.create(AppModule.forRoot(config), { logger: false });
  app.setGlobalPrefix('api/v1');
  app.use(createRequestContextMiddleware(rootLogger));
  app.useGlobalFilters(new SafeExceptionFilter(rootLogger));

  await app.listen(0, '127.0.0.1');
  const address = (app.getHttpServer() as { address(): AddressInfo | string | null }).address();
  if (address === null || typeof address === 'string') {
    await app.close();
    throw new Error('test app did not bind to a TCP port');
  }

  return {
    app,
    port: address.port,
    baseUrl: `http://127.0.0.1:${address.port}/api/v1`,
    close: () => app.close(),
  };
}
