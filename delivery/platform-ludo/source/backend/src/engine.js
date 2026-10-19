import { randomInt } from 'node:crypto';

export const COLORS = ['red', 'green', 'yellow', 'blue'];
export const SAFE = new Set([0, 8, 13, 21, 26, 34, 39, 47]);
export const FINISH = 57;
export function assert(condition, message, status = 400) {
  if (!condition) throw Object.assign(new Error(message), { status });
}
export function newState(players, now = Date.now()) {
  assert(players.length === 2 || players.length === 4, 'Choose 2 or 4 players');
  return { players: players.map((p, i) => ({ ...p, color: COLORS[players.length === 2 ? i * 2 : i], tokens: [-1, -1, -1, -1], eliminated: false })), turn: 0, dice: null, lastDice: null, sixes: 0, phase: 'roll', status: 'active', winner: null, deadline: now + 30000, revision: 0 };
}
export function square(player, progress) {
  // The 52-square circuit includes the square immediately before each start.
  // A token turns into its own lane from progress 50, before revisiting that square.
  return progress >= 0 && progress <= 50 ? (COLORS.indexOf(player.color) * 13 + progress) % 52 : null;
}
export function legalMoves(state) {
  if (state.status !== 'active' || state.phase !== 'move') return [];
  return state.players[state.turn].tokens.flatMap((p, i) => (p === -1 ? state.dice === 6 : p < FINISH && p + state.dice <= FINISH) ? [i] : []);
}
function next(state, now) {
  do { state.turn = (state.turn + 1) % state.players.length; } while (state.players[state.turn].eliminated);
  state.sixes = 0;
  reset(state, now);
}
function reset(state, now) { state.dice = null; state.phase = 'roll'; state.deadline = now + 30000; }
export function act(original, userId, action, now = Date.now(), roll = () => randomInt(1, 7)) {
  const s = structuredClone(original);
  assert(s.status === 'active', 'Game is not active', 409);
  const player = s.players.find(p => p.id === userId);
  assert(player && !player.eliminated, 'Not an active player', 403);
  if (action.type === 'forfeit') {
    player.eliminated = true;
    const remaining = s.players.filter(p => !p.eliminated);
    if (remaining.length === 1) { s.status = 'completed'; s.winner = remaining[0].id; }
    else if (s.players[s.turn].id === userId) next(s, now);
  } else {
    assert(s.players[s.turn].id === userId, 'Wait for your turn', 409);
    if (action.type === 'timeout') {
      assert(now >= s.deadline, 'Turn has not expired', 409);
      player.missedTurns = (player.missedTurns || 0) + 1;
      if (player.missedTurns >= 3) return act(s, userId, { type: 'forfeit' }, now, roll);
      next(s, now);
    } else {
      assert(now < s.deadline, 'Turn expired', 409);
      player.missedTurns = 0;
      if (action.type === 'roll') {
        assert(s.phase === 'roll', 'Move before rolling again', 409);
        s.dice = roll(); assert(Number.isInteger(s.dice) && s.dice >= 1 && s.dice <= 6, 'Invalid dice');
        s.lastDice = s.dice; s.sixes = s.dice === 6 ? s.sixes + 1 : 0; s.phase = 'move';
        if (s.sixes === 3 || legalMoves(s).length === 0) next(s, now);
      } else if (action.type === 'move') {
        assert(legalMoves(s).includes(action.token), 'Illegal token movement', 409);
        const from = player.tokens[action.token];
        const to = from === -1 ? 0 : from + s.dice;
        player.tokens[action.token] = to;
        const target = square(player, to); let captured = false;
        if (target !== null && !SAFE.has(target)) {
          for (const opponent of s.players.filter(p => p.id !== userId && !p.eliminated)) {
            opponent.tokens = opponent.tokens.map(p => {
              if (square(opponent, p) === target) { captured = true; return -1; } return p;
            });
          }
        }
        if (player.tokens.every(p => p === FINISH)) { s.status = 'completed'; s.winner = player.id; }
        else if (s.dice === 6 || captured || to === FINISH) reset(s, now);
        else next(s, now);
      } else assert(false, 'Unknown action');
    }
  }
  s.revision += 1;
  return s;
}
export function botAction(state) {
  if (state.phase === 'roll') return { type: 'roll' };
  const p = state.players[state.turn];
  const ranked = legalMoves(state).map(token => {
    const to = p.tokens[token] === -1 ? 0 : p.tokens[token] + state.dice;
    const target = square(p, to);
    const captures = target !== null && !SAFE.has(target) && state.players.some(o => o.id !== p.id && !o.eliminated && o.tokens.some(t => square(o, t) === target));
    return { token, score: (to === FINISH ? 1000 : 0) + (captures ? 500 : 0) + (p.tokens[token] === -1 ? 60 : to) };
  }).sort((a, b) => b.score - a.score);
  return { type: 'move', token: ranked[0].token };
}
