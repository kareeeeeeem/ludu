import './env.js';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { randomBytes } from 'node:crypto';
import { writeFileSync, existsSync } from 'node:fs';
import { resolve } from 'node:path';
import { User } from './models.js';
import { ensureWallet } from './wallet.js';
const command = process.argv[2];
if (command !== '--create-local') throw new Error('Usage: npm run admin -- --create-local [--credentials-file=../delivery/ADMIN_CREDENTIALS.txt]');
const fileArg = process.argv[3];
if (fileArg && !fileArg.startsWith('--credentials-file=')) throw new Error('Unknown option');
const credentialsFile = fileArg ? resolve(fileArg.slice('--credentials-file='.length)) : null;
if (credentialsFile && existsSync(credentialsFile)) throw new Error('Credentials file already exists; refusing to overwrite');
if (command === '--create-local') {
  if (process.env.NODE_ENV === 'production' || !/^mongodb:\/\/((127\.0\.0\.1)|(localhost))(:|\/)/.test(process.env.MONGODB_URI || '')) throw new Error('Local admin creation requires a localhost MongoDB URI and non-production mode');
}
await mongoose.connect(process.env.MONGODB_URI);
if (command === '--create-local') {
  const email = 'admin@ludo.local';
  if (await User.exists({ role: 'admin' })) throw new Error('An administrator already exists. Use Admin Management in the app.');
  if (await User.exists({ email })) throw new Error('Local admin already exists. Use the existing credentials or explicitly reset the account.');
  const password = randomBytes(24).toString('base64url');
  await mongoose.connection.transaction(async session => {
    const [user] = await User.create([{ email, username: `LocalAdmin_${randomBytes(4).toString('hex')}`, password: await bcrypt.hash(password, 12), role: 'admin' }], { session });
    await ensureWallet(user, session);
  });
  console.log(`Local admin email: ${email}`);
  if (credentialsFile) {
    writeFileSync(credentialsFile, `LOCAL ADMIN CREDENTIALS\nCHANGE PASSWORD AFTER FIRST LOGIN\n\nEmail: ${email}\nPassword: ${password}\n`, { flag: 'wx', mode: 0o600 });
    console.log(`One-time credentials saved to ${credentialsFile} (owner-only access).`);
  } else {
    console.log(`One-time generated password: ${password}`);
    console.log('Store this password securely; it is not saved in plaintext.');
  }
}
await mongoose.disconnect();
