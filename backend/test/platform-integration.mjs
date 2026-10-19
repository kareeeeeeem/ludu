import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import mongoose from 'mongoose';
import request from 'supertest';
import { createApp } from '../src/app.js';
import { models, User, Game, MoneyWallet, CosmeticPurchase, PlatformLaunch } from '../src/models.js';
import { PlatformAdapter } from '../src/platform.js';
import { io as socketClient } from 'socket.io-client';

const uri = process.env.TEST_MONGODB_URI;
if (!uri || new URL(uri).pathname !== '/ludo_test_platform') throw new Error('Use isolated ludo_test_platform database');
const port = 3111;
const mockUrl = `http://127.0.0.1:${port}`;
const mockKey = 'isolated-test-only-key';
const child = spawn(process.execPath, ['mock-platform/server.mjs'], {
  cwd: new URL('../../', import.meta.url).pathname,
  env: { ...process.env, MOCK_PLATFORM_PORT: String(port), MOCK_PLATFORM_KEY: mockKey }, stdio: 'ignore'
});
let instance;
let token;
const auth = () => ({ Authorization: `Bearer ${token}` });
const call = (method, path) => request(instance.http)[method](`/api${path}`).set(auth());
const as = (playerToken, method, path) => request(instance.http)[method](`/api${path}`).set('Authorization', `Bearer ${playerToken}`);
async function launch(playerId) {
  const response = await fetch(`${mockUrl}/mock/launch`, { method: 'POST',
    headers: playerId ? { 'Content-Type': 'application/json', 'x-mock-admin': mockKey } : {},
    body: playerId ? JSON.stringify({ playerId }) : undefined });
  assert.equal(response.status, 200);
  return decodeURIComponent(new URL((await response.json()).url).hash.slice(9));
}
async function addMockPlayer(playerId, points = 100) {
  const response = await fetch(`${mockUrl}/mock/admin/player`, { method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-mock-admin': mockKey },
    body: JSON.stringify({ playerId, displayName: playerId, points }) });
  assert.equal(response.status, 201);
  const code = await launch(playerId);
  const exchange = await request(instance.http).post('/api/v1/platform/session/exchange').send({ sessionToken: code });
  assert.equal(exchange.status, 200, exchange.text);
  return exchange.body.token;
}
async function waitForMock() {
  for (let i = 0; i < 30; i++) {
    try { if ((await fetch(`${mockUrl}/health`)).ok) return; } catch {}
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error('Mock platform unavailable');
}
async function connectGameSocket(playerToken) {
  const socket = socketClient(`http://127.0.0.1:${instance.http.address().port}`, {
    transports: ['websocket'], auth: { token: playerToken }, reconnection: false
  });
  await new Promise((resolve, reject) => { socket.once('connect', resolve); socket.once('connect_error', reject); });
  return socket;
}
try {
  await waitForMock();
  await mongoose.connect(uri);
  await mongoose.connection.dropDatabase();
  await Promise.all(models.map(model => model.init()));
  instance = createApp({ secret: 'isolated-platform-test-secret-at-least-32-characters', test: true,
    platformMode: true, platformApiUrl: mockUrl, platformApiKey: mockKey,
    platformAdminApiKey: mockKey, platformCosmeticPrices: { dice_gold: 75, token_metallic: 60 } });
  await new Promise(resolve => instance.http.listen(0, '127.0.0.1', resolve));
  const code = await launch();
  const signed = await request(instance.http).post('/api/v1/platform/session/exchange').send({ sessionToken: code, playerId: 'forged' });
  assert.equal(signed.status, 400);
  const valid = await request(instance.http).post('/api/v1/platform/session/exchange').send({ sessionToken: code });
  assert.equal(valid.status, 200, valid.text);
  token = valid.body.token;
  assert.equal(valid.body.user.displayName, 'Club Player');
  assert.equal((await call('patch', '/auth/me').send({ displayName: 'Forged Name' })).status, 403);
  assert.equal((await request(instance.http).post('/api/v1/platform/session/exchange').send({ sessionToken: code })).status, 401);
  const invalid = await request(instance.http).post('/api/v1/platform/session/exchange').send({ sessionToken: 'invalid-code' });
  assert.equal(invalid.status, 401);
  assert.equal((await request(instance.http).post('/api/auth/guest')).status, 404);
  assert.equal((await request(instance.http).post('/api/auth/register').send({})).status, 404);
  assert.equal((await request(instance.http).post('/api/auth/login').send({})).status, 404);
  assert.equal((await request(instance.http).post('/api/auth/admin-login').send({ email: 'x@example.com', password: 'Whatever1234' })).status, 404);
  assert.equal((await call('get', '/wallet/config')).status, 404);
  assert.equal((await call('post', '/wallet/deposits').send({})).status, 404);
  assert.equal((await call('post', '/wallet/withdrawals').send({})).status, 404);
  assert.equal((await call('get', '/v1/game/me')).body.points, 250);
  const unauthorizedSocket = socketClient(`http://127.0.0.1:${instance.http.address().port}`, { transports: ['websocket'], auth: { token: 'invalid' }, reconnection: false });
  await new Promise(resolve => { unauthorizedSocket.on('connect_error', resolve); });
  assert.equal(unauthorizedSocket.connected, false);
  unauthorizedSocket.close();
  assert.equal((await call('get', '/v1/game/modes')).body.modes.find(m => m.id === 'magic').available, false);
  assert.equal((await call('post', '/rooms/create').send({ capacity: 2, stakeMinor: 100 })).status, 503);
  assert.equal((await call('get', '/wallet/config')).status, 404);
  const catalog = await call('get', '/shop/catalog');
  assert.equal(catalog.body.catalog.find(i => i.id === 'dice_gold').pricePoints, 75);
  const purchaseId = randomUUID();
  const purchased = await call('post', '/shop/buy').send({ itemId: 'dice_gold', requestId: purchaseId, pricePoints: 1 });
  assert.equal(purchased.status, 200, purchased.text);
  assert.equal((await call('get', '/v1/game/me')).body.points, 175);
  assert.equal((await call('post', '/shop/buy').send({ itemId: 'dice_gold', requestId: randomUUID() })).status, 409);
  assert.equal((await call('post', '/shop/buy').send({ itemId: 'dice_gold', requestId: purchaseId })).status, 200);
  assert.equal((await call('get', '/v1/game/me')).body.points, 175);
  assert.equal((await CosmeticPurchase.findOne({ requestId: purchaseId })).status, 'COMMITTED');
  assert.equal((await User.findOne({ platformId: 'local_player' })).inventory.includes('dice_gold'), true);
  assert.equal((await call('post', '/inventory/equip').send({ category: 'dice', itemId: 'dice_gold' })).status, 200);
  assert.equal((await call('post', '/inventory/equip').send({ category: 'token', itemId: 'dice_gold' })).status, 400);
  assert.equal((await call('post', '/inventory/equip').send({ category: 'token', itemId: 'token_crystal' })).status, 403);
  await fetch(`${mockUrl}/mock/admin/fail-next`, { method: 'POST', headers: { 'Content-Type': 'application/json', 'x-mock-admin': mockKey }, body: JSON.stringify({ path: '/ludo/points/purchase' }) });
  const pendingId = randomUUID();
  const pending = await call('post', '/shop/buy').send({ itemId: 'token_metallic', requestId: pendingId });
  assert.equal(pending.status, 202, pending.text);
  assert.equal(pending.body.status, 'PENDING');
  assert.equal((await call('get', `/shop/purchases/${pendingId}/status`)).body.status, 'PENDING');
  assert.equal((await call('post', '/shop/buy').send({ itemId: 'token_metallic', requestId: pendingId })).status, 200);
  assert.equal((await call('get', '/v1/game/me')).body.points, 115);
  assert.equal((await PlatformLaunch.countDocuments({ platformId: 'local_player' })), 1);
  const adapter = new PlatformAdapter({ platformApiUrl: mockUrl, platformApiKey: mockKey });
  const reservation = await adapter.reserve('local_player', 'test-match', 10);
  assert.equal(reservation.status, 'RESERVED');
  assert.equal((await adapter.reserve('local_player', 'test-match', 10)).reservationId, reservation.reservationId);
  assert.equal((await adapter.balance('local_player')).points, 105);
  assert.equal((await adapter.release('local_player', reservation.reservationId, 'test-match')).status, 'RELEASED');
  assert.equal((await adapter.balance('local_player')).points, 115);
  await assert.rejects(adapter.purchase('local_player', 'unlisted', 200, `ludo:cosmetic:local_player:${randomUUID()}`), /Platform rejected request/);
  assert.equal((await adapter.balance('local_player')).points, 115);
  const concurrent = await Promise.allSettled([
    adapter.reserve('local_player', 'concurrent-a', 80), adapter.reserve('local_player', 'concurrent-b', 80)
  ]);
  assert.equal(concurrent.filter(r => r.status === 'fulfilled').length, 1);
  assert.equal(concurrent.filter(r => r.status === 'rejected').length, 1);
  const successful = concurrent.find(r => r.status === 'fulfilled').value;
  const concurrentMatch = successful.reference.split(':')[2];
  await adapter.release('local_player', successful.reservationId, concurrentMatch);
  assert.equal((await adapter.balance('local_player')).points, 115);
  const other = await adapter.reserve('local_player', 'test-match-2', 10);
  assert.equal((await adapter.commit('local_player', other.reservationId, 'test-match-2')).status, 'COMMITTED');
  assert.equal((await adapter.balance('local_player')).points, 105);
  assert.equal((await adapter.settle('test-match-2', [{ playerId: 'local_player', points: 10 }])).status, 'SETTLED');
  assert.equal((await adapter.balance('local_player')).points, 115);
  assert.equal((await adapter.settle('test-match-2', [{ playerId: 'local_player', points: 10 }])).status, 'SETTLED');
  assert.equal((await adapter.balance('local_player')).points, 115);
  const playerTwo = await addMockPlayer('player_two');
  const room = await call('post', '/rooms/create').send({ capacity: 2, stakeMinor: 0 });
  assert.equal(room.status, 201, room.text);
  assert.equal((await as(playerTwo, 'post', '/rooms/join').send({ code: room.body.code })).status, 200);
  const started = await call('post', `/games/${room.body.id}/start`);
  assert.equal(started.status, 200, started.text);
  assert.deepEqual(started.body.state.players.map(p => p.color), ['red', 'yellow']);
  assert.equal(started.body.state.players[0].equipped.dice, 'dice_gold');
  assert.equal(started.body.state.players[1].equipped.dice, 'dice_classic');
  const firstSocket = await connectGameSocket(token);
  const secondSocket = await connectGameSocket(playerTwo);
  const synced = await new Promise(resolve => secondSocket.emit('sync', {}, resolve));
  assert.equal(synced.ok, true);
  assert.equal(synced.data.id, room.body.id);
  secondSocket.close();
  const reconnected = await connectGameSocket(playerTwo);
  assert.equal((await new Promise(resolve => reconnected.emit('sync', {}, resolve))).data.id, room.body.id);
  reconnected.close(); firstSocket.close();
  const rolled = await call('post', `/games/${room.body.id}/action`).send({ type: 'roll', revision: 0 });
  assert.equal(rolled.status, 200, rolled.text);
  assert(rolled.body.state.lastDice >= 1 && rolled.body.state.lastDice <= 6);
  assert.equal((await call('post', `/games/${room.body.id}/action`).send({ type: 'roll', revision: 0 })).status, 409);
  const forfeited = await as(playerTwo, 'post', `/games/${room.body.id}/action`)
    .send({ type: 'forfeit', revision: rolled.body.state.revision });
  assert.equal(forfeited.status, 200, forfeited.text);
  assert.equal(forfeited.body.status, 'completed');
  assert.equal(forfeited.body.state.winner, valid.body.user.id);
  assert.equal((await call('get', '/stats/user')).body.wins, 1);
  assert.equal((await as(playerTwo, 'get', '/stats/user')).body.losses, 1);
  assert.equal(await MoneyWallet.countDocuments({ userId: { $in: [valid.body.user.id, (await as(playerTwo, 'get', '/auth/me')).body.id] } }), 0);
  assert.equal((await call('get', '/stats/leaderboard?page=1')).body.length, 0);
  assert.equal((await call('get', '/stats/leaderboard?period=week')).body[0].wins, 1);
  const playerThree = await addMockPlayer('player_three');
  const playerFour = await addMockPlayer('player_four');
  for (const playerToken of [token, playerTwo, playerThree, playerFour]) {
    const queued = await as(playerToken, 'post', '/matchmaking/queue').send({ capacity: 4, stakeMinor: 0 });
    assert.equal(queued.status, 200, queued.text);
  }
  const matched = await call('get', '/matchmaking/status');
  assert.equal(matched.body.queued, false);
  const four = await Game.findById(matched.body.gameId).lean();
  assert.equal(four.status, 'active');
  assert.deepEqual(four.state.players.map(p => p.color), ['red', 'green', 'yellow', 'blue']);
  assert.equal((await as(playerThree, 'get', `/games/${room.body.id}`)).status, 404);
  const playerTwoId = (await as(playerTwo, 'get', '/auth/me')).body.id;
  const playerThreeId = (await as(playerThree, 'get', '/auth/me')).body.id;
  const playerFourId = (await as(playerFour, 'get', '/auth/me')).body.id;
  for (const player of [{ id: playerTwoId, token: playerTwo }, { id: playerThreeId, token: playerThree }, { id: playerFourId, token: playerFour }]) {
    const current = await Game.findById(four._id).lean();
    const end = await as(player.token, 'post', `/games/${four._id}/action`)
      .send({ type: 'forfeit', revision: current.state.revision });
    assert.equal(end.status, 200, end.text);
  }
  assert.equal((await Game.findById(four._id)).settled, true);
  assert.equal((await call('get', '/stats/user')).body.wins, 2);
  assert.equal((await call('get', '/stats/leaderboard?period=month')).body[0].wins, 2);
  assert.equal(await MoneyWallet.countDocuments({ userId: { $in: [valid.body.user.id, playerTwoId, playerThreeId, playerFourId] } }), 0);
  const poorPlayer = await addMockPlayer('poor_player', 10);
  const declinedId = randomUUID();
  assert.equal((await as(poorPlayer, 'post', '/shop/buy').send({ itemId: 'dice_gold', requestId: declinedId })).status, 402);
  assert.equal((await as(poorPlayer, 'get', `/shop/purchases/${declinedId}/status`)).body.status, 'DECLINED');
  assert.equal((await as(poorPlayer, 'get', '/v1/game/me')).body.points, 10);
  assert.equal((await as(poorPlayer, 'get', '/auth/me')).body.inventory.includes('dice_gold'), false);
  const concurrentPurchase = await Promise.all([
    as(playerTwo, 'post', '/shop/buy').send({ itemId: 'dice_gold', requestId: randomUUID() }),
    as(playerTwo, 'post', '/shop/buy').send({ itemId: 'dice_gold', requestId: randomUUID() })
  ]);
  assert.deepEqual(concurrentPurchase.map(r => r.status).sort(), [200, 409]);
  assert.equal((await as(playerTwo, 'get', '/v1/game/me')).body.points, 25);
  const waitingRoom = await call('post', '/rooms/create').send({ capacity: 2, stakeMinor: 0 });
  assert.equal(waitingRoom.status, 201);
  assert.equal((await as(playerTwo, 'post', '/rooms/join').send({ code: waitingRoom.body.code })).status, 200);
  assert.equal((await as(playerTwo, 'post', `/games/${waitingRoom.body.id}/leave`)).status, 200);
  assert.equal((await call('post', `/games/${waitingRoom.body.id}/leave`)).status, 200);
  assert.equal((await Game.findById(waitingRoom.body.id)).status, 'cancelled');
  assert.equal((await call('post', '/games/practice').send({ capacity: 2, stakeMinor: 10 })).status, 400);
  const practice = await call('post', '/games/practice').send({ capacity: 2, stakeMinor: 0 });
  assert.equal(practice.status, 201, practice.text);
  assert.equal(practice.body.status, 'active');
  assert.equal(practice.body.state.players[1].id.startsWith('bot:'), true);
  let practiceState = practice.body;
  for (let i = 0; i < 12 && practiceState.state.turn === 0; i++) {
    const action = practiceState.state.phase === 'roll' ? { type: 'roll' } :
      { type: 'move', token: practiceState.legalMoves[0] };
    const step = await call('post', `/games/${practice.body.id}/action`)
      .send({ ...action, revision: practiceState.state.revision });
    assert.equal(step.status, 200, step.text);
    practiceState = step.body;
  }
  assert.equal(practiceState.state.turn, 1);
  const beforeBot = practiceState.state.revision;
  await instance.service.tick();
  practiceState = (await call('get', `/games/${practice.body.id}`)).body;
  assert(practiceState.state.revision > beforeBot, 'Bot did not take an authoritative turn');
  assert.equal((await call('post', `/games/${practice.body.id}/action`).send({ type: 'forfeit', revision: practiceState.state.revision })).status, 200);
  assert.equal((await call('get', '/stats/user')).body.wins, 2);
  assert.equal(await MoneyWallet.countDocuments({ userId: valid.body.user.id }), 0);
  await PlatformLaunch.updateOne({ platformId: 'player_four' }, { sessionExpiresAt: new Date(0) });
  assert.equal((await as(playerFour, 'get', '/v1/game/me')).status, 401);
  const config = await request(instance.http).put('/api/v1/platform/admin/config').set('Authorization', `Bearer ${mockKey}`).send({
    gameEnabled: false, maintenanceMessage: 'Test maintenance', enabledModes: ['classic', 'practice'], matchTiers: [0], cosmeticAvailability: {}, reason: 'Integration test maintenance'
  });
  assert.equal(config.status, 200, config.text);
  assert.equal((await call('post', '/games/practice').send({ capacity: 2, stakeMinor: 0 })).status, 503);
  assert.equal((await call('post', '/v1/game/session/end')).status, 200);
  assert.equal((await call('get', '/v1/game/me')).status, 401);
  console.log('Platform integration verified: launch, replay, points, cosmetics, 2/4-player free matches, Socket.IO reconnect, practice, stats, no legacy wallet, adapter transactions, admin, revocation.');
} finally {
  if (instance) await new Promise(resolve => instance.io.close(resolve));
  if (mongoose.connection.readyState === 1) { await mongoose.connection.dropDatabase(); await mongoose.disconnect(); }
  child.kill('SIGTERM');
}
