import '../src/env.js';
import mongoose from 'mongoose';
import bcrypt from 'bcryptjs';
import { randomBytes, randomUUID } from 'node:crypto';
import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import { User } from '../src/models.js';
import { DepositRequest, Game, MoneyTransaction, MoneyWallet } from '../src/models.js';
import { ensureWallet } from '../src/wallet.js';
import { GameService } from '../src/service.js';

const uri = process.env.MONGODB_URI || '';
if (process.env.NODE_ENV === 'production' || !/^mongodb:\/\/(127\.0\.0\.1|localhost):27028\/ludo_club\?replicaSet=ludo$/.test(uri)) {
  throw new Error('UI E2E only accepts the local ludo_club replica set on port 27028');
}
const health = await fetch('http://127.0.0.1:3107/health');
if (!health.ok || !(await health.json()).ok) throw new Error('Start the local backend first');
await mongoose.connect(uri);
const runId = randomUUID().slice(0, 8);
const email = `ui-e2e-${runId}@ludo.local`;
const password = randomBytes(24).toString('base64url');
let admin;
const startedAt = new Date();
try {
  await mongoose.connection.transaction(async session => {
    [admin] = await User.create([{
      email, username: `UiE2eAdmin_${runId}`, password: await bcrypt.hash(password, 12), role: 'admin',
    }], { session });
    await ensureWallet(admin, session);
  });
  const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '../../frontend');
  const device = process.env.E2E_SIMULATOR_ID || '5A86C7C4-DE3C-4C27-A0E7-AE1A9C553FF9';
  console.log(`Running local UI E2E on ${device}; temporary admin ID ${admin.id}`);
  const args = [
    'test', 'integration_test/full_local_e2e_test.dart', '-d', device, '--no-pub',
    `--dart-define=E2E_ADMIN_EMAIL=${email}`,
    `--dart-define=E2E_ADMIN_PASSWORD=${password}`,
  ];
  const child = spawn('flutter', args, { cwd: root, stdio: 'inherit' });
  const code = await new Promise((resolve, reject) => {
    child.on('error', reject);
    child.on('exit', resolve);
  });
  if (code !== 0) process.exitCode = code || 1;
  if (code === 0) {
    const deposit = await DepositRequest.findOne({
      transferReference: /^UIE2E-/,
      createdAt: { $gte: startedAt },
      status: 'APPROVED',
    }).sort({ createdAt: -1 }).lean();
    if (!deposit) throw new Error('Completed UI E2E deposit not found');
    const match = await Game.findOne({
      members: deposit.userId,
      createdAt: { $gte: startedAt },
      mode: 'private', status: 'completed', stakeMinor: 2500,
    }).sort({ createdAt: -1 }).lean();
    if (!match || !match.settled) throw new Error('Completed UI E2E paid match not found');
    const before = await MoneyWallet.find({ userId: { $in: match.members } }).lean();
    const snapshot = JSON.stringify(before.map(w => [w.userId, w.availableMinor, w.reservedMinor]).sort());
    const service = new GameService({});
    for (let i = 0; i < 20; i++) {
      await service.transaction(async session => {
        await service.settle(await Game.findById(match._id).session(session), session);
      });
    }
    const after = await MoneyWallet.find({ userId: { $in: match.members } }).lean();
    if (JSON.stringify(after.map(w => [w.userId, w.availableMinor, w.reservedMinor]).sort()) !== snapshot) {
      throw new Error('Repeated settlement changed E2E wallet balances');
    }
    const prizes = await MoneyTransaction.countDocuments({ reference: `prize:${match._id}` });
    if (prizes !== 1) throw new Error(`Expected one prize transaction, found ${prizes}`);
    console.log(`Actual paid match ${match._id}: 20 internal settlement retries; balances unchanged; one PRIZE transaction.`);
  }
} finally {
  if (admin) {
    await User.updateOne({ _id: admin._id }, {
      $set: { isActive: false }, $inc: { tokenVersion: 1 },
      $unset: { refreshHash: 1, refreshExpires: 1 },
    });
    console.log(`Temporary UI E2E admin ${admin.id} disabled; audit records retained.`);
  }
  await mongoose.disconnect();
}
