import test from 'node:test';
import assert from 'node:assert/strict';
import { PlatformAdapter } from '../src/platform.js';

test('mock platform verifies only explicit local sessions and never approves paid cosmetics', async () => {
  const adapter = new PlatformAdapter({ platformMock: true });
  assert.equal((await adapter.verify('mock:local_player')).playerId, 'local_player');
  await assert.rejects(adapter.verify('guest'), /Invalid mock platform session/);
  assert.deepEqual(await adapter.balance('local_player'), { points: 0, currency: 'PLATFORM_POINTS', available: true });
  assert.equal(adapter.cosmeticPrice({ id: 'dice_classic', priceCoins: 0 }), 0);
  assert.equal(adapter.cosmeticPrice({ id: 'dice_gold', priceCoins: 500 }), null);
  await assert.rejects(adapter.purchase('local_player', 'dice_gold', 100), /Paid cosmetics require platform billing/);
});

test('configured platform price is independent of legacy coins', () => {
  const adapter = new PlatformAdapter({ platformCosmeticPrices: { dice_gold: 75 } });
  assert.equal(adapter.cosmeticPrice({ id: 'dice_gold', priceCoins: 500 }), 75);
});
