# Private tickets and QR check-in (#84)

Registration QR: a public /register/<slug> URL, displayed by the publishing form.
Ticket QR: ctm-ticket:v1:<random UUID v4>, generated locally without a third-party
QR service. It contains no person data and cannot log in or read ticket data.
A copied ticket reference can be presented at the door, so owners should keep it
private; server-side revocation and single admission protect reuse.

Each confirmed registration gets one ticket in the admission transaction. The
migration also backfills earlier registrations. Only the owner and administrators
can read ticket rows; get_my_tickets always returns only the session owner's
tickets, even when called by an admin. Full events do not invalidate issued tickets.

Events → Bilet giriş kontrolü accepts a USB/Bluetooth QR reader's keyboard output,
pasted QR text or the printed UUID fallback. It does not request camera access.
Select the event then submit to record admission. Admin/Super Admin or an active
member assigned in event_staff may scan that event. An operator cannot admit
themselves. Entry opens four hours before starts_at and closes at ends_at;
registration closed does not block admission, event cancelled/draft does.

Admission locks the event then ticket row. Duplicate scans return already used
with the original timestamp and never add a second admission. Invalid references
and wrong events cannot expose a ticket. Direct client inserts/updates/deletes
are revoked. Server authorization applies even if the UI is bypassed.

Only Admin/Super Admin may revoke, after UI confirmation. Revocation updates the
ticket audit fields and cancels registration in one transaction, releases its seat,
and cannot be undone by the attendee. Repeated revocation is idempotent. Check-in
and revoke capture the actor member UUID and timestamp. All procedures reject a
request captured under a different signed-in account.

Apply after the public registration migration. #86 staging gate: real Auth,
simultaneous scans/admissions, printed QR readability on phone/reader, responsive
layouts and cancellation/revocation. CI runs PGlite policy/transition tests, QR
encoding and component tests. No production schema, deployment or mail changes.
