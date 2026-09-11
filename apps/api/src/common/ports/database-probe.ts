export const DATABASE_PROBE = Symbol('DATABASE_PROBE');

// Port dla readiness: infrastruktura go implementuje, health tylko z niego korzysta.
export interface DatabaseProbe {
  ping(): Promise<void>;
}
