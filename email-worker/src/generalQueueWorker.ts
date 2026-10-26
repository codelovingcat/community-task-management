import type { EmailSettings, EmailTemplate, BrevoSendPayload } from './types';
import { loadEmailSettings } from './settingsLoader';
import { getSupabaseClient } from './supabaseClient';
import { normalizeTemplateParams, renderSubject, renderTemplate } from './templateEngine';
import { sendEmail } from './brevo';

type GeneralQueueItem = {
  id: number;
  recipient_email: string;
  recipient_name: string | null;
  template_code: string;
  template_params: Record<string, unknown> | null;
  attempt_count: number;
};

function log(message: string): void {
  console.log('[EmailWorker][general] ' + message);
}

async function getTemplate(code: string): Promise<EmailTemplate | null> {
  const { data, error } = await getSupabaseClient()
    .from('email_templates')
    .select('*')
    .eq('template_code', code)
    .eq('is_active', true)
    .maybeSingle();
  if (error) throw new Error(error.message);
  return (data as EmailTemplate | null) ?? null;
}

async function insertLog(item: GeneralQueueItem, eventType: 'sent' | 'failed', eventData: Record<string, unknown>): Promise<void> {
  const { error } = await getSupabaseClient().from('email_send_logs').insert({
    queue_id: item.id,
    speaker_queue_id: null,
    recipient_email: item.recipient_email,
    template_code: item.template_code,
    event_type: eventType,
    event_data: eventData
  } as never);
  if (error) throw new Error(error.message);
}

async function updateQueue(id: number, values: Record<string, unknown>): Promise<void> {
  const { error } = await getSupabaseClient().from('email_queue').update(values as never).eq('id', id);
  if (error) throw new Error(error.message);
}

function missingTemplateParams(source: string, params: Record<string, string>): string[] {
  const names = new Set<string>();
  const pattern = /{{\\s*([^}]+?)\\s*}}/g;
  let match: RegExpExecArray | null;
  while ((match = pattern.exec(source)) !== null) {
    const name = match[1].trim();
    if (!params[name]?.trim()) names.add(name);
  }
  return Array.from(names);
}

function buildPayload(settings: EmailSettings, item: GeneralQueueItem, template: EmailTemplate, params: Record<string, string>): BrevoSendPayload {
  const subject = renderSubject(template.subject, params);
  const html = renderTemplate(template.html_content, params);
  const base: BrevoSendPayload = {
    sender: { name: settings.sender_name, email: settings.sender_email },
    to: [{ email: item.recipient_email, name: item.recipient_name ?? undefined }],
    subject,
    htmlContent: html
  };
  if (template.brevo_template_id != null) {
    return {
      sender: base.sender,
      to: base.to,
      subject: '',
      htmlContent: '',
      templateId: template.brevo_template_id,
      params
    };
  }
  return base;
}

async function fetchPending(settings: EmailSettings, limit: number): Promise<GeneralQueueItem[]> {
  const { data, error } = await getSupabaseClient()
    .from('email_queue')
    .select('id, recipient_email, recipient_name, template_code, template_params, attempt_count')
    .eq('status', 'pending')
    .lte('next_attempt_at', new Date().toISOString())
    .lt('attempt_count', settings.retry_limit)
    .order('priority', { ascending: false })
    .order('created_at', { ascending: true })
    .limit(limit);
  if (error) throw new Error(error.message);
  return (data ?? []) as unknown as GeneralQueueItem[];
}

export async function processGeneralEmailQueue(): Promise<void> {
  const supabase = getSupabaseClient();
  const settings = await loadEmailSettings();
  if (!settings.enabled) return;

  const dayStart = new Date();
  dayStart.setUTCHours(0, 0, 0, 0);
  const { count, error: countError } = await supabase
    .from('email_send_logs')
    .select('id', { count: 'exact', head: true })
    .eq('event_type', 'sent')
    .gte('created_at', dayStart.toISOString());
  if (countError) throw new Error(countError.message);

  const remaining = settings.daily_limit - (count ?? 0);
  if (remaining <= 0) {
    log('Daily send limit reached.');
    return;
  }

  const pending = await fetchPending(settings, Math.min(50, remaining));
  let sent = 0;
  let failed = 0;

  for (const item of pending) {
    const attempt = item.attempt_count + 1;
    let template: EmailTemplate | null;
    try {
      template = await getTemplate(item.template_code);
    } catch (error) {
      log('Template lookup failed for queue #' + item.id + ': ' + String(error));
      continue;
    }

    if (!template) {
      const message = 'Active template not found: ' + item.template_code;
      const status = attempt >= settings.retry_limit ? 'failed' : 'pending';
      await updateQueue(item.id, {
        status,
        attempt_count: attempt,
        last_attempt_at: new Date().toISOString(),
        next_attempt_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
        error_message: message
      });
      try { await insertLog(item, 'failed', { attempt, error: message }); }
      catch (error) { log('Failure log insert failed for queue #' + item.id + ': ' + String(error)); }
      failed += status === 'failed' ? 1 : 0;
      continue;
    }

    const params = normalizeTemplateParams(item.template_params ?? {});
    const missing = Array.from(new Set([
      ...missingTemplateParams(template.subject, params),
      ...missingTemplateParams(template.html_content, params)
    ]));
    if (missing.length) {
      const message = 'Missing required template parameters: ' + missing.join(', ');
      const status = attempt >= settings.retry_limit ? 'failed' : 'pending';
      await updateQueue(item.id, {
        status,
        attempt_count: attempt,
        last_attempt_at: new Date().toISOString(),
        next_attempt_at: new Date(Date.now() + 5 * 60 * 1000).toISOString(),
        error_message: message
      });
      try { await insertLog(item, 'failed', { attempt, error: message }); }
      catch (error) { log('Failure log insert failed for queue #' + item.id + ': ' + String(error)); }
      failed += status === 'failed' ? 1 : 0;
      continue;
    }

    let messageId: string;
    try {
      const payload = buildPayload(settings, item, template, params);
      const response = await sendEmail(payload, settings.brevo_api_key);
      messageId = response.messageId;
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      const statusCode = error && typeof error === 'object' && 'status' in error ? Number((error as {status?: unknown}).status) : undefined;
      const noRetry = statusCode !== undefined && statusCode >= 400 && statusCode < 500;
      const status = noRetry || attempt >= settings.retry_limit ? 'failed' : 'pending';
      await updateQueue(item.id, {
        status,
        attempt_count: attempt,
        last_attempt_at: new Date().toISOString(),
        next_attempt_at: new Date(Date.now() + Math.min(60, 5 * Math.pow(2, attempt - 1)) * 60 * 1000).toISOString(),
        error_message: message
      });
      try { await insertLog(item, 'failed', { attempt, error: message, ...(statusCode ? { statusCode } : {}) }); }
      catch (logError) { log('Failure log insert failed for queue #' + item.id + ': ' + String(logError)); }
      failed += status === 'failed' ? 1 : 0;
      continue;
    }

    // Delivery succeeded. Mark the queue row sent before best-effort logging, so log failures
    // never enter the send-failure/retry branch and do not intentionally requeue this email.
    await updateQueue(item.id, {
      status: 'sent',
      attempt_count: attempt,
      last_attempt_at: new Date().toISOString(),
      sent_at: new Date().toISOString(),
      brevo_message_id: messageId,
      error_message: null
    });
    sent += 1;
    try {
      await insertLog(item, 'sent', { attempt, messageId });
    } catch (error) {
      log('DELIVERY SUCCEEDED but send log insert failed for queue #' + item.id + ': ' + String(error));
    }
  }

  log('General queue complete: sent=' + sent + ', terminal failures=' + failed + ', processed=' + pending.length);
}
