import { useEffect, useRef, useState } from 'react';
import { client } from './client';
import { SignIn } from './SignIn';
import { safeResourceUrl } from './resourceUrl';
type Page={event_id:string;slug:string;title:string;summary:string;location:string;starts_at:string;registration_closes_at:string;state:string;privacy_url:string;consent_version:string;consent_text:string};
const messages:Record<string,string>={registered:'Kaydınız alındı.',already_registered:'Bu etkinliğe zaten kayıtlısınız.',registration_cancelled:'Kaydınız iptal edilmiş. Etkinlik yöneticisiyle iletişime geçin.',cancelled:'Etkinlik iptal edildi.',full:'Etkinliğin kontenjanı doldu.',closed:'Etkinlik kaydı kapandı.',consent_required:'Bilgilendirme metni değişmiş olabilir. Sayfayı yenileyip tekrar onaylayın.',verification_required:'Önce e-posta adresinizi doğrulayın.',rate_limited:'Çok fazla deneme yaptınız. On dakika sonra tekrar deneyin.',invalid_input:'Adınızı kontrol edin.',session_changed:'Oturum değişti. Sayfayı yenileyin.',not_found:'Etkinlik bulunamadı.'};
export function Registration({slug,userId}:{slug:string;userId:string|null}) {
 const [page,setPage]=useState<Page|null>(null),[loading,setLoading]=useState(true),[error,setError]=useState(''),[result,setResult]=useState(''),[pending,setPending]=useState(false),[retry,setRetry]=useState(0);
 const busy=useRef(false),alive=useRef(false);
 useEffect(()=>{let active=true;alive.current=true;setLoading(true);setError('');setResult('');
  void Promise.resolve(client.from('public_event_pages').select('*').eq('slug',slug).maybeSingle()).then(({data,error})=>{if(active){if(error)setError('Etkinlik yüklenemedi.');else setPage(data);setLoading(false);}}).catch(()=>{if(active){setError('Etkinlik yüklenemedi.');setLoading(false);}});
  return()=>{active=false;alive.current=false;};
 },[slug,retry]);
 async function submit(event:React.FormEvent<HTMLFormElement>) {
  event.preventDefault();if(busy.current || !page) return;busy.current=true;setPending(true);setError('');
  const form=new FormData(event.currentTarget);
  try {
   const {data,error}=await client.rpc('register_for_event',{p_slug:slug,p_name:String(form.get('name')??''),p_consent_version:page.consent_version,p_accepted:form.get('consent')==='on',p_expected_user_id:userId});
   if(alive.current){if(error)setError('Kayıt tamamlanamadı. Yeniden deneyin.');else setResult(data?.status??'error');}
  }catch{if(alive.current)setError('Bağlantı kurulamadı. Yeniden deneyin.');}
  finally{busy.current=false;if(alive.current)setPending(false);}
 }
 if(loading) return <main className="portal-login" role="status">Etkinlik yükleniyor…</main>;
 if(error && !page) return <main className="portal-login"><p role="alert">{error}</p><button onClick={()=>setRetry(n=>n+1)}>Tekrar dene</button></main>;
 if(!page) return <main className="portal-login"><h1>Etkinlik bulunamadı</h1><a href="/">Panele dön</a></main>;
 const closed=page.state!=='open'||Date.parse(page.registration_closes_at)<=Date.now();
 const success=['registered','already_registered'].includes(result);
 return <main className="portal-main"><section className="card"><p className="eyebrow">ETKİNLİK KAYDI</p><h1>{page.title}</h1><p className="task-description">{page.summary}</p><p>{page.location}</p><p>{new Date(page.starts_at).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul'})} · İstanbul</p>
  {error&&<p role="alert">{error}</p>}{result&&<p role="status">{messages[result]??'Kayıt sonucu alınamadı. Yeniden deneyin.'}</p>}
  {success?<a href="/">Katılımcı panelime git</a>:closed?<p role="status">{page.state==='cancelled'?'Etkinlik iptal edildi.':'Kayıt şu anda kapalı.'}</p>:userId?<form className="note-editor" onSubmit={event=>void submit(event)}><fieldset disabled={pending}><legend>Katılım bilgileri</legend><label>Ad soyad<input name="name" autoComplete="name" required minLength={2} maxLength={100}/></label><p className="small">{page.consent_text}</p>{safeResourceUrl(page.privacy_url)&&<a href={page.privacy_url} target="_blank" rel="noopener noreferrer">Gizlilik bilgilendirmesi</a>}<label><input type="checkbox" name="consent" required/> Bilgilendirmeyi okudum ve etkinlik kaydı için kabul ediyorum.</label><button type="submit">{pending?'Kaydediliyor…':'Etkinliğe kaydol'}</button></fieldset></form>:<SignIn registration/>}
 </section><p className="small muted">Etkinlik katılımı, topluluğun iç görevlerine veya üye listesine erişim vermez.</p><a href="/">Panelime dön</a></main>;
}
