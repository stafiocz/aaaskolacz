import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { validateItem } from './catalog.js';

const seed = JSON.parse(await readFile(new URL('./german-seed.json', import.meta.url), 'utf8'));
const items = seed.courses[0].items;
const data = id => items.find(item => item.id === `7-german-${id}`).data;

test('German notes cover vocabulary, all pronouns and corrected conjugation and accusative', () => {
  assert.equal(items.length, 68);
  assert.equal(new Set(items.map(item => item.id)).size, 68);
  assert.equal(items.filter(item => item.data.exerciseType === 'vocabulary').length, 21);
  for (const item of items) validateItem(item.data, 'vocabulary', 7);
  const expected = {
    ich: ['habe', 'koche'], du: ['hast', 'kochst'], er: ['hat', 'kocht'],
    'sie-singular': ['hat', 'kocht'], es: ['hat', 'kocht'], wir: ['haben', 'kochen'],
    ihr: ['habt', 'kocht'], 'sie-plural': ['haben', 'kochen'], 'sie-formal': ['haben', 'kochen'],
  };
  for (const [id, forms] of Object.entries(expected)) {
    assert.deepEqual([data(`haben-${id}`).english, data(`kochen-${id}`).english], forms);
  }
  assert.equal(data('pronoun-sie-formal').english, 'Sie');
  assert.equal(data('pronoun-sie-plural').english, 'sie');
  assert.equal(data('sentence-du-wein').english, 'Du hast den Wein.');
  assert.equal(data('sentence-sie-saft').english, 'Sie hat den Saft.');
  assert.equal(data('sentence-wir-apfel').english, 'Wir haben den Apfel.');
  assert.deepEqual(data('word-paprika').alternatives, ['der Paprika']);
});

test('language content rejects invalid type, nonboolean casing and grammar without explanation', () => {
  for (const change of [{ exerciseType: 'other' }, { caseSensitive: 'true' }, { instruction: '' }, { explanation: null }]) {
    assert.throws(() => validateItem({ ...data('haben-du'), ...change }, 'vocabulary', 7));
  }
});
