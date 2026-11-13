import { PGlite } from '@electric-sql/pglite';
import { readFile } from 'node:fs/promises';
export const ids = Object.fromEntries(['a','b','admin','super','outsider'].map((key,i)=>[key,`a0000000-0000-4000-8000-00000000000${i+1}`]));
export async function migrate(db, name) { await db.exec(await readFile(new URL(`../../supabase/migrations/${name}`, import.meta.url),'utf8')); }
export async function asUser(db, key) {
 await db.exec('RESET ROLE; SET ROLE authenticated');
 await db.query("SELECT set_config('test.uid',$1,false)",[ids[key] || '']);
}
export async function portalDb() {
 const db = new PGlite();
 await db.exec(`
 CREATE ROLE anon; CREATE ROLE authenticated; CREATE ROLE service_role BYPASSRLS;
 CREATE SCHEMA auth; GRANT USAGE ON SCHEMA auth TO authenticated, service_role;
 CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$ SELECT nullif(current_setting('test.uid',true),'')::uuid $$;
 CREATE TABLE auth.users(id uuid PRIMARY KEY, email text, email_confirmed_at timestamptz);
 CREATE TABLE members(id uuid PRIMARY KEY,name text,email text,phone text,company text,job_title text,comm_title text,avatar text,bio text,system_role text,is_active boolean DEFAULT true);
 CREATE TABLE tasks(id uuid PRIMARY KEY DEFAULT gen_random_uuid(),title text,description text,status text,deadline timestamptz,image_url text,points integer,assignee_id uuid REFERENCES members,created_at timestamptz DEFAULT now(),updated_at timestamptz DEFAULT now());
 CREATE TABLE archived_tasks(LIKE tasks INCLUDING DEFAULTS INCLUDING CONSTRAINTS,done_completed_at timestamptz NOT NULL,done_completed_by uuid REFERENCES members,archived_at timestamptz NOT NULL DEFAULT now(),archived_reason text NOT NULL,PRIMARY KEY(id));
 CREATE TABLE profiles(id uuid,member_id uuid,access_token uuid);
 CREATE TABLE org_departments(id uuid,name text,deleted_at timestamptz);
 CREATE TABLE org_department_members(id uuid,user_id uuid,department_id uuid,deleted_at timestamptz);
 CREATE FUNCTION current_profile_token() RETURNS uuid LANGUAGE sql AS $$ SELECT null::uuid $$;
 CREATE FUNCTION current_member_id() RETURNS uuid LANGUAGE sql AS $$ SELECT auth.uid() $$;
 CREATE FUNCTION current_member_role() RETURNS text LANGUAGE sql AS $$ SELECT 'User'::text $$;
 GRANT ALL ON ALL TABLES IN SCHEMA public TO authenticated, anon;
 CREATE POLICY legacy_all ON members FOR ALL TO authenticated USING(true) WITH CHECK(true);
 CREATE POLICY legacy_all ON tasks FOR ALL TO authenticated USING(true) WITH CHECK(true);
 CREATE POLICY legacy_all ON archived_tasks FOR ALL TO authenticated USING(true) WITH CHECK(true);
 `);
 for(const [key,id] of Object.entries(ids)) {
  await db.query('INSERT INTO auth.users VALUES ($1,$2,now())',[id,`${key}@example.invalid`]);
  if(key==='outsider') continue;
  await db.query('INSERT INTO members(id,name,email,system_role) VALUES ($1,$2,$3,$4)',[id,key,`${key}@example.invalid`,key==='admin'?'Admin':key==='super'?'Super Admin':'User']);
 }
 for(const key of ['a','b']) {
  await db.query("INSERT INTO tasks(id,title,status,assignee_id,points) VALUES ($1,$2,'backlog',$1,10)",[ids[key],`${key} task`]);
  await db.query("INSERT INTO archived_tasks(id,title,status,assignee_id,points,done_completed_at,archived_reason) VALUES ($1,$2,'done',$1,5,now(),'legacy')",[ids[key],`${key} archived`]);
 }
 await migrate(db,'20261111172605_authenticated_self_profile.sql');
 await migrate(db,'20261113191954_admin_only_task_mutations.sql');
 await migrate(db,'20261113200143_portal_identity_privacy.sql');
 return db;
}
