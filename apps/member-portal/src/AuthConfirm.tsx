import { useEffect, useRef, useState } from 'react';
import { client } from './client';
import { readPortalConfirmation } from '../../../src/lib/portalLinks';
export function AuthConfirm() {
  const [entry]=useState(()=>readPortalConfirmation(window.location.href));
  const [status,setStatus]=useState<'ready'|'pending'|'error'>(entry.token?'ready':'error');
  const inFlight=useRef(false);
  useEffect(()=>{ window.history.replaceState(null,'','/auth/confirm?next='+encodeURIComponent(entry.next)); },[entry.next]);
  async function confirm() {
    if(inFlight.current || status!=='ready' || !entry.token) return;
    inFlight.current=true;setStatus('pending');
    try {
      const {data,error}=await client.auth.verifyOtp({token_hash:entry.token,type:'email'});
      if(error || !data.session) setStatus('error');
      else window.location.replace(entry.next);
    } catch {setStatus('error');}
  }
  return <main className="portal-login"><p className="eyebrow">GÜVENLİ GİRİŞ</p><h1>Panelinize devam edin</h1>
    {status==='error'?<><p role="alert">Bağlantı geçersiz, kullanılmış veya süresi dolmuş olabilir. Yeni bir giriş bağlantısı isteyin.</p><a href={entry.next}>Giriş ekranına dön</a></>:<><p className="muted">Bu e-postanın gönderildiği hesapla oturum açılacak.</p><button className="primary" disabled={status==='pending'} onClick={()=>void confirm()}>{status==='pending'?'Doğrulanıyor…':'Girişi onayla'}</button></>}
  </main>;
}
