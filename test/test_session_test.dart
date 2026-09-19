import 'dart:convert';

import 'package:aaaskola/progress.dart';
import 'package:aaaskola/test_session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final kind in ['math', 'spelling', 'vocabulary']) {
    test(
      '$kind guest retries persist, add one task each time, and finish only after all repairs',
      () async {
        final saved = <String, String?>{};
        ProgressController controller() => ProgressController(
          enabled: false,
          readPractice: (key) => saved[key],
          writePractice: (key, value) => saved[key] = value,
        );
        var progress = controller();
        final items = List.generate(
          32,
          (i) => <String, dynamic>{
            'id': 'item-$i',
            'data': switch (kind) {
              'math' => <String, dynamic>{
                'group': 'sum',
                'heading': 'Sčítání',
                'beforeAnswer': '$i + 1 =',
                'afterAnswer': '',
                'answer': i + 1,
                'nextStep': <String, dynamic>{
                  'group': 'sum',
                  'heading': 'Zkouška',
                  'beforeAnswer': '${i + 1} − 1 =',
                  'afterAnswer': '',
                  'answer': i,
                },
              },
              'spelling' => <String, dynamic>{
                'sentence': 'Věta $i skončil_.',
                'letter': 'y',
                'reason': 'yes',
                'explanation': 'Vysvětlení.',
                'reasons': [
                  <String, dynamic>{'id': 'yes', 'text': 'Správně'},
                  <String, dynamic>{'id': 'no', 'text': 'Chybně'},
                ],
              },
              _ => <String, dynamic>{
                'english': 'word$i',
                'czech': 'slovo$i',
                'topic': 'Test',
                'page': 1,
                'alternatives': <String>[],
              },
            },
          },
        );
        TestSession session() => TestSession(
          progress: progress,
          kind: kind,
          grade: 7,
          subject: 'test',
          items: items,
        );
        var quiz = session();
        Future<Map<String, dynamic>> answer(
          Map<String, dynamic> task, {
          bool wrong = false,
        }) => quiz.answer({
          'id': newExerciseId(),
          'exerciseId': task['exerciseId'],
          'step': task['step'],
          'revision': task['revision'],
          'answer': switch (kind) {
            'math' => wrong ? -1 : task['problem']['answer'],
            'spelling' =>
              wrong
                  ? (task['step'] == 0 ? 'i' : 'no')
                  : task['problem'][task['step'] == 0 ? 'letter' : 'reason'],
            _ => wrong ? '' : task['problem']['english'],
          },
        });
        Future<void> solve() async {
          while ((await answer(await quiz.load()))['completed'] != true) {}
        }

        final first = await quiz.load();
        expect(await quiz.load(newRound: true), first);
        if (kind != 'vocabulary') {
          await answer(first);
          expect((await quiz.load())['step'], 1);
        }
        final wrong = await answer(await quiz.load(), wrong: true);
        expect(wrong['progress']['total'], 16);
        expect(wrong['progress']['completed'], 0);
        final next = await quiz.load();
        progress.dispose();
        progress = controller();
        quiz = session();
        expect(await quiz.load(newRound: true), next);
        for (var i = 0; i < 3; i++) {
          expect((await quiz.load())['itemId'], isNot(first['itemId']));
          await solve();
        }
        final repeat = await quiz.load();
        expect(repeat['exerciseId'], first['exerciseId']);
        expect(repeat['problem'], first['problem']);
        expect(repeat['step'], 0);
        expect(repeat['revision'], 1);
        await expectLater(answer(first), throwsA(isA<MathExerciseChanged>()));
        expect((await answer(repeat, wrong: true))['progress']['total'], 17);
        for (var i = 0; i < 3; i++) {
          await solve();
        }
        expect((await quiz.load())['exerciseId'], first['exerciseId']);
        while ((await quiz.load())['progress']['finished'] != true) {
          await solve();
        }
        final done = await quiz.load();
        expect(done['progress'], {
          'total': 17,
          'completed': 17,
          'mistakes': 2,
          'started': true,
          'finished': true,
        });
        progress.dispose();
        progress = controller();
        quiz = session();
        expect(await quiz.load(), done);
        expect((await quiz.load(newRound: true))['progress']['total'], 15);
        expect((await quiz.load())['progress']['mistakes'], 0);
        progress.dispose();
      },
    );
  }

  test(
    'a mistake on the last vocabulary card adds a separate exercise before the retry',
    () async {
      final quiz = TestSession(
        progress: null,
        kind: 'vocabulary',
        grade: 5,
        subject: 'english',
        items: [
          {
            'id': 'one',
            'data': <String, dynamic>{
              'english': 'one',
              'czech': 'jedna',
              'topic': 'Čísla',
              'page': 1,
              'alternatives': <String>[],
            },
          },
        ],
      );
      final first = await quiz.load();
      Future<void> answer(Map<String, dynamic> task, String value) async =>
          quiz.answer({
            'id': newExerciseId(),
            'exerciseId': task['exerciseId'],
            'step': 0,
            'revision': task['revision'],
            'answer': value,
          });
      await answer(first, '');
      final extra = await quiz.load();
      expect(extra['progress']['total'], 2);
      expect(extra['exerciseId'], isNot(first['exerciseId']));
      await answer(extra, 'ONE!');
      final retry = await quiz.load();
      expect(retry['exerciseId'], first['exerciseId']);
      await answer(retry, 'one');
      expect((await quiz.load())['progress']['completed'], 2);
      expect((await quiz.load())['progress']['finished'], true);
    },
  );

  test(
    'legacy guest snapshot is adopted and a storage failure cannot silently advance it',
    () async {
      final problem = <String, dynamic>{
        'group': 'sum',
        'heading': 'Součet',
        'beforeAnswer': '2 + 2 =',
        'afterAnswer': '',
        'answer': 4,
      };
      var raw = jsonEncode({
        'exerciseId': 'old',
        'step': 1,
        'problem': problem,
      });
      var fail = false;
      final progress = ProgressController(
        enabled: false,
        readPractice: (_) => raw,
        writePractice: (_, value) {
          if (fail) throw StateError('Storage unavailable');
          raw = value!;
        },
      );
      final quiz = TestSession(
        progress: progress,
        kind: 'math',
        grade: 3,
        subject: 'math',
        items: [
          {'id': 'sum', 'data': problem},
        ],
      );
      final first = await quiz.load();
      expect(first['exerciseId'], 'old');
      expect(first['problem'], problem);
      fail = true;
      await expectLater(
        quiz.answer({
          'id': newExerciseId(),
          'exerciseId': 'old',
          'step': 0,
          'revision': 0,
          'answer': 4,
        }),
        throwsStateError,
      );
      expect(await quiz.load(), first);
      progress.dispose();
    },
  );
}
