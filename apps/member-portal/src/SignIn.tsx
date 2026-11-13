import { useState, type FormEvent } from 'react';
import { client } from './client';

export function SignIn() {
  const [pending, setPending] = useState(false);
  const [error, setError] = useState('');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (pending) return;
    const values = new FormData(event.currentTarget);
    setPending(true);
    setError('');
    try {
      const { error: authError } = await client.auth.signInWithPassword({
        email: String(values.get('email') ?? '').trim(), password: String(values.get('password') ?? ''),
      });
      if (authError) setError('Giriş yapılamadı. Bilgilerinizi kontrol edip tekrar deneyin.');
    } catch {
      setError('Bağlantı kurulamadı. Lütfen tekrar deneyin.');
    } finally { setPending(false); }
  }
  return <main className="portal-login">
    <p className="eyebrow">SİZE AİT ALAN</p>
    <h1>Kullanıcı paneline<br />hoş geldiniz.</h1>
    <p className="muted">Görevlerinizi ve topluluk bilgilerinizi tek bir yerde takip edin.</p>
    <form onSubmit={(event) => void submit(event)}>
      <label htmlFor="email">E-posta</label>
      <input id="email" name="email" type="email" autoComplete="username" required disabled={pending} />
      <label htmlFor="password">Şifre</label>
      <input id="password" name="password" type="password" autoComplete="current-password" required disabled={pending} />
      {error && <p role="alert" className="error">{error}</p>}
      <button type="submit" className="primary" disabled={pending}>{pending ? 'Giriş yapılıyor…' : 'Giriş yap'}</button>
    </form>
    <p className="muted small">Mevcut topluluk hesabınızı kullanın. Hesabınız yoksa topluluk yöneticinizle iletişime geçin.</p>
  </main>;
}
