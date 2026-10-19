// One-off release gate: Android host plus a second authenticated Socket.IO client.
import { io } from 'socket.io-client';

const base = 'http://127.0.0.1:3122';
const mock = 'http://127.0.0.1:3114';
const key = 'release-gate-only';
const playerId = `gate_b_${Date.now()}`;
const code = process.env.ROOM_CODE;
if (!code) throw Error('ROOM_CODE required');
const json = async (url, body, headers = {}) => {
  const response = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });
  const data = await response.json();
  if (!response.ok) throw Error(`${url}: ${response.status} ${JSON.stringify(data)}`);
  return data;
};
await json(`${mock}/mock/admin/player`, { playerId, displayName: 'Gate B', points: 175 }, { 'x-mock-admin': key });
const launch = await json(`${mock}/mock/launch`, { playerId }, { 'x-mock-admin': key });
const sessionToken = decodeURIComponent(new URL(launch.url).hash.slice(9));
const exchanged = await json(`${base}/api/v1/platform/session/exchange`, { sessionToken });
const token = exchanged.token;
const socket = io(base, { transports: ['websocket'], auth: { token }, reconnection: false });
let socketUpdates = [];
socket.on('game_state', state => socketUpdates.push({ revision: state.state?.revision, turn: state.state?.turn, phase: state.state?.phase }));
await new Promise((resolve, reject) => { socket.once('connect', resolve); socket.once('connect_error', reject); });
const joined = await json(`${base}/api/rooms/join`, { code }, { authorization: `Bearer ${token}` });
console.log(`JOINED game=${joined.id} members=${joined.members.length} socket=${socket.connected}`);
let bRolled = false;
let aRolled = false;
for (let n = 0; n < 240; n++) {
  const response = await fetch(`${base}/api/games/${joined.id}`, { headers: { authorization: `Bearer ${token}` } });
  const game = await response.json();
  if (game.status === 'active') {
    const own = game.state.players.findIndex(p => p.id === String(exchanged.user.id));
    if (game.state.revision > 0 && game.state.players.some(p => p.id !== String(exchanged.user.id))) aRolled = true;
    if (game.state.turn === own && game.state.phase === 'roll' && !bRolled) {
      const ack = await new Promise(resolve => socket.emit('roll_dice', { gameId: joined.id, revision: game.state.revision }, resolve));
      if (!ack.ok) throw Error(`B roll: ${ack.error}`);
      bRolled = true;
      console.log(`B_ROLL revision=${ack.data.state.revision} dice=${ack.data.state.lastDice}`);
    }
    if (bRolled && aRolled && socketUpdates.length >= 2) {
      const latest = await (await fetch(`${base}/api/games/${joined.id}`, { headers: { authorization: `Bearer ${token}` } })).json();
      const observed = socketUpdates.at(-1);
      if (observed.revision === latest.state.revision) {
        console.log(JSON.stringify({ pass: true, gameId: joined.id, members: latest.members.length, revision: latest.state.revision, socketUpdates: socketUpdates.length, serverDice: latest.state.lastDice }));
        socket.disconnect(); process.exit(0);
      }
    }
  }
  await new Promise(resolve => setTimeout(resolve, 500));
}
console.log(JSON.stringify({ pass: false, bRolled, aRolled, socketUpdates }));
socket.disconnect(); process.exitCode = 1;
