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
    await isolated.query("UPDATE practice_items SET active=false WHERE id='7-czech-videly'");
    await migrate(isolated);
    assert.equal((await isolated.query("SELECT active FROM practice_items WHERE id='7-czech-videly'")).rows[0].active, false);
    assert.equal((await isolated.query('SELECT count(*)::int n FROM practice_items')).rows[0].n, 1311);
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
async function mathExercise(session, grade = 5) {
  const response = await post('/api/math/exercise', session, { grade, subject: 'math', newRound: true });
  assert.equal(response.status, 200);
  return response.json();
}
async function solveMath(session, exercise) {
  const response = await post('/api/math/answer', session, {
    id: randomUUID(), exerciseId: exercise.exerciseId, step: exercise.step, revision: exercise.revision, answer: exercise.problem.answer,
  });
  assert.equal(response.status, 200);
  return response.json();
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
  assert.equal(initial.courses.reduce((n, c) => n + c.items.length, 0), 1311);
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

test('unfinished math survives navigation, concurrent tabs, logout, migration and account changes', async () => {
  const alice = await signIn();
  for (const grade of [3, 5]) {
    const first = await mathExercise(alice, grade);
    const tabs = await Promise.all(Array.from({ length: 8 }, () => mathExercise(alice, grade)));
    for (const tab of tabs) assert.deepEqual(tab, first);
    const wrong = await post('/api/math/answer', alice, {
      id: randomUUID(), exerciseId: first.exerciseId, step: first.step,
      answer: first.problem.answer === 0 ? 1 : 0,
    });
    const result = await wrong.json();
    assert.equal(result.correct, false);
    assert.equal(result.progress.total, 16);
    const next = await mathExercise(alice, grade);
    assert.notEqual(next.exerciseId, first.exerciseId);
    await migrate(pool);
    await post('/api/logout', alice);
    const again = await signIn();
    assert.deepEqual(await mathExercise(again, grade), next);
    const bob = await signIn('bob');
    assert.notEqual((await mathExercise(bob, grade)).exerciseId, first.exerciseId);
    alice.cookie = again.cookie;
    alice.csrf = again.csrf;
  }
  assert.equal((await pool.query('SELECT count(*)::int n FROM exercises WHERE user_id=$1', [alice.user.id])).rows[0].n, 4);
  assert.equal((await dailyGoals(pool, alice.user.id)).math, 0);
});

test('chain resumes at the unfinished step; concurrent answer retries count once and cannot skip steps', async () => {
  const session = await signIn();
  let chain;
  for (let i = 0; i < 8; i++) {
    const exercise = await mathExercise(session);
    if (exercise.problem.nextStep) { chain = exercise; break; }
    await solveMath(session, exercise);
  }
  assert.ok(chain);
  const before = (await dailyGoals(pool, session.user.id)).math;
  const firstAnswer = { id: randomUUID(), exerciseId: chain.exerciseId, step: 0, answer: chain.problem.answer };
  const replies = await Promise.all(Array.from({ length: 5 }, () => post('/api/math/answer', session, firstAnswer)));
  for (const reply of replies) assert.deepEqual(await reply.json(), { correct: true, completed: false, progress: { ...chain.progress, started: true } });
  const second = await mathExercise(session);
  assert.equal(second.exerciseId, chain.exerciseId);
  assert.equal(second.step, 1);
  assert.deepEqual(second.problem, chain.problem.nextStep);
  assert.equal((await dailyGoals(pool, session.user.id)).math, before);
  assert.equal((await post('/api/math/answer', session, { ...firstAnswer, id: randomUUID() })).status, 409);
  assert.equal((await post('/api/math/answer', session, { ...firstAnswer, answer: firstAnswer.answer + 1 })).status, 409);
  const lastAnswer = { id: randomUUID(), exerciseId: chain.exerciseId, step: 1, answer: second.problem.answer };
  assert.deepEqual(await (await post('/api/math/answer', session, lastAnswer)).json(), { correct: true, completed: true, progress: { ...chain.progress, completed: chain.progress.completed + 1, started: true } });
  const next = await mathExercise(session);
  assert.notEqual(next.exerciseId, chain.exerciseId);
  assert.deepEqual(await (await post('/api/math/answer', session, lastAnswer)).json(), { correct: true, completed: true, progress: { ...chain.progress, completed: chain.progress.completed + 1, started: true } });
  assert.deepEqual(await mathExercise(session), next);
  assert.equal((await dailyGoals(pool, session.user.id)).math, before + 1);
  assert.equal((await pool.query('SELECT count(*)::int n FROM attempts WHERE exercise_id=$1', [chain.exerciseId])).rows[0].n, 2);
});

test('assigned math checks answers on the server and rejects forged completion, other accounts and invalid requests', async () => {
  const session = await signIn(), bob = await signIn('bob');
  const exercise = await mathExercise(session, 3);
  const payload = { id: randomUUID(), exerciseId: exercise.exerciseId, step: 0, answer: exercise.problem.answer };
  assert.equal((await post('/api/math/answer', bob, payload)).status, 409);
  assert.equal((await post('/api/math/answer', session, payload, { 'X-CSRF-Token': '' })).status, 403);
  assert.equal((await post('/api/math/exercise', session, { grade: 3, subject: 'math' }, { Origin: 'https://evil.test' })).status, 403);
  assert.equal((await fetch(base + '/api/math/exercise', { method: 'POST' })).status, 401);
  for (const change of [{ answer: -1 }, { answer: 1.5 }, { step: -1 }, { step: 11 }, { id: 'invalid' }]) {
    assert.equal((await post('/api/math/answer', session, { ...payload, ...change })).status, 400);
  }
  assert.equal((await post('/api/math/exercise', session, { grade: 5, subject: 'english' })).status, 404);
  assert.equal((await post('/api/math/exercise', session, { grade: '3', subject: 'math' })).status, 400);
  assert.equal((await post('/api/attempts', session, attempt({ exerciseId: exercise.exerciseId, grade: 3, itemId: exercise.itemId }))).status, 409);
  const wrong = await post('/api/math/answer', session, { ...payload, answer: exercise.problem.answer + 1, correct: true, completed: true });
  const result = await wrong.json();
  assert.equal(result.correct, false);
  assert.equal(result.progress.total, 16);
  assert.notEqual((await mathExercise(session, 3)).exerciseId, exercise.exerciseId);
});

test('server math selection keeps a balanced mix and does not repeat items before exhausting a group', async () => {
  const session = await signIn();
  const seen = new Set();
  let lastGroup;
  for (let cycle = 0; cycle < 2; cycle++) {
    const groups = new Set();
    for (let index = 0; index < 8; index++) {
      let exercise = await mathExercise(session);
      assert.ok(!groups.has(exercise.problem.group));
      assert.notEqual(exercise.problem.group, lastGroup);
      lastGroup = exercise.problem.group;
      groups.add(lastGroup);
      assert.ok(!seen.has(exercise.itemId));
      seen.add(exercise.itemId);
      while (!(await solveMath(session, exercise)).completed) exercise = await mathExercise(session);
    }
  }
  assert.equal((await dailyGoals(pool, session.user.id)).math, 16);
});

test('editing or deactivating catalog content preserves the already assigned question', async () => {
  const session = await signIn();
  const exercise = await mathExercise(session, 3);
  const { rows: [original] } = await pool.query('SELECT * FROM practice_items WHERE id=$1', [exercise.itemId]);
  try {
    await pool.query("UPDATE practice_items SET active=false, data=jsonb_set(data, '{answer}', '999'::jsonb) WHERE id=$1", [exercise.itemId]);
    assert.deepEqual(await mathExercise(session, 3), exercise);
    assert.equal((await solveMath(session, exercise)).correct, true);
  } finally {
    await pool.query('UPDATE practice_items SET active=$2, data=$3 WHERE id=$1', [original.id, original.active, original.data]);
  }
});

async function spellingExercise(session) {
  const response = await post('/api/spelling/exercise', session, { grade: 7, subject: 'czech' });
  assert.equal(response.status, 200);
  return response.json();
}

test('Czech requires correct letter and reason, persists across tabs and login, and records one completion', async () => {
  const session = await signIn();
  const first = await spellingExercise(session);
  const tabs = await Promise.all(Array.from({ length: 5 }, () => spellingExercise(session)));
  for (const tab of tabs) assert.deepEqual(tab, first);
  const payload = { id: randomUUID(), exerciseId: first.exerciseId, step: 0, answer: first.problem.letter };
  assert.equal((await post('/api/spelling/answer', session, { ...payload, step: 1, answer: first.problem.reason })).status, 409);
  const responses = await Promise.all(Array.from({ length: 5 }, () => post('/api/spelling/answer', session, payload)));
  for (const response of responses) assert.deepEqual(await response.json(), { correct: true, completed: false, progress: { ...first.progress, started: true } });
  const again = await signIn();
  await migrate(pool);
  const second = await spellingExercise(again);
  assert.deepEqual(second, { ...first, step: 1, progress: { ...first.progress, started: true } });
  assert.equal((await post('/api/spelling/answer', again, { ...payload, id: randomUUID() })).status, 409);
  assert.equal((await post('/api/spelling/answer', again, { ...payload, answer: first.problem.letter === 'i' ? 'y' : 'i' })).status, 409);
  const last = { ...payload, id: randomUUID(), step: 1, answer: first.problem.reason };
  assert.deepEqual(await (await post('/api/spelling/answer', again, last)).json(), { correct: true, completed: true, progress: { ...first.progress, completed: 1, started: true } });
  const next = await spellingExercise(again);
  assert.notEqual(next.exerciseId, first.exerciseId);
  assert.notEqual(next.itemId, first.itemId);
  assert.deepEqual(await (await post('/api/spelling/answer', again, last)).json(), { correct: true, completed: true, progress: { ...first.progress, completed: 1, started: true } });
  assert.deepEqual(await spellingExercise(again), next);
  const day = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(new Date());
  const [row] = await stats(again, day, day);
  assert.equal(row.subject, 'czech'); assert.equal(row.grade, 7);
  assert.equal(row.practiced, 1); assert.equal(row.correct, 2); assert.equal(row.incorrect, 0); assert.equal(row.completed, 1);
  const goals = await dailyGoals(pool, session.user.id);
  assert.equal(goals.math, 0); assert.equal(goals.vocabulary, 0);
});

test('Czech rejects forged completion, another account, invalid steps and CSRF; assigned content survives edits', async () => {
  const alice = await signIn(), bob = await signIn('bob');
  const first = await spellingExercise(alice);
  const payload = { id: randomUUID(), exerciseId: first.exerciseId, step: 0, answer: first.problem.letter };
  assert.equal((await post('/api/spelling/answer', bob, payload)).status, 409);
  assert.equal((await post('/api/spelling/answer', alice, payload, { 'X-CSRF-Token': '' })).status, 403);
  assert.equal((await fetch(base + '/api/spelling/exercise', { method: 'POST' })).status, 401);
  assert.equal((await post('/api/spelling/exercise', alice, { grade: 3, subject: 'math' })).status, 404);
  assert.equal((await post('/api/spelling/exercise', alice, { grade: '7', subject: 'czech' })).status, 400);
  for (const change of [{ id: 'x' }, { step: 2 }, { step: '0' }, { answer: 1 }, { answer: 'a'.repeat(65) }]) {
    assert.equal((await post('/api/spelling/answer', alice, { ...payload, ...change })).status, 400);
  }
  assert.equal((await post('/api/attempts', alice, attempt({ subject: 'czech', grade: 7, exerciseId: first.exerciseId, itemId: first.itemId }))).status, 400);
  assert.equal((await post('/api/attempts', alice, attempt({ subject: 'czech', grade: 7 }))).status, 400);
  const { rows: [original] } = await pool.query('SELECT * FROM practice_items WHERE id=$1', [first.itemId]);
  try {
    await pool.query("UPDATE practice_items SET active=false, data=jsonb_set(data, '{letter}', '\"a\"'::jsonb) WHERE id=$1", [first.itemId]);
    assert.deepEqual(await spellingExercise(alice), first);
    assert.deepEqual(await (await post('/api/spelling/answer', alice, payload)).json(), { correct: true, completed: false, progress: { ...first.progress, started: true } });
  } finally {
    await pool.query('UPDATE practice_items SET active=$2,data=$3 WHERE id=$1', [original.id, original.active, original.data]);
  }
});

for (const [kind, grade, subject] of [['math', 3, 'math'], ['spelling', 7, 'czech'], ['vocabulary', 5, 'english']]) {
  test(`${kind}: each error adds one task, retries after three tasks, and cannot reset the round`, async () => {
    let session = await signIn();
    const start = async (newRound = false) => {
      const response = await post(`/api/${kind}/exercise`, session, { grade, subject, newRound });
      assert.equal(response.status, 200);
      return response.json();
    };
    const answer = async (task, wrong = false, id = randomUUID()) => {
      const value = kind === 'math' ? task.problem.answer + Number(wrong) : kind === 'spelling'
        ? wrong ? (task.step ? task.problem.reasons.find(r => r.id !== task.problem.reason).id : task.problem.letter === 'i' ? 'y' : 'i')
          : task.problem[task.step ? 'reason' : 'letter']
        : wrong ? '' : task.problem.english.toUpperCase().replace(/-/g, ' ').replace(/'/g, '’') + '!';
      const response = await post(`/api/${kind}/answer`, session, {
        id, exerciseId: task.exerciseId, step: task.step, revision: task.revision, answer: value,
      });
      assert.equal(response.status, 200);
      return response.json();
    };
    const solve = async () => {
      let task = await start();
      while (!(await answer(task)).completed) task = await start();
    };
    let first = await start();
    assert.equal(first.progress.total, 15);
    if (kind === 'spelling') { await answer(first); first = await start(); }
    const wrongId = randomUUID();
    const retries = await Promise.all(Array.from({ length: 5 }, () => answer(first, true, wrongId)));
    for (const result of retries) {
      assert.equal(result.correct, false);
      assert.equal(result.progress.mistakes, 1);
      assert.equal(result.progress.total, 16);
    }
    const next = await start();
    assert.notEqual(next.exerciseId, first.exerciseId);
    await migrate(pool);
    session = await signIn();
    assert.deepEqual(await start(true), next);
    for (let i = 0; i < 3; i++) {
      const task = await start();
      assert.notEqual(task.itemId, first.itemId);
      await solve();
    }
    const repeated = await start();
    assert.equal(repeated.exerciseId, first.exerciseId);
    assert.equal(repeated.itemId, first.itemId);
    assert.equal(repeated.revision, 1);
    assert.equal(repeated.step, 0);
    const stale = await post(`/api/${kind}/answer`, session, {
      id: randomUUID(), exerciseId: first.exerciseId, step: 0, revision: 0,
      answer: kind === 'math' ? first.problem.answer : kind === 'spelling' ? first.problem.letter : first.problem.english,
    });
    assert.equal(stale.status, 409);
    const twice = await answer(repeated, true);
    assert.equal(twice.progress.total, 17);
    assert.equal(twice.progress.mistakes, 2);
    for (let i = 0; i < 3; i++) await solve();
    assert.equal((await start()).exerciseId, first.exerciseId);
    await solve();
    while ((await start()).progress.completed < 16) await solve();
    const last = await start();
    const lastError = await answer(last, true);
    assert.equal(lastError.progress.total, 18);
    assert.equal(lastError.progress.mistakes, 3);
    assert.equal(lastError.progress.finished, false);
    assert.notEqual((await start()).exerciseId, last.exerciseId);
    await solve();
    assert.equal((await start()).exerciseId, last.exerciseId);
    await solve();
    const finished = await start();
    assert.deepEqual(finished.progress, { total: 18, completed: 18, mistakes: 3, finished: true, started: true });
    assert.equal((await answer(first, true, wrongId)).progress.total, 16);
    assert.deepEqual(await start(), finished);
    const day = new Intl.DateTimeFormat('sv-SE', { timeZone: 'Europe/Prague' }).format(new Date());
    const [row] = await stats(session, day, day);
    assert.equal(row.incorrect, 3);
    assert.equal(row.completed, 18);
    const goals = await dailyGoals(pool, session.user.id);
    assert.equal(goals.math, kind === 'math' ? 18 : 0);
    assert.equal(goals.vocabulary, kind === 'vocabulary' ? 18 : 0);
    const fresh = await start(true);
    assert.equal(fresh.progress.total, 15);
    assert.equal(fresh.progress.mistakes, 0);
  });
}

test('vocabulary assignment skips words learned today and resumes server-owned work', async () => {
  const session = await signIn();
  const { rows: learned } = await pool.query("SELECT id FROM practice_items WHERE grade=5 AND subject='english' AND active ORDER BY id LIMIT 10");
  for (const item of learned) {
    assert.equal((await post('/api/attempts', session, attempt({ grade: 5, subject: 'english', itemId: item.id,
      occurredAt: new Date().toISOString() }))).status, 201);
  }
  const response = await post('/api/vocabulary/exercise', session, { grade: 5, subject: 'english' });
  assert.equal(response.status, 200);
  const exercise = await response.json();
  assert.equal(exercise.cards.length, 15);
  assert.ok(exercise.cards.every(card => !learned.some(item => item.id === card.id)));
  assert.equal(new Set(exercise.cards.map(card => card.id)).size, 15);
  assert.equal((await post('/api/attempts', session, attempt({ exerciseId: exercise.exerciseId,
    grade: 5, subject: 'english', itemId: exercise.itemId }))).status, 409);
});

test('pre-round unfinished chain keeps its snapshot and current step during migration', async () => {
  const session = await signIn();
  const { rows: [item] } = await pool.query("SELECT id,data FROM practice_items WHERE grade=5 AND subject='math' AND data ? 'nextStep' LIMIT 1");
  const id = randomUUID();
  await pool.query(`INSERT INTO exercises(user_id,id,grade,subject,practice_item_id,math_problem,math_step)
    VALUES ($1,$2,5,'math',$3,$4,1)`, [session.user.id, id, item.id, item.data]);
  await migrate(pool);
  const task = await mathExercise(session);
  assert.equal(task.exerciseId, id);
  assert.equal(task.step, 1);
  assert.deepEqual(task.problem, item.data.nextStep);
  assert.equal(task.progress.total, 15);
  assert.equal((await solveMath(session, task)).completed, true);
});
