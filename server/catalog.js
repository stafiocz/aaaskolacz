const identifier = /^[a-z][a-z0-9_-]{0,63}$/;
const text = (value, limit = 500) => typeof value === 'string' && value.trim().length > 0 && value.length <= limit;
const integer = (value, min, max) => Number.isInteger(value) && value >= min && value <= max;
const assert = (condition, message) => { if (!condition) throw new Error(message); };
const record = value => {
  assert(value && typeof value === 'object' && !Array.isArray(value), 'Položka musí být objekt.');
  assert(value.active == null || typeof value.active === 'boolean', 'active musí být boolean.');
  assert(value.sortOrder == null || integer(value.sortOrder, -100000, 100000), 'Neplatné pořadí.');
};

export function validateItem(data, kind, maxDigits, depth = 0) {
  assert(data && typeof data === 'object' && !Array.isArray(data), 'Zadání musí být objekt.');
  if (kind === 'math') {
    assert(depth < 10 && text(data.group, 100) && text(data.heading, 100), 'Chybí skupina nebo nadpis příkladu.');
    assert(typeof data.beforeAnswer === 'string' && data.beforeAnswer.length <= 200 &&
      typeof data.afterAnswer === 'string' && data.afterAnswer.length <= 200 &&
      (data.beforeAnswer + data.afterAnswer).trim().length > 0, 'Neplatné zadání příkladu.');
    assert(integer(data.answer, 0, 10 ** maxDigits - 1), 'Výsledek se nevejde do klávesnice.');
    for (const field of ['instruction', 'verification']) {
      assert(data[field] == null || text(data[field]), `Neplatné pole ${field}.`);
    }
    if (data.nextStep != null) validateItem(data.nextStep, kind, maxDigits, depth + 1);
  } else if (kind === 'spelling') {
    assert(text(data.sentence) && data.sentence.split('_').length === 2, 'Věta musí obsahovat právě jednu mezeru označenou _.');
    assert(['i', 'í', 'y', 'ý', 'a'].includes(data.letter), 'Neplatné písmeno.');
    assert(text(data.explanation, 1000) && Array.isArray(data.reasons) && data.reasons.length >= 3 && data.reasons.length <= 6,
      'Chybí vysvětlení nebo možnosti zdůvodnění.');
    const ids = new Set();
    for (const reason of data.reasons) {
      assert(reason && identifier.test(reason.id) && text(reason.text) && !ids.has(reason.id), 'Neplatné nebo duplicitní zdůvodnění.');
      ids.add(reason.id);
    }
    assert(ids.has(data.reason), 'Správné zdůvodnění není mezi možnostmi.');
  } else {
    assert(kind === 'vocabulary' && text(data.english) && text(data.czech) && text(data.topic, 100), 'Chybí slovíčko, překlad nebo téma.');
    assert(integer(data.page, 0, 9999) && Array.isArray(data.alternatives) &&
      data.alternatives.length <= 30 && data.alternatives.every(a => text(a)), 'Neplatná stránka nebo alternativní odpovědi.');
    assert(data.exerciseType == null || ['vocabulary', 'grammar'].includes(data.exerciseType), 'Neplatný typ jazykové úlohy.');
    assert(data.caseSensitive == null || typeof data.caseSensitive === 'boolean', 'caseSensitive musí být boolean.');
    for (const field of ['instruction', 'explanation']) {
      assert(data[field] == null || text(data[field], 1000), `Neplatné pole ${field}.`);
    }
    assert(data.exerciseType !== 'grammar' || (text(data.instruction, 1000) && text(data.explanation, 1000)),
      'Gramatická úloha vyžaduje pokyn a vysvětlení.');
  }
}

export async function importContent(client, content) {
  record(content);
  for (const field of ['grades', 'subjects', 'courses']) {
    assert(Array.isArray(content[field] ?? []), `Pole ${field} musí být seznam.`);
  }
  for (const grade of content.grades ?? []) {
    record(grade);
    assert(integer(grade.id, 1, 99) && text(grade.name, 100), 'Neplatná třída.');
    await client.query(`INSERT INTO school_grades(id, name, sort_order, active) VALUES ($1,$2,$3,$4)
      ON CONFLICT (id) DO UPDATE SET name=EXCLUDED.name, sort_order=EXCLUDED.sort_order, active=EXCLUDED.active`,
    [grade.id, grade.name, grade.sortOrder ?? 0, grade.active ?? true]);
  }
  for (const subject of content.subjects ?? []) {
    record(subject);
    assert(text(subject.id) && identifier.test(subject.id) && text(subject.slug) && /^[a-z][a-z0-9-]{0,63}$/.test(subject.slug) && text(subject.name, 100) &&
      ['math', 'vocabulary', 'spelling'].includes(subject.kind), 'Neplatný předmět.');
    assert(subject.kind !== 'vocabulary' || text(subject.answerLanguage, 100), 'Chybí jazyk odpovědi.');
    const previous = (await client.query('SELECT kind FROM school_subjects WHERE id=$1', [subject.id])).rows[0];
    assert(!previous || previous.kind === subject.kind, 'Typ existujícího předmětu nelze změnit.');
    await client.query(`INSERT INTO school_subjects(id,slug,name,kind,answer_language,active) VALUES ($1,$2,$3,$4,$5,$6)
      ON CONFLICT (id) DO UPDATE SET slug=EXCLUDED.slug, name=EXCLUDED.name,
      answer_language=EXCLUDED.answer_language, active=EXCLUDED.active`,
    [subject.id, subject.slug, subject.name, subject.kind, subject.answerLanguage ?? '', subject.active ?? true]);
  }
  const seen = new Set();
  for (const course of content.courses ?? []) {
    record(course);
    assert(integer(course.grade, 1, 99) && text(course.subject) && identifier.test(course.subject) && Array.isArray(course.items), 'Neplatný kurz.');
    const subject = (await client.query('SELECT kind FROM school_subjects WHERE id=$1', [course.subject])).rows[0];
    assert(subject, 'Neznámý předmět.');
    const previous = (await client.query('SELECT * FROM school_courses WHERE grade=$1 AND subject=$2', [course.grade, course.subject])).rows[0];
    const maxDigits = course.maxDigits ?? previous?.max_digits ?? 7;
    assert(integer(maxDigits, 1, 7), 'Neplatná délka výsledku.');
    for (const field of ['description', 'sourceTitle']) {
      assert(course[field] == null || (typeof course[field] === 'string' && course[field].length <= 2000), `Neplatné pole ${field}.`);
    }
    await client.query(`INSERT INTO school_courses(grade,subject,description,source_title,max_digits,sort_order,active)
      VALUES ($1,$2,$3,$4,$5,$6,$7) ON CONFLICT (grade,subject) DO UPDATE SET
      description=EXCLUDED.description, source_title=EXCLUDED.source_title, max_digits=EXCLUDED.max_digits,
      sort_order=EXCLUDED.sort_order, active=EXCLUDED.active`,
    [course.grade, course.subject, course.description ?? previous?.description ?? '', course.sourceTitle ?? previous?.source_title ?? '',
      maxDigits, course.sortOrder ?? previous?.sort_order ?? 0, course.active ?? previous?.active ?? true]);
    for (const item of course.items) {
      record(item);
      assert(text(item.id) && /^[a-zA-Z0-9][a-zA-Z0-9_-]{0,127}$/.test(item.id) && !seen.has(item.id), 'Chybné nebo duplicitní ID zadání.');
      seen.add(item.id);
      validateItem(item.data, subject.kind, maxDigits);
      const result = await client.query(`INSERT INTO practice_items(id,grade,subject,data,active) VALUES ($1,$2,$3,$4,$5)
        ON CONFLICT (id) DO UPDATE SET data=EXCLUDED.data, active=EXCLUDED.active
        WHERE practice_items.grade=EXCLUDED.grade AND practice_items.subject=EXCLUDED.subject RETURNING id`,
      [item.id, course.grade, course.subject, item.data, item.active ?? true]);
      assert(result.rowCount === 1, 'ID zadání už patří jinému kurzu.');
    }
    const existing = await client.query('SELECT data FROM practice_items WHERE grade=$1 AND subject=$2 AND active', [course.grade, course.subject]);
    for (const item of existing.rows) validateItem(item.data, subject.kind, maxDigits);
  }
  return seen.size;
}

export async function readCatalog(pool) {
  const { rows: [row] } = await pool.query(`SELECT json_build_object(
    'grades', COALESCE((SELECT json_agg(json_build_object('id',id,'name',name,'sortOrder',sort_order) ORDER BY sort_order,id)
      FROM school_grades WHERE active), '[]'::json),
    'subjects', COALESCE((SELECT json_agg(json_build_object('id',id,'slug',slug,'name',name,'kind',kind,'answerLanguage',answer_language) ORDER BY id)
      FROM school_subjects WHERE active), '[]'::json),
    'courses', COALESCE((SELECT json_agg(json_build_object('grade',c.grade,'subject',c.subject,'description',c.description,
      'sourceTitle',c.source_title,'maxDigits',c.max_digits,'sortOrder',c.sort_order,
      'items', COALESCE((SELECT json_agg(json_build_object('id',i.id,'data',i.data) ORDER BY i.id)
        FROM practice_items i WHERE i.grade=c.grade AND i.subject=c.subject AND i.active), '[]'::json)) ORDER BY c.sort_order,c.subject)
      FROM school_courses c JOIN school_grades g ON g.id=c.grade JOIN school_subjects s ON s.id=c.subject
      WHERE c.active AND g.active AND s.active), '[]'::json)) AS catalog`);
  return row.catalog;
}
