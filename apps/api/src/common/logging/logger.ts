import { destination, pino } from 'pino';
import type { Logger } from 'pino';

import type { Environment, LogLevel } from '../../config/app-config.js';
import { getCorrelationId } from '../correlation/correlation-context.js';

export const SERVICE_NAME = 'homeintelcore-api';

export interface RootLoggerOptions {
  readonly level: LogLevel;
  readonly environment: Environment;
}

// Ścieżki, które nigdy nie mogą trafić do logów, nawet gdy ktoś zaloguje cały obiekt konfiguracji.
const REDACTED_PATHS = [
  'databaseUrl',
  '*.databaseUrl',
  'DATABASE_URL',
  '*.DATABASE_URL',
  'password',
  '*.password',
  'connectionString',
  '*.connectionString',
];

export function createRootLogger(options: RootLoggerOptions): Logger {
  return pino(
    {
      level: options.level,
      base: { service: SERVICE_NAME, environment: options.environment },
      timestamp: pino.stdTimeFunctions.isoTime,
      redact: { paths: REDACTED_PATHS, censor: '[redacted]' },
      mixin: () => {
        const correlationId = getCorrelationId();
        return correlationId === undefined ? {} : { correlationId };
      },
    },
    // Zapis synchroniczny: logi shutdownu nie giną przy process.exit.
    destination({ fd: 1, sync: true }),
  );
}

// Komunikaty sterownika mogą zawierać URL z hasłem; zostawiamy tylko bezpieczny opis.
export function describeError(error: unknown): Record<string, unknown> {
  if (!(error instanceof Error)) {
    return { name: 'UnknownError', message: redactSecrets(String(error)) };
  }
  const code = (error as { code?: unknown }).code;
  return {
    name: error.name,
    message: redactSecrets(error.message),
    ...(typeof code === 'string' ? { code } : {}),
  };
}

const URL_WITH_CREDENTIALS = /(postgres(?:ql)?:\/\/)[^\s]+/gi;

export function redactSecrets(text: string): string {
  return text.replace(URL_WITH_CREDENTIALS, '$1[redacted]');
}
