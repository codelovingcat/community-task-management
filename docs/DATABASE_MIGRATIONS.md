# Database migrations and historical SQL

## Fresh installation and upgrades

`supabase/bootstrap/schema.sql` is the reviewed schema-only compatibility snapshot
of the existing application through the October migrations. It contains tables,
enums, sequences, constraints, indexes, functions, triggers, RLS and grants, but
no users, members, event data, provider credentials or jobs. `reference-data.sql`
adds disabled template references and `enabled=false`; installing the application
does not enable email delivery. Templates must be configured before enabling mail.

The supported empty-database recipe (an isolated Supabase project with its Auth
schema and roles already initialized) is:

```sh
npm ci
node scripts/database-plan.mjs --fresh > /tmp/community-fresh.sql
psql -X -v ON_ERROR_STOP=1 -f /tmp/community-fresh.sql
```

Use the normal protected PostgreSQL connection environment/credential mechanism;
do not paste credentials into commands or source. The generated SQL runs the
baseline, reference rows and all later migrations in **one transaction**, then
records the equivalent local versions in Supabase migration history. Re-running
it refuses an existing public application schema before changing anything.
Do not use it on production or run the bootstrap SQL by itself. It is not a reset
script. `supabase db reset` alone is not supported: the older migration files
remain in place for existing deployments and expect the baseline tables.

`supabase/bootstrap/manifest.json` freezes the covered files and their SHA-256
hashes. Later migrations are read in filename order. Historical files are not
rewritten or replayed: some create policies without DROP and cannot run twice.
Existing projects must retain their actual migration history and review pending
SQL individually; this fresh-install recipe does not repair remote history.

The actual project's historical timestamps differ from local filenames. The
following is the read-only reconciliation, **not** an instruction to mark versions
applied just because names resemble each other:

| Hosted version | Equivalent local version / snapshot coverage |
| --- | --- |
| 20261025212928 | 20261026000100 core RLS |
| 20261026193555 | Intermediate authenticated-member hardening, captured by snapshot |
| 20261026202349 | 20261026000000 email backend-only access |
| 20261026202447 | 20261026001000 trigger search paths |
| 20261026202558 | 20261026002000 remaining anonymous policies |
| 20261026202700 | 20261026003000 public grants |
| 20261026202807 | 20261026004000 member/task/org RLS |
| 20261026205209 | 20261026005000 queue logs |
| 20261026210012 | 20261026006000 birthday deduplication |
| 20261026210408 | 20261026007000 delivered birthdays |
| 20261026210546 | 20261026008000 birthday backfill |
| 20261026210649 | 20261026009000 stale birthday cancellation |
| 20261026210756 | 20261026100000 deleted notification actor |
| 20261027200856 | Same local version, unassigned leaders |

For upgrades, inspect target policies/functions/grants and pending files, verify
identity mappings and a working active Super Admin, and keep a recovery backup.
Generate future migrations using `supabase migration new` after checking CLI
help. Apply reviewed migrations once in order, then test with real application
roles. Do not run the bootstrap, historical `database/` files or blindly repair
history on an existing database. Mail-related upgrades require #26 coordination.

A fresh installation has no administrator. A trusted database operator must
create the first verified Auth account and corresponding member, using a narrowly
scoped transaction to disable only `trg_guard_member_role_change` during the first
Super Admin insert, then immediately re-enable it and call `link_verified_member`
from a privileged backend. Do this before exposing the application. Browser users
cannot provision themselves as members or administrators.

## Verification

`node --test tests/database-baseline.test.mjs` runs the complete schema with the
actual PostgreSQL engine in PGlite, clean-install refusal on rerun, and an upgrade
that preserves an existing synthetic member. CI repeats fresh installation on
PostgreSQL 17 with a minimal Auth test fixture. The fixture is test-only; it is
not a replacement for Supabase Auth and does not validate hosted JWT/PostgREST.
Actual Auth, SMTP and deployment checks remain #86 and #26.

## Historical `database/` inventory

| Files | Status and caution |
| --- | --- |
| `email_system.sql` | Obsolete historical email setup, intentionally aborts within a transaction. Do not remove the guard or run individual fragments: the old functions and triggers can overwrite later fixes. |
| `enqueue_birthday_emails_and_birthday_personal + birthday_team.sql`, `setup_email_queue.sql` | Conflicting historical email/queue implementations. The latter includes a placeholder processor which can mark messages sent without delivery. Do not apply. |
| `drop_email_enqueue_trigger_functions_project_department_area.sql`, `drop_triggers_project_department_area_member_emails.sql`, `recreate_enqueue_triggers_project_department_area_member_emails.sql` | Historical trigger manipulation; can remove or restore outdated behavior. Do not apply as a migration sequence. |
| `events-fixed.sql`, `events-full-reset.sql`, `events-simple-final.sql` | Destructive alternative resets, including table drops. Never run on an existing environment. |
| `events.sql`, `events-teams-areas-v1.sql`, `events-project-members.sql`, `events-department-members.sql`, `events-security-fix.sql` | Historical event and organization alternatives/fixes; not a verified baseline. The reviewed versioned policies govern current access. |
| `archive_tasks.sql`, `clear_done_tasks_archive_candidates.sql`, `reset_archive_tasks.sql` | Historical archive setup or cleanup/reset operations. Review effects and data loss independently; not part of automatic setup. |
| `org-departments-rls-fix.sql`, `speakers-rls-fix.sql` | Historical/manual policy fixes. May conflict with later versioned policies; do not blindly reapply. |
| `30-community-settings.sql`, `announcements.sql`, `members.sql`, `notifications.sql`, `profiles.sql`, `speakers.sql`, `tasks.sql`, `useful_links.sql` | Historical feature setup. May overlap the current schema and policies; not a tested ordered baseline. |

## Email settings and secrets

The historical email setup no longer embeds an unexpanded shell expression or
creates the old anonymous policies. Its guarded reference seed would leave the
provider key null, sender details empty and email disabled for newly inserted
settings, while preserving existing settings on repeat. This does **not**
configure a database: the file intentionally fails before making changes.

The current worker reads provider configuration from the backend-only
`email_settings` table; see `email-worker/README.md` and `docs/OPERATIONS.md`.
Provision credentials through the environment's approved secret-handling process
and a privileged server-side operator; never commit a key, interpolate it into
SQL, put it in browser variables, paste it into shared SQL history, or print it
in logs. Keep sending disabled until the key, sender, access grants and worker
coordination have been reviewed. Do not assume these reference changes repair
permissions in an already running database.

## Local regression checks

After `npm ci`, run:

```sh
node --test supabase/tests/legacy-email-setup.test.mjs
```

These tests use an in-memory PostgreSQL-compatible PGlite instance and synthetic
settings and roles. They verify the historical script aborts, reference settings
preserve existing values, and the reference access block removes its known
anonymous policies and grants on rerun. They do not test a complete Supabase
schema, deployed RLS, Auth, migration order, or actual email delivery.

The fresh-install chain and snapshot upgrade are tested automatically. Hosted
migration application and real Auth/browser verification remain separate rollout
steps; a git merge does not apply SQL.
