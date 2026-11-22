import { readFile, readdir } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { createHash } from 'node:crypto';

const root = new URL('../', import.meta.url);
// The schema-only snapshot already contains the reviewed October migrations.
// They stay immutable in git; replaying their non-idempotent policies is unsafe.
export const baselineThrough = '20261027200856';
export async function pendingFiles() { return (await migrationFiles()).filter(n=>n.slice(0,14)>baselineThrough); }
export async function migrationFiles() {
 return (await readdir(new URL('supabase/migrations/',root))).filter(n=>/^\d{14}_.+\.sql$/.test(n)).sort();
}
export async function migrationSQL(name) {
 if (!(await migrationFiles()).includes(name)) throw new Error('Unknown migration');
 return readFile(new URL(`supabase/migrations/${name}`,root),'utf8');
}
export async function freshSQL() {
 const manifest = JSON.parse(await readFile(new URL('supabase/bootstrap/manifest.json',root),'utf8'));
 for (const [file,hash] of Object.entries(manifest.covered)) {
  const actual = createHash('sha256').update(await migrationSQL(file)).digest('hex');
  if (actual !== hash) throw new Error(`Covered migration changed: ${file}`);
 }
 const baseline = await readFile(new URL('supabase/bootstrap/schema.sql',root),'utf8');
 const files = await pendingFiles();
 const reference = await readFile(new URL('supabase/bootstrap/reference-data.sql',root),'utf8');
 const chunks = [baseline, reference];
 for (const file of files) chunks.push(`-- ${file}\n${await migrationSQL(file)}`);
 // Current files contain only top-level standalone BEGIN/COMMIT lines. Preserve
 // function/DO bodies and execute the whole installation atomically.
 const history = `CREATE SCHEMA IF NOT EXISTS supabase_migrations;
CREATE TABLE IF NOT EXISTS supabase_migrations.schema_migrations(version text PRIMARY KEY,statements text[],name text);
` + (await migrationFiles()).map(f=>`INSERT INTO supabase_migrations.schema_migrations(version,name) VALUES ('${f.slice(0,14)}','${f.slice(15,-4)}');`).join('\n');
 return 'BEGIN;\n' + chunks.map(s=>s.replace(/^\s*(BEGIN|COMMIT);\s*$/gm,'')).join('\n') + '\n'+history+'\nCOMMIT;\n';
}
if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
 if (process.argv[2] !== '--fresh' || process.argv.length !== 3) {
  console.error('Usage: node scripts/database-plan.mjs --fresh > /tmp/community-fresh.sql');
  process.exitCode = 1;
 } else process.stdout.write(await freshSQL());
}
