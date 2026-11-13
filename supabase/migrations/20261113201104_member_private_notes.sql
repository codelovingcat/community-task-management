BEGIN;
CREATE TABLE public.member_notes (
 id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
 owner_id uuid NOT NULL DEFAULT public.current_member_id() REFERENCES public.members(id) ON DELETE CASCADE,
 title text NOT NULL CHECK (char_length(btrim(title)) BETWEEN 1 AND 120),
 body text NOT NULL DEFAULT '' CHECK (char_length(body)<=4000),
 priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('low','normal','high')),
 created_at timestamptz NOT NULL DEFAULT now(),
 updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX member_notes_owner_updated_idx ON public.member_notes(owner_id,updated_at DESC,id);
ALTER TABLE public.member_notes ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.member_notes FROM PUBLIC,anon,authenticated;
GRANT SELECT,DELETE ON public.member_notes TO authenticated;
GRANT INSERT(owner_id,title,body,priority), UPDATE(title,body,priority) ON public.member_notes TO authenticated;
-- No admin exception: personal notes are private to their owner.
CREATE POLICY member_notes_owner_guard ON public.member_notes AS RESTRICTIVE FOR ALL TO authenticated
 USING (owner_id=(SELECT public.current_member_id())) WITH CHECK (owner_id=(SELECT public.current_member_id()));
CREATE POLICY member_notes_owner ON public.member_notes FOR ALL TO authenticated
 USING (owner_id=(SELECT public.current_member_id())) WITH CHECK (owner_id=(SELECT public.current_member_id()));
CREATE FUNCTION public.guard_member_note() RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path=pg_catalog AS $$
BEGIN
 IF TG_OP='UPDATE' THEN
  IF NEW.owner_id IS DISTINCT FROM OLD.owner_id OR NEW.id IS DISTINCT FROM OLD.id OR NEW.created_at IS DISTINCT FROM OLD.created_at
  THEN RAISE EXCEPTION 'Note identity and owner cannot change' USING ERRCODE='42501'; END IF;
  NEW.updated_at:=statement_timestamp();
 ELSE NEW.created_at:=statement_timestamp(); NEW.updated_at:=NEW.created_at;
 END IF;
 RETURN NEW;
END $$;
REVOKE ALL ON FUNCTION public.guard_member_note() FROM PUBLIC,anon,authenticated;
CREATE TRIGGER guard_member_note BEFORE INSERT OR UPDATE ON public.member_notes FOR EACH ROW EXECUTE FUNCTION public.guard_member_note();
COMMIT;
