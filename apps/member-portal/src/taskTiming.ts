import type { PortalTask } from './types';

export type TimingKind = 'scheduled' | 'soon' | 'urgent' | 'overdue' | 'onTime' | 'late' | 'completedUnknown' | 'undated' | 'invalid' | 'unknownStatus';
export interface TaskTiming { kind: TimingKind; label: string; tone: 'blue' | 'yellow' | 'orange' | 'red' | 'green' | 'neutral'; alert: boolean }
export const isComplete = (task: PortalTask) => task.status === 'completed' || task.status === 'done';
const timestamp = (value?: string | null) => value ? Date.parse(value) : NaN;
export function taskTiming(task: PortalTask, now: number): TaskTiming {
  const deadline = timestamp(task.deadline);
  if (isComplete(task)) {
    const completed = timestamp(task.completed_at);
    if (!Number.isFinite(completed) || !Number.isFinite(deadline)) {
      return { kind: 'completedUnknown', label: 'Tamamlandı · zaman bilgisi yok', tone: 'neutral', alert: false };
    }
    return completed <= deadline
      ? { kind: 'onTime', label: 'Zamanında tamamlandı', tone: 'green', alert: false }
      : { kind: 'late', label: 'Geç tamamlandı', tone: 'red', alert: false };
  }
  if (!['backlog', 'started', 'in_progress'].includes(task.status ?? '')) {
    return { kind: 'unknownStatus', label: 'Durum doğrulanamadı', tone: 'neutral', alert: false };
  }
  if (!task.deadline) return { kind: 'undated', label: 'Son tarih yok', tone: 'neutral', alert: false };
  if (!Number.isFinite(deadline)) return { kind: 'invalid', label: 'Tarih doğrulanamadı', tone: 'neutral', alert: false };
  const remaining = deadline - now;
  if (remaining < 0) return { kind: 'overdue', label: 'Son tarih geçti', tone: 'red', alert: true };
  if (remaining <= 24 * 60 * 60 * 1000) return { kind: 'urgent', label: 'Son 24 saat', tone: 'orange', alert: true };
  if (remaining <= 72 * 60 * 60 * 1000) return { kind: 'soon', label: 'Son 3 gün', tone: 'yellow', alert: true };
  return { kind: 'scheduled', label: 'Zaman var', tone: 'blue', alert: false };
}
const dateFormat = new Intl.DateTimeFormat('tr-TR', { timeZone: 'Europe/Istanbul', dateStyle: 'medium', timeStyle: 'short' });
export function formatTaskDate(value?: string | null) {
  const time = timestamp(value);
  return Number.isFinite(time) ? dateFormat.format(time) : '—';
}
export function taskSummary(tasks: PortalTask[], now: number) {
  const complete = tasks.filter(isComplete).length;
  const overdue = tasks.filter(task => taskTiming(task, now).kind === 'overdue').length;
  return { total: tasks.length, complete, overdue, active: tasks.length - complete, other: tasks.length - complete - overdue };
}
