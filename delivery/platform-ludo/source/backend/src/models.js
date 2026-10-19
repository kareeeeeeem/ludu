import mongoose from 'mongoose';
const { Schema } = mongoose;
const make = (name, definition, options = {}) => mongoose.model(name, new Schema(definition, { timestamps: true, ...options }));
export const User = make('User', {
  platformId: { type: String, unique: true, sparse: true, immutable: true },
  username: { type: String, unique: true, required: true }, email: { type: String, unique: true, required: true },
  password: { type: String, required: true, select: false }, avatar: { type: String, default: '🎲' },
  displayName: { type: String, default: '' },
  coins: { type: Number, default: function () { return this.platformId ? undefined : 1000; }, min: 0 },
  inventory: { type: [String], default: ['dice_classic', 'token_classic', 'board_classic', 'frame_bronze', 'emote_thumbsup'] },
  equipped: {
    dice: { type: String, default: 'dice_classic' },
    token: { type: String, default: 'token_classic' },
    board: { type: String, default: 'board_classic' },
    frame: { type: String, default: 'frame_bronze' }
  },
  role: { type: String, enum: ['user', 'admin'], default: 'user' }, isActive: { type: Boolean, default: true },
  tokenVersion: { type: Number, default: 0 }, resetHash: { type: String, select: false }, resetExpires: Date,
  refreshHash: { type: String, select: false }, refreshExpires: Date,
  points: { type: Number, default: function () { return this.platformId ? undefined : 100; } }, lastClaim: Date, activeGame: { type: String, default: null },
  wins: { type: Number, default: 0 }, losses: { type: Number, default: 0 }, games: { type: Number, default: 0 },
  streak: { type: Number, default: 0 }, bestStreak: { type: Number, default: 0 }, rating: { type: Number, default: 1000 },
  totalDeposited: { type: Number, default: 0 }, totalWithdrawn: { type: Number, default: 0 },
  totalWon: { type: Number, default: 0 }, totalLost: { type: Number, default: 0 },
});
export const PlatformLaunch = make('PlatformLaunch', {
  launchId: { type: String, required: true, unique: true },
  platformId: { type: String, required: true, index: true },
  tenantId: { type: String, default: 'default' },
  gameId: { type: String, required: true },
  sessionExpiresAt: { type: Date, required: true },
  revokedAt: Date,
});
PlatformLaunch.schema.index({ sessionExpiresAt: 1 }, { expireAfterSeconds: 86400 });
export const CosmeticPurchase = make('CosmeticPurchase', {
  requestId: { type: String, required: true, unique: true },
  userId: { type: String, required: true, index: true },
  itemId: { type: String, required: true },
  points: { type: Number, required: true, min: 0 },
  reference: { type: String, required: true, unique: true },
  status: { type: String, enum: ['PENDING', 'COMMITTED', 'DECLINED'], required: true },
  platformReference: String,
});
CosmeticPurchase.schema.index({ userId: 1, itemId: 1 }, { unique: true, partialFilterExpression: { status: 'PENDING' } });
export const Game = make('Game', {
  code: { type: String, unique: true, required: true }, host: String, mode: String, capacity: Number,
  members: [String], names: [String], status: { type: String, default: 'waiting', index: true },
  state: Schema.Types.Mixed, initial: Schema.Types.Mixed, settled: { type: Boolean, default: false },
  endedAt: Date, revision: { type: Number, default: 0 },
  entryFee: { type: Number, default: 0, min: 0 },
  prizePool: { type: Number, default: 0 },
  stakeMinor: { type: Number, default: 0, min: 0 },
  prizePoolMinor: { type: Number, default: 0, min: 0 },
  platformFinance: Schema.Types.Mixed,
  financeLeaseOwner: String, financeLeaseUntil: Date,
  fundingState: { type: String, enum: ['WAITING', 'FUNDS_RESERVED', 'STARTED', 'COMPLETED', 'CANCELLED', 'SETTLED', 'REFUNDED'], default: 'WAITING' },
});
Game.schema.index({ members: 1, createdAt: -1 });
export const Event = make('Event', { game: { type: String, index: true }, revision: Number, actor: String, action: Schema.Types.Mixed, state: Schema.Types.Mixed });
Event.schema.index({ game: 1, revision: 1 }, { unique: true });
export const Chat = make('Chat', { game: { type: String, index: true }, userId: String, username: String, message: String });
export const Queue = make('Queue', { userId: { type: String, unique: true }, username: String, capacity: Number, rating: Number, platformPlayer: { type: Boolean, default: false }, entryFee: { type: Number, default: 0 }, stakeMinor: { type: Number, default: 0 }, stakeRef: String });
export const Wallet = make('Wallet', {
  userId: { type: String, required: true, unique: true },
  available: { type: Number, required: true, min: 0 },
  reserved: { type: Number, required: true, min: 0, default: 0 },
  currency: { type: String, enum: ['DEMO_CREDITS'], default: 'DEMO_CREDITS' },
});
export const Stake = make('Stake', {
  userId: { type: String, required: true, index: true },
  gameId: { type: String, default: null, index: true },
  queueId: { type: String, default: null },
  amount: { type: Number, required: true, min: 1 },
  state: { type: String, enum: ['RESERVED', 'CAPTURED', 'RELEASED', 'REFUNDED'], required: true },
  reference: { type: String, required: true, unique: true },
});
export const Transaction = make('Transaction', {
  userId: { type: String, required: true, index: true },
  amount: { type: Number, required: true },
  availableDelta: { type: Number, required: true },
  reservedDelta: { type: Number, required: true },
  availableAfter: { type: Number, required: true, min: 0 },
  reservedAfter: { type: Number, required: true, min: 0 },
  type: { type: String, enum: ['OPENING_BALANCE', 'WELCOME', 'DAILY', 'WIN', 'ADMIN_ADJUSTMENT', 'DEPOSIT', 'WITHDRAWAL', 'STAKE_RESERVE', 'STAKE_CAPTURE', 'STAKE_RELEASE', 'PRIZE', 'REFUND'], required: true },
  status: { type: String, enum: ['POSTED'], default: 'POSTED' },
  reference: { type: String, required: true, unique: true },
  gameId: String,
  actor: String,
  reason: String,
});
Transaction.schema.pre('save', function rejectExistingLedgerSave() { if (!this.isNew) throw new Error('Ledger entries are immutable'); });
for (const operation of ['updateOne', 'updateMany', 'findOneAndUpdate', 'replaceOne', 'findOneAndReplace', 'deleteOne', 'deleteMany', 'findOneAndDelete']) {
  Transaction.schema.pre(operation, function rejectLedgerMutation() { throw new Error('Ledger entries are immutable'); });
}
export const MoneyWallet = make('MoneyWallet', {
  userId: { type: String, required: true, unique: true },
  availableMinor: { type: Number, required: true, min: 0, default: 0 },
  reservedMinor: { type: Number, required: true, min: 0, default: 0 },
  currency: { type: String, enum: ['EGP'], default: 'EGP' },
});
export const MoneyStake = make('MoneyStake', {
  userId: { type: String, required: true, index: true },
  gameId: { type: String, default: null, index: true },
  queueId: { type: String, default: null },
  amountMinor: { type: Number, required: true, min: 1 },
  state: { type: String, enum: ['RESERVED', 'CAPTURED', 'RELEASED', 'REFUNDED'], required: true },
  reference: { type: String, required: true, unique: true },
});
export const MoneyTransaction = make('MoneyTransaction', {
  userId: { type: String, required: true, index: true },
  amountMinor: { type: Number, required: true },
  availableDeltaMinor: { type: Number, required: true },
  reservedDeltaMinor: { type: Number, required: true },
  availableAfterMinor: { type: Number, required: true, min: 0 },
  reservedAfterMinor: { type: Number, required: true, min: 0 },
  currency: { type: String, enum: ['EGP'], default: 'EGP' },
  type: { type: String, enum: ['DEPOSIT', 'WITHDRAWAL_RESERVE', 'WITHDRAWAL_PAID', 'WITHDRAWAL_RELEASE', 'STAKE_RESERVE', 'STAKE_CAPTURE', 'STAKE_RELEASE', 'PRIZE', 'REFUND', 'ADMIN_ADJUSTMENT'], required: true },
  status: { type: String, enum: ['POSTED'], default: 'POSTED' },
  reference: { type: String, required: true, unique: true },
  matchId: String,
  depositRequestId: String,
  withdrawalRequestId: String,
  actor: String,
  reason: String,
});
MoneyTransaction.schema.pre('save', function rejectExistingMoneyLedgerSave() { if (!this.isNew) throw new Error('Money ledger entries are immutable'); });
for (const operation of ['updateOne', 'updateMany', 'findOneAndUpdate', 'replaceOne', 'findOneAndReplace', 'deleteOne', 'deleteMany', 'findOneAndDelete']) {
  MoneyTransaction.schema.pre(operation, function rejectMoneyLedgerMutation() { throw new Error('Money ledger entries are immutable'); });
}
export const DepositRequest = make('DepositRequest', {
  userId: { type: String, required: true, index: true },
  amountMinor: { type: Number, required: true, min: 1 },
  currency: { type: String, enum: ['EGP'], default: 'EGP' },
  requestId: { type: String, required: true, unique: true },
  transferReference: { type: String, required: true, unique: true },
  senderPhone: { type: String, required: true },
  receivingPhone: { type: String, required: true },
  note: { type: String, default: '' },
  status: { type: String, enum: ['PENDING', 'APPROVED', 'REJECTED'], default: 'PENDING', index: true },
  reviewedBy: String,
  reviewReason: String,
});
export const WithdrawalRequest = make('WithdrawalRequest', {
  userId: { type: String, required: true, index: true },
  amountMinor: { type: Number, required: true, min: 1 },
  currency: { type: String, enum: ['EGP'], default: 'EGP' },
  requestId: { type: String, required: true, unique: true },
  phone: { type: String, required: true },
  payoutReference: { type: String, unique: true, sparse: true },
  status: { type: String, enum: ['PENDING', 'PAID', 'REJECTED'], default: 'PENDING', index: true },
  reviewedBy: String,
  reviewReason: String,
});
export const Dispute = make('Dispute', { userId: String, game: String, message: String, status: { type: String, default: 'open' }, resolution: String });
export const Audit = make('Audit', { actor: String, action: String, target: String, amountMinor: Number, reference: String, reason: String, oldValue: String, newValue: String });
export const AppSetting = make('AppSetting', { key: { type: String, required: true, unique: true }, vodafoneCashReceivingNumber: { type: String, default: '' }, adminMutationVersion: { type: Number, default: 0 }, gameEnabled: { type: Boolean, default: true }, maintenanceMessage: { type: String, default: '' }, enabledModes: { type: [String], default: ['classic', 'practice'] }, matchTiers: { type: [Number], default: [0] }, cosmeticAvailability: { type: Map, of: Boolean, default: {} } });
export const models = [User, PlatformLaunch, CosmeticPurchase, Game, Event, Chat, Queue, Wallet, Stake, Transaction, MoneyWallet, MoneyStake, MoneyTransaction, DepositRequest, WithdrawalRequest, Dispute, Audit, AppSetting];
