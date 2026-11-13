import test from 'node:test';
import assert from 'node:assert/strict';
import {eventDb,register,asUser,ids,eventId,migrate} from './helpers/event-portal-db.mjs';
const migration='20261113205457_private_event_tickets.sql';
async function scan(db,key,reference,revoke=false) {
 await asUser(db,key);return (await db.query('SELECT '+(revoke?'revoke_event_ticket':'check_in_event_ticket')+'($1,$2,$3) AS result',[eventId,reference,ids[key]])).rows[0].result;
}
test('ticket backfill and issuance preserve owner privacy; attendee cannot forge state or check in',async()=>{
 const db=await eventDb();try{
  await register(db);await db.exec('RESET ROLE');await migrate(db,migration);await asUser(db,'outsider');
  const tickets=(await db.query('SELECT get_my_tickets() AS items')).rows[0].items;assert.equal(tickets.length,1);assert.match(tickets[0].reference,/^[a-f0-9-]{36}$/);
  const ref=tickets[0].reference;
  await assert.rejects(scan(db,'outsider',ref),e=>e.code==='42501');
  await asUser(db,'outsider');await assert.rejects(db.query("UPDATE event_tickets SET state='checked_in'"),e=>e.code==='42501');
  await assert.rejects(db.query('DELETE FROM event_tickets'),e=>e.code==='42501');
  await asUser(db,'b');assert.equal((await db.query('SELECT * FROM event_tickets')).rows.length,0);assert.deepEqual((await db.query('SELECT get_my_tickets() AS items')).rows[0].items,[]);
  await assert.rejects(scan(db,'b',ref),e=>e.code==='42501');
  await asUser(db,'admin');assert.equal((await db.query('SELECT * FROM event_tickets')).rows.length,1);assert.deepEqual((await db.query('SELECT get_my_tickets() AS items')).rows[0].items,[]);
  await db.exec('RESET ROLE; SET ROLE anon');await assert.rejects(db.query('SELECT get_my_tickets()'),e=>e.code==='42501');
 }finally{await db.close();}
});
test('event staff check-in is atomic/idempotent; revoked and cancelled tickets fail and release capacity',async()=>{
 const db=await eventDb();try{
  await db.exec('RESET ROLE');await migrate(db,migration);
  await register(db);const ref=(await db.query('SELECT get_my_tickets() AS items')).rows[0].items[0].reference;
  assert.equal((await scan(db,'admin',ref)).status,'not_open');
  await db.exec("RESET ROLE; INSERT INTO event_staff VALUES(gen_random_uuid(),'"+eventId+"','"+ids.a+"')");
  await asUser(db,'admin');await db.exec("UPDATE public_event_pages SET starts_at=now()-interval '1 hour',ends_at=now()+interval '1 hour',registration_closes_at=now()+interval '30 minutes'");
  assert.equal((await scan(db,'a',ref)).status,'checked_in');
  assert.equal((await scan(db,'a',ref)).status,'already_checked_in');
  await asUser(db,'a');assert.equal((await db.query('SELECT * FROM event_tickets')).rows.length,0);
  await assert.rejects(scan(db,'a',ref,true),e=>e.code==='42501');
  assert.equal((await scan(db,'admin',ref,true)).status,'revoked');
  assert.equal((await scan(db,'admin',ref,true)).status,'already_revoked');
  assert.equal((await scan(db,'a',ref)).status,'revoked');
  assert.equal((await register(db,'b')).status,'registered'); // Released seat; trigger issues a second ticket.
  assert.equal((await db.query('SELECT get_my_tickets() AS items')).rows[0].items.length,1);
  await asUser(db,'admin');assert.equal((await db.query('SELECT * FROM event_tickets')).rows.length,2);
  await db.exec("UPDATE public_event_pages SET state='cancelled'");
  assert.equal((await scan(db,'admin',ref)).status,'event_unavailable');
 }finally{await db.close();}
});
test('self check-in, stale operator identity, wrong ticket, and ended events cannot admit a person',async()=>{
 const db=await eventDb();try{
  await db.exec('RESET ROLE');await migrate(db,migration);await register(db,'admin');
  const ref=(await db.query('SELECT get_my_tickets() AS items')).rows[0].items[0].reference;
  assert.equal((await scan(db,'admin',ref)).status,'self_checkin_forbidden');
  await assert.rejects(db.query('SELECT check_in_event_ticket($1,$2,$3)',[eventId,ref,ids.b]),e=>e.code==='42501');
  assert.equal((await scan(db,'super','b0000000-0000-4000-8000-000000000099')).status,'invalid_ticket');
  await asUser(db,'admin');await db.exec("UPDATE public_event_pages SET starts_at=now()-interval '2 hours',ends_at=now()-interval '1 hour',registration_closes_at=now()-interval '2 hours'");
  assert.equal((await scan(db,'super',ref)).status,'ended');
 }finally{await db.close();}
});
