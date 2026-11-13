import { memberPortalUrl } from './memberPortalUrl';
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;
export function safePortalReturn(input: unknown): string {
  if(typeof input !== 'string' || input.length>300 || /[\\\x00-\x20\x7f]/.test(input)) return '/';
  if(input==='/') return '/';
  if(/^\/register\/[a-z0-9][a-z0-9-]{2,79}$/.test(input)) return input;
  const match = /^\/\?(task|ticket)=([^&]+)$/.exec(input);
  return match && uuid.test(match[2]) ? '/?'+match[1]+'='+match[2] : '/';
}
export function portalAuthRedirect(origin: unknown, next: unknown, development=false): string | null {
  const base=memberPortalUrl(origin,development);
  return base ? base+'auth/confirm?next='+encodeURIComponent(safePortalReturn(next)) : null;
}
export type PortalMessage = 'internal_welcome' | 'task_assigned' | 'task_reminder' | 'attendee_confirmation';
export function portalMessageLink(origin:unknown, kind:PortalMessage, reference:string, development=false):string|null {
  const base=memberPortalUrl(origin,development);
  if(!base || kind==='internal_welcome' || !uuid.test(reference)) return null;
  return base+'?'+(kind==='attendee_confirmation'?'ticket':'task')+'='+reference;
}
export function readPortalConfirmation(href:string) {
  const url=new URL(href);
  const hash=new URLSearchParams(url.hash.slice(1));
  const token=hash.get('token_hash');
  return {next:safePortalReturn(url.searchParams.get('next')), token:hash.get('type')==='email' && token && /^[a-zA-Z0-9_-]{32,512}$/.test(token) ? token : null};
}
