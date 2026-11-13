# Completion and personal scores (#80)

The database records `completed_at` when a task first enters `completed` or
`done`. Moving between those two statuses, changing the title/description or
changing the deadline does not rewrite the completion time. Reopening clears
it; completing again records a new time. Completed work must be reopened in a
separate operation before reassignment. This avoids silently moving earned
points to someone else. Task changes remain admin-only.

Score = sum of points on completed/done tasks assigned to the member, including
archived tasks. No late penalty. A task ID is counted once, with a live record
taking precedence over an archived duplicate. Reopening removes its points;
re-completion restores them. Changing task points as an admin recalculates the
score; permanently deleting a task removes its contribution. This is a current
completion score, not an immutable reward ledger. Historical completed tasks
still count points, but unknown completion times cannot be marked on time/late.

Historical completed_at remains NULL: updated_at and legacy done_completed_at
are not reliable completion evidence. Legacy archive fields are retained for
audit only. Automatic archiving only considers done tasks with a known completion
time older than seven days. Archive/restore RPCs perform both writes atomically,
retain assignment/status/points/completion/resource links, and fail on conflicts
without deleting data. Existing cron calls use the same automatic function name.

The portal displays only the member's own score and includes archived tasks.
Admins/Super Admins have a refreshable score table on Members. Both score/profile
RPCs are SECURITY INVOKER, so direct tables and aggregate RPCs share RLS.

Optional resource_url is validated as HTTPS in the DB, input form and portal.
Links open with noopener/noreferrer and are not auth credentials. Apply migration
20261113200634 after #79 in staging; test real roles, task transitions, manual
archive/restore and the existing cron schedule before production (#86).
Mail delivery and mail-worker code are unchanged.
