import React, { useCallback, useEffect, useState } from 'react';
import { Bell, CheckCheck, ChevronLeft, ChevronRight, Trash2 } from 'lucide-react';
import { FullNotification, NotificationType, NOTIFICATION_TYPE_CONFIG } from '../types/notification';
import { clearAllNotifications, deleteNotification, getNotifications, markAllAsRead, markAsRead } from '../lib/supabaseNotifications';
import { useUserProfile } from '../context/UserProfileContext';

const PAGE_SIZE = 20;

export const NotificationsPage: React.FC = () => {
  const { profile, isLoading: profileLoading } = useUserProfile();
  const [items, setItems] = useState<FullNotification[]>([]);
  const [page, setPage] = useState(1);
  const [total, setTotal] = useState(0);
  const [type, setType] = useState<NotificationType | ''>('');
  const [readFilter, setReadFilter] = useState<'all' | 'unread' | 'read'>('all');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (!profile?.id) {
      setItems([]);
      setTotal(0);
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const response = await getNotifications({
        page,
        limit: PAGE_SIZE,
        user_id: profile.id,
        ...(type ? { type } : {}),
        ...(readFilter === 'all' ? {} : { is_read: readFilter === 'read' }),
      });
      setItems(response.data);
      setTotal(response.total);
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Bildirimler yüklenemedi.');
    } finally {
      setLoading(false);
    }
  }, [profile?.id, page, type, readFilter]);

  useEffect(() => { void load(); }, [load]);

  const handleMarkAllRead = async () => {
    if (!profile?.id) return;
    try {
      await markAllAsRead(profile.id);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Bildirimler okundu işaretlenemedi.');
    }
  };

  const handleDelete = async (id: string) => {
    try {
      await deleteNotification(id);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Bildirim silinemedi.');
    }
  };

  const handleClearAll = async () => {
    if (!profile?.id || !window.confirm('Tüm bildirimlerini silmek istiyor musun? Bu işlem geri alınamaz.')) return;
    try {
      await clearAllNotifications(profile.id);
      setPage(1);
      await load();
    } catch (e) {
      setError(e instanceof Error ? e.message : 'Bildirimler silinemedi.');
    }
  };

  const handleOpen = async (notification: FullNotification) => {
    if (!notification.is_read) {
      try {
        await markAsRead(notification.id);
        setItems((prev) => prev.map((item) => item.id === notification.id
          ? { ...item, is_read: true, read_at: new Date().toISOString() }
          : item));
      } catch (e) {
        setError(e instanceof Error ? e.message : 'Bildirim okundu işaretlenemedi.');
      }
    }
  };

  const totalPages = Math.max(1, Math.ceil(total / PAGE_SIZE));

  if (profileLoading) {
    return <div className="p-8 text-sm text-[var(--text-secondary)]">Bildirimler yükleniyor…</div>;
  }
  if (!profile?.id) {
    return <div className="p-8 text-sm text-[var(--text-secondary)]">Bildirimleri görmek için oturum açmalısın.</div>;
  }

  return (
    <main className="mx-auto max-w-5xl p-6 md:p-8">
      <div className="mb-6 flex flex-wrap items-start justify-between gap-4">
        <div>
          <h1 className="text-2xl font-semibold text-[var(--text-primary)]">Bildirim Merkezi</h1>
          <p className="mt-1 text-sm text-[var(--text-secondary)]">Geçmiş bildirimlerini görüntüle ve yönet.</p>
        </div>
        <div className="flex flex-wrap gap-2">
          <button onClick={handleMarkAllRead} className="inline-flex items-center gap-2 rounded-lg border border-[var(--border-color)] px-3 py-2 text-sm text-[var(--text-primary)] hover:bg-[var(--bg-tertiary)]">
            <CheckCheck className="h-4 w-4" /> Tümünü okundu yap
          </button>
          <button onClick={handleClearAll} className="inline-flex items-center gap-2 rounded-lg border border-red-500/30 px-3 py-2 text-sm text-red-500 hover:bg-red-500/10">
            <Trash2 className="h-4 w-4" /> Tümünü sil
          </button>
        </div>
      </div>

      <div className="mb-5 flex flex-wrap gap-3">
        <label className="flex flex-col gap-1 text-xs text-[var(--text-secondary)]">
          Tür
          <select value={type} onChange={(e) => { setType(e.target.value as NotificationType | ''); setPage(1); }} className="min-w-44 rounded-lg border border-[var(--border-color)] bg-[var(--bg-card)] px-3 py-2 text-sm text-[var(--text-primary)]">
            <option value="">Tüm türler</option>
            {Object.entries(NOTIFICATION_TYPE_CONFIG).map(([key, value]) => <option key={key} value={key}>{value.label}</option>)}
          </select>
        </label>
        <label className="flex flex-col gap-1 text-xs text-[var(--text-secondary)]">
          Durum
          <select value={readFilter} onChange={(e) => { setReadFilter(e.target.value as 'all' | 'unread' | 'read'); setPage(1); }} className="min-w-44 rounded-lg border border-[var(--border-color)] bg-[var(--bg-card)] px-3 py-2 text-sm text-[var(--text-primary)]">
            <option value="all">Tümü</option>
            <option value="unread">Okunmamış</option>
            <option value="read">Okunmuş</option>
          </select>
        </label>
      </div>

      {error && <div role="alert" className="mb-4 rounded-lg border border-red-500/30 bg-red-500/10 p-3 text-sm text-red-500">{error}</div>}

      <section className="overflow-hidden rounded-xl border border-[var(--border-color)] bg-[var(--bg-card)]">
        {loading ? (
          <div className="p-8 text-center text-sm text-[var(--text-secondary)]">Yükleniyor…</div>
        ) : items.length === 0 ? (
          <div className="flex flex-col items-center gap-2 p-12 text-center text-[var(--text-secondary)]">
            <Bell className="h-8 w-8 opacity-50" />
            <p className="font-medium">Bu filtrede bildirim yok.</p>
          </div>
        ) : (
          <ul className="divide-y divide-[var(--border-color)]">
            {items.map((notification) => (
              <li key={notification.id} className={'flex items-start gap-3 p-4 ' + (notification.is_read ? 'opacity-75' : 'bg-[var(--bg-tertiary)]/40')}>
                <div className={'mt-1 h-2.5 w-2.5 shrink-0 rounded-full ' + (notification.is_read ? 'bg-transparent' : 'bg-[var(--accent)]')} />
                <button onClick={() => void handleOpen(notification)} className="min-w-0 flex-1 text-left">
                  <div className="flex flex-wrap items-center gap-2">
                    <span className="font-medium text-[var(--text-primary)]">{notification.title}</span>
                    <span className="rounded-full bg-[var(--bg-tertiary)] px-2 py-0.5 text-xs text-[var(--text-secondary)]">{NOTIFICATION_TYPE_CONFIG[notification.type]?.label ?? notification.type}</span>
                  </div>
                  <p className="mt-1 text-sm text-[var(--text-secondary)]">{notification.message}</p>
                  <time className="mt-2 block text-xs text-[var(--text-secondary)]">{new Date(notification.created_at).toLocaleString('tr-TR')}</time>
                </button>
                <button aria-label="Bildirimi sil" onClick={() => void handleDelete(notification.id)} className="rounded-lg p-2 text-[var(--text-secondary)] hover:bg-red-500/10 hover:text-red-500">
                  <Trash2 className="h-4 w-4" />
                </button>
              </li>
            ))}
          </ul>
        )}
      </section>

      <div className="mt-4 flex items-center justify-between text-sm text-[var(--text-secondary)]">
        <span>{total} bildirim · Sayfa {page} / {totalPages}</span>
        <div className="flex gap-2">
          <button disabled={page <= 1 || loading} onClick={() => setPage((current) => Math.max(1, current - 1))} className="rounded-lg border border-[var(--border-color)] p-2 disabled:opacity-40" aria-label="Önceki sayfa"><ChevronLeft className="h-4 w-4" /></button>
          <button disabled={page >= totalPages || loading} onClick={() => setPage((current) => Math.min(totalPages, current + 1))} className="rounded-lg border border-[var(--border-color)] p-2 disabled:opacity-40" aria-label="Sonraki sayfa"><ChevronRight className="h-4 w-4" /></button>
        </div>
      </div>
    </main>
  );
};
