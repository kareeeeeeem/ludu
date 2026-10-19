import mongoose from 'mongoose';
import { randomBytes, randomUUID } from 'node:crypto';
import { User, Game, Event, Chat, Queue, MoneyStake, Audit } from './models.js';
import { assert, newState, act, legalMoves, botAction } from './engine.js';
import { ensureWallet, changeWallet, reserveStake, releaseStake, captureStake, refundStake, validMinor } from './wallet.js';
import { PlatformMatchFinance } from './platform-match.js';

// One process owns scheduling. MongoDB transactions also protect against races and crashes.
export class GameService {
  constructor(io, platform, matchPolicy) { this.io = io; this.tail = Promise.resolve(); this.platformFinance = new PlatformMatchFinance(this, platform, matchPolicy); }
  serial(fn) { const run = this.tail.then(fn); this.tail = run.catch(() => {}); return run; }
  async transaction(fn) { return mongoose.connection.transaction(fn); }
  async publish(id) {
    const game = await Game.findById(id).lean();
    if (!game) return;
    const data = this.view(game);
    for (const user of game.members.filter(m => !m.startsWith('bot:'))) this.io.to(`user:${user}`).emit('game_state', data);
    return data;
  }
  view(game) { const data = game?.toObject ? game.toObject() : game; return { ...data, id: String(data._id), legalMoves: data.state ? legalMoves(data.state) : [], serverTime: Date.now() }; }
  async available(id, session) {
    const user = await User.findById(id).session(session);
    assert(user?.isActive, 'Account unavailable', 403);
    assert(!user.activeGame, 'Finish or leave your current game or queue first', 409);
    if (!user.platformId) await ensureWallet(user, session);
    return user;
  }
  async create(userId, capacity, mode = 'private', stakeMinor = 0) {
    assert([2, 4].includes(capacity), 'Choose 2 or 4 players');
    validMinor(stakeMinor, { zero: true });
    const fee = mode === 'practice' ? 0 : stakeMinor;
    return this.serial(async () => {
      let id;
      await this.transaction(async session => {
        const user = await this.available(userId, session);
        const members = [userId]; const names = [user.platformId ? user.displayName || 'Club Player' : user.username];
        if (mode === 'practice') for (let i = 1; i < capacity; i++) { members.push(`bot:${randomBytes(6).toString('hex')}`); names.push(`Bot ${i}`); }
        const [game] = await Game.create([{ code: randomBytes(5).toString('hex').toUpperCase(), host: userId, capacity, mode, members, names, stakeMinor: fee }], { session });
        id = String(game._id);
        if (fee > 0 && !user.platformId) {
          await reserveStake(userId, fee, `game:${id}:${userId}`, session, { gameId: id });
          game.fundingState = 'FUNDS_RESERVED'; await game.save({ session });
        }
        user.activeGame = id; await user.save({ session });
        if (mode === 'practice') await this.startDocument(game, session);
      });
      return this.publish(id);
    });
  }
  async startDocument(game, session) {
    assert(game.status === 'waiting', 'Room already started', 409);
    assert(game.members.length === game.capacity, 'Room must be full', 409);
    const fee = game.stakeMinor || 0;
    if (fee > 0 && !game.platformFinance) {
      const humans = game.members.filter(m => !m.startsWith('bot:'));
      const stakes = await MoneyStake.find({ gameId: String(game._id), state: 'RESERVED' }).session(session);
      assert(game.fundingState === 'FUNDS_RESERVED', 'Stakes are not reserved', 409);
      assert(stakes.length === humans.length && new Set(stakes.map(s => s.userId)).size === humans.length && stakes.every(s => s.amountMinor === fee && humans.includes(s.userId)), 'Every player must fund the match', 409);
      for (const stake of stakes) await captureStake(stake, session);
      game.prizePoolMinor = stakes.reduce((sum, stake) => sum + stake.amountMinor, 0);
    }
    const profiles = await User.find({ _id: { $in: game.members.filter(id => !id.startsWith('bot:')) } })
      .select('equipped').session(session);
    const equipment = new Map(profiles.map(user => [String(user._id), user.toObject().equipped]));
    game.state = newState(game.members.map((id, i) => ({ id, name: game.names[i],
      equipped: equipment.get(id) || { dice: 'dice_classic', token: 'token_classic', board: 'board_classic', frame: 'frame_bronze' } })));
    game.initial = structuredClone(game.state); game.status = 'active'; game.fundingState = 'STARTED';
    await game.save({ session });
  }
  async join(userId, code) {
    return this.serial(async () => {
      let id;
      await this.transaction(async session => {
        const user = await this.available(userId, session);
        const game = await Game.findOne({ code }).session(session);
        assert(game && game.mode === 'private' && game.status === 'waiting', 'Room unavailable', 404);
        assert(game.members.length < game.capacity, 'Room is full', 409);
        const fee = game.stakeMinor || 0;
        if (fee > 0) {
          const host = await User.findById(game.host).session(session);
          assert(!!host?.platformId === !!user.platformId, 'Match funding providers cannot be mixed', 403);
        }
        if (fee > 0 && !user.platformId) await reserveStake(userId, fee, `game:${game._id}:${userId}`, session, { gameId: String(game._id) });
        game.members.push(userId); game.names.push(user.platformId ? user.displayName || 'Club Player' : user.username); id = String(game._id);
        if (fee > 0 && !user.platformId) game.fundingState = 'FUNDS_RESERVED';
        user.activeGame = id; await user.save({ session }); await game.save({ session });
      }); return this.publish(id);
    });
  }
  async start(userId, id) {
    return this.serial(async () => {
      const waiting = await Game.findById(id);
      assert(waiting && waiting.host === userId, 'Only the host can start', 403);
      if (waiting.stakeMinor > 0 && !waiting.platformFinance) {
        const host = await User.findById(userId);
        if (host?.platformId) return this.platformFinance.begin(id);
      }
      if (waiting.platformFinance) return this.platformFinance.progress(id);
      await this.transaction(async session => {
        const game = await Game.findById(id).session(session);
        assert(game && game.host === userId, 'Only the host can start', 403);
        await this.startDocument(game, session);
      }); return this.publish(id);
    });
  }
  async settle(game, session) {
    if (game.settled) return;
    assert(['completed', 'cancelled'].includes(game.status), 'Match is not final', 409);
    game.fundingState = game.status === 'completed' ? 'COMPLETED' : 'CANCELLED';
    game.settled = true; game.endedAt = new Date();
    const humans = game.members.filter(m => !m.startsWith('bot:'));
    const users = await User.find({ _id: { $in: humans } }).session(session);
    const fee = game.stakeMinor || 0;
    const prizePool = game.prizePoolMinor || 0;
    const stakes = await MoneyStake.find({ gameId: String(game._id) }).session(session);
    if (game.status === 'completed' && fee > 0 && !game.platformFinance) {
      assert(game.state?.winner && humans.includes(game.state.winner), 'Invalid financial winner', 409);
      assert(stakes.length === humans.length && new Set(stakes.map(s => s.userId)).size === humans.length && stakes.every(s => s.state === 'CAPTURED' && s.amountMinor === fee && humans.includes(s.userId)), 'Captured stakes do not match participants', 409);
      assert(prizePool === stakes.reduce((sum, stake) => sum + stake.amountMinor, 0), 'Prize pool does not match captured stakes', 409);
    }
    if (game.status === 'cancelled' && !game.platformFinance) {
      for (const stake of stakes) {
        if (stake.state === 'RESERVED') await releaseStake(stake, session);
        else if (stake.state === 'CAPTURED') await refundStake(stake, session);
      }
      if (stakes.length > 0 || prizePool > 0) game.fundingState = 'REFUNDED';
    }
    for (const user of users) {
      user.activeGame = null;
      if (game.status === 'completed' && game.mode !== 'practice') {
        const won = String(user._id) === game.state?.winner;
        user.games++; user.wins += won ? 1 : 0; user.losses += won ? 0 : 1;
        user.streak = won ? user.streak + 1 : 0; user.bestStreak = Math.max(user.bestStreak, user.streak);
        const others = users.filter(u => String(u._id) !== String(user._id));
        const expected = others.reduce((sum, o) => sum + 1 / (1 + 10 ** ((o.rating - user.rating) / 400)), 0) / (others.length || 1);
        user.$locals.delta = Math.round(24 * ((won ? 1 : 0) - expected));
        if (won && prizePool > 0) {
          assert(!user.platformId, 'Platform matches cannot use the legacy wallet', 503);
          await ensureWallet(user, session);
          await changeWallet(String(user._id), prizePool, 0, 'PRIZE', `prize:${game._id}`, session, { amountMinor: prizePool, matchId: String(game._id) });
        }
      }
    }
    if (game.platformFinance) {
      assert(game.platformFinance.state === 'IN_PROGRESS', 'Platform match not funded', 409);
      game.platformFinance.state = 'SETTLING'; game.markModified('platformFinance');
    } else if (game.status === 'completed') game.fundingState = 'SETTLED';
    for (const user of users) { user.rating += user.$locals.delta || 0; await user.save({ session }); }
    await game.save({ session });
  }
  async action(userId, id, action, revision) {
    return this.serial(async () => {
      await this.transaction(async session => {
        const game = await Game.findById(id).session(session);
        assert(game && game.members.includes(userId), 'Game unavailable', 404);
        assert(game.status === 'active', 'Game is not active', 409);
        assert(revision === game.state.revision, 'State changed; refresh and retry', 409);
        game.state = act(game.state, userId, action); game.status = game.state.status;
        await Event.create([{ game: id, revision: game.state.revision, actor: userId, action, state: game.state }], { session });
        if (game.status === 'completed') await this.settle(game, session); else await game.save({ session });
      });
      const game = await Game.findById(id);
      if (game.platformFinance?.state === 'SETTLING') await this.platformFinance.progress(id);
      return this.publish(id);
    });
  }
  async leave(userId, id) {
    return this.serial(async () => {
      const waiting = await Game.findById(id);
      if (waiting?.platformFinance) {
        assert(waiting.members.includes(userId) && waiting.status === 'waiting', 'Room unavailable', 409);
        return this.platformFinance.cancel(waiting, 'player left before start');
      }
      await this.transaction(async session => {
        const game = await Game.findById(id).session(session);
        assert(game?.members.includes(userId), 'Game unavailable', 404);
        assert(game.status === 'waiting', 'Use forfeit for an active game', 409);
        if (game.host === userId) { game.status = 'cancelled'; await this.settle(game, session); }
        else {
          const stake = await MoneyStake.findOne({ gameId: id, userId, state: 'RESERVED' }).session(session);
          if (stake) await releaseStake(stake, session);
          const i = game.members.indexOf(userId); game.members.splice(i, 1); game.names.splice(i, 1);
          if (game.stakeMinor > 0 && !(await MoneyStake.exists({ gameId: id, state: 'RESERVED' }).session(session))) game.fundingState = 'WAITING';
          await User.updateOne({ _id: userId, activeGame: id }, { activeGame: null }, { session }); await game.save({ session });
        }
      }); return this.publish(id);
    });
  }
  async queue(userId, capacity, stakeMinor = 0) {
    assert([2, 4].includes(capacity), 'Choose 2 or 4 players');
    validMinor(stakeMinor, { zero: true });
    await this.serial(() => this.transaction(async session => {
      const user = await this.available(userId, session);
      let stakeRef;
      if (stakeMinor > 0 && !user.platformId) {
        stakeRef = `queue:${userId}:${randomUUID()}`;
        await reserveStake(userId, stakeMinor, stakeRef, session, { queueId: userId });
      }
      user.activeGame = 'queue'; await user.save({ session });
      await Queue.create([{ userId, username: user.platformId ? user.displayName || 'Club Player' : user.username, capacity, rating: user.rating, platformPlayer: !!user.platformId, stakeMinor, stakeRef }], { session });
    }));
    await this.match(); return this.queueStatus(userId);
  }
  async queueStatus(userId) {
    const q = await Queue.findOne({ userId }).lean(); const u = await User.findById(userId).lean();
    return { queued: !!q, queuedAt: q?.createdAt, capacity: q?.capacity, gameId: u?.activeGame === 'queue' ? null : u?.activeGame };
  }
  async unqueue(userId) {
    await this.serial(() => this.transaction(async session => {
      const queued = await Queue.findOne({ userId }).session(session);
      if (queued?.stakeRef) {
        const stake = await MoneyStake.findOne({ reference: queued.stakeRef, state: 'RESERVED' }).session(session);
        if (stake) await releaseStake(stake, session);
      }
      await Queue.deleteOne({ userId }, { session });
      await User.updateOne({ _id: userId, activeGame: 'queue' }, { activeGame: null }, { session });
    })); return this.queueStatus(userId);
  }
  async match() {
    return this.serial(async () => {
      const queue = await Queue.find().sort({ createdAt: 1 }).lean();
      const used = new Set();
      for (const first of queue) {
        if (used.has(first.userId)) continue;
        const window = 100 + Math.floor((Date.now() - first.createdAt.getTime()) / 1000) * 10;
        const group = queue.filter(q => !used.has(q.userId) && q.capacity === first.capacity && q.stakeMinor === first.stakeMinor && !!q.platformPlayer === !!first.platformPlayer && Math.abs(q.rating - first.rating) <= window).slice(0, first.capacity);
        if (group.length !== first.capacity) continue;
        let id; let platformMatch = false;
        await this.transaction(async session => {
          const members = group.map(q => q.userId);
          assert(await Queue.countDocuments({ userId: { $in: members } }).session(session) === members.length, 'Queue changed', 409);
          const [game] = await Game.create([{ code: randomBytes(5).toString('hex').toUpperCase(), host: members[0], mode: 'quick', capacity: first.capacity, members, names: group.map(q => q.username), stakeMinor: first.stakeMinor }], { session });
          id = String(game._id);
          const platformPlayers = first.stakeMinor > 0 && (await User.findById(members[0]).session(session))?.platformId;
          platformMatch = !!platformPlayers;
          if (first.stakeMinor > 0 && !platformPlayers) {
            for (const queued of group) {
              if (!queued.stakeRef) {
                const user = await User.findById(queued.userId).session(session);
                await ensureWallet(user, session);
                queued.stakeRef = `queue:${queued.userId}:${randomUUID()}`;
                await reserveStake(queued.userId, first.stakeMinor, queued.stakeRef, session, { queueId: queued.userId });
              }
              const stake = await MoneyStake.findOne({ reference: queued.stakeRef, state: 'RESERVED', userId: queued.userId }).session(session);
              assert(stake && stake.amountMinor === first.stakeMinor, 'Queued stake missing', 409);
              stake.gameId = id; stake.queueId = null; await stake.save({ session });
            }
            game.fundingState = 'FUNDS_RESERVED'; await game.save({ session });
          }
          await User.updateMany({ _id: { $in: members } }, { activeGame: id }, { session });
          await Queue.deleteMany({ userId: { $in: members } }, { session });
          if (!platformPlayers) await this.startDocument(game, session);
        }); group.forEach(q => used.add(q.userId));
        if (platformMatch) await this.platformFinance.begin(id);
        await this.publish(id);
      }
    });
  }
  async chat(user, id, message) {
    const game = await Game.findById(id).lean();
    assert(game?.members.includes(String(user._id)), 'Game unavailable', 404);
    assert(['active', 'waiting'].includes(game.status), 'Chat has closed', 409);
    const chat = await Chat.create({ game: id, userId: String(user._id), username: user.platformId ? user.displayName || 'Club Player' : user.username, message });
    for (const member of game.members) this.io.to(`user:${member}`).emit('chat_message', chat.toObject());
    return chat;
  }
  async moderate(actor, id, action, winner, reason) {
    return this.serial(async () => {
      const waiting = await Game.findById(id);
      if (action === 'cancel' && waiting?.status === 'waiting' && waiting.platformFinance)
        return this.platformFinance.cancel(waiting, reason);
      await this.transaction(async session => {
        const game = await Game.findById(id).session(session);
        assert(game && ['waiting', 'active'].includes(game.status), 'Game already closed', 409);
        if (action === 'result') {
          assert(!game.stakeMinor, 'Force winner is disabled for financial matches', 403);
          assert(game.status === 'active' && game.members.includes(winner) && !game.state.players.find(p => p.id === winner).eliminated, 'Invalid winner');
          game.state = { ...game.state, status: 'completed', winner, revision: game.state.revision + 1 }; game.status = 'completed';
          await Event.create([{ game: id, revision: game.state.revision, actor, action: { type: 'admin_result', reason }, state: game.state }], { session });
        } else { game.status = 'cancelled'; if (game.state) game.state = { ...game.state, status: 'cancelled', revision: game.state.revision + 1 }; }
        await this.settle(game, session);
        await Audit.create([{ actor, action, target: id, reason }], { session });
      });
      const game = await Game.findById(id);
      if (game.platformFinance?.state === 'SETTLING') await this.platformFinance.progress(id);
      return this.publish(id);
    });
  }
  async tick() {
    if (this.ticking) return; this.ticking = true;
    try {
      const pending = await Game.find({ 'platformFinance.state': { $in: ['RESERVING', 'RELEASING', 'COMMITTING', 'FUNDED', 'SETTLING'] } }).select('_id').lean();
      for (const game of pending) await this.serial(() => this.platformFinance.progress(String(game._id)));
      await this.match();
      const games = await Game.find({ status: 'active' }).lean();
      for (const game of games) {
        const s = game.state; const player = s.players[s.turn];
        const action = Date.now() >= s.deadline ? { type: 'timeout' } : player.id.startsWith('bot:') ? botAction(s) : null;
        if (action) await this.action(player.id, String(game._id), action, s.revision).catch(e => { if (e.status !== 409) throw e; });
      }
      const abandoned = await Game.find({ status: 'waiting', createdAt: { $lt: new Date(Date.now() - 30 * 60000) } }).lean();
      for (const game of abandoned) await this.moderate('system', String(game._id), 'cancel', null, 'Room expired');
    } finally { this.ticking = false; }
  }
}
