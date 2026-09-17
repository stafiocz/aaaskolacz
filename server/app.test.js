import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import pg from 'pg';
import { createApp } from './app.js';
import { migrate, hashToken } from './database.js';

assert.match(process.env.PGDATABASE ?? '', /_test$/, 'Tests require a dedicated *_test database');
const pool = new pg.Pool();
const origin = 'https://aaaskola.cz';
let server, base;
before(async () => { await migrate(pool); await migrate(pool); });
after(async () => pool.end());
beforeEach(async () => {
  await pool.query('TRUNCATE users CASCADE');
  server = createApp({ pool, origin, clientId: 'test.apps.googleusercontent.com',
    verifyIdentity: async token => {
      if (!['alice', 'bob'].includes(token)) throw new Error('Invalid identity');
      return { sub: token, name: token, email: `${token}@example.test` };
    },
  }).listen(0, '127.0.0.1');
  await once(server, 'listening');
  base = `http://127.0.0.1:${server.address().port}`;
});
afterEach(async () => { server.close(); await once(server, 'close'); });

async function signIn(identity = 'alice') {
  const start = await fetch(base + '/login');
  const nonceCookie = start.headers.getSetCookie()[0].split(';')[0];
  const nonce = nonceCookie.split('=')[1];
  const response = await fetch(base + '/api/auth/google', { method: 'POST',
    headers: { 'Content-Type': 'application/json', Origin: origin, Cookie: nonceCookie },
    body: JSON.stringify({ nonce, credential: identity }) });
  assert.equal(response.status, 200);
  const cookie = response.headers.getSetCookie()[0];
  assert.match(cookie, /HttpOnly/); assert.match(cookie, /Secure/); assert.match(cookie, /SameSite=Lax/);
  const me = await (await fetch(base + '/api/me', { headers: { Cookie: cookie.split(';')[0] } })).json();
  return { cookie: cookie.split(';')[0], ...me };
}
function attempt(values = {}) {
  return { id: randomUUID(), exerciseId: randomUUID(), subject: 'math', grade: 5,
    correct: true, completed: true, occurredAt: '2026-03-29T12:00:00.000Z', ...values };
}
function post(path, session, body, headers = {}) {
  return fetch(base + path, { method: 'POST', headers: {
    'Content-Type': 'application/json', Origin: origin, Cookie: session.cookie,
    'X-CSRF-Token': session.csrf, ...headers }, body: JSON.stringify(body) });
}
async function stats(session, from = '2026-03-01', to = '2026-03-31') {
  const response = await fetch(base + `/api/stats?from=${from}&to=${to}`, { headers: { Cookie: session.cookie } });
  assert.equal(response.status, 200); return (await response.json()).days;
}

test('health checks database; guest cannot read or write results', async () => {
  assert.equal((await fetch(base + '/healthz')).status, 200);
  assert.equal((await (await fetch(base + '/api/me')).json()).user, null);
  assert.equal((await fetch(base + '/api/stats')).status, 401);
  assert.equal((await fetch(base + '/api/attempts', { method: 'POST' })).status, 401);
});
test('Google login requires same origin, matching nonce cookie and a verified identity', async () => {
  const start = await fetch(base + '/login');
  const cookie = start.headers.getSetCookie()[0].split(';')[0];
  const nonce = cookie.split('=')[1];
  const session = { cookie, csrf: '' };
  assert.equal((await post('/api/auth/google', session, { nonce, credential: 'alice' }, { Origin: 'https://evil.test' })).status, 403);
  assert.equal((await post('/api/auth/google', session, { nonce: '0'.repeat(64), credential: 'alice' })).status, 403);
  assert.equal((await post('/api/auth/google', session, { nonce, credential: 'forged' })).status, 401);
  assert.equal((await pool.query('SELECT count(*)::int AS n FROM users')).rows[0].n, 0);
});
test('sessions are hashed, expire, and are invalidated by logout', async () => {
  const session = await signIn();
  const token = session.cookie.split('=')[1];
  const stored = (await pool.query('SELECT token_hash FROM sessions')).rows[0].token_hash;
  assert.notEqual(stored, token); assert.equal(stored, hashToken(token));
  assert.equal((await post('/api/logout', session)).status, 204);
  assert.equal((await (await fetch(base + '/api/me', { headers: { Cookie: session.cookie } })).json()).user, null);
  const fresh = await signIn();
  await pool.query("UPDATE sessions SET expires_at = now() - interval '1 second'");
  assert.equal((await post('/api/attempts', fresh, attempt())).status, 401);
});
test('account is stable across logins and results are isolated by session owner', async () => {
  const alice = await signIn(), aliceAgain = await signIn(), bob = await signIn('bob');
  assert.equal(alice.user.id, aliceAgain.user.id);
  const payload = attempt({ userId: bob.user.id });
  assert.equal((await post('/api/attempts', alice, payload)).status, 201);
  assert.equal((await stats(alice)).length, 1); assert.deepEqual(await stats(bob), []);
});
test('CSRF and cross-origin attempts are rejected including multibyte tokens', async () => {
  const session = await signIn();
  for (const headers of [{ 'X-CSRF-Token': '' }, { Origin: 'https://evil.test' }, { 'X-CSRF-Token': 'é'.repeat(64) }]) {
    assert.equal((await post('/api/attempts', session, attempt(), headers)).status, 403);
  }
  assert.deepEqual(await stats(session), []);
});
test('concurrent retries are idempotent and a changed payload conflicts', async () => {
  const session = await signIn(), payload = attempt();
  const responses = await Promise.all(Array.from({ length: 6 }, () => post('/api/attempts', session, payload)));
  assert.deepEqual(responses.map(r => r.status).sort(), [200, 200, 200, 200, 200, 201]);
  assert.equal((await post('/api/attempts', session, { ...payload, correct: false, completed: false })).status, 409);
  assert.equal((await post('/api/attempts', session, { ...payload, id: randomUUID() })).status, 409);
  assert.equal((await stats(session))[0].correct, 1);
});
test('math chain counts both steps and retries but only one completion; English is separate', async () => {
  const session = await signIn(), exerciseId = randomUUID();
  for (const [correct, completed] of [[false, false], [true, false], [true, true]]) {
    assert.equal((await post('/api/attempts', session, attempt({ exerciseId, correct, completed }))).status, 201);
  }
  const word = randomUUID();
  for (const correct of [false, true]) {
    assert.equal((await post('/api/attempts', session, attempt({ exerciseId: word, subject: 'english', correct, completed: correct }))).status, 201);
  }
  assert.deepEqual(await stats(session), [
    { day: '2026-03-29', subject: 'english', grade: 5, practiced: 1, correct: 1, incorrect: 1, completed: 1 },
    { day: '2026-03-29', subject: 'math', grade: 5, practiced: 1, correct: 2, incorrect: 1, completed: 1 },
  ]);
});
test('offline events use Czech calendar days across midnight and daylight saving', async () => {
  const session = await signIn();
  for (const occurredAt of ['2026-03-28T22:59:59.000Z', '2026-03-28T23:00:00.000Z', '2026-03-29T21:59:59.000Z', '2026-03-29T22:00:00.000Z']) {
    assert.equal((await post('/api/attempts', session, attempt({ occurredAt }))).status, 201);
  }
  const rows = await stats(session, '2026-03-29', '2026-03-29');
  assert.equal(rows.length, 1); assert.equal(rows[0].completed, 2);
});
test('invalid answers, grades, dates and completed failures are rejected', async () => {
  const session = await signIn();
  for (const values of [{ grade: 7 }, { subject: 'english', grade: 3 }, { correct: false },
    { id: 'bad' }, { occurredAt: 'invalid' }, { occurredAt: '2099-01-01T00:00:00.000Z' }]) {
    assert.equal((await post('/api/attempts', session, attempt(values))).status, 400);
  }
  for (const query of ['from=2026-02-30&to=2026-03-01', 'from=2026-03-03&to=2026-03-02', 'from=2020-01-01&to=2026-01-01']) {
    assert.equal((await fetch(base + '/api/stats?' + query, { headers: { Cookie: session.cookie } })).status, 400);
  }
});
