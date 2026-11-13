# Separate member application

Tracking: #87. Source lives in `apps/member-portal`; management remains at root.
They share one Supabase project. Build outputs, entry points and deployments are
independent. Portal source never imports the admin layout, roster or task editors.

## Local setup and builds

Install once at repository root with `npm ci` (one existing lockfile). The child
package is a separate app with scripts, not a separately installed dependency tree.
Set browser-safe `VITE_SUPABASE_URL` and `VITE_SUPABASE_ANON_KEY` in root `.env.local`.
Use `VITE_MEMBER_PORTAL_URL=http://localhost:5174` for management development.

- Management: `npm run dev`, `npm run build` (root `dist`).
- Portal: `npm run dev:portal` (port 5174), `npm run build:portal`
  (`apps/member-portal/dist`).
- Checks: `npm run typecheck`, `npm run typecheck:portal`, `npm run lint`,
  `npm run test:portal`.

The portal can also run its scripts via `npm --prefix apps/member-portal run dev`
after the root install. No provider or service-role key belongs in either client.

## Separate deployment

Use a second hosting project against the same repository. Build from repository
root with `npm ci` and `npm run build:portal`; publish `apps/member-portal/dist`.
Apply the SPA rewrite and response headers in `apps/member-portal/vercel.json`
to that hosting project (or equivalent host configuration). Do not accidentally
reuse the management output directory/configuration. Direct URLs must serve the
portal's HTML. This PR does not create or switch hosting projects.

Set management `VITE_MEMBER_PORTAL_URL` to the portal's HTTPS origin, with no
credentials/query/fragment/subpath. `/profile` leaves the management app; missing,
invalid or same-origin configuration shows a clear unavailable message. Retired
`/profile/:token` links remain retired. Tokens are never copied into a URL.

Existing password accounts can sign in now. Session storage is origin-scoped:
a different portal origin needs its own login; clicking Profile is one navigation,
not cross-origin SSO. Mail links/PKCE/expiry and validated return destinations
remain #82. There is no public signup form in this first release.

## Database and release prerequisites

The profile uses only the no-argument `get_my_profile()` RPC. That resolves member
identity in PostgreSQL; caller-supplied member IDs/emails never select a profile.
The app clears data across account changes. Null RPC result means unregistered;
RPC/network failure offers retry. Missing client configuration renders a friendly
error instead of a blank page.

Read-only inspection on 2026-11-13 found the live Task Manager project healthy but
`get_my_profile()` absent. The existing migration
`20261111172605_authenticated_self_profile.sql` must be reviewed and deployed with
its prerequisites; merging frontend changes cannot create it. Do not add an
anonymous table fallback to hide this failure.

Do not invite new users or expose attendee registration until #76 (task writes),
#79 (identity/read/score isolation), and #86 (real role tests and rollout) are done.
The legacy shared member/task read policies are not a private-score contract.
No production migration, registration or mail delivery is performed here.

## Remaining work

#78 dashboard/deadline display; #79 privacy; #80 real completion timestamp and
score/resource-link contracts; #81 private notes; #82 personal link entry;
#83 external registration; #84 QR tickets; #85 reminder producer; #86 rollout.
The initial internal welcome excludes the panel link; task emails include it.
External attendee registration confirmation includes panel/ticket entry.
