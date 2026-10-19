import { createServer } from 'node:http';
import { randomUUID, randomBytes } from 'node:crypto';

if (process.env.NODE_ENV === 'production') throw new Error('Mock platform cannot run in production');
const port = Number(process.env.MOCK_PLATFORM_PORT || 3110);
const key = process.env.MOCK_PLATFORM_KEY || 'local-only-mock-key';
const gameUrl = process.env.MOCK_GAME_URL || 'http://127.0.0.1:8080/';
const players = new Map([['local_player', { playerId: 'local_player', displayName: 'Club Player', avatar: '🎲', points: 250, reserved: 0 }]]);
const launchCodes = new Map();
const transactions = new Map();
const reservations = new Map();
let commissionPoints = 0;
let failNext = null;

const json = (res, status, data) => { res.writeHead(status, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }); res.end(JSON.stringify(data)); };
const error = (res, status, message) => json(res, status, { error: message });
const integer = n => Number.isSafeInteger(n) && n >= 0;
const requirePlayer = id => players.get(id);
const idempotent = (keyValue, work, payload, endpoint) => {
  if (!keyValue || typeof keyValue !== 'string' || keyValue.length > 200) return { status: 400, data: { error: 'Idempotency-Key required' } };
  const fingerprint = JSON.stringify([endpoint, payload]);
  if (transactions.has(keyValue)) {
    const prior = transactions.get(keyValue);
    return prior.fingerprint === fingerprint ? prior : { status: 409, data: { error: 'Idempotency key payload mismatch' } };
  }
  const result = work();
  result.fingerprint = fingerprint;
  if (result.status < 500) transactions.set(keyValue, result);
  return result;
};
const result = (status, data) => ({ status, data });

async function body(req) {
  let raw = '';
  for await (const chunk of req) {
    raw += chunk;
    if (raw.length > 8192) throw new Error('Request too large');
  }
  return raw ? JSON.parse(raw) : {};
}

const server = createServer(async (req, res) => {
  const path = new URL(req.url, `http://127.0.0.1:${port}`).pathname;
  if (path === '/' && req.method === 'GET') {
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'no-store' });
    return res.end(`<!doctype html><html><head><meta name="viewport" content="width=device-width,initial-scale=1"><title>Local Gaming Platform</title><style>body{font:18px system-ui;margin:0;background:#b9eeff;color:#21445a;display:grid;place-items:center;min-height:100vh}.card{background:#fffaf0;border-radius:32px;padding:40px;max-width:430px;box-shadow:0 20px 50px #315c7040}h1{margin-top:0}button{border:0;border-radius:18px;background:#ffba22;padding:18px 28px;font:bold 20px system-ui;cursor:pointer}</style></head><body><main class="card"><h1>🎮 Local Gaming Platform</h1><p>Development mock · Club Player · 250 starting test points</p><p>Select Ludo to exchange a one-time launch code with the game backend.</p><button onclick="fetch('/mock/launch',{method:'POST'}).then(r=>r.json()).then(d=>location.href=d.url)">🎲 Play Ludo</button></main></body></html>`);
  }
  if (path === '/health') return json(res, 200, { ok: true, mock: true });
  let data;
  try { data = await body(req); } catch { return error(res, 400, 'Invalid JSON'); }
  if (path === '/mock/launch' && req.method === 'POST') {
    const playerId = req.headers['x-mock-admin'] === key && typeof data.playerId === 'string' && players.has(data.playerId)
      ? data.playerId : 'local_player';
    const code = randomBytes(24).toString('base64url');
    launchCodes.set(code, { playerId, launchId: randomUUID(), expiresAt: Date.now() + 120000 });
    return json(res, 200, { url: `${gameUrl}#session=${encodeURIComponent(code)}` });
  }
  if (path.startsWith('/mock/admin/')) {
    if (req.headers['x-mock-admin'] !== key) return error(res, 403, 'Mock admin key required');
    if (path === '/mock/admin/player' && req.method === 'POST') {
      if (typeof data.playerId !== 'string' || !/^[\w:.-]{3,128}$/.test(data.playerId) ||
          typeof data.displayName !== 'string' || data.displayName.trim().length < 1 || data.displayName.length > 30 ||
          !integer(data.points) || players.has(data.playerId)) return error(res, 400, 'Invalid or duplicate mock player');
      const player = { playerId: data.playerId, displayName: data.displayName.trim(), avatar: '🎲', points: data.points, reserved: 0 };
      players.set(data.playerId, player);
      return json(res, 201, player);
    }
    if (path === '/mock/admin/credit' && req.method === 'POST') {
      const player = requirePlayer(data.playerId);
      if (!player || !integer(data.points)) return error(res, 400, 'Invalid player or points');
      player.points += data.points;
      return json(res, 200, { points: player.points });
    }
    if (path === '/mock/admin/fail-next' && req.method === 'POST') {
      failNext = typeof data.path === 'string' ? { path: data.path, skip: Number.isInteger(data.skip) && data.skip >= 0 ? data.skip : 0 } : null;
      return json(res, 200, { ok: true, failNext });
    }
    if (path === '/mock/admin/state' && req.method === 'GET') {
      return json(res, 200, { players: [...players.values()], reservations: [...reservations.values()], transactions: [...transactions.entries()], commissionPoints });
    }
  }
  if (req.headers.authorization !== `Bearer ${key}`) return error(res, 401, 'Service authorization required');
  if (failNext?.path === path) {
    if (failNext.skip > 0) failNext.skip--;
    else { failNext = null; return error(res, 503, 'Injected mock failure'); }
  }
  if (path === '/ludo/session/verify' && req.method === 'POST') {
    const launch = launchCodes.get(data.sessionToken);
    if (!launch || launch.expiresAt <= Date.now()) return error(res, 401, 'Launch invalid, expired, or replayed');
    launchCodes.delete(data.sessionToken);
    const player = requirePlayer(launch.playerId);
    return json(res, 200, { playerId: player.playerId, displayName: player.displayName, avatar: player.avatar,
      launchId: launch.launchId, tenantId: 'local-mock', gameId: 'ludo-club', expiresAt: new Date(launch.expiresAt).toISOString() });
  }
  if (path === '/ludo/points/balance' && req.method === 'POST') {
    const player = requirePlayer(data.playerId);
    return player ? json(res, 200, { points: player.points, reserved: player.reserved }) : error(res, 404, 'Player not found');
  }
  if (path === '/ludo/points/transaction-status' && req.method === 'POST') {
    const tx = transactions.get(data.reference);
    return tx ? json(res, 200, tx.data) : error(res, 404, 'Transaction unknown');
  }
  const idem = req.headers['idempotency-key'];
  if (path === '/ludo/points/purchase' && req.method === 'POST') {
    const response = idempotent(idem, () => {
      const player = requirePlayer(data.playerId);
      if (!player || !integer(data.points) || data.points === 0 || data.reference !== idem) return result(400, { error: 'Invalid purchase' });
      if (player.points < data.points) return result(402, { approved: false, status: 'DECLINED', reference: idem, error: 'Insufficient points' });
      player.points -= data.points;
      return result(200, { approved: true, reference: idem, points: player.points, status: 'COMMITTED' });
    }, data, path);
    return json(res, response.status, response.data);
  }
  if (path === '/ludo/points/reserve' && req.method === 'POST') {
    const response = idempotent(idem, () => {
      const player = requirePlayer(data.playerId);
      if (!player || !integer(data.points) || data.points === 0 || data.reference !== idem) return result(400, { error: 'Invalid reservation' });
      if (player.points < data.points) return result(402, { status: 'DECLINED', reference: idem, error: 'Insufficient points' });
      player.points -= data.points; player.reserved += data.points;
      const reservation = { reservationId: randomUUID(), playerId: data.playerId, matchId: data.matchId, points: data.points, status: 'RESERVED', reference: idem };
      reservations.set(reservation.reservationId, reservation);
      return result(200, reservation);
    }, data, path);
    return json(res, response.status, response.data);
  }
  if (['/ludo/points/commit', '/ludo/points/release'].includes(path) && req.method === 'POST') {
    const response = idempotent(idem, () => {
      const reservation = reservations.get(data.reservationId);
      if (!reservation || reservation.playerId !== data.playerId) return result(404, { error: 'Reservation not found' });
      const target = path.endsWith('/commit') ? 'COMMITTED' : 'RELEASED';
      if (reservation.status !== 'RESERVED') return result(409, { error: 'Reservation already finalized', status: reservation.status });
      const player = requirePlayer(data.playerId);
      player.reserved -= reservation.points;
      if (target === 'RELEASED') player.points += reservation.points;
      reservation.status = target;
      return result(200, { reservationId: reservation.reservationId, status: target, reference: idem });
    }, data, path);
    return json(res, response.status, response.data);
  }
  if (path === '/ludo/points/settle' && req.method === 'POST') {
    const response = idempotent(idem, () => {
      if (!Array.isArray(data.awards) || data.reference !== idem || !data.matchId ||
          data.funding !== 'committed-entry-escrow' || !integer(data.commissionPoints)) return result(400, { error: 'Invalid settlement' });
      for (const award of data.awards) if (!requirePlayer(award.playerId) || !integer(award.points)) return result(400, { error: 'Invalid award' });
      const funded = [...reservations.values()].filter(r => r.matchId === data.matchId && r.status === 'COMMITTED');
      const pool = funded.reduce((sum, r) => sum + r.points, 0);
      const distributed = data.awards.reduce((sum, award) => sum + award.points, data.commissionPoints);
      if (pool === 0 || pool !== distributed || data.awards.some(a => !funded.some(r => r.playerId === a.playerId)))
        return result(409, { error: 'Committed entry escrow mismatch' });
      if ([...transactions.keys()].some(k => k.startsWith(`ludo:settle:${data.matchId}`)))
        return result(409, { error: 'Match already settled' });
      for (const award of data.awards) requirePlayer(award.playerId).points += award.points;
      commissionPoints += data.commissionPoints;
      return result(200, { status: 'SETTLED', reference: idem, matchId: data.matchId, commissionPoints: data.commissionPoints });
    }, data, path);
    return json(res, response.status, response.data);
  }
  error(res, 404, 'Mock endpoint not found');
});
server.listen(port, '127.0.0.1', () => console.log(`Local mock platform: http://127.0.0.1:${port}`));
