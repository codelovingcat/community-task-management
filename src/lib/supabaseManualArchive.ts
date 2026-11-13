import { supabase } from './supabase';

// The database moves both rows atomically and enforces admin authorization.
export async function archiveTaskNow(taskId: string): Promise<{ moved: boolean }> {
  const { error } = await supabase.rpc('archive_single_task', { p_task_id: taskId });
  if (error) throw new Error(error.message || 'İşlem tamamlanamadı');
  return { moved: true };
}
