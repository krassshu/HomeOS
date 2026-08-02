import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const docsRoot = path.join(root, 'Docs');
const errors = [];
const markdownFiles = [];

function walk(directory) {
  for (const entry of fs.readdirSync(directory, { withFileTypes: true })) {
    const fullPath = path.join(directory, entry.name);
    if (entry.isDirectory()) walk(fullPath);
    else if (entry.name.endsWith('.md')) markdownFiles.push(fullPath);
  }
}

function report(file, message) {
  errors.push(`${path.relative(root, file)}: ${message}`);
}

walk(docsRoot);

let relativeLinks = 0;
for (const file of markdownFiles) {
  const content = fs.readFileSync(file, 'utf8');

  const fences = content.match(/^\s*```/gm)?.length ?? 0;
  if (fences % 2 !== 0) report(file, 'nieparzysta liczba ogrodzeń bloków kodu');

  for (const match of content.matchAll(/\[[^\]]*]\(([^)]+)\)/g)) {
    const target = match[1];
    if (!target || target.startsWith('#') || /^[a-z]+:/i.test(target)) continue;
    relativeLinks += 1;
    const filePart = decodeURI(target.split('#')[0]);
    const resolved = path.resolve(path.dirname(file), filePart);
    if (!fs.existsSync(resolved)) report(file, `zerwane łącze względne: ${target}`);
  }

  if (/[A-Za-z0-9-]+-v\d+\.\d+\.md/.test(content)) {
    report(file, 'odwołanie do starej nazwy pliku z sufiksem wersji');
  }

  if (
    /\b11\s+operacj|\bport[^\n]{0,40}DocumentProvider[^\n]{0,40}\b11\s+(?:operacj|operations)/i.test(
      content,
    )
  ) {
    report(file, 'stara liczba 11 operacji DocumentProvider');
  }
}

const canonicalDocuments = [
  'domain/01-Core-Domain-Model.md',
  'domain/02-Object-Model.md',
  'architecture/03-Technology-Architecture.md',
  'operations/04-Deployment-and-Infrastructure.md',
  'architecture/05-Open-Source-Architecture.md',
  'workflows/06-System-Workflows.md',
  '07-Product-and-Delivery-Roadmap.md',
];

for (const relative of canonicalDocuments) {
  const file = path.join(docsRoot, relative);
  const content = fs.readFileSync(file, 'utf8');
  const topStatus = content.match(/^\*\*Status:\*\*\s*(.+)$/m)?.[1];
  const blockStatus = content.match(/\|\s*\*\*Status\*\*\s*\|\s*([^|]+)\|/)?.[1]?.trim();
  if (!topStatus || !blockStatus) report(file, 'brak jednego z dwóch zgodnych pól statusu');

  const normalize = (value) =>
    value
      .normalize('NFD')
      .replace(/\p{Diacritic}/gu, '')
      .replaceAll('`', '')
      .replace(/\s+/g, ' ')
      .trim()
      .toLowerCase();

  if (topStatus && blockStatus && normalize(topStatus) !== normalize(blockStatus)) {
    report(file, `sprzeczne statusy: ${topStatus} / ${blockStatus}`);
  }
}

const adrFiles = fs
  .readdirSync(path.join(docsRoot, 'adr'))
  .filter((name) => /^ADR-\d{3}-.*\.md$/.test(name))
  .map((name) => path.join(docsRoot, 'adr', name));

const adrCounts = { accepted: 0, proposed: 0, deprecated: 0, draft: 0 };
for (const file of adrFiles) {
  const content = fs.readFileSync(file, 'utf8');
  const status = content.match(/\|\s*\*\*Status\*\*\s*\|\s*`([^`]+)`\s*\|/)?.[1];
  if (!status || !(status in adrCounts)) report(file, 'brak prawidłowego statusu ADR');
  else adrCounts[status] += 1;
}

const indexFile = path.join(docsRoot, 'adr', '09-Architecture-Decisions-Index.md');
const index = fs.readFileSync(indexFile, 'utf8');
for (const status of ['accepted', 'proposed', 'deprecated']) {
  const declared = Number(
    index
      .match(
        new RegExp(
          `\\| \\\`${status}\\\` \\| \\*\\*(\\d+)\\*\\*|\\| \\\`${status}\\\` \\| (\\d+) \\|`,
        ),
      )
      ?.slice(1)
      .find(Boolean),
  );
  if (declared !== adrCounts[status]) {
    report(indexFile, `liczba ${status}: indeks=${declared}, pliki=${adrCounts[status]}`);
  }
}

if (errors.length > 0) {
  process.stderr.write(`${errors.join('\n')}\n`);
  process.exitCode = 1;
} else {
  process.stdout.write(
    `OK: ${markdownFiles.length} plików Markdown, ${relativeLinks} linków względnych, ${adrFiles.length} ADR-ów.\n`,
  );
}
