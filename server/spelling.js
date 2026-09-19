import { randomUUID, randomInt } from 'node:crypto';

function assignment(exercise) {
  return { exerciseId: exercise.id, itemId: exercise.practice_item_id,
    step: exercise.spelling_step, problem: exercise.spelling_problem };
}

export async function startSpelling(pool, userId, grade, subject) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM users WHERE id=$1 FOR UPDATE', [userId]);
    const { rows: [pending] } = await client.query(`SELECT * FROM exercises
      WHERE user_id=$1 AND grade=$2 AND subject=$3 AND spelling_problem IS NOT NULL AND NOT completed`, [userId, grade, subject]);
    if (pending) {
      await client.query('COMMIT');
      return assignment(pending);
    }
    const { rows: [item] } = await client.query(`SELECT p.id,p.data FROM practice_items p
      JOIN school_courses c ON c.grade=p.grade AND c.subject=p.subject
      JOIN school_subjects s ON s.id=c.subject JOIN school_grades g ON g.id=c.grade
      WHERE p.grade=$2 AND p.subject=$3 AND p.active AND c.active AND s.active AND g.active AND s.kind='spelling'
      ORDER BY (SELECT count(*) FROM exercises e WHERE e.user_id=$1 AND e.practice_item_id=p.id), random() LIMIT 1`,
    [userId, grade, subject]);
    if (!item) {
      await client.query('ROLLBACK');
      return null;
    }
    for (let i = item.data.reasons.length - 1; i > 0; i--) {
      const j = randomInt(i + 1);
      [item.data.reasons[i], item.data.reasons[j]] = [item.data.reasons[j], item.data.reasons[i]];
    }
    const { rows: [exercise] } = await client.query(`
      INSERT INTO exercises(user_id,id,grade,subject,practice_item_id,spelling_problem)
      VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`, [userId, randomUUID(), grade, subject, item.id, item.data]);
    await client.query('COMMIT');
    return assignment(exercise);
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}

export async function answerSpelling(pool, userId, { id, exerciseId, step, answer }) {
  const client = await pool.connect();
  try {
    await client.query('BEGIN');
    await client.query('SELECT id FROM users WHERE id=$1 FOR UPDATE', [userId]);
    const { rows: [exercise] } = await client.query('SELECT * FROM exercises WHERE user_id=$1 AND id=$2', [userId, exerciseId]);
    const { rows: [existing] } = await client.query('SELECT * FROM attempts WHERE user_id=$1 AND id=$2', [userId, id]);
    const problem = exercise?.spelling_problem;
    if (!problem ||
        (existing && (existing.exercise_id !== exerciseId || existing.spelling_step !== step || existing.spelling_answer !== answer)) ||
        (!existing && (exercise.completed || exercise.spelling_step !== step)) ||
        !(step === 0 ? ['i', 'í', 'y', 'ý', 'a'].includes(answer) : problem.reasons.some(r => r.id === answer))) {
      await client.query('ROLLBACK');
      return null;
    }
    const correct = answer === (step === 0 ? problem.letter : problem.reason);
    const completed = correct && step === 1;
    if (!existing) {
      await client.query(`INSERT INTO attempts(user_id,id,exercise_id,correct,completed,spelling_answer,spelling_step)
        VALUES ($1,$2,$3,$4,$5,$6,$7)`, [userId, id, exerciseId, correct, completed, answer, step]);
      if (correct) await client.query(`UPDATE exercises SET completed=$3, spelling_step=1 WHERE user_id=$1 AND id=$2`,
        [userId, exerciseId, completed]);
    }
    await client.query('COMMIT');
    return { correct, completed };
  } catch (error) {
    await client.query('ROLLBACK');
    throw error;
  } finally { client.release(); }
}
