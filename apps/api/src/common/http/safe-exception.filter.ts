import { Catch, HttpException } from '@nestjs/common';
import type { ArgumentsHost, ExceptionFilter } from '@nestjs/common';
import type { ServerResponse } from 'node:http';
import type { Logger } from 'pino';

import { CORRELATION_ID_HEADER, getCorrelationId } from '../correlation/correlation-context.js';
import { describeError, redactSecrets } from '../logging/logger.js';

const INTERNAL_SERVER_ERROR = 500;

// Nieznane wyjątki dostają stałą, anonimową odpowiedź; szczegóły idą wyłącznie do logu.
@Catch()
export class SafeExceptionFilter implements ExceptionFilter {
  constructor(private readonly logger: Logger) {}

  catch(exception: unknown, host: ArgumentsHost): void {
    const response = host.switchToHttp().getResponse<ServerResponse>();
    const correlationId = getCorrelationId();

    let statusCode: number;
    let body: unknown;

    if (exception instanceof HttpException) {
      statusCode = exception.getStatus();
      body =
        statusCode === INTERNAL_SERVER_ERROR
          ? { statusCode, error: 'Internal Server Error' }
          : exception.getResponse();
      // Wyjątki HTTP < 500 są oczekiwane; 503 readiness loguje już ReadinessService.
      if (statusCode === INTERNAL_SERVER_ERROR) {
        this.logger.error({ err: describeError(exception), statusCode }, 'request failed');
      }
    } else {
      statusCode = INTERNAL_SERVER_ERROR;
      body = { statusCode, error: 'Internal Server Error' };
      this.logger.error(
        {
          err: describeError(exception),
          stack: exception instanceof Error ? redactSecrets(exception.stack ?? '') : undefined,
        },
        'unhandled exception',
      );
    }

    const payload =
      typeof body === 'object' && body !== null && correlationId !== undefined
        ? { ...body, correlationId }
        : body;

    if (correlationId !== undefined && !response.headersSent) {
      response.setHeader(CORRELATION_ID_HEADER, correlationId);
    }
    response.statusCode = statusCode;
    response.setHeader('content-type', 'application/json; charset=utf-8');
    response.end(JSON.stringify(payload));
  }
}
