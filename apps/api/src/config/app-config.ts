export const LOG_LEVELS = ['fatal', 'error', 'warn', 'info', 'debug', 'trace'] as const;
export type LogLevel = (typeof LOG_LEVELS)[number];

export const ENVIRONMENTS = ['development', 'test', 'production'] as const;
export type Environment = (typeof ENVIRONMENTS)[number];

export interface AppConfig {
  readonly environment: Environment;
  readonly host: string;
  readonly port: number;
  readonly databaseUrl: string;
  readonly logLevel: LogLevel;
  readonly readinessTimeoutMs: number;
  readonly shutdownTimeoutMs: number;
}

export type EnvSource = Readonly<Record<string, string | undefined>>;

export class ConfigValidationError extends Error {
  constructor(readonly problems: readonly string[]) {
    super(`Invalid configuration:\n- ${problems.join('\n- ')}`);
    this.name = 'ConfigValidationError';
  }
}

const DEFAULTS = {
  environment: 'development',
  host: '127.0.0.1',
  port: 3000,
  logLevel: 'info',
  readinessTimeoutMs: 2_000,
  shutdownTimeoutMs: 10_000,
} as const;

// Placeholdery z .env.example i infra/homelab/.env.example; nie mogą trafić do runtime.
const SECRET_PLACEHOLDERS = ['__GENERATED_BY_DEV_SETUP__', '__SET_ME__'];
const DATABASE_URL_PROTOCOLS = ['postgresql:', 'postgres:'];
const MAX_PORT = 65_535;

function readEnum<T extends string>(
  problems: string[],
  name: string,
  raw: string | undefined,
  allowed: readonly T[],
  fallback: T,
): T {
  if (raw === undefined || raw === '') return fallback;
  if ((allowed as readonly string[]).includes(raw)) return raw as T;
  problems.push(`${name} must be one of: ${allowed.join(', ')}`);
  return fallback;
}

function readInteger(
  problems: string[],
  name: string,
  raw: string | undefined,
  fallback: number,
  min: number,
  max: number,
): number {
  if (raw === undefined || raw === '') return fallback;
  if (!/^\d+$/.test(raw)) {
    problems.push(`${name} must be an integer between ${min} and ${max}`);
    return fallback;
  }
  const value = Number(raw);
  if (value < min || value > max) {
    problems.push(`${name} must be an integer between ${min} and ${max}`);
    return fallback;
  }
  return value;
}

function readHost(problems: string[], raw: string | undefined): string {
  if (raw === undefined || raw === '') return DEFAULTS.host;
  if (/\s/.test(raw)) {
    problems.push('HOST must not contain whitespace');
    return DEFAULTS.host;
  }
  return raw;
}

// Komunikaty celowo nie cytują wartości: URL zawiera hasło.
function readDatabaseUrl(problems: string[], raw: string | undefined): string {
  if (raw === undefined || raw === '') {
    problems.push('DATABASE_URL is required');
    return '';
  }
  if (SECRET_PLACEHOLDERS.some((placeholder) => raw.includes(placeholder))) {
    problems.push(
      'DATABASE_URL still contains a placeholder; run `pnpm dev:setup` or set a real value',
    );
    return '';
  }

  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    problems.push('DATABASE_URL is not a valid URL');
    return '';
  }

  if (!DATABASE_URL_PROTOCOLS.includes(url.protocol)) {
    problems.push('DATABASE_URL must use the postgresql:// scheme');
  }
  if (url.hostname === '') {
    problems.push('DATABASE_URL must include a host');
  }
  if (url.port !== '' && (Number(url.port) < 1 || Number(url.port) > MAX_PORT)) {
    problems.push(`DATABASE_URL port must be between 1 and ${MAX_PORT}`);
  }
  if (url.pathname.length < 2) {
    problems.push('DATABASE_URL must include a database name');
  }
  return raw;
}

export function loadAppConfig(env: EnvSource): AppConfig {
  const problems: string[] = [];

  const config: AppConfig = {
    environment: readEnum(
      problems,
      'NODE_ENV',
      env['NODE_ENV'],
      ENVIRONMENTS,
      DEFAULTS.environment,
    ),
    host: readHost(problems, env['HOST']),
    port: readInteger(problems, 'PORT', env['PORT'], DEFAULTS.port, 1, MAX_PORT),
    databaseUrl: readDatabaseUrl(problems, env['DATABASE_URL']),
    logLevel: readEnum(problems, 'LOG_LEVEL', env['LOG_LEVEL'], LOG_LEVELS, DEFAULTS.logLevel),
    readinessTimeoutMs: readInteger(
      problems,
      'READINESS_TIMEOUT_MS',
      env['READINESS_TIMEOUT_MS'],
      DEFAULTS.readinessTimeoutMs,
      100,
      60_000,
    ),
    shutdownTimeoutMs: readInteger(
      problems,
      'SHUTDOWN_TIMEOUT_MS',
      env['SHUTDOWN_TIMEOUT_MS'],
      DEFAULTS.shutdownTimeoutMs,
      1_000,
      300_000,
    ),
  };

  if (problems.length > 0) {
    throw new ConfigValidationError(problems);
  }
  return config;
}
