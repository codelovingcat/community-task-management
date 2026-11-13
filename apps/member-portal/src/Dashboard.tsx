import { useEffect, useMemo, useState } from 'react';
import type { PortalProfile } from './types';
import { formatTaskDate, isComplete, taskSummary, taskTiming } from './taskTiming';
import { TaskBadge, TaskList } from './TaskList';
import { safeResourceUrl } from './resourceUrl';

function safePhoto(value?: string | null) {
  if (!value) return null;
  try { const url = new URL(value); return url.protocol === 'https:' && !url.username && !url.password ? url.href : null; }
  catch { return null; }
}
export function Dashboard({ data, onRefresh }: { data: PortalProfile; onRefresh: () => void }) {
  const [now, setNow] = useState(Date.now);
  const [motion, setMotion] = useState(true);
  const [search, setSearch] = useState('');
  useEffect(() => {
    const timer = setInterval(() => setNow(Date.now()), 60000);
    return () => clearInterval(timer);
  }, []);
  const stats = taskSummary(data.tasks, now);
  const shown = useMemo(() => {
    const query = search.trim().toLocaleLowerCase('tr-TR');
    return data.tasks.filter(task => `${task.title} ${task.description ?? ''}`.toLocaleLowerCase('tr-TR').includes(query));
  }, [data.tasks, search]);
  const active = useMemo(() => shown.filter(task => !isComplete(task)), [shown]);
  const completed = useMemo(() => shown.filter(isComplete), [shown]);
  const photo = safePhoto(data.member.avatar);
  const selectedId = new URLSearchParams(window.location.search).get('task');
  // A URL identifier only selects from the server-authorized self-profile.
  const selectedTask = data.tasks.find(task => task.id === selectedId);
  const resource = safeResourceUrl(selectedTask?.resource_url);
  const completeAngle = stats.total ? stats.complete / stats.total * 360 : 0;
  const overdueAngle = stats.total ? stats.overdue / stats.total * 360 : 0;
  const soon = data.tasks.filter(task => ['urgent', 'soon'].includes(taskTiming(task, now).kind)).length;
  const chart = stats.total ? `conic-gradient(#378a70 0deg ${completeAngle}deg, #cd5260 ${completeAngle}deg ${completeAngle + overdueAngle}deg, #8aa9d4 ${completeAngle + overdueAngle}deg 360deg)` : '#e6ebf2';

  return <div className={motion ? 'dashboard' : 'dashboard motion-off'}>
    <div className="page-heading"><div><p className="eyebrow">KİŞİSEL ÇALIŞMA ALANINIZ</p><h1>Merhaba, {data.member.name.split(' ')[0]}.</h1><p className="muted">Bugünün öncelikleri ve size atanan işler.</p></div><button onClick={onRefresh}>Bilgileri yenile</button></div>
    <section className="card profile-card" aria-label="Profil bilgilerim">
      <div className="avatar">{photo ? <img src={photo} alt={data.member.name} referrerPolicy="no-referrer" /> : <span aria-hidden="true">{data.member.name.slice(0, 1).toLocaleUpperCase('tr-TR')}</span>}</div>
      <div className="identity"><h2>{data.member.name}</h2><p>{[data.member.job_title, data.member.company].filter(Boolean).join(' · ') || 'Topluluk üyesi'}</p>{data.member.comm_title && <span className="role-label">{data.member.comm_title}</span>}</div>
      <dl className="contact"><div><dt>E-posta</dt><dd>{data.member.email || 'Belirtilmemiş'}</dd></div><div><dt>Telefon</dt><dd>{data.member.phone || 'Belirtilmemiş'}</dd></div></dl>
    </section>
    {data.member.bio && <section className="card"><h2>Hakkımda</h2><p className="task-description">{data.member.bio}</p></section>}
    <section className="card" aria-label="Kişisel puanım"><p className="eyebrow">KİŞİSEL PUANIM</p><h2>{data.score ?? 0} puan</h2><p className="small muted">Tamamlanan görevlerin puan toplamı. Arşivlenen işler dahildir; gecikme cezası uygulanmaz. Puanınızı yalnızca siz ve yöneticiler görebilir.</p></section>
    <div className="overview-grid">
      <section className="card progress-card" aria-label="Görev özeti">
        <div><p className="eyebrow">GENEL BAKIŞ</p><h2>Görev yolculuğunuz</h2><p className="muted small">Tamamlananlar ve sırada bekleyenler.</p>
          <ul className="chart-legend"><li><i className="legend-green" aria-hidden="true" />Tamamlanan <strong>{stats.complete}</strong></li><li><i className="legend-red" aria-hidden="true" />Geciken aktif <strong>{stats.overdue}</strong></li><li><i className="legend-blue" aria-hidden="true" />Diğer aktif <strong>{stats.other}</strong></li></ul>
        </div>
        <div className="donut" style={{ background: chart }} role="img" aria-label={`${stats.total} görev: ${stats.complete} tamamlanan, ${stats.overdue} geciken aktif, ${stats.other} diğer aktif`}><div><strong>{stats.total}</strong><span>toplam görev</span></div></div>
      </section>
      <section className="card attention-card" aria-label="Yaklaşan tarihler">
        <p className="eyebrow">ÖNCELİKLERİNİZ</p><h2>Takvim ne söylüyor?</h2>
        <div className="attention-line tone-red"><strong>{stats.overdue}</strong><span>görevin son tarihi geçti</span></div>
        <div className="attention-line tone-orange"><strong>{soon}</strong><span>görevin son tarihi yaklaşıyor</span></div>
        <p className="small muted">Son 3 gün sarı, son 24 saat turuncu; geciken görevler kırmızı gösterilir.</p>
        <label className="motion-control"><input type="checkbox" checked={motion} onChange={event => setMotion(event.target.checked)} />Uyarı animasyonlarını göster</label>
      </section>
    </div>
    {selectedId && <section className="card detail-card" aria-label="Görev detayı">
      <a href="/" className="small">← Görev listesine dön</a>
      {selectedTask ? <><h2>{selectedTask.title}</h2><TaskBadge task={selectedTask} now={now} /><p className="task-description">{selectedTask.description || 'Bu görev için açıklama eklenmemiş.'}</p><p className="small muted">Son tarih: {formatTaskDate(selectedTask.deadline)} · İstanbul</p>{resource && <p><a className="task-link" href={resource} target="_blank" rel="noopener noreferrer" referrerPolicy="no-referrer">Görev / anket bağlantısını aç ↗</a></p>}<p className="small muted">Görev değişiklikleri topluluk yöneticiniz tarafından yapılır.</p></>
        : <><h2>Görev bulunamadı</h2><p>Bu görev size atanmamış veya artık mevcut değil.</p></>}
    </section>}
    <div className="task-toolbar"><div><p className="eyebrow">GÖREVLERİM</p><h2>Yapılacaklar ve tamamlananlar</h2></div><label className="search-label"><span className="sr-only">Görevlerimde ara</span><input type="search" placeholder="Görevlerimde ara…" value={search} onChange={event => setSearch(event.target.value)} /></label></div>
    <TaskList title="Aktif görevler" tasks={active} now={now} empty={search ? 'Aramanızla eşleşen aktif görev yok.' : 'Şu anda aktif göreviniz yok.'} />
    <TaskList title="Tamamlanan görevler" tasks={completed} now={now} empty={search ? 'Aramanızla eşleşen tamamlanmış görev yok.' : 'Henüz tamamlanan göreviniz yok.'} />
    <footer className="dashboard-footer">Tarihler İstanbul saatine göredir. Tamamlanma tarihi kayıtlı olmayan geçmiş görevlerde zaman bilgisi gösterilmez.</footer>
  </div>;
}
