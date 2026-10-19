import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import mongoose from 'mongoose';
import request from 'supertest';
import { io as connect } from 'socket.io-client';
import { randomUUID } from 'node:crypto';
import { createApp } from '../src/app.js';
import { models, User, Game, Queue, Event, MoneyWallet, MoneyStake, MoneyTransaction, DepositRequest, WithdrawalRequest, AppSetting, Audit } from '../src/models.js';
import { GameService } from '../src/service.js';

const uri = process.env.TEST_MONGODB_URI;
if (!uri || !/^ludo_test(?:_[a-z0-9]+)?$/.test(new URL(uri).pathname.slice(1))) throw new Error('Set TEST_MONGODB_URI to an isolated ludo_test replica-set database');
let instance; let base;
const accounts = [];
const fixturePhone = '01000000000'; // Test-only fixture; no transfer is sent.
const api = (i, method, path, body) => request(instance.http)[method](`/api${path}`).set('Authorization', `Bearer ${accounts[i].token}`).send(body);
const wallet = async i => MoneyWallet.findOne({ userId: accounts[i].user.id }).lean();
const adjust = async (i, amountMinor) => api(4, 'put', `/admin/users/${accounts[i].user.id}/balance`, { amountMinor, reason: 'Isolated test funding only', requestId: randomUUID() });

before(async () => {
  await mongoose.connect(uri); await mongoose.connection.dropDatabase(); await Promise.all(models.map(m => m.init()));
  instance = createApp({ secret: 'integration-test-secret-with-more-than-32-characters', test: true, vodafoneReceivingNumber: fixturePhone });
  await new Promise(r => instance.http.listen(0, '127.0.0.1', r)); base = `http://127.0.0.1:${instance.http.address().port}`;
  for (let i = 0; i < 6; i++) {
    const response = await request(instance.http).post('/api/auth/register').send({ username: `Player ${i}`, email: `p${i}@example.com`, password: 'LongPassword123!' });
    assert.equal(response.status, 201, response.text); accounts.push(response.body);
  }
  await User.updateOne({ _id: accounts[4].user.id }, { role: 'admin' });
});
after(async () => { await new Promise(r => instance.io.close(r)); await mongoose.connection.dropDatabase(); await mongoose.disconnect(); });

test('anonymous identity is server-created, persistent, revocable and distinct from legacy points', async () => {
  const guest = await request(instance.http).post('/api/auth/guest').send({ userId: accounts[0].user.id, role: 'admin', points: 999999 });
  assert.equal(guest.status, 201); assert.notEqual(guest.body.user.id, accounts[0].user.id);
  assert.equal(guest.body.user.availableMinor, 0); assert.equal(guest.body.user.role, 'user');
  assert.equal((await request(instance.http).get('/api/auth/me').set('Authorization', `Bearer ${guest.body.token}`)).status, 200);
  const rotated = await request(instance.http).post('/api/auth/refresh').send({ refreshToken: guest.body.refreshToken });
  assert.equal(rotated.status, 200); assert.equal(rotated.body.user.id, guest.body.user.id);
  assert.equal((await request(instance.http).post('/api/auth/refresh').send({ refreshToken: guest.body.refreshToken })).status, 401);
  await request(instance.http).post('/api/auth/logout').set('Authorization', `Bearer ${rotated.body.token}`);
  assert.equal((await request(instance.http).post('/api/auth/refresh').send({ refreshToken: rotated.body.refreshToken })).status, 401);
  assert.equal((await wallet(0)).availableMinor, 0); assert.equal((await User.findById(accounts[0].user.id)).points, 100);
});

test('client cannot mint via legacy endpoints, balance or admin paths', async () => {
  for (const path of ['/wallet/deposit', '/wallet/withdraw', '/wallet/claim']) assert.equal((await api(0, 'post', path, { amountMinor: 99999 })).status, 410);
  assert.equal((await api(0, 'put', `/admin/users/${accounts[0].user.id}/balance`, { amountMinor: 100, reason: 'Unauthorized', requestId: randomUUID() })).status, 403);
  assert.equal((await api(0, 'get', '/admin/deposits')).status, 403);
  assert.equal((await api(0, 'get', `/admin/wallets/${accounts[0].user.id}`)).status, 403);
  assert.equal((await api(0, 'post', '/rooms/create', { capacity: 2, entryFee: 10 })).status, 400);
  assert.equal((await wallet(0)).availableMinor, 0);
});

test('Mongo payment setting changes dynamically; Admin management is guarded and prevents lockout', async () => {
  assert.equal((await api(0, 'get', '/wallet/config')).body.receivingPhone, fixturePhone);
  assert.equal((await api(0, 'put', '/admin/settings/payment', { vodafoneCashReceivingNumber: '01004632660', reason: 'Unauthorized edit' })).status, 403);
  assert.equal((await api(0, 'post', '/admin/admins', { email: 'other-admin@example.com', reason: 'Unauthorized create' })).status, 403);
  assert.equal((await api(0, 'get', '/admin/admins')).status, 403);
  const changed = await api(4, 'put', '/admin/settings/payment', { vodafoneCashReceivingNumber: '01004632660', reason: 'Test controlled payment setting' });
  assert.equal(changed.status, 200, changed.text);
  assert.equal((await api(0, 'get', '/wallet/config')).body.receivingPhone, '01004632660');
  assert.equal((await AppSetting.findOne({ key: 'payment' })).vodafoneCashReceivingNumber, '01004632660');
  assert.equal(await Audit.countDocuments({ action: 'payment_setting_update', oldValue: fixturePhone, newValue: '01004632660' }), 1);
  assert.equal((await api(4, 'put', '/admin/settings/payment', { vodafoneCashReceivingNumber: '123', reason: 'Invalid number' })).status, 400);
  await api(4, 'put', '/admin/settings/payment', { vodafoneCashReceivingNumber: fixturePhone, reason: 'Restore isolated test fixture' });

  const created = await api(4, 'post', '/admin/admins', { email: 'other-admin@example.com', reason: 'Test Admin creation' });
  assert.equal(created.status, 201, created.text);
  assert.ok(created.body.oneTimePassword.length >= 20);
  const adminId = created.body.id;
  assert.equal((await api(4, 'get', '/admin/admins')).body.some(a => a._id === adminId), true);
  const login = await request(instance.http).post('/api/auth/admin-login').send({ email: created.body.email, password: created.body.oneTimePassword });
  assert.equal(login.status, 200, login.text);
  const reset = await api(4, 'put', `/admin/admins/${adminId}/reset-password`, { reason: 'Test password rotation' });
  assert.equal(reset.status, 200, reset.text);
  assert.equal((await request(instance.http).post('/api/auth/admin-login').send({ email: created.body.email, password: created.body.oneTimePassword })).status, 401);
  assert.equal((await request(instance.http).post('/api/auth/admin-login').send({ email: created.body.email, password: reset.body.oneTimePassword })).status, 200);
  assert.equal((await api(4, 'put', `/admin/admins/${accounts[4].user.id}/active`, { active: false, reason: 'Attempt self lockout' })).status, 409);
  assert.equal((await api(4, 'put', `/admin/users/${adminId}/ban`, { banned: true, reason: 'Attempt Admin bypass' })).status, 409);
  const disabled = await api(4, 'put', `/admin/admins/${adminId}/active`, { active: false, reason: 'End temporary test account' });
  assert.equal(disabled.status, 200, disabled.text);
  assert.equal((await request(instance.http).get('/api/admin/admins').set('Authorization', `Bearer ${login.body.token}`)).status, 401);
  assert.equal((await request(instance.http).post('/api/auth/admin-login').send({ email: created.body.email, password: reset.body.oneTimePassword })).status, 401);
  assert.equal(await User.countDocuments({ role: 'admin', isActive: true }), 1);
});

test('deposit request is not money; admin approval is atomic and idempotent', async () => {
  const input = { amountMinor: 10000, requestId: randomUUID(), senderPhone: fixturePhone, transferReference: `test-transfer-${randomUUID()}` };
  const created = await api(0, 'post', '/wallet/deposits', input);
  assert.equal(created.status, 201, created.text); assert.equal(created.body.status, 'PENDING');
  assert.equal((await wallet(0)).availableMinor, 0);
  assert.equal((await api(0, 'post', '/wallet/deposits', input)).body._id, created.body._id);
  assert.equal((await api(0, 'post', '/wallet/deposits', { ...input, amountMinor: 20000 })).status, 409);
  const approvals = await Promise.all(Array.from({ length: 2 }, () => api(4, 'put', `/admin/deposits/${created.body._id}/approve`, { reason: 'Verified isolated test transfer' })));
  assert.ok(approvals.every(r => r.status === 200 || r.status === 409), approvals.map(r => r.text).join('\n'));
  assert.equal((await wallet(0)).availableMinor, 10000);
  assert.equal(await MoneyTransaction.countDocuments({ reference: `deposit:${created.body._id}` }), 1);
  assert.equal((await api(4, 'put', `/admin/deposits/${created.body._id}/approve`, { reason: 'Retry of approval' })).status, 200);
  assert.equal((await wallet(0)).availableMinor, 10000);
  assert.equal((await api(4, 'put', `/admin/deposits/${created.body._id}/reject`, { reason: 'Too late now' })).status, 409);
});

test('rejected deposit never credits and transfer reference cannot be reused', async () => {
  const input = { amountMinor: 5000, requestId: randomUUID(), senderPhone: fixturePhone, transferReference: `test-transfer-${randomUUID()}` };
  const created = await api(1, 'post', '/wallet/deposits', input); assert.equal(created.status, 201);
  assert.equal((await api(2, 'post', '/wallet/deposits', { ...input, requestId: randomUUID() })).status, 409);
  assert.equal((await api(2, 'post', '/wallet/deposits', { ...input, transferReference: input.transferReference.toUpperCase(), requestId: randomUUID() })).status, 409);
  assert.equal((await api(4, 'put', `/admin/deposits/${created.body._id}/reject`, { reason: 'No transfer found' })).status, 200);
  assert.equal((await api(4, 'put', `/admin/deposits/${created.body._id}/approve`, { reason: 'Invalid replay' })).status, 409);
  assert.equal((await wallet(1)).availableMinor, 0);
});

test('withdrawal reserves available, cannot overspend, rejects/releases once', async () => {
  const initial = await wallet(0);
  const input = { amountMinor: 3000, phone: fixturePhone, requestId: randomUUID() };
  const created = await api(0, 'post', '/wallet/withdrawals', input);
  assert.equal(created.status, 201, created.text); assert.equal(created.body.status, 'PENDING');
  assert.equal((await wallet(0)).availableMinor, initial.availableMinor - 3000);
  assert.equal((await wallet(0)).reservedMinor, initial.reservedMinor + 3000);
  assert.equal((await api(0, 'post', '/wallet/withdrawals', input)).body._id, created.body._id);
  assert.equal((await api(0, 'post', '/wallet/withdrawals', { amountMinor: 999999, phone: fixturePhone, requestId: randomUUID() })).status, 402);
  const results = await Promise.all(Array.from({ length: 2 }, () => api(4, 'put', `/admin/withdrawals/${created.body._id}/reject`, { reason: 'Test rejection and release' })));
  assert.ok(results.every(r => r.status === 200 || r.status === 409));
  assert.equal((await wallet(0)).availableMinor, initial.availableMinor);
  assert.equal((await wallet(0)).reservedMinor, initial.reservedMinor);
  assert.equal(await MoneyTransaction.countDocuments({ reference: `withdrawal:reject:${created.body._id}` }), 1);
  assert.equal((await api(4, 'put', `/admin/withdrawals/${created.body._id}/paid`, { reason: 'Cannot pay rejected', payoutReference: 'TEST-REJECTED-REF' })).status, 409);
});

test('concurrent withdrawals cannot spend the same balance; paid happens once', async () => {
  const before = await wallet(0);
  const inputs = [0, 1].map(() => ({ amountMinor: 7000, phone: fixturePhone, requestId: randomUUID() }));
  const results = await Promise.all(inputs.map(input => api(0, 'post', '/wallet/withdrawals', input)));
  assert.equal(results.filter(r => r.status === 201).length, 1, results.map(r => r.text).join('\n'));
  assert.equal((await wallet(0)).availableMinor, before.availableMinor - 7000);
  const id = results.find(r => r.status === 201).body._id;
  const paidBody = { reason: 'External transfer verified in test', payoutReference: `TEST-PAYOUT-${randomUUID()}` };
  const paid = await Promise.all(Array.from({ length: 2 }, () => api(4, 'put', `/admin/withdrawals/${id}/paid`, paidBody)));
  assert.ok(paid.every(r => r.status === 200 || r.status === 409));
  assert.equal((await wallet(0)).reservedMinor, 0);
  assert.equal(await MoneyTransaction.countDocuments({ reference: `withdrawal:paid:${id}` }), 1);
  assert.equal((await api(4, 'put', `/admin/withdrawals/${id}/reject`, { reason: 'Cannot reject paid' })).status, 409);
  const second = await api(0, 'post', '/wallet/withdrawals', { amountMinor: 1000, phone: fixturePhone, requestId: randomUUID() });
  assert.equal(second.status, 201);
  assert.equal((await api(4, 'put', `/admin/withdrawals/${second.body._id}/paid`, paidBody)).status, 409);
  assert.equal((await WithdrawalRequest.findById(second.body._id)).status, 'PENDING');
  assert.equal((await api(4, 'put', `/admin/withdrawals/${second.body._id}/reject`, { reason: 'Release after duplicate reference' })).status, 200);
});

test('waiting cancellation without reservation and repeated cancellation never mint value', async () => {
  const userId = accounts[1].user.id; const before = await wallet(1);
  const [legacy] = await Game.create([{ code: randomUUID().replaceAll('-', '').slice(0, 10).toUpperCase(), host: userId, mode: 'private', capacity: 2, members: [userId], names: ['Player 1'], stakeMinor: 1000 }]);
  await User.updateOne({ _id: userId }, { activeGame: String(legacy._id) });
  assert.equal((await api(1, 'post', `/games/${legacy._id}/leave`, {})).status, 200);
  assert.equal((await api(4, 'put', `/admin/games/${legacy._id}/cancel`, { reason: 'Repeat cancellation attempt' })).status, 409);
  assert.deepEqual([(await wallet(1)).availableMinor, (await wallet(1)).reservedMinor], [before.availableMinor, before.reservedMinor]);
  assert.equal(await MoneyTransaction.countDocuments({ matchId: String(legacy._id) }), 0);
});

test('reserved waiting room releases exactly once on leave or concurrent cancel', async () => {
  assert.equal((await adjust(1, 5000)).status, 200);
  assert.equal((await adjust(2, 5000)).status, 200);
  const before1 = await wallet(1); const before2 = await wallet(2);
  const room = await api(1, 'post', '/rooms/create', { capacity: 2, stakeMinor: 1000 }); assert.equal(room.status, 201, room.text);
  assert.equal((await wallet(1)).availableMinor, before1.availableMinor - 1000);
  assert.equal((await api(2, 'post', '/rooms/join', { code: room.body.code })).status, 200);
  assert.equal((await api(2, 'post', `/games/${room.body.id}/leave`, {})).status, 200);
  assert.equal((await wallet(2)).availableMinor, before2.availableMinor);
  const cancels = await Promise.all([api(1, 'post', `/games/${room.body.id}/leave`, {}), api(4, 'put', `/admin/games/${room.body.id}/cancel`, { reason: 'Concurrent cancel test' })]);
  assert.equal(cancels.filter(r => r.status === 200).length, 1);
  assert.equal((await wallet(1)).availableMinor, before1.availableMinor);
  assert.equal((await wallet(1)).reservedMinor, before1.reservedMinor);
  assert.equal(await MoneyTransaction.countDocuments({ reference: `release:game:${room.body.id}:${accounts[1].user.id}` }), 1);
});

test('paid match captures both stakes and server pays winner once even after 100 retries', async () => {
  const before0 = await wallet(0); const before1 = await wallet(1);
  const room = await api(0, 'post', '/rooms/create', { capacity: 2, stakeMinor: 1000 }); assert.equal(room.status, 201);
  await api(1, 'post', '/rooms/join', { code: room.body.code });
  const start = await api(0, 'post', `/games/${room.body.id}/start`, {}); assert.equal(start.status, 200, start.text);
  assert.equal(start.body.prizePoolMinor, 2000);
  assert.equal(await MoneyStake.countDocuments({ gameId: room.body.id, state: 'CAPTURED' }), 2);
  assert.equal((await api(4, 'put', `/admin/games/${room.body.id}/result`, { winner: accounts[0].user.id, reason: 'Fraudulent force win attempt' })).status, 403);
  const ended = await api(0, 'post', `/games/${room.body.id}/action`, { type: 'forfeit', revision: 0 });
  assert.equal(ended.status, 200, ended.text); assert.equal(ended.body.state.winner, accounts[1].user.id);
  assert.equal((await wallet(0)).availableMinor, before0.availableMinor - 1000);
  assert.equal((await wallet(1)).availableMinor, before1.availableMinor + 1000);
  const repeated = new GameService(instance.io);
  for (let i = 0; i < 100; i++) await repeated.transaction(async session => repeated.settle(await Game.findById(room.body.id).session(session), session));
  assert.equal(await MoneyTransaction.countDocuments({ reference: `prize:${room.body.id}` }), 1);
  assert.equal((await wallet(1)).availableMinor, before1.availableMinor + 1000);
});

test('four-player paid matchmaking, queue release and bot practice', async () => {
  await adjust(0, 2000); await adjust(3, 2000); await adjust(5, 2000);
  const before = await wallet(0);
  assert.equal((await api(0, 'post', '/matchmaking/queue', { capacity: 4, stakeMinor: 1000 })).status, 200);
  assert.equal((await api(0, 'delete', '/matchmaking/queue')).status, 200);
  assert.equal((await wallet(0)).availableMinor, before.availableMinor);
  for (const i of [0, 1, 3, 5]) assert.equal((await api(i, 'post', '/matchmaking/queue', { capacity: 4, stakeMinor: 1000 })).status, 200);
  const status = await api(0, 'get', '/matchmaking/status'); assert.ok(status.body.gameId);
  const game = await Game.findById(status.body.gameId); assert.equal(game.members.length, 4); assert.equal(game.prizePoolMinor, 4000);
  for (let i = 0; i < 3; i++) assert.equal((await api([0, 1, 3][i], 'post', `/games/${game._id}/action`, { type: 'forfeit', revision: i })).status, 200);
  assert.equal(await MoneyTransaction.countDocuments({ reference: `prize:${game._id}` }), 1);
  const practice = await api(0, 'post', '/games/practice', { capacity: 2 }); assert.equal(practice.status, 201);
  assert.equal(practice.body.stakeMinor, 0);
  await api(0, 'post', `/games/${practice.body.id}/action`, { type: 'forfeit', revision: 0 });
});

test('socket auth, revision, reconnect sync, and cross-match protection', async () => {
  const room = await api(0, 'post', '/rooms/create', { capacity: 2 });
  await api(1, 'post', '/rooms/join', { code: room.body.code }); await api(0, 'post', `/games/${room.body.id}/start`, {});
  assert.equal((await api(2, 'post', `/games/${room.body.id}/action`, { type: 'roll', revision: 0 })).status, 404);
  assert.equal((await api(0, 'post', `/games/${room.body.id}/action`, { type: 'roll', dice: 6, revision: 0 })).status, 400);
  const unauthorized = connect(base, { transports: ['websocket'], auth: { token: 'forged' }, reconnection: false });
  await new Promise((resolve, reject) => { unauthorized.on('connect', () => reject(new Error('Accepted forged socket'))); unauthorized.on('connect_error', resolve); }); unauthorized.close();
  const socket = connect(base, { transports: ['websocket'], auth: { token: accounts[0].token } });
  await new Promise((resolve, reject) => { socket.on('connect', resolve); socket.on('connect_error', reject); });
  try {
    const sync = await new Promise(resolve => socket.emit('sync', {}, resolve)); assert.equal(sync.ok, true); assert.equal(sync.data.id, room.body.id);
    const roll = await api(0, 'post', `/games/${room.body.id}/action`, { type: 'roll', revision: 0 }); assert.equal(roll.status, 200);
    assert.equal((await api(0, 'post', `/games/${room.body.id}/action`, { type: 'roll', revision: 0 })).status, 409);
    assert.equal((await api(2, 'get', `/games/${room.body.id}`)).status, 404);
  } finally { socket.close(); await api(4, 'put', `/admin/games/${room.body.id}/cancel`, { reason: 'End socket test room' }); }
});

test('scheduler resumes persisted bot turn and expires waiting room without minting', async () => {
  const practice = await api(3, 'post', '/games/practice', { capacity: 2 });
  assert.equal(practice.status, 201);
  await Game.updateOne({ _id: practice.body.id }, { 'state.turn': 1 });
  const recovered = new GameService(instance.io);
  await recovered.tick();
  assert.equal((await Game.findById(practice.body.id)).state.revision, 1);
  await recovered.moderate('system', practice.body.id, 'cancel', null, 'Test cleanup');
  const before = await wallet(3);
  const waiting = await api(3, 'post', '/rooms/create', { capacity: 2, stakeMinor: 1000 });
  assert.equal(waiting.status, 201);
  // Mongoose timestamps treat createdAt as immutable; age the isolated fixture directly.
  await Game.collection.updateOne({ _id: new mongoose.Types.ObjectId(waiting.body.id) }, { $set: { createdAt: new Date(Date.now() - 31 * 60000) } });
  await recovered.tick();
  assert.equal((await Game.findById(waiting.body.id)).status, 'cancelled');
  assert.equal((await wallet(3)).availableMinor, before.availableMinor);
  assert.equal((await wallet(3)).reservedMinor, before.reservedMinor);
  assert.equal(await MoneyTransaction.countDocuments({ reference: `release:game:${waiting.body.id}:${accounts[3].user.id}` }), 1);
});

test('banned player cannot use session; admin adjustment is ledgered once', async () => {
  const input = { amountMinor: 500, reason: 'Authorized test adjustment', requestId: randomUUID() };
  assert.equal((await api(4, 'put', `/admin/users/${accounts[2].user.id}/balance`, input)).status, 200);
  assert.equal((await api(4, 'put', `/admin/users/${accounts[2].user.id}/balance`, input)).status, 200);
  assert.equal(await MoneyTransaction.countDocuments({ reference: `admin:${input.requestId}` }), 1);
  const inspected = await api(4, 'get', `/admin/wallets/${accounts[2].user.id}`);
  assert.equal(inspected.status, 200); assert.ok(Array.isArray(inspected.body.transactions)); assert.ok(Array.isArray(inspected.body.matches));
  assert.equal((await api(4, 'put', `/admin/users/${accounts[2].user.id}/balance`, { ...input, amountMinor: -500 })).status, 409);
  assert.equal((await api(4, 'put', `/admin/users/${accounts[2].user.id}/ban`, { banned: true, reason: 'Isolated test ban' })).status, 200);
  assert.equal((await api(2, 'get', '/auth/me')).status, 401);
});

test('ledger conservation and malformed EGP values', async () => {
  for (const amountMinor of [0, -1, 1.5, '1e9', 1000000001]) {
    const response = await api(0, 'post', '/wallet/withdrawals', { amountMinor, phone: fixturePhone, requestId: randomUUID() });
    assert.equal(response.status, 400, `${amountMinor}: ${response.text}`);
  }
  const wallets = await MoneyWallet.find().lean();
  for (const row of wallets) {
    const records = await MoneyTransaction.find({ userId: row.userId }).lean();
    assert.equal(records.reduce((sum, tx) => sum + tx.availableDeltaMinor, 0), row.availableMinor, `available ${row.userId}`);
    assert.equal(records.reduce((sum, tx) => sum + tx.reservedDeltaMinor, 0), row.reservedMinor, `reserved ${row.userId}`);
    assert.ok(row.availableMinor >= 0 && row.reservedMinor >= 0);
  }
  for (const deposit of await DepositRequest.find().lean()) {
    assert.equal(await MoneyTransaction.countDocuments({ reference: `deposit:${deposit._id}` }), deposit.status === 'APPROVED' ? 1 : 0);
  }
  for (const withdrawal of await WithdrawalRequest.find().lean()) {
    assert.equal(await MoneyTransaction.countDocuments({ reference: `withdrawal:reserve:${withdrawal._id}` }), 1);
    assert.equal(await MoneyTransaction.countDocuments({ reference: `withdrawal:paid:${withdrawal._id}` }), withdrawal.status === 'PAID' ? 1 : 0);
    assert.equal(await MoneyTransaction.countDocuments({ reference: `withdrawal:reject:${withdrawal._id}` }), withdrawal.status === 'REJECTED' ? 1 : 0);
  }
  const approvedInflow = (await DepositRequest.find({ status: 'APPROVED' }).lean()).reduce((sum, row) => sum + row.amountMinor, 0);
  const adjustments = (await MoneyTransaction.find({ type: 'ADMIN_ADJUSTMENT' }).lean()).reduce((sum, row) => sum + row.availableDeltaMinor, 0);
  const paidOutflow = (await WithdrawalRequest.find({ status: 'PAID' }).lean()).reduce((sum, row) => sum + row.amountMinor, 0);
  assert.equal(wallets.reduce((sum, row) => sum + row.availableMinor + row.reservedMinor, 0), approvedInflow + adjustments - paidOutflow, 'System value must equal approved external inflow plus audited adjustments minus paid withdrawals');
});
