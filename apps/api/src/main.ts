import { NestFactory } from '@nestjs/core';
import type { INestApplication } from '@nestjs/common';
import { destination, pino } from 'pino';
import type { Logger } from 'pino';

import { AppModule } from './app.module.js';
import { createRequestContextMiddleware } from './common/correlation/request-context.middleware.js';
import { SafeExceptionFilter } from './common/http/safe-exception.filter.js';
import { AppLogger } from './common/logging/app-logger.service.js';
import { createRootLogger, describeError, SERVICE_NAME } from './common/logging/logger.js';
import { ConfigValidationError, loadAppConfig } from './config/app-config.js';

const SHUTDOWN_SIGNALS = ['SIGTERM', 'SIGINT'] as const;

function registerShutdownHandlers(app: INestApplication, logger: Logger, timeoutMs: number): void {
  let shuttingDown = false;

  const shutdown = (signal: NodeJS.Signals): void => {
    if (shuttingDown) return;
    shuttingDown = true;
    logger.info({ signal, timeoutMs }, 'shutdown requested');

    // Twardy limit: zawieszone połączenie nie może zablokować zakończenia procesu.
    const deadline = setTimeout(() => {
      logger.error({ timeoutMs }, 'shutdown timed out, exiting forcefully');
      process.exit(1);
    }, timeoutMs);
    deadline.unref();

    app.close().then(
      () => {
        logger.info('shutdown complete');
        process.exit(0);
      },
      (error: unknown) => {
        logger.error({ err: describeError(error) }, 'shutdown failed');
        process.exit(1);
      },
    );
  };

  for (const signal of SHUTDOWN_SIGNALS) {
    process.once(signal, () => shutdown(signal));
  }
}

async function bootstrap(): Promise<void> {
  // Walidacja przed utworzeniem aplikacji: błędna konfiguracja nigdy nie zaczyna nasłuchiwać.
  const config = loadAppConfig(process.env);
  const logger = createRootLogger({ level: config.logLevel, environment: config.environment });

  const app = await NestFactory.create(AppModule.forRoot(config), {
    logger: new AppLogger(logger),
  });

  app.setGlobalPrefix('api/v1');
  app.use(createRequestContextMiddleware(logger));
  app.useGlobalFilters(new SafeExceptionFilter(logger));
  registerShutdownHandlers(app, logger, config.shutdownTimeoutMs);

  await app.listen(config.port, config.host);
  logger.info({ host: config.host, port: config.port }, 'api listening');
}

bootstrap().catch((error: unknown) => {
  const fallbackLogger = pino(
    { base: { service: SERVICE_NAME } },
    destination({ fd: 2, sync: true }),
  );
  if (error instanceof ConfigValidationError) {
    fallbackLogger.fatal({ problems: error.problems }, 'configuration invalid, refusing to start');
  } else {
    fallbackLogger.fatal({ err: describeError(error) }, 'startup failed');
  }
  process.exitCode = 1;
});
