import {portalDb,migrate,asUser,ids} from './portal-db.mjs';
export {migrate,asUser,ids};
export const eventId='e0000000-0000-4000-8000-000000000001';
export async function eventDb() {
 const db=await portalDb();
 await migrate(db,'20261113200634_task_completion_scores.sql');
 await migrate(db,'20261113201104_member_private_notes.sql');
 await db.exec("CREATE TABLE events(id uuid PRIMARY KEY,title text); CREATE TABLE event_staff(id uuid, event_id uuid,member_id uuid); INSERT INTO events VALUES('"+eventId+"','Internal event');");
 await migrate(db,'20261113204406_public_event_registration.sql');
 await asUser(db,'admin');
 await db.query("INSERT INTO public_event_pages(event_id,slug,title,starts_at,ends_at,registration_closes_at,capacity,state,privacy_url,consent_version,consent_text) VALUES($1,'open-event','Public event',now()+interval '1 day',now()+interval '2 days',now()+interval '1 day',1,'open','https://example.com/privacy','v1','Consent text')",[eventId]);
 return db;
}
export async function register(db,key='outsider',extra={}) {
 await asUser(db,key);
 return (await db.query('SELECT register_for_event($1,$2,$3,$4,$5) AS result',[extra.slug??'open-event',extra.name??'Test Guest',extra.version??'v1',extra.accepted??true,extra.expected??ids[key]])).rows[0].result;
}
