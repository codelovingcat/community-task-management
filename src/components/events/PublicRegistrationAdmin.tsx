import { useEffect, useRef, useState } from 'react';
import type { FullEvent } from '../../types/event';
import { useUserProfile } from '../../context/UserProfileContext';
import { supabase } from '../../lib/supabase';
import { memberPortalUrl } from '../../lib/memberPortalUrl';
type Page={event_id:string;slug:string;title:string;summary:string;location:string;starts_at:string;ends_at:string;registration_closes_at:string;capacity:number;state:string;privacy_url:string;consent_version:string;consent_text:string};
export function PublicRegistrationAdmin({events}:{events:FullEvent[]}) {
 const {user,profile}=useUserProfile();
 return user && ['Admin','Super Admin'].includes(profile?.system_role??'') ? <Editor key={user.id} events={events}/> : null;
}
function Editor({events}:{events:FullEvent[]}) {
 const [selected,setSelected]=useState('');
 const event=events.find(e=>e.id===selected);
 return <section className="my-6 rounded-xl border border-white/10 p-5 text-silver-200"><h2 className="text-xl font-semibold">Dış katılımcı kaydı</h2><p className="my-2 text-sm">Herkese açık kayıt sayfası. İç açıklamalar ve Drive bağlantıları yayınlanmaz.</p><label>Etkinlik<select className="m-2 rounded bg-coal-800 p-2" value={selected} onChange={e=>setSelected(e.target.value)}><option value="">Etkinlik seçin</option>{events.map(e=><option key={e.id} value={e.id}>{e.title}</option>)}</select></label>{event&&<PageEditor key={event.id} event={event}/>}</section>;
}
function PageEditor({event}:{event:FullEvent}) {
 const defaults:Page={event_id:event.id,slug:'',title:event.title,summary:'',location:event.location??'',starts_at:event.start_date,ends_at:event.end_date,registration_closes_at:event.start_date,capacity:50,state:'draft',privacy_url:'',consent_version:'v1',consent_text:''};
 const [page,setPage]=useState<Page>(defaults),[exists,setExists]=useState(false),[loading,setLoading]=useState(true),[pending,setPending]=useState(false),[message,setMessage]=useState(''),[failed,setFailed]=useState(false),[retry,setRetry]=useState(0);
 const busy=useRef(false),alive=useRef(false);
 useEffect(()=>{let active=true;alive.current=true;setLoading(true);setMessage('');setFailed(false);
  void Promise.resolve(supabase.from('public_event_pages').select('*').eq('event_id',event.id).maybeSingle()).then(({data,error})=>{if(active){if(error){setFailed(true);setMessage('Yayın ayarları yüklenemedi.');}else{setExists(!!data);setPage(data??defaults);}setLoading(false);}}).catch(()=>{if(active){setFailed(true);setMessage('Yayın ayarları yüklenemedi.');setLoading(false);}});
  return()=>{active=false;alive.current=false;};
 },[event.id,retry]);
 async function save(e:React.FormEvent) {
  e.preventDefault();if(busy.current)return;busy.current=true;setPending(true);setMessage('');
  const fields={...page};delete (fields as Partial<Page>&{updated_at?:string}).updated_at;
  try{const query=exists?supabase.from('public_event_pages').update(fields).eq('event_id',event.id):supabase.from('public_event_pages').insert(fields);const {data,error}=await query.select().maybeSingle();if(alive.current){if(error||!data)setMessage('Kaydedilemedi. Alanları, bağlantının benzersizliğini ve mevcut kayıt sayısını kontrol edin.');else{setPage(data);setExists(true);setMessage('Kayıt sayfası kaydedildi.');}}}catch{if(alive.current)setMessage('Bağlantı hatası. Yeniden deneyin.');}finally{busy.current=false;if(alive.current)setPending(false);}
 }
 const base=memberPortalUrl(import.meta.env.VITE_MEMBER_PORTAL_URL,import.meta.env.DEV);
 const inputClass='mt-1 mb-3 block w-full rounded bg-coal-800 p-2 text-silver-100';
 if(loading)return <p role="status">Yayın ayarları yükleniyor…</p>;
 if(failed)return <div><p role="alert">{message}</p><button onClick={()=>setRetry(n=>n+1)}>Yeniden dene</button></div>;
 const textFields:[keyof Page,string,number][]=[['title','Herkese açık başlık',200],['summary','Etkinlik özeti',2000],['location','Herkese açık konum',500],['privacy_url','Gizlilik metni URL (HTTPS)',2048],['consent_version','Onay metni sürümü',50],['consent_text','Katılımcıya gösterilecek onay metni',2000]];
 return <form onSubmit={e=>void save(e)} className="mt-4"><fieldset disabled={pending} className="grid gap-x-4 sm:grid-cols-2">
  <label>Bağlantı adı<input className={inputClass} required pattern="[a-z0-9][a-z0-9-]{2,79}" maxLength={80} disabled={exists} value={page.slug} onChange={e=>setPage({...page,slug:e.target.value})}/></label>
  {textFields.map(([key,label,max])=><label key={key}>{label}<textarea className={inputClass} required={!['summary','location'].includes(key)} maxLength={max} value={page[key]} onChange={e=>setPage({...page,[key]:e.target.value})}/></label>)}
  {(['starts_at','ends_at','registration_closes_at'] as const).map((key,i)=><label key={key}>{['Başlangıç','Bitiş','Kayıt kapanışı'][i]} (UTC)<input className={inputClass} type="datetime-local" required value={page[key]?.slice(0,16)} onChange={e=>setPage({...page,[key]:e.target.value?e.target.value+':00Z':''})}/></label>)}
  <label>Kontenjan<input className={inputClass} type="number" required min={1} max={100000} value={page.capacity} onChange={e=>setPage({...page,capacity:Number(e.target.value)})}/></label>
  <label>Kayıt durumu<select className={inputClass} value={page.state} onChange={e=>setPage({...page,state:e.target.value})}><option value="draft">Taslak</option><option value="open">Kayıt açık</option><option value="closed">Kayıt kapalı</option><option value="cancelled">Etkinlik iptal</option></select></label>
  <button type="submit" className="rounded bg-ice-500 p-3 text-coal-900">{pending?'Kaydediliyor…':'Yayın ayarlarını kaydet'}</button>
 </fieldset>{message&&<p role="status" className="my-3">{message}</p>}{exists&&base&&<p className="my-3"><a href={base+'register/'+page.slug} target="_blank" rel="noopener noreferrer" className="underline">Kayıt sayfasını aç ↗</a></p>}<p className="text-sm">Yayın bilgileri ayrı tutulur. Ana etkinlik tarihi değişirse bu tarihleri de güncelleyin. Metin değişikliklerinde sürümü artırın.</p></form>;
}
