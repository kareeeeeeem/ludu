import assert from 'node:assert/strict';

const launcher = process.env.MOCK_PLATFORM_URL || 'http://127.0.0.1:3110';
const game = process.env.LUDO_API_URL || 'http://127.0.0.1:3108';
const web = process.env.LUDO_WEB_URL || 'http://127.0.0.1:8080';

const launch = await fetch(`${launcher}/mock/launch`, { method: 'POST' });
assert.equal(launch.status, 200, 'Local launcher unavailable');
const launchUrl = new URL((await launch.json()).url);
assert.equal(launchUrl.origin, new URL(web).origin);
const code = decodeURIComponent(launchUrl.hash.slice('#session='.length));
assert(code.length > 10, 'Launcher did not issue a code');

const exchange = await fetch(`${game}/api/v1/platform/session/exchange`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ sessionToken: code })
});
assert.equal(exchange.status, 200, 'Game rejected the local launch');
const { token } = await exchange.json();
assert(token, 'Game did not issue a session');
const authenticated = { Authorization: `Bearer ${token}` };

const me = await fetch(`${game}/api/v1/game/me`, { headers: authenticated });
assert.equal(me.status, 200);
const profile = await me.json();
assert.equal(profile.platformPlayer, true);
assert(Number.isSafeInteger(profile.points));

const replay = await fetch(`${game}/api/v1/platform/session/exchange`, {
  method: 'POST', headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({ sessionToken: code })
});
assert.equal(replay.status, 401, 'Launch code replay was accepted');

const end = await fetch(`${game}/api/v1/game/session/end`, { method: 'POST', headers: authenticated });
assert.equal(end.status, 200);
const afterEnd = await fetch(`${game}/api/v1/game/me`, { headers: authenticated });
assert.equal(afterEnd.status, 401, 'Ended session was accepted');
console.log('Local launcher, platform exchange, points lookup, replay rejection and revocation verified.');
