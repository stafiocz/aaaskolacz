import { readFile, mkdir, writeFile } from 'node:fs/promises';
import { resolve, join } from 'node:path';
import { validateItem } from '../server/catalog.js';

const output = process.argv[2];
if (!output) throw new Error('Použití: node tool/export_math_grade2.mjs VÝSTUPNÍ_ADRESÁŘ');
const pages = JSON.parse(await readFile(new URL('./math_grade2_source.json', import.meta.url), 'utf8'));
const headings = {
  within20: 'POČÍTÁNÍ DO 20', within100: 'POČÍTÁNÍ DO 100', tens: 'POČÍTÁNÍ S DESÍTKAMI',
  missing: 'DOPLŇ ČÍSLO', brackets: 'POČÍTÁNÍ SE ZÁVORKAMI', split: 'ROZLOŽ A VYPOČÍTEJ',
  rounding: 'ZAOKROUHLOVÁNÍ NA DESÍTKY',
};
function calculate(expression) {
  if (!/^[0-9+()\-]+$/.test(expression)) throw new Error(`Neplatný výraz: ${expression}`);
  const tokens = expression.match(/\d+|[()+-]/g);
  let index = 0;
  function number() {
    const token = tokens[index++];
    if (token === '(') {
      const value = sum();
      if (tokens[index++] !== ')') throw new Error('Chybí uzavírací závorka.');
      return value;
    }
    if (!/^\d+$/.test(token ?? '')) throw new Error('Chybí číslo.');
    return Number(token);
  }
  function sum() {
    let value = number();
    while (['+', '-'].includes(tokens[index])) {
      const operator = tokens[index++];
      value += (operator === '+' ? 1 : -1) * number();
      if (value < 0 || value > 100) throw new Error(`Výpočet mimo rozsah: ${expression}`);
    }
    return value;
  }
  const value = sum();
  if (index !== tokens.length) throw new Error(`Zbytek výrazu: ${expression}`);
  return value;
}
const display = expression => expression.replaceAll('+', ' + ').replaceAll('-', ' − ').replaceAll('=', ' = ').trim();
const step = (group, beforeAnswer, answer, instruction, afterAnswer = '') => ({
  group, heading: headings[group], beforeAnswer, afterAnswer, answer, instruction,
});
const rounded = number => Math.floor((number + 5) / 10) * 10;
function exercise(kind, expression) {
  if (kind === 'missing') {
    const [left, right] = expression.split('=');
    if ((expression.match(/_/g) ?? []).length !== 1 || !right) throw new Error('Chybné doplňování.');
    const answers = Array.from({ length: 101 }, (_, i) => i).filter(i => {
      try { return calculate(left.replace('_', i)) === calculate(right.replace('_', i)); }
      catch { return false; }
    });
    if (answers.length !== 1) throw new Error(`Nejednoznačné doplňování: ${expression}`);
    const [before, after] = display(expression).split('_');
    return step('missing', before.trim(), answers[0], 'Doplň chybějící číslo.', after.trim());
  }
  const answer = calculate(expression);
  if (kind === 'round') return step('rounding', `${expression} ≐`, rounded(answer), 'Zaokrouhli na nejbližší desítku. Je-li na místě jednotek 5 až 9, zaokrouhli nahoru.');
  if (kind === 'calculateRound') {
    const data = step('rounding', `${display(expression)} =`, answer, 'Nejdřív vypočítej přesný výsledek. Potom ho zaokrouhlíš na desítky.');
    data.nextStep = exercise('round', String(answer));
    return data;
  }
  if (kind === 'split') {
    const [, aText, operator, bText] = expression.match(/^(\d+)([+-])(\d+)$/) ?? [];
    const a = Number(aText), b = Number(bText);
    const first = operator === '+' ? 10 - a % 10 : a % 10;
    const rest = b - first;
    if (!(first > 0 && rest > 0)) throw new Error(`Příklad nepřechází přes desítku: ${expression}`);
    const boundary = operator === '+' ? a + first : a - first;
    const data = step('split', display(`${a}${operator}`), first,
      `Příklad ${display(expression)}: kolik ${operator === '+' ? 'přičteš' : 'odečteš'} nejprve, aby ${operator === '+' ? 'vzniklo' : 'zbylo'} ${boundary}?`, `= ${boundary}`);
    data.nextStep = step('split', `${b} = ${first} +`, rest, `Rozlož číslo ${b}. Doplň jeho druhou část.`);
    data.nextStep.nextStep = step('split', `${display(`${a}${operator}${first}${operator}${rest}`)} =`, answer,
      `Dokonči výpočet původního příkladu ${display(expression)}.`);
    return data;
  }
  if (kind !== 'calculate') throw new Error(`Neznámý typ: ${kind}`);
  const numbers = expression.match(/\d+/g).map(Number);
  const group = expression.includes('(') ? 'brackets'
    : numbers.every(n => n % 10 === 0) ? 'tens'
    : Math.max(answer, ...numbers) <= 20 ? 'within20' : 'within100';
  return step(group, `${display(expression)} =`, answer,
    group === 'brackets' ? 'Nejdřív vypočítej závorku. Napiš výsledek celého příkladu.' : 'Napiš výsledek a potvrď ho.');
}
const items = new Map();
let sourceCount = 0;
for (const { page, ...sections } of pages) {
  for (const [kind, expressions] of Object.entries(sections)) {
    for (const expression of expressions) {
      sourceCount++;
      const id = `2-math-${kind}-${expression.replaceAll('+', 'p').replaceAll('-', 'm').replaceAll('(', 'l').replaceAll(')', 'r').replaceAll('=', 'eq')}`;
      if (items.has(id)) {
        const sourcePages = items.get(id).data.sourcePages;
        if (!sourcePages.includes(page)) sourcePages.push(page);
        continue;
      }
      const data = { ...exercise(kind, expression), sourcePages: [page] };
      validateItem(data, 'math', 3);
      items.set(id, { id, data });
    }
  }
}
const grade = { id: 2, name: '2. třída', sortOrder: 8 };
const course = {
  grade: 2, subject: 'math', maxDigits: 3, sortOrder: 0,
  description: 'Sčítání a odčítání do 100, doplňování čísel, rozklady přes desítku, závorky a zaokrouhlování.',
  sourceTitle: 'Pracovní sešit – fotografie stran 3–6 a 9–24',
};
const content = { grades: [grade], courses: [{ ...course, items: [...items.values()] }] };
const directory = resolve(output);
await mkdir(directory, { recursive: true });
await writeFile(join(directory, 'content.json'), JSON.stringify(content, null, 2) + '\n');
console.log(JSON.stringify({ sourceCount, uniqueItems: items.size, pages: pages.map(p => p.page),
  groups: Object.fromEntries(Object.keys(headings).map(group => [group, [...items.values()].filter(i => i.data.group === group).length])),
  contentBytes: Buffer.byteLength(JSON.stringify(content)), directory }, null, 2));
