import { useEffect, useState } from 'react';
import { client } from './client';
import { ticketCode } from '../../../src/lib/ticketCode';
import { TicketQr } from '../../../src/components/events/TicketQr';
type Ticket={id:string;reference:string;state:string;registration_state:string;event_state:string;title:string;starts_at:string|null;ends_at:string|null;location:string|null;checked_in_at:string|null};
export function Tickets() {
 const [rows,setRows]=useState<Ticket[]|null>(null),[error,setError]=useState(false),[retry,setRetry]=useState(0);
 useEffect(()=>{let active=true;setRows(null);setError(false);
  void Promise.resolve(client.rpc('get_my_tickets')).then(({data,error})=>{if(active){if(error)setError(true);else setRows(data??[]);}}).catch(()=>{if(active)setError(true);});return()=>{active=false;};
 },[retry]);
 const selected=new URLSearchParams(window.location.search).get('ticket');
 return <section className="card" aria-label="Biletlerim"><p className="eyebrow">ETKİNLİK KATILIMI</p><h2>Biletlerim</h2><button onClick={()=>setRetry(n=>n+1)}>Biletleri yenile</button>
  {error?<p role="alert">Biletler yüklenemedi. Yeniden deneyin.</p>:rows===null?<p role="status">Biletler yükleniyor…</p>:<>
   {selected&&!rows.some(t=>t.id===selected)&&<p role="alert">Bu bilet bulunamadı veya size ait değil.</p>}
   {!rows.length&&<p>Henüz biletiniz yok. Bir etkinlik kayıt bağlantısından katılabilirsiniz.</p>}
   <div className="note-grid">{rows.filter(t=>!selected||t.id===selected).map(t=>{
    const available=['open','closed'].includes(t.event_state)&&t.registration_state==='confirmed'&&t.state!=='revoked';
    const code=ticketCode(t.reference);
    return <article key={t.id} className="note-card"><h3>{t.title}</h3><p>{t.location}</p><p>{t.starts_at?new Date(t.starts_at).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul'}):'Tarih belirtilmemiş'} · İstanbul</p>
     <p role="status">{!available?'Bilet kullanıma kapalı / iptal edildi':t.state==='checked_in'?'Giriş kaydedildi':'Biletiniz hazır'}</p>
     {available&&t.state==='valid'&&code&&<><TicketQr value={code} label={t.title+' giriş bileti'}/><p className="small muted">Bu QR kapı girişinde kullanılır. Giriş bağlantısı değildir.</p></>}
     <p className="small" style={{overflowWrap:'anywhere'}}>Bilet referansı: {t.reference}</p>
     {t.checked_in_at&&<p className="small">Giriş: {new Date(t.checked_in_at).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul'})}</p>}
    </article>;
   })}</div>{selected&&<a href="/">Tüm biletlerim</a>}
  </>}
 </section>;
}
