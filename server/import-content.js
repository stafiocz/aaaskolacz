import { readFile } from 'node:fs/promises';
import pg from 'pg';
import { importContent, readCatalog } from './catalog.js';

const chunks = [];
for await (const chunk of process.stdin) chunks.push(chunk);
const content = JSON.parse(Buffer.concat(chunks).toString('utf8'));
const password = process.env.PGPASSWORD_FILE
  ? (await readFile(process.env.PGPASSWORD_FILE, 'utf8')).trim() : process.env.PGPASSWORD;
const pool = new pg.Pool({ password, max: 1, connectionTimeoutMillis: 5000 });
const client = await pool.connect();
try {
  await client.query('BEGIN');
  await client.query('SELECT pg_advisory_xact_lock(84731201)');
  const count = await importContent(client, content);
  const catalog = await readCatalog(client);
  if (process.argv.includes('--check')) {
    await client.query('ROLLBACK');
    console.log(`Validní obsah: ${count} zadání. Databáze se nezměnila.`);
  } else {
    await client.query('COMMIT');
    console.log(`Uloženo ${count} zadání. Aktivní nabídka: ${catalog.grades.length} tříd, ${catalog.courses.length} kurzů.`);
  }
} catch (error) {
  await client.query('ROLLBACK');
  console.error('Import zrušen:', error.message);
  process.exitCode = 1;
} finally { client.release(); await pool.end(); }
