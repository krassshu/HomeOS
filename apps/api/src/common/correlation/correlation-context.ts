import { AsyncLocalStorage } from 'node:async_hooks';
import { randomUUID } from 'node:crypto';

export const CORRELATION_ID_HEADER = 'x-correlation-id';

const CORRELATION_ID_PATTERN = /^[A-Za-z0-9._:-]{1,128}$/;

interface CorrelationStore {
  readonly correlationId: string;
}

const storage = new AsyncLocalStorage<CorrelationStore>();

export function getCorrelationId(): string | undefined {
  return storage.getStore()?.correlationId;
}

export function runWithCorrelationId<T>(correlationId: string, fn: () => T): T {
  return storage.run({ correlationId }, fn);
}

// Nagłówek klienta jest akceptowany tylko w bezpiecznym formacie; inaczej generujemy własny.
export function resolveCorrelationId(incoming: string | string[] | undefined): string {
  const candidate = Array.isArray(incoming) ? incoming[0] : incoming;
  if (candidate !== undefined && CORRELATION_ID_PATTERN.test(candidate)) {
    return candidate;
  }
  return randomUUID();
}
