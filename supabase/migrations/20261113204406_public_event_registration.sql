BEGIN;
CREATE TABLE public.public_event_pages (
 event_id uuid PRIMARY KEY REFERENCES public.events(id) ON DELETE RESTRICT,
 slug text NOT NULL UNIQUE CHECK(slug ~ '^[a-z0-9][a-z0-9-]{2,79}$'),
 title text NOT NULL CHECK(char_length(btrim(title)) BETWEEN 1 AND 200),
 summary text NOT NULL DEFAULT '' CHECK(char_length(summary)<=2000),
 location text NOT NULL DEFAULT '' CHECK(char_length(location)<=500),
 starts_at timestamptz NOT NULL, ends_at timestamptz NOT NULL CHECK(ends_at>starts_at),
 registration_closes_at timestamptz NOT NULL CHECK(registration_closes_at<=ends_at),
 capacity integer NOT NULL CHECK(capacity BETWEEN 1 AND 100000),
 state text NOT NULL DEFAULT 'draft' CHECK(state IN ('draft','open','closed','cancelled')),
 privacy_url text NOT NULL CHECK(public.valid_task_resource_url(privacy_url)),
 consent_version text NOT NULL CHECK(char_length(btrim(consent_version)) BETWEEN 1 AND 50),
 consent_text text NOT NULL CHECK(char_length(btrim(consent_text)) BETWEEN 1 AND 2000),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE TABLE public.event_registrations (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 event_id uuid NOT NULL REFERENCES public.public_event_pages(event_id) ON DELETE RESTRICT,
 auth_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 display_name text NOT NULL CHECK(char_length(btrim(display_name)) BETWEEN 2 AND 100),
 email text NOT NULL,
 state text NOT NULL DEFAULT 'confirmed' CHECK(state IN ('confirmed','cancelled')),
 consent_version text NOT NULL, consent_text text NOT NULL, privacy_url text NOT NULL,
 consented_at timestamptz NOT NULL DEFAULT now(), created_at timestamptz NOT NULL DEFAULT now(),
 UNIQUE(event_id,auth_user_id)
);
CREATE INDEX event_registrations_owner_idx ON public.event_registrations(auth_user_id,created_at DESC);
CREATE INDEX event_registrations_capacity_idx ON public.event_registrations(event_id) WHERE state='confirmed';
ALTER TABLE public.public_event_pages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_registrations ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.public_event_pages,public.event_registrations FROM PUBLIC,anon,authenticated;
GRANT SELECT ON public.public_event_pages TO anon,authenticated;
GRANT INSERT,UPDATE ON public.public_event_pages TO authenticated;
GRANT SELECT ON public.event_registrations TO authenticated;
CREATE POLICY public_event_visible ON public.public_event_pages FOR SELECT TO anon,authenticated USING(state<>'draft');
CREATE POLICY public_event_admin ON public.public_event_pages FOR ALL TO authenticated
 USING((SELECT public.current_member_role()) IN ('Admin','Super Admin')) WITH CHECK((SELECT public.current_member_role()) IN ('Admin','Super Admin'));
CREATE POLICY registration_owner_read ON public.event_registrations FOR SELECT TO authenticated USING(auth_user_id=(SELECT auth.uid()));
CREATE POLICY registration_admin_read ON public.event_registrations FOR SELECT TO authenticated USING((SELECT public.current_member_role()) IN ('Admin','Super Admin'));

CREATE TABLE private.portal_rate_limits (
 auth_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
 operation text NOT NULL, window_start timestamptz NOT NULL, requests integer NOT NULL,
 PRIMARY KEY(auth_user_id,operation)
);
ALTER TABLE private.portal_rate_limits ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.portal_rate_limits FROM PUBLIC,anon,authenticated;
CREATE FUNCTION private.allow_event_registration() RETURNS boolean
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE n integer;
BEGIN
 IF auth.uid() IS NULL THEN RETURN false; END IF;
 INSERT INTO private.portal_rate_limits AS r(auth_user_id,operation,window_start,requests)
 VALUES(auth.uid(),'event_registration',clock_timestamp(),1)
 ON CONFLICT(auth_user_id,operation) DO UPDATE SET
 requests=CASE WHEN r.window_start<clock_timestamp()-interval '10 minutes' THEN 1 ELSE r.requests+1 END,
 window_start=CASE WHEN r.window_start<clock_timestamp()-interval '10 minutes' THEN clock_timestamp() ELSE r.window_start END
 RETURNING requests INTO n;
 RETURN n<=10;
END $$;
REVOKE ALL ON FUNCTION private.allow_event_registration() FROM PUBLIC,anon,authenticated;

CREATE FUNCTION private.register_for_event(p_slug text,p_name text,p_consent_version text,p_accepted boolean,p_expected_user_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE page public.public_event_pages%ROWTYPE; registration public.event_registrations%ROWTYPE; verified_email text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Authentication required' USING ERRCODE='42501'; END IF;
 IF p_expected_user_id IS DISTINCT FROM auth.uid() THEN RETURN jsonb_build_object('status','session_changed'); END IF;
 SELECT email INTO verified_email FROM auth.users WHERE id=auth.uid() AND email_confirmed_at IS NOT NULL;
 IF verified_email IS NULL THEN RETURN jsonb_build_object('status','verification_required'); END IF;
 -- Return instead of raising: rejected requests must not roll the counter back.
 IF NOT private.allow_event_registration() THEN RETURN jsonb_build_object('status','rate_limited'); END IF;
 IF p_slug IS NULL OR p_slug !~ '^[a-z0-9][a-z0-9-]{2,79}$' OR p_name IS NULL OR char_length(btrim(p_name)) NOT BETWEEN 2 AND 100
 THEN RETURN jsonb_build_object('status','invalid_input'); END IF;
 -- All admissions and later revocations lock this event before capacity checks.
 SELECT * INTO page FROM public.public_event_pages WHERE slug=p_slug FOR UPDATE;
 IF NOT FOUND OR page.state='draft' THEN RETURN jsonb_build_object('status','not_found'); END IF;
 IF page.state='cancelled' THEN RETURN jsonb_build_object('status','cancelled'); END IF;
 SELECT * INTO registration FROM public.event_registrations WHERE event_id=page.event_id AND auth_user_id=auth.uid();
 IF FOUND THEN RETURN jsonb_build_object('status',CASE WHEN registration.state='confirmed' THEN 'already_registered' ELSE 'registration_cancelled' END,'registration_id',registration.id); END IF;
 IF page.state<>'open' OR page.registration_closes_at<=clock_timestamp() OR page.ends_at<=clock_timestamp() THEN RETURN jsonb_build_object('status','closed'); END IF;
 IF p_accepted IS DISTINCT FROM true OR p_consent_version IS DISTINCT FROM page.consent_version THEN RETURN jsonb_build_object('status','consent_required'); END IF;
 IF (SELECT count(*) FROM public.event_registrations WHERE event_id=page.event_id AND state='confirmed')>=page.capacity THEN RETURN jsonb_build_object('status','full'); END IF;
 INSERT INTO public.event_registrations(event_id,auth_user_id,display_name,email,consent_version,consent_text,privacy_url)
 VALUES(page.event_id,auth.uid(),btrim(p_name),verified_email,page.consent_version,page.consent_text,page.privacy_url) RETURNING * INTO registration;
 RETURN jsonb_build_object('status','registered','registration_id',registration.id);
END $$;
REVOKE ALL ON FUNCTION private.register_for_event(text,text,text,boolean,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION private.register_for_event(text,text,text,boolean,uuid) TO authenticated;
CREATE FUNCTION public.register_for_event(p_slug text,p_name text,p_consent_version text,p_accepted boolean,p_expected_user_id uuid) RETURNS jsonb
LANGUAGE sql SECURITY INVOKER SET search_path=pg_catalog AS $$ SELECT private.register_for_event(p_slug,p_name,p_consent_version,p_accepted,p_expected_user_id) $$;
REVOKE ALL ON FUNCTION public.register_for_event(text,text,text,boolean,uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.register_for_event(text,text,text,boolean,uuid) TO authenticated;

CREATE FUNCTION public.guard_public_event_page() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN
 IF TG_OP='UPDATE' THEN
  IF NEW.event_id IS DISTINCT FROM OLD.event_id OR NEW.slug IS DISTINCT FROM OLD.slug THEN RAISE EXCEPTION 'Published event identity cannot change'; END IF;
  IF NEW.capacity<(SELECT count(*) FROM public.event_registrations WHERE event_id=OLD.event_id AND state='confirmed') THEN RAISE EXCEPTION 'Capacity cannot be below confirmed registrations'; END IF;
 END IF;
 NEW.updated_at:=statement_timestamp();RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_public_event_page() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_public_event_page BEFORE INSERT OR UPDATE ON public.public_event_pages FOR EACH ROW EXECUTE FUNCTION public.guard_public_event_page();
COMMIT;
