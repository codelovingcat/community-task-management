import { useEffect, useState } from 'react';
import type { PortalTask } from './types';
import { formatTaskDate, taskTiming } from './taskTiming';

export function TaskBadge({ task, now }: { task: PortalTask; now: number }) {
  const timing = taskTiming(task, now);
  return <span className={`task-badge tone-${timing.tone}`}>
    {timing.alert && <span aria-hidden="true" className={`alert-dot${timing.kind === 'overdue' ? ' pulsing' : ''}`}>!</span>}
    {timing.label}
  </span>;
}
export function TaskList({ title, tasks, now, empty }: { title: string; tasks: PortalTask[]; now: number; empty: string }) {
  const [page, setPage] = useState(1);
  const totalPages = Math.max(1, Math.ceil(tasks.length / 8));
  const currentPage = Math.min(page, totalPages);
  useEffect(() => { setPage(1); }, [tasks]);
  const visible = tasks.slice((currentPage - 1) * 8, currentPage * 8);
  return <section className="card task-section" aria-label={title}>
    <div className="section-title"><h2>{title}</h2><span className="count">{tasks.length}</span></div>
    {!tasks.length ? <p className="muted empty-state">{empty}</p> : <div className="table-scroll">
      <table><caption className="sr-only">{title} · Tarihler İstanbul saatine göredir.</caption>
        <thead><tr><th scope="col">Görev</th><th scope="col">Son tarih</th><th scope="col">Durum</th><th scope="col"><span className="sr-only">Detay</span></th></tr></thead>
        <tbody>{visible.map(task => <tr key={task.id}>
          <th scope="row"><a className="task-title" href={`?task=${encodeURIComponent(task.id)}`}>{task.title}</a>{task.archived && <span className="small muted"> · Arşiv</span>}
            {task.description && <p className="task-excerpt">{task.description.slice(0, 95)}{task.description.length > 95 ? '…' : ''}</p>}
          </th>
          <td className="date-cell">{formatTaskDate(task.deadline)}</td>
          <td><TaskBadge task={task} now={now} /></td>
          <td><a className="task-link" href={`?task=${encodeURIComponent(task.id)}`} aria-label={`${task.title} görevine git`}>Göreve git <span aria-hidden="true">↗</span></a></td>
        </tr>)}</tbody>
      </table>
    </div>}
    {totalPages > 1 && <nav className="pagination" aria-label={`${title} sayfaları`}>
      <button disabled={currentPage === 1} onClick={() => setPage(currentPage - 1)}>Önceki</button>
      <span>{currentPage} / {totalPages}</span>
      <button disabled={currentPage === totalPages} onClick={() => setPage(currentPage + 1)}>Sonraki</button>
    </nav>}
  </section>;
}
