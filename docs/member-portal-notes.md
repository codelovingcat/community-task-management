# Private note cards (#81)

Member portal notes are persisted in the shared database, separately from tasks.
Owners can create/edit/delete plain-text cards with title (1–120 characters),
body (up to 4000) and low/normal/high priority. Notes never modify assigned tasks.
Cards load in pages of 24, with a load-more control. Delete requires an explicit
in-page confirmation. Save failures preserve the draft; updates/deletes use
updated_at optimistic concurrency so another tab's changes are not overwritten.
Cancel editing then refresh to resolve a conflict.

RLS and column grants enforce immutable ownership and timestamps; Admin and
Super Admin have no read/write exception. A service-role database operator is
still privileged, as with all Supabase data: never ship that key to either app.
Every request includes the captured member owner ID, checked against the current
server Auth identity, so a session switch cannot save an old draft to a new user.
The Profile component is keyed by Auth user ID and Notes by member ID; pending
responses are discarded on unmount. No private drafts are stored in localStorage.

Apply 20261113201104_member_private_notes.sql after the identity migration and
run the #86 real-account checks: A CRUD, B denied, admin denied, anonymous denied,
session switch, offline retry, stale tab conflict, and narrow-screen layout.
