// One-off release gate: ADB performs human taps; MongoDB is read only evidence.
import { MongoClient, ObjectId } from 'mongodb';
import { spawnSync } from 'node:child_process';

const playerId = process.env.GATE_PLAYER_ID;
const mongo = new MongoClient(process.env.GATE_MONGODB_URI);
await mongo.connect();
const db = mongo.db();
let user = await db.collection('users').findOne({ platformId: playerId });
if (!user?.activeGame) {
  tap(70, 135);
  await new Promise(resolve => setTimeout(resolve, 350));
  tap(450, 830);
  await new Promise(resolve => setTimeout(resolve, 350));
  tap(450, 1230);
  for (let i = 0; i < 30; i++) {
    await new Promise(resolve => setTimeout(resolve, 200));
    user = await db.collection('users').findOne({ platformId: playerId });
    if (user?.activeGame) break;
  }
}
if (!user?.activeGame) throw Error('No active game after Android Practice entry');
const gameId = user.activeGame;
const gameObjectId = new ObjectId(gameId);
let rolledRevision = -1;
let movedRevision = -1;
let initialToken = null;
const deadline = Date.now() + 100000;
function tap(x, y) {
  const result = spawnSync('adb', ['shell', 'input', 'tap', `${x}`, `${y}`], { encoding: 'utf8' });
  if (result.status !== 0) throw Error(result.stderr);
}
try {
  while (Date.now() < deadline) {
    const game = await db.collection('games').findOne({ _id: gameObjectId });
    const state = game?.state;
    if (!state || game.status !== 'active') throw Error(`Game ${game?.status}`);
    const playerIndex = state.players.findIndex(p => p.id === String(user._id));
    if (playerIndex < 0) throw Error('Player missing');
    if (initialToken !== null && state.players[playerIndex].tokens[0] !== initialToken) {
      console.log(JSON.stringify({ pass: true, gameId, from: initialToken, to: state.players[playerIndex].tokens[0], revision: state.revision }));
      spawnSync('adb', ['shell', 'screencap', '-p', '/sdcard/gate-move.png']);
      spawnSync('adb', ['pull', '/sdcard/gate-move.png', '../delivery/platform-ludo/builds/release-gate-move.png']);
      process.exitCode = 0;
      break;
    }
    if (state.turn === playerIndex && state.phase === 'roll' && rolledRevision !== state.revision) {
      rolledRevision = state.revision;
      tap(450, 1320);
      console.log(`ANDROID_ROLL_TAP revision=${state.revision}`);
    }
    if (state.turn === playerIndex && state.phase === 'move' && state.lastDice === 6 && movedRevision !== state.revision) {
      movedRevision = state.revision;
      initialToken = state.players[playerIndex].tokens[0];
      await new Promise(resolve => setTimeout(resolve, 600));
      tap(592, 594);
      console.log(`ANDROID_TOKEN_TAP revision=${state.revision} dice=${state.lastDice}`);
    }
    await new Promise(resolve => setTimeout(resolve, 300));
  }
  if (initialToken === null || process.exitCode !== 0) {
    console.log('NOT_VERIFIED: no confirmed token move within 100 seconds');
    process.exitCode = 1;
  }
} finally {
  await mongo.close();
}
