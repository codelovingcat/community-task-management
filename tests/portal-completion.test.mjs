import test from 'node:test';
import assert from 'node:assert/strict';
import {portalDb,migrate,asUser,ids} from './helpers/portal-db.mjs';
const migration='20261113200634_task_completion_scores.sql';

test('completion transitions, archive/restore and private score are consistent',async()=>{
 const db=await portalDb();try {
  await migrate(db,migration);
  await db.exec('DELETE FROM archived_tasks');
  await asUser(db,'admin');
  const score=async()=>Number((await db.query('SELECT total_points FROM get_member_scores() WHERE member_id=$1',[ids.a])).rows[0]?.total_points);
  const task=async()=> (await db.query('SELECT * FROM tasks WHERE id=$1',[ids.a])).rows[0];
  assert.equal(await score(),0);
  await db.query("UPDATE tasks SET completed_at='2000-01-01' WHERE id=$1",[ids.a]);assert.equal((await task()).completed_at,null);
  await db.query("UPDATE tasks SET status='completed',completed_at='2000-01-01',resource_url='https://example.com/survey?q=1' WHERE id=$1",[ids.a]);
  const stamp=new Date((await task()).completed_at).getTime();assert.ok(stamp>Date.parse('2026-01-01'));assert.equal(await score(),10);
  await db.query("UPDATE tasks SET description='Edited',completed_at='2000-01-01',status='done' WHERE id=$1",[ids.a]);assert.equal(new Date((await task()).completed_at).getTime(),stamp);
  await assert.rejects(db.query('UPDATE tasks SET assignee_id=$1 WHERE id=$2',[ids.b,ids.a]),/yeniden açın/);
  await db.query('SELECT archive_single_task($1)',[ids.a]);assert.equal(await score(),10);assert.equal(await task(),undefined);
  await asUser(db,'a'); const p=(await db.query('SELECT get_my_profile() AS p')).rows[0].p;assert.equal(p.score,10);assert.equal(new Date(p.tasks[0].completed_at).getTime(),stamp);assert.equal(p.tasks[0].archived,true);
  assert.equal((await db.query('SELECT * FROM get_member_scores()')).rows.length,1);
  await assert.rejects(db.query('SELECT archive_single_task($1)',[ids.b]),e=>e.code==='42501');
  await assert.rejects(db.query('SELECT restore_archived_task($1)',[ids.a]),e=>e.code==='42501');
  await assert.rejects(db.query('SELECT archive_done_tasks_older_than_7_days()'),e=>e.code==='42501');
  await asUser(db,'admin'); await db.query('SELECT restore_archived_task($1)',[ids.a]);assert.equal(new Date((await task()).completed_at).getTime(),stamp);assert.equal(await score(),10);
  await db.query("UPDATE tasks SET status='backlog' WHERE id=$1",[ids.a]);assert.equal((await task()).completed_at,null);assert.equal(await score(),0);
  await db.query('UPDATE tasks SET assignee_id=$1 WHERE id=$2',[ids.b,ids.a]);assert.equal(await score(),0);
  await db.query("UPDATE tasks SET status='done' WHERE id=$1",[ids.a]);assert.notEqual(new Date((await task()).completed_at).getTime(),stamp);
  await db.query('DELETE FROM tasks WHERE id=$1',[ids.a]);assert.equal(Number((await db.query('SELECT total_points FROM get_member_scores() WHERE member_id=$1',[ids.b])).rows[0].total_points),0);
 }finally{await db.close();}
});

test('unknown historical completion stays unknown, duplicates do not double score, conflicts roll back',async()=>{
 const db=await portalDb();try {
  await db.exec("UPDATE tasks SET status='done'"); await migrate(db,migration);
  await asUser(db,'admin');
  assert.equal((await db.query('SELECT completed_at FROM tasks LIMIT 1')).rows[0].completed_at,null);
  assert.equal(Number((await db.query('SELECT total_points FROM get_member_scores() WHERE member_id=$1',[ids.a])).rows[0].total_points),10);
  await assert.rejects(db.query('SELECT archive_single_task($1)',[ids.a]),e=>e.code==='23505');
  assert.equal((await db.query('SELECT id FROM tasks')).rows.length,2);
  await assert.rejects(db.query('SELECT restore_archived_task($1)',[ids.a]),e=>e.code==='23505');
  assert.equal((await db.query('SELECT id FROM archived_tasks')).rows.length,2);
  await db.query('DELETE FROM tasks WHERE id=$1',[ids.a]);await db.query('SELECT restore_archived_task($1)',[ids.a]);
  assert.equal((await db.query('SELECT completed_at FROM tasks WHERE id=$1',[ids.a])).rows[0].completed_at,null);
  await db.exec('RESET ROLE; SET ROLE service_role');assert.equal((await db.query('SELECT archive_done_tasks_older_than_7_days() AS n')).rows[0].n,0);
 }finally{await db.close();}
});

test('resource links reject unsafe schemes, credentials, controls and oversized input',async()=>{
 const db=await portalDb();try {
  await migrate(db,migration);await asUser(db,'admin');
  for(const url of ['http://example.com','javascript:alert(1)','https://user:pass@example.com','https://example.com/\nx','https://example.com/\\x','https://'+ 'x'.repeat(2050)]) {
   await assert.rejects(db.query('UPDATE tasks SET resource_url=$1 WHERE id=$2',[url,ids.a]),e=>e.code==='23514');
  }
  for(const url of [null,'https://example.com','https://forms.example.com/a?x=1#section']) await db.query('UPDATE tasks SET resource_url=$1 WHERE id=$2',[url,ids.a]);
 }finally{await db.close();}
});

test('scheduled archive uses actual completion age and retains resource and score',async()=>{
 const db=await portalDb();try {
  await db.exec('DELETE FROM archived_tasks');await migrate(db,migration);
  await asUser(db,'admin');
  await assert.rejects(db.query('SELECT archive_single_task($1)',[ids.a]),/completed/);
  await db.query("UPDATE tasks SET status='done',resource_url='https://example.com/form' WHERE id=$1",[ids.a]);
  // Simulate time passing without forging a browser-writable timestamp.
  await db.exec(`RESET ROLE; ALTER TABLE tasks DISABLE TRIGGER record_task_completion; UPDATE tasks SET completed_at=now()-interval '8 days' WHERE id='${ids.a}'; ALTER TABLE tasks ENABLE TRIGGER record_task_completion; SET ROLE service_role`);
  assert.equal((await db.query('SELECT archive_done_tasks_older_than_7_days() AS n')).rows[0].n,1);
  assert.equal((await db.query('SELECT archive_done_tasks_older_than_7_days() AS n')).rows[0].n,0);
  await asUser(db,'a');const p=(await db.query('SELECT get_my_profile() AS p')).rows[0].p;
  assert.equal(p.score,10);assert.equal(p.tasks[0].resource_url,'https://example.com/form');assert.equal(p.tasks[0].archived,true);
 }finally{await db.close();}
});
