import 'catalog_fixture.dart';
import 'dart:convert';
import 'package:aaaskola/english_page.dart';
import '../tool/math_seed.dart';
import 'package:aaaskola/progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'english_page_test.dart' show words, tapText, answer;
import 'practice_grade5_test.dart' show answerCorrectly;
import 'practice_test.dart' show submit, key;

void main() {
  late ProgressController progress;
  final attempts = <Map<String, dynamic>>[];
  setUp(() {
    attempts.clear();
    progress = ProgressController(
      enabled: true,
      baseUrl: Uri.parse('https://aaaskola.cz'),
      readPending: (_) => null,
      writePending: (_, _) {},
      client: MockClient((request) async {
        if (request.url.path == '/api/me') {
          return http.Response(
            jsonEncode({
              'user': {
                'id': 'alice',
                'name': 'Alice',
                'email': 'alice@example.test',
              },
              'csrf': 'csrf',
              'today': '2026-09-17',
              'loginAvailable': true,
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/api/stats') {
          return http.Response(
            jsonEncode({
              'days': [
                {
                  'day': '2026-09-17',
                  'subject': 'math',
                  'subjectName': 'Matematika',
                  'subjectKind': 'math',
                  'gradeName': '5. třída',
                  'grade': 5,
                  'completed': 3,
                  'correct': 4,
                  'incorrect': 2,
                },
                {
                  'day': '2026-09-17',
                  'subject': 'english',
                  'subjectName': 'Angličtina',
                  'subjectKind': 'vocabulary',
                  'gradeName': '5. třída',
                  'grade': 5,
                  'completed': 2,
                  'correct': 2,
                  'incorrect': 1,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        attempts.add(jsonDecode(request.body) as Map<String, dynamic>);
        return http.Response('{}', 201);
      }),
    );
  });
  tearDown(() => progress.dispose());

  testWidgets(
    'daily results show separate subjects, counts and empty days on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(testApp(progress: progress));
      await tester.pumpAndSettle();
      await tapText(tester, 'Moje výsledky');
      expect(find.text('17. 9. 2026'), findsOneWidget);
      expect(find.text('Matematika · 5. třída'), findsWidgets);
      expect(find.text('Angličtina · 5. třída'), findsWidgets);
      expect(find.textContaining('Dokončeno příkladů: 3'), findsWidgets);
      expect(find.textContaining('Správně: 4   ·   Chybně: 2'), findsWidgets);
      expect(find.text('Zatím žádné procvičování.'), findsWidgets);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'math records mistakes and counts a two-step chain as one completed exercise',
    (tester) async {
      await tester.pumpWidget(testApp(progress: progress));
      await tester.pumpAndSettle();
      await tapText(tester, '5. třída');
      await tapText(tester, 'Matematika');
      await key(tester, '9');
      await key(tester, '9');
      await key(tester, '9');
      await key(tester, '9');
      await key(tester, '9');
      await key(tester, '9');
      await key(tester, '9');
      await submit(tester);
      expect(attempts.single['correct'], false);
      expect(attempts.single['completed'], false);
      for (var index = 0; index < grade5Modes.length; index++) {
        await answerCorrectly(tester);
        await submit(tester);
        if (find.textContaining('Krok 2').evaluate().isNotEmpty) {
          await answerCorrectly(tester);
          await submit(tester);
        }
      }
      expect(
        attempts.every((a) => a['subject'] == 'math' && a['grade'] == 5),
        true,
      );
      expect(
        attempts.where((a) => a['completed'] == true).length,
        grade5Modes.length,
      );
      final chain = attempts
          .where((a) => a['correct'] == true && a['completed'] == false)
          .single;
      expect(
        attempts.where(
          (a) =>
              a['exerciseId'] == chain['exerciseId'] && a['completed'] == true,
        ),
        hasLength(1),
      );
    },
  );
  testWidgets(
    'English records unknown words and their successful retry under one exercise ID',
    (tester) async {
      await progress.load();
      await progress.flush();
      await tester.pumpWidget(
        ProgressScope(
          controller: progress,
          child: const MaterialApp(home: EnglishPage(grade: 5, entries: words)),
        ),
      );
      await tapText(tester, 'Rovnou se vyzkoušet');
      await tapText(tester, 'Nevím · ukázat odpověď');
      expect(attempts, hasLength(1));
      expect(attempts.first['correct'], false);
      await tapText(tester, 'Pokračovat');
      await answer(tester);
      await answer(tester);
      expect(attempts, hasLength(3));
      expect(attempts.last['exerciseId'], attempts.first['exerciseId']);
      expect(attempts.last['completed'], true);
      expect(
        attempts.every((a) => a['subject'] == 'english' && a['grade'] == 5),
        true,
      );
    },
  );
}
