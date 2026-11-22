import test from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { PGlite } from '@electric-sql/pglite';
import { pg_trgm } from '@electric-sql/pglite/contrib/pg_trgm';
import { freshSQL } from '../scripts/database-plan.mjs';

test('complete schema preserves admin CRUD and rejects external, inactive and anonymous community access',async t=>{
 const db=new PGlite({extensions:{pg_trgm}});t.after(()=>db.close());
 await db.exec(await readFile(new URL('./helpers/supabase-auth.sql',import.meta.url),'utf8'));
 await db.exec(await freshSQL());
 const ids=['10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000003'];
 for(let i=0;i<ids.length;i++) {
  await db.query('insert into auth.users values($1,$2,now())',[ids[i],`fixture${i}@example.invalid`]);
  if(i<2){
   await db.query('insert into members(id,name,email,birth_day,birth_month,system_role) values($1,$2,$3,1,1,$4)',[ids[i],`Fixture ${i}`,`fixture${i}@example.invalid`,i===0?'Admin':'User']);
   await db.query('select link_verified_member($1,$1)',[ids[i]]);
  }
 }
 const act=async id=>{await db.exec('reset role; set role authenticated');await db.query("select set_config('request.jwt.claims',$1,false)",[JSON.stringify({sub:id,role:'authenticated'})]);};
 await act(ids[0]);
 const setting=(await db.query("insert into community_settings(app_name) values('Smoke fixture') returning id")).rows[0].id;
 assert.equal((await db.query("update community_settings set app_name='Changed' where id=$1 returning id",[setting])).rows.length,1);
 await act(ids[1]);
 assert.equal((await db.query('select id from community_settings where id=$1',[setting])).rows.length,1);
 assert.equal((await db.query("update community_settings set app_name='Denied' where id=$1 returning id",[setting])).rows.length,0);
 await assert.rejects(db.query("insert into community_settings(app_name) values('Denied')"),e=>e.code==='42501');
 await act(ids[2]);
 const tables=['announcements','announcement_members','events','event_staff','event_speakers','community_settings','menu_items'];
 for(const table of tables) assert.equal((await db.query(`select * from ${table}`)).rows.length,0);
 await db.exec('reset role');await db.query('update members set is_active=false where id=$1',[ids[1]]);
 await act(ids[1]);assert.equal((await db.query('select * from community_settings')).rows.length,0);
 await db.exec('reset role;set role anon');
 for(const table of tables) await assert.rejects(db.query(`select * from ${table}`),e=>e.code==='42501');
 await act(ids[0]);assert.equal((await db.query('delete from community_settings where id=$1 returning id',[setting])).rows.length,1);
 await db.exec('reset role');
 const gate=await db.query(await readFile(new URL('../supabase/audits/private_community_release_gate.sql',import.meta.url),'utf8'));
 assert.equal(gate.rows.length,7);assert.ok(gate.rows.every(r=>r.ready));
 await db.exec('grant truncate on events to authenticated');
 assert.equal((await db.query(await readFile(new URL('../supabase/audits/private_community_release_gate.sql',import.meta.url),'utf8'))).rows.find(r=>r.name==='events').ready,false);
});
