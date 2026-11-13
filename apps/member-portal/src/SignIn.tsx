import { useRef, useState, type FormEvent } from 'react';
import { client } from './client';
import { portalAuthRedirect, safePortalReturn } from '../../../src/lib/portalLinks';
export function SignIn({ registration = false }: { registration?: boolean }) {
  const [method, setMethod] = useState<'link' | 'password'>('link');
  const [notice, setNotice] = useState('');
  const busy = useRef(false);
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy.current) return;
    busy.current=true;
    const values = new FormData(event.currentTarget);
    setPending(true); setError(''); setNotice('');
    try {
      if (method === 'link') {
        const next = safePortalReturn(window.location.pathname.startsWith('/register/') ? window.location.pathname : window.location.pathname + window.location.search);
        const redirect = portalAuthRedirect(import.meta.env.VITE_MEMBER_PORTAL_URL, next, import.meta.env.DEV);
        if (!redirect || new URL(redirect).origin !== window.location.origin) { setError('Giriş bağlantısı henüz yapılandırılmamış. Şifreyle giriş yapabilir veya yöneticinize bildirebilirsiniz.'); return; }
        const {error: linkError} = await client.auth.signInWithOtp({email:String(values.get('email') ?? '').trim(),options:{shouldCreateUser:registration,emailRedirectTo:redirect}});
        if (linkError && (linkError.status === 429 || (linkError.status ?? 0) >= 500)) setError('Bağlantı gönderilemedi. Biraz bekleyip tekrar deneyin.');
        else setNotice('Adresiniz uygunsa giriş bağlantısı gönderildi. Gelen kutunuzu kontrol edin; tekrar istemeden önce bir dakika bekleyin.');
        return;
      }
      const { error: authError } = await client.auth.signInWithPassword({
        email: String(values.get('email') ?? '').trim(), password: String(values.get('password') ?? ''),
      });
      if (authError) setError('Giriş yapılamadı. Bilgilerinizi kontrol edip tekrar deneyin.');
    } catch { setError('Bağlantı kurulamadı. Lütfen tekrar deneyin.'); }
    finally { busy.current=false; setPending(false); }
  }
  return <main className="portal-login">
    <p className="eyebrow">SİZE AİT ALAN</p><h1>Kullanıcı paneline<br />hoş geldiniz.</h1>
    <p className="muted">Görevlerinizi ve topluluk bilgilerinizi tek bir yerde takip edin.</p>
    <div className="note-actions"><button disabled={pending} onClick={()=>{setMethod('link');setError('');}}>E-posta bağlantısıyla</button><button disabled={pending} onClick={()=>{setMethod('password');setError('');}}>Şifreyle</button></div>
    <form onSubmit={(event) => void submit(event)}>
      <label htmlFor="email">E-posta</label><input id="email" name="email" type="email" autoComplete="username" required disabled={pending} />
      {method === 'password' && <><label htmlFor="password">Şifre</label><input id="password" name="password" type="password" autoComplete="current-password" required disabled={pending} /></>}
      {notice && <p role="status">{notice}</p>}{error && <p role="alert" className="error">{error}</p>}
      <button type="submit" className="primary" disabled={pending}>{pending ? 'İşlem sürüyor…' : method === 'link' ? 'Giriş bağlantısı gönder' : 'Giriş yap'}</button>
    </form>
    <p className="muted small">{registration ? 'Etkinliğe kayıt için önce e-posta adresinizi doğrulayın. Bu işlem topluluk üyeliği vermez.' : 'Mevcut hesabınızı kullanın. Topluluk üyeliğiniz için yöneticinizle iletişime geçin.'}</p>
  </main>;
}
