BEGIN;
ALTER TABLE public.tasks ADD COLUMN completed_at timestamptz, ADD COLUMN resource_url text;
ALTER TABLE public.archived_tasks ADD COLUMN completed_at timestamptz, ADD COLUMN resource_url text;
-- Old done_completed_at was based on updated_at, so it is not evidence of completion.
-- Keep legacy values for audit only; new code reads completed_at (unknown = NULL).
ALTER TABLE public.archived_tasks ALTER COLUMN done_completed_at DROP NOT NULL;
CREATE FUNCTION public.valid_task_resource_url(value text) RETURNS boolean
LANGUAGE sql IMMUTABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT value IS NULL OR (length(value)<=2048 AND value ~ '^https://[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?(:[0-9]{1,5})?([/?#][^[:space:][:cntrl:]\\]*)?$')
$$;
REVOKE ALL ON FUNCTION public.valid_task_resource_url(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.valid_task_resource_url(text) TO authenticated, service_role;
ALTER TABLE public.tasks ADD CONSTRAINT tasks_resource_url_check CHECK (public.valid_task_resource_url(resource_url));
ALTER TABLE public.archived_tasks ADD CONSTRAINT archive_resource_url_check CHECK (public.valid_task_resource_url(resource_url));
CREATE FUNCTION public.record_task_completion() RETURNS trigger
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE archived public.archived_tasks%ROWTYPE;
BEGIN
 IF TG_OP='UPDATE' AND OLD.status::text IN ('completed','done') THEN
  IF NEW.assignee_id IS DISTINCT FROM OLD.assignee_id THEN
   RAISE EXCEPTION 'Tamamlanan görevi yeniden atamadan önce ayrı bir işlemle yeniden açın';
  END IF;
  IF NEW.status::text IN ('completed','done') THEN NEW.completed_at:=OLD.completed_at;
  ELSE NEW.completed_at:=NULL; END IF;
 ELSIF NEW.status::text IN ('completed','done') THEN
  NEW.completed_at:=statement_timestamp();
  IF TG_OP='INSERT' THEN
   SELECT * INTO archived FROM public.archived_tasks WHERE id=NEW.id FOR UPDATE;
   IF FOUND THEN
    IF NEW.assignee_id IS DISTINCT FROM archived.assignee_id OR NEW.points IS DISTINCT FROM archived.points
      OR NEW.status::text IS DISTINCT FROM archived.status::text
    THEN RAISE EXCEPTION 'Restore must preserve archived assignment, points and status'; END IF;
    NEW.completed_at:=archived.completed_at;
   END IF;
  END IF;
 ELSE NEW.completed_at:=NULL;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.record_task_completion() FROM PUBLIC, anon, authenticated;
CREATE TRIGGER record_task_completion BEFORE INSERT OR UPDATE ON public.tasks
 FOR EACH ROW EXECUTE FUNCTION public.record_task_completion();

-- A single transaction moves the record. Conflict or failed delete rolls back.
CREATE OR REPLACE FUNCTION public.archive_single_task(p_task_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE t public.tasks%ROWTYPE;
BEGIN
 IF (SELECT public.current_member_role()) IS NULL OR (SELECT public.current_member_role()) NOT IN ('Admin','Super Admin')
 THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.tasks WHERE id=p_task_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Task not found'; END IF;
 IF t.status::text NOT IN ('completed','done') THEN RAISE EXCEPTION 'Only completed tasks can be archived'; END IF;
 INSERT INTO public.archived_tasks(id,title,description,deadline,image_url,points,assignee_id,status,created_at,updated_at,completed_at,resource_url,done_completed_at,done_completed_by,archived_at,archived_reason)
 VALUES(t.id,t.title,t.description,t.deadline,t.image_url,t.points,t.assignee_id,t.status,t.created_at,t.updated_at,t.completed_at,t.resource_url,t.completed_at,public.current_member_id(),now(),'manual_done');
 DELETE FROM public.tasks WHERE id=p_task_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Task could not be removed'; END IF;
END $$;
CREATE FUNCTION public.restore_archived_task(task_id uuid) RETURNS void
LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
DECLARE t public.archived_tasks%ROWTYPE;
BEGIN
 IF (SELECT public.current_member_role()) IS NULL OR (SELECT public.current_member_role()) NOT IN ('Admin','Super Admin')
 THEN RAISE EXCEPTION 'Admin required' USING ERRCODE='42501'; END IF;
 SELECT * INTO t FROM public.archived_tasks WHERE id=task_id FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Archive not found'; END IF;
 INSERT INTO public.tasks(id,title,description,deadline,image_url,points,assignee_id,status,created_at,updated_at,completed_at,resource_url)
 VALUES(t.id,t.title,t.description,t.deadline,t.image_url,t.points,t.assignee_id,t.status,t.created_at,now(),t.completed_at,t.resource_url);
 DELETE FROM public.archived_tasks WHERE id=task_id;
 IF NOT FOUND THEN RAISE EXCEPTION 'Archive could not be removed'; END IF;
END $$;
REVOKE ALL ON FUNCTION public.archive_single_task(uuid),public.restore_archived_task(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.archive_single_task(uuid),public.restore_archived_task(uuid) TO authenticated;
CREATE OR REPLACE FUNCTION public.archive_done_tasks_older_than_7_days() RETURNS integer
LANGUAGE plpgsql SECURITY DEFINER SET search_path=pg_catalog AS $$
DECLARE t public.tasks%ROWTYPE; moved integer:=0;
BEGIN
 FOR t IN SELECT * FROM public.tasks WHERE status::text='done' AND completed_at<now()-interval '7 days' FOR UPDATE SKIP LOCKED LOOP
  INSERT INTO public.archived_tasks(id,title,description,deadline,image_url,points,assignee_id,status,created_at,updated_at,completed_at,resource_url,done_completed_at,done_completed_by,archived_at,archived_reason)
  VALUES(t.id,t.title,t.description,t.deadline,t.image_url,t.points,t.assignee_id,t.status,t.created_at,t.updated_at,t.completed_at,t.resource_url,t.completed_at,NULL,now(),'done_7_days');
  DELETE FROM public.tasks WHERE id=t.id;
  moved:=moved+1;
 END LOOP;
 RETURN moved;
END $$;
REVOKE ALL ON FUNCTION public.archive_done_tasks_older_than_7_days() FROM PUBLIC,anon,authenticated;
GRANT EXECUTE ON FUNCTION public.archive_done_tasks_older_than_7_days() TO service_role;

-- Invoker functions keep table RLS effective; no SECURITY DEFINER score bypass.
CREATE FUNCTION public.get_member_scores() RETURNS TABLE(member_id uuid,member_name text,total_points bigint,completed_tasks bigint)
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 WITH records AS (
  SELECT id,assignee_id,status::text,points FROM public.tasks
  UNION ALL SELECT a.id,a.assignee_id,a.status::text,a.points FROM public.archived_tasks a
   WHERE NOT EXISTS(SELECT 1 FROM public.tasks t WHERE t.id=a.id)
 ) SELECT m.id,m.name,coalesce(sum(r.points) FILTER(WHERE r.status IN ('completed','done')),0)::bigint,
 count(r.id) FILTER(WHERE r.status IN ('completed','done'))
 FROM public.members m LEFT JOIN records r ON r.assignee_id=m.id GROUP BY m.id,m.name ORDER BY m.name,m.id
$$;
REVOKE ALL ON FUNCTION public.get_member_scores() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_member_scores() TO authenticated;
CREATE OR REPLACE FUNCTION public.get_my_profile() RETURNS jsonb
LANGUAGE sql STABLE SECURITY INVOKER SET search_path=pg_catalog AS $$
 SELECT jsonb_build_object(
  'member',jsonb_build_object('id',m.id,'name',m.name,'email',m.email,'phone',m.phone,'company',m.company,'job_title',m.job_title,'comm_title',m.comm_title,'avatar',m.avatar,'bio',m.bio),
  'score',coalesce((SELECT total_points FROM public.get_member_scores() s WHERE s.member_id=m.id),0),
  'tasks',coalesce((SELECT jsonb_agg(jsonb_build_object('id',t.id,'title',t.title,'description',t.description,'status',t.status,'deadline',t.deadline,'completed_at',t.completed_at,'resource_url',t.resource_url,'points',t.points,'archived',t.archived) ORDER BY t.created_at DESC,t.id)
   FROM (SELECT id,title,description,status,deadline,completed_at,resource_url,points,created_at,false AS archived FROM public.tasks WHERE assignee_id=m.id
    UNION ALL SELECT a.id,a.title,a.description,a.status,a.deadline,a.completed_at,a.resource_url,a.points,a.created_at,true FROM public.archived_tasks a WHERE a.assignee_id=m.id AND NOT EXISTS(SELECT 1 FROM public.tasks t WHERE t.id=a.id)) t),'[]'::jsonb),
  'org_department_members',coalesce((SELECT jsonb_agg(jsonb_build_object('id',dm.id,'department',jsonb_build_object('id',d.id,'name',d.name)) ORDER BY d.name) FROM public.org_department_members dm JOIN public.org_departments d ON d.id=dm.department_id WHERE dm.user_id=m.id AND dm.deleted_at IS NULL AND d.deleted_at IS NULL),'[]'::jsonb)
 ) FROM public.members m WHERE m.id=(SELECT public.current_member_id())
$$;
REVOKE ALL ON FUNCTION public.get_my_profile() FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;
CREATE INDEX IF NOT EXISTS tasks_assignee_completion_idx ON public.tasks(assignee_id,status);
CREATE INDEX IF NOT EXISTS archived_tasks_assignee_idx ON public.archived_tasks(assignee_id);
COMMIT;
