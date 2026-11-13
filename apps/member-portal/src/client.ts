import { createClient } from '@supabase/supabase-js';
import { getRequiredSupabaseConfig } from '../../../src/lib/supabaseConfig.js';

const config = getRequiredSupabaseConfig(import.meta.env.VITE_SUPABASE_URL, import.meta.env.VITE_SUPABASE_ANON_KEY);
export const client = createClient(config.url, config.anonKey, {
  auth: { flowType: 'pkce', persistSession: true, autoRefreshToken: true, detectSessionInUrl: false },
});
