import { test, before, after, beforeEach, afterEach } from 'node:test';
import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { once } from 'node:events';
import pg from 'pg';
import { createApp } from './app.js';
import { migrate, hashToken, dailyGoals } from './database.js';

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
  assert.equal((await fetch(base + '/api/daily-goals')).status, 401);
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
    { day: '2026-03-29', subject: 'english', grade: 5, subjectName: 'Angličtina', subjectKind: 'vocabulary', gradeName: '5. třída', practiced: 1, correct: 1, incorrect: 1, completed: 1 },
    { day: '2026-03-29', subject: 'math', grade: 5, subjectName: 'Matematika', subjectKind: 'math', gradeName: '5. třída', practiced: 1, correct: 2, incorrect: 1, completed: 1 },
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

test('catalog migration preserves legacy accounts, sessions and results and never reseeds edits', async () => {
  const schema = `migration_${randomUUID().replaceAll('-', '')}`;
  await pool.query(`CREATE SCHEMA ${schema}`);
  const isolated = new pg.Pool({ options: `-c search_path=${schema}` });
  try {
    const { readFile } = await import('node:fs/promises');
    const { login, dailyStats } = await import('./database.js');
    await isolated.query(await readFile(new URL('./schema.sql', import.meta.url), 'utf8'));
    const session = await login(isolated, { sub: 'legacy', name: 'Legacy', email: 'legacy@example.test' });
    const legacy = attempt();
    await isolated.query("INSERT INTO exercises(user_id,id,subject,grade,completed) VALUES ($1,$2,'math',5,true)", [session.user.id, legacy.exerciseId]);
    await isolated.query('INSERT INTO attempts VALUES ($1,$2,$3,true,true,$4)', [session.user.id, legacy.id, legacy.exerciseId, legacy.occurredAt]);
    await migrate(isolated);
    assert.equal((await dailyStats(isolated, session.user.id, '2026-03-01', '2026-03-31'))[0].correct, 1);
    assert.equal((await isolated.query('SELECT count(*)::int n FROM sessions')).rows[0].n, 1);
    await isolated.query("UPDATE practice_items SET active=false WHERE id='3-math-additionSubtraction-1'");
    await isolated.query("UPDATE school_grades SET name='Třeťáci' WHERE id=3");
    await migrate(isolated);
    assert.equal((await isolated.query("SELECT active FROM practice_items WHERE id='3-math-additionSubtraction-1'")).rows[0].active, false);
    assert.equal((await isolated.query('SELECT name FROM school_grades WHERE id=3')).rows[0].name, 'Třeťáci');
    assert.equal((await isolated.query('SELECT count(*)::int n FROM practice_items')).rows[0].n, 1283);
  } finally {
    await isolated.end();
    await pool.query(`DROP SCHEMA ${schema} CASCADE`);
  }
});

test('daily goals count completed math and distinct words, persist across logins and isolate users', async () => {
  const session = await signIn();
  const { rows: words } = await pool.query("SELECT id FROM practice_items WHERE grade=5 AND subject='english' ORDER BY id LIMIT 16");
  const occurredAt = new Date().toISOString();
  const read = async (owner = session) => {
    const response = await fetch(base + '/api/daily-goals', { headers: { Cookie: owner.cookie } });
    assert.equal(response.status, 200);
    return response.json();
  };
  for (let n = 0; n < 14; n++) {
    assert.equal((await post('/api/attempts', session, attempt({ occurredAt, grade: n % 2 ? 3 : 5 }))).status, 201);
    assert.equal((await post('/api/attempts', session, attempt({ occurredAt, subject: 'english', itemId: words[n].id }))).status, 201);
  }
  const chain = randomUUID();
  await post('/api/attempts', session, attempt({ occurredAt, exerciseId: chain, completed: false }));
  await post('/api/attempts', session, attempt({ occurredAt, correct: false, completed: false }));
  await post('/api/attempts', session, attempt({ occurredAt, subject: 'english', itemId: words[0].id }));
  let result = await read();
  assert.equal(result.target, 15); assert.equal(result.math, 14); assert.equal(result.vocabulary, 14);
  const completed = attempt({ occurredAt, exerciseId: chain });
  assert.equal((await post('/api/attempts', session, completed)).status, 201);
  assert.equal((await post('/api/attempts', session, completed)).status, 200);
  await post('/api/attempts', session, attempt({ occurredAt, subject: 'english', itemId: words[14].id }));
  result = await read(await signIn());
  assert.equal(result.math, 15); assert.equal(result.vocabulary, 15);
  assert.equal(result.wordIds.length, 15);
  await post('/api/attempts', session, attempt({ occurredAt }));
  await post('/api/attempts', session, attempt({ occurredAt, subject: 'english', itemId: words[15].id }));
  assert.equal((await read()).math, 16); assert.equal((await read()).vocabulary, 16);
  const bob = await read(await signIn('bob'));
  assert.equal(bob.math, 0); assert.equal(bob.vocabulary, 0);
});

test('daily goals reset at Czech midnight including daylight saving and count old offline events on their day', async () => {
  const session = await signIn();
  for (const occurredAt of ['2026-03-28T22:59:59.000Z', '2026-03-28T23:00:00.000Z', '2026-03-29T21:59:59.000Z', '2026-03-29T22:00:00.000Z']) {
    await post('/api/attempts', session, attempt({ occurredAt }));
  }
  const spring = await dailyGoals(pool, session.user.id, new Date('2026-03-29T12:00:00Z'));
  assert.equal(spring.day, '2026-03-29'); assert.equal(spring.math, 2);
  assert.equal(spring.resetsAt.toISOString(), '2026-03-29T22:00:00.000Z');
  const next = await dailyGoals(pool, session.user.id, spring.resetsAt);
  assert.equal(next.day, '2026-03-30'); assert.equal(next.math, 1);
  const autumn = await dailyGoals(pool, session.user.id, new Date('2026-10-25T12:00:00Z'));
  assert.equal(autumn.resetsAt.toISOString(), '2026-10-25T23:00:00.000Z');
  assert.equal(autumn.math, 0);
});

test('word identity must belong to the course and cannot change on a retry', async () => {
  const session = await signIn();
  const { rows: words } = await pool.query("SELECT id FROM practice_items WHERE grade=5 AND subject='english' ORDER BY id LIMIT 2");
  for (const itemId of ['missing', words[0].id, 123]) {
    assert.equal((await post('/api/attempts', session, attempt({ itemId }))).status, 400);
  }
  const payload = attempt({ subject: 'english', itemId: words[0].id });
  assert.equal((await post('/api/attempts', session, payload)).status, 201);
  assert.equal((await post('/api/attempts', session, { ...payload, itemId: words[1].id })).status, 409);
});

async function importTransaction(content, check = false) {
  const { importContent } = await import('./catalog.js');
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const count = await importContent(client, content);
    await client.query(check ? 'ROLLBACK' : 'COMMIT');
    return count;
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}
const newWord = { english: 'Haus', czech: 'dům', topic: 'Doma', page: 1, alternatives: ['das Haus'] };
const newContent = () => ({
  grades: [{ id: 4, name: '4. třída' }],
  subjects: [{ id: 'german', slug: 'nemcina', name: 'Němčina', kind: 'vocabulary', answerLanguage: 'německy' }],
  courses: [{ grade: 4, subject: 'german', description: 'Slovíčka', maxDigits: 3,
    items: [{ id: 'test-house', data: newWord }] }],
});

test('database-only changes appear in catalog immediately and new courses record separate results', async () => {
  const session = await signIn(), bob = await signIn('bob');
  const catalog = async () => {
    const response = await fetch(base + '/api/catalog');
    assert.equal(response.status, 200);
    assert.match(response.headers.get('cache-control'), /no-store/);
    return response.json();
  };
  const initial = await catalog();
  assert.equal(initial.courses.reduce((n, c) => n + c.items.length, 0), 1283);
  try {
    await importTransaction(newContent());
    const updated = await catalog();
    assert.equal(updated.grades.find(g => g.id === 4).name, '4. třída');
    assert.equal(updated.subjects.find(s => s.id === 'german').name, 'Němčina');
    assert.equal(updated.courses.find(c => c.grade === 4).items[0].data.czech, 'dům');
    assert.equal((await post('/api/attempts', session, attempt({ grade: 4, subject: 'german' }))).status, 201);
    const rows = await stats(session);
    assert.equal(rows[0].subjectName, 'Němčina'); assert.equal(rows[0].completed, 1);
    assert.deepEqual(await stats(bob), []);
    await importTransaction({ courses: [{ grade: 4, subject: 'german', items: [
      { id: 'test-house', data: newWord, active: false },
    ] }] });
    const hidden = (await catalog()).courses.find(c => c.grade === 4);
    assert.equal(hidden.items.length, 0); assert.equal(hidden.description, 'Slovíčka'); assert.equal(hidden.maxDigits, 3);
    await pool.query('UPDATE school_grades SET active=false WHERE id=4');
    assert.equal((await catalog()).courses.some(c => c.grade === 4), false);
    assert.equal((await stats(session))[0].completed, 1);
  } finally {
    await pool.query('TRUNCATE users CASCADE');
    await pool.query("DELETE FROM practice_items WHERE subject='german'; DELETE FROM school_courses WHERE subject='german'; DELETE FROM school_subjects WHERE id='german'; DELETE FROM school_grades WHERE id=4");
  }
});

test('content import validates entire transaction, preserves courses, and supports dry run', async () => {
  assert.equal(await importTransaction(newContent(), true), 1);
  assert.equal((await pool.query('SELECT 1 FROM school_grades WHERE id=4')).rowCount, 0);
  for (const edit of [
    content => { content.courses[0].items[0].data.english = ''; },
    content => { content.courses[0].items[0].id = '5-english-1'; },
    content => { delete content.subjects[0].id; },
    content => { content.courses[0].active = 'false'; },
    content => { content.courses[0].items.push(content.courses[0].items[0]); },
  ]) {
    const content = newContent();
    content.courses[0].items[0].data = { ...newWord };
    edit(content);
    await assert.rejects(importTransaction(content));
    assert.equal((await pool.query('SELECT 1 FROM school_grades WHERE id=4')).rowCount, 0);
  }
  await assert.rejects(importTransaction({ courses: [{ grade: 5, subject: 'math', maxDigits: 1, items: [] }] }));
  assert.equal((await pool.query("SELECT max_digits FROM school_courses WHERE grade=5 AND subject='math'")).rows[0].max_digits, 7);
});
