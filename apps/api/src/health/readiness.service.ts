import { Inject, Injectable, Logger } from '@nestjs/common';

import { APP_CONFIG } from '../config/config.module.js';
import type { AppConfig } from '../config/app-config.js';
import { describeError } from '../common/logging/logger.js';
import { DATABASE_PROBE } from '../common/ports/database-probe.js';
import type { DatabaseProbe } from '../common/ports/database-probe.js';

export type ReadinessStatus = 'ok' | 'unavailable';

export interface ReadinessResult {
  readonly status: ReadinessStatus;
  readonly checks: { readonly database: 'up' | 'down' };
}

class ReadinessTimeoutError extends Error {
  constructor(timeoutMs: number) {
    super(`database probe timed out after ${timeoutMs} ms`);
    this.name = 'ReadinessTimeoutError';
  }
}

async function withTimeout<T>(work: Promise<T>, timeoutMs: number): Promise<T> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new ReadinessTimeoutError(timeoutMs)), timeoutMs);
  });
  try {
    return await Promise.race([work, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

@Injectable()
export class ReadinessService {
  private readonly logger = new Logger(ReadinessService.name);

  constructor(
    @Inject(DATABASE_PROBE) private readonly database: DatabaseProbe,
    @Inject(APP_CONFIG) private readonly config: AppConfig,
  ) {}

  async check(): Promise<ReadinessResult> {
    try {
      await withTimeout(this.database.ping(), this.config.readinessTimeoutMs);
      return { status: 'ok', checks: { database: 'up' } };
    } catch (error: unknown) {
      // Techniczna przyczyna zostaje w logu; odpowiedź HTTP jest anonimowa.
      this.logger.warn({ reason: describeError(error), check: 'database' });
      return { status: 'unavailable', checks: { database: 'down' } };
    }
  }
}
