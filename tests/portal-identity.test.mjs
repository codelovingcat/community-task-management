import test from 'node:test';
import assert from 'node:assert/strict';
import {portalDb,asUser,ids} from './helpers/portal-db.mjs';

test('stable Auth identity protects direct rows, RPCs and scores despite permissive legacy policies',async()=>{
 const db=await portalDb(); try {
  for(const key of ['a','b']) {
   await asUser(db,key);
   for(const table of ['members','tasks','archived_tasks']) assert.deepEqual((await db.query(`SELECT id FROM ${table}`)).rows.map(r=>r.id),[ids[key]]);
   assert.equal((await db.query('SELECT get_my_profile() AS p')).rows[0].p.member.id,ids[key]);
   assert.equal((await db.query('SELECT get_current_member() AS p')).rows[0].p.id,ids[key]);
   await assert.rejects(db.query('SELECT * FROM private.member_identities'),e=>e.code==='42501');
   await assert.rejects(db.query('SELECT link_verified_member($1,$1)',[ids[key]]),e=>e.code==='42501');
   assert.equal((await db.query("UPDATE tasks SET points=100 RETURNING id")).rows.length,0);
   assert.equal((await db.query('DELETE FROM archived_tasks RETURNING id')).rows.length,0);
   await assert.rejects(db.query(`INSERT INTO archived_tasks(id,assignee_id,points,done_completed_at,archived_reason) VALUES (gen_random_uuid(),'${ids[key]}',999,now(),'fake')`),e=>e.code==='42501');
  }
  for(const key of ['admin','super']) {await asUser(db,key); assert.equal((await db.query('SELECT * FROM tasks')).rows.length,2); assert.equal((await db.query('SELECT * FROM members')).rows.length,4);}
  await asUser(db,'outsider'); assert.equal((await db.query('SELECT * FROM tasks')).rows.length,0); assert.equal((await db.query('SELECT get_my_profile() AS p')).rows[0].p,null);
  await db.exec(`RESET ROLE; UPDATE auth.users SET email='changed@example.invalid' WHERE id='${ids.a}'; UPDATE members SET email='different@example.invalid' WHERE id='${ids.a}'`);
  await asUser(db,'a'); await db.query("SELECT set_config('request.jwt.claims',$1,false)",[JSON.stringify({email:'admin@example.invalid'})]);
  assert.equal((await db.query('SELECT current_member_id() AS id')).rows[0].id,ids.a);
  assert.equal((await db.query('SELECT current_member_role() AS role')).rows[0].role,'User');
  await db.exec(`RESET ROLE; UPDATE members SET is_active=false WHERE id='${ids.a}'`);
  await asUser(db,'a'); assert.equal((await db.query('SELECT * FROM tasks')).rows.length,0);
  await db.exec('RESET ROLE; SET ROLE anon');
  await assert.rejects(db.query('SELECT get_my_profile()'),e=>e.code==='42501');
  await assert.rejects(db.query('SELECT points FROM tasks'),e=>e.code==='42501');
 } finally {await db.close();}
});
