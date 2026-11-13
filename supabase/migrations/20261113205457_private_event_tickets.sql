BEGIN;
CREATE TABLE public.event_tickets (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 registration_id uuid NOT NULL UNIQUE REFERENCES public.event_registrations(id) ON DELETE CASCADE,
 reference uuid NOT NULL UNIQUE DEFAULT gen_random_uuid(),
 state text NOT NULL DEFAULT 'valid' CHECK(state IN ('valid','checked_in','revoked')),
 created_at timestamptz NOT NULL DEFAULT now(),
 checked_in_at timestamptz, checked_in_by uuid REFERENCES public.members(id) ON DELETE SET NULL,
 revoked_at timestamptz, revoked_by uuid REFERENCES public.members(id) ON DELETE SET NULL
);
ALTER TABLE public.event_tickets ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.event_tickets FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.event_tickets TO authenticated;
CREATE POLICY ticket_owner_read ON public.event_tickets FOR SELECT TO authenticated
 USING(EXISTS(SELECT 1 FROM public.event_registrations r WHERE r.id=registration_id AND r.auth_user_id=(SELECT auth.uid())));
CREATE POLICY ticket_admin_read ON public.event_tickets FOR SELECT TO authenticated
 USING((SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE FUNCTION private.issue_event_ticket() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN
 INSERT INTO public.event_tickets(registration_id) VALUES(NEW.id);
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION private.issue_event_ticket() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER issue_event_ticket AFTER INSERT ON public.event_registrations FOR EACH ROW EXECUTE FUNCTION private.issue_event_ticket();
INSERT INTO public.event_tickets(registration_id,state)
 SELECT id,CASE WHEN state='confirmed' THEN 'valid' ELSE 'revoked' END FROM public.event_registrations
 ON CONFLICT(registration_id) DO NOTHING;

CREATE FUNCTION public.get_my_tickets() RETURNS jsonb LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT coalesce(jsonb_agg(jsonb_build_object(
 'id',t.id,'reference',t.reference,'state',t.state,'checked_in_at',t.checked_in_at,
 'event_id',r.event_id,'registration_state',r.state,'title',coalesce(p.title,'Etkinlik'),
 'event_state',coalesce(p.state,'unavailable'),'starts_at',p.starts_at,'ends_at',p.ends_at,'location',p.location
 ) ORDER BY t.created_at DESC,t.id),'[]'::jsonb)
 FROM public.event_tickets t JOIN public.event_registrations r ON r.id=t.registration_id
 LEFT JOIN public.public_event_pages p ON p.event_id=r.event_id
 WHERE r.auth_user_id=(SELECT auth.uid())
$$;
REVOKE ALL ON FUNCTION public.get_my_tickets() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_tickets() TO authenticated;

CREATE FUNCTION private.check_in_event_ticket(p_event_id uuid,p_reference uuid,p_expected_user_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE actor uuid; page public.public_event_pages%ROWTYPE; ticket public.event_tickets%ROWTYPE; registration public.event_registrations%ROWTYPE;
BEGIN
 actor:=public.current_member_id();
 IF auth.uid() IS NULL OR p_expected_user_id IS DISTINCT FROM auth.uid() OR actor IS NULL THEN RAISE EXCEPTION 'Authorized operator required' USING ERRCODE='42501'; END IF;
 IF coalesce(public.current_member_role(),'') NOT IN ('Admin','Super Admin')
 AND NOT EXISTS(SELECT 1 FROM public.event_staff WHERE event_id=p_event_id AND member_id=actor)
 THEN RAISE EXCEPTION 'Event operator required' USING ERRCODE='42501'; END IF;
 SELECT * INTO page FROM public.public_event_pages WHERE event_id=p_event_id FOR UPDATE;
 IF NOT FOUND OR page.state IN ('draft','cancelled') THEN RETURN jsonb_build_object('status','event_unavailable'); END IF;
 SELECT t.* INTO ticket FROM public.event_tickets t JOIN public.event_registrations r ON r.id=t.registration_id
 WHERE t.reference=p_reference AND r.event_id=p_event_id FOR UPDATE OF t;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','invalid_ticket'); END IF;
 SELECT * INTO registration FROM public.event_registrations WHERE id=ticket.registration_id;
 IF registration.auth_user_id=auth.uid() THEN RETURN jsonb_build_object('status','self_checkin_forbidden'); END IF;
 IF ticket.state='revoked' OR registration.state<>'confirmed' THEN RETURN jsonb_build_object('status','revoked'); END IF;
 IF ticket.state='checked_in' THEN RETURN jsonb_build_object('status','already_checked_in','checked_in_at',ticket.checked_in_at,'name',registration.display_name); END IF;
 IF clock_timestamp()<page.starts_at-interval '4 hours' THEN RETURN jsonb_build_object('status','not_open'); END IF;
 IF clock_timestamp()>page.ends_at THEN RETURN jsonb_build_object('status','ended'); END IF;
 UPDATE public.event_tickets SET state='checked_in',checked_in_at=statement_timestamp(),checked_in_by=actor WHERE id=ticket.id;
 RETURN jsonb_build_object('status','checked_in','name',registration.display_name);
END $$;
REVOKE ALL ON FUNCTION private.check_in_event_ticket(uuid,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.check_in_event_ticket(uuid,uuid,uuid) TO authenticated;
CREATE FUNCTION public.check_in_event_ticket(p_event_id uuid,p_reference uuid,p_expected_user_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT private.check_in_event_ticket(p_event_id,p_reference,p_expected_user_id) $$;
REVOKE ALL ON FUNCTION public.check_in_event_ticket(uuid,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.check_in_event_ticket(uuid,uuid,uuid) TO authenticated;

CREATE FUNCTION private.revoke_event_ticket(p_event_id uuid,p_reference uuid,p_expected_user_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE ticket public.event_tickets%ROWTYPE;
BEGIN
 IF auth.uid() IS NULL OR p_expected_user_id IS DISTINCT FROM auth.uid() OR coalesce(public.current_member_role(),'') NOT IN ('Admin','Super Admin')
 THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
 -- Same lock order as admission and scan; cancellation releases capacity atomically.
 PERFORM 1 FROM public.public_event_pages WHERE event_id=p_event_id FOR UPDATE;
 SELECT t.* INTO ticket FROM public.event_tickets t JOIN public.event_registrations r ON r.id=t.registration_id WHERE t.reference=p_reference AND r.event_id=p_event_id FOR UPDATE OF t;
 IF NOT FOUND THEN RETURN jsonb_build_object('status','invalid_ticket'); END IF;
 IF ticket.state='revoked' THEN RETURN jsonb_build_object('status','already_revoked'); END IF;
 UPDATE public.event_tickets SET state='revoked',revoked_at=statement_timestamp(),revoked_by=public.current_member_id() WHERE id=ticket.id;
 UPDATE public.event_registrations SET state='cancelled' WHERE id=ticket.registration_id;
 RETURN jsonb_build_object('status','revoked');
END $$;
REVOKE ALL ON FUNCTION private.revoke_event_ticket(uuid,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.revoke_event_ticket(uuid,uuid,uuid) TO authenticated;
CREATE FUNCTION public.revoke_event_ticket(p_event_id uuid,p_reference uuid,p_expected_user_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT private.revoke_event_ticket(p_event_id,p_reference,p_expected_user_id) $$;
REVOKE ALL ON FUNCTION public.revoke_event_ticket(uuid,uuid,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.revoke_event_ticket(uuid,uuid,uuid) TO authenticated;
COMMIT;
