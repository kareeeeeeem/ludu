import { randomUUID } from 'node:crypto';
import { assert } from './engine.js';

// The host platform is the authority for identity and points. Calls fail closed.
export class PlatformAdapter {
  constructor(config = {}) {
    this.url = config.platformApiUrl?.replace(/\/$/, '');
    this.key = config.platformApiKey;
    this.mock = config.platformMock === true;
    this.cosmeticPrices = config.platformCosmeticPrices || {};
  }

  async request(path, body, idempotencyKey) {
    assert(this.url && this.key, 'Platform API is not configured', 503);
    let response;
    try {
      response = await fetch(`${this.url}${path}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', Authorization: `Bearer ${this.key}`,
          ...(idempotencyKey ? { 'Idempotency-Key': idempotencyKey } : {}) },
        body: JSON.stringify(body), signal: AbortSignal.timeout(10000)
      });
    } catch { assert(false, 'Platform API unavailable', 503); }
    const status = path === '/ludo/session/verify' && [400, 401, 403].includes(response.status)
      ? 401 : response.status === 402 ? 402 : 503;
    if (path === '/ludo/points/transaction-status' && response.status === 404) return { status: 'UNKNOWN' };
    assert(response.ok, 'Platform rejected request', status);
    return response.json();
  }

  async verify(sessionToken) {
    assert(typeof sessionToken === 'string' && sessionToken.length > 0 && sessionToken.length <= 4096, 'Platform session required', 401);
    if (this.mock) {
      assert(/^mock:[a-zA-Z0-9_-]{3,64}$/.test(sessionToken), 'Invalid mock platform session', 401);
      return { playerId: sessionToken.slice(5), displayName: 'Club Player', avatar: '🎲',
        launchId: randomUUID(), gameId: 'ludo-club', tenantId: 'local-mock',
        expiresAt: new Date(Date.now() + 60000).toISOString() };
    }
    const data = await this.request('/ludo/session/verify', { sessionToken });
    assert(typeof data.playerId === 'string' && /^[\w:.-]{3,128}$/.test(data.playerId), 'Invalid platform identity', 502);
    assert(typeof data.launchId === 'string' && /^[\w:.-]{8,128}$/.test(data.launchId), 'Invalid launch ID', 502);
    assert(data.gameId === 'ludo-club', 'Launch not authorized for Ludo', 403);
    const expiry = Date.parse(data.expiresAt);
    assert(Number.isFinite(expiry) && expiry > Date.now() && expiry <= Date.now() + 300000, 'Launch expired or invalid', 401);
    return data;
  }

  async balance(playerId) {
    if (this.mock) return { points: 0, currency: 'PLATFORM_POINTS', available: true };
    const data = await this.request('/ludo/points/balance', { playerId });
    assert(Number.isSafeInteger(data.points) && data.points >= 0, 'Invalid platform balance', 502);
    return { points: data.points, currency: 'PLATFORM_POINTS', available: true };
  }

  async purchase(playerId, itemId, points, reference) {
    assert(Number.isSafeInteger(points) && points >= 0, 'Invalid point price', 400);
    if (points === 0) return { approved: true };
    // The mock never reports a paid purchase as successful.
    assert(!this.mock, 'Paid cosmetics require platform billing', 503);
    const key = reference;
    assert(typeof key === 'string' && key.startsWith(`ludo:cosmetic:${playerId}:`), 'Invalid purchase reference', 400);
    const data = await this.request('/ludo/points/purchase',
      { playerId, itemId, points, reference: key }, key);
    assert(data.approved === true, 'Platform purchase was not approved', 402);
    return data;
  }

  async transactionStatus(reference) {
    assert(typeof reference === 'string' && reference.length <= 200, 'Invalid transaction reference', 400);
    return this.request('/ludo/points/transaction-status', { reference });
  }

  async reserve(playerId, matchId, points) {
    assert(Number.isSafeInteger(points) && points > 0, 'Invalid entry points', 400);
    const reference = `ludo:reserve:${matchId}:${playerId}`;
    const data = await this.request('/ludo/points/reserve', { playerId, matchId, points, reference }, reference);
    assert(data.status === 'RESERVED' && typeof data.reservationId === 'string' && data.reference === reference,
      'Invalid platform reservation', 502);
    return data;
  }

  async commit(playerId, reservationId, matchId) {
    const reference = `ludo:commit:${matchId}:${playerId}`;
    const data = await this.request('/ludo/points/commit', { playerId, reservationId, matchId, reference }, reference);
    assert(data.status === 'COMMITTED' && data.reference === reference && data.reservationId === reservationId,
      'Invalid platform commit', 502);
    return data;
  }

  async release(playerId, reservationId, matchId) {
    const reference = `ludo:release:${matchId}:${playerId}`;
    const data = await this.request('/ludo/points/release', { playerId, reservationId, matchId, reference }, reference);
    assert(data.status === 'RELEASED' && data.reference === reference && data.reservationId === reservationId,
      'Invalid platform release', 502);
    return data;
  }

  async settle(matchId, awards, commissionPoints = 0) {
    assert(Array.isArray(awards) && awards.every(a => typeof a.playerId === 'string' && Number.isSafeInteger(a.points) && a.points >= 0), 'Invalid settlement awards', 400);
    assert(Number.isSafeInteger(commissionPoints) && commissionPoints >= 0, 'Invalid commission', 400);
    const reference = `ludo:settle:${matchId}`;
    const data = await this.request('/ludo/points/settle', { matchId, awards, commissionPoints, funding: 'committed-entry-escrow', reference }, reference);
    assert(data.status === 'SETTLED' && data.reference === reference && data.matchId === matchId,
      'Invalid platform settlement', 502);
    return data;
  }

  cosmeticPrice(item) {
    if (item.priceCoins === 0) return 0;
    const price = this.cosmeticPrices[item.id];
    return Number.isSafeInteger(price) && price > 0 ? price : null;
  }

  reference() { return randomUUID(); }
}
