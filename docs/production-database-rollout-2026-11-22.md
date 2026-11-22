# Production database rollout — 2026-11-22

The user explicitly approved the eleven-migration Task Manager candidate.
All eleven were applied successfully to project `vbokappwelyrvoxnkigp` from the
reviewed source files. The earlier approval rejection is resolved for this rollout.
No baseline/reset script or email-worker/provider change was applied.

## Applied versions

| Repository file | Hosted version |
| --- | --- |
| 20261103000000_restrict_member_helper_execution.sql | 20261122194215 |
| 20261111150204_restrict_private_community_reads.sql | 20261122194714 |
| 20261111172605_authenticated_self_profile.sql | 20261122194826 |
| 20261111195910_restrict_notification_table_privileges.sql | 20261122194840 |
| 20261112185658_restrict_core_non_rls_privileges.sql | 20261122194847 |
| 20261113191954_admin_only_task_mutations.sql | 20261122195148 |
| 20261113200143_portal_identity_privacy.sql | 20261122195207 |
| 20261113200634_task_completion_scores.sql | 20261122195349 |
| 20261113201104_member_private_notes.sql | 20261122195356 |
| 20261113204406_public_event_registration.sql | 20261122195405 |
| 20261113205457_private_event_tickets.sql | 20261122195412 |

Hosted timestamps differ from filenames because the migration tool records the
actual application time. The rollout manifest records both names and hashes;
do not repair history or replay these migrations based on timestamp differences.

## Verified on the hosted database

- All 16 required portal relations/functions/columns exist.
- All seven private-community gate rows pass: RLS enabled, anonymous reads denied,
  unsafe browser grants removed and reviewed policy sets installed.
- PostgreSQL authenticated Admin role created, read, updated and deleted a
  synthetic member; exactly one welcome job was queued without a worker.
  The transaction was rolled back. Subsequent checks found zero smoke members,
  zero smoke settings and zero smoke welcome jobs.
- Admin `get_my_profile()` and `get_current_member()` return successfully.
- An unregistered authenticated identity sees zero rows in eleven internal tables,
  no profile/current-member record and cannot insert/update/delete settings.
  Anonymous reads of the seven private tables are denied.
- All three real members remain. Two have verified Auth UUID bindings, including
  one active Super Admin. The third has no matching Auth account; its member row
  is retained, and access requires verified account provisioning. No identity was
  invented and no account was automatically verified.

These checks used database-role/JWT-claim simulation by an authorized operator,
not real end-user Auth tokens. Deployed PostgREST/browser sign-in, separate-origin
portal login, expiry/reuse and concurrent registration/check-in remain #86.

## Remaining deployment work

PRs #97–#99 were merged by the user. #3's database rollout is complete. #4 still
requires verifying the deployed frontend against the intended fork and testing
real authenticated browser/API CRUD. Its closure from merging #99 does not prove
those checks; keep/reopen it until they pass. The last inspected Vercel production
metadata points to DevCodexa/main `c1c544a`; this database rollout did not change
Vercel, Auth callback/SMTP settings or send real email. #26 remains delivery work.

## Advisor comparison

The two public client-executable SECURITY DEFINER identity-helper warnings are
resolved. Backend-only tables, the private identity/rate-limit tables and the
retired token-profile table intentionally have no client policies. They remain
denied by grants/RLS; do not add permissive policies to silence the informational
[RLS notice](https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy).
The pre-existing [pg_trgm schema warning](https://supabase.com/docs/guides/database/database-linter?lint=0014_extension_in_public)
and [leaked-password protection setting](https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection)
are unchanged by this approved schema scope.

