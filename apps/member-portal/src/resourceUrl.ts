export function safeResourceUrl(value?: string | null): string | null {
  if (!value || value.length > 2048 || /[\s\\\x00-\x1f\x7f]/.test(value)) return null;
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && !url.username && !url.password && url.hostname ? url.href : null;
  } catch { return null; }
}
