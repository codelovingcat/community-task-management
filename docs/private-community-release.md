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

**Applied and database-verified on 2026-11-22 after explicit user approval.**
All seven catalog gates pass. Hosted SQL-role checks confirmed Admin settings create/update
and profile RPCs, denied external-account reads/writes, and denied anonymous reads.
The synthetic member/settings/queue fixtures were rolled back; real members remain.
See [deployment evidence](production-database-rollout-2026-11-22.md) for actual
migration versions and boundaries. #3's database rollout is complete; real browser,
Auth-provider and portal deployment verification remains #4/#86.
