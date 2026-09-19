import 'dart:convert';

import 'package:aaaskola/catalog.dart';
import 'package:aaaskola/main.dart';
import 'package:aaaskola/progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'daily_goals_fixture.dart';
import 'practice_test.dart' show key, submit, textAt;

final firstStep = <String, dynamic>{
  'group': 'chain',
  'heading': 'ŘETĚZEC',
  'beforeAnswer': '8 : 2 =',
  'afterAnswer': '',
  'answer': 4,
  'nextStep': {
    'group': 'chain',
    'heading': 'ŘETĚZEC',
    'beforeAnswer': '4 + 2 =',
    'afterAnswer': '',
    'answer': 6,
  },
};

Widget app(ProgressController progress) => AaaSkolaApp(
  progress: progress,
  catalog: CatalogController(
    initial: SchoolCatalog.fromJson({
      'grades': [
        {'id': 3, 'name': '3. třída'},
      ],
      'subjects': [
        {
          'id': 'math',
          'slug': 'matematika',
          'name': 'Matematika',
          'kind': 'math',
        },
      ],
      'courses': [
        {
          'grade': 3,
          'subject': 'math',
          'description': 'Mix',
          'maxDigits': 3,
          'items': [
            {'id': 'chain', 'data': firstStep},
          ],
        },
      ],
    }),
  ),
);

Future<void> tap(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

Future<void> open(WidgetTester tester, ProgressController progress) async {
  await tester.pumpWidget(app(progress));
  await tester.pumpAndSettle();
  await tap(tester, '3. třída');
  await tap(tester, 'Matematika');
}

Future<void> reopen(WidgetTester tester) async {
  await tap(tester, 'Matematika · 3. třída');
  await tap(tester, 'Matematika');
}

void main() {
  testWidgets(
    'guest cannot reroll on back or reload, and resumes the second chain step',
    (tester) async {
      final saved = <String, String?>{};
      ProgressController controller() => ProgressController(
        enabled: false,
        readPractice: (course) => saved[course],
        writePractice: (course, value) => saved[course] = value,
      );
      var progress = controller();
      await open(tester, progress);
      final original = saved['3.math'];
      expect(original, isNotNull);
      for (var index = 0; index < 3; index++) {
        await reopen(tester);
        expect(saved['3.math'], original);
        expect(textAt(tester, 'problem'), '8 : 2 =');
      }
      await key(tester, '9');
      await submit(tester);
      await reopen(tester);
      expect(saved['3.math'], original);
      await key(tester, '4');
      await submit(tester);
      expect(textAt(tester, 'score'), 'Správně: 0');
      await reopen(tester);
      expect(textAt(tester, 'problem'), '4 + 2 =');
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
      progress = controller();
      await open(tester, progress);
      expect(textAt(tester, 'problem'), '4 + 2 =');
      await key(tester, '6');
      await submit(tester);
      expect(textAt(tester, 'score'), 'Správně: 1');
      expect(saved['3.math'], isNull);
      await submit(tester);
      expect(
        jsonDecode(saved['3.math']!)['exerciseId'],
        isNot(jsonDecode(original!)['exerciseId']),
      );
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
    },
  );

  testWidgets(
    'signed-in math restores the server step and retries a lost answer response with the same ID',
    (tester) async {
      var step = 0;
      var completed = false;
      var loseResponse = true;
      final sent = <Map<String, dynamic>>[];
      final replies = <String, Map<String, dynamic>>{};
      final progress = ProgressController(
        enabled: true,
        baseUrl: Uri.parse('https://aaaskola.cz'),
        readPending: (_) => null,
        writePending: (_, _) {},
        client: MockClient((request) async {
          Map<String, dynamic> response;
          switch (request.url.path) {
            case '/api/me':
              response = {
                'user': {
                  'id': 'alice',
                  'name': 'Alice',
                  'email': 'alice@example.test',
                },
                'csrf': 'token',
                'loginAvailable': true,
              };
            case '/api/daily-goals':
              response = goalsData(math: completed ? 1 : 0);
            case '/api/math/exercise':
              response = {
                'exerciseId': 'exercise',
                'step': step,
                'problem': step == 0 ? firstStep : firstStep['nextStep'],
              };
            case '/api/math/answer':
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              sent.add(body);
              expect(body.containsKey('correct'), false);
              response = replies.putIfAbsent(body['id'] as String, () {
                expect(body['step'], step);
                final correct = body['answer'] == (step == 0 ? 4 : 6);
                completed = correct && step == 1;
                if (correct && !completed) step++;
                return {'correct': correct, 'completed': completed};
              });
              if (loseResponse) {
                loseResponse = false;
                throw http.ClientException('Connection lost after save');
              }
            default:
              throw StateError('Unexpected request: ${request.url}');
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await open(tester, progress);
      await reopen(tester);
      expect(textAt(tester, 'problem'), '8 : 2 =');
      await key(tester, '4');
      await submit(tester);
      expect(find.text('Zkusit odeslat znovu'), findsOneWidget);
      expect(textAt(tester, 'score'), 'Správně: 0');
      await key(tester, '9');
      expect(textAt(tester, 'answer'), '4');
      await submit(tester);
      expect(sent, hasLength(2));
      expect(sent[0], sent[1]);
      await reopen(tester);
      expect(textAt(tester, 'problem'), '4 + 2 =');
      await key(tester, '6');
      await submit(tester);
      expect(textAt(tester, 'score'), 'Správně: 1');
      expect(progress.goals!.math, 1);
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
    },
  );

  testWidgets(
    'unavailable account or assignment does not fall back to a new guest problem',
    (tester) async {
      var accountAvailable = false;
      final progress = ProgressController(
        enabled: true,
        baseUrl: Uri.parse('https://aaaskola.cz'),
        readPending: (_) => null,
        writePending: (_, _) {},
        client: MockClient((request) async {
          if (request.url.path == '/api/me' && accountAvailable) {
            return http.Response(
              jsonEncode({
                'user': {
                  'id': 'alice',
                  'name': 'Alice',
                  'email': 'alice@example.test',
                },
                'csrf': 'token',
              }),
              200,
            );
          }
          if (request.url.path == '/api/daily-goals') {
            return http.Response(jsonEncode(goalsData()), 200);
          }
          return http.Response('{}', 503);
        }),
      );
      await open(tester, progress);
      expect(find.byKey(const ValueKey('problem')), findsNothing);
      expect(
        find.text('Účet se nepodařilo načíst. Zkus to znovu.'),
        findsOneWidget,
      );
      accountAvailable = true;
      await tap(tester, 'Zkusit znovu');
      expect(find.byKey(const ValueKey('problem')), findsNothing);
      expect(
        find.text('Rozpracovaný příklad se nepodařilo načíst. Zkus to znovu.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
    },
  );
}
