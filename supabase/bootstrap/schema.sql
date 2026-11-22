-- Schema-only compatibility baseline, inspected 2026-11-22. No production rows or secrets.
-- Fresh database only. Use scripts/database-plan.mjs; never apply this to a populated project.
SET check_function_bodies = false;
SET search_path = public, extensions;
DO $guard$ BEGIN
 IF to_regclass('public.members') IS NOT NULL OR EXISTS(SELECT 1 FROM pg_tables WHERE schemaname='public') THEN
  RAISE EXCEPTION 'Fresh-install baseline refuses an existing public application schema';
 END IF;
 IF to_regclass('auth.users') IS NULL THEN RAISE EXCEPTION 'Supabase Auth schema is required'; END IF;
END $guard$;
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE TYPE public."area_member_role_enum" AS ENUM ('LEADER','TEAM_MEMBER');
CREATE TYPE public."departments_member_role_enum" AS ENUM ('LEADER','TEAM_MEMBER');
CREATE TYPE public."email_priority_enum" AS ENUM ('low','medium','high');
CREATE TYPE public."email_queue_status_enum" AS ENUM ('pending','sent','failed');
CREATE TYPE public."event_type_enum" AS ENUM ('Workshop','Face-to-Face','Bootcamp','Webinar','Quiz Night','Mülakat Yayını','Coffee Talk','İlk Konuşmam(Future)','Other');
CREATE TYPE public."link_target_type_enum" AS ENUM ('sub_team','project');
CREATE TYPE public."notification_type_enum" AS ENUM ('task_added','task_completed','task_deleted','member_added','member_removed','member_updated','birthday');
CREATE TYPE public."project_member_role_enum" AS ENUM ('LEADER','TEAM_MEMBER');
CREATE TYPE public."speaker_status" AS ENUM ('green','red','neutral');
CREATE TYPE public."system_role_enum" AS ENUM ('Super Admin','Admin','User');
CREATE TYPE public."task_status_enum" AS ENUM ('backlog','started','in_progress','completed','done');
CREATE TYPE public."team_member_role_enum" AS ENUM ('lead','member');
CREATE SEQUENCE public."email_settings_id_seq" START 1 INCREMENT 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;
CREATE SEQUENCE public."birthday_notifications_id_seq" START 1 INCREMENT 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;
CREATE SEQUENCE public."email_send_logs_id_seq" START 1 INCREMENT 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;
CREATE SEQUENCE public."email_queue_id_seq" START 1 INCREMENT 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;
CREATE SEQUENCE public."email_templates_id_seq" START 1 INCREMENT 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;
CREATE SEQUENCE public."manual_emails_id_seq" START 1 INCREMENT 1 MINVALUE 1 MAXVALUE 9223372036854775807 CACHE 1;
CREATE TABLE public."members" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "name" text NOT NULL,
 "email" text NOT NULL,
 "phone" text DEFAULT ''::text,
 "company" text DEFAULT ''::text,
 "job_title" text DEFAULT ''::text,
 "comm_title" text DEFAULT ''::text,
 "bio" text DEFAULT ''::text,
 "birth_day" integer NOT NULL,
 "birth_month" integer NOT NULL,
 "system_role" system_role_enum DEFAULT 'User'::system_role_enum NOT NULL,
 "avatar" text DEFAULT ''::text,
 "active_tasks" integer DEFAULT 0 NOT NULL,
 "total_tasks" integer DEFAULT 3 NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "is_active" boolean DEFAULT true NOT NULL
);
CREATE TABLE public."tasks" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "title" text NOT NULL,
 "description" text DEFAULT ''::text,
 "deadline" timestamp with time zone,
 "image_url" text DEFAULT ''::text,
 "points" integer DEFAULT 1,
 "assignee_id" uuid,
 "status" task_status_enum DEFAULT 'backlog'::task_status_enum NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."useful_links" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "title" text NOT NULL,
 "url" text NOT NULL,
 "description" text DEFAULT ''::text,
 "category_name" text NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."org_departments" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "name" text NOT NULL,
 "description" text,
 "responsible_person_id" uuid,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "deleted_at" timestamp with time zone
);
CREATE TABLE public."org_areas" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "department_id" uuid NOT NULL,
 "name" text NOT NULL,
 "description" text,
 "area_leader_id" uuid,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "deleted_at" timestamp with time zone
);
CREATE TABLE public."org_department_members" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "department_id" uuid NOT NULL,
 "user_id" uuid NOT NULL,
 "role" departments_member_role_enum DEFAULT 'TEAM_MEMBER'::departments_member_role_enum NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "deleted_at" timestamp with time zone
);
CREATE TABLE public."announcements" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "title" text NOT NULL,
 "description" text DEFAULT ''::text NOT NULL,
 "link" text DEFAULT ''::text,
 "type" event_type_enum DEFAULT 'Other'::event_type_enum NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."announcement_members" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "announcement_id" uuid NOT NULL,
 "member_id" uuid NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."events" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "title" text NOT NULL,
 "description" text DEFAULT ''::text,
 "event_type" event_type_enum DEFAULT 'Other'::event_type_enum NOT NULL,
 "start_date" timestamp with time zone NOT NULL,
 "end_date" timestamp with time zone NOT NULL,
 "drive_link" text DEFAULT ''::text,
 "location" text DEFAULT ''::text,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."event_staff" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "event_id" uuid NOT NULL,
 "member_id" uuid NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."event_speakers" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "event_id" uuid NOT NULL,
 "speaker_id" uuid NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."notifications" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "title" text NOT NULL,
 "message" text NOT NULL,
 "type" notification_type_enum DEFAULT 'task_added'::notification_type_enum NOT NULL,
 "is_read" boolean DEFAULT false NOT NULL,
 "related_id" uuid,
 "related_type" text,
 "user_id" uuid,
 "actor_id" uuid,
 "actor_name" text,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "read_at" timestamp with time zone,
 "dedupe_key" text
);
CREATE TABLE public."speakers" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "full_name" text NOT NULL,
 "company" text DEFAULT ''::text,
 "email" text,
 "phone" text,
 "image_url" text DEFAULT ''::text,
 "title" text DEFAULT ''::text,
 "description" text DEFAULT ''::text,
 "status" speaker_status DEFAULT 'neutral'::speaker_status NOT NULL,
 "added_by" uuid,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."org_area_members" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "area_id" uuid NOT NULL,
 "user_id" uuid NOT NULL,
 "role" area_member_role_enum DEFAULT 'TEAM_MEMBER'::area_member_role_enum NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "deleted_at" timestamp with time zone
);
CREATE TABLE public."org_projects" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "area_id" uuid NOT NULL,
 "name" text NOT NULL,
 "description" text,
 "file_url" text,
 "external_url" text,
 "start_date" date,
 "end_date" date,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "deleted_at" timestamp with time zone
);
CREATE TABLE public."org_project_members" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "project_id" uuid NOT NULL,
 "user_id" uuid NOT NULL,
 "role" project_member_role_enum DEFAULT 'TEAM_MEMBER'::project_member_role_enum NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "deleted_at" timestamp with time zone
);
CREATE TABLE public."profiles" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "member_id" uuid NOT NULL,
 "access_token" uuid NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."member_areas" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "profile_id" uuid NOT NULL,
 "area_name" text NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."member_announcements" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "profile_id" uuid NOT NULL,
 "announcement_title" text NOT NULL,
 "announcement_body" text DEFAULT ''::text,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."member_attachments" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "profile_id" uuid NOT NULL,
 "attachment_name" text NOT NULL,
 "attachment_url" text NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."community_settings" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "logo_url" text DEFAULT ''::text,
 "app_name" text DEFAULT 'Topluluk'::text,
 "app_subtitle" text DEFAULT 'Görev Yönetimi'::text,
 "dashboard_title" text DEFAULT 'Dashboard'::text,
 "dashboard_subtitle" text DEFAULT 'Topluluk görev yönetimine genel bakış'::text,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."menu_items" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "label" text NOT NULL,
 "path" text NOT NULL,
 "is_active" boolean DEFAULT true NOT NULL,
 "icon_key" text DEFAULT 'layout_dashboard'::text NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."birthday_email_deliveries" (
 "queue_id" bigint NOT NULL,
 "birthday_person_id" uuid NOT NULL,
 "notification_year" integer NOT NULL,
 "channel" text NOT NULL,
 "delivered_at" timestamp with time zone DEFAULT now() NOT NULL
);
CREATE TABLE public."archived_tasks" (
 "id" uuid NOT NULL,
 "title" text NOT NULL,
 "description" text DEFAULT ''::text,
 "deadline" timestamp with time zone,
 "image_url" text DEFAULT ''::text,
 "points" integer DEFAULT 1,
 "assignee_id" uuid,
 "status" task_status_enum NOT NULL,
 "done_completed_at" timestamp with time zone NOT NULL,
 "done_completed_by" uuid,
 "archived_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "archived_reason" text DEFAULT 'done_7_days'::text NOT NULL,
 "created_at" timestamp with time zone NOT NULL,
 "updated_at" timestamp with time zone NOT NULL
);
CREATE TABLE public."birthday_notifications" (
 "id" bigint DEFAULT nextval('birthday_notifications_id_seq'::regclass) NOT NULL,
 "birthday_person_id" uuid NOT NULL,
 "notification_year" integer NOT NULL,
 "personal_mail_sent" boolean DEFAULT false NOT NULL,
 "team_mails_sent_count" integer DEFAULT 0 NOT NULL,
 "sent_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."email_settings" (
 "id" bigint DEFAULT nextval('email_settings_id_seq'::regclass) NOT NULL,
 "setting_key" character varying(100) NOT NULL,
 "setting_value" text,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."email_templates" (
 "id" bigint DEFAULT nextval('email_templates_id_seq'::regclass) NOT NULL,
 "template_name" character varying(100) NOT NULL,
 "template_code" character varying(50) NOT NULL,
 "brevo_template_id" integer,
 "subject" character varying(200) NOT NULL,
 "html_content" text NOT NULL,
 "is_active" boolean DEFAULT true NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."speaker_email_queue" (
 "id" uuid DEFAULT gen_random_uuid() NOT NULL,
 "speaker_id" uuid NOT NULL,
 "email_type" text DEFAULT 'welcome'::text NOT NULL,
 "status" text DEFAULT 'pending'::text NOT NULL,
 "error_message" text,
 "retry_count" integer DEFAULT 0 NOT NULL,
 "scheduled_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "sent_at" timestamp with time zone,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
CREATE TABLE public."email_send_logs" (
 "id" bigint DEFAULT nextval('email_send_logs_id_seq'::regclass) NOT NULL,
 "queue_id" bigint,
 "recipient_email" character varying(255) NOT NULL,
 "template_code" character varying(50) NOT NULL,
 "event_type" character varying(50) DEFAULT 'sent'::character varying NOT NULL,
 "event_data" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "speaker_queue_id" uuid
);
CREATE TABLE public."email_queue" (
 "id" bigint DEFAULT nextval('email_queue_id_seq'::regclass) NOT NULL,
 "recipient_email" character varying(255) NOT NULL,
 "recipient_name" character varying(255),
 "template_code" character varying(50) NOT NULL,
 "template_params" jsonb DEFAULT '{}'::jsonb NOT NULL,
 "priority" email_priority_enum DEFAULT 'medium'::email_priority_enum NOT NULL,
 "status" email_queue_status_enum DEFAULT 'pending'::email_queue_status_enum NOT NULL,
 "attempt_count" integer DEFAULT 0 NOT NULL,
 "last_attempt_at" timestamp with time zone,
 "sent_at" timestamp with time zone,
 "error_message" text,
 "brevo_message_id" character varying(255),
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "updated_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "cc_emails" jsonb DEFAULT '[]'::jsonb,
 "next_attempt_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
 "idempotency_key" text
);
CREATE TABLE public."manual_emails" (
 "id" bigint DEFAULT nextval('manual_emails_id_seq'::regclass) NOT NULL,
 "sender_name" character varying(255) DEFAULT 'Orion Tech Community'::character varying NOT NULL,
 "sender_email" character varying(255) NOT NULL,
 "to_emails" jsonb DEFAULT '[]'::jsonb NOT NULL,
 "cc_emails" jsonb DEFAULT '[]'::jsonb NOT NULL,
 "subject" character varying(500) NOT NULL,
 "html_content" text NOT NULL,
 "status" email_queue_status_enum DEFAULT 'pending'::email_queue_status_enum NOT NULL,
 "brevo_message_ids" jsonb DEFAULT '[]'::jsonb NOT NULL,
 "error_message" text,
 "sent_by" character varying(255),
 "sent_at" timestamp with time zone,
 "created_at" timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);
ALTER TABLE public."announcement_members" ADD CONSTRAINT "announcement_members_pkey" PRIMARY KEY (id);
ALTER TABLE public."announcement_members" ADD CONSTRAINT "uq_announcement_member" UNIQUE (announcement_id, member_id);
ALTER TABLE public."announcements" ADD CONSTRAINT "announcements_description_check" CHECK ((length(description) <= 5000));
ALTER TABLE public."announcements" ADD CONSTRAINT "announcements_pkey" PRIMARY KEY (id);
ALTER TABLE public."announcements" ADD CONSTRAINT "announcements_title_check" CHECK (((length(title) >= 2) AND (length(title) <= 200)));
ALTER TABLE public."announcements" ADD CONSTRAINT "chk_announcements_link_valid" CHECK (((link = ''::text) OR (link IS NULL) OR (link ~* '^https?://.+'::text)));
ALTER TABLE public."archived_tasks" ADD CONSTRAINT "archived_tasks_pkey" PRIMARY KEY (id);
ALTER TABLE public."birthday_email_deliveries" ADD CONSTRAINT "birthday_email_deliveries_channel_check" CHECK ((channel = ANY (ARRAY['personal'::text, 'team'::text])));
ALTER TABLE public."birthday_email_deliveries" ADD CONSTRAINT "birthday_email_deliveries_pkey" PRIMARY KEY (queue_id);
ALTER TABLE public."birthday_notifications" ADD CONSTRAINT "birthday_notifications_birthday_person_id_notification_year_key" UNIQUE (birthday_person_id, notification_year);
ALTER TABLE public."birthday_notifications" ADD CONSTRAINT "birthday_notifications_pkey" PRIMARY KEY (id);
ALTER TABLE public."community_settings" ADD CONSTRAINT "chk_community_settings_logo_url_valid" CHECK (((logo_url = ''::text) OR (logo_url IS NULL) OR (logo_url ~* '^https?://.+'::text)));
ALTER TABLE public."community_settings" ADD CONSTRAINT "community_settings_pkey" PRIMARY KEY (id);
ALTER TABLE public."email_queue" ADD CONSTRAINT "email_queue_pkey" PRIMARY KEY (id);
ALTER TABLE public."email_send_logs" ADD CONSTRAINT "email_send_logs_exactly_one_queue_ref" CHECK ((num_nonnulls(queue_id, speaker_queue_id) = 1));
ALTER TABLE public."email_send_logs" ADD CONSTRAINT "email_send_logs_pkey" PRIMARY KEY (id);
ALTER TABLE public."email_settings" ADD CONSTRAINT "email_settings_pkey" PRIMARY KEY (id);
ALTER TABLE public."email_settings" ADD CONSTRAINT "email_settings_setting_key_key" UNIQUE (setting_key);
ALTER TABLE public."email_templates" ADD CONSTRAINT "email_templates_pkey" PRIMARY KEY (id);
ALTER TABLE public."email_templates" ADD CONSTRAINT "email_templates_template_code_key" UNIQUE (template_code);
ALTER TABLE public."event_speakers" ADD CONSTRAINT "event_speakers_pkey" PRIMARY KEY (id);
ALTER TABLE public."event_speakers" ADD CONSTRAINT "uq_event_speaker" UNIQUE (event_id, speaker_id);
ALTER TABLE public."event_staff" ADD CONSTRAINT "event_staff_pkey" PRIMARY KEY (id);
ALTER TABLE public."event_staff" ADD CONSTRAINT "uq_event_member" UNIQUE (event_id, member_id);
ALTER TABLE public."events" ADD CONSTRAINT "chk_dates" CHECK ((end_date > start_date));
ALTER TABLE public."events" ADD CONSTRAINT "events_pkey" PRIMARY KEY (id);
ALTER TABLE public."events" ADD CONSTRAINT "events_title_check" CHECK (((length(title) >= 2) AND (length(title) <= 200)));
ALTER TABLE public."manual_emails" ADD CONSTRAINT "manual_emails_pkey" PRIMARY KEY (id);
ALTER TABLE public."member_announcements" ADD CONSTRAINT "member_announcements_pkey" PRIMARY KEY (id);
ALTER TABLE public."member_announcements" ADD CONSTRAINT "uq_member_announcements" UNIQUE (profile_id, announcement_title);
ALTER TABLE public."member_areas" ADD CONSTRAINT "member_areas_pkey" PRIMARY KEY (id);
ALTER TABLE public."member_areas" ADD CONSTRAINT "uq_member_areas" UNIQUE (profile_id, area_name);
ALTER TABLE public."member_attachments" ADD CONSTRAINT "member_attachments_pkey" PRIMARY KEY (id);
ALTER TABLE public."member_attachments" ADD CONSTRAINT "uq_member_attachments" UNIQUE (profile_id, attachment_name);
ALTER TABLE public."members" ADD CONSTRAINT "members_active_tasks_check" CHECK ((active_tasks >= 0));
ALTER TABLE public."members" ADD CONSTRAINT "members_birth_day_check" CHECK (((birth_day >= 1) AND (birth_day <= 31)));
ALTER TABLE public."members" ADD CONSTRAINT "members_birth_month_check" CHECK (((birth_month >= 1) AND (birth_month <= 12)));
ALTER TABLE public."members" ADD CONSTRAINT "members_email_key" UNIQUE (email);
ALTER TABLE public."members" ADD CONSTRAINT "members_pkey" PRIMARY KEY (id);
ALTER TABLE public."members" ADD CONSTRAINT "members_total_tasks_check" CHECK (((total_tasks >= 0) AND (total_tasks <= 3)));
ALTER TABLE public."menu_items" ADD CONSTRAINT "menu_items_icon_key_check" CHECK ((length(icon_key) <= 80));
ALTER TABLE public."menu_items" ADD CONSTRAINT "menu_items_label_check" CHECK (((length(label) >= 1) AND (length(label) <= 80)));
ALTER TABLE public."menu_items" ADD CONSTRAINT "menu_items_path_check" CHECK (((length(path) >= 1) AND (length(path) <= 200)));
ALTER TABLE public."menu_items" ADD CONSTRAINT "menu_items_pkey" PRIMARY KEY (id);
ALTER TABLE public."notifications" ADD CONSTRAINT "notifications_pkey" PRIMARY KEY (id);
ALTER TABLE public."org_area_members" ADD CONSTRAINT "org_area_members_pkey" PRIMARY KEY (id);
ALTER TABLE public."org_areas" ADD CONSTRAINT "org_areas_pkey" PRIMARY KEY (id);
ALTER TABLE public."org_department_members" ADD CONSTRAINT "org_department_members_pkey" PRIMARY KEY (id);
ALTER TABLE public."org_departments" ADD CONSTRAINT "org_departments_pkey" PRIMARY KEY (id);
ALTER TABLE public."org_project_members" ADD CONSTRAINT "org_project_members_pkey" PRIMARY KEY (id);
ALTER TABLE public."org_project_members" ADD CONSTRAINT "uq_org_project_members_project_user" UNIQUE (project_id, user_id);
ALTER TABLE public."org_projects" ADD CONSTRAINT "chk_org_projects_dates" CHECK (((end_date IS NULL) OR (start_date IS NULL) OR (end_date >= start_date)));
ALTER TABLE public."org_projects" ADD CONSTRAINT "org_projects_pkey" PRIMARY KEY (id);
ALTER TABLE public."profiles" ADD CONSTRAINT "profiles_access_token_key" UNIQUE (access_token);
ALTER TABLE public."profiles" ADD CONSTRAINT "profiles_member_id_key" UNIQUE (member_id);
ALTER TABLE public."profiles" ADD CONSTRAINT "profiles_pkey" PRIMARY KEY (id);
ALTER TABLE public."speaker_email_queue" ADD CONSTRAINT "speaker_email_queue_pkey" PRIMARY KEY (id);
ALTER TABLE public."speakers" ADD CONSTRAINT "speakers_full_name_check" CHECK (((length(full_name) >= 2) AND (length(full_name) <= 200)));
ALTER TABLE public."speakers" ADD CONSTRAINT "speakers_pkey" PRIMARY KEY (id);
ALTER TABLE public."tasks" ADD CONSTRAINT "tasks_pkey" PRIMARY KEY (id);
ALTER TABLE public."tasks" ADD CONSTRAINT "tasks_points_check" CHECK (((points >= 0) AND (points <= 100)));
ALTER TABLE public."tasks" ADD CONSTRAINT "tasks_title_check" CHECK (((length(title) >= 2) AND (length(title) <= 200)));
ALTER TABLE public."useful_links" ADD CONSTRAINT "useful_links_category_name_check" CHECK (((length(category_name) >= 2) AND (length(category_name) <= 100)));
ALTER TABLE public."useful_links" ADD CONSTRAINT "useful_links_pkey" PRIMARY KEY (id);
ALTER TABLE public."useful_links" ADD CONSTRAINT "useful_links_title_check" CHECK (((length(title) >= 2) AND (length(title) <= 200)));
ALTER TABLE public."useful_links" ADD CONSTRAINT "useful_links_url_check" CHECK ((length(url) >= 5));
ALTER TABLE public."announcement_members" ADD CONSTRAINT "announcement_members_announcement_id_fkey" FOREIGN KEY (announcement_id) REFERENCES announcements(id) ON DELETE CASCADE;
ALTER TABLE public."announcement_members" ADD CONSTRAINT "announcement_members_member_id_fkey" FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE;
ALTER TABLE public."archived_tasks" ADD CONSTRAINT "archived_tasks_assignee_id_fkey" FOREIGN KEY (assignee_id) REFERENCES members(id) ON DELETE SET NULL;
ALTER TABLE public."birthday_email_deliveries" ADD CONSTRAINT "birthday_email_deliveries_birthday_person_id_fkey" FOREIGN KEY (birthday_person_id) REFERENCES members(id) ON DELETE CASCADE;
ALTER TABLE public."birthday_email_deliveries" ADD CONSTRAINT "birthday_email_deliveries_queue_id_fkey" FOREIGN KEY (queue_id) REFERENCES email_queue(id) ON DELETE CASCADE;
ALTER TABLE public."birthday_notifications" ADD CONSTRAINT "birthday_notifications_birthday_person_id_fkey" FOREIGN KEY (birthday_person_id) REFERENCES members(id) ON DELETE CASCADE;
ALTER TABLE public."email_queue" ADD CONSTRAINT "email_queue_template_code_fkey" FOREIGN KEY (template_code) REFERENCES email_templates(template_code) ON DELETE RESTRICT;
ALTER TABLE public."email_send_logs" ADD CONSTRAINT "email_send_logs_queue_id_fkey" FOREIGN KEY (queue_id) REFERENCES email_queue(id) ON DELETE CASCADE;
ALTER TABLE public."email_send_logs" ADD CONSTRAINT "email_send_logs_speaker_queue_id_fkey" FOREIGN KEY (speaker_queue_id) REFERENCES speaker_email_queue(id) ON DELETE CASCADE;
ALTER TABLE public."event_speakers" ADD CONSTRAINT "event_speakers_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
ALTER TABLE public."event_speakers" ADD CONSTRAINT "event_speakers_speaker_id_fkey" FOREIGN KEY (speaker_id) REFERENCES speakers(id) ON DELETE CASCADE;
ALTER TABLE public."event_staff" ADD CONSTRAINT "event_staff_event_id_fkey" FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE;
ALTER TABLE public."event_staff" ADD CONSTRAINT "event_staff_member_id_fkey" FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE;
ALTER TABLE public."member_announcements" ADD CONSTRAINT "member_announcements_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public."member_areas" ADD CONSTRAINT "member_areas_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public."member_attachments" ADD CONSTRAINT "member_attachments_profile_id_fkey" FOREIGN KEY (profile_id) REFERENCES profiles(id) ON DELETE CASCADE;
ALTER TABLE public."notifications" ADD CONSTRAINT "notifications_actor_id_fkey" FOREIGN KEY (actor_id) REFERENCES members(id) ON DELETE SET NULL;
ALTER TABLE public."notifications" ADD CONSTRAINT "notifications_user_id_fkey" FOREIGN KEY (user_id) REFERENCES members(id) ON DELETE SET NULL;
ALTER TABLE public."org_area_members" ADD CONSTRAINT "org_area_members_area_id_fkey" FOREIGN KEY (area_id) REFERENCES org_areas(id) ON DELETE CASCADE;
ALTER TABLE public."org_area_members" ADD CONSTRAINT "org_area_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES members(id) ON DELETE CASCADE;
ALTER TABLE public."org_areas" ADD CONSTRAINT "org_areas_area_leader_id_fkey" FOREIGN KEY (area_leader_id) REFERENCES members(id) ON DELETE SET NULL;
ALTER TABLE public."org_areas" ADD CONSTRAINT "org_areas_department_id_fkey" FOREIGN KEY (department_id) REFERENCES org_departments(id) ON DELETE CASCADE;
ALTER TABLE public."org_department_members" ADD CONSTRAINT "org_department_members_department_id_fkey" FOREIGN KEY (department_id) REFERENCES org_departments(id) ON DELETE CASCADE;
ALTER TABLE public."org_department_members" ADD CONSTRAINT "org_department_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES members(id) ON DELETE CASCADE;
ALTER TABLE public."org_departments" ADD CONSTRAINT "org_departments_responsible_person_id_fkey" FOREIGN KEY (responsible_person_id) REFERENCES members(id) ON DELETE SET NULL;
ALTER TABLE public."org_project_members" ADD CONSTRAINT "org_project_members_project_id_fkey" FOREIGN KEY (project_id) REFERENCES org_projects(id) ON DELETE CASCADE;
ALTER TABLE public."org_project_members" ADD CONSTRAINT "org_project_members_user_id_fkey" FOREIGN KEY (user_id) REFERENCES members(id) ON DELETE CASCADE;
ALTER TABLE public."org_projects" ADD CONSTRAINT "org_projects_area_id_fkey" FOREIGN KEY (area_id) REFERENCES org_areas(id) ON DELETE CASCADE;
ALTER TABLE public."profiles" ADD CONSTRAINT "profiles_member_id_fkey" FOREIGN KEY (member_id) REFERENCES members(id) ON DELETE CASCADE;
ALTER TABLE public."speaker_email_queue" ADD CONSTRAINT "speaker_email_queue_speaker_fkey" FOREIGN KEY (speaker_id) REFERENCES speakers(id) ON DELETE CASCADE;
ALTER TABLE public."speakers" ADD CONSTRAINT "speakers_added_by_fkey" FOREIGN KEY (added_by) REFERENCES members(id) ON DELETE SET NULL;
ALTER TABLE public."tasks" ADD CONSTRAINT "tasks_assignee_id_fkey" FOREIGN KEY (assignee_id) REFERENCES members(id) ON DELETE SET NULL;
ALTER SEQUENCE public."birthday_notifications_id_seq" OWNED BY public."birthday_notifications"."id";
ALTER SEQUENCE public."email_queue_id_seq" OWNED BY public."email_queue"."id";
ALTER SEQUENCE public."email_send_logs_id_seq" OWNED BY public."email_send_logs"."id";
ALTER SEQUENCE public."email_settings_id_seq" OWNED BY public."email_settings"."id";
ALTER SEQUENCE public."email_templates_id_seq" OWNED BY public."email_templates"."id";
ALTER SEQUENCE public."manual_emails_id_seq" OWNED BY public."manual_emails"."id";
CREATE INDEX idx_announcement_members_announcement_id ON public.announcement_members USING btree (announcement_id);
CREATE INDEX idx_announcement_members_member_id ON public.announcement_members USING btree (member_id);
CREATE INDEX idx_announcement_members_unique_check ON public.announcement_members USING btree (announcement_id, member_id);
CREATE INDEX idx_announcements_created_at ON public.announcements USING btree (created_at DESC);
CREATE INDEX idx_announcements_title_trgm ON public.announcements USING gin (title gin_trgm_ops);
CREATE INDEX idx_announcements_type ON public.announcements USING btree (type);
CREATE INDEX idx_announcements_updated_at ON public.announcements USING btree (updated_at DESC);
CREATE INDEX idx_archived_tasks_assignee_id ON public.archived_tasks USING btree (assignee_id);
CREATE INDEX idx_archived_tasks_done_completed_at ON public.archived_tasks USING btree (done_completed_at);
CREATE INDEX idx_archived_tasks_done_completed_by ON public.archived_tasks USING btree (done_completed_by);
CREATE INDEX idx_email_queue_created_at ON public.email_queue USING btree (created_at);
CREATE INDEX idx_email_queue_due_pending ON public.email_queue USING btree (status, next_attempt_at, priority, created_at);
CREATE UNIQUE INDEX idx_email_queue_idempotency_key ON public.email_queue USING btree (idempotency_key) WHERE (idempotency_key IS NOT NULL);
CREATE INDEX idx_email_queue_status ON public.email_queue USING btree (status);
CREATE INDEX idx_email_send_logs_event_type ON public.email_send_logs USING btree (event_type);
CREATE INDEX idx_email_send_logs_recipient_email ON public.email_send_logs USING btree (recipient_email);
CREATE INDEX idx_email_send_logs_speaker_queue_id ON public.email_send_logs USING btree (speaker_queue_id);
CREATE INDEX idx_event_speakers_event_id ON public.event_speakers USING btree (event_id);
CREATE INDEX idx_event_speakers_speaker_id ON public.event_speakers USING btree (speaker_id);
CREATE INDEX idx_event_staff_event_id ON public.event_staff USING btree (event_id);
CREATE INDEX idx_event_staff_member_id ON public.event_staff USING btree (member_id);
CREATE INDEX idx_events_event_type ON public.events USING btree (event_type);
CREATE INDEX idx_events_start_date ON public.events USING btree (start_date);
CREATE INDEX idx_events_title ON public.events USING btree (title);
CREATE INDEX idx_manual_emails_created_at ON public.manual_emails USING btree (created_at);
CREATE INDEX idx_manual_emails_status ON public.manual_emails USING btree (status);
CREATE INDEX idx_member_announcements_profile_id ON public.member_announcements USING btree (profile_id);
CREATE INDEX idx_member_areas_profile_id ON public.member_areas USING btree (profile_id);
CREATE INDEX idx_member_attachments_profile_id ON public.member_attachments USING btree (profile_id);
CREATE INDEX idx_members_comm_title ON public.members USING btree (comm_title);
CREATE INDEX idx_members_email ON public.members USING btree (email);
CREATE INDEX idx_members_name ON public.members USING btree (name);
CREATE INDEX idx_members_system_role ON public.members USING btree (system_role);
CREATE INDEX idx_menu_items_is_active ON public.menu_items USING btree (is_active);
CREATE INDEX idx_menu_items_path ON public.menu_items USING btree (path);
CREATE UNIQUE INDEX idx_notifications_dedupe_key ON public.notifications USING btree (dedupe_key) WHERE (dedupe_key IS NOT NULL);
CREATE INDEX idx_org_area_members_area_id ON public.org_area_members USING btree (area_id);
CREATE INDEX idx_org_area_members_user_id ON public.org_area_members USING btree (user_id);
CREATE INDEX idx_org_areas_area_leader_id ON public.org_areas USING btree (area_leader_id);
CREATE INDEX idx_org_areas_department_id ON public.org_areas USING btree (department_id);
CREATE INDEX idx_org_department_members_department_id ON public.org_department_members USING btree (department_id);
CREATE INDEX idx_org_department_members_user_id ON public.org_department_members USING btree (user_id);
CREATE INDEX idx_org_departments_responsible_person_id ON public.org_departments USING btree (responsible_person_id);
CREATE INDEX idx_org_project_members_project_id ON public.org_project_members USING btree (project_id);
CREATE INDEX idx_org_project_members_user_id ON public.org_project_members USING btree (user_id);
CREATE INDEX idx_org_projects_area_id ON public.org_projects USING btree (area_id);
CREATE INDEX idx_tasks_assignee_id ON public.tasks USING btree (assignee_id);
CREATE INDEX idx_tasks_deadline ON public.tasks USING btree (deadline);
CREATE INDEX idx_tasks_status ON public.tasks USING btree (status);
CREATE INDEX idx_tasks_title ON public.tasks USING btree (title);
CREATE INDEX idx_useful_links_category_name ON public.useful_links USING btree (category_name);
CREATE INDEX idx_useful_links_created_at ON public.useful_links USING btree (created_at);
CREATE INDEX idx_useful_links_title ON public.useful_links USING btree (title);
CREATE UNIQUE INDEX uq_menu_items_path_label ON public.menu_items USING btree (path, label);
CREATE UNIQUE INDEX uq_org_area_members_area_user ON public.org_area_members USING btree (area_id, user_id);
CREATE UNIQUE INDEX uq_org_department_members_department_user ON public.org_department_members USING btree (department_id, user_id);
CREATE OR REPLACE FUNCTION public.archive_done_tasks_older_than_7_days()
 RETURNS integer
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_moved integer := 0;
  v_completed_by uuid;
BEGIN

  -- auth.uid() members tablosunda var mı kontrol et
  -- Yoksa NULL kullan (cron job'da zaten NULL gelir)
  SELECT m.id INTO v_completed_by
    FROM members m
   WHERE m.id = auth.uid()
   LIMIT 1;

  -- Done + 7 günden eski task'ları arşive taşı
  INSERT INTO archived_tasks (
    id,
    title,
    description,
    deadline,
    image_url,
    points,
    assignee_id,
    status,
    done_completed_at,
    done_completed_by,
    archived_at,
    archived_reason,
    created_at,
    updated_at
  )
  SELECT
    t.id,
    t.title,
    COALESCE(t.description, ''),
    t.deadline,
    COALESCE(t.image_url, ''),
    COALESCE(t.points, 1),
    t.assignee_id,
    t.status,
    t.updated_at,
    v_completed_by,          -- NULL gelebilir, sorun değil
    timezone('utc', now()),
    'done_7_days',
    t.created_at,
    t.updated_at
  FROM tasks t
  WHERE t.status = 'done'
    AND t.updated_at < (now() - INTERVAL '7 days')
  ON CONFLICT (id) DO NOTHING;

  -- Arşive taşınanları tasks'tan sil
  DELETE FROM tasks
  WHERE status = 'done'
    AND updated_at < (now() - INTERVAL '7 days')
    AND id IN (
      SELECT id FROM archived_tasks
      WHERE archived_reason = 'done_7_days'
    );

  GET DIAGNOSTICS v_moved = ROW_COUNT;

  RAISE NOTICE '[Archive] % task arşive taşındı.', v_moved;

  RETURN v_moved;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.archive_single_task(p_task_id uuid)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_completed_by uuid;
BEGIN

  -- auth.uid() members tablosunda var mı kontrol et
  SELECT m.id INTO v_completed_by
    FROM members m
   WHERE m.id = auth.uid()
   LIMIT 1;

  -- Arşive ekle
  INSERT INTO archived_tasks (
    id,
    title,
    description,
    deadline,
    image_url,
    points,
    assignee_id,
    status,
    done_completed_at,
    done_completed_by,
    archived_at,
    archived_reason,
    created_at,
    updated_at
  )
  SELECT
    t.id,
    t.title,
    COALESCE(t.description, ''),
    t.deadline,
    COALESCE(t.image_url, ''),
    COALESCE(t.points, 1),
    t.assignee_id,
    t.status,
    t.updated_at,
    v_completed_by,          -- NULL gelebilir, sorun değil
    timezone('utc', now()),
    'manual',
    t.created_at,
    t.updated_at
  FROM tasks t
  WHERE t.id = p_task_id
  ON CONFLICT (id) DO NOTHING;

  -- Tasks'tan sil
  DELETE FROM tasks WHERE id = p_task_id;

END;
$function$
;
CREATE OR REPLACE FUNCTION public.cancel_stale_birthday_jobs_on_date_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_year integer := extract(year FROM (now() AT TIME ZONE 'Europe/Istanbul'))::integer;
  v_today date := (now() AT TIME ZONE 'Europe/Istanbul')::date;
BEGIN
  IF NEW.birth_day IS DISTINCT FROM OLD.birth_day OR NEW.birth_month IS DISTINCT FROM OLD.birth_month THEN
    UPDATE public.email_queue
       SET status = 'failed',
           error_message = 'Cancelled because the member birthday date changed',
           updated_at = now()
     WHERE status = 'pending'
       AND template_code IN ('birthday_personal', 'birthday_team')
       AND template_params ->> 'birthday_person_id' = OLD.id::text
       AND (
         (template_params ->> 'birthday_day') IS DISTINCT FROM NEW.birth_day::text
         OR (template_params ->> 'birthday_month') IS DISTINCT FROM NEW.birth_month::text
       );

    -- If no birthday email has been delivered this year, remove today's stale in-app notice too.
    IF NOT EXISTS (
      SELECT 1 FROM public.birthday_email_deliveries d
       WHERE d.birthday_person_id = OLD.id AND d.notification_year = v_year
    ) THEN
      DELETE FROM public.notifications
       WHERE type = 'birthday'
         AND related_id = OLD.id
         AND created_at AT TIME ZONE 'Europe/Istanbul' >= v_today::timestamp
         AND created_at AT TIME ZONE 'Europe/Istanbul' < (v_today + 1)::timestamp
         AND dedupe_key LIKE 'birthday:' || v_year || ':' || OLD.id::text || ':%';
    END IF;
  END IF;
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.current_member_id()
 RETURNS uuid
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT m.id
  FROM public.members AS m
  WHERE lower(m.email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
  LIMIT 1;
$function$
;
CREATE OR REPLACE FUNCTION public.current_member_role()
 RETURNS text
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT m.system_role::text
  FROM public.members AS m
  WHERE lower(m.email) = lower(COALESCE(auth.jwt() ->> 'email', ''))
  LIMIT 1;
$function$
;
CREATE OR REPLACE FUNCTION public.current_profile_token()
 RETURNS uuid
 LANGUAGE sql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  SELECT NULLIF(current_setting('request.profile_token', true), '')::uuid;
$function$
;
CREATE OR REPLACE FUNCTION public.email_queue_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.email_settings_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  NEW.updated_at = timezone('utc', now());
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.enforce_max_total_tasks()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if new.total_tasks > 3 then
    raise exception 'Total tasks cannot exceed 3. Received: %', new.total_tasks;
  end if;
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.enforce_task_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if new.active_tasks > new.total_tasks then
    raise exception 'Task limit exceeded: active_tasks (%) cannot exceed total_tasks (%)', 
      new.active_tasks, new.total_tasks;
  end if;
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.enqueue_birthday_emails(p_personal_only boolean DEFAULT false)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_year integer := extract(year FROM (now() AT TIME ZONE 'Europe/Istanbul'))::integer;
  v_member record;
  v_recipient record;
BEGIN
  FOR v_member IN
    SELECT id, name, email, birth_day, birth_month FROM public.members
     WHERE birth_day = extract(day FROM (now() AT TIME ZONE 'Europe/Istanbul'))::integer
       AND birth_month = extract(month FROM (now() AT TIME ZONE 'Europe/Istanbul'))::integer
       AND email IS NOT NULL AND is_active = true
  LOOP
    INSERT INTO public.birthday_notifications
      (birthday_person_id, notification_year, personal_mail_sent, team_mails_sent_count, sent_at)
    VALUES (v_member.id, v_year, false, 0, now())
    ON CONFLICT (birthday_person_id, notification_year) DO NOTHING;

    INSERT INTO public.notifications
      (title, message, type, related_id, related_type, user_id, actor_id, actor_name, dedupe_key)
    SELECT 'Doğum Günü', format('Bugün %s doğum gününü kutluyor.', v_member.name),
      'birthday', v_member.id, 'member', m.id, v_member.id, v_member.name,
      'birthday:' || v_year || ':' || v_member.id::text || ':' || m.id::text
    FROM public.members m WHERE m.is_active = true
    ON CONFLICT DO NOTHING;

    IF NOT EXISTS (
      SELECT 1 FROM public.birthday_email_deliveries d
       WHERE d.birthday_person_id = v_member.id AND d.notification_year = v_year AND d.channel = 'personal'
    ) AND NOT EXISTS (
      SELECT 1 FROM public.birthday_notifications b
       WHERE b.birthday_person_id = v_member.id AND b.notification_year = v_year AND b.personal_mail_sent = true
    ) THEN
      INSERT INTO public.email_queue
        (recipient_email, recipient_name, template_code, template_params, priority, status, idempotency_key)
      VALUES (
        v_member.email, v_member.name, 'birthday_personal',
        jsonb_build_object('member_name', coalesce(v_member.name, 'Üye'),
          'birthday_person_id', v_member.id::text, 'birthday_year', v_year,
          'birthday_day', v_member.birth_day, 'birthday_month', v_member.birth_month),
        'high', 'pending',
        'birthday:' || v_year || ':' || v_member.id::text || ':' ||
          v_member.birth_month || '-' || v_member.birth_day || ':personal:' || lower(v_member.email)
      ) ON CONFLICT DO NOTHING;
    END IF;

    IF p_personal_only THEN CONTINUE; END IF;

    FOR v_recipient IN
      SELECT DISTINCT team_member.id, team_member.email, team_member.name
      FROM public.members team_member
      JOIN (
        SELECT oam.user_id AS member_id
          FROM public.org_area_members oam
          JOIN public.org_area_members birthday_oam ON birthday_oam.area_id = oam.area_id
         WHERE birthday_oam.user_id = v_member.id AND oam.deleted_at IS NULL AND birthday_oam.deleted_at IS NULL
        UNION
        SELECT odm.user_id
          FROM public.org_department_members odm
          JOIN public.org_department_members birthday_odm ON birthday_odm.department_id = odm.department_id
         WHERE birthday_odm.user_id = v_member.id AND odm.deleted_at IS NULL AND birthday_odm.deleted_at IS NULL
        UNION
        SELECT opm.user_id
          FROM public.org_project_members opm
          JOIN public.org_project_members birthday_opm ON birthday_opm.project_id = opm.project_id
         WHERE birthday_opm.user_id = v_member.id AND opm.deleted_at IS NULL AND birthday_opm.deleted_at IS NULL
      ) shared ON shared.member_id = team_member.id
      WHERE team_member.id <> v_member.id AND team_member.is_active = true AND team_member.email IS NOT NULL
    LOOP
      INSERT INTO public.email_queue
        (recipient_email, recipient_name, template_code, template_params, priority, status, idempotency_key)
      VALUES (
        v_recipient.email, v_recipient.name, 'birthday_team',
        jsonb_build_object('birthday_person', coalesce(v_member.name, 'Bir ekip üyesi'),
          'birthday_person_id', v_member.id::text, 'birthday_year', v_year,
          'birthday_day', v_member.birth_day, 'birthday_month', v_member.birth_month),
        'medium', 'pending',
        'birthday:' || v_year || ':' || v_member.id::text || ':' ||
          v_member.birth_month || '-' || v_member.birth_day || ':team:' || v_recipient.id::text
      ) ON CONFLICT DO NOTHING;
    END LOOP;
  END LOOP;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.enqueue_email(p_recipient_email character varying, p_recipient_name character varying, p_template_code character varying, p_template_params jsonb, p_priority email_priority_enum DEFAULT 'medium'::email_priority_enum)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  INSERT INTO email_queue
    (recipient_email, recipient_name, template_code, template_params, priority, status)
  VALUES (
    p_recipient_email,
    p_recipient_name,
    p_template_code,
    COALESCE(p_template_params, '{}'::jsonb),
    p_priority,
    'pending'
  );
END;
$function$
;
CREATE OR REPLACE FUNCTION public.guard_member_role_change()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.system_role::text = 'Super Admin'
       AND public.current_member_role() IS DISTINCT FROM 'Super Admin' THEN
      RAISE EXCEPTION 'Only a Super Admin can create a Super Admin account';
    END IF;
    RETURN NEW;
  END IF;

  IF NEW.system_role IS DISTINCT FROM OLD.system_role
     AND public.current_member_role() IS DISTINCT FROM 'Super Admin' THEN
    RAISE EXCEPTION 'Only a Super Admin can change system roles';
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.guard_task_updates()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF public.current_member_role() IN ('Super Admin', 'Admin') THEN
    RETURN NEW;
  END IF;

  IF OLD.assignee_id IS DISTINCT FROM public.current_member_id() THEN
    RAISE EXCEPTION 'Only an administrator or the assigned member can update this task';
  END IF;

  IF NEW.assignee_id IS DISTINCT FROM OLD.assignee_id THEN
    RAISE EXCEPTION 'Only an administrator can reassign a task';
  END IF;

  IF (to_jsonb(NEW) - 'status' - 'updated_at')
     IS DISTINCT FROM
     (to_jsonb(OLD) - 'status' - 'updated_at') THEN
    RAISE EXCEPTION 'Assigned members may only change task status';
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.handle_task_assignment_and_limit()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_active_count integer := 0;
  v_task_limit integer := 3;
  v_should_check boolean := false;
BEGIN
  IF TG_OP = 'DELETE' THEN
    IF OLD.assignee_id IS NOT NULL THEN
      UPDATE public.members AS m
      SET active_tasks = (
        SELECT count(*)::integer
        FROM public.tasks AS t
        WHERE t.assignee_id = OLD.assignee_id
          AND t.status::text IN ('started', 'in_progress')
      )
      WHERE m.id = OLD.assignee_id;
    END IF;
    RETURN OLD;
  END IF;

  IF NEW.assignee_id IS NOT NULL
     AND NEW.status::text IN ('started', 'in_progress') THEN
    IF TG_OP = 'INSERT' THEN
      v_should_check := true;
    ELSE
      v_should_check :=
        OLD.assignee_id IS DISTINCT FROM NEW.assignee_id
        OR OLD.status::text NOT IN ('started', 'in_progress');
    END IF;
  END IF;

  IF v_should_check THEN
    SELECT count(*)::integer, COALESCE(max(m.total_tasks), 3)
      INTO v_active_count, v_task_limit
    FROM public.tasks AS t
    JOIN public.members AS m ON m.id = NEW.assignee_id
    WHERE t.assignee_id = NEW.assignee_id
      AND t.status::text IN ('started', 'in_progress')
      AND t.id <> NEW.id;

    IF v_active_count >= v_task_limit THEN
      RAISE EXCEPTION 'This member has reached their active task limit (%)', v_task_limit;
    END IF;
  END IF;

  IF NEW.assignee_id IS NOT NULL THEN
    UPDATE public.members AS m
    SET active_tasks = (
      SELECT count(*)::integer
      FROM public.tasks AS t
      WHERE t.assignee_id = NEW.assignee_id
        AND t.status::text IN ('started', 'in_progress')
    )
    WHERE m.id = NEW.assignee_id;
  END IF;

  IF TG_OP = 'UPDATE'
     AND OLD.assignee_id IS NOT NULL
     AND OLD.assignee_id IS DISTINCT FROM NEW.assignee_id THEN
    UPDATE public.members AS m
    SET active_tasks = (
      SELECT count(*)::integer
      FROM public.tasks AS t
      WHERE t.assignee_id = OLD.assignee_id
        AND t.status::text IN ('started', 'in_progress')
    )
    WHERE m.id = OLD.assignee_id;
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.notify_member_added()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  INSERT INTO public.notifications
    (title, message, type, related_id, related_type, user_id, actor_id, actor_name, dedupe_key)
  SELECT 'Yeni Üye', format('%s topluluğa katıldı.', NEW.name), 'member_added',
         NEW.id, 'member', m.id, NEW.id, NEW.name,
         'member_added:' || NEW.id::text || ':' || m.id::text
    FROM public.members m WHERE m.is_active = true
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.notify_member_removed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  -- The deleted member no longer exists as an actor FK; keep their name as a snapshot.
  INSERT INTO public.notifications
    (title, message, type, related_id, related_type, user_id, actor_id, actor_name, dedupe_key)
  SELECT 'Üye Ayrıldı', format('%s topluluktan ayrıldı.', OLD.name), 'member_removed',
         OLD.id, 'member', m.id, NULL, OLD.name,
         'member_removed:' || OLD.id::text || ':' || m.id::text
    FROM public.members m WHERE m.is_active = true
  ON CONFLICT DO NOTHING;
  RETURN OLD;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.notify_task_added()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  INSERT INTO public.notifications
    (title, message, type, related_id, related_type, user_id, actor_id, actor_name, dedupe_key)
  SELECT 'Yeni Görev', format('Yeni görev eklendi: %s', NEW.title), 'task_added',
         NEW.id, 'task', m.id, NEW.assignee_id, NULL,
         'task_added:' || NEW.id::text || ':' || m.id::text
    FROM public.members m WHERE m.is_active = true
  ON CONFLICT DO NOTHING;
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.notify_task_completed()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF NEW.status::text IN ('completed', 'done') AND OLD.status IS DISTINCT FROM NEW.status THEN
    INSERT INTO public.notifications
      (title, message, type, related_id, related_type, user_id, actor_id, actor_name, dedupe_key)
    SELECT 'Görev Tamamlandı', format('Görev tamamlandı: %s', NEW.title), 'task_completed',
           NEW.id, 'task', m.id, NEW.assignee_id, NULL,
           'task_completed:' || NEW.id::text || ':' || m.id::text || ':' || NEW.status::text
      FROM public.members m WHERE m.is_active = true
    ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.notify_task_deleted()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  INSERT INTO public.notifications
    (title, message, type, related_id, related_type, user_id, actor_id, actor_name, dedupe_key)
  SELECT 'Görev Silindi', format('Görev silindi: %s', OLD.title), 'task_deleted',
         OLD.id, 'task', m.id, OLD.assignee_id, NULL,
         'task_deleted:' || OLD.id::text || ':' || m.id::text
    FROM public.members m WHERE m.is_active = true
  ON CONFLICT DO NOTHING;
  RETURN OLD;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.process_speaker_email_queue()
 RETURNS TABLE(processed_count integer)
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_count integer := 0;
BEGIN
  UPDATE speaker_email_queue
  SET status = 'sent',
      sent_at = timezone('utc'::text, now())
  WHERE id IN (
    SELECT seq.id
    FROM speaker_email_queue seq
    JOIN speakers s ON s.id = seq.speaker_id
    WHERE seq.status = 'pending'
      AND seq.scheduled_at <= timezone('utc'::text, now())
      AND seq.retry_count < 3
      AND s.status = 'green'
    LIMIT 10
  );
  
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN QUERY SELECT v_count;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.record_birthday_email_delivery(p_queue_id bigint, p_birthday_person_id uuid, p_notification_year integer, p_channel text)
 RETURNS void
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_inserted bigint;
BEGIN
  IF p_channel NOT IN ('personal', 'team') THEN
    RAISE EXCEPTION 'Invalid birthday email channel';
  END IF;

  INSERT INTO public.birthday_email_deliveries(queue_id, birthday_person_id, notification_year, channel)
  VALUES (p_queue_id, p_birthday_person_id, p_notification_year, p_channel)
  ON CONFLICT (queue_id) DO NOTHING
  RETURNING queue_id INTO v_inserted;

  IF v_inserted IS NULL THEN
    RETURN;
  END IF;

  IF p_channel = 'personal' THEN
    UPDATE public.birthday_notifications
       SET personal_mail_sent = true, sent_at = now()
     WHERE birthday_person_id = p_birthday_person_id
       AND notification_year = p_notification_year;
  ELSE
    UPDATE public.birthday_notifications
       SET team_mails_sent_count = team_mails_sent_count + 1, sent_at = now()
     WHERE birthday_person_id = p_birthday_person_id
       AND notification_year = p_notification_year;
  END IF;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.send_speaker_welcome()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  -- Sadece status green ise mail gönder
  IF NEW.status = 'green' AND NEW.email IS NOT NULL THEN
    -- Burada Supabase Edge Function veya pg_net ile mail gönderebilirsin
    -- Örnek: Edge Function çağırma
    PERFORM
      net.http_post(
        url := current_setting('app.settings.edge_function_url') || '/send-welcome-email',
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
        ),
        body := jsonb_build_object(
          'speaker_id', NEW.id,
          'email', NEW.email,
          'full_name', NEW.full_name
        )
      );
  END IF;
  
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.set_updated_at_utc()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_announcement_general()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_member record;
BEGIN
  FOR v_member IN
    SELECT id, email, name
      FROM members
     WHERE email IS NOT NULL
       AND is_active = true   -- ✅ Sadece aktif üyeler
  LOOP
    PERFORM enqueue_email(
      v_member.email,
      v_member.name,
      'announcement_general',
      jsonb_build_object(
        'member_name',              COALESCE(v_member.name, 'Üye'),
        'announcement_title',       COALESCE(NEW.title, 'Yeni Duyuru'),
        'announcement_description', COALESCE(NEW.description, '')
      ),
      'low'
    );
  END LOOP;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_announcement_member()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_email varchar;
  v_name  varchar;
BEGIN
  SELECT m.email, m.name
    INTO v_email, v_name
    FROM members m
   WHERE m.id = NEW.profile_id;

  IF v_email IS NOT NULL THEN
    PERFORM enqueue_email(
      v_email, v_name,
      'announcement_member',
      jsonb_build_object(
        'member_name',       COALESCE(v_name, 'Üye'),
        'announcement_title', COALESCE(NEW.announcement_title, 'Yeni Bildirim'),
        'announcement_body',  COALESCE(NEW.announcement_body, '')
      ),
      'medium'
    );
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_area_member()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_email     varchar;
  v_name      varchar;
  v_area_name varchar;
BEGIN
  SELECT m.email, m.name
    INTO v_email, v_name
    FROM members m
   WHERE m.id = NEW.user_id
     AND m.is_active = true;

  SELECT a.name                  -- ✅ title → name
    INTO v_area_name
    FROM org_areas a
   WHERE a.id = NEW.area_id;

  IF v_email IS NOT NULL AND v_area_name IS NOT NULL THEN
    PERFORM enqueue_email(
      v_email, v_name,
      'area_member',
      jsonb_build_object(
        'member_name', COALESCE(v_name, 'Üye'),
        'area_name',   v_area_name
      ),
      'medium'
    );
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_department_member()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_email           varchar;
  v_name            varchar;
  v_department_name varchar;
BEGIN
  SELECT m.email, m.name
    INTO v_email, v_name
    FROM members m
   WHERE m.id = NEW.user_id
     AND m.is_active = true;

  SELECT d.name                  -- ✅ title → name
    INTO v_department_name
    FROM org_departments d
   WHERE d.id = NEW.department_id;

  IF v_email IS NOT NULL AND v_department_name IS NOT NULL THEN
    PERFORM enqueue_email(
      v_email, v_name,
      'department_member',
      jsonb_build_object(
        'member_name',     COALESCE(v_name, 'Üye'),
        'department_name', v_department_name
      ),
      'medium'
    );
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_event_speaker()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_speaker_email varchar;
  v_speaker_name  varchar;
  v_event_name    varchar;
  v_event_date    text;
  v_event_loc     text;
BEGIN
  -- Konuşmacı bilgisi speakers tablosundan
  SELECT s.email, s.full_name
    INTO v_speaker_email, v_speaker_name
    FROM speakers s
   WHERE s.id = NEW.speaker_id;

  -- Etkinlik bilgisi events tablosundan
  SELECT
    e.title,
    to_char(e.start_date, 'DD.MM.YYYY HH24:MI'),
    COALESCE(e.location, 'Belirtilmemiş')
    INTO v_event_name, v_event_date, v_event_loc
    FROM events e
   WHERE e.id = NEW.event_id;

  IF v_speaker_email IS NOT NULL AND v_event_name IS NOT NULL THEN
    PERFORM enqueue_email(
      v_speaker_email,
      v_speaker_name,
      'event_speaker',
      jsonb_build_object(
        'speaker_name',   COALESCE(v_speaker_name, 'Konuşmacı'),
        'event_name',     v_event_name,
        'event_date',     COALESCE(v_event_date, 'Belirtilmemiş'),
        'event_location', v_event_loc
      ),
      'high'
    );
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_event_staff_member()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_email      varchar;
  v_name       varchar;
  v_event_name varchar;
  v_event_date text;
  v_event_loc  text;
BEGIN
  SELECT m.email, m.name
    INTO v_email, v_name
    FROM members m
   WHERE m.id = NEW.member_id;

  SELECT
    e.title,
    to_char(e.start_date, 'DD.MM.YYYY HH24:MI'),
    COALESCE(e.location, 'Belirtilmemiş')
    INTO v_event_name, v_event_date, v_event_loc
    FROM events e
   WHERE e.id = NEW.event_id;

  IF v_email IS NOT NULL AND v_event_name IS NOT NULL THEN
    PERFORM enqueue_email(
      v_email, v_name,
      'event_staff_member',
      jsonb_build_object(
        'member_name',    COALESCE(v_name, 'Üye'),
        'event_name',     v_event_name,
        'event_date',     COALESCE(v_event_date, 'Belirtilmemiş'),
        'event_location', v_event_loc
      ),
      'medium'
    );
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_member_area_assigned()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_email varchar;
  v_name  varchar;
BEGIN
  SELECT m.email, m.name
    INTO v_email, v_name
    FROM members m
   WHERE m.id = NEW.profile_id;

  IF v_email IS NOT NULL AND NEW.area_name IS NOT NULL THEN
    PERFORM enqueue_email(
      v_email, v_name,
      'member_area_assigned',
      jsonb_build_object(
        'member_name', COALESCE(v_name, 'Üye'),
        'area_name',   NEW.area_name
      ),
      'medium'
    );
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_project_member()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_email        varchar;
  v_name         varchar;
  v_project_name varchar;
BEGIN
  SELECT m.email, m.name
    INTO v_email, v_name
    FROM members m
   WHERE m.id = NEW.user_id
     AND m.is_active = true;

  SELECT p.name                  -- ✅ title → name
    INTO v_project_name
    FROM org_projects p
   WHERE p.id = NEW.project_id;

  IF v_email IS NOT NULL AND v_project_name IS NOT NULL THEN
    PERFORM enqueue_email(
      v_email, v_name,
      'project_member',
      jsonb_build_object(
        'member_name',  COALESCE(v_name, 'Üye'),
        'project_name', v_project_name
      ),
      'medium'
    );
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_speaker_invite()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  IF NEW.status = 'green' AND NEW.email IS NOT NULL THEN
    INSERT INTO public.speaker_email_queue (
      speaker_id,
      email_type,
      status,
      scheduled_at
    ) VALUES (
      NEW.id,
      'welcome',
      'pending',
      timezone('utc'::text, now())
    );
  END IF;
  
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_task_assigned()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
DECLARE
  v_email    varchar;
  v_name     varchar;
  v_deadline text;
BEGIN
  -- assignee yoksa işlem yapma
  IF NEW.assignee_id IS NULL THEN
    RETURN NEW;
  END IF;

  -- UPDATE: assignee değişmediyse işlem yapma
  IF TG_OP = 'UPDATE' AND
     OLD.assignee_id IS NOT DISTINCT FROM NEW.assignee_id THEN
    RETURN NEW;
  END IF;

  SELECT m.email, m.name
    INTO v_email, v_name
    FROM members m
   WHERE m.id = NEW.assignee_id
   LIMIT 1;

  IF v_email IS NOT NULL THEN
    v_deadline := CASE
      WHEN NEW.deadline IS NOT NULL
      THEN to_char(NEW.deadline, 'DD.MM.YYYY')
      ELSE 'Belirtilmemiş'
    END;

    PERFORM enqueue_email(
      v_email,
      v_name,
      'task_assigned',
      jsonb_build_object(
        'member_name', COALESCE(v_name, 'Üye'),
        'task_name',   COALESCE(NEW.title, 'Yeni Görev'),
        'deadline',    v_deadline
      ),
      'high'
    );
  END IF;

  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trg_enqueue_welcome_member()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  -- Email yoksa veya pasif ekleniyorsa mail gönderme
  IF NEW.email IS NULL OR NEW.is_active = false THEN
    RETURN NEW;
  END IF;

  PERFORM enqueue_email(
    NEW.email,
    NEW.name,
    'welcome_member',
    jsonb_build_object(
      'member_name', COALESCE(NEW.name, 'Üye'),
      'join_date',   to_char(COALESCE(NEW.created_at, now()), 'DD.MM.YYYY')
    ),
    'medium'
  );
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.trigger_set_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  NEW.updated_at = timezone('utc'::text, now());
  RETURN NEW;
END;
$function$
;
CREATE OR REPLACE FUNCTION public.update_events_updated_at()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  new.updated_at = timezone('utc'::text, now());
  return new;
end;
$function$
;
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
 RETURNS trigger
 LANGUAGE plpgsql
 SET search_path TO 'pg_catalog', 'public'
AS $function$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$function$
;
CREATE TRIGGER tr_enqueue_announcement_general AFTER INSERT ON public.announcements FOR EACH ROW EXECUTE FUNCTION trg_enqueue_announcement_general();
CREATE TRIGGER trg_announcements_updated_at BEFORE UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION set_updated_at_utc();
CREATE TRIGGER trg_community_settings_updated_at BEFORE UPDATE ON public.community_settings FOR EACH ROW EXECUTE FUNCTION set_updated_at_utc();
CREATE TRIGGER trg_email_queue_updated_at BEFORE UPDATE ON public.email_queue FOR EACH ROW EXECUTE FUNCTION email_queue_set_updated_at();
CREATE TRIGGER trg_email_settings_updated_at BEFORE UPDATE ON public.email_settings FOR EACH ROW EXECUTE FUNCTION email_settings_set_updated_at();
CREATE TRIGGER tr_enqueue_event_speaker AFTER INSERT ON public.event_speakers FOR EACH ROW EXECUTE FUNCTION trg_enqueue_event_speaker();
CREATE TRIGGER tr_enqueue_event_staff_member AFTER INSERT ON public.event_staff FOR EACH ROW EXECUTE FUNCTION trg_enqueue_event_staff_member();
CREATE TRIGGER update_events_updated_at BEFORE UPDATE ON public.events FOR EACH ROW EXECUTE FUNCTION update_events_updated_at();
CREATE TRIGGER tr_enqueue_announcement_member AFTER INSERT ON public.member_announcements FOR EACH ROW EXECUTE FUNCTION trg_enqueue_announcement_member();
CREATE TRIGGER trg_member_announcements_updated_at BEFORE UPDATE ON public.member_announcements FOR EACH ROW EXECUTE FUNCTION set_updated_at_utc();
CREATE TRIGGER tr_enqueue_member_area_assigned AFTER INSERT ON public.member_areas FOR EACH ROW EXECUTE FUNCTION trg_enqueue_member_area_assigned();
CREATE TRIGGER trg_member_areas_updated_at BEFORE UPDATE ON public.member_areas FOR EACH ROW EXECUTE FUNCTION set_updated_at_utc();
CREATE TRIGGER trg_member_attachments_updated_at BEFORE UPDATE ON public.member_attachments FOR EACH ROW EXECUTE FUNCTION set_updated_at_utc();
CREATE TRIGGER tr_enqueue_welcome_member AFTER INSERT ON public.members FOR EACH ROW EXECUTE FUNCTION trg_enqueue_welcome_member();
CREATE TRIGGER trg_cancel_stale_birthday_jobs AFTER UPDATE OF birth_day, birth_month ON public.members FOR EACH ROW EXECUTE FUNCTION cancel_stale_birthday_jobs_on_date_change();
CREATE TRIGGER trg_enforce_max_total_tasks BEFORE INSERT OR UPDATE ON public.members FOR EACH ROW EXECUTE FUNCTION enforce_max_total_tasks();
CREATE TRIGGER trg_guard_member_role_change BEFORE INSERT OR UPDATE OF system_role ON public.members FOR EACH ROW EXECUTE FUNCTION guard_member_role_change();
CREATE TRIGGER trg_notify_member_added AFTER INSERT ON public.members FOR EACH ROW EXECUTE FUNCTION notify_member_added();
CREATE TRIGGER trg_notify_member_removed AFTER DELETE ON public.members FOR EACH ROW EXECUTE FUNCTION notify_member_removed();
CREATE TRIGGER trg_menu_items_updated_at BEFORE UPDATE ON public.menu_items FOR EACH ROW EXECUTE FUNCTION set_updated_at_utc();
CREATE TRIGGER tr_enqueue_area_member AFTER INSERT ON public.org_area_members FOR EACH ROW EXECUTE FUNCTION trg_enqueue_area_member();
CREATE TRIGGER tr_org_area_members_updated_at BEFORE UPDATE ON public.org_area_members FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER tr_org_areas_updated_at BEFORE UPDATE ON public.org_areas FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER tr_enqueue_department_member AFTER INSERT ON public.org_department_members FOR EACH ROW EXECUTE FUNCTION trg_enqueue_department_member();
CREATE TRIGGER tr_org_departments_updated_at BEFORE UPDATE ON public.org_departments FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER tr_enqueue_project_member AFTER INSERT ON public.org_project_members FOR EACH ROW EXECUTE FUNCTION trg_enqueue_project_member();
CREATE TRIGGER tr_org_project_members_updated_at BEFORE UPDATE ON public.org_project_members FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER tr_org_projects_updated_at BEFORE UPDATE ON public.org_projects FOR EACH ROW EXECUTE FUNCTION trigger_set_updated_at();
CREATE TRIGGER trg_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION set_updated_at_utc();
CREATE TRIGGER tr_enqueue_on_status_change AFTER UPDATE OF status ON public.speakers FOR EACH ROW WHEN (((old.status <> 'green'::speaker_status) AND (new.status = 'green'::speaker_status))) EXECUTE FUNCTION trg_enqueue_speaker_invite();
CREATE TRIGGER tr_enqueue_speaker_invite AFTER INSERT ON public.speakers FOR EACH ROW WHEN ((new.status = 'green'::speaker_status)) EXECUTE FUNCTION trg_enqueue_speaker_invite();
CREATE TRIGGER tr_enqueue_task_assigned_insert AFTER INSERT ON public.tasks FOR EACH ROW EXECUTE FUNCTION trg_enqueue_task_assigned();
CREATE TRIGGER tr_enqueue_task_assigned_update AFTER UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION trg_enqueue_task_assigned();
CREATE TRIGGER trg_guard_task_updates BEFORE UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION guard_task_updates();
CREATE TRIGGER trg_notify_task_added AFTER INSERT ON public.tasks FOR EACH ROW EXECUTE FUNCTION notify_task_added();
CREATE TRIGGER trg_notify_task_completed AFTER UPDATE OF status ON public.tasks FOR EACH ROW EXECUTE FUNCTION notify_task_completed();
CREATE TRIGGER trg_notify_task_deleted AFTER DELETE ON public.tasks FOR EACH ROW EXECUTE FUNCTION notify_task_deleted();
CREATE TRIGGER trg_task_flow_control AFTER INSERT OR UPDATE ON public.tasks FOR EACH ROW EXECUTE FUNCTION handle_task_assignment_and_limit();
CREATE TRIGGER trg_task_flow_control_delete AFTER DELETE ON public.tasks FOR EACH ROW EXECUTE FUNCTION handle_task_assignment_and_limit();
ALTER TABLE public."members" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."tasks" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."useful_links" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."org_departments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."org_areas" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."org_department_members" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."announcements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."announcement_members" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."events" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."event_staff" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."event_speakers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."notifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."speakers" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."org_area_members" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."org_projects" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."org_project_members" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."profiles" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."member_areas" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."member_announcements" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."member_attachments" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."community_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."menu_items" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."birthday_email_deliveries" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."archived_tasks" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."birthday_notifications" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."email_settings" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."email_templates" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."speaker_email_queue" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."email_send_logs" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."email_queue" ENABLE ROW LEVEL SECURITY;
ALTER TABLE public."manual_emails" ENABLE ROW LEVEL SECURITY;
CREATE POLICY "announcement_members_admin_delete" ON public."announcement_members" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "announcement_members_admin_insert" ON public."announcement_members" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "announcement_members_admin_update" ON public."announcement_members" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "announcement_members_read_own_or_admin" ON public."announcement_members" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((member_id = current_member_id()) OR (current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))));
CREATE POLICY "announcements_admin_delete" ON public."announcements" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "announcements_admin_insert" ON public."announcements" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "announcements_admin_update" ON public."announcements" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "announcements_read_authenticated" ON public."announcements" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);
CREATE POLICY "archived_tasks_delete_admin_or_assignee" ON public."archived_tasks" AS PERMISSIVE FOR DELETE TO "authenticated" USING (((current_member_id() IS NOT NULL) AND ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])) OR (assignee_id = current_member_id()))));
CREATE POLICY "archived_tasks_insert_admin_or_assignee" ON public."archived_tasks" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((current_member_id() IS NOT NULL) AND ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])) OR (assignee_id = current_member_id()))));
CREATE POLICY "archived_tasks_read_registered_member" ON public."archived_tasks" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "archived_tasks_update_admin_or_assignee" ON public."archived_tasks" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((current_member_id() IS NOT NULL) AND ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])) OR (assignee_id = current_member_id())))) WITH CHECK (((current_member_id() IS NOT NULL) AND ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])) OR (assignee_id = current_member_id()))));
CREATE POLICY "community_settings_admin_delete" ON public."community_settings" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "community_settings_admin_insert" ON public."community_settings" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "community_settings_admin_update" ON public."community_settings" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "community_settings_read_authenticated" ON public."community_settings" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);
CREATE POLICY "event_speakers_admin_all" ON public."event_speakers" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "event_speakers_read_authenticated" ON public."event_speakers" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);
CREATE POLICY "event_staff_admin_all" ON public."event_staff" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "event_staff_read_authenticated" ON public."event_staff" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);
CREATE POLICY "events_admin_delete" ON public."events" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "events_admin_insert" ON public."events" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "events_admin_update" ON public."events" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "events_read_authenticated" ON public."events" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);
CREATE POLICY "manual_emails_admin_only" ON public."manual_emails" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "anon can read member_announcements by profile token" ON public."member_announcements" AS PERMISSIVE FOR SELECT TO "anon" USING ((profile_id IN ( SELECT profiles.id
   FROM profiles
  WHERE (profiles.access_token = current_profile_token()))));
CREATE POLICY "anon can read member_areas by profile token" ON public."member_areas" AS PERMISSIVE FOR SELECT TO "anon" USING ((profile_id IN ( SELECT profiles.id
   FROM profiles
  WHERE (profiles.access_token = current_profile_token()))));
CREATE POLICY "anon can read member_attachments by profile token" ON public."member_attachments" AS PERMISSIVE FOR SELECT TO "anon" USING ((profile_id IN ( SELECT profiles.id
   FROM profiles
  WHERE (profiles.access_token = current_profile_token()))));
CREATE POLICY "members_delete_admin" ON public."members" AS PERMISSIVE FOR DELETE TO "authenticated" USING (((current_member_role() = 'Super Admin'::text) OR ((current_member_role() = 'Admin'::text) AND ((system_role)::text <> 'Super Admin'::text))));
CREATE POLICY "members_insert_admin" ON public."members" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "members_read_authenticated" ON public."members" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "members_update_admin" ON public."members" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((current_member_role() = 'Super Admin'::text) OR ((current_member_role() = 'Admin'::text) AND ((system_role)::text <> 'Super Admin'::text)))) WITH CHECK (((current_member_role() = 'Super Admin'::text) OR ((current_member_role() = 'Admin'::text) AND ((system_role)::text <> 'Super Admin'::text))));
CREATE POLICY "menu_items_admin_all" ON public."menu_items" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "menu_items_read_authenticated" ON public."menu_items" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);
CREATE POLICY "notifications_delete_own_or_admin" ON public."notifications" AS PERMISSIVE FOR DELETE TO "authenticated" USING (((user_id = current_member_id()) OR (current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))));
CREATE POLICY "notifications_insert_self_or_admin" ON public."notifications" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])) OR ((user_id = current_member_id()) AND (actor_id = current_member_id()))));
CREATE POLICY "notifications_read_own_or_admin" ON public."notifications" AS PERMISSIVE FOR SELECT TO "authenticated" USING (((user_id = current_member_id()) OR (current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))));
CREATE POLICY "notifications_update_own_or_admin" ON public."notifications" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((user_id = current_member_id()) OR (current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])))) WITH CHECK (((user_id = current_member_id()) OR (current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))));
CREATE POLICY "org_area_members_admin_all" ON public."org_area_members" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "org_area_members_read_authenticated" ON public."org_area_members" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "org_areas_admin_all" ON public."org_areas" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "org_areas_read_authenticated" ON public."org_areas" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "org_department_members_admin_all" ON public."org_department_members" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "org_department_members_read_authenticated" ON public."org_department_members" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "org_departments_admin_all" ON public."org_departments" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "org_departments_read_authenticated" ON public."org_departments" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "org_project_members_admin_all" ON public."org_project_members" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "org_project_members_read_authenticated" ON public."org_project_members" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "org_projects_admin_all" ON public."org_projects" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "org_projects_read_authenticated" ON public."org_projects" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "anon can read profile by token" ON public."profiles" AS PERMISSIVE FOR SELECT TO "anon" USING ((access_token = current_profile_token()));
CREATE POLICY "speakers_admin_manage" ON public."speakers" AS PERMISSIVE FOR ALL TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "speakers_read_registered_member" ON public."speakers" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "tasks_delete_admin_or_assignee" ON public."tasks" AS PERMISSIVE FOR DELETE TO "authenticated" USING (((current_member_id() IS NOT NULL) AND ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])) OR (assignee_id = current_member_id()))));
CREATE POLICY "tasks_insert_admin_or_self" ON public."tasks" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK (((current_member_id() IS NOT NULL) AND ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])) OR (assignee_id = current_member_id()))));
CREATE POLICY "tasks_read_authenticated" ON public."tasks" AS PERMISSIVE FOR SELECT TO "authenticated" USING ((current_member_id() IS NOT NULL));
CREATE POLICY "tasks_update_admin_or_assignee" ON public."tasks" AS PERMISSIVE FOR UPDATE TO "authenticated" USING (((current_member_id() IS NOT NULL) AND ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])) OR (assignee_id = current_member_id())))) WITH CHECK (((current_member_id() IS NOT NULL) AND ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])) OR (assignee_id = current_member_id()))));
CREATE POLICY "useful_links_delete_admin" ON public."useful_links" AS PERMISSIVE FOR DELETE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "useful_links_insert_admin" ON public."useful_links" AS PERMISSIVE FOR INSERT TO "authenticated" WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
CREATE POLICY "useful_links_read_authenticated" ON public."useful_links" AS PERMISSIVE FOR SELECT TO "authenticated" USING (true);
CREATE POLICY "useful_links_update_admin" ON public."useful_links" AS PERMISSIVE FOR UPDATE TO "authenticated" USING ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text]))) WITH CHECK ((current_member_role() = ANY (ARRAY['Super Admin'::text, 'Admin'::text])));
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC, anon, authenticated;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO service_role;
GRANT DELETE ON public."announcement_members" TO "authenticated";
GRANT INSERT ON public."announcement_members" TO "authenticated";
GRANT REFERENCES ON public."announcement_members" TO "authenticated";
GRANT SELECT ON public."announcement_members" TO "authenticated";
GRANT TRIGGER ON public."announcement_members" TO "authenticated";
GRANT TRUNCATE ON public."announcement_members" TO "authenticated";
GRANT UPDATE ON public."announcement_members" TO "authenticated";
GRANT DELETE ON public."announcement_members" TO "service_role";
GRANT INSERT ON public."announcement_members" TO "service_role";
GRANT REFERENCES ON public."announcement_members" TO "service_role";
GRANT SELECT ON public."announcement_members" TO "service_role";
GRANT TRIGGER ON public."announcement_members" TO "service_role";
GRANT TRUNCATE ON public."announcement_members" TO "service_role";
GRANT UPDATE ON public."announcement_members" TO "service_role";
GRANT DELETE ON public."announcements" TO "authenticated";
GRANT INSERT ON public."announcements" TO "authenticated";
GRANT REFERENCES ON public."announcements" TO "authenticated";
GRANT SELECT ON public."announcements" TO "authenticated";
GRANT TRIGGER ON public."announcements" TO "authenticated";
GRANT TRUNCATE ON public."announcements" TO "authenticated";
GRANT UPDATE ON public."announcements" TO "authenticated";
GRANT DELETE ON public."announcements" TO "service_role";
GRANT INSERT ON public."announcements" TO "service_role";
GRANT REFERENCES ON public."announcements" TO "service_role";
GRANT SELECT ON public."announcements" TO "service_role";
GRANT TRIGGER ON public."announcements" TO "service_role";
GRANT TRUNCATE ON public."announcements" TO "service_role";
GRANT UPDATE ON public."announcements" TO "service_role";
GRANT DELETE ON public."archived_tasks" TO "authenticated";
GRANT INSERT ON public."archived_tasks" TO "authenticated";
GRANT SELECT ON public."archived_tasks" TO "authenticated";
GRANT UPDATE ON public."archived_tasks" TO "authenticated";
GRANT DELETE ON public."archived_tasks" TO "service_role";
GRANT INSERT ON public."archived_tasks" TO "service_role";
GRANT REFERENCES ON public."archived_tasks" TO "service_role";
GRANT SELECT ON public."archived_tasks" TO "service_role";
GRANT TRIGGER ON public."archived_tasks" TO "service_role";
GRANT TRUNCATE ON public."archived_tasks" TO "service_role";
GRANT UPDATE ON public."archived_tasks" TO "service_role";
GRANT DELETE ON public."birthday_email_deliveries" TO "service_role";
GRANT INSERT ON public."birthday_email_deliveries" TO "service_role";
GRANT REFERENCES ON public."birthday_email_deliveries" TO "service_role";
GRANT SELECT ON public."birthday_email_deliveries" TO "service_role";
GRANT TRIGGER ON public."birthday_email_deliveries" TO "service_role";
GRANT TRUNCATE ON public."birthday_email_deliveries" TO "service_role";
GRANT UPDATE ON public."birthday_email_deliveries" TO "service_role";
GRANT DELETE ON public."birthday_notifications" TO "service_role";
GRANT INSERT ON public."birthday_notifications" TO "service_role";
GRANT REFERENCES ON public."birthday_notifications" TO "service_role";
GRANT SELECT ON public."birthday_notifications" TO "service_role";
GRANT TRIGGER ON public."birthday_notifications" TO "service_role";
GRANT TRUNCATE ON public."birthday_notifications" TO "service_role";
GRANT UPDATE ON public."birthday_notifications" TO "service_role";
GRANT DELETE ON public."community_settings" TO "authenticated";
GRANT INSERT ON public."community_settings" TO "authenticated";
GRANT REFERENCES ON public."community_settings" TO "authenticated";
GRANT SELECT ON public."community_settings" TO "authenticated";
GRANT TRIGGER ON public."community_settings" TO "authenticated";
GRANT TRUNCATE ON public."community_settings" TO "authenticated";
GRANT UPDATE ON public."community_settings" TO "authenticated";
GRANT DELETE ON public."community_settings" TO "service_role";
GRANT INSERT ON public."community_settings" TO "service_role";
GRANT REFERENCES ON public."community_settings" TO "service_role";
GRANT SELECT ON public."community_settings" TO "service_role";
GRANT TRIGGER ON public."community_settings" TO "service_role";
GRANT TRUNCATE ON public."community_settings" TO "service_role";
GRANT UPDATE ON public."community_settings" TO "service_role";
GRANT DELETE ON public."email_queue" TO "service_role";
GRANT INSERT ON public."email_queue" TO "service_role";
GRANT REFERENCES ON public."email_queue" TO "service_role";
GRANT SELECT ON public."email_queue" TO "service_role";
GRANT TRIGGER ON public."email_queue" TO "service_role";
GRANT TRUNCATE ON public."email_queue" TO "service_role";
GRANT UPDATE ON public."email_queue" TO "service_role";
GRANT DELETE ON public."email_send_logs" TO "service_role";
GRANT INSERT ON public."email_send_logs" TO "service_role";
GRANT REFERENCES ON public."email_send_logs" TO "service_role";
GRANT SELECT ON public."email_send_logs" TO "service_role";
GRANT TRIGGER ON public."email_send_logs" TO "service_role";
GRANT TRUNCATE ON public."email_send_logs" TO "service_role";
GRANT UPDATE ON public."email_send_logs" TO "service_role";
GRANT DELETE ON public."email_settings" TO "service_role";
GRANT INSERT ON public."email_settings" TO "service_role";
GRANT REFERENCES ON public."email_settings" TO "service_role";
GRANT SELECT ON public."email_settings" TO "service_role";
GRANT TRIGGER ON public."email_settings" TO "service_role";
GRANT TRUNCATE ON public."email_settings" TO "service_role";
GRANT UPDATE ON public."email_settings" TO "service_role";
GRANT DELETE ON public."email_templates" TO "service_role";
GRANT INSERT ON public."email_templates" TO "service_role";
GRANT REFERENCES ON public."email_templates" TO "service_role";
GRANT SELECT ON public."email_templates" TO "service_role";
GRANT TRIGGER ON public."email_templates" TO "service_role";
GRANT TRUNCATE ON public."email_templates" TO "service_role";
GRANT UPDATE ON public."email_templates" TO "service_role";
GRANT DELETE ON public."event_speakers" TO "authenticated";
GRANT INSERT ON public."event_speakers" TO "authenticated";
GRANT REFERENCES ON public."event_speakers" TO "authenticated";
GRANT SELECT ON public."event_speakers" TO "authenticated";
GRANT TRIGGER ON public."event_speakers" TO "authenticated";
GRANT TRUNCATE ON public."event_speakers" TO "authenticated";
GRANT UPDATE ON public."event_speakers" TO "authenticated";
GRANT DELETE ON public."event_speakers" TO "service_role";
GRANT INSERT ON public."event_speakers" TO "service_role";
GRANT REFERENCES ON public."event_speakers" TO "service_role";
GRANT SELECT ON public."event_speakers" TO "service_role";
GRANT TRIGGER ON public."event_speakers" TO "service_role";
GRANT TRUNCATE ON public."event_speakers" TO "service_role";
GRANT UPDATE ON public."event_speakers" TO "service_role";
GRANT DELETE ON public."event_staff" TO "authenticated";
GRANT INSERT ON public."event_staff" TO "authenticated";
GRANT REFERENCES ON public."event_staff" TO "authenticated";
GRANT SELECT ON public."event_staff" TO "authenticated";
GRANT TRIGGER ON public."event_staff" TO "authenticated";
GRANT TRUNCATE ON public."event_staff" TO "authenticated";
GRANT UPDATE ON public."event_staff" TO "authenticated";
GRANT DELETE ON public."event_staff" TO "service_role";
GRANT INSERT ON public."event_staff" TO "service_role";
GRANT REFERENCES ON public."event_staff" TO "service_role";
GRANT SELECT ON public."event_staff" TO "service_role";
GRANT TRIGGER ON public."event_staff" TO "service_role";
GRANT TRUNCATE ON public."event_staff" TO "service_role";
GRANT UPDATE ON public."event_staff" TO "service_role";
GRANT DELETE ON public."events" TO "authenticated";
GRANT INSERT ON public."events" TO "authenticated";
GRANT REFERENCES ON public."events" TO "authenticated";
GRANT SELECT ON public."events" TO "authenticated";
GRANT TRIGGER ON public."events" TO "authenticated";
GRANT TRUNCATE ON public."events" TO "authenticated";
GRANT UPDATE ON public."events" TO "authenticated";
GRANT DELETE ON public."events" TO "service_role";
GRANT INSERT ON public."events" TO "service_role";
GRANT REFERENCES ON public."events" TO "service_role";
GRANT SELECT ON public."events" TO "service_role";
GRANT TRIGGER ON public."events" TO "service_role";
GRANT TRUNCATE ON public."events" TO "service_role";
GRANT UPDATE ON public."events" TO "service_role";
GRANT DELETE ON public."manual_emails" TO "authenticated";
GRANT INSERT ON public."manual_emails" TO "authenticated";
GRANT SELECT ON public."manual_emails" TO "authenticated";
GRANT UPDATE ON public."manual_emails" TO "authenticated";
GRANT DELETE ON public."manual_emails" TO "service_role";
GRANT INSERT ON public."manual_emails" TO "service_role";
GRANT REFERENCES ON public."manual_emails" TO "service_role";
GRANT SELECT ON public."manual_emails" TO "service_role";
GRANT TRIGGER ON public."manual_emails" TO "service_role";
GRANT TRUNCATE ON public."manual_emails" TO "service_role";
GRANT UPDATE ON public."manual_emails" TO "service_role";
GRANT DELETE ON public."member_announcements" TO "anon";
GRANT INSERT ON public."member_announcements" TO "anon";
GRANT REFERENCES ON public."member_announcements" TO "anon";
GRANT SELECT ON public."member_announcements" TO "anon";
GRANT TRIGGER ON public."member_announcements" TO "anon";
GRANT TRUNCATE ON public."member_announcements" TO "anon";
GRANT UPDATE ON public."member_announcements" TO "anon";
GRANT DELETE ON public."member_announcements" TO "authenticated";
GRANT INSERT ON public."member_announcements" TO "authenticated";
GRANT REFERENCES ON public."member_announcements" TO "authenticated";
GRANT SELECT ON public."member_announcements" TO "authenticated";
GRANT TRIGGER ON public."member_announcements" TO "authenticated";
GRANT TRUNCATE ON public."member_announcements" TO "authenticated";
GRANT UPDATE ON public."member_announcements" TO "authenticated";
GRANT DELETE ON public."member_announcements" TO "service_role";
GRANT INSERT ON public."member_announcements" TO "service_role";
GRANT REFERENCES ON public."member_announcements" TO "service_role";
GRANT SELECT ON public."member_announcements" TO "service_role";
GRANT TRIGGER ON public."member_announcements" TO "service_role";
GRANT TRUNCATE ON public."member_announcements" TO "service_role";
GRANT UPDATE ON public."member_announcements" TO "service_role";
GRANT DELETE ON public."member_areas" TO "anon";
GRANT INSERT ON public."member_areas" TO "anon";
GRANT REFERENCES ON public."member_areas" TO "anon";
GRANT SELECT ON public."member_areas" TO "anon";
GRANT TRIGGER ON public."member_areas" TO "anon";
GRANT TRUNCATE ON public."member_areas" TO "anon";
GRANT UPDATE ON public."member_areas" TO "anon";
GRANT DELETE ON public."member_areas" TO "authenticated";
GRANT INSERT ON public."member_areas" TO "authenticated";
GRANT REFERENCES ON public."member_areas" TO "authenticated";
GRANT SELECT ON public."member_areas" TO "authenticated";
GRANT TRIGGER ON public."member_areas" TO "authenticated";
GRANT TRUNCATE ON public."member_areas" TO "authenticated";
GRANT UPDATE ON public."member_areas" TO "authenticated";
GRANT DELETE ON public."member_areas" TO "service_role";
GRANT INSERT ON public."member_areas" TO "service_role";
GRANT REFERENCES ON public."member_areas" TO "service_role";
GRANT SELECT ON public."member_areas" TO "service_role";
GRANT TRIGGER ON public."member_areas" TO "service_role";
GRANT TRUNCATE ON public."member_areas" TO "service_role";
GRANT UPDATE ON public."member_areas" TO "service_role";
GRANT DELETE ON public."member_attachments" TO "anon";
GRANT INSERT ON public."member_attachments" TO "anon";
GRANT REFERENCES ON public."member_attachments" TO "anon";
GRANT SELECT ON public."member_attachments" TO "anon";
GRANT TRIGGER ON public."member_attachments" TO "anon";
GRANT TRUNCATE ON public."member_attachments" TO "anon";
GRANT UPDATE ON public."member_attachments" TO "anon";
GRANT DELETE ON public."member_attachments" TO "authenticated";
GRANT INSERT ON public."member_attachments" TO "authenticated";
GRANT REFERENCES ON public."member_attachments" TO "authenticated";
GRANT SELECT ON public."member_attachments" TO "authenticated";
GRANT TRIGGER ON public."member_attachments" TO "authenticated";
GRANT TRUNCATE ON public."member_attachments" TO "authenticated";
GRANT UPDATE ON public."member_attachments" TO "authenticated";
GRANT DELETE ON public."member_attachments" TO "service_role";
GRANT INSERT ON public."member_attachments" TO "service_role";
GRANT REFERENCES ON public."member_attachments" TO "service_role";
GRANT SELECT ON public."member_attachments" TO "service_role";
GRANT TRIGGER ON public."member_attachments" TO "service_role";
GRANT TRUNCATE ON public."member_attachments" TO "service_role";
GRANT UPDATE ON public."member_attachments" TO "service_role";
GRANT DELETE ON public."members" TO "authenticated";
GRANT INSERT ON public."members" TO "authenticated";
GRANT REFERENCES ON public."members" TO "authenticated";
GRANT SELECT ON public."members" TO "authenticated";
GRANT TRIGGER ON public."members" TO "authenticated";
GRANT TRUNCATE ON public."members" TO "authenticated";
GRANT UPDATE ON public."members" TO "authenticated";
GRANT DELETE ON public."members" TO "service_role";
GRANT INSERT ON public."members" TO "service_role";
GRANT REFERENCES ON public."members" TO "service_role";
GRANT SELECT ON public."members" TO "service_role";
GRANT TRIGGER ON public."members" TO "service_role";
GRANT TRUNCATE ON public."members" TO "service_role";
GRANT UPDATE ON public."members" TO "service_role";
GRANT DELETE ON public."menu_items" TO "authenticated";
GRANT INSERT ON public."menu_items" TO "authenticated";
GRANT REFERENCES ON public."menu_items" TO "authenticated";
GRANT SELECT ON public."menu_items" TO "authenticated";
GRANT TRIGGER ON public."menu_items" TO "authenticated";
GRANT TRUNCATE ON public."menu_items" TO "authenticated";
GRANT UPDATE ON public."menu_items" TO "authenticated";
GRANT DELETE ON public."menu_items" TO "service_role";
GRANT INSERT ON public."menu_items" TO "service_role";
GRANT REFERENCES ON public."menu_items" TO "service_role";
GRANT SELECT ON public."menu_items" TO "service_role";
GRANT TRIGGER ON public."menu_items" TO "service_role";
GRANT TRUNCATE ON public."menu_items" TO "service_role";
GRANT UPDATE ON public."menu_items" TO "service_role";
GRANT DELETE ON public."notifications" TO "authenticated";
GRANT INSERT ON public."notifications" TO "authenticated";
GRANT REFERENCES ON public."notifications" TO "authenticated";
GRANT SELECT ON public."notifications" TO "authenticated";
GRANT TRIGGER ON public."notifications" TO "authenticated";
GRANT TRUNCATE ON public."notifications" TO "authenticated";
GRANT UPDATE ON public."notifications" TO "authenticated";
GRANT DELETE ON public."notifications" TO "service_role";
GRANT INSERT ON public."notifications" TO "service_role";
GRANT REFERENCES ON public."notifications" TO "service_role";
GRANT SELECT ON public."notifications" TO "service_role";
GRANT TRIGGER ON public."notifications" TO "service_role";
GRANT TRUNCATE ON public."notifications" TO "service_role";
GRANT UPDATE ON public."notifications" TO "service_role";
GRANT DELETE ON public."org_area_members" TO "authenticated";
GRANT INSERT ON public."org_area_members" TO "authenticated";
GRANT REFERENCES ON public."org_area_members" TO "authenticated";
GRANT SELECT ON public."org_area_members" TO "authenticated";
GRANT TRIGGER ON public."org_area_members" TO "authenticated";
GRANT TRUNCATE ON public."org_area_members" TO "authenticated";
GRANT UPDATE ON public."org_area_members" TO "authenticated";
GRANT DELETE ON public."org_area_members" TO "service_role";
GRANT INSERT ON public."org_area_members" TO "service_role";
GRANT REFERENCES ON public."org_area_members" TO "service_role";
GRANT SELECT ON public."org_area_members" TO "service_role";
GRANT TRIGGER ON public."org_area_members" TO "service_role";
GRANT TRUNCATE ON public."org_area_members" TO "service_role";
GRANT UPDATE ON public."org_area_members" TO "service_role";
GRANT DELETE ON public."org_areas" TO "authenticated";
GRANT INSERT ON public."org_areas" TO "authenticated";
GRANT REFERENCES ON public."org_areas" TO "authenticated";
GRANT SELECT ON public."org_areas" TO "authenticated";
GRANT TRIGGER ON public."org_areas" TO "authenticated";
GRANT TRUNCATE ON public."org_areas" TO "authenticated";
GRANT UPDATE ON public."org_areas" TO "authenticated";
GRANT DELETE ON public."org_areas" TO "service_role";
GRANT INSERT ON public."org_areas" TO "service_role";
GRANT REFERENCES ON public."org_areas" TO "service_role";
GRANT SELECT ON public."org_areas" TO "service_role";
GRANT TRIGGER ON public."org_areas" TO "service_role";
GRANT TRUNCATE ON public."org_areas" TO "service_role";
GRANT UPDATE ON public."org_areas" TO "service_role";
GRANT DELETE ON public."org_department_members" TO "authenticated";
GRANT INSERT ON public."org_department_members" TO "authenticated";
GRANT REFERENCES ON public."org_department_members" TO "authenticated";
GRANT SELECT ON public."org_department_members" TO "authenticated";
GRANT TRIGGER ON public."org_department_members" TO "authenticated";
GRANT TRUNCATE ON public."org_department_members" TO "authenticated";
GRANT UPDATE ON public."org_department_members" TO "authenticated";
GRANT DELETE ON public."org_department_members" TO "service_role";
GRANT INSERT ON public."org_department_members" TO "service_role";
GRANT REFERENCES ON public."org_department_members" TO "service_role";
GRANT SELECT ON public."org_department_members" TO "service_role";
GRANT TRIGGER ON public."org_department_members" TO "service_role";
GRANT TRUNCATE ON public."org_department_members" TO "service_role";
GRANT UPDATE ON public."org_department_members" TO "service_role";
GRANT DELETE ON public."org_departments" TO "authenticated";
GRANT INSERT ON public."org_departments" TO "authenticated";
GRANT REFERENCES ON public."org_departments" TO "authenticated";
GRANT SELECT ON public."org_departments" TO "authenticated";
GRANT TRIGGER ON public."org_departments" TO "authenticated";
GRANT TRUNCATE ON public."org_departments" TO "authenticated";
GRANT UPDATE ON public."org_departments" TO "authenticated";
GRANT DELETE ON public."org_departments" TO "service_role";
GRANT INSERT ON public."org_departments" TO "service_role";
GRANT REFERENCES ON public."org_departments" TO "service_role";
GRANT SELECT ON public."org_departments" TO "service_role";
GRANT TRIGGER ON public."org_departments" TO "service_role";
GRANT TRUNCATE ON public."org_departments" TO "service_role";
GRANT UPDATE ON public."org_departments" TO "service_role";
GRANT DELETE ON public."org_project_members" TO "authenticated";
GRANT INSERT ON public."org_project_members" TO "authenticated";
GRANT REFERENCES ON public."org_project_members" TO "authenticated";
GRANT SELECT ON public."org_project_members" TO "authenticated";
GRANT TRIGGER ON public."org_project_members" TO "authenticated";
GRANT TRUNCATE ON public."org_project_members" TO "authenticated";
GRANT UPDATE ON public."org_project_members" TO "authenticated";
GRANT DELETE ON public."org_project_members" TO "service_role";
GRANT INSERT ON public."org_project_members" TO "service_role";
GRANT REFERENCES ON public."org_project_members" TO "service_role";
GRANT SELECT ON public."org_project_members" TO "service_role";
GRANT TRIGGER ON public."org_project_members" TO "service_role";
GRANT TRUNCATE ON public."org_project_members" TO "service_role";
GRANT UPDATE ON public."org_project_members" TO "service_role";
GRANT DELETE ON public."org_projects" TO "authenticated";
GRANT INSERT ON public."org_projects" TO "authenticated";
GRANT REFERENCES ON public."org_projects" TO "authenticated";
GRANT SELECT ON public."org_projects" TO "authenticated";
GRANT TRIGGER ON public."org_projects" TO "authenticated";
GRANT TRUNCATE ON public."org_projects" TO "authenticated";
GRANT UPDATE ON public."org_projects" TO "authenticated";
GRANT DELETE ON public."org_projects" TO "service_role";
GRANT INSERT ON public."org_projects" TO "service_role";
GRANT REFERENCES ON public."org_projects" TO "service_role";
GRANT SELECT ON public."org_projects" TO "service_role";
GRANT TRIGGER ON public."org_projects" TO "service_role";
GRANT TRUNCATE ON public."org_projects" TO "service_role";
GRANT UPDATE ON public."org_projects" TO "service_role";
GRANT DELETE ON public."profiles" TO "anon";
GRANT INSERT ON public."profiles" TO "anon";
GRANT REFERENCES ON public."profiles" TO "anon";
GRANT SELECT ON public."profiles" TO "anon";
GRANT TRIGGER ON public."profiles" TO "anon";
GRANT TRUNCATE ON public."profiles" TO "anon";
GRANT UPDATE ON public."profiles" TO "anon";
GRANT DELETE ON public."profiles" TO "authenticated";
GRANT INSERT ON public."profiles" TO "authenticated";
GRANT REFERENCES ON public."profiles" TO "authenticated";
GRANT SELECT ON public."profiles" TO "authenticated";
GRANT TRIGGER ON public."profiles" TO "authenticated";
GRANT TRUNCATE ON public."profiles" TO "authenticated";
GRANT UPDATE ON public."profiles" TO "authenticated";
GRANT DELETE ON public."profiles" TO "service_role";
GRANT INSERT ON public."profiles" TO "service_role";
GRANT REFERENCES ON public."profiles" TO "service_role";
GRANT SELECT ON public."profiles" TO "service_role";
GRANT TRIGGER ON public."profiles" TO "service_role";
GRANT TRUNCATE ON public."profiles" TO "service_role";
GRANT UPDATE ON public."profiles" TO "service_role";
GRANT DELETE ON public."speaker_email_queue" TO "service_role";
GRANT INSERT ON public."speaker_email_queue" TO "service_role";
GRANT REFERENCES ON public."speaker_email_queue" TO "service_role";
GRANT SELECT ON public."speaker_email_queue" TO "service_role";
GRANT TRIGGER ON public."speaker_email_queue" TO "service_role";
GRANT TRUNCATE ON public."speaker_email_queue" TO "service_role";
GRANT UPDATE ON public."speaker_email_queue" TO "service_role";
GRANT DELETE ON public."speakers" TO "authenticated";
GRANT INSERT ON public."speakers" TO "authenticated";
GRANT SELECT ON public."speakers" TO "authenticated";
GRANT UPDATE ON public."speakers" TO "authenticated";
GRANT DELETE ON public."speakers" TO "service_role";
GRANT INSERT ON public."speakers" TO "service_role";
GRANT REFERENCES ON public."speakers" TO "service_role";
GRANT SELECT ON public."speakers" TO "service_role";
GRANT TRIGGER ON public."speakers" TO "service_role";
GRANT TRUNCATE ON public."speakers" TO "service_role";
GRANT UPDATE ON public."speakers" TO "service_role";
GRANT DELETE ON public."tasks" TO "authenticated";
GRANT INSERT ON public."tasks" TO "authenticated";
GRANT REFERENCES ON public."tasks" TO "authenticated";
GRANT SELECT ON public."tasks" TO "authenticated";
GRANT TRIGGER ON public."tasks" TO "authenticated";
GRANT TRUNCATE ON public."tasks" TO "authenticated";
GRANT UPDATE ON public."tasks" TO "authenticated";
GRANT DELETE ON public."tasks" TO "service_role";
GRANT INSERT ON public."tasks" TO "service_role";
GRANT REFERENCES ON public."tasks" TO "service_role";
GRANT SELECT ON public."tasks" TO "service_role";
GRANT TRIGGER ON public."tasks" TO "service_role";
GRANT TRUNCATE ON public."tasks" TO "service_role";
GRANT UPDATE ON public."tasks" TO "service_role";
GRANT DELETE ON public."useful_links" TO "authenticated";
GRANT INSERT ON public."useful_links" TO "authenticated";
GRANT REFERENCES ON public."useful_links" TO "authenticated";
GRANT SELECT ON public."useful_links" TO "authenticated";
GRANT TRIGGER ON public."useful_links" TO "authenticated";
GRANT TRUNCATE ON public."useful_links" TO "authenticated";
GRANT UPDATE ON public."useful_links" TO "authenticated";
GRANT DELETE ON public."useful_links" TO "service_role";
GRANT INSERT ON public."useful_links" TO "service_role";
GRANT REFERENCES ON public."useful_links" TO "service_role";
GRANT SELECT ON public."useful_links" TO "service_role";
GRANT TRIGGER ON public."useful_links" TO "service_role";
GRANT TRUNCATE ON public."useful_links" TO "service_role";
GRANT UPDATE ON public."useful_links" TO "service_role";
GRANT EXECUTE ON FUNCTION public."guard_member_role_change"() TO "anon";
GRANT EXECUTE ON FUNCTION public."guard_member_role_change"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."guard_member_role_change"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."guard_task_updates"() TO "anon";
GRANT EXECUTE ON FUNCTION public."guard_task_updates"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."guard_task_updates"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."current_member_role"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."current_member_role"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_task_assigned"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trigger_set_updated_at"() TO "anon";
GRANT EXECUTE ON FUNCTION public."trigger_set_updated_at"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."trigger_set_updated_at"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."email_settings_set_updated_at"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."update_updated_at_column"() TO "anon";
GRANT EXECUTE ON FUNCTION public."update_updated_at_column"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."update_updated_at_column"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."email_queue_set_updated_at"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_announcement_general"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."current_member_id"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."current_member_id"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."enforce_task_limit"() TO "anon";
GRANT EXECUTE ON FUNCTION public."enforce_task_limit"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."enforce_task_limit"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."current_profile_token"() TO "anon";
GRANT EXECUTE ON FUNCTION public."current_profile_token"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."current_profile_token"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."enforce_max_total_tasks"() TO "anon";
GRANT EXECUTE ON FUNCTION public."enforce_max_total_tasks"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."enforce_max_total_tasks"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."update_events_updated_at"() TO "anon";
GRANT EXECUTE ON FUNCTION public."update_events_updated_at"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."update_events_updated_at"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."set_updated_at_utc"() TO "anon";
GRANT EXECUTE ON FUNCTION public."set_updated_at_utc"() TO "authenticated";
GRANT EXECUTE ON FUNCTION public."set_updated_at_utc"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."notify_task_added"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."notify_task_deleted"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."notify_task_completed"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."notify_member_added"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."cancel_stale_birthday_jobs_on_date_change"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."notify_member_removed"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_member_area_assigned"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_speaker_invite"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_announcement_member"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_event_staff_member"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_event_speaker"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_welcome_member"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."send_speaker_welcome"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_project_member"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_department_member"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."trg_enqueue_area_member"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."handle_task_assignment_and_limit"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."archive_done_tasks_older_than_7_days"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."archive_single_task"(p_task_id uuid) TO "service_role";
GRANT EXECUTE ON FUNCTION public."enqueue_email"(p_recipient_email character varying, p_recipient_name character varying, p_template_code character varying, p_template_params jsonb, p_priority email_priority_enum) TO "service_role";
GRANT EXECUTE ON FUNCTION public."process_speaker_email_queue"() TO "service_role";
GRANT EXECUTE ON FUNCTION public."record_birthday_email_delivery"(p_queue_id bigint, p_birthday_person_id uuid, p_notification_year integer, p_channel text) TO "service_role";
GRANT EXECUTE ON FUNCTION public."enqueue_birthday_emails"(p_personal_only boolean) TO "service_role";
SET check_function_bodies = true;

