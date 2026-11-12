import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';

test('read-only community audit reports unsafe grants, missing tables and corrected privileges', async () => {
  const db = new PGlite();
  try {
    await db.exec(`CREATE ROLE anon; CREATE ROLE authenticated;
      CREATE TABLE public.events (id int, name text);
      GRANT SELECT (name) ON public.events TO anon;
      GRANT TRUNCATE ON public.events TO authenticated;
      CREATE POLICY legacy_open ON public.events FOR SELECT TO anon USING (true);`);
    const sql = await readFile(new URL('../supabase/audits/private_community_access.sql', import.meta.url), 'utf8');
    let result = (await db.query(sql)).rows;
    assert.equal(result.length, 7);
    const unsafe = result.find((r) => r.table_name === 'events');
    assert.equal(unsafe.table_exists, true);
    assert.equal(unsafe.rls_enabled, false);
    assert.equal(unsafe.anon_any_column_select, true);
    assert.equal(unsafe.authenticated_truncate, true);
    assert.equal(unsafe.policies[0].name, 'legacy_open');
    assert.equal(result.find((r) => r.table_name === 'menu_items').table_exists, false);
    await db.exec('ALTER TABLE public.events ENABLE ROW LEVEL SECURITY; REVOKE SELECT(name) ON public.events FROM anon; REVOKE TRUNCATE ON public.events FROM authenticated; DROP POLICY legacy_open ON public.events');
    result = (await db.query(sql)).rows;
    const corrected = result.find((r) => r.table_name === 'events');
    assert.equal(corrected.rls_enabled, true);
    assert.equal(corrected.anon_any_column_select, false);
    assert.equal(corrected.authenticated_truncate, false);
    assert.deepEqual(corrected.policies, []);
  } finally { await db.close(); }
});
