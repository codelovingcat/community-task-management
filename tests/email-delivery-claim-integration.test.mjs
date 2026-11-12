import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { createRequire } from 'node:module';
import { PGlite } from '@electric-sql/pglite';

const require = createRequire(import.meta.url);
const clientModule = require('../email-worker/dist/supabaseClient.js');
const { claimDelivery } = require('../email-worker/dist/deliveryClaim.js');

// Test the repository migration and compare-and-set predicates against an
// isolated PostgreSQL engine. This does not simulate a real provider or JWT.
test('each queue has only one owner and stale workers cannot change its claimed row', async (t) => {
  const db = new PGlite();
  t.after(() => db.close());
  await db.exec(`
    CREATE TABLE public.email_queue (id bigint PRIMARY KEY, status text NOT NULL, next_attempt_at timestamptz);
    CREATE TABLE public.speaker_email_queue (id uuid PRIMARY KEY, status text NOT NULL, scheduled_at timestamptz);
    INSERT INTO public.email_queue VALUES (1, 'pending', now());
    INSERT INTO public.speaker_email_queue VALUES ('b1000000-0000-4000-8000-000000000001', 'pending', now());
  `);
  const migration = await readFile(new URL('../supabase/migrations/20261104204533_email_delivery_claims.sql', import.meta.url), 'utf8');
  await db.exec(migration);
  await db.exec(migration);
  // Translate the worker's PostgREST operations to parameterized SQL on PGlite.
  // Reject unexpected operations rather than pretending they succeeded.
  t.mock.method(clientModule, 'getSupabaseClient', () => ({ from(table) {
    assert.ok(['email_queue', 'speaker_email_queue'].includes(table));
    const values = {}; const filters = [];
    return {
      update(row) { Object.assign(values, row); return this; },
      eq(column, value) { filters.push([column, value]); return this; },
      is(column, value) { assert.equal(column, 'delivery_claim_token'); assert.equal(value, null); filters.push([column, null]); return this; },
      select(column) { assert.equal(column, 'id'); return this; },
      async maybeSingle() {
        assert.deepEqual(filters.map(([key]) => key), ['id', 'status', 'delivery_claim_token']);
        const result = await db.query(`UPDATE public.${table}
          SET delivery_claim_token = $1, delivery_claimed_at = $2
          WHERE id = $3 AND status = $4 AND delivery_claim_token IS NULL RETURNING id`,
          [values.delivery_claim_token, values.delivery_claimed_at, filters[0][1], filters[1][1]]);
        return { data: result.rows[0] ?? null, error: null };
      }
    };
  } }));
  for (const [table, id] of [['email_queue', 1], ['speaker_email_queue', 'b1000000-0000-4000-8000-000000000001']]) {
    const results = await Promise.all([claimDelivery(table, id), claimDelivery(table, id)]);
    assert.equal(results.filter(Boolean).length, 1, table);
    const owner = results.find(Boolean);
    const loser = 'a1000000-0000-4000-8000-000000000002';
    assert.equal((await db.query(`SELECT delivery_claim_token FROM public.${table} WHERE id=$1`, [id])).rows[0].delivery_claim_token, owner);
    assert.equal((await db.query(`UPDATE public.${table} SET status='sent'
      WHERE id=$1 AND status='pending' AND delivery_claim_token=$2 RETURNING id`, [id, loser])).rows.length, 0);
    assert.equal((await db.query(`UPDATE public.${table} SET status='failed'
      WHERE id=$1 AND status='pending' AND delivery_claim_token IS NULL RETURNING id`, [id])).rows.length, 0);
    assert.equal((await db.query(`UPDATE public.${table} SET status='sent'
      WHERE id=$1 AND status='pending' AND delivery_claim_token=$2 RETURNING id`, [id, owner])).rows.length, 1);
    assert.equal(await claimDelivery(table, id), null);
  }
});
