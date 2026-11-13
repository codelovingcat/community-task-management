import { useState } from 'react';
import { client } from './client';
import { usePortalSession } from './usePortalSession';
import { SignIn } from './SignIn';
import { Profile } from './Profile';
import { AuthConfirm } from './AuthConfirm';

export function App() {
  const { user, loading, error } = usePortalSession();
  const [signingOut, setSigningOut] = useState(false);
  const [signOutError, setSignOutError] = useState(false);
  async function signOut() {
    setSigningOut(true); setSignOutError(false);
    try {
      const { error: failure } = await client.auth.signOut();
      if (failure) setSignOutError(true);
    } catch { setSignOutError(true); }
    finally { setSigningOut(false); }
  }
  if (window.location.pathname === '/auth/confirm') return <AuthConfirm />;
  if (loading) return <main className="portal-login" role="status">Oturum kontrol ediliyor…</main>;
  if (!user) return <>{error && <p role="alert">Oturum alınamadı. Lütfen yeniden giriş yapın.</p>}<SignIn /></>;
  return <>
    <a className="skip-link" href="#main">İçeriğe geç</a>
    <header className="portal-header"><a className="brand" href="/">COMMUNITY <span>Kullanıcı paneli</span></a>
      <button onClick={() => void signOut()} disabled={signingOut}>{signingOut ? 'Çıkılıyor…' : 'Çıkış yap'}</button>
    </header>
    {signOutError && <p role="alert" className="error">Çıkış yapılamadı. Tekrar deneyin.</p>}
    <main id="main" className="portal-main"><Profile key={user.id} /></main>
  </>;
}
