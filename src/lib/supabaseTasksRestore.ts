import { supabase } from './supabase';

// The database moves both rows atomically and enforces admin authorization.
export async function restoreArchivedTaskToDone(taskId: string): Promise<{ restored: boolean }> {
  const { error } = await supabase.rpc('restore_archived_task', { task_id: taskId });
  if (error) throw new Error(error.message || 'İşlem tamamlanamadı');
  return { restored: true };
}
