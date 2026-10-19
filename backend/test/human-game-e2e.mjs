// Live local diagnostic: Android host taps every roll/move; authenticated second client uses HTTP.
// Run only against the isolated local Mock Platform and MongoDB stack.
import { spawnSync } from 'node:child_process';
import { io } from 'socket.io-client';

const api = 'http://127.0.0.1:3108';
const mock = 'http://127.0.0.1:3110';
const key = 'local-only-mock-key';
const roomCode = process.env.ROOM_CODE;
if (!roomCode && !process.env.GAME_ID) throw Error('ROOM_CODE or GAME_ID required');
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const adb = (...args) => {
  const result = spawnSync('adb', args, { encoding: 'utf8' });
  if (result.status !== 0) throw Error(result.stderr || `adb ${args.join(' ')}`);
};
const post = async (url, body, headers = {}) => {
  const response = await fetch(url, { method: 'POST', headers: { 'content-type': 'application/json', ...headers }, body: JSON.stringify(body) });
  const data = await response.json();
  if (!response.ok) throw Error(`${response.status} ${url} ${JSON.stringify(data)}`);
  return data;
};
const playerId = process.env.GUEST_PLAYER_ID || `human_game_b_${Date.now()}`;
if (!process.env.GUEST_PLAYER_ID) await post(`${mock}/mock/admin/player`, { playerId, displayName: 'Classic Opponent', points: 0 }, { 'x-mock-admin': key });
const launch = await post(`${mock}/mock/launch`, { playerId }, { 'x-mock-admin': key });
const sessionToken = decodeURIComponent(new URL(launch.url).hash.slice(9));
const exchanged = await post(`${api}/api/v1/platform/session/exchange`, { sessionToken });
const auth = { authorization: `Bearer ${exchanged.token}` };
const socket = io(api, { transports: ['websocket'], auth: { token: exchanged.token }, reconnection: false });
let socketRevision = -1;
let latestGame;
socket.on('game_state', game => { socketRevision = game.state?.revision ?? -1; latestGame = game; });
await new Promise((resolve, reject) => { socket.once('connect', resolve); socket.once('connect_error', reject); });
const room = process.env.GAME_ID
  ? await (await fetch(`${api}/api/games/${process.env.GAME_ID}`, { headers: auth })).json()
  : await post(`${api}/api/rooms/join`, { code: roomCode }, auth);
if (room.members.length !== 2) throw Error(`Room has ${room.members.length} members`);
const gameId = room.id;
const hostId = room.members[0];
const guestId = room.members[1];
const get = async () => {
  for (;;) {
    const response = await fetch(`${api}/api/games/${gameId}`, { headers: auth });
    if (response.status === 429) {
      const waitSeconds = Number(response.headers.get('retry-after')) || 60;
      console.log(`DIAGNOSTIC_RATE_LIMIT wait=${waitSeconds}s`);
      await sleep(waitSeconds * 1000);
      continue;
    }
    if (!response.ok) throw Error(`GET game ${response.status}`);
    return response.json();
  }
};
console.log(`ROOM_JOINED game=${gameId} host=${hostId} guest=${guestId} socket=${socket.connected}`);
if (!process.env.GAME_ID) adb('shell', 'input', 'tap', '450', '1390');
let game;
for (let n = 0; n < 30; n++) {
  game = await get();
  if (game.status === 'active') break;
  await sleep(250);
}
if (game.status !== 'active') throw Error(`Android Start did not activate match: ${game.status}`);
console.log(`MATCH_STARTED revision=${game.state.revision} turn=${game.state.turn}`);

const ring = [
  [1,6],[2,6],[3,6],[4,6],[5,6],[6,5],[6,4],[6,3],[6,2],[6,1],[6,0],[7,0],[8,0],
  [8,1],[8,2],[8,3],[8,4],[8,5],[9,6],[10,6],[11,6],[12,6],[13,6],[14,6],[14,7],[14,8],
  [13,8],[12,8],[11,8],[10,8],[9,8],[8,9],[8,10],[8,11],[8,12],[8,13],[8,14],[7,14],[6,14],
  [6,13],[6,12],[6,11],[6,10],[6,9],[5,8],[4,8],[3,8],[2,8],[1,8],[0,8],[0,7],[0,6]
];
const colorIndex = { red:0, green:1, yellow:2, blue:3 };
const position = (color, progress, token) => {
  const index=colorIndex[color];
  if (progress === -1) {
    const origin=[[9,0],[9,9],[0,9],[0,0]][index];
    return [origin[0]+(origin[0]===0?2.8:.8)+(token%2?1.2:0),
      origin[1]+(origin[1]===0?2.8:.8)+(token>=2?1.2:0)];
  }
  if (progress <= 50) return ring[(index*13+progress+13)%52];
  if (progress === 57) return [[7,6.15],[7.85,7],[7,7.85],[6.15,7]][index];
  const n=progress-51;
  return [[7,1+n],[13-n,7],[7,13-n],[1+n,7]][index];
};
const tapToken = (player, token) => {
  const [x,y]=position(player.color,player.tokens[token],token);
  // 900x1600 emulator: board left=60, top=413, frame=20, cell=49.2.
  const px=Math.round(80+(x+.5)*49.2), py=Math.round(433+(y+.5)*49.2);
  adb('shell','input','tap',String(px),String(py));
  return [px,py];
};
let humanRolls=0, humanMoves=0, guestRolls=0, guestMoves=0, firstMove=null;
for(let step=0;step<2500;step++) {
  game=latestGame?.id===gameId && latestGame.state.revision>=game.state.revision ? latestGame : game;
  if(game.status==='completed') break;
  if(game.status!=='active') throw Error(`Unexpected game status ${game.status}`);
  const state=game.state;
  const player=state.players[state.turn];
  if(player.id===hostId) {
    const before=state.revision;
    const legalBefore=game.legalMoves;
    const tap=state.phase==='roll' ? (adb('shell','input','tap','450','1320'),[450,1320])
      : tapToken(player,game.legalMoves[0]);
    let next=game;
    for(let retry=0;retry<40;retry++) {
      await sleep(125);
      if(latestGame?.id===gameId && latestGame.state.revision>before) { next=latestGame; break; }
    }
    if(next.state.revision<=before) next=await get();
    if(next.state.revision<=before) {
      console.log(`ANDROID_ACTION_STUCK type=${state.phase} revision=${before} tap=${tap} legal=${game.legalMoves}`);
      adb('shell','screencap','-p','/sdcard/human-game-stuck.png');
      adb('pull','/sdcard/human-game-stuck.png','../delivery/platform-ludo/builds/human-game-stuck.png');
      throw Error('Android action did not reach authoritative state');
    }
    game=next;
    if(state.phase==='roll') {
      humanRolls++;
      if(next.state.lastDice<1||next.state.lastDice>6) throw Error('Invalid server dice');
      console.log(`HUMAN_ROLL revision=${next.state.revision} dice=${next.state.lastDice} phase=${next.state.phase}`);
    } else {
      humanMoves++;
      const moved=player.tokens.findIndex((progress,index)=>next.state.players[state.turn].tokens[index]!==progress);
      if(moved<0 || !legalBefore.includes(moved)) throw Error('Human legal token position did not change');
      const beforeToken=player.tokens[moved];
      const afterToken=next.state.players[state.turn].tokens[moved];
      if(!firstMove) {
        firstMove={ token:moved, before:beforeToken, after:afterToken, revision:next.state.revision, tap };
        adb('shell','screencap','-p','/sdcard/human-game-first-move.png');
        adb('pull','/sdcard/human-game-first-move.png','../delivery/platform-ludo/builds/human-game-first-move.png');
      }
      console.log(`HUMAN_MOVE revision=${next.state.revision} token=${moved} ${beforeToken}->${afterToken} tap=${tap}`);
    }
  } else if(player.id===guestId) {
    const action=state.phase==='roll'?{type:'roll'}:{type:'move',token:game.legalMoves[0]};
    const next=await post(`${api}/api/games/${gameId}/action`,{...action,revision:state.revision},auth);
    if(next.state.revision!==state.revision+1) throw Error('Guest revision mismatch');
    game=next;
    if(action.type==='roll') guestRolls++; else guestMoves++;
  } else throw Error(`Unknown turn owner ${player.id}`);
  if((step+1)%50===0) console.log(`PROGRESS actions=${step+1} humanRolls=${humanRolls} humanMoves=${humanMoves} guestRolls=${guestRolls} guestMoves=${guestMoves} socketRevision=${socketRevision}`);
}
game=await get();
const result={status:game.status,winner:game.state.winner,gameId,humanRolls,humanMoves,guestRolls,guestMoves,firstMove,revision:game.state.revision,socketRevision};
console.log(`FINAL ${JSON.stringify(result)}`);
socket.disconnect();
if(game.status!=='completed'||humanMoves===0||guestMoves===0||socketRevision<game.state.revision) process.exitCode=1;
