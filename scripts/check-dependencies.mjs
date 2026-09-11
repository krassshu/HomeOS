import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const exactVersion = /^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$/;
const packageManagerPattern = /^pnpm@(\d+\.\d+\.\d+)$/;
const dependencyFields = ['dependencies', 'devDependencies', 'optionalDependencies'];
const violations = [];

function findPackageFiles() {
  const files = [path.join(root, 'package.json')];
  for (const group of ['apps', 'packages']) {
    const groupDir = path.join(root, group);
    if (!fs.existsSync(groupDir)) continue;
    for (const entry of fs.readdirSync(groupDir, { withFileTypes: true })) {
      const file = path.join(groupDir, entry.name, 'package.json');
      if (entry.isDirectory() && fs.existsSync(file)) files.push(file);
    }
  }
  return files;
}

function isAllowedVersion(version) {
  return version === 'workspace:*' || exactVersion.test(version);
}

let dependencyCount = 0;
const packageFiles = findPackageFiles();

for (const file of packageFiles) {
  const relative = path.relative(root, file);
  const manifest = JSON.parse(fs.readFileSync(file, 'utf8'));

  for (const field of dependencyFields) {
    for (const [name, version] of Object.entries(manifest[field] ?? {})) {
      dependencyCount += 1;
      if (typeof version !== 'string' || !isAllowedVersion(version)) {
        violations.push(`${relative}: ${field}.${name} = "${version}" (wymagana dokładna wersja)`);
      }
    }
  }

  // packageManager i engines.pnpm są wymagane tylko w root.
  if (file !== packageFiles[0]) continue;

  const packageManager = String(manifest.packageManager ?? '');
  const managerVersion = packageManager.match(packageManagerPattern)?.[1];
  if (!managerVersion) {
    violations.push(
      `${relative}: packageManager musi mieć postać pnpm@X.Y.Z (jest "${packageManager}")`,
    );
  }

  const enginesPnpm = manifest.engines?.pnpm;
  if (managerVersion && enginesPnpm !== managerVersion) {
    violations.push(
      `${relative}: engines.pnpm = "${enginesPnpm}" różni się od packageManager (${managerVersion})`,
    );
  }
}

if (violations.length > 0) {
  console.error('Naruszenia polityki zależności:');
  for (const violation of violations) console.error(`- ${violation}`);
  process.exit(1);
}

console.log(`OK: ${packageFiles.length} pakietów, ${dependencyCount} zależności`);
