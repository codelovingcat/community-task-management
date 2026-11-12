# Inspecting delivery claims

The worker retains a claim if it cannot prove the result of a provider request
or cannot record a successful delivery. It deliberately does not retry such a
message automatically, because the provider may have accepted it.

From a trusted worker environment, with its server-only Supabase credentials
configured and the worker compiled, run `node dist/claimStatus.js` from the
`email-worker` directory. The command only reads aggregate counts of pending
claims older than 15 minutes. It prints no email addresses, payloads, tokens,
or credentials. Exit code 0 means no stale claims were found; 2 means one or
more need investigation; 1 means the check failed. A claim younger than the
threshold or one with a missing timestamp is not included in these counts.

For a stale claim, an authorized operator must inspect the corresponding queue
record and provider delivery history using approved tools. Confirm the provider
outcome and coordinate all consumers before changing any row. Do not clear a
claim merely because it is old: the provider may already have sent the email.
This check does not repair records, send email, or establish exactly-once
delivery. It requires the claim migration on the selected database; it does
not deploy that migration or prove that all consumers follow the protocol.
