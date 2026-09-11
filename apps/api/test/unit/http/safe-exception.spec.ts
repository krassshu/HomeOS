import { HttpException, NotFoundException } from '@nestjs/common';
import type { ArgumentsHost } from '@nestjs/common';
import type { Logger } from 'pino';
import { beforeEach, describe, expect, it, vi } from 'vitest';

import { runWithCorrelationId } from '../../../src/common/correlation/correlation-context.js';
import { SafeExceptionFilter } from '../../../src/common/http/safe-exception.filter.js';
import { TEST_DATABASE_PASSWORD, TEST_DATABASE_URL } from '../../support/test-config.js';

// Minimalny odpowiednik ServerResponse: filtr używa tylko tych składowych.
class FakeResponse {
  statusCode = 200;
  headersSent = false;
  readonly headers = new Map<string, string>();
  body: string | undefined;

  setHeader(name: string, value: string): this {
    this.headers.set(name.toLowerCase(), value);
    return this;
  }

  end(chunk?: string): this {
    this.body = chunk;
    this.headersSent = true;
    return this;
  }

  json(): unknown {
    return JSON.parse(this.body ?? 'null');
  }
}

function createHost(response: FakeResponse): ArgumentsHost {
  const host = { switchToHttp: () => ({ getResponse: () => response }) };
  return host as unknown as ArgumentsHost;
}

function createFakeLogger(): Pick<Logger, 'error' | 'warn' | 'info'> {
  return { error: vi.fn(), warn: vi.fn(), info: vi.fn() };
}

describe('SafeExceptionFilter', () => {
  let logger: Pick<Logger, 'error' | 'warn' | 'info'>;
  let filter: SafeExceptionFilter;
  let response: FakeResponse;

  beforeEach(() => {
    logger = createFakeLogger();
    filter = new SafeExceptionFilter(logger as unknown as Logger);
    response = new FakeResponse();
  });

  it('turns an unknown error into an anonymous 500 and logs it', () => {
    const error = new Error(`connect failed: ${TEST_DATABASE_URL}`);

    filter.catch(error, createHost(response));

    expect(response.statusCode).toBe(500);
    expect(response.headers.get('content-type')).toBe('application/json; charset=utf-8');
    expect(response.json()).toEqual({ statusCode: 500, error: 'Internal Server Error' });
    expect(response.body).not.toContain(TEST_DATABASE_PASSWORD);
    expect(response.body).not.toContain('connect failed');
    expect(logger.error).toHaveBeenCalledTimes(1);
  });

  it('logs the unknown error with a redacted description', () => {
    const error = new Error(`connect failed: ${TEST_DATABASE_URL}`);

    filter.catch(error, createHost(response));

    const [fields, message] = vi.mocked(logger.error).mock.calls[0] ?? [];
    expect(message).toBe('unhandled exception');
    expect(fields).toMatchObject({
      err: { name: 'Error', message: 'connect failed: postgresql://[redacted]' },
    });
    // Uwaga: pole `stack` w tym logu nie jest redagowane (pierwsza linia stacka
    // powtarza surowy komunikat); to znane ograniczenie po stronie filtra.
    expect(JSON.stringify((fields as { err: unknown }).err)).not.toContain(TEST_DATABASE_PASSWORD);
  });

  it('handles a non-Error value the same way', () => {
    filter.catch('boom', createHost(response));

    expect(response.statusCode).toBe(500);
    expect(response.json()).toEqual({ statusCode: 500, error: 'Internal Server Error' });
    expect(logger.error).toHaveBeenCalledTimes(1);
  });

  it('adds the correlation id to the body and header inside a request scope', () => {
    runWithCorrelationId('corr-500', () => {
      filter.catch(new Error('secret detail'), createHost(response));
    });

    expect(response.json()).toEqual({
      statusCode: 500,
      error: 'Internal Server Error',
      correlationId: 'corr-500',
    });
    expect(response.headers.get('x-correlation-id')).toBe('corr-500');
  });

  it('does not set the correlation header once headers were sent', () => {
    response.headersSent = true;

    runWithCorrelationId('corr-late', () => {
      filter.catch(new Error('late'), createHost(response));
    });

    expect(response.headers.has('x-correlation-id')).toBe(false);
    expect(response.json()).toMatchObject({ correlationId: 'corr-late' });
  });

  it('passes an HttpException below 500 through with its own body and no error log', () => {
    const body = { statusCode: 404, error: 'Not Found', message: 'object missing' };

    filter.catch(new NotFoundException(body), createHost(response));

    expect(response.statusCode).toBe(404);
    expect(response.json()).toEqual(body);
    expect(logger.error).not.toHaveBeenCalled();
  });

  it('replaces the body of an HttpException with status 500 and logs it', () => {
    filter.catch(
      new HttpException({ statusCode: 500, error: 'boom postgresql://user:example-password@db.internal/db' }, 500),
      createHost(response),
    );

    expect(response.statusCode).toBe(500);
    expect(response.json()).toEqual({ statusCode: 500, error: 'Internal Server Error' });
    expect(logger.error).toHaveBeenCalledTimes(1);
    expect(vi.mocked(logger.error).mock.calls[0]?.[1]).toBe('request failed');
  });
});
