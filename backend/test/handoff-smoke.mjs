// Local handoff smoke test: no payment or wallet mutation, no credentials logged.
import { readFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import mongoose from 'mongoose';
import { User, MoneyWallet } from '../src/models.js';

const credentials = readFileSync('../delivery/ADMIN_CREDENTIALS.txt', 'utf8');
const email = credentials.match(/^Email: (.+)$/m)?.[1];
const password = credentials.match(/^Password: (.+)$/m)?.[1];
if (!email || !password) throw new Error('Local handoff credentials are missing');
const base = 'http://127.0.0.1:3107/api';
async function call(path, method = 'GET', body, token) {
  const response = await fetch(base + path, { method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}) });
  return { status: response.status, body: await response.json() };
}
function expect(result, status, message) { if (result.status !== status) throw new Error(`${message}: HTTP ${result.status} ${JSON.stringify(result.body)}`); return result.body; }
const login = expect(await call('/auth/admin-login', 'POST', { email, password }), 200, 'Permanent Admin login');
const adminToken = login.token;
const before = expect(await call('/admin/settings/payment', 'GET', null, adminToken), 200, 'Payment setting').vodafoneCashReceivingNumber;
if (before !== '01004632660') throw new Error('Unexpected initial Vodafone Cash number');
let guestId; let tempId;
try {
  const guest = expect(await call('/auth/guest', 'POST'), 201, 'Guest identity');
  guestId = guest.user.id;
  const playerToken = guest.token;
  for (const path of ['/admin/admins', '/admin/settings/payment', '/admin/transactions', '/admin/deposits', '/admin/withdrawals']) {
    expect(await call(path, 'GET', null, playerToken), 403, `Player blocked from ${path}`);
  }
  for (const [path, method, body] of [
    ['/admin/admins', 'POST', { email: `test-${randomUUID()}@ludo.local`, reason: 'Unauthorized runtime check' }],
    ['/admin/settings/payment', 'PUT', { vodafoneCashReceivingNumber: '01000000000', reason: 'Unauthorized runtime check' }],
  ]) expect(await call(path, method, body, playerToken), 403, `Player blocked from ${path}`);

  expect(await call('/admin/settings/payment', 'PUT', { vodafoneCashReceivingNumber: '01000000000', reason: 'Temporary local handoff verification' }, adminToken), 200, 'Change Vodafone number');
  const updated = expect(await call('/wallet/config', 'GET', null, playerToken), 200, 'Player config after Admin change');
  if (updated.receivingPhone !== '01000000000') throw new Error('Player did not see dynamic number');
  const created = expect(await call('/admin/admins', 'POST', { email: `handoff-test-${randomUUID()}@ludo.local`, reason: 'Temporary Admin runtime test' }, adminToken), 201, 'Create temporary Admin');
  tempId = created.id;
  const tempLogin = expect(await call('/auth/admin-login', 'POST', { email: created.email, password: created.oneTimePassword }), 200, 'Temporary Admin login');
  const reset = expect(await call(`/admin/admins/${tempId}/reset-password`, 'PUT', { reason: 'Test secure password reset' }, adminToken), 200, 'Reset temporary Admin password');
  expect(await call('/auth/admin-login', 'POST', { email: created.email, password: created.oneTimePassword }), 401, 'Old password revoked');
  expect(await call('/auth/admin-login', 'POST', { email: created.email, password: reset.oneTimePassword }), 200, 'New password works');
  expect(await call(`/admin/admins/${login.user.id}/active`, 'PUT', { active: false, reason: 'Verify self lockout protection' }, adminToken), 409, 'Permanent Admin self-disable blocked');
  expect(await call(`/admin/admins/${tempId}/active`, 'PUT', { active: false, reason: 'End temporary Admin runtime test' }, adminToken), 200, 'Disable temporary Admin');
  expect(await call('/admin/admins', 'GET', null, tempLogin.token), 401, 'Disabled Admin token revoked');
  expect(await call('/auth/admin-login', 'POST', { email: created.email, password: reset.oneTimePassword }), 401, 'Disabled Admin login blocked');
  console.log('PASS: Admin login, player 403, dynamic number without APK rebuild, Admin create/login/reset/disable, last-Admin protection');
} finally {
  const restored = await call('/admin/settings/payment', 'PUT', { vodafoneCashReceivingNumber: before, reason: 'Restore final client receiving number' }, adminToken);
  if (restored.status !== 200) throw new Error('Could not restore final Vodafone number');
  await mongoose.connect('mongodb://127.0.0.1:27028/ludo_club?replicaSet=ludo');
  if (guestId) { await User.deleteOne({ _id: guestId, role: 'user' }); await MoneyWallet.deleteOne({ userId: guestId, availableMinor: 0, reservedMinor: 0 }); }
  if (tempId) { await User.deleteOne({ _id: tempId, role: 'admin', isActive: false }); await MoneyWallet.deleteOne({ userId: tempId, availableMinor: 0, reservedMinor: 0 }); }
  await mongoose.disconnect();
}
