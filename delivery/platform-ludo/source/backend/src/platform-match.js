import { Game, User, Audit } from './models.js';
import { assert } from './engine.js';
import { policyTier } from './match-policy.js';
import { randomUUID } from 'node:crypto';

const terminal = new Set(['SETTLED', 'RELEASED', 'MANUAL_REVIEW']);
const ref = (kind, matchId, platformId) => `ludo:${kind}:${matchId}${platformId ? `:${platformId}` : ''}`;

// Persist intent before every external call. A replay always uses the same match ID and key.
export class PlatformMatchFinance {
  constructor(service, adapter, policy) { this.service = service; this.adapter = adapter; this.policy = policy; }

  async save(game, action, reference = '') {
    if (game.financeLeaseOwner) game.financeLeaseUntil = new Date(Date.now() + 30000);
    game.markModified('platformFinance');
    await game.save();
    if (action) await Audit.create({ actor: 'platform-match', action, target: String(game._id), reference,
      reason: game.platformFinance.state });
  }

  async begin(id) {
    let game = await Game.findById(id);
    assert(game?.status === 'waiting' && game.members.length === game.capacity, 'Room must be full', 409);
    assert(game.stakeMinor > 0 && !game.platformFinance, 'Match funding already started', 409);
    const tier = policyTier(this.policy, game.stakeMinor, game.capacity);
    const users = await User.find({ _id: { $in: game.members } });
    assert(users.length === game.capacity && users.every(u => u.platformId), 'Verified platform players required', 403);
    const finance = { state: 'RESERVING', policy: tier, participants: game.members.map(id => {
      const user = users.find(u => String(u._id) === id);
      return { userId: id, platformId: user.platformId, reserve: 'NONE', commit: 'NONE', release: 'NONE' };
    }) };
    const inserted = await Game.updateOne({ _id: id, status: 'waiting', platformFinance: { $exists: false } },
      { $set: { platformFinance: finance } });
    if (inserted.modifiedCount !== 1) return this.progress(id);
    await Audit.create({ actor: 'platform-match', action: 'funding_started', target: id, reason: 'RESERVING' });
    return this.progress(id);
  }

  async callOrStatus(work, reference, expected) {
    try { return await work(); }
    catch (error) {
      if (error.status === 402) return { status: 'DECLINED' };
      let status;
      try { status = await this.adapter.transactionStatus(reference); } catch { return null; }
      if (status.status === 'UNKNOWN' || status.status === 'PENDING') return null;
      if (status.status === 'DECLINED') return status;
      if (status.status === expected) return status;
      return { status: 'CONFLICT', observed: status.status };
    }
  }

  async cancel(game, reason) {
    const f = game.platformFinance;
    if (f.state === 'RESERVING' || f.state === 'RESERVED') {
      f.state = 'RELEASING'; f.cancelReason = reason;
      await this.save(game, 'funding_cancelling');
      return this.progress(String(game._id));
    }
    if (f.state === 'COMMITTING' || f.state === 'FUNDED') {
      f.state = 'MANUAL_REVIEW'; f.cancelReason = reason;
      await this.save(game, 'funding_manual_review');
      return this.service.view(game);
    }
    return this.service.view(game);
  }

  async progress(id) {
    const owner = randomUUID();
    const leased = await Game.findOneAndUpdate({ _id: id,
      $or: [{ financeLeaseUntil: { $exists: false } }, { financeLeaseUntil: { $lt: new Date() } }] },
      { $set: { financeLeaseOwner: owner, financeLeaseUntil: new Date(Date.now() + 30000) } }, { new: true });
    if (!leased) { const current = await Game.findById(id); return current && this.service.view(current); }
    try { return await this.advance(id); }
    finally { await Game.updateOne({ _id: id, financeLeaseOwner: owner },
      { $unset: { financeLeaseOwner: 1, financeLeaseUntil: 1 } }); }
  }

  async advance(id) {
    let game = await Game.findById(id);
    if (!game?.platformFinance || terminal.has(game.platformFinance.state)) return game && this.service.view(game);
    const f = game.platformFinance;
    const matchId = String(game._id);
    if (f.state === 'RESERVING' || f.state === 'RELEASING') {
      for (const p of f.participants) {
        if (p.reserve !== 'NONE' && p.reserve !== 'PENDING') continue;
        const reference = ref('reserve', matchId, p.platformId);
        if (p.reserve === 'NONE') { p.reserve = 'PENDING'; await this.save(game, 'reservation_intent', reference); }
        const response = await this.callOrStatus(() => this.adapter.reserve(p.platformId, matchId, f.policy.points), reference, 'RESERVED');
        if (!response) return this.service.view(game);
        if (response.status === 'CONFLICT') { f.state = 'MANUAL_REVIEW'; await this.save(game, 'reserve_conflict', reference); return this.service.view(game); }
        if (response.status === 'DECLINED') { p.reserve = 'DECLINED'; f.state = 'RELEASING'; }
        else {
          assert(response.status === 'RESERVED' && response.reference === reference && typeof response.reservationId === 'string', 'Invalid reservation status', 502);
          p.reserve = 'RESERVED'; p.reservationId = response.reservationId;
        }
        await this.save(game, 'reservation_result', reference);
        if (f.state === 'RELEASING') break;
      }
    }
    if (f.state === 'RELEASING') {
      for (const p of f.participants) {
        if (p.reserve === 'NONE') continue;
        if (p.reserve === 'PENDING') {
          const reference = ref('reserve', matchId, p.platformId);
          const response = await this.callOrStatus(() => this.adapter.reserve(p.platformId, matchId, f.policy.points), reference, 'RESERVED');
          if (!response) return this.service.view(game);
          if (response.status === 'DECLINED') p.reserve = 'DECLINED';
          else if (response.status === 'RESERVED' && response.reference === reference && response.reservationId) {
            p.reserve = 'RESERVED'; p.reservationId = response.reservationId;
          } else { f.state = 'MANUAL_REVIEW'; await this.save(game, 'reserve_conflict', reference); return this.service.view(game); }
          await this.save(game, 'reservation_result', reference);
        }
        if (p.reserve !== 'RESERVED' || p.release === 'RELEASED') continue;
        const reference = ref('release', matchId, p.platformId);
        const response = await this.callOrStatus(() => this.adapter.release(p.platformId, p.reservationId, matchId), reference, 'RELEASED');
        if (!response) return this.service.view(game);
        if (response.status !== 'RELEASED' || response.reference !== reference || response.reservationId !== p.reservationId) {
          f.state = 'MANUAL_REVIEW'; await this.save(game, 'release_conflict', reference); return this.service.view(game);
        }
        p.release = 'RELEASED'; await this.save(game, 'reservation_released', reference);
      }
      f.state = 'RELEASED'; game.status = 'cancelled'; game.settled = true; game.endedAt = new Date();
      await this.service.transaction(async session => {
        await User.updateMany({ _id: { $in: game.members }, activeGame: matchId }, { activeGame: null }, { session });
        game.markModified('platformFinance'); await game.save({ session });
      });
      await Audit.create({ actor: 'platform-match', action: 'funding_released', target: matchId, reason: f.cancelReason || 'pre-start cancellation' });
      return this.service.publish(matchId);
    }
    if (f.state === 'RESERVING' && f.participants.every(p => p.reserve === 'RESERVED')) {
      f.state = 'COMMITTING'; await this.save(game, 'all_reserved');
    }
    if (f.state === 'COMMITTING') {
      for (const p of f.participants) {
        if (p.commit === 'COMMITTED') continue;
        const reference = ref('commit', matchId, p.platformId);
        const response = await this.callOrStatus(() => this.adapter.commit(p.platformId, p.reservationId, matchId), reference, 'COMMITTED');
        if (!response) return this.service.view(game);
        if (response.status !== 'COMMITTED' || response.reference !== reference || response.reservationId !== p.reservationId) {
          f.state = 'MANUAL_REVIEW'; await this.save(game, 'commit_conflict', reference); return this.service.view(game);
        }
        p.commit = 'COMMITTED'; await this.save(game, 'reservation_committed', reference);
      }
      f.state = 'FUNDED'; await this.save(game, 'all_committed');
    }
    if (f.state === 'FUNDED') {
      await this.service.transaction(async session => {
        game = await Game.findById(matchId).session(session);
        assert(game.status === 'waiting' && game.platformFinance.state === 'FUNDED', 'Funding state changed', 409);
        await this.service.startDocument(game, session);
        game.platformFinance.state = 'IN_PROGRESS'; game.markModified('platformFinance'); await game.save({ session });
      });
      return this.service.publish(matchId);
    }
    if (f.state === 'SETTLING') {
      const awards = game.status === 'cancelled'
        ? f.participants.map(p => ({ playerId: p.platformId, points: f.policy.points }))
        : [{ playerId: f.participants.find(p => p.userId === game.state.winner)?.platformId,
          points: f.policy.winnerPoints }];
      assert(awards.every(a => a.playerId), 'Financial winner missing', 409);
      const commissionPoints = game.status === 'cancelled' ? 0 : f.policy.commissionPoints;
      assert(awards.reduce((sum, a) => sum + a.points, commissionPoints) === f.policy.points * game.capacity,
        'Settlement does not conserve entries', 409);
      const reference = ref('settle', matchId);
      const response = await this.callOrStatus(() => this.adapter.settle(matchId, awards, commissionPoints), reference, 'SETTLED');
      if (!response) return this.service.view(game);
      if (response.status !== 'SETTLED' || response.reference !== reference || response.matchId !== matchId) {
        f.state = 'MANUAL_REVIEW'; await this.save(game, 'settlement_conflict', reference); return this.service.view(game);
      }
      f.state = 'SETTLED'; f.settlementReference = reference; await this.save(game, 'settlement_confirmed', reference);
    }
    return this.service.view(game);
  }
}
