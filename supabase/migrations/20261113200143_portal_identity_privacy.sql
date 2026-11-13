BEGIN;
-- Only this private mapping establishes community membership. Auth signup alone
-- does not grant membership, and later email changes never rebind an identity.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon;
GRANT USAGE ON SCHEMA private TO authenticated, service_role;
CREATE TABLE private.member_identities (
  auth_user_id uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  member_id uuid NOT NULL UNIQUE REFERENCES public.members(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);
ALTER TABLE private.member_identities ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.member_identities FROM PUBLIC, anon, authenticated;
DO $$ BEGIN
  IF EXISTS (SELECT lower(email) FROM public.members GROUP BY lower(email) HAVING count(*) > 1)
     OR EXISTS (SELECT lower(email) FROM auth.users WHERE email_confirmed_at IS NOT NULL GROUP BY lower(email) HAVING count(*) > 1)
  THEN RAISE EXCEPTION 'Ambiguous verified email mapping; reconcile identities before migration'; END IF;
END $$;
INSERT INTO private.member_identities(auth_user_id, member_id)
SELECT u.id, m.id FROM auth.users u JOIN public.members m ON lower(u.email) = lower(m.email)
WHERE u.email_confirmed_at IS NOT NULL;

CREATE OR REPLACE FUNCTION private.session_member_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
 SELECT m.id FROM private.member_identities i JOIN public.members m ON m.id = i.member_id
 WHERE i.auth_user_id = (SELECT auth.uid()) AND m.is_active IS TRUE
$$;
CREATE OR REPLACE FUNCTION private.session_member_role() RETURNS text
LANGUAGE sql STABLE SECURITY DEFINER SET search_path = pg_catalog AS $$
 SELECT m.system_role::text FROM private.member_identities i JOIN public.members m ON m.id = i.member_id
 WHERE i.auth_user_id = (SELECT auth.uid()) AND m.is_active IS TRUE
$$;
REVOKE ALL ON FUNCTION private.session_member_id(), private.session_member_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION private.session_member_id(), private.session_member_role() TO authenticated, service_role;
CREATE OR REPLACE FUNCTION public.current_member_id() RETURNS uuid
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = pg_catalog AS $$ SELECT private.session_member_id() $$;
CREATE OR REPLACE FUNCTION public.current_member_role() RETURNS text
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = pg_catalog AS $$ SELECT private.session_member_role() $$;
REVOKE ALL ON FUNCTION public.current_member_id(), public.current_member_role() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.current_member_id(), public.current_member_role() TO authenticated, service_role;

-- Provisioning is an explicit trusted-server operation, never a browser choice
-- of member ID. Existing bindings cannot be overwritten using this function.
CREATE FUNCTION public.link_verified_member(p_auth_user_id uuid, p_member_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY DEFINER SET search_path = pg_catalog AS $$
BEGIN
 IF NOT EXISTS (SELECT 1 FROM auth.users u JOIN public.members m ON lower(m.email)=lower(u.email)
   WHERE u.id=p_auth_user_id AND m.id=p_member_id AND u.email_confirmed_at IS NOT NULL)
 THEN RAISE EXCEPTION 'Verified member/account match required' USING ERRCODE='42501'; END IF;
 INSERT INTO private.member_identities(auth_user_id, member_id) VALUES (p_auth_user_id, p_member_id);
END $$;
REVOKE ALL ON FUNCTION public.link_verified_member(uuid,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.link_verified_member(uuid,uuid) TO service_role;

-- Restrictive policies also constrain legacy permissive policies, including ALL.
ALTER TABLE public.members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.tasks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.archived_tasks ENABLE ROW LEVEL SECURITY;
CREATE POLICY portal_member_read_guard ON public.members AS RESTRICTIVE FOR SELECT TO authenticated
 USING (id=(SELECT public.current_member_id()) OR (SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY portal_member_read ON public.members FOR SELECT TO authenticated
 USING (id=(SELECT public.current_member_id()) OR (SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY portal_task_read_guard ON public.tasks AS RESTRICTIVE FOR SELECT TO authenticated
 USING (assignee_id=(SELECT public.current_member_id()) OR (SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY portal_task_read ON public.tasks FOR SELECT TO authenticated
 USING (assignee_id=(SELECT public.current_member_id()) OR (SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY portal_archive_read_guard ON public.archived_tasks AS RESTRICTIVE FOR SELECT TO authenticated
 USING (assignee_id=(SELECT public.current_member_id()) OR (SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY portal_archive_read ON public.archived_tasks FOR SELECT TO authenticated
 USING (assignee_id=(SELECT public.current_member_id()) OR (SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY portal_archive_insert_guard ON public.archived_tasks AS RESTRICTIVE FOR INSERT TO authenticated
 WITH CHECK ((SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY portal_archive_update_guard ON public.archived_tasks AS RESTRICTIVE FOR UPDATE TO authenticated
 USING ((SELECT public.current_member_role()) IN ('Admin','Super Admin')) WITH CHECK ((SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY portal_archive_delete_guard ON public.archived_tasks AS RESTRICTIVE FOR DELETE TO authenticated
 USING ((SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY portal_archive_admin ON public.archived_tasks FOR ALL TO authenticated
 USING ((SELECT public.current_member_role()) IN ('Admin','Super Admin')) WITH CHECK ((SELECT public.current_member_role()) IN ('Admin','Super Admin'));
REVOKE ALL ON public.members, public.tasks, public.archived_tasks FROM PUBLIC, anon;
REVOKE TRUNCATE, REFERENCES, TRIGGER ON public.members, public.tasks, public.archived_tasks FROM authenticated;
DO $$ DECLARE t text; c text; BEGIN
 FOREACH t IN ARRAY ARRAY['members','tasks','archived_tasks'] LOOP
  FOR c IN SELECT column_name FROM information_schema.columns WHERE table_schema='public' AND table_name=t LOOP
   EXECUTE format('REVOKE ALL (%I) ON public.%I FROM PUBLIC, anon', c, t);
  END LOOP;
 END LOOP;
END $$;
GRANT SELECT ON public.members, public.tasks, public.archived_tasks TO authenticated;
CREATE FUNCTION public.get_current_member() RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path = pg_catalog AS $$
 SELECT to_jsonb(m) FROM public.members m WHERE m.id=(SELECT public.current_member_id())
$$;
REVOKE ALL ON FUNCTION public.get_current_member() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_current_member() TO authenticated;
COMMIT;
