import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { freshSQL, pendingFiles, migrationSQL } from '../scripts/database-plan.mjs';

export async function baselineDb() {
 const db = new PGlite({extensions:{pg_trgm}});
 await db.exec(await readFile(new URL('./helpers/supabase-auth.sql',import.meta.url),'utf8'));
 return db;
}
test('empty database accepts complete baseline and ordered migration chain; rerun refuses existing data',async t=>{
 const db = await baselineDb(); t.after(()=>db.close());
 try { await db.exec(await freshSQL()); } catch(e) { throw new Error(e.message); }
 assert.equal((await db.query('select count(*)::int n from members')).rows[0].n,0);
 for (const table of ['members','tasks','member_notes','public_event_pages','event_registrations','event_tickets']) {
  assert.equal((await db.query('select relrowsecurity from pg_class where oid=$1::regclass',[table])).rows[0].relrowsecurity,true);
 }
 await assert.rejects(db.exec(await freshSQL()),/refuses an existing/);
 await db.exec('ROLLBACK');
 assert.equal((await db.query('select count(*)::int n from members')).rows[0].n,0);
});
test('schema-only legacy snapshot upgrades using every real migration without replacing records',async t=>{
 const db = await baselineDb(); t.after(()=>db.close());
 await db.exec(await readFile(new URL('../supabase/bootstrap/schema.sql',import.meta.url),'utf8'));
 await db.exec(await readFile(new URL('../supabase/bootstrap/reference-data.sql',import.meta.url),'utf8'));
 await db.exec("insert into members(name,email,birth_day,birth_month,system_role) values('Fixture','fixture@example.invalid',1,1,'User')");
 for (const file of await pendingFiles()) {
  try { await db.exec(await migrationSQL(file)); } catch(e) { throw new Error(`${file}: ${e.message}`); }
 }
 assert.equal((await db.query("select count(*)::int n from members where email='fixture@example.invalid'")).rows[0].n,1);
});
