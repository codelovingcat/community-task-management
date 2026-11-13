import { useEffect, useRef, useState } from 'react';
import { deleteNote, listNotes, notePageSize, saveNote } from './notesStore';
import type { Note, NoteDraft, Priority } from './notesStore';
const empty: NoteDraft = {title:'',body:'',priority:'normal'};
const priorities: Record<Priority,string> = {low:'Düşük',normal:'Normal',high:'Acil'};

export function Notes({ownerId}: {ownerId:string}) {
  const [notes,setNotes] = useState<Note[]>([]);
  const [loading,setLoading] = useState(true);
  const [busy,setBusy] = useState(false);
  const [hasMore,setHasMore] = useState(false);
  const [error,setError] = useState('');
  const [notice,setNotice] = useState('');
  const [editor,setEditor] = useState<Note | 'new' | null>(null);
  const [draft,setDraft] = useState<NoteDraft>(empty);
  const [confirm,setConfirm] = useState<Note | null>(null);
  const generation = useRef(0);
  const alive = useRef(false);
  const inFlight = useRef(false);

  async function load(offset=0) {
    const request=++generation.current;
    setLoading(true); setError('');
    try {
      const rows=await listNotes(ownerId,offset);
      if(!alive.current || request!==generation.current) return;
      setNotes(current=>offset ? [...current,...rows].filter((note,i,all)=>all.findIndex(n=>n.id===note.id)===i) : rows);
      setHasMore(rows.length===notePageSize);
    } catch(err) { if(alive.current && request===generation.current) setError(err instanceof Error ? err.message : 'Notlar yüklenemedi.'); }
    finally { if(alive.current && request===generation.current) setLoading(false); }
  }
  useEffect(()=>{
    alive.current=true; setNotes([]); setEditor(null); setConfirm(null); setDraft(empty); setNotice('');
    void load();
    return ()=>{alive.current=false; ++generation.current;};
  },[ownerId]);

  function edit(note:Note | 'new') {
    setEditor(note);setDraft(note==='new'?empty:{title:note.title,body:note.body,priority:note.priority});setConfirm(null);setError('');setNotice('');
  }
  async function mutate(action:()=>Promise<unknown>, message:string) {
    if(inFlight.current) return;
    inFlight.current=true; setBusy(true);setError('');setNotice('');
    const request=++generation.current;
    try {
      await action();
      if(!alive.current || request!==generation.current) return;
      setEditor(null);setConfirm(null);setDraft(empty);setNotice(message);
      await load();
    } catch(err) {if(alive.current && request===generation.current) setError(err instanceof Error?err.message:'İşlem tamamlanamadı.');}
    finally {inFlight.current=false;if(alive.current) setBusy(false);}
  }
  return <section className="card notes-section" aria-label="Özel notlarım">
    <div className="notes-heading"><div><p className="eyebrow">KENDİME NOTLAR</p><h2>Not kartlarım</h2><p className="small muted">Bu notları yalnızca siz görebilirsiniz.</p></div><div className="note-actions"><button disabled={busy || loading || editor!==null} onClick={()=>void load()}>Notları yenile</button><button disabled={busy || loading || editor!==null} onClick={()=>edit('new')}>Yeni not</button></div></div>
    {notice && <p role="status">{notice}</p>}
    {error && <p role="alert" className="tone-red">{error}</p>}
    {loading && <p role="status">Notlar yükleniyor…</p>}
    {editor && <form className="note-editor" onSubmit={event=>{event.preventDefault();void mutate(()=>saveNote(ownerId,draft,editor==='new'?undefined:editor),'Not kaydedildi.');}}>
      <fieldset disabled={busy}><legend>{editor==='new'?'Yeni not':'Notu düzenle'}</legend>
        <label>Başlık<input required maxLength={120} value={draft.title} onChange={event=>setDraft({...draft,title:event.target.value})} /></label>
        <label>Not<textarea rows={5} maxLength={4000} value={draft.body} onChange={event=>setDraft({...draft,body:event.target.value})} /></label>
        <p className="small muted">{draft.body.length} / 4000 karakter</p>
        <label>Öncelik<select value={draft.priority} onChange={event=>setDraft({...draft,priority:event.target.value as Priority})}>{Object.entries(priorities).map(([value,label])=><option key={value} value={value}>{label}</option>)}</select></label>
        <div className="note-actions"><button type="submit">{busy?'Kaydediliyor…':'Notu kaydet'}</button><button type="button" onClick={()=>{setEditor(null);setDraft(empty);setError('');}}>Vazgeç</button></div>
      </fieldset>
    </form>}
    {!loading && !error && !notes.length && <p className="muted">Henüz notunuz yok. İlk not kartınızı ekleyin.</p>}
    <div className="note-grid">{notes.map(note=><article key={note.id} className={`note-card priority-${note.priority}`}>
      <span className="note-priority">{priorities[note.priority]}</span><h3>{note.title}</h3><p className="note-body">{note.body}</p>
      <p className="small muted">Güncelleme: {new Date(note.updated_at).toLocaleString('tr-TR',{timeZone:'Europe/Istanbul'})}</p>
      {confirm?.id===note.id ? <div role="group" aria-label={`${note.title} silme onayı`}><p>Bu not kalıcı olarak silinsin mi?</p><div className="note-actions"><button disabled={busy} onClick={()=>void mutate(()=>deleteNote(ownerId,note),'Not silindi.')}>Evet, notu sil</button><button disabled={busy} onClick={()=>setConfirm(null)}>İptal</button></div></div> : <div className="note-actions"><button disabled={busy || loading || editor!==null} onClick={()=>edit(note)}>Düzenle</button><button disabled={busy || loading || editor!==null} onClick={()=>{setConfirm(note);setError('');}}>Sil</button></div>}
    </article>)}</div>
    {hasMore && <button disabled={busy || loading || editor!==null} onClick={()=>void load(notes.length)}>Daha fazla not</button>}
  </section>;
}
