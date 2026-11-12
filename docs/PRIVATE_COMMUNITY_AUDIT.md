# Private community access audit

`supabase/audits/private_community_access.sql` is a read-only metadata query
for the seven tables in issue #3. An authorized operator can execute it in the
SQL editor of the intended project before and after a reviewed deployment.
It reports missing tables, RLS, anonymous table and column SELECT privileges,
unneeded browser-role table privileges and policy definitions. It does not
read member data, modify grants, or apply migrations. SQL editor history may
retain the query, but the query contains no secrets.

Missing tables, disabled RLS, anonymous access or authenticated TRUNCATE,
TRIGGER or REFERENCES should be investigated. RLS does not restrict TRUNCATE.
The output is evidence for review, not a complete security verdict: inspect
policy expressions and role memberships, and test allowed and denied requests
with real sessions in an isolated Supabase project. Verify the target and
existing schema before deploying migrations. Merge does not apply SQL.

Run `node --test tests/private-community-audit.test.mjs` after installing the
lockfile dependencies. The test uses only synthetic PGlite data and does not
verify any deployed database or Supabase Auth behavior.
