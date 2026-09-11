import { spawn } from 'node:child_process';
import { existsSync } from 'node:fs';
import path from 'node:path';
import process from 'node:process';

// Wczytuje root .env (jeśli istnieje) i uruchamia podane polecenie z tym środowiskiem.
const root = path.resolve(import.meta.dirname, '..');
const envFile = path.join(root, '.env');
if (existsSync(envFile)) {
  process.loadEnvFile(envFile);
}

const [command, ...args] = process.argv.slice(2);
if (!command) {
  process.stderr.write('Użycie: node scripts/with-env.mjs <polecenie> [argumenty]\n');
  process.exit(2);
}

const child = spawn(command, args, { stdio: 'inherit', env: process.env });

// Sygnały zakończenia idą do dziecka, żeby API mogło zamknąć się łagodnie.
for (const signal of ['SIGTERM', 'SIGINT', 'SIGHUP']) {
  process.on(signal, () => child.kill(signal));
}

child.on('exit', (code, signal) => {
  process.exit(code ?? (signal ? 1 : 0));
});
