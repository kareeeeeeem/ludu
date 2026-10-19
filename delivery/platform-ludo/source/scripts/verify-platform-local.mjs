import assert from 'node:assert/strict';

const base = process.env.LUDO_API_URL || 'http://127.0.0.1:3108';
let token;
async function call(path, method = 'GET', body) {
  const response = await fetch(`${base}/api${path}`, {
    method, headers: { 'Content-Type': 'application/json', ...(token ? { Authorization: `Bearer ${token}` } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {})
  });
  return { status: response.status, data: await response.json() };
}
assert.equal((await call('/auth/guest', 'POST')).status, 404);
const signed = await call('/v1/platform/session/exchange', 'POST', { sessionToken: 'mock:local_player' });
assert.equal(signed.status, 200, JSON.stringify(signed.data));
assert.equal(signed.data.user.platformPlayer, true);
token = signed.data.token;
const me = await call('/auth/me');
assert.equal(me.status, 200);
assert.equal(me.data.points, 0);
assert.equal(me.data.availableMinor, undefined);
const catalog = await call('/shop/catalog');
assert.equal(catalog.status, 200);
assert.equal(catalog.data.catalog.find(i => i.id === 'dice_gold').pricePoints, null);
assert.equal((await call('/shop/buy', 'POST', { itemId: 'dice_gold' })).status, 503);
assert.equal((await call('/wallet/config')).status, 404);
assert.equal((await call('/rooms/create', 'POST', { capacity: 2, stakeMinor: 100 })).status, 503);
const room = await call('/rooms/create', 'POST', { capacity: 2, stakeMinor: 0 });
assert.equal(room.status, 201, JSON.stringify(room.data));
console.log('Platform mock session, balance, catalog, purchase guard, wallet isolation, and free room verified.');
