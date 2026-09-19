import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { validateItem } from './catalog.js';

const seed = JSON.parse(await readFile(new URL('./spelling-seed.json', import.meta.url), 'utf8'));
const items = seed.courses[0].items;
test('worksheet has 28 unique, valid two-stage exercises including agreement and long vowels', () => {
  assert.equal(items.length, 28);
  assert.equal(new Set(items.map(i => i.id)).size, 28);
  for (const item of items) validateItem(item.data, 'spelling', 7);
  const expected = { dosli: ['i', 'animate'], tvrzi: ['i', 'pisen'], rozloucili: ['i', 'animate'],
    uciteli: ['i', 'muz'], videly: ['y', 'feminine'], koroptvi: ['í', 'pisen'], vypravili: ['i', 'animate'],
    houby: ['y', 'zena'], meli: ['i', 'animate'], datli: ['i', 'pan'], topoly: ['y', 'hrad'],
    slouzily: ['y', 'inanimate'], vetrolamy: ['y', 'hrad'], rostly: ['y', 'feminine'], vrby: ['y', 'zena'],
    mezi: ['i', 'pisen'], cvrkali: ['i', 'animate'], hyrily: ['y', 'inanimate'], barvami: ['i', 'zena'],
    jela: ['a', 'neuter'], svetly: ['y', 'mesto'], vsi: ['í', 'kost'], krouzili: ['i', 'animate'],
    holubi: ['i', 'pan'], ridili: ['i', 'animate'], pravidly: ['y', 'mesto'], lezely: ['y', 'inanimate'], stromy: ['y', 'hrad'] };
  for (const item of items) assert.deepEqual([item.data.letter, item.data.reason], expected[item.id.replace('7-czech-', '')]);
});

test('content import rejects ambiguous gaps, missing answers and duplicate reasoning choices', () => {
  const data = items[0].data;
  for (const change of [
    { sentence: 'Žáci přišli.' }, { sentence: 'Žáci přišl_ a odešl_.' }, { letter: 'e' },
    { reason: 'missing' }, { reasons: data.reasons.slice(0, 1) },
    { reasons: [data.reasons[0], data.reasons[0], data.reasons[1]] }, { explanation: '' },
  ]) assert.throws(() => validateItem({ ...data, ...change }, 'spelling', 7));
});
