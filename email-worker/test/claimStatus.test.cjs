const test = require('node:test');
const assert = require('node:assert/strict');
const clientModule = require('../dist/supabaseClient.js');
const { getStaleClaimCounts } = require('../dist/claimStatus.js');

test('counts stale pending claims in both queues without fetching identifiers or messages', async (t) => {
  const requests = [];
  t.mock.method(clientModule, 'getSupabaseClient', () => ({
    from(table) {
      const steps = []; requests.push([table, steps]);
      const query = {
        select(...args) { steps.push(['select', ...args]); return this; },
        eq(...args) { steps.push(['eq', ...args]); return this; },
        not(...args) { steps.push(['not', ...args]); return this; },
        lt(...args) { steps.push(['lt', ...args]); return Promise.resolve({ count: table === 'email_queue' ? 2 : 0, error: null }); },
      };
      return query;
    }
  }));
  const cutoff = new Date('2026-11-12T00:00:00Z');
  assert.deepEqual(await getStaleClaimCounts(cutoff), { email_queue: 2, speaker_email_queue: 0 });
  assert.equal(requests.length, 2);
  for (const [, steps] of requests) assert.deepEqual(steps, [
    ['select', 'id', { count: 'exact', head: true }], ['eq', 'status', 'pending'],
    ['not', 'delivery_claim_token', 'is', null], ['lt', 'delivery_claimed_at', cutoff.toISOString()]
  ]);
});

test('does not report a missing or failed count as a healthy queue', async (t) => {
  const q = { select() { return this; }, eq() { return this; }, not() { return this; },
    lt() { return Promise.resolve({ count: null, error: { message: 'private secret' } }); } };
  t.mock.method(clientModule, 'getSupabaseClient', () => ({ from: () => q }));
  await assert.rejects(getStaleClaimCounts(new Date()), /Could not inspect email_queue claims/);
});
