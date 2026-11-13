import { useEffect, useState } from 'react';
import { client } from './client';
type Row={id:string;state:string;public_event_pages:{title:string;state:string}|null};
export function AttendeePanel({userId}:{userId:string}) {
 const [rows,setRows]=useState<Row[]|null>(null),[error,setError]=useState(false),[retry,setRetry]=useState(0);
 useEffect(()=>{let active=true;setRows(null);setError(false);void Promise.resolve(client.from('event_registrations').select('id,state,public_event_pages(title,state)').eq('auth_user_id',userId).order('created_at',{ascending:false})).then(({data,error})=>{if(active){if(error)setError(true);else setRows((data as unknown as Row[])??[]);}}).catch(()=>{if(active)setError(true);});return()=>{active=false;};},[userId,retry]);
 return <section className="card" aria-label="Etkinlik kayıtlarım"><h2>Etkinlik kayıtlarım</h2><button onClick={()=>setRetry(n=>n+1)}>Kayıtları yenile</button>{error?<p role="alert">Kayıtlar yüklenemedi. Yeniden deneyin.</p>:rows===null?<p role="status">Kayıtlar yükleniyor…</p>:!rows.length?<p>Henüz etkinlik kaydınız yok. Bir etkinlik kayıt bağlantısıyla katılabilirsiniz.</p>:<ul>{rows.map(r=><li key={r.id}><strong>{r.public_event_pages?.title??'Etkinlik'}</strong> — {r.state==='cancelled'||r.public_event_pages?.state==='cancelled'?'İptal edildi':'Kayıt onaylandı'}</li>)}</ul>}</section>;
}
