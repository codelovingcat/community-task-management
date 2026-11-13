# Task management write access

Issue #76: member tasks are read-only. Management task controls require Admin or
Super Admin; RLS enforces this independently of the UI. Legacy permissive task
write policies cannot override the restrictive guards. Task reads are unchanged;
private score/identity work is tracked in #79.

Apply `20261113191954_admin_only_task_mutations.sql` only after the existing
registered-member helper/core RLS migrations, and verify current role mapping,
trigger/RPC EXECUTE grants and schema in an isolated compatible database first.
The migration revokes TRUNCATE/REFERENCES/TRIGGER and anonymous write grants.
It does not change mail queues, providers or privileged backend workers.
Historical core migration already revokes public execution of definer RPCs;
review target-specific RPCs for alternate write paths before release.

Merge does not apply SQL. Production rollout/real JWT and API verification is
tracked in #86. No production database changes were made in this PR.

Validation: `node --test tests/core-rls-integration.test.mjs tests/task-delete-ui.test.mjs`.
These use synthetic PostgreSQL identities and component fixtures, not a live
Supabase Auth session.
