-- Disposable tests only. No real account or email delivery.
INSERT INTO auth.users(id,email,email_confirmed_at)
VALUES('10000000-0000-4000-8000-000000000001','admin@example.invalid',now());
INSERT INTO public.members(id,name,email,birth_day,birth_month,system_role)
VALUES('10000000-0000-4000-8000-000000000001','Fixture admin','admin@example.invalid',1,1,'Admin');
SELECT public.link_verified_member('10000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001');
