import mongoose from 'mongoose';
import { z } from 'zod';
import { rateLimit } from 'express-rate-limit';
import { DepositRequest, WithdrawalRequest, MoneyTransaction, MoneyWallet, Game, Audit, User } from './models.js';
import { assert } from './engine.js';
import { ensureWallet, changeWallet, MAX_MINOR } from './wallet.js';
import { paymentSettings } from './settings.js';

const amountMinor = z.number().int().min(1).max(MAX_MINOR);
const phone = z.string().regex(/^01[0125][0-9]{8}$/, 'Enter an Egyptian mobile number');
const requestId = z.uuid();
const reason = z.string().trim().min(5).max(500);
const id = value => { assert(mongoose.isValidObjectId(value), 'Invalid request ID', 400); return value; };
const sameRequest = (found, userId, input) => found && found.userId === userId && found.amountMinor === input.amountMinor && found.requestId === input.requestId;
const page = req => Math.max(0, Math.min(10000, Number(req.query.page) || 0));

export function playerFinanceRoutes(app, config) {
  const financialRequestLimit = rateLimit({ windowMs: 15 * 60000, limit: config.test ? 1000 : 30, standardHeaders: 'draft-8', legacyHeaders: false });
  app.get('/api/wallet/balance', (req, res) => res.json({ availableMinor: req.wallet.availableMinor, reservedMinor: req.wallet.reservedMinor, currency: 'EGP' }));
  app.get('/api/wallet/transactions', async (req, res) => res.json(await MoneyTransaction.find({ userId: String(req.user._id) }).sort({ createdAt: -1 }).limit(100).lean()));
  app.get('/api/wallet/config', async (req, res) => { const phone = (await paymentSettings(config)).vodafoneCashReceivingNumber; res.json({ currency: 'EGP', depositMethod: 'VODAFONE_CASH_MANUAL', receivingPhone: phone || null, depositAvailable: !!phone, localDemo: phone.startsWith('LOCAL_DEMO_'), withdrawalMethod: 'VODAFONE_CASH_MANUAL' }); });
  app.get('/api/wallet/deposits', async (req, res) => res.json(await DepositRequest.find({ userId: String(req.user._id) }).sort({ createdAt: -1 }).limit(100).lean()));
  app.post('/api/wallet/deposits', financialRequestLimit, async (req, res) => {
    const receivingPhone = (await paymentSettings(config)).vodafoneCashReceivingNumber;
    assert(receivingPhone, 'Vodafone Cash receiving number is not configured', 503);
    const input = z.object({ amountMinor, requestId, senderPhone: phone, transferReference: z.string().trim().min(4).max(100).regex(/^[A-Za-z0-9._/-]+$/).transform(value => value.toUpperCase()), note: z.string().trim().max(500).optional().default('') }).strict().parse(req.body);
    const userId = String(req.user._id);
    let found = await DepositRequest.findOne({ requestId: input.requestId });
    if (found) { assert(sameRequest(found, userId, input) && found.transferReference === input.transferReference && found.senderPhone === input.senderPhone, 'Request ID already used', 409); return res.json(found); }
    try { found = await DepositRequest.create({ ...input, userId, receivingPhone, currency: 'EGP' }); }
    catch (error) { if (error.code !== 11000) throw error; found = await DepositRequest.findOne({ requestId: input.requestId }); assert(sameRequest(found, userId, input) && found.transferReference === input.transferReference, 'Duplicate request or transfer reference', 409); }
    res.status(found.status === 'PENDING' ? 201 : 200).json(found);
  });
  app.get('/api/wallet/withdrawals', async (req, res) => res.json(await WithdrawalRequest.find({ userId: String(req.user._id) }).sort({ createdAt: -1 }).limit(100).lean()));
  app.post('/api/wallet/withdrawals', financialRequestLimit, async (req, res) => {
    const input = z.object({ amountMinor, requestId, phone }).strict().parse(req.body);
    const userId = String(req.user._id);
    let found = await WithdrawalRequest.findOne({ requestId: input.requestId });
    if (found) { assert(sameRequest(found, userId, input) && found.phone === input.phone, 'Request ID already used', 409); return res.json(found); }
    try {
      await mongoose.connection.transaction(async session => {
        found = (await WithdrawalRequest.create([{ ...input, userId, currency: 'EGP' }], { session }))[0];
        await changeWallet(userId, -input.amountMinor, input.amountMinor, 'WITHDRAWAL_RESERVE', `withdrawal:reserve:${found._id}`, session, { amountMinor: input.amountMinor, withdrawalRequestId: String(found._id) });
      });
    } catch (error) {
      if (error.code !== 11000) throw error;
      found = await WithdrawalRequest.findOne({ requestId: input.requestId });
      assert(sameRequest(found, userId, input) && found.phone === input.phone, 'Request ID already used', 409);
    }
    res.status(found.status === 'PENDING' ? 201 : 200).json(found);
  });
  // Old simulated endpoints cannot mint or destroy EGP.
  for (const path of ['/api/wallet/deposit', '/api/wallet/withdraw', '/api/wallet/claim']) app.post(path, (req, res) => res.status(410).json({ error: 'Use the reviewed Vodafone Cash request workflow' }));
}

export function adminFinanceRoutes(app) {
  app.get('/api/admin/deposits', async (req, res) => res.json(await DepositRequest.find().sort({ createdAt: -1 }).skip(page(req) * 50).limit(50).lean()));
  app.get('/api/admin/withdrawals', async (req, res) => res.json(await WithdrawalRequest.find().sort({ createdAt: -1 }).skip(page(req) * 50).limit(50).lean()));
  app.get('/api/admin/transactions', async (req, res) => res.json(await MoneyTransaction.find().sort({ createdAt: -1 }).skip(page(req) * 50).limit(50).lean()));
  app.get('/api/admin/wallets/:userId', async (req, res) => {
    const userId = id(req.params.userId);
    const wallet = await MoneyWallet.findOne({ userId }).lean(); assert(wallet, 'Wallet not found', 404);
    res.json({ wallet, transactions: await MoneyTransaction.find({ userId }).sort({ createdAt: -1 }).limit(25).lean(), matches: await Game.find({ members: userId }).select('status mode stakeMinor prizePoolMinor fundingState settled createdAt endedAt state.winner').sort({ createdAt: -1 }).limit(25).lean() });
  });
  app.put('/api/admin/deposits/:id/approve', async (req, res) => {
    const depositId = id(req.params.id); const { reason: why } = z.object({ reason }).strict().parse(req.body);
    let found;
    await mongoose.connection.transaction(async session => {
      found = await DepositRequest.findOneAndUpdate({ _id: depositId, status: 'PENDING' }, { $set: { status: 'APPROVED', reviewedBy: String(req.user._id), reviewReason: why } }, { new: true, session });
      if (!found) { found = await DepositRequest.findById(depositId).session(session); assert(found?.status === 'APPROVED', 'Deposit is not pending', 409); return; }
      await ensureWallet(found.userId, session);
      await changeWallet(found.userId, found.amountMinor, 0, 'DEPOSIT', `deposit:${depositId}`, session, { amountMinor: found.amountMinor, depositRequestId: depositId, actor: String(req.user._id), reason: why });
      await Audit.create([{ actor: String(req.user._id), action: 'deposit_approve', target: found.userId, amountMinor: found.amountMinor, reference: depositId, reason: why }], { session });
    });
    res.json(found);
  });
  app.put('/api/admin/deposits/:id/reject', async (req, res) => {
    const depositId = id(req.params.id); const { reason: why } = z.object({ reason }).strict().parse(req.body);
    let found;
    await mongoose.connection.transaction(async session => {
      found = await DepositRequest.findOneAndUpdate({ _id: depositId, status: 'PENDING' }, { $set: { status: 'REJECTED', reviewedBy: String(req.user._id), reviewReason: why } }, { new: true, session });
      if (!found) { found = await DepositRequest.findById(depositId).session(session); assert(found?.status === 'REJECTED', 'Deposit is not pending', 409); return; }
      await Audit.create([{ actor: String(req.user._id), action: 'deposit_reject', target: found.userId, amountMinor: found.amountMinor, reference: depositId, reason: why }], { session });
    });
    res.json(found);
  });
  for (const [action, status, type] of [['paid', 'PAID', 'WITHDRAWAL_PAID'], ['reject', 'REJECTED', 'WITHDRAWAL_RELEASE']]) app.put(`/api/admin/withdrawals/:id/${action}`, async (req, res) => {
    const withdrawalId = id(req.params.id);
    const input = z.object(action === 'paid' ? { reason, payoutReference: z.string().trim().min(4).max(100).regex(/^[A-Za-z0-9._/-]+$/).transform(value => value.toUpperCase()) } : { reason }).strict().parse(req.body);
    const why = input.reason;
    let found;
    await mongoose.connection.transaction(async session => {
      found = await WithdrawalRequest.findOneAndUpdate({ _id: withdrawalId, status: 'PENDING' }, { $set: { status, reviewedBy: String(req.user._id), reviewReason: why, ...(action === 'paid' ? { payoutReference: input.payoutReference } : {}) } }, { new: true, session });
      if (!found) { found = await WithdrawalRequest.findById(withdrawalId).session(session); assert(found?.status === status && (action !== 'paid' || found.payoutReference === input.payoutReference), 'Withdrawal is not pending', 409); return; }
      await changeWallet(found.userId, action === 'reject' ? found.amountMinor : 0, -found.amountMinor, type, `withdrawal:${action}:${withdrawalId}`, session, { amountMinor: found.amountMinor, withdrawalRequestId: withdrawalId, actor: String(req.user._id), reason: why });
      await Audit.create([{ actor: String(req.user._id), action: `withdrawal_${action}`, target: found.userId, amountMinor: found.amountMinor, reference: action === 'paid' ? input.payoutReference : withdrawalId, reason: why }], { session });
    });
    res.json(found);
  });
  app.put('/api/admin/users/:id/balance', async (req, res) => {
    const userId = id(req.params.id);
    const input = z.object({ amountMinor: z.number().int().min(-MAX_MINOR).max(MAX_MINOR).refine(n => n !== 0), reason, requestId }).strict().parse(req.body);
    const reference = `admin:${input.requestId}`;
    let existing = await MoneyTransaction.findOne({ reference });
    if (existing) { assert(existing.userId === userId && existing.availableDeltaMinor === input.amountMinor, 'Adjustment reference already used', 409); return res.json({ ok: true, reference }); }
    try {
      await mongoose.connection.transaction(async session => {
        const user = await User.findById(userId).session(session); assert(user, 'Player not found', 404);
        await ensureWallet(userId, session);
        await changeWallet(userId, input.amountMinor, 0, 'ADMIN_ADJUSTMENT', reference, session, { amountMinor: Math.abs(input.amountMinor), actor: String(req.user._id), reason: input.reason });
        await Audit.create([{ actor: String(req.user._id), action: 'wallet_adjustment', target: userId, amountMinor: input.amountMinor, reference, reason: input.reason }], { session });
      });
    } catch (error) { if (error.code !== 11000) throw error; existing = await MoneyTransaction.findOne({ reference }); assert(existing?.userId === userId && existing.availableDeltaMinor === input.amountMinor, 'Adjustment reference already used', 409); }
    res.json({ ok: true, reference });
  });
}
