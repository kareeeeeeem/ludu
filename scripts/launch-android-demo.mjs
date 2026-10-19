import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';

const launcher = process.env.MOCK_PLATFORM_URL || 'http://127.0.0.1:3110';
const response = await fetch(`${launcher}/mock/launch`, { method: 'POST' });
assert.equal(response.status, 200, 'Start the local mock platform first');
const code = decodeURIComponent(new URL((await response.json()).url).hash.slice('#session='.length));
assert(code.length > 10, 'Missing one-time launch code');
const result = spawnSync('adb', ['shell', 'am', 'start', '-n',
  'club.ludo.ludo_club/.MainActivity', '--es', 'platform_session', code],
{ encoding: 'utf8' });
assert.equal(result.status, 0, result.stderr || 'adb launch failed');
console.log('Launched Android Ludo with a one-time local platform session.');
