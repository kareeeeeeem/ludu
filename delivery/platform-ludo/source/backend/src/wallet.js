import { MoneyWallet, MoneyStake, MoneyTransaction } from './models.js';
import { assert } from './engine.js';

// Legacy points are never silently converted to EGP. New monetary wallets start at zero.
export const MAX_MINOR = 1_000_000_000;
const MAX_BALANCE_MINOR = 1_000_000_000_000;
export function validMinor(value, { zero = false } = {}) {
  assert(Number.isSafeInteger(value) && value >= (zero ? 0 : 1) && value <= MAX_MINOR, 'Invalid EGP minor-unit amount', 400);
  return value;
}
export async function ensureWallet(user, session) {
  const userId = String(user._id || user);
  return MoneyWallet.findOneAndUpdate({ userId }, { $setOnInsert: { userId, availableMinor: 0, reservedMinor: 0, currency: 'EGP' } }, { upsert: true, new: true, session });
}
export async function changeWallet(userId, availableDeltaMinor, reservedDeltaMinor, type, reference, session, details = {}) {
  assert(Number.isSafeInteger(availableDeltaMinor) && Number.isSafeInteger(reservedDeltaMinor), 'Invalid wallet delta');
  assert(Math.abs(availableDeltaMinor) <= MAX_BALANCE_MINOR && Math.abs(reservedDeltaMinor) <= MAX_BALANCE_MINOR, 'Invalid wallet delta');
  const conditions = { userId };
  if (availableDeltaMinor < 0) conditions.availableMinor = { $gte: -availableDeltaMinor };
  else if (availableDeltaMinor > 0) conditions.availableMinor = { $lte: MAX_BALANCE_MINOR - availableDeltaMinor };
  if (reservedDeltaMinor < 0) conditions.reservedMinor = { $gte: -reservedDeltaMinor };
  else if (reservedDeltaMinor > 0) conditions.reservedMinor = { $lte: MAX_BALANCE_MINOR - reservedDeltaMinor };
  const wallet = await MoneyWallet.findOneAndUpdate(conditions, { $inc: { availableMinor: availableDeltaMinor, reservedMinor: reservedDeltaMinor } }, { new: true, session });
  assert(wallet, 'Insufficient balance or wallet limit exceeded', 402);
  await MoneyTransaction.create([{
    userId, amountMinor: details.amountMinor ?? Math.max(Math.abs(availableDeltaMinor), Math.abs(reservedDeltaMinor)),
    availableDeltaMinor, reservedDeltaMinor, availableAfterMinor: wallet.availableMinor, reservedAfterMinor: wallet.reservedMinor,
    type, reference, matchId: details.matchId, depositRequestId: details.depositRequestId,
    withdrawalRequestId: details.withdrawalRequestId, actor: details.actor, reason: details.reason,
  }], { session });
  return wallet;
}
export async function reserveStake(userId, amountMinor, reference, session, { gameId = null, queueId = null } = {}) {
  validMinor(amountMinor);
  const wallet = await changeWallet(userId, -amountMinor, amountMinor, 'STAKE_RESERVE', `reserve:${reference}`, session, { amountMinor, matchId: gameId });
  const [stake] = await MoneyStake.create([{ userId, amountMinor, reference, gameId, queueId, state: 'RESERVED' }], { session });
  return { wallet, stake };
}
export async function releaseStake(stake, session) {
  assert(stake.state === 'RESERVED', 'Stake is not reserved', 409);
  const wallet = await changeWallet(stake.userId, stake.amountMinor, -stake.amountMinor, 'STAKE_RELEASE', `release:${stake.reference}`, session, { amountMinor: stake.amountMinor, matchId: stake.gameId });
  stake.state = 'RELEASED'; await stake.save({ session });
  return wallet;
}
export async function captureStake(stake, session) {
  assert(stake.state === 'RESERVED', 'Stake is not reserved', 409);
  await changeWallet(stake.userId, 0, -stake.amountMinor, 'STAKE_CAPTURE', `capture:${stake.reference}`, session, { amountMinor: stake.amountMinor, matchId: stake.gameId });
  stake.state = 'CAPTURED'; await stake.save({ session });
}
export async function refundStake(stake, session) {
  assert(stake.state === 'CAPTURED', 'Stake was not captured', 409);
  await changeWallet(stake.userId, stake.amountMinor, 0, 'REFUND', `refund:${stake.reference}`, session, { amountMinor: stake.amountMinor, matchId: stake.gameId });
  stake.state = 'REFUNDED'; await stake.save({ session });
}
