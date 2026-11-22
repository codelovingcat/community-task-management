-- Authorized operator smoke test. Run in staging first.
-- Synthetic row, notifications and queued welcome job stay uncommitted and are
-- rolled back. Never run fragments separately or change ROLLBACK to COMMIT.
-- This tests PostgreSQL authenticated-role access, not Supabase JWT verification.
BEGIN;
SET LOCAL statement_timeout='10s';
DO $setup$
DECLARE selected_user uuid;
BEGIN
 SELECT i.auth_user_id INTO selected_user
 FROM private.member_identities i JOIN public.members m ON m.id=i.member_id
 WHERE m.is_active AND m.system_role::text IN ('Admin','Super Admin')
 ORDER BY m.id LIMIT 1;
 IF selected_user IS NULL THEN RAISE EXCEPTION 'An active mapped admin is required'; END IF;
 PERFORM set_config('request.jwt.claims',jsonb_build_object('sub',selected_user,'role','authenticated')::text,true);
 PERFORM set_config('ctm.smoke_member',gen_random_uuid()::text,true);
END $setup$;
SET LOCAL ROLE authenticated;
DO $crud$
DECLARE fixture uuid := current_setting('ctm.smoke_member')::uuid; affected integer;
BEGIN
 IF public.current_member_role() NOT IN ('Admin','Super Admin') THEN RAISE EXCEPTION 'Admin context failed'; END IF;
 INSERT INTO public.members(id,name,email,birth_day,birth_month,system_role)
 VALUES(fixture,'Database smoke fixture',fixture::text||'@example.invalid',1,1,'User');
 IF NOT EXISTS(SELECT 1 FROM public.members WHERE id=fixture) THEN RAISE EXCEPTION 'Read after create failed'; END IF;
 UPDATE public.members SET name='Updated smoke fixture' WHERE id=fixture;
 GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 THEN RAISE EXCEPTION 'Update failed'; END IF;
 DELETE FROM public.members WHERE id=fixture;
 GET DIAGNOSTICS affected=ROW_COUNT;
 IF affected<>1 OR EXISTS(SELECT 1 FROM public.members WHERE id=fixture) THEN RAISE EXCEPTION 'Delete failed'; END IF;
END $crud$;
RESET ROLE;
DO $queue$
BEGIN
 IF (SELECT count(*) FROM public.email_queue WHERE recipient_email=current_setting('ctm.smoke_member')||'@example.invalid'
  AND template_code='welcome_member' AND status::text='pending')<>1 THEN
  RAISE EXCEPTION 'Expected exactly one queued welcome job, without a running worker';
 END IF;
END $queue$;
ROLLBACK;
