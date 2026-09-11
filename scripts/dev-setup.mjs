import crypto from 'node:crypto';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const root = path.resolve(import.meta.dirname, '..');
const envFile = path.join(root, '.env');
const exampleFile = path.join(root, '.env.example');
const placeholder = '__GENERATED_BY_DEV_SETUP__';

if (fs.existsSync(envFile)) {
  console.log(`.env istnieje, nie nadpisuję: ${envFile}`);
  process.exit(0);
}

const example = fs.readFileSync(exampleFile, 'utf8');
if (!example.includes(placeholder)) {
  console.error(`.env.example nie zawiera placeholdera ${placeholder}`);
  process.exit(1);
}

// hex jest bezpieczny w URL, więc DATABASE_URL nie wymaga kodowania hasła.
const password = crypto.randomBytes(24).toString('hex');
const content = example.replaceAll(placeholder, password);

try {
  // 'wx' zawodzi, gdy plik powstał w międzyczasie — nigdy nie nadpisujemy.
  fs.writeFileSync(envFile, content, { flag: 'wx', mode: 0o600 });
} catch (error) {
  const message = error instanceof Error ? error.message : String(error);
  console.error(`Nie udało się zapisać .env: ${message}`);
  process.exit(1);
}

const mode = (fs.statSync(envFile).mode & 0o777).toString(8);
console.log(`Utworzono ${envFile} (tryb ${mode}). Hasło bazy wygenerowano losowo.`);
