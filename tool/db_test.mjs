// Runs the backend SQL tests on PGlite (Postgres in WASM), no Docker needed.
// For each supabase/tests/*.sql (except files starting with "_"): fresh database, auth stub,
// all supabase/migrations in order, then the test file. A test fails if any statement raises.
//
//   npm ci && node tool/db_test.mjs [filter]

import { readdirSync, readFileSync } from 'node:fs';
import { join } from 'node:path';
import { PGlite } from '@electric-sql/pglite';

const root = new URL('..', import.meta.url).pathname;
const migrationsDir = join(root, 'supabase/migrations');
const testsDir = join(root, 'supabase/tests');
const filter = process.argv[2] ?? '';

const read = (dir, f) => readFileSync(join(dir, f), 'utf8');
const migrations = readdirSync(migrationsDir).filter((f) => f.endsWith('.sql')).sort();
const stub = read(testsDir, '_auth_stub.sql');
const tests = readdirSync(testsDir)
  .filter((f) => f.endsWith('.sql') && !f.startsWith('_') && f.includes(filter))
  .sort();

let failed = 0;
for (const test of tests) {
  const db = new PGlite();
  let stage = 'auth stub';
  try {
    await db.exec(stub);
    for (const m of migrations) {
      stage = m;
      await db.exec(read(migrationsDir, m));
    }
    stage = test;
    await db.exec(read(testsDir, test));
    console.log(`ok   ${test}`);
  } catch (e) {
    failed++;
    console.log(`FAIL ${test} (in ${stage})\n     ${e.message}`);
  } finally {
    await db.close();
  }
}
console.log(`\n${tests.length - failed}/${tests.length} test files passed`);
process.exit(failed ? 1 : 0);
