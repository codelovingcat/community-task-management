-- Read-only deployment gate. No personal data, writes, role changes or grants.
-- Policy behavior is separately tested against the complete schema in CI.
WITH expected(name) AS (
 SELECT unnest(ARRAY['announcements','announcement_members','events','event_staff',
 'event_speakers','community_settings','menu_items'])
), checks AS (
 SELECT e.name,
 coalesce(c.relrowsecurity,false) AS rls_enabled,
 coalesce(NOT has_any_column_privilege('anon',c.oid,'SELECT')
  AND NOT has_table_privilege('anon',c.oid,'INSERT,UPDATE,DELETE,TRUNCATE,REFERENCES,TRIGGER'),false) AS anonymous_denied,
 coalesce(NOT has_table_privilege('authenticated',c.oid,'TRUNCATE,REFERENCES,TRIGGER'),false) AS unsafe_grants_absent,
 (SELECT count(*)=2 AND bool_and(
  p.policyname=e.name||'_admin_manage' OR
  p.policyname=e.name||CASE WHEN e.name='announcement_members' THEN '_read_own_or_admin' ELSE '_read_registered_member' END)
  FROM pg_policies p WHERE p.schemaname='public' AND p.tablename=e.name) AS reviewed_policy_set
 FROM expected e LEFT JOIN pg_class c ON c.oid=to_regclass('public.'||e.name)
)
SELECT name,rls_enabled,anonymous_denied,unsafe_grants_absent,reviewed_policy_set,
 rls_enabled AND anonymous_denied AND unsafe_grants_absent AND reviewed_policy_set AS ready
FROM checks ORDER BY name;
