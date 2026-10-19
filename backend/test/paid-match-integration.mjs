import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import mongoose from 'mongoose';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { models, Game, User, MoneyWallet } from '../src/models.js';

const uri = process.env.TEST_MONGODB_URI;
if (!uri || new URL(uri).pathname !== '/ludo_test_paid') throw new Error('Use isolated ludo_test_paid database');
const port = 3112;
const mockUrl = `http://127.0.0.1:${port}`;
const key = 'isolated-paid-test-key';
const policy = { version: 1, policyId: 'test-only-policy-v1', approved: false, testOnly: true,
  settlementFunding: 'committed-entry-escrow', beforeStart: 'release-reservations',
  afterStart: 'return-entries-via-settlement', forfeit: 'remaining-player-wins',
  timeout: 'engine-three-misses-forfeit', rounding: 'integer-exact',
  tiers: [{ points: 10, capacity: 2, winnerPoints: 18, commissionPoints: 2 },
    { points: 10, capacity: 4, winnerPoints: 36, commissionPoints: 4 }] };
const child = spawn(process.execPath, ['mock-platform/server.mjs'], { cwd: new URL('../../', import.meta.url).pathname,
  env: { ...process.env, MOCK_PLATFORM_PORT: String(port), MOCK_PLATFORM_KEY: key }, stdio: 'ignore' });
let app;
const config = { secret: 'isolated-paid-test-secret-at-least-32-characters', test: true,
  platformMode: true, platformApiUrl: mockUrl, platformApiKey: key, platformAdminApiKey: key,
  platformMatchPolicy: policy };
const api = (token, method, path) => request(app.http)[method](`/api${path}`).set('Authorization', `Bearer ${token}`);
const admin = async (path, data = {}) => fetch(`${mockUrl}${path}`, { method: 'POST',
  headers: { 'Content-Type': 'application/json', 'x-mock-admin': key }, body: JSON.stringify(data) });
const state = async () => (await (await fetch(`${mockUrl}/mock/admin/state`, { headers: { 'x-mock-admin': key } })).json());
const balance = async id => (await state()).players.find(p => p.playerId === id).points;
async function launch(id, points = 100) {
  if (id !== 'local_player') assert.equal((await admin('/mock/admin/player', { playerId: id, displayName: id, points })).status, 201);
  const url = (await (await admin('/mock/launch', { playerId: id })).json()).url;
  const code = decodeURIComponent(new URL(url).hash.slice(9));
  const exchange = await request(app.http).post('/api/v1/platform/session/exchange').send({ sessionToken: code });
  assert.equal(exchange.status, 200, exchange.text);
  return { id: exchange.body.user.id, token: exchange.body.token, platformId: id };
}
async function room(players, capacity = players.length) {
  const made = await api(players[0].token, 'post', '/rooms/create').send({ capacity, stakeMinor: 10 });
  assert.equal(made.status, 201, made.text);
  for (const player of players.slice(1)) {
    const joined = await api(player.token, 'post', '/rooms/join').send({ code: made.body.code });
    assert.equal(joined.status, 200, joined.text);
  }
  return made.body.id;
}
async function forfeitTo(players, id, winnerIndex = 0) {
  for (const player of players.filter((_, i) => i !== winnerIndex)) {
    const game = await Game.findById(id).lean();
    const ended = await api(player.token, 'post', `/games/${id}/action`).send({ type: 'forfeit', revision: game.state.revision });
    assert.equal(ended.status, 200, ended.text);
  }
  return Game.findById(id).lean();
}
try {
  for (let i = 0; i < 30; i++) { try { if ((await fetch(`${mockUrl}/health`)).ok) break; } catch {} await new Promise(r => setTimeout(r, 100)); }
  await mongoose.connect(uri); await mongoose.connection.dropDatabase(); await Promise.all(models.map(m => m.init()));
  app = createApp(config); await new Promise(r => app.http.listen(0, '127.0.0.1', r));
  const a = await launch('local_player'); const b = await launch('paid_b');
  const c = await launch('paid_c'); const d = await launch('paid_d');
  assert.equal((await api(a.token, 'post', '/rooms/create').send({ capacity: 2, stakeMinor: 10 })).status, 403);
  const cfg = await request(app.http).put('/api/v1/platform/admin/config').set('Authorization', `Bearer ${key}`).send({
    gameEnabled: true, maintenanceMessage: '', enabledModes: ['classic', 'practice'], matchTiers: [0, 10],
    cosmeticAvailability: {}, reason: 'Enable isolated test policy' });
  assert.equal(cfg.status, 200, cfg.text);
  const tiers = (await api(a.token, 'get', '/v1/game/modes')).body.entryTiers;
  assert.deepEqual(tiers.find(t => t.points === 10).capacities, [2, 4]);
  const two = await room([a, b]);
  assert.equal(await balance('local_player'), 250);
  assert.equal(await balance('paid_b'), 100);
  const started = await api(a.token, 'post', `/games/${two}/start`);
  assert.equal(started.status, 200, started.text);
  assert.equal(started.body.status, 'active');
  assert.equal(started.body.platformFinance.state, 'IN_PROGRESS');
  assert.equal(await balance('local_player'), 240);
  assert.equal(await balance('paid_b'), 90);
  assert.equal((await api(a.token, 'post', `/games/${two}/start`)).status, 200);
  const completed = await forfeitTo([a, b], two);
  assert.equal(completed.platformFinance.state, 'SETTLED');
  assert.equal(await balance('local_player'), 258);
  assert.equal(await balance('paid_b'), 90);
  assert.equal((await state()).commissionPoints, 2);
  assert.equal((await api(b.token, 'post', `/games/${two}/action`).send({ type: 'forfeit', revision: completed.state.revision })).status, 409);
  assert.equal(await MoneyWallet.countDocuments(), 0);
  const four = await room([a, b, c, d]);
  assert.equal((await api(a.token, 'post', `/games/${four}/start`)).status, 200);
  const fourDone = await forfeitTo([a, b, c, d], four);
  assert.equal(fourDone.platformFinance.state, 'SETTLED');
  assert.equal((await state()).commissionPoints, 6);
  assert.equal((await api(a.token, 'get', '/stats/user')).body.wins, 2);
  const waiting = await room([a, b]);
  const beforeLeave = [await balance('local_player'), await balance('paid_b')];
  assert.equal((await api(a.token, 'post', `/games/${waiting}/leave`)).status, 200);
  assert.equal((await Game.findById(waiting)).status, 'cancelled');
  assert.deepEqual([await balance('local_player'), await balance('paid_b')], beforeLeave);
  const e = await launch('poor_e', 5);
  const failed = await room([a, e]);
  const rejected = await api(a.token, 'post', `/games/${failed}/start`);
  assert.equal(rejected.status, 200, rejected.text);
  assert.equal(rejected.body.status, 'cancelled');
  assert.equal(rejected.body.platformFinance.state, 'RELEASED');
  assert.equal(await balance('poor_e'), 5);
  const declinedStatus = await app.service.platformFinance.adapter.transactionStatus(`ludo:reserve:${failed}:poor_e`);
  assert.equal(declinedStatus.status, 'DECLINED');
  const reserveOutage = await room([a, b]);
  await admin('/mock/admin/fail-next', { path: '/ludo/points/reserve' });
  const awaitingReserve = await api(a.token, 'post', `/games/${reserveOutage}/start`);
  assert.equal(awaitingReserve.status, 200, awaitingReserve.text);
  assert.equal(awaitingReserve.body.platformFinance.state, 'RESERVING');
  await app.service.tick();
  assert.equal((await Game.findById(reserveOutage)).platformFinance.state, 'IN_PROGRESS');
  await forfeitTo([a, b], reserveOutage);
  const cancelledPending = await room([a, b]);
  const beforePendingCancel = [await balance('local_player'), await balance('paid_b')];
  await admin('/mock/admin/fail-next', { path: '/ludo/points/reserve' });
  assert.equal((await api(a.token, 'post', `/games/${cancelledPending}/start`)).body.platformFinance.state, 'RESERVING');
  assert.equal((await request(app.http).post(`/api/v1/platform/admin/matches/${cancelledPending}/cancel`)
    .set('Authorization', `Bearer ${key}`).send({ reason: 'Room expired during funding' })).status, 200);
  assert.equal((await Game.findById(cancelledPending)).platformFinance.state, 'RELEASED');
  assert.deepEqual([await balance('local_player'), await balance('paid_b')], beforePendingCancel);
  const outage = await room([a, b]);
  assert.equal((await admin('/mock/admin/fail-next', { path: '/ludo/points/commit' })).status, 200);
  const pending = await api(a.token, 'post', `/games/${outage}/start`);
  assert.equal(pending.status, 200, pending.text);
  assert.equal(pending.body.platformFinance?.state, 'COMMITTING', pending.text);
  await new Promise(r => app.io.close(r));
  app = createApp(config); await new Promise(r => app.http.listen(0, '127.0.0.1', r));
  await app.service.tick();
  assert.equal((await Game.findById(outage)).platformFinance.state, 'IN_PROGRESS');
  assert.equal((await admin('/mock/admin/fail-next', { path: '/ludo/points/settle' })).status, 200);
  await forfeitTo([a, b], outage);
  assert.equal((await Game.findById(outage)).platformFinance.state, 'SETTLING');
  await app.service.tick();
  assert.equal((await Game.findById(outage)).platformFinance.state, 'SETTLED');
  const partialCommit = await room([a, b]);
  await admin('/mock/admin/fail-next', { path: '/ludo/points/commit', skip: 1 });
  const partiallyFunded = await api(a.token, 'post', `/games/${partialCommit}/start`);
  assert.equal(partiallyFunded.status, 200, partiallyFunded.text);
  assert.equal(partiallyFunded.body.platformFinance.state, 'COMMITTING');
  assert.equal(partiallyFunded.body.platformFinance.participants[0].commit, 'COMMITTED');
  assert.equal(partiallyFunded.body.platformFinance.participants[1].commit, 'NONE');
  assert.equal((await request(app.http).get('/api/v1/platform/admin/finance')).status, 403);
  const reviewQueue = await request(app.http).get('/api/v1/platform/admin/finance')
    .set('Authorization', `Bearer ${key}`);
  assert.equal(reviewQueue.status, 200);
  assert(reviewQueue.body.some(g => g.id === partialCommit && g.finance.state === 'COMMITTING'));
  assert.equal((await request(app.http).post(`/api/v1/platform/admin/finance/${partialCommit}/reconcile`)
    .set('Authorization', `Bearer ${key}`)).status, 200);
  assert.equal((await Game.findById(partialCommit)).platformFinance.state, 'IN_PROGRESS');
  await forfeitTo([a, b], partialCommit);
  const timed = await room([a, b]);
  assert.equal((await api(a.token, 'post', `/games/${timed}/start`)).status, 200);
  for (let i = 0; i < 5; i++) {
    const game = await Game.findById(timed);
    if (game.status !== 'active') break;
    game.state.deadline = Date.now() - 1;
    game.markModified('state'); await game.save();
    await app.service.tick();
  }
  assert.equal((await Game.findById(timed)).status, 'completed');
  assert.equal((await Game.findById(timed)).platformFinance.state, 'SETTLED');
  const cancelled = await room([a, b]);
  const concurrentStarts = await Promise.all([
    api(a.token, 'post', `/games/${cancelled}/start`), api(a.token, 'post', `/games/${cancelled}/start`)
  ]);
  assert(concurrentStarts.every(r => r.status === 200), concurrentStarts.map(r => r.text).join('\n'));
  await app.service.tick();
  assert.equal((await Game.findById(cancelled)).platformFinance.state, 'IN_PROGRESS');
  assert.equal((await request(app.http).post(`/api/v1/platform/admin/matches/${cancelled}/cancel`)
    .set('Authorization', `Bearer ${key}`).send({ reason: 'Isolated cancellation test' })).status, 200);
  assert.equal((await Game.findById(cancelled)).platformFinance.state, 'SETTLED');
  const beforeQueue = await balance('local_player');
  assert.equal((await api(a.token, 'post', '/matchmaking/queue').send({ capacity: 4, stakeMinor: 10 })).status, 200);
  assert.equal(await balance('local_player'), beforeQueue);
  for (const player of [b, c, d])
    assert.equal((await api(player.token, 'post', '/matchmaking/queue').send({ capacity: 4, stakeMinor: 10 })).status, 200);
  const matched = await api(a.token, 'get', '/matchmaking/status');
  assert.equal(matched.body.queued, false);
  assert.equal((await Game.findById(matched.body.gameId)).platformFinance.state, 'IN_PROGRESS');
  assert.equal((await forfeitTo([a, b, c, d], matched.body.gameId)).platformFinance.state, 'SETTLED');
  assert.equal((await state()).players.every(p => p.points >= 0), true);
  const financial = await state();
  const sum = financial.players.reduce((n, p) => n + p.points + p.reserved, financial.commissionPoints);
  assert.equal(sum, 250 + 100 + 100 + 100 + 5);
  assert.equal((await User.findById(a.id)).activeGame, null);
  console.log('Paid match integration verified: 2/4 player entry, reserve/commit/settle, commission, failure rollback, restart, outage recovery, cancellation, conservation.');
} finally {
  if (app) await new Promise(r => app.io.close(r));
  if (mongoose.connection.readyState === 1) { await mongoose.connection.dropDatabase(); await mongoose.disconnect(); }
  child.kill('SIGTERM');
}
