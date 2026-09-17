import { readFileSync } from 'node:fs';
import { resolve } from 'node:path';
import pg from 'pg';
import { createApp } from './app.js';
import { migrate } from './database.js';

const password = process.env.PGPASSWORD_FILE
  ? readFileSync(process.env.PGPASSWORD_FILE, 'utf8').trim() : process.env.PGPASSWORD;
const pool = new pg.Pool({ password, max: 10, connectionTimeoutMillis: 5000 });
pool.on('error', error => console.error('Database connection interrupted', error.code));
for (let attempt = 0; ; attempt++) {
  try { await migrate(pool); break; }
  catch (error) {
    if (attempt >= 29) throw error;
    console.log('Waiting for database');
    await new Promise(resolve => setTimeout(resolve, 2000));
  }
}
const origin = process.env.APP_ORIGIN || 'https://aaaskola.cz';
const clientId = process.env.GOOGLE_CLIENT_ID || '';
if (clientId && !/^[a-zA-Z0-9_-]+\.apps\.googleusercontent\.com$/.test(clientId)) throw new Error('Invalid Google client ID');
const app = createApp({ pool, origin, clientId, webRoot: resolve(process.env.WEB_ROOT || '../build/web') });
const server = app.listen(Number(process.env.PORT || 8080), '0.0.0.0', () => console.log('AAA skola ready'));
async function stop() { server.close(async () => { await pool.end(); process.exit(0); }); }
process.on('SIGTERM', stop);
process.on('SIGINT', stop);
