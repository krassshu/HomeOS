import { execFileSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const maxScannedBytes = 2 * 1024 * 1024;
const violations = [];

const forbiddenPaths = [
  { name: 'plik .env', test: (p) => /(^|\/)\.env(\..+)?$/.test(p) && !p.endsWith('.example') },
  { name: 'klucz lub certyfikat', test: (p) => /\.(key|pem|p12|pfx|token)$/.test(p) },
  { name: 'klucz SSH', test: (p) => /(^|\/)(id_rsa|id_ed25519)[^/]*$/.test(p) },
  { name: '.DS_Store', test: (p) => /(^|\/)\.DS_Store$/.test(p) },
  {
    name: 'katalog artefaktów',
    test: (p) => /(^|\/)(node_modules|dist|coverage|sbom|\.idea|\.vscode)\//.test(p),
  },
  { name: 'log lub cache TS', test: (p) => /\.(log|tsbuildinfo)$/.test(p) },
  {
    name: 'wygenerowany Prisma Client',
    test: (p) => p.startsWith('apps/api/src/infrastructure/persistence/generated/'),
  },
  { name: 'zrzut bazy', test: (p) => /\.(dump|sql\.gz)$/.test(p) },
];

const placeholderPasswords = ['__GENERATED_BY_DEV_SETUP__', '__SET_ME__'];
const placeholderWords = ['password', 'changeme', 'example'];

function isPlaceholderPassword(password) {
  if (placeholderPasswords.includes(password)) return true;
  if (password.startsWith('<') && password.endsWith('>')) return true;
  // Podstawienia shell/printf/szablonów (${VAR}, %s, {{ x }}) nie są literalnym hasłem.
  if (/^(\$|%|\{\{)/.test(password)) return true;
  const lower = password.toLowerCase();
  return placeholderWords.some((word) => lower.includes(word));
}

const contentPatterns = [
  {
    name: 'URL PostgreSQL z hasłem',
    regex: /postgres(?:ql)?:\/\/[^:\s]+:([^@\s]+)@/g,
    accept: (match) => !isPlaceholderPassword(match[1] ?? ''),
  },
  { name: 'klucz AWS', regex: /AKIA[0-9A-Z]{16}/g },
  { name: 'token GitHub', regex: /gh[po]_[A-Za-z0-9]{36}/g },
  { name: 'klucz prywatny', regex: /-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----/g },
  { name: 'token Slack', regex: /xox[baprs]-/g },
];

function isBinary(buffer) {
  return buffer.subarray(0, 8192).includes(0);
}

function scanContent(relative) {
  if (relative === 'pnpm-lock.yaml') return;
  const file = path.join(root, relative);
  if (!fs.existsSync(file) || !fs.statSync(file).isFile()) return;
  if (fs.statSync(file).size > maxScannedBytes) return;

  const buffer = fs.readFileSync(file);
  if (isBinary(buffer)) return;

  const lines = buffer.toString('utf8').split('\n');
  lines.forEach((line, index) => {
    for (const pattern of contentPatterns) {
      for (const match of line.matchAll(pattern.regex)) {
        if (pattern.accept && !pattern.accept(match)) continue;
        // Celowo bez treści dopasowania — sekret nie może trafić do logu CI.
        violations.push(`${relative}:${index + 1}: ${pattern.name}`);
      }
    }
  });
}

const tracked = execFileSync('git', ['ls-files', '-z'], { cwd: root, encoding: 'utf8' })
  .split('\0')
  .filter((entry) => entry.length > 0);

for (const relative of tracked) {
  for (const rule of forbiddenPaths) {
    if (rule.test(relative)) violations.push(`${relative}: niedozwolony plik w Git (${rule.name})`);
  }
  scanContent(relative);
}

if (violations.length > 0) {
  console.error('Naruszenia wśród plików śledzonych przez Git:');
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log(`OK: ${tracked.length} śledzonych plików, brak naruszeń`);
