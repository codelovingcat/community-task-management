import { client } from './client';
export type Priority = 'low' | 'normal' | 'high';
export interface Note { id: string; owner_id: string; title: string; body: string; priority: Priority; created_at: string; updated_at: string }
export type NoteDraft = Pick<Note, 'title' | 'body' | 'priority'>;
const fields = 'id,owner_id,title,body,priority,created_at,updated_at';
export const notePageSize = 24;
export async function listNotes(ownerId: string, offset = 0): Promise<Note[]> {
  const {data,error} = await client.from('member_notes').select(fields).eq('owner_id',ownerId)
    .order('updated_at',{ascending:false}).order('id').range(offset,offset+notePageSize-1);
  if(error) throw new Error('Notlar yüklenemedi. Yeniden deneyin.');
  return data ?? [];
}
export async function saveNote(ownerId: string, draft: NoteDraft, previous?: Note): Promise<Note> {
  const input = {title:draft.title.trim(), body:draft.body, priority:draft.priority};
  if(!input.title || input.title.length>120 || input.body.length>4000 || !['low','normal','high'].includes(input.priority)) throw new Error('Başlık 1–120, not en fazla 4000 karakter olmalı.');
  // The captured owner prevents a request begun in account A from being saved
  // to account B if the underlying client session changes before dispatch.
  const query = previous ? client.from('member_notes').update(input).eq('id',previous.id).eq('owner_id',ownerId).eq('updated_at',previous.updated_at)
    : client.from('member_notes').insert({...input, owner_id:ownerId});
  const {data,error} = await query.select(fields).maybeSingle();
  if(error) throw new Error('Not kaydedilemedi. Bağlantınızı kontrol edip yeniden deneyin.');
  if(!data) throw new Error('Not değişmiş veya erişiminiz sona ermiş. Notları yenileyin.');
  return data;
}
export async function deleteNote(ownerId: string, note: Note): Promise<void> {
  const {data,error} = await client.from('member_notes').delete().eq('id',note.id).eq('owner_id',ownerId).eq('updated_at',note.updated_at).select('id').maybeSingle();
  if(error) throw new Error('Not silinemedi. Yeniden deneyin.');
  if(!data) throw new Error('Not değişmiş veya erişiminiz sona ermiş. Notları yenileyin.');
}
