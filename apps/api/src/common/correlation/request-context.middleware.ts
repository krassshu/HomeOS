import type { IncomingMessage, ServerResponse } from 'node:http';

import type { Logger } from 'pino';

import {
  CORRELATION_ID_HEADER,
  resolveCorrelationId,
  runWithCorrelationId,
} from './correlation-context.js';

type NextFunction = (error?: unknown) => void;

export type RequestContextMiddleware = (
  req: IncomingMessage,
  res: ServerResponse,
  next: NextFunction,
) => void;

// Jedno middleware: nadaje correlation ID i loguje zakończenie żądania.
export function createRequestContextMiddleware(logger: Logger): RequestContextMiddleware {
  return (req, res, next) => {
    const correlationId = resolveCorrelationId(req.headers[CORRELATION_ID_HEADER]);
    res.setHeader(CORRELATION_ID_HEADER, correlationId);

    const startedAt = process.hrtime.bigint();

    runWithCorrelationId(correlationId, () => {
      res.on('finish', () => {
        const durationMs = Number(process.hrtime.bigint() - startedAt) / 1_000_000;
        logger.info(
          {
            method: req.method,
            path: req.url?.split('?')[0],
            statusCode: res.statusCode,
            durationMs: Math.round(durationMs * 1000) / 1000,
          },
          'request completed',
        );
      });
      next();
    });
  };
}
