import { readFile } from 'node:fs/promises';
import { randomUUID, createHash, randomBytes } from 'node:crypto';
import { importContent } from './catalog.js';

export const secretToken = () => randomBytes(32).toString('hex');
export const hashToken = token => createHash('sha256').update(token).digest('hex');

export async function migrate(pool) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(84731201)');
    await client.query(await readFile(new URL('./schema.sql', import.meta.url), 'utf8'));
    await client.query('CREATE TABLE IF NOT EXISTS content_migrations (version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now())');
    if (!(await client.query("SELECT 1 FROM content_migrations WHERE version='catalog-v1'")).rowCount) {
      await client.query(await readFile(new URL('./catalog.sql', import.meta.url), 'utf8'));
      await importContent(client, JSON.parse(await readFile(new URL('./content-seed.json', import.meta.url), 'utf8')));
      await client.query(`ALTER TABLE exercises DROP CONSTRAINT IF EXISTS exercises_subject_check;
        ALTER TABLE exercises DROP CONSTRAINT IF EXISTS exercises_check;
        ALTER TABLE exercises ADD CONSTRAINT exercises_course_fk FOREIGN KEY (grade,subject) REFERENCES school_courses(grade,subject);
        INSERT INTO content_migrations(version) VALUES ('catalog-v1')`);
    }
    await client.query('ALTER TABLE exercises ADD COLUMN IF NOT EXISTS practice_item_id text');
    await client.query(`ALTER TABLE exercises ADD COLUMN IF NOT EXISTS math_problem jsonb;
      ALTER TABLE exercises ADD COLUMN IF NOT EXISTS math_step integer NOT NULL DEFAULT 0;
      ALTER TABLE attempts ADD COLUMN IF NOT EXISTS math_answer integer;
      ALTER TABLE attempts ADD COLUMN IF NOT EXISTS math_step integer`);
    await client.query('COMMIT');
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}

export async function login(pool, identity, previousToken) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    const { rows: [user] } = await client.query(`
      INSERT INTO users(id, google_sub, name, email) VALUES ($1, $2, $3, $4)
      ON CONFLICT (google_sub) DO UPDATE SET name = EXCLUDED.name, email = EXCLUDED.email
      RETURNING id, name, email`, [randomUUID(), identity.sub, identity.name, identity.email]);
    if (previousToken) await client.query('DELETE FROM sessions WHERE token_hash = $1', [hashToken(previousToken)]);
    await client.query('DELETE FROM sessions WHERE expires_at < now()');
    const token = secretToken(), csrf = secretToken();
    await client.query(`INSERT INTO sessions VALUES ($1, $2, $3, now() + interval '30 days')`,
      [hashToken(token), user.id, csrf]);
    await client.query('COMMIT');
    return { user, token, csrf };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}

export async function saveAttempt(pool, userId, attempt) {
  const { id, exerciseId, subject, grade, correct, completed, occurredAt, itemId = null } = attempt;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`INSERT INTO exercises(user_id, id, subject, grade, practice_item_id) VALUES ($1, $2, $3, $4, $5)
      ON CONFLICT DO NOTHING`, [userId, exerciseId, subject, grade, itemId]);
    const { rows: [exercise] } = await client.query(
      'SELECT * FROM exercises WHERE user_id = $1 AND id = $2 FOR UPDATE', [userId, exerciseId]);
    const { rows: [existing] } = await client.query(
      'SELECT * FROM attempts WHERE user_id = $1 AND id = $2', [userId, id]);
    if (exercise.math_problem || exercise.subject !== subject || exercise.grade !== grade || exercise.practice_item_id !== itemId ||
        (existing && (existing.exercise_id !== exerciseId || existing.correct !== correct || existing.completed !== completed ||
          existing.answered_at.getTime() !== Date.parse(occurredAt))) ||
        (!existing && exercise.completed)) {
      await client.query('ROLLBACK');
      return 'conflict';
    }
    if (!existing) {
      await client.query(`INSERT INTO attempts(user_id, id, exercise_id, correct, completed, answered_at)
        VALUES ($1, $2, $3, $4, $5, $6)`, [userId, id, exerciseId, correct, completed, new Date(occurredAt)]);
      if (completed) await client.query('UPDATE exercises SET completed = true WHERE user_id = $1 AND id = $2', [userId, exerciseId]);
    }
    await client.query('COMMIT');
    return existing ? 'duplicate' : 'created';
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}

export async function dailyGoals(pool, userId, now = new Date()) {
  const { rows: [result] } = await pool.query(`
    WITH day AS (SELECT ($2::timestamptz AT TIME ZONE 'Europe/Prague')::date AS date),
    completed AS (
      SELECT e.id, e.practice_item_id, s.kind
      FROM attempts a JOIN exercises e ON e.user_id=a.user_id AND e.id=a.exercise_id
      JOIN school_subjects s ON s.id=e.subject CROSS JOIN day
      WHERE a.user_id=$1 AND a.completed
        AND a.answered_at >= day.date::timestamp AT TIME ZONE 'Europe/Prague'
        AND a.answered_at < (day.date + 1)::timestamp AT TIME ZONE 'Europe/Prague'
    )
    SELECT to_char(day.date, 'YYYY-MM-DD') AS day,
      (day.date + 1)::timestamp AT TIME ZONE 'Europe/Prague' AS "resetsAt",
      (SELECT count(*)::int FROM completed WHERE kind='math') AS math,
      (SELECT count(DISTINCT coalesce(practice_item_id, id::text))::int FROM completed WHERE kind='vocabulary') AS vocabulary,
      ARRAY(SELECT DISTINCT practice_item_id FROM completed WHERE kind='vocabulary' AND practice_item_id IS NOT NULL) AS "wordIds"
    FROM day`, [userId, now]);
  return { ...result, target: 15 };
}

export async function dailyStats(pool, userId, from, to) {
  const { rows } = await pool.query(`
    SELECT to_char(a.answered_at AT TIME ZONE 'Europe/Prague', 'YYYY-MM-DD') AS day,
      e.subject, e.grade, s.name AS "subjectName", s.kind AS "subjectKind", g.name AS "gradeName", count(DISTINCT a.exercise_id)::int AS practiced,
      count(*) FILTER (WHERE a.correct)::int AS correct,
      count(*) FILTER (WHERE NOT a.correct)::int AS incorrect,
      count(*) FILTER (WHERE a.completed)::int AS completed
    FROM attempts a JOIN exercises e ON e.user_id = a.user_id AND e.id = a.exercise_id
    JOIN school_subjects s ON s.id=e.subject JOIN school_grades g ON g.id=e.grade
    WHERE a.user_id = $1
      AND a.answered_at >= $2::date::timestamp AT TIME ZONE 'Europe/Prague'
      AND a.answered_at < ($3::date + 1)::timestamp AT TIME ZONE 'Europe/Prague'
    GROUP BY day, e.subject, e.grade, s.id, g.id ORDER BY day DESC, e.subject, e.grade`, [userId, from, to]);
  return rows;
}
