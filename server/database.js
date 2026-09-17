import { readFile } from 'node:fs/promises';
import { randomUUID, createHash, randomBytes } from 'node:crypto';

export const secretToken = () => randomBytes(32).toString('hex');
export const hashToken = token => createHash('sha256').update(token).digest('hex');

export async function migrate(pool) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT pg_advisory_xact_lock(84731201)');
    await client.query(await readFile(new URL('./schema.sql', import.meta.url), 'utf8'));
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
  const { id, exerciseId, subject, grade, correct, completed, occurredAt } = attempt;
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query(`INSERT INTO exercises(user_id, id, subject, grade) VALUES ($1, $2, $3, $4)
      ON CONFLICT DO NOTHING`, [userId, exerciseId, subject, grade]);
    const { rows: [exercise] } = await client.query(
      'SELECT * FROM exercises WHERE user_id = $1 AND id = $2 FOR UPDATE', [userId, exerciseId]);
    const { rows: [existing] } = await client.query(
      'SELECT * FROM attempts WHERE user_id = $1 AND id = $2', [userId, id]);
    if (exercise.subject !== subject || exercise.grade !== grade ||
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

export async function dailyStats(pool, userId, from, to) {
  const { rows } = await pool.query(`
    SELECT to_char(a.answered_at AT TIME ZONE 'Europe/Prague', 'YYYY-MM-DD') AS day,
      e.subject, e.grade, count(DISTINCT a.exercise_id)::int AS practiced,
      count(*) FILTER (WHERE a.correct)::int AS correct,
      count(*) FILTER (WHERE NOT a.correct)::int AS incorrect,
      count(*) FILTER (WHERE a.completed)::int AS completed
    FROM attempts a JOIN exercises e ON e.user_id = a.user_id AND e.id = a.exercise_id
    WHERE a.user_id = $1
      AND a.answered_at >= $2::date::timestamp AT TIME ZONE 'Europe/Prague'
      AND a.answered_at < ($3::date + 1)::timestamp AT TIME ZONE 'Europe/Prague'
    GROUP BY day, e.subject, e.grade ORDER BY day DESC, e.subject, e.grade`, [userId, from, to]);
  return rows;
}
