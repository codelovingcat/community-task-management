# Email Worker

A long-running Node.js worker for both email queues in the Task Manager database.

## Queues

- email_queue: welcome, task assignment, membership, and birthday messages. Uses BIGINT queue IDs and template_params.
- speaker_email_queue: speaker-related messages. Uses UUID queue IDs and speaker-specific template fields.
- email_send_logs stores the general queue reference in queue_id and the speaker queue reference in speaker_queue_id. Do not coerce UUIDs into the BIGINT field.

The worker runs both processors immediately on startup and then every five minutes. The general processor invokes the idempotent birthday enqueue function using the Europe/Istanbul calendar date and reconciles delivery markers for sent birthday messages.

## Configuration

Set these environment variables in the worker's secret manager:

- SUPABASE_URL: the Supabase project URL.
- SUPABASE_SERVICE_ROLE_KEY: server-only service-role key. Never expose this key to the browser or commit it to Git.

Provider settings (brevo_api_key, sender_email, sender_name, daily_limit, retry_limit, and enabled) are read from the backend-only email_settings table.

The service must run as a persistent Node.js process because it uses node-cron. A serverless deployment that suspends the process will not run this in-process schedule reliably; use an always-on worker or a protected scheduled endpoint that invokes the processors.

## Local checks

From this directory:

\`\`\`sh
npm ci
npm test
\`\`\`

The current automated tests cover template rendering and parameter normalization. Provider delivery and queue retry behavior still require integration tests. Do not test by sending real email to community members; use a sandbox/test recipient and a controlled queue fixture.
