import { randomUUID, randomInt } from 'node:crypto';

function shuffle(items) {
  for (let i = items.length - 1; i > 0; i--) {
    const j = randomInt(i + 1);
    [items[i], items[j]] = [items[j], items[i]];
  }
  return items;
}

async function itemPicker(client, userId, grade, subject, kind, state) {
  const { rows: items } = await client.query(`SELECT p.id,p.data,
    (SELECT count(*)::int FROM exercises e WHERE e.user_id=$1 AND e.practice_item_id=p.id) AS used,
    EXISTS(SELECT 1 FROM exercises e JOIN attempts a ON a.user_id=e.user_id AND a.exercise_id=e.id
      WHERE e.user_id=$1 AND e.practice_item_id=p.id AND a.completed
        AND (a.answered_at AT TIME ZONE 'Europe/Prague')::date=(now() AT TIME ZONE 'Europe/Prague')::date) AS learned
    FROM practice_items p JOIN school_courses c ON c.grade=p.grade AND c.subject=p.subject
    JOIN school_subjects s ON s.id=c.subject JOIN school_grades g ON g.id=c.grade
    WHERE p.grade=$2 AND p.subject=$3 AND p.active AND c.active AND s.active AND g.active AND s.kind=$4`,
  [userId, grade, subject, kind]);
  if (!items.length) return null;
  const used = new Set(state?.used ?? []);
  const counts = {};
  for (const item of items) counts[item.data.group] = (counts[item.data.group] ?? 0) + item.used;
  for (const entry of state?.queue ?? []) {
    const item = items.find(item => item.id === entry.itemId);
    if (item) { item.used++; counts[item.data.group]++; }
  }
  const { rows: [last] } = kind === 'math' ? await client.query(`SELECT e.math_problem->>'group' AS category
    FROM exercises e JOIN attempts a ON a.user_id=e.user_id AND a.exercise_id=e.id
    WHERE e.user_id=$1 AND e.grade=$2 AND e.subject=$3 ORDER BY a.answered_at DESC LIMIT 1`, [userId, grade, subject]) : { rows: [] };
  let lastGroup = last?.category;
  const pick = () => {
    let options = items.filter(item => !used.has(item.id));
    if (!options.length) { used.clear(); options = [...items]; }
    if (kind === 'vocabulary' && options.some(item => !item.learned)) options = options.filter(item => !item.learned);
    shuffle(options);
    if (kind === 'math') {
      options.sort((a, b) => counts[a.data.group] - counts[b.data.group] ||
        Number(a.data.group === lastGroup) - Number(b.data.group === lastGroup) || a.used - b.used);
    } else options.sort((a, b) => a.used - b.used);
    const item = options[0];
    used.add(item.id);
    item.used++;
    counts[item.data.group]++;
    lastGroup = item.data.group;
    const problem = structuredClone(item.data);
    if (kind === 'spelling') shuffle(problem.reasons);
    return { exerciseId: randomUUID(), itemId: item.id, step: 0, revision: 0, problem };
  };
  pick.count = Math.min(15, items.length);
  return pick;
}

function problemAt(entry, kind) {
  let problem = entry.problem;
  if (kind === 'math') for (let i = 0; i < entry.step; i++) problem = problem.nextStep;
  return problem;
}

function progress(state) {
  return { total: state.total, completed: state.completed, mistakes: state.mistakes,
    finished: state.queue.length === 0, started: state.started };
}

function assignment(state, kind) {
  const entry = state.queue[0];
  return { ...(entry ? { ...entry, problem: problemAt(entry, kind) } : {}), progress: progress(state),
    ...(kind === 'vocabulary' ? { cards: state.queue.map(e => ({ id: e.itemId, data: e.problem })) } : {}) };
}

async function save(client, userId, grade, subject, state) {
  await client.query(`INSERT INTO practice_tests(user_id,grade,subject,state) VALUES ($1,$2,$3,$4)
    ON CONFLICT(user_id,grade,subject) DO UPDATE SET state=excluded.state`, [userId, grade, subject, state]);
}

async function activate(client, userId, grade, subject, kind, state) {
  const entry = state.queue[0];
  if (!entry) return;
  await client.query(`INSERT INTO exercises(user_id,id,grade,subject,practice_item_id,test_id,math_problem,spelling_problem)
    VALUES ($1,$2,$3,$4,$5,$6,$7,$8) ON CONFLICT(user_id,id) DO UPDATE SET test_id=excluded.test_id`,
  [userId, entry.exerciseId, grade, subject, entry.itemId, state.id,
    kind === 'math' ? entry.problem : null, kind === 'spelling' ? entry.problem : null]);
}

export async function startPractice(pool, userId, grade, subject, kind, newRound = false) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM users WHERE id=$1 FOR UPDATE', [userId]);
    const { rows: [saved] } = await client.query('SELECT state FROM practice_tests WHERE user_id=$1 AND grade=$2 AND subject=$3', [userId, grade, subject]);
    let state = saved?.state;
    if (state && state.kind !== kind) { await client.query('ROLLBACK'); return null; }
    if (!state || (newRound && !state.queue.length)) {
      const pick = await itemPicker(client, userId, grade, subject, kind);
      if (!pick) { await client.query('ROLLBACK'); return null; }
      const { rows: [legacy] } = await client.query(`SELECT * FROM exercises WHERE user_id=$1 AND grade=$2 AND subject=$3
        AND NOT completed AND test_id IS NULL AND (math_problem IS NOT NULL OR spelling_problem IS NOT NULL) LIMIT 1`, [userId, grade, subject]);
      const queue = [];
      if (legacy) queue.push({ exerciseId: legacy.id, itemId: legacy.practice_item_id,
        step: kind === 'math' ? legacy.math_step : legacy.spelling_step, revision: 0,
        problem: kind === 'math' ? legacy.math_problem : legacy.spelling_problem });
      const total = kind === 'vocabulary' ? pick.count : 15;
      while (queue.length < total) queue.push(pick());
      state = { id: randomUUID(), kind, queue, used: queue.map(e => e.itemId), total, completed: 0, mistakes: 0, started: Boolean(legacy) };
      await save(client, userId, grade, subject, state);
    }
    await activate(client, userId, grade, subject, kind, state);
    await client.query('COMMIT');
    return assignment(state, kind);
  } catch (error) {
    await client.query('ROLLBACK'); throw error;
  } finally { client.release(); }
}

const normalize = answer => answer.trim().toLowerCase().replace(/[’‘]/g, "'").replace(/[.!?,]+$/g, '')
  .replace(/[-–]/g, ' ').replace(/\s+/g, ' ').trim();

export async function answerPractice(pool, userId, kind, { id, exerciseId, step, answer, revision = 0 }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM users WHERE id=$1 FOR UPDATE', [userId]);
    const { rows: [exercise] } = await client.query('SELECT * FROM exercises WHERE user_id=$1 AND id=$2', [userId, exerciseId]);
    const { rows: [existing] } = await client.query('SELECT * FROM attempts WHERE user_id=$1 AND id=$2', [userId, id]);
    const { rows: [saved] } = exercise ? await client.query('SELECT state FROM practice_tests WHERE user_id=$1 AND grade=$2 AND subject=$3',
      [userId, exercise.grade, exercise.subject]) : { rows: [] };
    if (existing) {
      const matches = saved?.state.kind === kind && existing.exercise_id === exerciseId && existing.test_revision === revision &&
        existing.test_answer?.step === step && existing.test_answer?.answer === answer;
      await client.query('ROLLBACK');
      return matches ? existing.test_result : null;
    }
    const state = saved?.state, entry = state?.queue[0];
    if (!entry || state.kind !== kind || entry.exerciseId !== exerciseId || entry.step !== step || entry.revision !== revision) {
      await client.query('ROLLBACK'); return null;
    }
    const problem = problemAt(entry, kind);
    if (kind === 'spelling' && !(step === 0 ? ['i', 'í', 'y', 'ý', 'a'].includes(answer) : problem.reasons.some(r => r.id === answer))) {
      await client.query('ROLLBACK'); return null;
    }
    const correct = kind === 'math' ? answer === problem.answer : kind === 'spelling'
      ? answer === problem[step === 0 ? 'letter' : 'reason']
      : [problem.english, ...(problem.alternatives ?? [])].some(value => normalize(value) === normalize(answer));
    const completed = correct && (kind === 'math' ? !problem.nextStep : kind === 'spelling' ? step === 1 : true);
    state.started = true;
    if (!correct) {
      const pick = await itemPicker(client, userId, exercise.grade, exercise.subject, kind, state);
      // A stored snapshot keeps an unfinished test usable even if its course was retired.
      const extra = pick ? pick() : { ...structuredClone(entry), exerciseId: randomUUID(), step: 0, revision: 0 };
      state.queue.shift();
      state.queue.push(extra);
      state.used.push(extra.itemId);
      entry.step = 0;
      entry.revision++;
      state.queue.splice(Math.min(3, state.queue.length), 0, entry);
      state.mistakes++;
      state.total++;
    } else if (completed) {
      state.queue.shift();
      state.completed++;
    } else entry.step++;
    const result = { correct, completed, progress: progress(state) };
    await client.query(`INSERT INTO attempts(user_id,id,exercise_id,correct,completed,test_revision,test_answer,test_result)
      VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`, [userId, id, exerciseId, correct, completed, revision, { step, answer }, result]);
    await client.query('UPDATE exercises SET completed=$3 WHERE user_id=$1 AND id=$2', [userId, exerciseId, completed]);
    await save(client, userId, exercise.grade, exercise.subject, state);
    await client.query('COMMIT');
    return result;
  } catch (error) {
    await client.query('ROLLBACK'); throw error;
  } finally { client.release(); }
}
