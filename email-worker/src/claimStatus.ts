import 'dotenv/config';
import { getSupabaseClient } from './supabaseClient';

const tables = ['email_queue', 'speaker_email_queue'] as const;

/** Read only counts: stale claims need human/provider reconciliation, not an automatic retry. */
export async function getStaleClaimCounts(cutoff: Date): Promise<Record<string, number>> {
  const client = getSupabaseClient();
  const counts: Record<string, number> = {};
  for (const table of tables) {
    const { count, error } = await client.from(table)
      .select('id', { count: 'exact', head: true })
      .eq('status', 'pending')
      .not('delivery_claim_token', 'is', null)
      .or(`delivery_claimed_at.is.null,delivery_claimed_at.lt.${cutoff.toISOString()}`);
    if (error || count === null || !Number.isSafeInteger(count) || count < 0) throw new Error(`Could not inspect ${table} claims`);
    counts[table] = count;
  }
  return counts;
}

async function main(): Promise<void> {
  // Allow time for normal provider requests and a slow database update.
  const cutoff = new Date(Date.now() - 15 * 60 * 1000);
  const counts = await getStaleClaimCounts(cutoff);
  for (const table of tables) console.log(`${table}: ${counts[table]} pending claims older than 15 minutes or missing a timestamp`);
  if (Object.values(counts).some((count) => count > 0)) process.exitCode = 2;
}

if (require.main === module) {
  void main().catch(() => {
    console.error('Unable to inspect delivery claims. Check server configuration and database access.');
    process.exitCode = 1;
  });
}
