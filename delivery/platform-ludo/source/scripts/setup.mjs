import { existsSync, readFileSync, writeFileSync } from 'node:fs';
import { randomBytes } from 'node:crypto';
const target = new URL('../backend/.env', import.meta.url);
if (!existsSync(target)) {
  const sample = readFileSync(new URL('../backend/.env.example', import.meta.url), 'utf8');
  writeFileSync(target, sample.replace('replace-with-at-least-32-random-characters', randomBytes(48).toString('hex')), { mode: 0o600 });
  console.log('Created backend/.env with a random local secret. Configure email delivery and database as needed.');
} else console.log('backend/.env already exists; preserved.');
