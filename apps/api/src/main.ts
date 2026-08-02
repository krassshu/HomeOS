import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module.js';

function readPort(value: string | undefined): number {
  const port = Number(value ?? '3000');

  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error('PORT must be an integer between 1 and 65535');
  }

  return port;
}

async function bootstrap(): Promise<void> {
  const app = await NestFactory.create(AppModule);
  const host = process.env.HOST ?? '127.0.0.1';
  const port = readPort(process.env.PORT);

  app.setGlobalPrefix('api/v1');
  app.enableShutdownHooks();

  await app.listen(port, host);
}

bootstrap().catch((error: unknown) => {
  const message = error instanceof Error ? (error.stack ?? error.message) : String(error);
  process.stderr.write(`${message}\n`);
  process.exitCode = 1;
});
