// Local-only QA launcher. Creates an isolated Mock Platform player and hands
// its one-time launch code to the installed Android app.
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const base = process.env.MOCK_PLATFORM_URL || 'http://127.0.0.1:3110';
const key = process.env.MOCK_PLATFORM_KEY || 'local-only-mock-key';
const playerId = process.env.QA_PLAYER_ID || `qa_${Date.now()}`;
const headers = { 'Content-Type': 'application/json', 'x-mock-admin': key };
if (!process.env.QA_PLAYER_ID) {
  const created = await fetch(`${base}/mock/admin/player`, {
    method: 'POST', headers,
    body: JSON.stringify({ playerId, displayName: 'QA Player', points: 175 }),
  });
  assert.equal(created.status, 201, await created.text());
}
const launched = await fetch(`${base}/mock/launch`, {
  method: 'POST', headers,
  body: JSON.stringify({ playerId }),
});
assert.equal(launched.status, 200);
const code = decodeURIComponent(new URL((await launched.json()).url).hash.slice(9));
const stop = spawnSync('adb', ['shell', 'am', 'force-stop', 'club.ludo.ludo_club'], { encoding: 'utf8' });
assert.equal(stop.status, 0, stop.stderr);
const start = spawnSync('adb', ['shell', 'am', 'start', '-n', 'club.ludo.ludo_club/.MainActivity',
  '--es', 'platform_session', code], { encoding: 'utf8' });
assert.equal(start.status, 0, start.stderr);
console.log(`Launched isolated Android QA player ${playerId}.`);
