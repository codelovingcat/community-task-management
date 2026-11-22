-- Fresh-install reference data only; no provider configuration or live recipients.
-- Disabled templates satisfy existing enqueue foreign keys without enabling delivery.
INSERT INTO public.email_templates(template_name,template_code,subject,html_content,is_active)
SELECT code,code,'Configure template before enabling delivery','<p>Template configuration required.</p>',false
FROM unnest(ARRAY['welcome_member','task_assigned','announcement_member','announcement_general',
 'project_member','department_member','area_member','speaker_invite','event_speaker',
 'event_staff_member','birthday_personal','birthday_team']) code
ON CONFLICT(template_code) DO NOTHING;
INSERT INTO public.email_settings(setting_key,setting_value) VALUES('enabled','false')
ON CONFLICT(setting_key) DO NOTHING;
