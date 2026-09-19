import 'dart:async';
import 'dart:convert';
import 'package:aaaskola/progress.dart';
import 'package:aaaskola/progress_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'daily_goals_fixture.dart';

void main() {
  late ProgressController progress;
  var owner = 'alice';
  var stored = goalsData(math: 14, vocabulary: 15);
  var available = true;
  final pending = <String, String>{};
  var now = DateTime.utc(2026, 9, 17, 21, 59, 50);
  Completer<http.Response>? delayedGoals;
  setUp(() {
    owner = 'alice';
    stored = goalsData(math: 14, vocabulary: 15);
    available = true;
    pending.clear();
    delayedGoals = null;
    now = DateTime.utc(2026, 9, 17, 21, 59, 50);
    progress = ProgressController(
      enabled: true,
      now: () => now,
      baseUrl: Uri.parse('https://aaaskola.cz'),
      readPending: (id) => pending[id],
      writePending: (id, value) => pending[id] = value,
      client: MockClient((request) async {
        if (request.url.path == '/api/me') {
          return http.Response(
            jsonEncode({
              'user': {'id': owner},
              'csrf': 'csrf',
            }),
            200,
          );
        }
        if (request.url.path == '/api/daily-goals') {
          if (delayedGoals != null) return delayedGoals!.future;
          return http.Response(jsonEncode(stored), available ? 200 : 503);
        }
        if (request.url.path == '/api/attempts') {
          if (!available) return http.Response('{}', 503);
          final body = jsonDecode(request.body);
          if (body['completed'] == true && body['subject'] == 'math') {
            stored['math'] = (stored['math'] as int) + 1;
          }
          return http.Response('{}', 201);
        }
        return http.Response('', 204);
      }),
    );
  });

  void answer({bool completed = true}) => progress.record(
    exerciseId: newExerciseId(),
    subject: 'math',
    grade: 5,
    correct: completed,
    completed: completed,
  );

  test(
    'saved answers advance goals; failures wait for sync; reload and logout use server state',
    () async {
      await progress.load();
      expect(progress.goals!.math, 14);
      answer(completed: false);
      await progress.flush();
      expect(progress.goals!.math, 14);
      available = false;
      answer();
      await progress.flush();
      expect(progress.goals!.completed, false);
      expect(progress.pendingCount, 1);
      available = true;
      await progress.flush();
      await progress.refreshGoals();
      expect(progress.goals!.completed, true);
      expect(progress.pendingCount, 0);
      await progress.load();
      expect(progress.goals!.math, 15);
      await progress.logout();
      expect(progress.goals, isNull);
      owner = 'bob';
      stored = goalsData();
      await progress.load();
      expect(progress.goals!.math, 0);
      progress.dispose();
    },
  );

  test('a late goals response cannot restore progress after logout', () async {
    await progress.load();
    delayedGoals = Completer<http.Response>();
    final request = progress.refreshGoals();
    await progress.logout();
    delayedGoals!.complete(http.Response(jsonEncode(stored), 200));
    await request;
    expect(progress.goals, isNull);
    progress.dispose();
  });

  test('a slow goals refresh does not block saving the next answer', () async {
    await progress.load();
    delayedGoals = Completer<http.Response>();
    answer();
    await progress.flush();
    answer();
    await progress.flush();
    expect(progress.pendingCount, 0);
    expect(stored['math'], 16);
    delayedGoals!.complete(http.Response(jsonEncode(stored), 200));
    await progress.refreshGoals();
    expect(progress.goals!.math, 16);
    progress.dispose();
  });

  testWidgets(
    'midnight clears yesterday even offline, then loads the new day',
    (tester) async {
      stored['resetsAt'] = '2026-09-17T22:00:00.000Z';
      await progress.load();
      expect(progress.goals!.math, 14);
      available = false;
      now = DateTime.utc(2026, 9, 17, 22);
      await tester.pump(const Duration(seconds: 10));
      expect(progress.goals, isNull);
      expect(progress.goalsError, isNotNull);
      available = true;
      stored = {
        ...goalsData(),
        'day': '2026-09-18',
        'resetsAt': '2026-09-18T22:00:00.000Z',
      };
      await tester.pump(const Duration(minutes: 1));
      expect(progress.goals!.day, DateTime(2026, 9, 18));
      expect(progress.goals!.math, 0);
      progress.dispose();
    },
  );

  testWidgets(
    'daily card shows 14/15, completion, capped bars and guest instructions on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await progress.load();
      await tester.pumpWidget(
        ProgressScope(
          controller: progress,
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: DailyGoalsCard()),
            ),
          ),
        ),
      );
      expect(find.text('Příklady: 14 / 15'), findsOneWidget);
      expect(find.text('Slovíčka: 15 / 15 · Splněno!'), findsOneWidget);
      stored = goalsData(math: 20, vocabulary: 18);
      await progress.refreshGoals();
      await tester.pump();
      expect(find.text('Dnešní úkoly jsou splněné!'), findsOneWidget);
      expect(find.text('Příklady: 15 / 15 · Splněno!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await progress.logout();
      await tester.pump();
      expect(find.text('Příklady: cíl 15'), findsOneWidget);
      expect(
        find.text('Přihlas se a ukládej si plnění denních úkolů.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      progress.dispose();
    },
  );
}
