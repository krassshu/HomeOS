import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const envFile = path.join(root, '.env');
const composeFile = path.join(root, 'infra/dev/compose.yaml');
const composeProject = 'homeintelcore-local';
const volumeName = `${composeProject}-core-db-data`;

const args = process.argv.slice(2);
const confirmed = args.length === 2 && args[0] === '--confirm' && args[1] === composeProject;

if (!confirmed) {
  console.error(
    [
      'NIEODWRACALNY reset lokalnej bazy Core.',
      `Usuwa kontenery projektu Compose "${composeProject}" oraz wolumen "${volumeName}"`,
      'razem ze wszystkimi danymi lokalnej bazy Core. Nie ma z tego kopii ani cofnięcia.',
      '',
      `Aby wykonać: pnpm db:reset --confirm ${composeProject}`,
    ].join('\n'),
  );
  process.exit(1);
}

if (!fs.existsSync(envFile)) {
  console.error(
    'Brak root .env — Compose nie rozwiąże nazwy projektu. Uruchom najpierw pnpm dev:setup.',
  );
  process.exit(1);
}

function run(command, commandArgs, options = {}) {
  const result = spawnSync(command, commandArgs, { cwd: root, encoding: 'utf8', ...options });
  if (result.error) {
    console.error(`Nie udało się uruchomić ${command}: ${result.error.message}`);
    process.exit(1);
  }
  return result;
}

const inspect = run('docker', [
  'volume',
  'inspect',
  volumeName,
  '--format',
  '{{ index .Labels "com.docker.compose.project" }}',
]);

if (inspect.status !== 0) {
  console.log(`Wolumen ${volumeName} nie istnieje — nie ma czego resetować.`);
  process.exit(0);
}

const ownerProject = inspect.stdout.trim();
if (ownerProject !== composeProject) {
  console.error(
    `Odmowa: wolumen ${volumeName} ma etykietę projektu "${ownerProject}", oczekiwano "${composeProject}".`,
  );
  process.exit(1);
}

const down = run(
  'docker',
  ['compose', '--env-file', envFile, '-f', composeFile, 'down', '--volumes', '--remove-orphans'],
  { stdio: 'inherit' },
);
process.exit(down.status ?? 1);
