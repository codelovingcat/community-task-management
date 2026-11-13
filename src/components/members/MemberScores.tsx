import { useEffect, useState } from 'react';
import { supabase } from '../../lib/supabase';
import { useUserProfile } from '../../context/UserProfileContext';
type Score = { member_id: string; member_name: string; total_points: number; completed_tasks: number };
export function MemberScores() {
  const { user, profile } = useUserProfile();
  const allowed = profile?.system_role === 'Admin' || profile?.system_role === 'Super Admin';
  return allowed && user ? <ScoreTable key={user.id} /> : null;
}
function ScoreTable() {
  const [rows, setRows] = useState<Score[] | null>(null);
  const [error, setError] = useState(false);
  const [attempt, setAttempt] = useState(0);
  useEffect(() => {
    let active = true;
    setRows(null); setError(false);
    void Promise.resolve(supabase.rpc('get_member_scores')).then(({data,error}) => {
      if (!active) return;
      if (error) setError(true); else setRows(data ?? []);
    }).catch(() => { if (active) setError(true); });
    return () => { active = false; };
  }, [attempt]);
  return <section className="rounded-xl border border-white/10 p-5 text-silver-200" aria-label="Üye puanları">
    <h2 className="text-lg font-semibold">Üye puanları</h2>
    <p className="text-sm">Tamamlanan ve arşivlenen görevlerin toplamı; gecikme cezası yoktur.</p>
    <button className="my-3 underline" onClick={() => setAttempt(n=>n+1)}>Puanları yenile</button>
    {error ? <p role="alert">Puanlar yüklenemedi. Yeniden deneyin.</p> : !rows ? <p role="status">Puanlar yükleniyor…</p> : <div className="max-h-80 overflow-auto"><table className="w-full text-left"><thead><tr><th>Üye</th><th>Tamamlanan</th><th>Puan</th></tr></thead><tbody>{rows.map(row=><tr key={row.member_id}><td>{row.member_name}</td><td>{row.completed_tasks}</td><td>{row.total_points}</td></tr>)}</tbody></table></div>}
  </section>;
}
