# Private community release evidence (#3)

2026-11-22: all seven tables already had RLS enabled, but six had authenticated
SELECT policies with `USING (true)`. An external Auth signup could therefore read
internal community settings, events and announcements without membership.

The reviewed fix is already on main:
`20261111150204_restrict_private_community_reads.sql`. It replaces policies and
removes anonymous/unsafe grants on announcements, announcement_members, events,
event_staff, event_speakers, community_settings and menu_items. Members read shared
records; recipient mappings are owner/admin-only; only Admin/Super Admin writes.
Public registration uses separate public_event_pages, not private events.

This PR adds a repeatable read-only deployment gate and tests against the complete
baseline/migration chain, including real member mapping, active/inactive members,
an unregistered Auth user, anon and admin CRUD. The existing policy matrix tests
continue covering all seven tables, denied writes and hostile legacy policies.

## Hosted rollout status

**Not applied.** Automatic approval review rejected the live policy replacement
because it changes the production authorization boundary and could disrupt access.
No workaround was attempted. User approval is required for this exact migration
on Task Manager project `vbokappwelyrvoxnkigp` before applying it.

After approval, apply that reviewed migration once, then run
`supabase/audits/private_community_release_gate.sql` and the detailed companion
audit. Every gate row must be ready; review policy expressions and real sessions
as well. A passing catalog gate is necessary, not sufficient proof of behavior.
Revalidate an active Super Admin and external/member sessions. Keep #3 open until
the hosted checks pass; merging source alone does not complete rollout.
