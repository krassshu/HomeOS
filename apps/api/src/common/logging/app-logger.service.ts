import type { LoggerService } from '@nestjs/common';
import type { Logger } from 'pino';

import { describeError } from './logger.js';

// Adapter Nest LoggerService → pino, żeby logi frameworka miały ten sam format JSON.
export class AppLogger implements LoggerService {
  constructor(private readonly logger: Logger) {}

  log(message: unknown, ...params: unknown[]): void {
    this.write('info', message, params);
  }

  error(message: unknown, ...params: unknown[]): void {
    this.write('error', message, params);
  }

  warn(message: unknown, ...params: unknown[]): void {
    this.write('warn', message, params);
  }

  debug(message: unknown, ...params: unknown[]): void {
    this.write('debug', message, params);
  }

  verbose(message: unknown, ...params: unknown[]): void {
    this.write('trace', message, params);
  }

  fatal(message: unknown, ...params: unknown[]): void {
    this.write('fatal', message, params);
  }

  private write(
    level: 'fatal' | 'error' | 'warn' | 'info' | 'debug' | 'trace',
    message: unknown,
    params: unknown[],
  ): void {
    // Nest przekazuje kontekst (nazwę klasy) jako ostatni parametr tekstowy.
    const context = typeof params.at(-1) === 'string' ? (params.at(-1) as string) : undefined;
    const fields: Record<string, unknown> = context === undefined ? {} : { context };

    if (message instanceof Error) {
      this.logger[level]({ ...fields, err: describeError(message) }, message.message);
      return;
    }
    if (typeof message === 'object' && message !== null) {
      this.logger[level]({ ...fields, ...message });
      return;
    }
    this.logger[level](fields, String(message));
  }
}
