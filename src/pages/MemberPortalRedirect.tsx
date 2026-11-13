import { useEffect } from 'react';
import { memberPortalUrl } from '../lib/memberPortalUrl';

export function MemberPortalRedirect() {
  const url = memberPortalUrl(import.meta.env.VITE_MEMBER_PORTAL_URL, import.meta.env.DEV);
  const validUrl = url && new URL(url).origin !== window.location.origin ? url : null;
  useEffect(() => { if (validUrl) window.location.replace(validUrl); }, [validUrl]);
  return <main className="p-8 text-[var(--text-primary)]">
    <h1 className="text-2xl font-bold">Kullanıcı paneli</h1>
    {validUrl ? <p className="mt-4">Paneliniz açılıyor… <a className="underline" href={validUrl}>Panele git</a></p>
      : <p className="mt-4" role="status">Kullanıcı paneli henüz kullanıma açılmadı. Lütfen topluluk yöneticinizle iletişime geçin.</p>}
  </main>;
}
