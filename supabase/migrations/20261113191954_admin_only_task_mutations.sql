-- Member portal tasks are read-only. Admins manage tasks in Task Manager.
-- Prerequisites: registered-member helpers and core task RLS migrations.
BEGIN;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.tasks FROM PUBLIC, anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.tasks FROM authenticated;
DO $columns$
DECLARE c text;
BEGIN
  FOR c IN SELECT attname FROM pg_attribute WHERE attrelid = 'public.tasks'::regclass
    AND attnum > 0 AND NOT attisdropped
  LOOP
    EXECUTE format('REVOKE INSERT (%I), UPDATE (%I), REFERENCES (%I) ON public.tasks FROM PUBLIC, anon', c, c, c);
    EXECUTE format('REVOKE REFERENCES (%I) ON public.tasks FROM authenticated', c);
  END LOOP;
END;
$columns$;

-- Restrictive guards AND with every permissive policy, including legacy ALL
-- policies. Keep SELECT unchanged for the separately reviewed privacy work.
DROP POLICY IF EXISTS tasks_admin_write_guard_insert ON public.tasks;
CREATE POLICY tasks_admin_write_guard_insert ON public.tasks AS RESTRICTIVE
  FOR INSERT TO authenticated WITH CHECK (
    (SELECT public.current_member_id()) IS NOT NULL AND
    (SELECT public.current_member_role()) IN ('Admin', 'Super Admin'));
DROP POLICY IF EXISTS tasks_admin_write_guard_update ON public.tasks;
CREATE POLICY tasks_admin_write_guard_update ON public.tasks AS RESTRICTIVE
  FOR UPDATE TO authenticated USING (
    (SELECT public.current_member_id()) IS NOT NULL AND
    (SELECT public.current_member_role()) IN ('Admin', 'Super Admin'))
  WITH CHECK ((SELECT public.current_member_id()) IS NOT NULL AND
    (SELECT public.current_member_role()) IN ('Admin', 'Super Admin'));
DROP POLICY IF EXISTS tasks_admin_write_guard_delete ON public.tasks;
CREATE POLICY tasks_admin_write_guard_delete ON public.tasks AS RESTRICTIVE
  FOR DELETE TO authenticated USING (
    (SELECT public.current_member_id()) IS NOT NULL AND
    (SELECT public.current_member_role()) IN ('Admin', 'Super Admin'));

DROP POLICY IF EXISTS tasks_insert_admin_or_self ON public.tasks;
DROP POLICY IF EXISTS tasks_update_admin_or_assignee ON public.tasks;
DROP POLICY IF EXISTS tasks_delete_admin_or_assignee ON public.tasks;
DROP POLICY IF EXISTS tasks_admin_insert ON public.tasks;
DROP POLICY IF EXISTS tasks_admin_update ON public.tasks;
DROP POLICY IF EXISTS tasks_admin_delete ON public.tasks;
CREATE POLICY tasks_admin_insert ON public.tasks FOR INSERT TO authenticated
  WITH CHECK ((SELECT public.current_member_role()) IN ('Admin', 'Super Admin'));
CREATE POLICY tasks_admin_update ON public.tasks FOR UPDATE TO authenticated
  USING ((SELECT public.current_member_role()) IN ('Admin', 'Super Admin'))
  WITH CHECK ((SELECT public.current_member_role()) IN ('Admin', 'Super Admin'));
CREATE POLICY tasks_admin_delete ON public.tasks FOR DELETE TO authenticated
  USING ((SELECT public.current_member_role()) IN ('Admin', 'Super Admin'));
COMMIT;
