import { useEffect, useState } from 'react';
import { client } from './client';
import { Dashboard } from './Dashboard';
import { Notes } from './Notes';
import type { PortalProfile } from './types';

// Mounted with key=Auth user ID, so account switches discard all prior data.
export function Profile() {
  const [data, setData] = useState<PortalProfile | null>(null);
  const [state, setState] = useState<'loading' | 'error' | 'unregistered' | 'ready'>('loading');
  const [retry, setRetry] = useState(0);
  useEffect(() => {
    let active = true;
    setData(null);
    setState('loading');
    void client.rpc('get_my_profile').then(({ data: result, error }) => {
      if (!active) return;
      if (error) { setState('error'); return; }
      if (!result) { setState('unregistered'); return; }
      if (!result.member?.id || typeof result.member.name !== 'string' || !Array.isArray(result.tasks)) {
        setState('error'); return;
      }
      setData(result as PortalProfile);
      setState('ready');
    }, () => { if (active) setState('error'); });
    return () => { active = false; };
  }, [retry]);
  if (state === 'loading') return <p role="status">Bilgileriniz yükleniyor…</p>;
  if (state === 'unregistered') return <section className="card"><h1>Üyeliğiniz henüz eşleştirilmemiş</h1><p>Topluluk yöneticinizle iletişime geçin.</p></section>;
  if (state === 'error' || !data) return <section className="card" role="alert">
    <h1>Bilgileriniz yüklenemedi</h1><p>Tekrar deneyin. Sorun sürerse topluluk yöneticinize bildirin.</p>
    <button onClick={() => setRetry((count) => count + 1)}>Tekrar dene</button>
  </section>;
  return <><Dashboard data={data} onRefresh={() => setRetry((count) => count + 1)} /><Notes key={data.member.id} ownerId={data.member.id} /></>;
}
