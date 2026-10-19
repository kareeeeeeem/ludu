import express from 'express';
import { createServer } from 'node:http';
import { Server } from 'socket.io';
import cors from 'cors';
import helmet from 'helmet';
import { rateLimit } from 'express-rate-limit';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import { randomBytes, createHash, timingSafeEqual } from 'node:crypto';
import mongoose from 'mongoose';
import { z } from 'zod';
import { User, PlatformLaunch, CosmeticPurchase, MoneyWallet, MoneyStake, Game, Event, Chat, DepositRequest, WithdrawalRequest, Dispute, Audit, Queue, AppSetting } from './models.js';
import { assert } from './engine.js';
import { GameService } from './service.js';
import { ensureWallet, releaseStake, MAX_MINOR } from './wallet.js';
import { playerFinanceRoutes, adminFinanceRoutes } from './finance.js';
import { paymentSettings, phonePattern } from './settings.js';
import { PlatformAdapter } from './platform.js';
import { parseMatchPolicy, policyTier } from './match-policy.js';

const credentials = z.object({ email: z.email().max(254).transform(s => s.toLowerCase()), password: z.string().min(10).max(72).refine(value => Buffer.byteLength(value, 'utf8') <= 72, 'Password must fit within 72 UTF-8 bytes') });
const username = z.string().trim().min(3).max(24).regex(/^[\p{L}\p{N}_ -]+$/u);
const roomInput = z.object({ capacity: z.union([z.literal(2), z.literal(4)]), stakeMinor: z.number().int().min(0).max(MAX_MINOR).optional().default(0) }).strict();
const codeInput = z.object({ code: z.string().trim().toUpperCase().regex(/^[A-F0-9]{10}$/) });
const actionInput = z.object({ type: z.enum(['roll', 'move', 'forfeit']), token: z.number().int().min(0).max(3).optional(), revision: z.number().int().nonnegative() }).strict();
const messageInput = z.object({ message: z.string().trim().min(1).max(280) });
const reasonInput = z.object({ reason: z.string().trim().min(5).max(500) });
const adminPassword = credentials.shape.password;
const adminEmail = credentials.shape.email;
const idOf = user => String(user._id);
const publicUser = (u, wallet) => ({
  id: idOf(u),
  username: u.username,
  displayName: u.displayName || u.username,
  avatar: u.avatar || '🎲',
  role: u.role,
  ...(u.platformId ? { platformPlayer: true, pointsProvider: 'platform' } : {
    availableMinor: wallet?.availableMinor ?? 0, reservedMinor: wallet?.reservedMinor ?? 0,
    currency: 'EGP', coins: u.coins ?? 1000 }),
  inventory: u.inventory && u.inventory.length > 0 ? u.inventory : ['dice_classic', 'token_classic', 'board_classic', 'frame_bronze', 'emote_thumbsup'],
  equipped: u.equipped || { dice: 'dice_classic', token: 'token_classic', board: 'board_classic', frame: 'frame_bronze' },
  activeGame: u.activeGame,
  games: u.games,
  wins: u.wins,
  losses: u.losses,
  streak: u.streak,
  bestStreak: u.bestStreak,
  rating: u.rating
});
const hash = t => createHash('sha256').update(t).digest('hex');
const page = req => Math.max(0, Math.min(10000, Number(req.query.page) || 0));

export function createApp(config) {
  assert(config.secret?.length >= 32, 'JWT_SECRET must contain at least 32 characters');
  assert(!config.vodafoneReceivingNumber || config.vodafoneReceivingNumber.startsWith('LOCAL_DEMO_') || /^01[0125][0-9]{8}$/.test(config.vodafoneReceivingNumber), 'Invalid Vodafone Cash receiving number');
  const app = express(); const http = createServer(app);
  const origins = config.origins || ['http://localhost:8080'];
  const io = new Server(http, { cors: { origin: origins }, maxHttpBufferSize: 8192 });
  const platform = new PlatformAdapter(config);
  const platformMode = config.platformMode === true;
  const matchPolicy = parseMatchPolicy(config.platformMatchPolicy, { allowTest: config.test === true || (config.matchPolicyTestMode === true && process.env.NODE_ENV !== 'production') });
  const service = new GameService(io, platform, matchPolicy);
  const gameConfig = async () => await AppSetting.findOne({ key: 'game_config' }).lean()
    || { gameEnabled: true, maintenanceMessage: '', enabledModes: ['classic', 'practice'], matchTiers: [0], cosmeticAvailability: {} };
  const validateEntry = async (points, capacity) => {
    if (!platformMode || points === 0) return;
    policyTier(matchPolicy, points, capacity);
    const cfg = await gameConfig();
    assert((cfg.matchTiers || [0]).includes(points), 'Match tier is disabled', 403);
  };
  const safeServiceKey = value => {
    if (!config.platformAdminApiKey || typeof value !== 'string') return false;
    const expected = Buffer.from(config.platformAdminApiKey);
    const actual = Buffer.from(value);
    return expected.length === actual.length && timingSafeEqual(expected, actual);
  };
  app.use(helmet(), cors({ origin: origins }), express.json({ limit: '16kb' }));
  app.use('/api', rateLimit({ windowMs: 60000, limit: 180, standardHeaders: 'draft-8', legacyHeaders: false }));
  const authLimit = rateLimit({ windowMs: 15 * 60000, limit: config.test ? 1000 : 25 });
  const chatLimit = rateLimit({ windowMs: 10000, limit: 8 });
  const tokenFor = (u, launchId) => jwt.sign({ sub: idOf(u), v: u.tokenVersion, ...(launchId ? { l: launchId } : {}) }, config.secret, { expiresIn: launchId ? '1h' : '7d', issuer: 'ludo-club', audience: 'ludo-club-app' });
  async function authenticate(token) {
    let data;
    try { data = jwt.verify(token, config.secret, { algorithms: ['HS256'], issuer: 'ludo-club', audience: 'ludo-club-app' }); } catch { assert(false, 'Please log in again', 401); }
    const u = await User.findById(data.sub);
    assert(u?.isActive && data.v === u.tokenVersion, 'Please log in again', 401);
    assert(!platformMode || u.platformId, 'Platform session required', 403);
    if (u.platformId) {
      assert(data.l, 'Platform launch session required', 401);
      const launch = await PlatformLaunch.findOne({ launchId: data.l, platformId: u.platformId, revokedAt: null, sessionExpiresAt: { $gt: new Date() } });
      assert(launch, 'Platform launch session expired', 401);
    }
    return u;
  }
  const auth = async (req, res, next) => { try {
    req.user = await authenticate(req.headers.authorization?.replace(/^Bearer /, ''));
    assert(!platformMode || req.user.platformId, 'Platform session required', 403);
    if (!req.user.platformId) {
      req.wallet = await MoneyWallet.findOne({ userId: idOf(req.user) });
      if (!req.wallet) await mongoose.connection.transaction(async session => { req.wallet = await ensureWallet(req.user, session); });
    }
    next();
  } catch (e) { next(e); } };
  const admin = (req, res, next) => { try { assert(req.user.role === 'admin', 'Administrator access required', 403); next(); } catch (e) { next(e); } };
  const memberGame = async (req) => {
    assert(mongoose.isValidObjectId(req.params.id), 'Invalid game ID', 400);
    const game = await Game.findById(req.params.id).lean();
    assert(game && (game.members.includes(idOf(req.user)) || req.user.role === 'admin'), 'Game unavailable', 404); return game;
  };
  app.get('/health', (req, res) => res.status(mongoose.connection.readyState === 1 ? 200 : 503).json(platformMode
    ? { ok: mongoose.connection.readyState === 1, platform: true }
    : { ok: mongoose.connection.readyState === 1, currency: 'EGP', deposit: 'MANUAL_ADMIN_REVIEW', withdrawal: 'MANUAL_ADMIN_PAYOUT' }));
  app.get('/api/v1/game/health', (req, res) => res.json({ ok: true, gameId: 'ludo-club', apiVersion: '1' }));
  app.get('/api/v1/game/ready', async (req, res) => {
    const cfg = await gameConfig();
    const ready = mongoose.connection.readyState === 1 && cfg.gameEnabled !== false;
    res.status(ready ? 200 : 503).json({ ready, maintenance: cfg.gameEnabled === false, message: cfg.maintenanceMessage || '' });
  });
  app.get('/api/v1/game/integration-status', async (req, res) => {
    const cfg = await gameConfig();
    res.json({ platformMode, mock: platform.mock, sessionExchange: !!(platform.mock || platform.url),
      pointsBalance: !!(platform.mock || platform.url), paidMatches: !!matchPolicy && (cfg.matchTiers || []).some(n => n > 0),
      cosmeticBilling: !!platform.url, gameEnabled: cfg.gameEnabled !== false });
  });
  const adminConfigInput = z.object({ gameEnabled: z.boolean(), maintenanceMessage: z.string().max(200),
    enabledModes: z.array(z.enum(['classic', 'practice'])).min(1),
    matchTiers: z.array(z.number().int().nonnegative()).min(1),
    cosmeticAvailability: z.record(z.string(), z.boolean()), reason: reasonInput.shape.reason }).strict();
  app.get('/api/v1/platform/admin/config', async (req, res) => {
    assert(safeServiceKey(req.headers.authorization?.replace(/^Bearer /, '')), 'Platform administration key required', 403);
    res.json(await gameConfig());
  });
  app.put('/api/v1/platform/admin/config', async (req, res) => {
    assert(safeServiceKey(req.headers.authorization?.replace(/^Bearer /, '')), 'Platform administration key required', 403);
    const { reason, ...configUpdate } = adminConfigInput.parse(req.body);
    for (const points of configUpdate.matchTiers.filter(n => n > 0))
      assert(matchPolicy?.tiers.some(t => t.points === points), 'Approved match policy required for tier', 503);
    const setting = await AppSetting.findOneAndUpdate({ key: 'game_config' }, { $set: configUpdate }, { upsert: true, new: true });
    await Audit.create({ actor: 'platform-service', action: 'game_config_update', target: 'game_config', reason });
    res.json(setting);
  });
  app.get('/api/v1/platform/admin/finance', async (req, res) => {
    assert(safeServiceKey(req.headers.authorization?.replace(/^Bearer /, '')), 'Platform administration key required', 403);
    const states = ['RESERVING', 'RELEASING', 'COMMITTING', 'FUNDED', 'SETTLING', 'MANUAL_REVIEW'];
    const games = await Game.find({ 'platformFinance.state': { $in: states } })
      .select('status code members platformFinance createdAt updatedAt').sort({ updatedAt: 1 }).limit(100).lean();
    res.json(games.map(g => ({ id: String(g._id), status: g.status, code: g.code,
      finance: g.platformFinance, createdAt: g.createdAt, updatedAt: g.updatedAt })));
  });
  app.post('/api/v1/platform/admin/finance/:id/reconcile', async (req, res) => {
    assert(safeServiceKey(req.headers.authorization?.replace(/^Bearer /, '')), 'Platform administration key required', 403);
    const id = z.string().regex(/^[a-f0-9]{24}$/).parse(req.params.id);
    const game = await Game.findById(id);
    assert(game?.platformFinance, 'Platform match unavailable', 404);
    assert(game.platformFinance.state !== 'MANUAL_REVIEW', 'Manual review requires platform operator decision', 409);
    res.json(await service.serial(() => service.platformFinance.progress(id)));
  });
  app.post('/api/v1/platform/admin/matches/:id/cancel', async (req, res) => {
    assert(safeServiceKey(req.headers.authorization?.replace(/^Bearer /, '')), 'Platform administration key required', 403);
    const id = z.string().regex(/^[a-f0-9]{24}$/).parse(req.params.id);
    const { reason } = reasonInput.parse(req.body);
    const game = await Game.findById(id);
    assert(game?.platformFinance && ['waiting', 'active'].includes(game.status), 'Platform match unavailable', 404);
    res.json(await service.moderate('platform-service', id, 'cancel', null, reason));
  });
  const exchangePlatformSession = async (req, res) => {
    const { sessionToken } = z.object({ sessionToken: z.string().min(1).max(4096) }).strict().parse(req.body);
    const identity = await platform.verify(sessionToken);
    const platformId = identity.playerId;
    const verifiedName = String(identity.displayName || 'Club Player').slice(0, 30);
    const verifiedAvatar = ['🎲', '🦊', '🐼', '🐯', '🐸', '🦁', '👑', '💎', '🚀', '⚡️'].includes(identity.avatar) ? identity.avatar : '🎲';
    try {
      await PlatformLaunch.create({ launchId: identity.launchId, platformId,
        tenantId: identity.tenantId || 'default', gameId: identity.gameId,
        sessionExpiresAt: new Date(Date.now() + 3600000) });
    } catch (error) {
      if (error.code !== 11000) throw error;
      assert(false, 'Platform launch already used', 409);
    }
    let user = await User.findOne({ platformId });
    if (!user) {
      const suffix = hash(platformId).slice(0, 20);
      try {
        user = await User.create({
        platformId, username: `Player_${suffix}`, email: `platform_${suffix}@ludo.club.local`,
        password: await bcrypt.hash(randomBytes(32).toString('hex'), 10),
        coins: null, points: null,
        displayName: verifiedName,
        avatar: verifiedAvatar
        });
      } catch (error) {
        if (error.code !== 11000) throw error;
        user = await User.findOne({ platformId });
      }
    }
    assert(user?.isActive, 'Player access disabled', 403);
    user = await User.findOneAndUpdate({ platformId }, { $set: { displayName: verifiedName, avatar: verifiedAvatar } }, { new: true });
    res.json({ token: tokenFor(user, identity.launchId), expiresIn: 3600, user: publicUser(user) });
  };
  app.post('/api/v1/platform/session/exchange', authLimit, exchangePlatformSession);
  app.post('/api/auth/platform', authLimit, exchangePlatformSession);
  if (platformMode) app.use('/api/auth', (req, res, next) => {
    if (['/platform', '/admin-login', '/me', '/logout'].includes(req.path)) return next();
    res.status(404).json({ error: 'Use the host platform session' });
  });
  app.post('/api/auth/register', authLimit, async (req, res) => {
    const input = credentials.extend({ username }).parse(req.body); const password = await bcrypt.hash(input.password, 12); let user;
    await mongoose.connection.transaction(async session => {
      [user] = await User.create([{ ...input, password }], { session });
      await ensureWallet(user, session);
    }); res.status(201).json({ token: tokenFor(user), user: publicUser(user) });
  });
  app.post('/api/auth/login', authLimit, async (req, res) => {
    const input = credentials.parse(req.body); const user = await User.findOne({ email: input.email }).select('+password');
    const valid = await bcrypt.compare(input.password, user?.password || '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxhHn.hSoKUO9lfTlwy.FBLF6Z2');
    assert(user?.isActive && valid, 'Invalid email or password', 401);
    let wallet = await MoneyWallet.findOne({ userId: idOf(user) });
    if (!wallet) await mongoose.connection.transaction(async session => { wallet = await ensureWallet(user, session); });
    res.json({ token: tokenFor(user), user: publicUser(user, wallet) });
  });
  app.post('/api/auth/admin-login', authLimit, async (req, res) => {
    assert(!platformMode, 'Use the platform administration service', 404);
    const input = credentials.parse(req.body);
    const user = await User.findOne({ email: input.email }).select('+password');
    const valid = await bcrypt.compare(input.password, user?.password || '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxhHn.hSoKUO9lfTlwy.FBLF6Z2');
    assert(user?.isActive && valid && user.role === 'admin', 'Invalid administrator credentials', 401);
    let wallet = await MoneyWallet.findOne({ userId: idOf(user) });
    if (!wallet) await mongoose.connection.transaction(async session => { wallet = await ensureWallet(user, session); });
    res.json({ token: tokenFor(user), user: publicUser(user, wallet) });
  });
  app.post('/api/auth/guest', authLimit, async (req, res) => {
    const guestSuffix = randomBytes(4).toString('hex');
    const guestUser = {
      username: `Guest_${guestSuffix}`,
      email: `guest_${guestSuffix}@ludo.club.local`,
      password: await bcrypt.hash(randomBytes(32).toString('hex'), 10)
    };
    let user;
    const refreshToken = randomBytes(32).toString('hex');
    await mongoose.connection.transaction(async session => {
      [user] = await User.create([{ ...guestUser, refreshHash: hash(refreshToken), refreshExpires: new Date(Date.now() + 365 * 86400000) }], { session });
      await ensureWallet(user, session);
    });
    res.status(201).json({ token: tokenFor(user), refreshToken, user: publicUser(user) });
  });
  app.post('/api/auth/refresh', authLimit, async (req, res) => {
    const { refreshToken } = z.object({ refreshToken: z.string().regex(/^[a-f0-9]{64}$/) }).parse(req.body);
    const nextToken = randomBytes(32).toString('hex');
    const user = await User.findOneAndUpdate({ refreshHash: hash(refreshToken), refreshExpires: { $gt: new Date() }, isActive: true }, {
      $set: { refreshHash: hash(nextToken), refreshExpires: new Date(Date.now() + 365 * 86400000) },
    }, { new: true });
    assert(user, 'Session expired', 401);
    const wallet = await MoneyWallet.findOne({ userId: idOf(user) });
    res.json({ token: tokenFor(user), refreshToken: nextToken, user: publicUser(user, wallet) });
  });
  app.post('/api/auth/forgot-password', authLimit, async (req, res) => {
    const { email } = credentials.pick({ email: true }).parse(req.body);
    assert(config.mailKey, 'Password recovery email is not configured', 503);
    const user = await User.findOne({ email });
    if (user) {
      const token = randomBytes(32).toString('hex'); user.resetHash = hash(token); user.resetExpires = new Date(Date.now() + 30 * 60000); await user.save();
      const response = await fetch('https://api.resend.com/emails', { method: 'POST', headers: { Authorization: `Bearer ${config.mailKey}`, 'Content-Type': 'application/json' }, signal: AbortSignal.timeout(10000), body: JSON.stringify({ from: config.mailFrom, to: [email], subject: 'Reset your Ludo Club password', text: `Your reset code (valid for 30 minutes):\n${token}\nOpen Ludo Club, choose Reset password, and paste this code.` }) });
      assert(response.ok, 'Email delivery failed; please try again later', 503);
    } res.json({ message: 'If the account exists, a reset code has been sent.' });
  });
  app.post('/api/auth/reset-password', authLimit, async (req, res) => {
    const input = z.object({ token: z.string().regex(/^[a-f0-9]{64}$/), password: credentials.shape.password }).parse(req.body);
    const password = await bcrypt.hash(input.password, 12);
    const u = await User.findOneAndUpdate({ resetHash: hash(input.token), resetExpires: { $gt: new Date() } }, { $set: { password }, $unset: { resetHash: 1, resetExpires: 1, refreshHash: 1, refreshExpires: 1 }, $inc: { tokenVersion: 1 } });
    assert(u, 'Reset code is invalid or expired'); res.json({ message: 'Password updated. Please log in.' });
  });
  app.use('/api', auth);
  const requireGameMode = async mode => {
    if (!platformMode) return;
    const cfg = await gameConfig();
    assert(cfg.gameEnabled !== false, cfg.maintenanceMessage || 'Ludo is under maintenance', 503);
    assert((cfg.enabledModes || []).includes(mode), 'Game mode is disabled', 503);
  };
  app.get('/api/v1/game/me', async (req, res) => {
    assert(req.user.platformId, 'Platform session required', 403);
    res.json({ ...publicUser(req.user), ...(await platform.balance(req.user.platformId)) });
  });
  app.get('/api/v1/game/catalog-info', async (req, res) => {
    const cfg = await gameConfig();
    res.json({ gameId: 'ludo-club', name: 'Ludo Club', version: '1', enabled: cfg.gameEnabled !== false,
      capacities: [2, 4], multiplayer: true, practice: (cfg.enabledModes || []).includes('practice') });
  });
  app.get('/api/v1/game/modes', async (req, res) => {
    const cfg = await gameConfig();
    res.json({ modes: [
      { id: 'classic', available: cfg.gameEnabled !== false && (cfg.enabledModes || []).includes('classic'), capacities: [2, 4] },
      { id: 'practice', available: cfg.gameEnabled !== false && (cfg.enabledModes || []).includes('practice'), capacities: [2, 4], entryPoints: 0 },
      { id: 'magic', available: false, reason: 'Rules pending platform approval' },
      { id: 'fast', available: false, reason: 'Rules pending platform approval' }
    ], entryTiers: (cfg.matchTiers || [0]).map(points => ({ points,
      capacities: points === 0 ? [2, 4] : (matchPolicy?.tiers.filter(t => t.points === points).map(t => t.capacity) || []),
      available: points === 0 || !!matchPolicy?.tiers.some(t => t.points === points) })) });
  });
  app.post('/api/v1/game/launch/validate', (req, res) => res.json({ valid: !!req.user.platformId, gameId: 'ludo-club' }));
  app.post('/api/v1/game/session/end', async (req, res) => {
    assert(req.user.platformId, 'Platform session required', 403);
    const bearer = req.headers.authorization?.replace(/^Bearer /, '');
    const data = jwt.verify(bearer, config.secret, { algorithms: ['HS256'], issuer: 'ludo-club', audience: 'ludo-club-app' });
    await PlatformLaunch.updateOne({ launchId: data.l, platformId: req.user.platformId }, { revokedAt: new Date() });
    io.in(`user:${req.user._id}`).disconnectSockets(true);
    res.json({ ended: true });
  });
  const COSMETIC_CATALOG = [
    { id: 'dice_classic', category: 'dice', name: 'Classic Dice', rarity: 'Common', priceCoins: 0 },
    { id: 'dice_gold', category: 'dice', name: 'Gold Dice', rarity: 'Rare', priceCoins: 500 },
    { id: 'dice_diamond', category: 'dice', name: 'Diamond Dice', rarity: 'Epic', priceCoins: 1200 },
    { id: 'dice_neon', category: 'dice', name: 'Cyber Neon Dice', rarity: 'Rare', priceCoins: 800 },
    { id: 'dice_fire', category: 'dice', name: 'Flame Dice', rarity: 'Legendary', priceCoins: 1500 },
    { id: 'token_classic', category: 'token', name: 'Classic Tokens', rarity: 'Common', priceCoins: 0 },
    { id: 'token_metallic', category: 'token', name: 'Metallic Tokens', rarity: 'Rare', priceCoins: 500 },
    { id: 'token_crystal', category: 'token', name: 'Crystal Tokens', rarity: 'Epic', priceCoins: 1000 },
    { id: 'token_royal', category: 'token', name: 'Royal Crown Tokens', rarity: 'Legendary', priceCoins: 1500 },
    { id: 'token_neon', category: 'token', name: 'Glow Neon Tokens', rarity: 'Rare', priceCoins: 800 },
    { id: 'board_classic', category: 'board', name: 'Classic Board', rarity: 'Common', priceCoins: 0 },
    { id: 'board_royal', category: 'board', name: 'Royal Velvet Board', rarity: 'Rare', priceCoins: 800 },
    { id: 'board_midnight', category: 'board', name: 'Midnight Onyx Board', rarity: 'Epic', priceCoins: 1200 },
    { id: 'board_neon', category: 'board', name: 'Cyber Arcade Board', rarity: 'Epic', priceCoins: 1500 },
    { id: 'board_luxury', category: 'board', name: 'Gold Casino Board', rarity: 'Legendary', priceCoins: 2000 },
    { id: 'frame_bronze', category: 'frame', name: 'Bronze Ring', rarity: 'Common', priceCoins: 0 },
    { id: 'frame_silver', category: 'frame', name: 'Silver Crest', rarity: 'Rare', priceCoins: 500 },
    { id: 'frame_gold', category: 'frame', name: 'Golden Aura', rarity: 'Epic', priceCoins: 1000 },
    { id: 'frame_diamond', category: 'frame', name: 'Diamond Crown', rarity: 'Legendary', priceCoins: 2000 },
  ];

  app.get('/api/auth/me', async (req, res) => res.json({ ...publicUser(req.user, req.wallet),
    ...(req.user.platformId ? await platform.balance(req.user.platformId) : {}) }));
  app.patch('/api/auth/me', async (req, res) => {
    assert(!req.user.platformId, 'Player identity is managed by the platform', 403);
    const data = z.object({
      username: username.optional(),
      displayName: z.string().trim().max(30).optional(),
      avatar: z.enum(['🎲', '🦊', '🐼', '🐯', '🐸', '🦁', '👑', '💎', '🚀', '⚡️'])
    }).parse(req.body);
    if (data.username) req.user.username = data.username;
    if (data.displayName !== undefined) req.user.displayName = data.displayName;
    if (data.avatar) req.user.avatar = data.avatar;
    await req.user.save();
    res.json(publicUser(req.user, req.wallet));
  });

  app.get('/api/shop/catalog', async (req, res) => {
    const cfg = await gameConfig();
    res.json({ catalog: req.user.platformId
      ? COSMETIC_CATALOG.map(item => ({ ...item, pricePoints: platform.cosmeticPrice(item), priceCoins: undefined,
        available: cfg.cosmeticAvailability?.[item.id] !== false }))
      : COSMETIC_CATALOG });
  });
  async function finishCosmeticPurchase(purchase) {
    await User.updateOne({ _id: purchase.userId }, { $addToSet: { inventory: purchase.itemId } });
    await CosmeticPurchase.updateOne({ _id: purchase._id }, { status: 'COMMITTED', platformReference: purchase.reference });
  }
  app.post('/api/shop/buy', async (req, res) => {
    const { itemId, requestId } = z.object({ itemId: z.string(), requestId: z.uuid().optional() }).parse(req.body);
    const item = COSMETIC_CATALOG.find(i => i.id === itemId);
    assert(item, 'Item not found in cosmetic catalog', 404);
    if (req.user.platformId) {
      const cfg = await gameConfig();
      assert(cfg.cosmeticAvailability?.[itemId] !== false, 'Cosmetic unavailable', 503);
      const price = platform.cosmeticPrice(item);
      assert(price !== null, 'This cosmetic is not available for platform points', 503);
      assert(requestId, 'Purchase requestId required', 400);
      let purchase = await CosmeticPurchase.findOne({ requestId });
      if (purchase) {
        assert(purchase.userId === idOf(req.user) && purchase.itemId === itemId, 'Purchase reference belongs to another item', 409);
        if (purchase.status === 'COMMITTED') return res.json(publicUser(await User.findById(req.user._id)));
        assert(purchase.status !== 'DECLINED', 'Purchase was declined; start a new request', 402);
      } else {
        assert(!(req.user.inventory || []).includes(itemId), 'Item already owned', 409);
        assert(price === 0 || !platform.mock, 'Paid cosmetics require platform billing', 503);
        purchase = await CosmeticPurchase.create({ requestId, userId: idOf(req.user), itemId,
          points: price, reference: `ludo:cosmetic:${req.user.platformId}:${requestId}`, status: 'PENDING' });
      }
      if (purchase.points > 0) {
        try {
          await platform.purchase(req.user.platformId, itemId, purchase.points, purchase.reference);
        } catch (e) {
          if (e.status === 402) {
            await CosmeticPurchase.updateOne({ _id: purchase._id }, { status: 'DECLINED' });
            throw e;
          }
          let status;
          try { status = await platform.transactionStatus(purchase.reference); } catch { /* unresolved */ }
          if (['DECLINED', 'FAILED'].includes(status?.status)) {
            await CosmeticPurchase.updateOne({ _id: purchase._id }, { status: 'DECLINED' });
            assert(false, 'Platform declined purchase', 402);
          }
          if (status?.approved !== true && status?.status !== 'COMMITTED') {
            return res.status(202).json({ status: 'PENDING', requestId });
          }
        }
      }
      await finishCosmeticPurchase(purchase);
      return res.json(publicUser(await User.findById(req.user._id)));
    }
    const currentInventory = req.user.inventory || [];
    assert(!platformMode, 'Platform session required', 403);
    assert(!currentInventory.includes(itemId), 'Item already owned', 409);
    assert((req.user.coins ?? 1000) >= item.priceCoins, 'Insufficient cosmetic Coins', 400);
    req.user.coins = (req.user.coins ?? 1000) - item.priceCoins;
    req.user.inventory = [...currentInventory, itemId];
    await req.user.save();
    res.json(publicUser(req.user, req.wallet));
  });
  app.get('/api/shop/purchases/:requestId/status', async (req, res) => {
    assert(req.user.platformId, 'Platform session required', 403);
    const requestId = z.uuid().parse(req.params.requestId);
    const purchase = await CosmeticPurchase.findOne({ requestId, userId: idOf(req.user) });
    assert(purchase, 'Purchase not found', 404);
    if (purchase.status === 'PENDING') {
      let status;
      try { status = await platform.transactionStatus(purchase.reference); } catch { /* pending */ }
      if (status?.approved === true || status?.status === 'COMMITTED') await finishCosmeticPurchase(purchase);
      else if (['DECLINED', 'FAILED'].includes(status?.status)) await CosmeticPurchase.updateOne({ _id: purchase._id }, { status: 'DECLINED' });
    }
    const latest = await CosmeticPurchase.findById(purchase._id);
    res.json({ status: latest.status, requestId, itemId: latest.itemId });
  });

  app.post('/api/inventory/equip', async (req, res) => {
    const { category, itemId } = z.object({ category: z.enum(['dice', 'token', 'board', 'frame']), itemId: z.string() }).parse(req.body);
    const currentInventory = req.user.inventory || [];
    assert(COSMETIC_CATALOG.some(item => item.id === itemId && item.category === category), 'Cosmetic category mismatch', 400);
    assert(currentInventory.includes(itemId), 'Item not owned', 403);

    req.user.equipped = { ...(req.user.equipped || {}), [category]: itemId };
    req.user.markModified('equipped');
    await req.user.save();
    res.json(publicUser(req.user, req.wallet));
  });
  app.post('/api/auth/logout', async (req, res) => { await User.updateOne({ _id: req.user._id }, { $inc: { tokenVersion: 1 }, $unset: { refreshHash: 1, refreshExpires: 1 } }); if (req.user.platformId) await PlatformLaunch.updateMany({ platformId: req.user.platformId, revokedAt: null }, { revokedAt: new Date() }); io.in(`user:${req.user._id}`).disconnectSockets(true); res.json({ ok: true }); });
  if (!platformMode) playerFinanceRoutes(app, config);
  app.post('/api/rooms/create', async (req, res) => { await requireGameMode('classic'); const { capacity, stakeMinor } = roomInput.parse(req.body); await validateEntry(stakeMinor, capacity); res.status(201).json(await service.create(idOf(req.user), capacity, 'private', stakeMinor)); });
  app.post('/api/rooms/join', async (req, res) => { await requireGameMode('classic'); const code = codeInput.parse(req.body).code; if (req.user.platformId) { const game = await Game.findOne({ code }); if (game?.stakeMinor) await validateEntry(game.stakeMinor, game.capacity); } res.json(await service.join(idOf(req.user), code)); });
  app.get('/api/rooms/:code', async (req, res) => {
    const code = codeInput.parse(req.params).code; const g = await Game.findOne({ code }).lean();
    assert(g?.members.includes(idOf(req.user)), 'Room unavailable', 404); res.json(service.view(g));
  });
  app.post('/api/games/practice', async (req, res) => { await requireGameMode('practice'); const input = roomInput.parse(req.body); assert(input.stakeMinor === 0, 'Practice cannot charge points', 400); res.status(201).json(await service.create(idOf(req.user), input.capacity, 'practice')); });
  app.post('/api/matchmaking/queue', async (req, res) => { await requireGameMode('classic'); const { capacity, stakeMinor } = roomInput.parse(req.body); await validateEntry(stakeMinor, capacity); res.json(await service.queue(idOf(req.user), capacity, stakeMinor)); });
  app.delete('/api/matchmaking/queue', async (req, res) => res.json(await service.unqueue(idOf(req.user))));
  app.get('/api/matchmaking/status', async (req, res) => res.json(await service.queueStatus(idOf(req.user))));
  app.get('/api/games/history', async (req, res) => {
    const filter = { members: idOf(req.user) };
    if (['quick', 'private', 'practice'].includes(req.query.mode)) filter.mode = req.query.mode;
    res.json((await Game.find(filter).sort({ createdAt: -1 }).skip(page(req) * 25).limit(25).lean()).map(g => service.view(g)));
  });
  app.get('/api/games/:id', async (req, res) => res.json(service.view(await memberGame(req))));
  app.get('/api/games/:id/replay', async (req, res) => { const g = await memberGame(req); res.json({ initial: g.initial, events: await Event.find({ game: req.params.id }).sort({ revision: 1 }).lean() }); });
  app.get('/api/games/:id/chat', async (req, res) => { await memberGame(req); res.json((await Chat.find({ game: req.params.id }).sort({ createdAt: -1 }).limit(100).lean()).reverse()); });
  app.post('/api/games/:id/chat', chatLimit, async (req, res) => { await memberGame(req); res.status(201).json(await service.chat(req.user, req.params.id, messageInput.parse(req.body).message)); });
  app.post('/api/games/:id/start', async (req, res) => { await memberGame(req); res.json(await service.start(idOf(req.user), req.params.id)); });
  app.post('/api/games/:id/leave', async (req, res) => { await memberGame(req); res.json(await service.leave(idOf(req.user), req.params.id)); });
  app.post('/api/games/:id/action', async (req, res) => { await memberGame(req); const { revision, ...action } = actionInput.parse(req.body); res.json(await service.action(idOf(req.user), req.params.id, action, revision)); });
  app.post('/api/games/:id/disputes', async (req, res) => { await memberGame(req); const { message } = messageInput.parse(req.body); res.status(201).json(await Dispute.create({ userId: idOf(req.user), game: req.params.id, message })); });
  app.get('/api/disputes', async (req, res) => res.json(await Dispute.find({ userId: idOf(req.user) }).sort({ createdAt: -1 }).limit(100).lean()));
  app.get('/api/stats/user', (req, res) => res.json({ ...publicUser(req.user, req.wallet), winRate: req.user.games ? req.user.wins / req.user.games : 0 }));
  app.get('/api/stats/leaderboard', async (req, res) => {
    const period = z.enum(['all', 'week', 'month']).parse(req.query.period || 'all');
    const playerFilter = { isActive: true, ...(platformMode ? { platformId: { $type: 'string' } } : {}) };
    if (period === 'all') return res.json(await User.find({ ...playerFilter, games: { $gt: 0 } })
      .select('username displayName avatar wins games rating').sort({ wins: -1, rating: -1, username: 1 })
      .skip(page(req) * 100).limit(100).lean());
    const since = new Date(Date.now() - (period === 'week' ? 7 : 30) * 86400000);
    const rows = await Game.aggregate([
      { $match: { status: 'completed', mode: { $ne: 'practice' }, endedAt: { $gte: since } } },
      { $group: { _id: '$state.winner', wins: { $sum: 1 } } },
      { $addFields: { playerObjectId: { $convert: { input: '$_id', to: 'objectId', onError: null, onNull: null } } } },
      { $lookup: { from: 'users', localField: 'playerObjectId', foreignField: '_id', as: 'player' } },
      { $unwind: '$player' },
      { $match: { 'player.isActive': true, ...(platformMode ? { 'player.platformId': { $type: 'string' } } : {}) } },
      { $sort: { wins: -1, _id: 1 } }, { $skip: page(req) * 100 }, { $limit: 100 },
      { $project: { _id: 1, wins: 1, username: '$player.username', displayName: '$player.displayName', avatar: '$player.avatar', rating: '$player.rating' } }
    ]);
    res.json(rows);
  });
  app.use('/api/admin', admin);
  if (!platformMode) adminFinanceRoutes(app);
  if (!platformMode) {
  app.get('/api/admin/settings/payment', async (req, res) => {
    const setting = await paymentSettings(config);
    res.json({ vodafoneCashReceivingNumber: setting.vodafoneCashReceivingNumber });
  });
  app.put('/api/admin/settings/payment', async (req, res) => {
    const { vodafoneCashReceivingNumber: number, reason } = z.object({ vodafoneCashReceivingNumber: z.string().regex(phonePattern), reason: reasonInput.shape.reason }).strict().parse(req.body);
    let setting;
    await mongoose.connection.transaction(async session => {
      setting = await AppSetting.findOne({ key: 'payment' }).session(session);
      if (!setting) setting = (await AppSetting.create([{ key: 'payment', vodafoneCashReceivingNumber: config.vodafoneReceivingNumber || '' }], { session }))[0];
      const oldValue = setting.vodafoneCashReceivingNumber;
      setting.vodafoneCashReceivingNumber = number;
      await setting.save({ session });
      await Audit.create([{ actor: idOf(req.user), action: 'payment_setting_update', target: 'payment.vodafoneCashReceivingNumber', oldValue, newValue: number, reason }], { session });
    });
    res.json({ vodafoneCashReceivingNumber: setting.vodafoneCashReceivingNumber });
  });
  }
  app.get('/api/admin/admins', async (req, res) => res.json(await User.find({ role: 'admin' }).select('username email isActive createdAt updatedAt').sort({ createdAt: 1 }).lean()));
  app.post('/api/admin/admins', async (req, res) => {
    const input = z.object({ email: adminEmail, reason: reasonInput.shape.reason }).strict().parse(req.body);
    const password = randomBytes(24).toString('base64url');
    let user;
    await mongoose.connection.transaction(async session => {
      [user] = await User.create([{ email: input.email, username: `Admin_${randomBytes(6).toString('hex')}`, password: await bcrypt.hash(password, 12), role: 'admin' }], { session });
      await ensureWallet(user, session);
      await Audit.create([{ actor: idOf(req.user), action: 'admin_create', target: idOf(user), reason: input.reason }], { session });
    });
    res.status(201).json({ id: idOf(user), email: user.email, oneTimePassword: password });
  });
  app.put('/api/admin/admins/:id/active', async (req, res) => {
    assert(mongoose.isValidObjectId(req.params.id), 'Invalid administrator ID', 400);
    const { active, reason } = z.object({ active: z.boolean(), reason: reasonInput.shape.reason }).strict().parse(req.body);
    assert(active || req.params.id !== idOf(req.user), 'Cannot disable your own administrator account', 409);
    let user;
    await mongoose.connection.transaction(async session => {
      // All Admin-state changes write this document so concurrent disables conflict and retry.
      await AppSetting.updateOne({ key: 'payment' }, { $inc: { adminMutationVersion: 1 } }, { session, upsert: true });
      user = await User.findOne({ _id: req.params.id, role: 'admin' }).session(session);
      assert(user, 'Administrator not found', 404);
      if (!active && user.isActive) assert(await User.countDocuments({ role: 'admin', isActive: true }).session(session) > 1, 'Cannot disable the last active administrator', 409);
      if (user.isActive === active) return;
      user.isActive = active; user.tokenVersion++; user.refreshHash = undefined; user.refreshExpires = undefined;
      await user.save({ session });
      await Audit.create([{ actor: idOf(req.user), action: active ? 'admin_enable' : 'admin_disable', target: idOf(user), reason }], { session });
    });
    if (!active) io.in(`user:${req.params.id}`).disconnectSockets(true);
    res.json({ id: idOf(user), isActive: user.isActive });
  });
  app.put('/api/admin/admins/:id/reset-password', async (req, res) => {
    assert(mongoose.isValidObjectId(req.params.id), 'Invalid administrator ID', 400);
    const { reason } = reasonInput.strict().parse(req.body);
    const password = randomBytes(24).toString('base64url');
    const digest = await bcrypt.hash(password, 12);
    await mongoose.connection.transaction(async session => {
      const user = await User.findOneAndUpdate({ _id: req.params.id, role: 'admin' }, { $set: { password: digest }, $unset: { refreshHash: 1, refreshExpires: 1 }, $inc: { tokenVersion: 1 } }, { session });
      assert(user, 'Administrator not found', 404);
      await Audit.create([{ actor: idOf(req.user), action: 'admin_password_reset', target: req.params.id, reason }], { session });
    });
    io.in(`user:${req.params.id}`).disconnectSockets(true);
    res.json({ oneTimePassword: password });
  });
  app.put('/api/admin/admins/me/password', async (req, res) => {
    const { currentPassword, newPassword } = z.object({ currentPassword: adminPassword, newPassword: adminPassword }).strict().parse(req.body);
    const user = await User.findById(req.user._id).select('+password');
    assert(await bcrypt.compare(currentPassword, user.password), 'Current password is incorrect', 401);
    user.password = await bcrypt.hash(newPassword, 12); user.tokenVersion++;
    await mongoose.connection.transaction(async session => {
      await user.save({ session });
      await Audit.create([{ actor: idOf(req.user), action: 'admin_password_change', target: idOf(req.user), reason: 'Administrator changed own password' }], { session });
    });
    io.in(`user:${idOf(req.user)}`).disconnectSockets(true);
    res.json({ ok: true, signInAgain: true });
  });
  app.get('/api/admin/analytics', async (req, res) => res.json({ users: await User.countDocuments(), activeGames: await Game.countDocuments({ status: 'active' }), completedGames: await Game.countDocuments({ status: 'completed' }), queued: await Queue.countDocuments(), pendingDeposits: await DepositRequest.countDocuments({ status: 'PENDING' }), pendingWithdrawals: await WithdrawalRequest.countDocuments({ status: 'PENDING' }), disputes: await Dispute.countDocuments({ status: 'open' }), modes: await Game.aggregate([{ $group: { _id: '$mode', games: { $sum: 1 } } }]), dailyGames: await Game.aggregate([{ $group: { _id: { $dateToString: { format: '%Y-%m-%d', date: '$createdAt' } }, games: { $sum: 1 } } }, { $sort: { _id: -1 } }, { $limit: 30 }]) }));
  app.get('/api/admin/games', async (req, res) => res.json((await Game.find().sort({ createdAt: -1 }).skip(page(req) * 50).limit(50).lean()).map(g => service.view(g))));
  app.get('/api/admin/users', async (req, res) => res.json(await User.find().select('-resetExpires -tokenVersion').sort({ createdAt: -1 }).skip(page(req) * 50).limit(50).lean()));
  app.get('/api/admin/audit', async (req, res) => res.json(await Audit.find().sort({ createdAt: -1 }).skip(page(req) * 50).limit(50).lean()));
  app.get('/api/admin/disputes', async (req, res) => res.json(await Dispute.find().sort({ createdAt: -1 }).skip(page(req) * 50).limit(50).lean()));
  app.put('/api/admin/disputes/:id', async (req, res) => {
    const { reason } = reasonInput.parse(req.body); let d;
    await mongoose.connection.transaction(async session => {
      d = await Dispute.findOneAndUpdate({ _id: req.params.id, status: 'open' }, { status: 'resolved', resolution: reason }, { new: true, session }); assert(d, 'Open dispute not found', 404);
      await Audit.create([{ actor: idOf(req.user), action: 'resolve', target: req.params.id, reason }], { session });
    }); res.json(d);
  });
  app.put('/api/admin/users/:id/ban', async (req, res) => {
    const { banned, reason } = reasonInput.extend({ banned: z.boolean() }).parse(req.body);
    assert(req.params.id !== idOf(req.user), 'Cannot ban yourself');
    await mongoose.connection.transaction(async session => {
      const u = await User.findById(req.params.id).session(session); assert(u, 'User not found', 404);
      assert(u.role !== 'admin', 'Use Admin Management for administrator accounts', 409);
      u.isActive = !banned; u.tokenVersion++; u.refreshHash = undefined; u.refreshExpires = undefined; await u.save({ session });
      if (banned) {
        const queued = await Queue.findOne({ userId: req.params.id }).session(session);
        if (queued?.stakeRef) {
          const stake = await MoneyStake.findOne({ reference: queued.stakeRef, state: 'RESERVED' }).session(session);
          if (stake) await releaseStake(stake, session);
        }
        await Queue.deleteOne({ userId: req.params.id }, { session });
        if (u.activeGame === 'queue') await User.updateOne({ _id: u._id }, { activeGame: null }, { session });
      }
      await Audit.create([{ actor: idOf(req.user), action: banned ? 'ban' : 'unban', target: req.params.id, reason }], { session });
    }); io.in(`user:${req.params.id}`).disconnectSockets(true); res.json({ ok: true });
  });
  for (const action of ['cancel', 'result']) app.put(`/api/admin/games/:id/${action}`, async (req, res) => {
    const { reason, winner } = reasonInput.extend({ winner: z.string().optional() }).parse(req.body);
    res.json(await service.moderate(idOf(req.user), req.params.id, action, winner, reason));
  });
  app.use((req, res) => res.status(404).json({ error: 'Endpoint not found' }));
  app.use((e, req, res, next) => {
    const status = e instanceof z.ZodError || e.name === 'CastError' ? 400 : e.code === 11000 ? 409 : e.status || 500;
    if (status === 500) console.error('Request failed:', e.message);
    res.status(status).json({ error: e instanceof z.ZodError ? e.issues.map(i => `${i.path.join('.')}: ${i.message}`).join('; ') : e.code === 11000 ? 'Already exists or request already processed' : status === 500 ? 'Unexpected server error' : e.message });
  });
  io.use(async (socket, next) => { try { socket.data.user = await authenticate(socket.handshake.auth.token); next(); } catch { next(new Error('Unauthorized')); } });
  io.on('connection', socket => {
    socket.join(`user:${socket.data.user._id}`);
    let count = 0; let windowStart = Date.now();
    const on = (event, handler) => socket.on(event, async (raw, ack) => {
      try {
        if (Date.now() - windowStart > 10000) { count = 0; windowStart = Date.now(); }
        assert(++count <= 20, 'Too many events', 429);
        const user = await authenticate(socket.handshake.auth.token); const data = raw || {};
        const result = await handler(user, data);
        if (typeof ack === 'function') ack({ ok: true, data: result });
      } catch (e) { if (typeof ack === 'function') ack({ ok: false, error: e.status ? e.message : 'Invalid request' }); }
    });
    on('sync', async u => { const latest = await User.findById(u._id); return latest.activeGame && latest.activeGame !== 'queue' ? service.publish(latest.activeGame) : service.queueStatus(idOf(u)); });
    on('join_queue', async (u, d) => { await requireGameMode('classic'); const input = roomInput.parse(d); await validateEntry(input.stakeMinor, input.capacity); return service.queue(idOf(u), input.capacity, input.stakeMinor); });
    on('leave_queue', u => service.unqueue(idOf(u)));
    on('create_room', async (u, d) => { await requireGameMode('classic'); const input = roomInput.parse(d); await validateEntry(input.stakeMinor, input.capacity); return service.create(idOf(u), input.capacity, 'private', input.stakeMinor); });
    on('join_room', async (u, d) => { await requireGameMode('classic'); const code = codeInput.parse(d).code; if (u.platformId) { const game = await Game.findOne({ code }); if (game?.stakeMinor) await validateEntry(game.stakeMinor, game.capacity); } return service.join(idOf(u), code); });
    const gameId = d => z.string().regex(/^[a-f0-9]{24}$/).parse(d.gameId);
    on('start_game', (u, d) => service.start(idOf(u), gameId(d)));
    on('leave_room', (u, d) => service.leave(idOf(u), gameId(d)));
    for (const [event, type] of [['roll_dice', 'roll'], ['make_move', 'move'], ['forfeit_game', 'forfeit']]) on(event, (u, d) => { const { gameId: ignored, ...payload } = d; const { revision, ...action } = actionInput.parse({ ...payload, type }); return service.action(idOf(u), gameId(d), action, revision); });
    on('send_chat', (u, d) => service.chat(u, gameId(d), messageInput.parse(d).message));
  });
  return { app, http, io, service };
}
