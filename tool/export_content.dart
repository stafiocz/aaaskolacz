import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'math_seed.dart';
import 'vocabulary_seed.dart';
import 'vocabulary_grade5_seed.dart';

Map<String, dynamic> problemJson(MathProblem p) => {
  'group': p.mode.name,
  'heading': p.mode.heading,
  'beforeAnswer': p.beforeAnswer,
  'afterAnswer': p.afterAnswer,
  'answer': p.answer,
  'instruction':
      p.instruction ??
      (p.mode == PracticeMode.brackets
          ? 'Nejdřív spočítej závorku, pak celý příklad.'
          : p.mode.hasMissingNumber
          ? 'Doplň chybějící číslo a potvrď ho.'
          : 'Napiš výsledek a potvrď ho.'),
  if (p.verification != null) 'verification': p.verification,
  if (p.nextStep != null) 'nextStep': problemJson(p.nextStep!),
};

void main() {
  final courses = <Map<String, dynamic>>[];
  for (final grade in [3, 5]) {
    final random = Random(20260917 + grade);
    final items = <Map<String, dynamic>>[];
    for (final mode in grade == 3 ? grade3Modes : grade5Modes) {
      final bank = <String, MathProblem>{};
      final size = mode == PracticeMode.additionSubtraction ? 24 : 60;
      while (bank.length < size) {
        final problem = MathProblem.next(mode, random);
        bank[problem.question] = problem;
      }
      var index = 0;
      for (final problem in bank.values) {
        items.add({
          'id': '$grade-math-${mode.name}-${++index}',
          'data': problemJson(problem),
        });
      }
    }
    courses.add({
      'grade': grade,
      'subject': 'math',
      'sortOrder': 0,
      'description': grade == 3
          ? 'Sčítání a odčítání do 100, násobilka, dělení, závorky a doplňování čísel. Vše v jednom mixu.'
          : 'Miliony · sčítání, odčítání, násobení, dělení a početní řetězce. Vše v jednom mixu.',
      'sourceTitle': grade == 3 ? 'Mix příkladů' : 'Miliony – opakování',
      'maxDigits': grade == 3 ? 3 : 7,
      'items': items,
    });
  }
  for (final grade in [5, 7]) {
    var index = 0;
    courses.add({
      'grade': grade,
      'subject': 'english',
      'sortOrder': 1,
      'description':
          'Slovíčka a fráze z učebnice. Kartičky a zkoušení v jednom mixu.',
      'sourceTitle': grade == 5
          ? 'Introduction a Me! · strany 4–21'
          : 'Introduction · strany 4–7',
      'maxDigits': 3,
      'items': [
        for (final word in grade == 5 ? vocabularyGrade5 : vocabulary)
          {
            'id': '$grade-english-${++index}',
            'data': {
              'english': word.english,
              'czech': word.czech,
              'topic': word.topic,
              'page': word.page,
              'alternatives': word.alternatives,
            },
          },
      ],
    });
  }
  final content = {
    'grades': [
      for (final grade in [7, 5, 3])
        {'id': grade, 'name': '$grade. třída', 'sortOrder': 10 - grade},
    ],
    'subjects': [
      {
        'id': 'math',
        'slug': 'matematika',
        'name': 'Matematika',
        'kind': 'math',
        'answerLanguage': '',
      },
      {
        'id': 'english',
        'slug': 'anglictina',
        'name': 'Angličtina',
        'kind': 'vocabulary',
        'answerLanguage': 'anglicky',
      },
    ],
    'courses': courses,
  };
  File('server/content-seed.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(content)}\n',
  );
  stdout.writeln(
    '${courses.length} kurzů, ${courses.fold<int>(0, (n, c) => n + (c['items'] as List).length)} zadání',
  );
}
