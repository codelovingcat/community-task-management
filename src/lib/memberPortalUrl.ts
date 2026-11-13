/** Configured deployment URL only; never accepts a URL supplied by a visitor. */
export function memberPortalUrl(input: unknown, development = false): string | null {
  if (typeof input !== 'string' || !input.trim()) return null;
  try {
    const value = new URL(input.trim());
    const local = ['localhost', '127.0.0.1', '[::1]'].includes(value.hostname);
    if (value.protocol !== 'https:' && !(development && local && value.protocol === 'http:')) return null;
    if (value.username || value.password || value.search || value.hash) return null;
    // First release is a standalone origin, not an admin route/subpath.
    if (value.pathname !== '/') return null;
    return value.href;
  } catch { return null; }
}
