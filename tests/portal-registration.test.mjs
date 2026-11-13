import test from 'node:test';
import assert from 'node:assert/strict';
import {eventDb,register,asUser,ids,eventId} from './helpers/event-portal-db.mjs';
test('verified external attendees register once without gaining community access',async()=>{
 const db=await eventDb();try{
  const first=await register(db);assert.equal(first.status,'registered');
  const again=await register(db);assert.equal(again.status,'already_registered');assert.equal(again.registration_id,first.registration_id);
  assert.equal((await db.query('SELECT * FROM members')).rows.length,0);
  assert.equal((await db.query('SELECT * FROM tasks')).rows.length,0);
  assert.equal((await db.query('SELECT * FROM member_notes')).rows.length,0);
  assert.equal((await db.query('SELECT * FROM get_member_scores()')).rows.length,0);
  assert.equal((await db.query('SELECT get_my_profile() AS p')).rows[0].p,null);
  const own=(await db.query('SELECT * FROM event_registrations')).rows[0];
  assert.equal(own.auth_user_id,ids.outsider);assert.equal(own.email,'outsider@example.invalid');assert.equal(own.consent_text,'Consent text');
  await assert.rejects(db.query("UPDATE event_registrations SET state='cancelled'"),e=>e.code==='42501');
  await assert.rejects(db.query('DELETE FROM event_registrations'),e=>e.code==='42501');
  assert.equal((await register(db,'a')).status,'full');
  await asUser(db,'a');assert.equal((await db.query('SELECT * FROM event_registrations')).rows.length,0);
  await asUser(db,'admin');assert.equal((await db.query('SELECT * FROM event_registrations')).rows.length,1);
  await assert.rejects(db.query('UPDATE public_event_pages SET capacity=0'),e=>e.code==='P0001'||e.code==='23514');
  await db.exec('RESET ROLE; SET ROLE anon');assert.equal((await db.query('SELECT title FROM public_event_pages')).rows[0].title,'Public event');
  await assert.rejects(db.query('SELECT * FROM event_registrations'),e=>e.code==='42501');
  await assert.rejects(db.query("SELECT register_for_event('open-event','Guest','v1',true,null)"),e=>e.code==='42501');
 }finally{await db.close();}
});
test('consent version, verified identity, closed/cancelled state and durable rate limits are enforced',async()=>{
 const db=await eventDb();try{
  assert.equal((await register(db,'outsider',{accepted:false})).status,'consent_required');
  assert.equal((await register(db,'outsider',{version:'old'})).status,'consent_required');
  assert.equal((await register(db,'outsider',{expected:ids.admin})).status,'session_changed');
  await db.exec("RESET ROLE; UPDATE auth.users SET email_confirmed_at=null WHERE id='"+ids.outsider+"'");
  assert.equal((await register(db)).status,'verification_required');
  await db.exec("RESET ROLE; UPDATE auth.users SET email_confirmed_at=now() WHERE id='"+ids.outsider+"'; DELETE FROM private.portal_rate_limits");
  for(let i=0;i<10;i++)assert.equal((await register(db,'outsider',{name:''})).status,'invalid_input');
  assert.equal((await register(db)).status,'rate_limited');
  await db.exec("RESET ROLE; UPDATE private.portal_rate_limits SET window_start=now()-interval '11 minutes'");
  await asUser(db,'admin');await db.exec("UPDATE public_event_pages SET state='closed'");assert.equal((await register(db)).status,'closed');
  await asUser(db,'admin');await db.exec("UPDATE public_event_pages SET state='cancelled'");assert.equal((await register(db)).status,'cancelled');
  await asUser(db,'admin');await db.exec("UPDATE public_event_pages SET state='draft'");assert.equal((await register(db)).status,'not_found');
  await db.exec('RESET ROLE; SET ROLE anon');assert.equal((await db.query('SELECT * FROM public_event_pages')).rows.length,0);
 }finally{await db.close();}
});
test('an internal member can also attend, while registration cannot publish events or change ownership',async()=>{
 const db=await eventDb();try{
  assert.equal((await register(db,'a')).status,'registered');
  assert.equal((await db.query('SELECT current_member_id() AS id')).rows[0].id,ids.a);
  assert.equal((await db.query("UPDATE public_event_pages SET state='cancelled' RETURNING event_id")).rows.length,0);
  await assert.rejects(db.query("UPDATE event_registrations SET auth_user_id=$1",[ids.b]),e=>e.code==='42501');
  await asUser(db,'admin');
  await assert.rejects(db.query("UPDATE public_event_pages SET slug='another-event' WHERE event_id=$1",[eventId]),/identity cannot change/);
  await db.exec("UPDATE public_event_pages SET consent_text='New text',consent_version='v2'");
  assert.equal((await db.query('SELECT consent_text FROM event_registrations')).rows[0].consent_text,'Consent text');
 }finally{await db.close();}
});
