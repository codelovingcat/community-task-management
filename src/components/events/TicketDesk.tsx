import { useEffect, useRef, useState } from 'react';
import type { FullEvent } from '../../types/event';
import { useUserProfile } from '../../context/UserProfileContext';
import { supabase } from '../../lib/supabase';
import { parseTicketCode } from '../../lib/ticketCode';
const messages:Record<string,string>={checked_in:'Giriş kaydedildi.',already_checked_in:'Bu bilet daha önce kullanılmış.',invalid_ticket:'Bu etkinlik için geçerli bilet bulunamadı.',revoked:'Bilet iptal edildi.',already_revoked:'Bilet zaten iptal edilmiş.',event_unavailable:'Etkinlik kapalı veya iptal edilmiş.',not_open:'Etkinlik giriş saati henüz başlamadı.',ended:'Etkinlik sona erdi.',self_checkin_forbidden:'Kendi girişinizi kaydedemezsiniz. Başka bir görevliye başvurun.'};
export function TicketDesk({events}:{events:FullEvent[]}) {
 const {user,profile}=useUserProfile();
 return user&&profile?<Desk key={user.id} events={events} userId={user.id} admin={['Admin','Super Admin'].includes(profile.system_role)}/>:null;
}
function Desk({events,userId,admin}:{events:FullEvent[];userId:string;admin:boolean}) {
 const [eventId,setEventId]=useState('');
 return <section className="my-6 rounded-xl border border-white/10 p-5 text-silver-200"><h2 className="text-xl font-semibold">Bilet giriş kontrolü</h2><p className="my-2 text-sm">Yalnızca yöneticiler ve seçili etkinliğe atanmış görevliler giriş kaydedebilir.</p><label>Etkinlik<select className="m-2 rounded bg-coal-800 p-2" value={eventId} onChange={e=>setEventId(e.target.value)}><option value="">Etkinlik seçin</option>{events.map(e=><option key={e.id} value={e.id}>{e.title}</option>)}</select></label>{eventId&&<Scan key={eventId} eventId={eventId} userId={userId} admin={admin}/>}</section>;
}
function Scan({eventId,userId,admin}:{eventId:string;userId:string;admin:boolean}) {
 const [code,setCode]=useState(''),[pending,setPending]=useState(false),[confirm,setConfirm]=useState(false),[message,setMessage]=useState(''),[name,setName]=useState('');
 const busy=useRef(false),alive=useRef(false);
 useEffect(()=>{alive.current=true;return()=>{alive.current=false;};},[]);
 async function run(revoke=false) {
  if(busy.current)return;const reference=parseTicketCode(code);
  if(!reference){setMessage('Geçerli bilet QR kodunu veya referansını girin.');return;}
  busy.current=true;setPending(true);setMessage('');setName('');
  try{const {data,error}=await supabase.rpc(revoke?'revoke_event_ticket':'check_in_event_ticket',{p_event_id:eventId,p_reference:reference,p_expected_user_id:userId});
   if(alive.current){setMessage(error?'İşlem yapılamadı. Etkinlik yetkinizi ve bağlantınızı kontrol edin.':messages[data?.status]??'İşlem sonucu alınamadı.');setName(error?'':data?.name??'');setConfirm(false);}
  }catch{if(alive.current)setMessage('Bağlantı kurulamadı. Yeniden deneyin.');}finally{busy.current=false;if(alive.current)setPending(false);}
 }
 return <form className="mt-4" onSubmit={e=>{e.preventDefault();void run();}}><fieldset disabled={pending}><label>QR okuyucu çıktısı veya bilet referansı<input className="my-2 block w-full rounded bg-coal-800 p-3" required maxLength={64} autoComplete="off" value={code} onChange={e=>{setCode(e.target.value);setConfirm(false);setMessage('');setName('');}}/></label><button type="submit" className="rounded bg-ice-500 p-3 text-coal-900">{pending?'Kontrol ediliyor…':'Girişi kaydet'}</button>
 {admin&&<button type="button" className="ml-3 p-3 underline" onClick={()=>setConfirm(true)}>Bileti iptal et</button>}
 {confirm&&<div role="group" aria-label="Bilet iptal onayı"><p>Bilet kalıcı olarak iptal edilecek ve kontenjan serbest bırakılacak.</p><button type="button" className="p-3 underline" onClick={()=>void run(true)}>Evet, bileti iptal et</button><button type="button" className="p-3" onClick={()=>setConfirm(false)}>Vazgeç</button></div>}
 </fieldset>{message&&<p role="status" className="my-3">{message}{name?' — '+name:''}</p>}</form>;
}
