import 'dart:convert';
import 'dart:math';
import 'package:aaaskola/catalog.dart';
import 'package:aaaskola/main.dart';
import 'package:aaaskola/math_problem.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'catalog_fixture.dart';
import 'english_page_test.dart' show tapText;

Map<String, dynamic> problem(String group, int value) => {
  'group': group,
  'heading': 'SČÍTÁNÍ',
  'beforeAnswer': '$value + 1 =',
  'afterAnswer': '',
  'answer': value + 1,
};

void main() {
  test(
    'database mix covers all groups and each group deck before repeating',
    () {
      final practice = MixedPractice(
        random: Random(4),
        problems: [
          for (final group in ['a', 'b', 'c'])
            for (var i = 0; i < 10; i++)
              MathProblem.fromJson(problem(group, i)),
        ],
      );
      final seen = <String, Set<String>>{};
      MathProblem? last;
      for (var cycle = 0; cycle < 10; cycle++) {
        final groups = <String>{};
        for (var index = 0; index < 3; index++) {
          final next = practice.next();
          expect(next.group, isNot(last?.group));
          expect(groups.add(next.group), true);
          expect((seen[next.group] ??= {}).add(next.question), true);
          last = next;
        }
      }
      expect(seen.values.every((questions) => questions.length == 10), true);
      final single = MixedPractice(
        problems: [MathProblem.fromJson(problem('a', 2))],
      );
      expect(single.next().answer, 3);
      expect(single.next().answer, 3);
    },
  );

  test('runtime content includes every notebook problem and chained steps', () {
    final catalog = SchoolCatalog.fromJson(seedJson());
    final course = catalog.courses.firstWhere(
      (c) => c['grade'] == 3 && c['subject'] == 'math',
    );
    final notebook = catalog
        .problems(course)
        .where((p) => p.group == 'additionSubtraction');
    expect(notebook.length, 24);
    for (final p in notebook) {
      final numbers = RegExp(
        r'\d+',
      ).allMatches(p.beforeAnswer).map((m) => int.parse(m[0]!)).toList();
      expect(
        p.answer,
        p.beforeAnswer.contains('+')
            ? numbers[0] + numbers[1]
            : numbers[0] - numbers[1],
      );
    }
    final chain = MathProblem.fromJson({
      ...problem('chain', 1),
      'nextStep': problem('chain', 5),
    });
    expect(chain.nextStep!.answer, 6);
  });

  testWidgets(
    'loading failure retries; refresh adds routes and exercises without app changes',
    (tester) async {
      var status = 503;
      var data = <String, dynamic>{'grades': [], 'subjects': [], 'courses': []};
      final controller = CatalogController(
        baseUrl: Uri.parse('https://aaaskola.cz'),
        client: MockClient((request) async {
          expect(request.url.path, '/api/catalog');
          return http.Response(
            jsonEncode(data),
            status,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(AaaSkolaApp(catalog: controller));
      await tester.pumpAndSettle();
      expect(find.textContaining('nepodařilo načíst'), findsOneWidget);
      status = 200;
      await tapText(tester, 'Zkusit znovu');
      expect(find.text('Cvičení se připravují.'), findsOneWidget);
      data = {
        'grades': [
          {'id': 4, 'name': 'Čtvrťáci'},
        ],
        'subjects': [
          {
            'id': 'numbers',
            'slug': 'cisla',
            'name': 'Čísla',
            'kind': 'math',
            'answerLanguage': '',
          },
          {
            'id': 'german',
            'slug': 'nemcina',
            'name': 'Němčina',
            'kind': 'vocabulary',
            'answerLanguage': 'německy',
          },
        ],
        'courses': [
          {
            'grade': 4,
            'subject': 'numbers',
            'description': 'Počítání',
            'sourceTitle': '',
            'maxDigits': 3,
            'items': [
              {'id': 'new-example', 'data': problem('new', 23)},
            ],
          },
          {
            'grade': 4,
            'subject': 'german',
            'description': 'Slovíčka',
            'sourceTitle': 'Nová slovíčka',
            'maxDigits': 3,
            'items': [
              {
                'id': 'house',
                'data': {
                  'english': 'Haus',
                  'czech': 'dům',
                  'topic': 'Doma',
                  'page': 1,
                  'alternatives': ['das Haus'],
                },
              },
            ],
          },
        ],
      };
      await tapText(tester, 'Obnovit nabídku');
      await tapText(tester, 'Čtvrťáci');
      await tapText(tester, 'Čísla');
      expect(find.textContaining('23 + 1 ='), findsOneWidget);
      await tapText(tester, '2');
      await tapText(tester, '4');
      await tapText(tester, 'Zkontrolovat');
      expect(find.text('Výborně! To je správně.'), findsOneWidget);
      await tapText(tester, 'Čísla · Čtvrťáci');
      await tapText(tester, 'Němčina');
      expect(find.text('Němčina · Čtvrťáci'), findsOneWidget);
      await tapText(tester, 'Rovnou se vyzkoušet');
      expect(find.text('dům'), findsOneWidget);
      await tester.enterText(
        find.byKey(const ValueKey('vocabulary-answer')),
        'das Haus',
      );
      await tapText(tester, 'Zkontrolovat');
      expect(find.text('Správně!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('failed refresh retains the last loaded catalog', () async {
    final initial = SchoolCatalog.fromJson(seedJson());
    final controller = CatalogController(
      initial: initial,
      client: MockClient((_) async => http.Response('', 503)),
    );
    await controller.load();
    expect(controller.data, same(initial));
    expect(controller.error, isNotNull);
    controller.dispose();
  });
}
