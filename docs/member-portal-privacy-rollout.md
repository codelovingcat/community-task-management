# Member portal identity and privacy (#79)

The portal remains an independently built application in `apps/member-portal`.
Both applications share Supabase Auth/Postgres; only an immutable Auth UUID to
member UUID binding grants community access. Email is only a verified initial
migration/provisioning match, never a request-time authorization credential.

Apply the committed migrations in timestamp order in staging first, including
`authenticated_self_profile` and `admin_only_task_mutations`. Production has not
been migrated by this PR. Deploying frontend alone is insufficient.

## Before rollout

- Reconcile case-insensitive duplicate emails; migration deliberately aborts.
- Audit verified matches and unmatched members with privileged SQL. Read-only
  audit on 2026-11-13 found 3 members, 2 verified matches. No identities or emails
  are recorded in this document. Ensure at least one active Super Admin matches.
- Resolve unmatched accounts by verifying account ownership, then calling
  `link_verified_member(auth_user_id, member_id)` from a trusted service-role
  backend/operator. It requires the same verified email and refuses replacement
  bindings. Use it for later internal-member onboarding too. Browser clients
  cannot call it. Auth signups/external attendees do not become members.
- Do not expose the `private` schema in the Data API. Its tables have no client
  grants; the only authenticated helper functions accept no identity parameters.
- Audit public views/materialized views and client-executable SECURITY DEFINER
  functions. At inspection there were no public views and the only such definer
  functions callable by clients were the two identity helpers (now invokers).
  Re-audit custom objects before production to avoid a separately granted bypass.

```sql
select schemaname, viewname from pg_views where schemaname='public';
select schemaname, matviewname from pg_matviews where schemaname='public';
select p.oid::regprocedure from pg_proc p join pg_namespace n on n.oid=p.pronamespace
where n.nspname='public' and p.prosecdef and p.prokind='f'
and (has_function_privilege('anon',p.oid,'EXECUTE')
  or has_function_privilege('authenticated',p.oid,'EXECUTE'));
```

## Acceptance on real authenticated sessions (#86 deployment gate)

Use member A, member B, Admin, Super Admin, an unregistered Auth account and anon.
For each test get_my_profile/get_current_member, direct members/tasks/archived_tasks
SELECT, points columns, embedded joins and existing dashboard/statistics RPCs.
Members see their own records; admins retain management visibility; inactive or
unmapped accounts see no community rows. Spoofing email claims/URL IDs must not
change ownership. Members cannot mutate tasks or archive rows. Test admin CRUD
and existing organizational pages, whose member joins now respect privacy.

PGlite regression tests exercise actual PostgreSQL roles, policies and functions,
including deliberately permissive legacy policies. They are not a substitute
for these real Auth/PostgREST deployment checks. Issue #86 remains that gate.

This PR also carries #90's dashboard commits into main: #90 was merged into the
previous feature branch after that branch's earlier merge into main.
