import { spawn } from 'node:child_process';
import type { ChildProcess } from 'node:child_process';
import { existsSync } from 'node:fs';
import { createServer, connect } from 'node:net';
import type { AddressInfo } from 'node:net';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

import { afterEach, describe, expect, it } from 'vitest';

const API_ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const DIST_MAIN = resolve(API_ROOT, 'dist/main.js');

const HOST = '127.0.0.1';
// Port 1 na loopbacku nic nie nasłuchuje; shutdown ma działać także bez bazy.
const DOWN_PASSWORD = 'hic-shutdown-secret';
const DOWN_DATABASE_URL = `postgresql://hic_nobody:${DOWN_PASSWORD}@${HOST}:1/hic_down`;
const MYSQL_DATABASE_URL = `mysql://hic_nobody:${DOWN_PASSWORD}@${HOST}:3306/hic_down`;

const READY_POLL_TIMEOUT_MS = 10_000;
const READY_POLL_INTERVAL_MS = 100;
const EXIT_TIMEOUT_MS = 5_000;

interface ProcessExit {
  readonly code: number | null;
  readonly signal: NodeJS.Signals | null;
}

interface ApiProcess {
  readonly child: ChildProcess;
  readonly exited: Promise<ProcessExit>;
  stdout(): string;
  stderr(): string;
}

async function findFreePort(): Promise<number> {
  return new Promise((resolvePort, reject) => {
    const server = createServer();
    server.once('error', reject);
    server.listen(0, HOST, () => {
      const { port } = server.address() as AddressInfo;
      server.close((error) => (error ? reject(error) : resolvePort(port)));
    });
  });
}

async function isPortOpen(port: number): Promise<boolean> {
  return new Promise((resolveOpen) => {
    const socket = connect({ host: HOST, port });
    socket.once('connect', () => {
      socket.destroy();
      resolveOpen(true);
    });
    socket.once('error', () => resolveOpen(false));
  });
}

function sleep(ms: number): Promise<void> {
  return new Promise((resolveSleep) => setTimeout(resolveSleep, ms));
}

// Środowisko budujemy jawnie: proces nie może odziedziczyć DATABASE_URL z powłoki ani z .env.
function startApi(env: Readonly<Record<string, string>>): ApiProcess {
  const child = spawn(process.execPath, [DIST_MAIN], {
    cwd: API_ROOT,
    env: { PATH: process.env['PATH'] ?? '', ...env },
    stdio: ['ignore', 'pipe', 'pipe'],
  });

  const stdoutChunks: string[] = [];
  const stderrChunks: string[] = [];
  child.stdout?.setEncoding('utf8').on('data', (chunk: string) => stdoutChunks.push(chunk));
  child.stderr?.setEncoding('utf8').on('data', (chunk: string) => stderrChunks.push(chunk));

  const exited = new Promise<ProcessExit>((resolveExit, reject) => {
    child.once('error', reject);
    child.once('exit', (code, signal) => resolveExit({ code, signal }));
  });

  return {
    child,
    exited,
    stdout: () => stdoutChunks.join(''),
    stderr: () => stderrChunks.join(''),
  };
}

async function waitForExit(api: ApiProcess, timeoutMs: number): Promise<ProcessExit> {
  let timer: NodeJS.Timeout | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(
      () => reject(new Error(`process did not exit within ${timeoutMs} ms`)),
      timeoutMs,
    );
  });
  try {
    return await Promise.race([api.exited, timeout]);
  } finally {
    clearTimeout(timer);
  }
}

async function waitForLiveness(api: ApiProcess, port: number): Promise<void> {
  const deadline = Date.now() + READY_POLL_TIMEOUT_MS;
  let exit: ProcessExit | undefined;
  void api.exited.then((result) => {
    exit = result;
  });

  while (Date.now() < deadline) {
    if (exit !== undefined) {
      throw new Error(
        `api exited early (code ${String(exit.code)}, signal ${String(exit.signal)}): ${api.stderr()}`,
      );
    }
    try {
      const response = await fetch(`http://${HOST}:${port}/api/v1/health/live`);
      if (response.status === 200) return;
    } catch {
      // Serwer jeszcze nie nasłuchuje; ponawiamy do upływu limitu.
    }
    await sleep(READY_POLL_INTERVAL_MS);
  }
  throw new Error(`api did not answer liveness within ${READY_POLL_TIMEOUT_MS} ms`);
}

describe('dist/main.js process lifecycle', () => {
  if (!existsSync(DIST_MAIN)) {
    throw new Error(
      `${DIST_MAIN} does not exist; uruchom build: pnpm --filter @homeintelcore/api build`,
    );
  }

  let running: ApiProcess | undefined;

  afterEach(async () => {
    if (running !== undefined && running.child.exitCode === null) {
      running.child.kill('SIGKILL');
      await running.exited;
    }
    running = undefined;
  });

  it('shuts down cleanly on SIGTERM after it started listening (no database)', async () => {
    const port = await findFreePort();
    running = startApi({
      DATABASE_URL: DOWN_DATABASE_URL,
      PORT: String(port),
      HOST,
      LOG_LEVEL: 'warn',
      NODE_ENV: 'test',
    });

    await waitForLiveness(running, port);
    expect(running.child.kill('SIGTERM')).toBe(true);

    const exit = await waitForExit(running, EXIT_TIMEOUT_MS);
    expect(exit).toEqual({ code: 0, signal: null });
    await expect(isPortOpen(port)).resolves.toBe(false);

    const output = running.stdout() + running.stderr();
    expect(output).not.toContain(DOWN_PASSWORD);
    expect(output).not.toContain('DATABASE_URL');
  });

  it('exits with code 1 and never listens when DATABASE_URL is missing', async () => {
    const port = await findFreePort();
    running = startApi({ PORT: String(port), HOST, LOG_LEVEL: 'warn', NODE_ENV: 'test' });

    const exit = await waitForExit(running, EXIT_TIMEOUT_MS);
    expect(exit).toEqual({ code: 1, signal: null });
    await expect(isPortOpen(port)).resolves.toBe(false);

    const stderr = running.stderr();
    expect(stderr).toContain('configuration invalid');
    expect(stderr).toContain('DATABASE_URL is required');
    expect(stderr).not.toMatch(/\n\s+at /);
    expect(stderr).not.toContain('"stack"');
    expect(running.stdout()).toBe('');
  });

  it('exits with code 1 and names the required scheme for a mysql:// DATABASE_URL', async () => {
    const port = await findFreePort();
    running = startApi({
      DATABASE_URL: MYSQL_DATABASE_URL,
      PORT: String(port),
      HOST,
      LOG_LEVEL: 'warn',
      NODE_ENV: 'test',
    });

    const exit = await waitForExit(running, EXIT_TIMEOUT_MS);
    expect(exit).toEqual({ code: 1, signal: null });
    await expect(isPortOpen(port)).resolves.toBe(false);

    const stderr = running.stderr();
    expect(stderr).toContain('configuration invalid');
    expect(stderr).toContain('DATABASE_URL must use the postgresql:// scheme');
    expect(stderr).not.toContain(DOWN_PASSWORD);
    expect(stderr).not.toContain(MYSQL_DATABASE_URL);
    expect(stderr).not.toMatch(/\n\s+at /);
  });
});
