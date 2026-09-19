import 'dart:convert';
import 'dart:io';

import 'package:aaaskola/catalog.dart';
import 'package:aaaskola/main.dart';
import 'package:aaaskola/progress.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'daily_goals_fixture.dart';

final seed =
    jsonDecode(File('server/spelling-seed.json').readAsStringSync())
        as Map<String, dynamic>;
final item =
    (seed['courses'][0]['items'] as List).singleWhere(
          (item) => item['id'] == '7-czech-videly',
        )
        as Map<String, dynamic>;

Widget app(ProgressController progress, {Map<String, dynamic>? entry}) =>
    AaaSkolaApp(
      progress: progress,
      catalog: CatalogController(
        initial: SchoolCatalog.fromJson({
          'grades': [
            {'id': 7, 'name': '7. třída'},
          ],
          'subjects': seed['subjects'],
          'courses': [
            {
              ...seed['courses'][0] as Map<String, dynamic>,
              'items': [entry ?? item],
            },
          ],
        }),
      ),
    );

Future<void> tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> open(
  WidgetTester tester,
  ProgressController progress, {
  Map<String, dynamic>? entry,
}) async {
  await tester.pumpWidget(app(progress, entry: entry));
  await tester.pumpAndSettle();
  await tap(tester, find.text('7. třída'));
  await tap(tester, find.text('Čeština'));
}

Future<void> reopen(WidgetTester tester) async {
  await tester.pageBack();
  await tester.pumpAndSettle();
  await tap(tester, find.text('Čeština'));
}

void main() {
  testWidgets(
    'letter and reason must both be correct; back and full reload preserve the stage',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final saved = <String, String?>{};
      ProgressController controller() => ProgressController(
        enabled: false,
        readPractice: (key) => saved[key],
        writePractice: (key, value) => saved[key] = value,
      );
      var progress = controller();
      await open(tester, progress);
      final original = saved.values.single!;
      expect(find.byKey(const Key('reason-feminine')), findsNothing);
      await tap(tester, find.byKey(const Key('letter-i')));
      expect(find.text('Další úloha'), findsNothing);
      await reopen(tester);
      expect(jsonDecode(saved.values.single!)['total'], 16);
      expect(
        jsonDecode(saved.values.single!)['queue'][0]['exerciseId'],
        isNot(jsonDecode(original)['queue'][0]['exerciseId']),
      );
      await tap(tester, find.byKey(const Key('letter-y')));
      expect(find.text('2/2 · Zdůvodni pravopis'), findsOneWidget);
      expect(find.text('Další úloha'), findsNothing);
      expect(jsonDecode(saved.values.single!)['queue'][0]['step'], 1);
      await reopen(tester);
      expect(find.text('2/2 · Zdůvodni pravopis'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
      progress = controller();
      await open(tester, progress);
      expect(find.text('2/2 · Zdůvodni pravopis'), findsOneWidget);
      await tap(tester, find.byKey(const Key('reason-feminine')));
      expect(find.text('Správně! Písmeno i zdůvodnění.'), findsOneWidget);
      expect(find.text(item['data']['explanation'] as String), findsOneWidget);
      expect(jsonDecode(saved.values.single!)['completed'], 1);
      await tap(tester, find.text('Další úloha'));
      expect(
        jsonDecode(saved.values.single!)['queue'][0]['exerciseId'],
        isNot(jsonDecode(original)['queue'][0]['exerciseId']),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
    },
  );

  for (final id in ['7-czech-jela', '7-czech-koroptvi', '7-czech-vsi']) {
    testWidgets(
      '$id uses its actual vowel and matching grammatical explanation',
      (tester) async {
        final entry =
            (seed['courses'][0]['items'] as List).singleWhere(
                  (i) => i['id'] == id,
                )
                as Map<String, dynamic>;
        final progress = ProgressController(enabled: false);
        await open(tester, progress, entry: entry);
        await tap(tester, find.byKey(Key('letter-${entry['data']['letter']}')));
        await tap(tester, find.byKey(Key('reason-${entry['data']['reason']}')));
        expect(find.text('Správně! Písmeno i zdůvodnění.'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        progress.dispose();
      },
    );
  }

  testWidgets(
    'signed-in spelling retries lost responses once per ID and resumes the server stage',
    (tester) async {
      var step = 0;
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
              };
            case '/api/daily-goals':
              response = goalsData();
            case '/api/spelling/exercise':
              response = {
                'exerciseId': 'exercise',
                'step': step,
                'problem': item['data'],
                'itemId': item['id'],
              };
            case '/api/spelling/answer':
              final body = jsonDecode(request.body) as Map<String, dynamic>;
              expect(request.headers['X-CSRF-Token'], 'token');
              expect(body.containsKey('correct'), false);
              sent.add(body);
              response = replies.putIfAbsent(body['id'] as String, () {
                expect(body['step'], step);
                final correct =
                    body['answer'] == (step == 0 ? 'y' : 'feminine');
                final completed = correct && step == 1;
                if (correct) step = 1;
                return {'correct': correct, 'completed': completed};
              });
              if (loseResponse) {
                loseResponse = false;
                throw http.ClientException('Response lost after save');
              }
            default:
              throw StateError('Unexpected request ${request.url}');
          }
          return http.Response(
            jsonEncode(response),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      await open(tester, progress);
      await tap(tester, find.byKey(const Key('letter-y')));
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const Key('letter-i')))
            .onPressed,
        isNull,
      );
      await tap(tester, find.text('Zkusit znovu'));
      expect(sent, hasLength(2));
      expect(sent[0], sent[1]);
      await reopen(tester);
      expect(find.text('2/2 · Zdůvodni pravopis'), findsOneWidget);
      await tap(tester, find.byKey(const Key('reason-feminine')));
      expect(find.text('Další úloha'), findsOneWidget);
      expect(progress.goals!.math, 0);
      expect(progress.goals!.vocabulary, 0);
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
    },
  );

  testWidgets(
    'failed server assignment never falls back to an easier guest question',
    (tester) async {
      final progress = ProgressController(
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
      expect(find.byKey(const Key('spelling-sentence')), findsNothing);
      expect(
        find.text('Rozpracovanou úlohu se nepodařilo načíst. Zkus to znovu.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
    },
  );
}
