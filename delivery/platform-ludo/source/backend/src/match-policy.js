import { z } from 'zod';
import { assert } from './engine.js';

const tier = z.object({
  points: z.number().int().positive().safe(),
  capacity: z.union([z.literal(2), z.literal(4)]),
  winnerPoints: z.number().int().nonnegative().safe(),
  commissionPoints: z.number().int().nonnegative().safe()
}).strict().refine(t => t.winnerPoints + t.commissionPoints === t.points * t.capacity,
  'Winner award plus commission must equal all committed entries');

const schema = z.object({
  version: z.literal(1), policyId: z.string().regex(/^[a-zA-Z0-9_.-]{8,80}$/),
  approved: z.boolean(), testOnly: z.boolean(),
  settlementFunding: z.literal('committed-entry-escrow'),
  beforeStart: z.literal('release-reservations'),
  afterStart: z.literal('return-entries-via-settlement'),
  forfeit: z.literal('remaining-player-wins'),
  timeout: z.literal('engine-three-misses-forfeit'),
  rounding: z.literal('integer-exact'),
  tiers: z.array(tier).min(1)
}).strict().superRefine((p, ctx) => {
  const keys = new Set();
  for (const t of p.tiers) {
    const key = `${t.points}:${t.capacity}`;
    if (keys.has(key)) ctx.addIssue({ code: 'custom', message: `Duplicate tier ${key}` });
    keys.add(key);
  }
});

export function parseMatchPolicy(raw, { allowTest = false } = {}) {
  if (!raw) return null;
  const p = schema.parse(raw);
  assert(p.approved || (allowTest && p.testOnly), 'Match policy is not approved', 503);
  assert(!p.testOnly || allowTest, 'Test match policy cannot run in production', 503);
  return p;
}

export function policyTier(policy, points, capacity) {
  assert(policy, 'Approved match policy required', 503);
  const selected = policy.tiers.find(t => t.points === points && t.capacity === capacity);
  assert(selected, 'Match tier is not approved for this capacity', 403);
  return { ...selected, policyId: policy.policyId, version: policy.version,
    settlementFunding: policy.settlementFunding, beforeStart: policy.beforeStart,
    afterStart: policy.afterStart, forfeit: policy.forfeit, timeout: policy.timeout,
    rounding: policy.rounding };
}
