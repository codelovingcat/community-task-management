-- Operator-only, read-only catalog probe. Contains no user records or keys.
-- Existence is necessary, not sufficient: follow with role and CRUD smoke tests.
WITH required_relations(name) AS (
 VALUES ('private.member_identities'),('public.member_notes'),
 ('public.public_event_pages'),('public.event_registrations'),('public.event_tickets')
), required_functions(name) AS (
 VALUES ('public.get_my_profile()'),('public.get_current_member()'),
 ('public.get_member_scores()'),('public.get_my_tickets()'),
 ('public.register_for_event(text,text,text,boolean,uuid)'),
 ('public.check_in_event_ticket(uuid,uuid,uuid)'),('public.revoke_event_ticket(uuid,uuid,uuid)')
), required_columns(table_name,column_name) AS (
 VALUES ('tasks','completed_at'),('tasks','resource_url'),
 ('archived_tasks','completed_at'),('archived_tasks','resource_url')
)
SELECT 'relation' AS kind,name, to_regclass(name) IS NOT NULL AS present FROM required_relations
UNION ALL
SELECT 'function',name,to_regprocedure(name) IS NOT NULL FROM required_functions
UNION ALL
SELECT 'column',table_name||'.'||column_name,EXISTS(
 SELECT 1 FROM information_schema.columns c WHERE c.table_schema='public'
 AND c.table_name=r.table_name AND c.column_name=r.column_name)
FROM required_columns r ORDER BY kind,name;
