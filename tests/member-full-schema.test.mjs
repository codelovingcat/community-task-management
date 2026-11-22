import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { freshSQL } from '../scripts/database-plan.mjs';
import { createHash } from 'node:crypto';

test('real member CRUD works without mail worker and rollback leaves no rows or queued messages',async t=>{
 const db=new PGlite({extensions:{pg_trgm}});t.after(()=>db.close());
 const read=path=>readFile(new URL(path,import.meta.url),'utf8');
 await db.exec(await read('./helpers/supabase-auth.sql'));
 await db.exec(await freshSQL());
 await db.exec(await read('./helpers/admin-fixture.sql'));
 const counts=()=>db.query('select (select count(*)::int from members) members,(select count(*)::int from email_queue) jobs,(select count(*)::int from notifications) notifications');
 const before=(await counts()).rows;
 try {await db.exec(await read('../supabase/tests/member_crud_rollback.sql'));}catch(e){throw new Error(e.message);}
 assert.deepEqual((await counts()).rows,before);
 const audit=await db.query(await read('../supabase/audits/application_schema_readiness.sql'));
 assert.equal(audit.rows.length,16);
 assert.ok(audit.rows.every(r=>r.present),JSON.stringify(audit.rows.filter(r=>!r.present)));
});

test('reviewed Task Manager-only rollout upgrades the observed legacy schema without worker migrations',async t=>{
 const db=new PGlite({extensions:{pg_trgm}});t.after(()=>db.close());
 const read=path=>readFile(new URL(path,import.meta.url),'utf8');
 await db.exec(await read('./helpers/supabase-auth.sql'));
 await db.exec(await read('../supabase/bootstrap/schema.sql'));
 await db.exec(await read('../supabase/bootstrap/reference-data.sql'));
 // This account existed before the upgrade, as in the live schema audit.
 await db.exec("insert into auth.users values('10000000-0000-4000-8000-000000000001','admin@example.invalid',now()); insert into members(id,name,email,birth_day,birth_month,system_role) values('10000000-0000-4000-8000-000000000001','Fixture admin','admin@example.invalid',1,1,'Admin')");
 const plan=JSON.parse(await read('../supabase/rollout/task-manager.json'));
 for(const {file,sha256} of plan.migrations){
  const sql=await read(`../supabase/migrations/${file}`);
  assert.equal(createHash('sha256').update(sql).digest('hex'),sha256);
  try {await db.exec(sql);}catch(e){throw new Error(`${file}: ${e.message}`);}
 }
 await db.exec(await read('../supabase/tests/member_crud_rollback.sql'));
 const audit=await db.query(await read('../supabase/audits/application_schema_readiness.sql'));
 assert.ok(audit.rows.every(r=>r.present));
 assert.equal((await db.query('select count(*)::int n from members')).rows[0].n,1);
});
