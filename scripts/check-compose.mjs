import { execFileSync } from 'node:child_process';
import path from 'node:path';
import process from 'node:process';

// Statyczna kontrola obu plików Compose: obrazy z digestem, porty tylko na loopback,
// brak socketu Dockera i sieci zewnętrznych. Nie uruchamia kontenerów.
const root = path.resolve(import.meta.dirname, '..');
const composeFiles = ['infra/dev/compose.yaml', 'infra/homelab/compose.yaml'];
const placeholderEnv = {
  ...process.env,
  HOMEINTELCORE_DB_USER: 'check',
  HOMEINTELCORE_DB_NAME: 'check',
  HOMEINTELCORE_DB_PASSWORD: 'check-only-not-a-secret',
};
const violations = [];

function renderConfig(file) {
  const output = execFileSync(
    'docker',
    ['compose', '-f', file, '--env-file', '/dev/null', 'config', '--format', 'json'],
    { cwd: root, env: placeholderEnv, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] },
  );
  return JSON.parse(output);
}

for (const file of composeFiles) {
  const config = renderConfig(file);

  for (const [name, service] of Object.entries(config.services ?? {})) {
    const where = `${file} → ${name}`;
    const image = typeof service.image === 'string' ? service.image : '';

    if (service.build === undefined && !/@sha256:[0-9a-f]{64}$/.test(image)) {
      violations.push(`${where}: obraz bez digestu (${image || 'brak image'})`);
    }
    if (/:latest(@|$)/.test(image)) violations.push(`${where}: tag latest`);

    for (const port of service.ports ?? []) {
      const hostIp = typeof port === 'object' ? port.host_ip : undefined;
      if (hostIp !== '127.0.0.1') {
        violations.push(`${where}: port opublikowany poza 127.0.0.1 (${JSON.stringify(port)})`);
      }
    }

    for (const volume of service.volumes ?? []) {
      const source = typeof volume === 'object' ? String(volume.source ?? '') : String(volume);
      if (source.includes('docker.sock')) violations.push(`${where}: montowanie socketu Dockera`);
      if (source.startsWith('/srv/homeos')) violations.push(`${where}: montowanie danych M3`);
    }

    if (Object.keys(service.networks ?? {}).some((network) => network.startsWith('homeos-m3'))) {
      violations.push(`${where}: sieć laboratorium M3`);
    }
  }

  for (const [name, network] of Object.entries(config.networks ?? {})) {
    if (network?.external === true) violations.push(`${file}: sieć zewnętrzna ${name}`);
  }
}

if (violations.length > 0) {
  console.error('Naruszenia w plikach Compose:');
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log(
  `OK: ${composeFiles.length} plików Compose, obrazy z digestem, porty tylko na 127.0.0.1`,
);
