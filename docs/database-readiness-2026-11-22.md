# Task Manager readiness and member CRUD (#4)

## Verified facts

- Fork main is `ac80e5b049722e60719de41a4e397a8d36a25265`; #94–#96 merged.
- Task Manager database project is `vbokappwelyrvoxnkigp`. Its migration history
  still stops at the October changes. All 16 portal objects/columns checked by
  `supabase/audits/application_schema_readiness.sql` are missing, including
  `get_my_profile()` and `get_current_member()`. Deploying newer UI alone will
  fail profile loading until the matching schema is deployed.
- Existing `members` and the active `welcome_member` and `task_assigned` templates
  are present. Member creation directly inserts into `members`; its database
  trigger queues a welcome job. It does not call a running worker or provider.
  A missing welcome template would fail the queue FK and roll back member creation;
  the new baseline supplies disabled references to avoid that fresh-install gap.
- Read-only identity audit: three members, two verified Auth email matches,
  including one active Super Admin. Resolve the unmatched account through verified
  provisioning; do not fabricate an Auth identity or let public signup create a
  community member. Later internal members need the documented trusted
  `link_verified_member` provisioning step; creating a member is not an Auth signup.
- The public `/api/health` route at oriontechcommunity.vercel.app returns available
  with Auth reachable. It explicitly does **not** check Data API/database CRUD.
- Vercel production deployment `dpl_BzUr63fSLt2bRiRRinquKfpEPJLj` is READY, but its
  metadata says `DevCodexa/community-task-management`, main commit
  `c1c544a89abcb375a5b25f429c4768e1145a9699`, source `redeploy`. This does not verify
  deployment of the user's fork/main. Review the project Git connection and deploy
  the intended fork commit in preview before switching production. No Vercel
  configuration or production deployment was changed here.

## Concrete rollout candidate

`supabase/rollout/task-manager.json` lists eleven already-merged, mail-independent
application migrations, their hashes, intended project and reviewed source commit.
It covers private community/notification grants, profile/identity, admin-only task
writes, completion/scores, private notes, public registration and tickets.
It does not include email claims, templates, birthday producer or worker upgrades.

The exact list is tested against the full legacy schema, with an existing verified
Admin preserved and linked by migration. It is a reviewed candidate, **not applied**.
Automatic approval review rejected the attempted seven-table policy migration as
an unauthorized production access-control change. Explicit approval is required
before applying this broader, enumerated candidate; review backup/recovery and
fresh target drift first. Do not rerun baseline SQL, repair history blindly, change
provider configuration or enable sending as part of this rollout.

## Verification and completion gate

`node --test tests/member-full-schema.test.mjs` proves authenticated Admin member
create/read/update/delete with the actual tables, FKs, RLS and triggers, without a
worker. `supabase/tests/member_crud_rollback.sql` asserts one pending welcome job;
ROLLBACK discards the synthetic member, jobs and notifications. CI also executes
this SQL on PostgreSQL 17. No real mail is sent. SQL-role impersonation in an
isolated test does not prove hosted JWT verification or PostgREST behavior.

After approved migration rollout and correct preview deployment, run both schema
and private-community audit queries, then verify real admin/member/external sessions
and CRUD in the preview connected to the intended project. The rollback SQL can
be used by an authorized database operator after inspecting target triggers for
external side effects; do not run its fragments separately or commit its transaction.
Record deployed commit, target, migration versions and sanitized result codes.
Keep #4 open until actual deployed connectivity and authenticated CRUD pass.
#86 remains the full portal/Auth/browser release gate; #26 is mail delivery.
