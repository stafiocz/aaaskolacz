import { randomUUID } from 'node:crypto';

function stepAt(exercise, step = exercise.math_step) {
  let problem = exercise.math_problem;
  for (let index = 0; index < step && problem; index++) problem = problem.nextStep;
  return problem;
}

function assignment(exercise) {
  return { exerciseId: exercise.id, itemId: exercise.practice_item_id,
    step: exercise.math_step, problem: stepAt(exercise) };
}

export async function startMath(pool, userId, grade, subject) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    // Serializes assignment and answer requests from multiple tabs for this account.
    await client.query('SELECT id FROM users WHERE id=$1 FOR UPDATE', [userId]);
    const { rows: [pending] } = await client.query(`SELECT * FROM exercises
      WHERE user_id=$1 AND grade=$2 AND subject=$3 AND math_problem IS NOT NULL AND NOT completed`, [userId, grade, subject]);
    if (pending) {
      await client.query('COMMIT');
      return assignment(pending);
    }
    const { rows: [item] } = await client.query(`
      WITH items AS (
        SELECT p.id, p.data, p.data->>'group' AS category,
          (SELECT count(*) FROM exercises e WHERE e.user_id=$1 AND e.practice_item_id=p.id) AS used
        FROM practice_items p
        JOIN school_courses c ON c.grade=p.grade AND c.subject=p.subject
        JOIN school_subjects s ON s.id=c.subject JOIN school_grades g ON g.id=c.grade
        WHERE p.grade=$2 AND p.subject=$3 AND p.active AND c.active AND s.active AND g.active AND s.kind='math'
      ), categories AS (
        SELECT DISTINCT category,
          (SELECT count(*) FROM exercises e WHERE e.user_id=$1 AND e.grade=$2 AND e.subject=$3
            AND e.math_problem->>'group'=items.category) AS used
        FROM items
      ), last_category AS (
        SELECT e.math_problem->>'group' AS category FROM exercises e
        JOIN attempts a ON a.user_id=e.user_id AND a.exercise_id=e.id
        WHERE e.user_id=$1 AND e.grade=$2 AND e.subject=$3 AND e.math_problem IS NOT NULL
        ORDER BY a.answered_at DESC LIMIT 1
      ), chosen AS (
        SELECT category FROM categories ORDER BY used,
          (category IS NOT DISTINCT FROM (SELECT category FROM last_category)), random() LIMIT 1
      )
      SELECT id, data FROM items WHERE category=(SELECT category FROM chosen) ORDER BY used, random() LIMIT 1`, [userId, grade, subject]);
    if (!item) {
      await client.query('ROLLBACK');
      return null;
    }
    const { rows: [exercise] } = await client.query(`
      INSERT INTO exercises(user_id,id,grade,subject,practice_item_id,math_problem)
      VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`, [userId, randomUUID(), grade, subject, item.id, item.data]);
    await client.query('COMMIT');
    return assignment(exercise);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}

export async function answerMath(pool, userId, body) {
  const client = await pool.connect();
  const { id, exerciseId, step, answer } = body;
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM users WHERE id=$1 FOR UPDATE', [userId]);
    const { rows: [exercise] } = await client.query(
      'SELECT * FROM exercises WHERE user_id=$1 AND id=$2', [userId, exerciseId]);
    const { rows: [existing] } = await client.query(
      'SELECT * FROM attempts WHERE user_id=$1 AND id=$2', [userId, id]);
    if (!exercise?.math_problem ||
        (existing && (existing.exercise_id !== exerciseId || existing.math_step !== step || existing.math_answer !== answer)) ||
        (!existing && (exercise.completed || exercise.math_step !== step))) {
      await client.query('ROLLBACK');
      return null;
    }
    const problem = stepAt(exercise, step);
    const correct = answer === problem.answer;
    const completed = correct && !problem.nextStep;
    if (!existing) {
      await client.query(`INSERT INTO attempts(user_id,id,exercise_id,correct,completed,math_answer,math_step)
        VALUES ($1,$2,$3,$4,$5,$6,$7)`, [userId, id, exerciseId, correct, completed, answer, step]);
      if (correct) await client.query(`UPDATE exercises SET completed=$3, math_step=$4 WHERE user_id=$1 AND id=$2`,
        [userId, exerciseId, completed, completed ? step : step + 1]);
    }
    await client.query('COMMIT');
    return { correct, completed };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}
