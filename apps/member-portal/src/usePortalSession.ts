import { useEffect, useState } from 'react';
import type { User } from '@supabase/supabase-js';
import { client } from './client';

export function usePortalSession() {
  const [state, setState] = useState<{ user: User | null; loading: boolean; error: boolean }>({ user: null, loading: true, error: false });
  useEffect(() => {
    let active = true;
    let generation = 0;
    const request = generation;
    // No DB/network calls from the auth callback. A later event wins over the
    // initial lookup, so sign-out/account switches cannot resurrect old data.
    const { data: { subscription } } = client.auth.onAuthStateChange((_event, session) => {
      if (!active) return;
      generation++;
      setState({ user: session?.user ?? null, loading: false, error: false });
    });
    void client.auth.getSession().then(({ data, error }) => {
      if (active && request === generation) setState({ user: data.session?.user ?? null, loading: false, error: !!error });
    }).catch(() => {
      if (active && request === generation) setState({ user: null, loading: false, error: true });
    });
    return () => { active = false; subscription.unsubscribe(); };
  }, []);
  return state;
}
