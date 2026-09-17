import 'package:aaaskola/main.dart';
import 'package:aaaskola/math_problem.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'practice_test.dart' show key, submit, textAt;

Future<void> openGrade5(WidgetTester tester) async {
  await tester.pumpWidget(const AaaSkolaApp());
  for (final text in ['5. třída', 'Matematika']) {
    await tester.ensureVisible(find.text(text));
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }
}

int solve(String question) {
  final match = RegExp(
    r'^(\d+|\?)([+−×:])(\d+|\?)=(\d+|\?)$',
  ).firstMatch(question.replaceAll(RegExp(r'\s'), ''))!;
  final a = int.tryParse(match[1]!);
  final b = int.tryParse(match[3]!);
  final c = int.tryParse(match[4]!);
  return switch (match[2]) {
    '+' =>
      a == null
          ? c! - b!
          : b == null
          ? c! - a
          : a + b,
    '−' =>
      a == null
          ? c! + b!
          : b == null
          ? a - c!
          : a - b,
    '×' =>
      a == null
          ? c! ~/ b!
          : b == null
          ? c! ~/ a
          : a * b,
    ':' =>
      a == null
          ? c! * b!
          : b == null
          ? a ~/ c!
          : a ~/ b,
    _ => throw StateError('Unknown operation'),
  };
}

Future<void> answerCorrectly(WidgetTester tester) async {
  for (final digit in solve(textAt(tester, 'problem')).toString().split('')) {
    await key(tester, digit);
  }
  await submit(tester);
  expect(find.text('Výborně! To je správně.'), findsOneWidget);
}

void main() {
  testWidgets('grade 5 mathematics returns to its subjects', (tester) async {
    await openGrade5(tester);
    expect(find.text('Matematika · 5. třída'), findsOneWidget);
    await tester.tap(find.text('Matematika · 5. třída'));
    await tester.pumpAndSettle();
    expect(find.text('5. třída'), findsOneWidget);
    expect(find.text('Matematika'), findsOneWidget);
    expect(find.text('Angličtina'), findsOneWidget);
  });

  testWidgets(
    'seven digits, grouping, erasing and incorrect replacement work',
    (tester) async {
      await openGrade5(tester);
      for (final digit in '12345678'.split('')) {
        await key(tester, digit);
      }
      expect(textAt(tester, 'answer'), '1\u00a0234\u00a0567');
      await key(tester, '⌫');
      expect(textAt(tester, 'answer'), '123\u00a0456');
      await key(tester, 'C');
      await key(tester, '0');
      await key(tester, '5');
      expect(textAt(tester, 'answer'), '5');
      await key(tester, 'C');
      for (final digit in '9999999'.split('')) {
        await tester.sendKeyEvent(LogicalKeyboardKey.digit9, character: digit);
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('To ještě není ono. Zkus to znovu.'), findsOneWidget);
      await answerCorrectly(tester);
      final correct = textAt(tester, 'answer');
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(textAt(tester, 'answer'), correct);
    },
  );

  testWidgets(
    'mix includes two-step chains, counts once and shows inverse checks',
    (tester) async {
      await openGrade5(tester);
      final modes = <PracticeMode>{};
      for (var index = 0; index < grade5Modes.length; index++) {
        final mode = grade5Modes.singleWhere(
          (m) => find.text(m.heading).evaluate().isNotEmpty,
        );
        expect(modes.add(mode), isTrue);
        await answerCorrectly(tester);
        if (mode == PracticeMode.numberChain) {
          expect(textAt(tester, 'score'), 'Správně: $index');
          expect(find.text('Další krok'), findsOneWidget);
          final middle = textAt(tester, 'problem').split('= ').last;
          await submit(tester);
          expect(textAt(tester, 'problem'), startsWith(middle));
          expect(find.textContaining('Krok 2 ze 2'), findsOneWidget);
          expect(textAt(tester, 'answer'), '?');
          await key(tester, solve(textAt(tester, 'problem')) == 0 ? '1' : '0');
          await submit(tester);
          expect(textAt(tester, 'score'), 'Správně: $index');
          expect(find.text('Další příklad'), findsNothing);
          await answerCorrectly(tester);
        }
        if (mode == PracticeMode.largeAddition ||
            mode == PracticeMode.largeSubtraction) {
          expect(find.byKey(const ValueKey('verification')), findsOneWidget);
        }
        expect(textAt(tester, 'score'), 'Správně: ${index + 1}');
        expect(find.text('Další příklad'), findsOneWidget);
        await submit(tester);
        expect(find.byKey(const ValueKey('verification')), findsNothing);
        expect(textAt(tester, 'answer'), '?');
      }
      expect(modes, unorderedEquals(grade5Modes));
    },
  );

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('grade 5 equations and million-sized input fit $size', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openGrade5(tester);
      for (var index = 0; index < 9; index++) {
        for (final digit in '9999999'.split('')) {
          await key(tester, digit);
        }
        await key(tester, 'C');
        await answerCorrectly(tester);
        await submit(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
