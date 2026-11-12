-- Read-only inspection of issue #3. Run as an authorized operator on the
-- intended project; output is schema metadata only, never table rows.
WITH expected(name) AS (
  SELECT unnest(ARRAY['announcements', 'announcement_members', 'events',
    'event_staff', 'event_speakers', 'community_settings', 'menu_items'])
)
SELECT expected.name AS table_name,
  c.oid IS NOT NULL AS table_exists,
  c.relrowsecurity AS rls_enabled,
  has_table_privilege('anon', c.oid, 'SELECT') AS anon_select,
  has_any_column_privilege('anon', c.oid, 'SELECT') AS anon_any_column_select,
  has_table_privilege('anon', c.oid, 'INSERT') AS anon_insert,
  has_table_privilege('authenticated', c.oid, 'TRUNCATE') AS authenticated_truncate,
  has_table_privilege('authenticated', c.oid, 'TRIGGER') AS authenticated_trigger,
  has_table_privilege('authenticated', c.oid, 'REFERENCES') AS authenticated_references,
  COALESCE((SELECT jsonb_agg(jsonb_build_object(
    'name', p.policyname, 'command', p.cmd, 'roles', p.roles,
    'using', p.qual, 'check', p.with_check) ORDER BY p.policyname)
    FROM pg_policies p WHERE p.schemaname = 'public' AND p.tablename = expected.name), '[]'::jsonb) AS policies
FROM expected
LEFT JOIN pg_namespace n ON n.nspname = 'public'
LEFT JOIN pg_class c ON c.relnamespace = n.oid AND c.relname = expected.name AND c.relkind IN ('r', 'p')
ORDER BY expected.name;
