import test from 'node:test';
import assert from 'node:assert/strict';
import {portalDb,migrate,asUser,ids} from './helpers/portal-db.mjs';
test('notes are private even from admins; ownership, lengths and timestamps cannot be forged',async()=>{
 const db=await portalDb();try {
  await migrate(db,'20261113201104_member_private_notes.sql');
  await asUser(db,'a');
  const note=(await db.query("INSERT INTO member_notes(title,body,priority) VALUES ('Plan','<script>plain text</script>','high') RETURNING *")).rows[0];
  assert.equal(note.owner_id,ids.a);
  await db.query("UPDATE member_notes SET body='Updated' WHERE id=$1",[note.id]);
  assert.equal((await db.query('SELECT body FROM member_notes')).rows[0].body,'Updated');
  await assert.rejects(db.query('UPDATE member_notes SET owner_id=$1 WHERE id=$2',[ids.b,note.id]),e=>e.code==='42501');
  await assert.rejects(db.query("UPDATE member_notes SET created_at='2000-01-01'"),e=>e.code==='42501');
  await assert.rejects(db.query("UPDATE member_notes SET updated_at='2000-01-01'"),e=>e.code==='42501');
  await assert.rejects(db.query('TRUNCATE member_notes'),e=>e.code==='42501');
  await assert.rejects(db.query('INSERT INTO member_notes(owner_id,title) VALUES ($1,$2)',[ids.b,'Spoof']),e=>e.code==='42501');
  for(const [title,body,priority] of [[' ', '', 'normal'],['x'.repeat(121),'','normal'],['Valid','x'.repeat(4001),'normal'],['Valid','','unknown']]) await assert.rejects(db.query('INSERT INTO member_notes(title,body,priority) VALUES($1,$2,$3)',[title,body,priority]),e=>e.code==='23514');
  for(const key of ['b','admin','super','outsider']) {
   await asUser(db,key);assert.equal((await db.query('SELECT * FROM member_notes')).rows.length,0);
   assert.equal((await db.query("UPDATE member_notes SET body='Hacked' RETURNING id")).rows.length,0);
   assert.equal((await db.query('DELETE FROM member_notes RETURNING id')).rows.length,0);
   await assert.rejects(db.query('INSERT INTO member_notes(owner_id,title) VALUES($1,$2)',[ids.a,'Spoof']),e=>e.code==='42501');
  }
  await asUser(db,'a');assert.equal((await db.query('DELETE FROM member_notes WHERE id=$1 RETURNING id',[note.id])).rows.length,1);
  await db.exec('RESET ROLE; SET ROLE anon');await assert.rejects(db.query('SELECT * FROM member_notes'),e=>e.code==='42501');
 }finally{await db.close();}
});
