const test = require('node:test');
const assert = require('node:assert/strict');
const clientModule = require('../dist/supabaseClient.js');
const settingsModule = require('../dist/settingsLoader.js');
const brevoModule = require('../dist/brevo.js');
const { processGeneralEmailQueue } = require('../dist/generalQueueWorker.js');

// Synthetic examples derived from the documented enqueue/template contract.
// Provider-hosted templates and production trigger definitions need separate checks.
const contracts = {
  welcome_member: ['member_name', 'join_date'],
  task_assigned: ['member_name', 'task_name', 'deadline'],
  announcement_general: ['member_name', 'announcement_title', 'announcement_description'],
  announcement_member: ['member_name', 'announcement_title', 'announcement_body'],
  project_member: ['member_name', 'project_name'],
  department_member: ['member_name', 'department_name'],
  area_member: ['member_name', 'area_name'],
  member_area_assigned: ['member_name', 'area_name'],
  event_speaker: ['speaker_name', 'event_name', 'event_date', 'event_location'],
  event_staff_member: ['member_name', 'event_name', 'event_date', 'event_location'],
  birthday_personal: ['member_name'],
  birthday_team: ['birthday_person'],
  manual_compose: ['subject', 'html_content'],
  other: ['subject', 'title', 'member_name', 'message'],
};

function fixture(code, names, missing) {
  const params = Object.fromEntries(names.filter((name) => name !== missing).map((name) => [name, `${name} <unsafe>`]));
  const row = { id: 1, recipient_email: 'synthetic@example.invalid', recipient_name: 'Ada', template_code: code,
    template_params: params, attempt_count: 0, status: 'pending', delivery_claim_token: null };
  const template = { template_code: code, subject: 'Notice', html_content: names.map((n) => `<p>{{${n}}}</p>`).join(''),
    brevo_template_id: null, is_active: true };
  const sends = [];
  class Query {
    constructor(table) { this.table = table; this.filters = []; this.action = 'select'; }
    select() { return this; } eq(k, v) { this.filters.push([k, v]); return this; } is(k, v) { this.filters.push([k, v]); return this; }
    in() { return this; } lt() { return this; } lte() { return this; } gte() { return this; } order() { return this; } limit() { return this; }
    update(values) { this.action = 'update'; this.values = values; return this; }
    insert() { return Promise.resolve({ error: null }); }
    execute(single = false) {
      if (this.table === 'email_templates') return { data: this.filters.some(([k, v]) => k === 'template_code' && v === code) ? template : null, error: null };
      if (this.table === 'email_send_logs') return { count: 0, data: [], error: null };
      if (this.table !== 'email_queue') throw new Error('Unexpected table');
      const matches = this.filters.every(([key, value]) => row[key] === value);
      if (matches && this.action === 'update') Object.assign(row, this.values);
      return { data: single ? (matches ? { id: row.id } : null) : (matches ? [row] : []), error: null };
    }
    maybeSingle() { return Promise.resolve(this.execute(true)); }
    then(resolve, reject) { return Promise.resolve(this.execute()).then(resolve, reject); }
  }
  return { row, sends, client: { from: (table) => new Query(table), rpc: async () => ({ error: null }) } };
}

for (const [code, names] of Object.entries(contracts)) {
  test(`${code}: all documented parameters render as text and missing parameters prevent sending`, async (t) => {
    let current;
    t.mock.method(clientModule, 'getSupabaseClient', () => current.client);
    t.mock.method(settingsModule, 'loadEmailSettings', async () => ({ enabled: true, daily_limit: 10, retry_limit: 3,
      sender_name: 'Test', sender_email: 'sender@example.invalid', brevo_api_key: 'synthetic' }));
    t.mock.method(brevoModule, 'sendEmail', async (payload) => { current.sends.push(payload); return { messageId: 'synthetic-id' }; });
    current = fixture(code, names);
    await processGeneralEmailQueue();
    assert.equal(current.sends.length, 1);
    for (const name of names) assert.ok(current.sends[0].htmlContent.includes(`${name} &lt;unsafe&gt;`));
    for (const name of names) {
      current = fixture(code, names, name);
      await processGeneralEmailQueue();
      assert.equal(current.sends.length, 0, name);
      assert.equal(current.row.delivery_claim_token, null);
      assert.ok(current.row.error_message.includes(name));
    }
  });
}
