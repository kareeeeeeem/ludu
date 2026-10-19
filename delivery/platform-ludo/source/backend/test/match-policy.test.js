import test from 'node:test';
import assert from 'node:assert/strict';
import { parseMatchPolicy, policyTier } from '../src/match-policy.js';

const policy = { version: 1, policyId: 'test-policy-v1', approved: false, testOnly: true,
  settlementFunding: 'committed-entry-escrow', beforeStart: 'release-reservations',
  afterStart: 'return-entries-via-settlement', forfeit: 'remaining-player-wins',
  timeout: 'engine-three-misses-forfeit', rounding: 'integer-exact',
  tiers: [{ points: 10, capacity: 2, winnerPoints: 18, commissionPoints: 2 }] };

test('match policy fails closed and conserves every integer entry', () => {
  assert.equal(parseMatchPolicy(null), null);
  assert.throws(() => parseMatchPolicy(policy));
  assert.equal(policyTier(parseMatchPolicy(policy, { allowTest: true }), 10, 2).winnerPoints, 18);
  assert.throws(() => parseMatchPolicy({ ...policy, tiers: [{ ...policy.tiers[0], winnerPoints: 19 }] }, { allowTest: true }));
  assert.throws(() => parseMatchPolicy({ ...policy, tiers: [policy.tiers[0], policy.tiers[0]] }, { allowTest: true }));
  assert.throws(() => policyTier(parseMatchPolicy(policy, { allowTest: true }), 10, 4));
});
