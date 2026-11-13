# Public event registration (#83)

Publish a public registration page from Events → Dış katılımcı kaydı.
The public projection contains only deliberately published text, location,
schedule, capacity and consent fields. Internal descriptions/Drive links/rosters
are never joined into it. Public dates are a separate snapshot: update them when
the internal schedule changes. Slugs are immutable so shared links stay stable.

The portal route is /register/<slug>. A visitor verifies their email through
Supabase Auth before admission. This creates an event_registrations row linked
to Auth UUID, not a members row or privileged identity binding. One account may
be both a member and attendee without inheriting extra privileges.

The database validates the verified account, name, expected session identity,
current consent version, open/cancelled state and deadline. It locks the event
before duplicate/capacity checks; UNIQUE(event_id, auth_user_id) enforces one
registration. A per-user limiter permits 10 attempts per 10 minutes, including
invalid/rejected attempts (returned statuses preserve the counter). Provider
Auth rate limits/CAPTCHA handle signup abuse before verification. Anonymous
clients cannot call registration or read registrations; registered users only
read their own data, admins can review event registrations.

Consent text/version/URL/time and verified email are snapshotted on registration.
Changes to published consent do not rewrite existing acceptances. Confirmed
registrations cannot be silently deleted by deleting the source event; cancel
the published event instead. Admins cannot reduce capacity below confirmed count.

Apply migrations after #79–#81, configure #82 Auth entry, and test real concurrent
last-seat requests and actual Auth isolation under #86. Tests run SQL policies,
limits, duplicates, both identity types, consent snapshots and component states.
No live SQL, real email or worker changes. #26 owns confirmation email delivery;
the persisted registration ID is the idempotency key for its future adapter.
