import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaaskola/main.dart';
import 'package:aaaskola/math_problem.dart';

Future<void> openMath(WidgetTester tester) async {
  await tester.pumpWidget(const AaaSkolaApp());
  await tester.ensureVisible(find.text('3. třída'));
  await tester.tap(find.text('3. třída'));
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.text('Matematika'));
  await tester.tap(find.text('Matematika'));
  await tester.pumpAndSettle();
}

String textAt(WidgetTester tester, String key) =>
    tester.widget<Text>(find.byKey(ValueKey(key))).data!;

Future<void> key(WidgetTester tester, String digit) async {
  final button = find.byKey(ValueKey('key-$digit'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pump();
}

Future<void> submit(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('submit'));
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

int result(WidgetTester tester) {
  final question = textAt(tester, 'problem');
  final factors = RegExp(
    r'\d+',
  ).allMatches(question).map((match) => int.parse(match.group(0)!)).toList();
  if (find.byKey(const ValueKey('problem-suffix')).evaluate().isNotEmpty) {
    final value = int.parse(textAt(tester, 'problem-suffix').substring(2));
    return question.contains('×') ? value ~/ factors[0] : factors[0] ~/ value;
  }
  if (question.contains('(')) {
    final signs = RegExp(
      r'[+−]',
    ).allMatches(question).map((m) => m[0]).toList();
    final inner = signs[1] == '+'
        ? factors[1] + factors[2]
        : factors[1] - factors[2];
    return signs[0] == '+' ? factors[0] + inner : factors[0] - inner;
  }
  return question.contains('×')
      ? factors[0] * factors[1]
      : factors[0] ~/ factors[1];
}

PracticeMode modeAt(WidgetTester tester) => PracticeMode.values.singleWhere(
  (mode) => find.text(mode.heading).evaluate().isNotEmpty,
);

Future<void> answerCorrectly(WidgetTester tester) async {
  for (final digit in result(tester).toString().split('')) {
    await key(tester, digit);
  }
  await submit(tester);
}

void main() {
  testWidgets(
    'screen keypad edits a three-digit answer and rejects empty input',
    (tester) async {
      await openMath(tester);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('submit')))
            .onPressed,
        isNull,
      );
      expect(find.byType(TextField), findsNothing);
      expect(find.byKey(const ValueKey('practice-mode')), findsNothing);
      expect(find.text('MIX'), findsOneWidget);
      await key(tester, '0');
      await key(tester, '4');
      expect(textAt(tester, 'answer'), '4');
      await key(tester, '2');
      await key(tester, '7');
      await key(tester, '9');
      expect(textAt(tester, 'answer'), '427');
      await key(tester, '⌫');
      expect(textAt(tester, 'answer'), '42');
      await key(tester, 'C');
      await key(tester, '⌫');
      expect(textAt(tester, 'answer'), '?');
    },
  );

  testWidgets(
    'incorrect answer can be replaced, success unlocks next problem',
    (tester) async {
      await openMath(tester);
      final original = textAt(tester, 'problem');
      await key(tester, result(tester) == 0 ? '1' : '0');
      await submit(tester);
      expect(find.text('To ještě není ono. Zkus to znovu.'), findsOneWidget);
      expect(textAt(tester, 'problem'), original);
      expect(textAt(tester, 'score'), contains('0'));

      await answerCorrectly(tester);
      expect(find.text('Výborně! To je správně.'), findsOneWidget);
      expect(textAt(tester, 'score'), contains('1'));
      expect(find.text('Další příklad'), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(find.byKey(const ValueKey('key-1')))
            .onPressed,
        isNull,
      );

      await submit(tester);
      expect(textAt(tester, 'problem'), isNot(original));
      expect(textAt(tester, 'answer'), '?');
      expect(textAt(tester, 'score'), contains('1'));
    },
  );

  testWidgets(
    'a full mixed practice session covers all types and scores once',
    (tester) async {
      await openMath(tester);
      final modes = <PracticeMode>{};
      for (var count = 1; count <= 25; count++) {
        final original = textAt(tester, 'problem');
        modes.add(modeAt(tester));
        await answerCorrectly(tester);
        expect(textAt(tester, 'score'), 'Správně: $count');
        await submit(tester);
        expect(textAt(tester, 'problem'), isNot(original));
        expect(textAt(tester, 'answer'), '?');
        if (count % 5 == 0) {
          expect(modes, unorderedEquals(PracticeMode.values));
          modes.clear();
        }
      }
    },
  );

  testWidgets('physical keyboard supports digits, erase, and checking', (
    tester,
  ) async {
    await openMath(tester);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4, character: '4');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
    await tester.pump();
    expect(textAt(tester, 'answer'), '42');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(textAt(tester, 'answer'), '4');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    final wrongAnswer = result(tester) == 0 ? '1' : '0';
    await tester.sendKeyEvent(
      wrongAnswer == '1'
          ? LogicalKeyboardKey.digit1
          : LogicalKeyboardKey.digit0,
      character: wrongAnswer,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('To ještě není ono. Zkus to znovu.'), findsOneWidget);
  });

  testWidgets('mixed problems check answers and reset feedback automatically', (
    tester,
  ) async {
    await openMath(tester);
    var count = 0;
    for (var index = 0; index < 10; index++) {
      final mode = modeAt(tester);
      expect(textAt(tester, 'answer'), '?');
      expect(find.text('Výborně! To je správně.'), findsNothing);
      expect(find.text(mode.heading), findsOneWidget);
      final original = textAt(tester, 'problem');
      final suffix = mode.hasMissingNumber
          ? textAt(tester, 'problem-suffix')
          : '';
      await key(tester, result(tester) == 0 ? '1' : '0');
      await submit(tester);
      expect(find.text('To ještě není ono. Zkus to znovu.'), findsOneWidget);
      expect(textAt(tester, 'problem'), original);
      await answerCorrectly(tester);
      expect(find.text('Výborně! To je správně.'), findsOneWidget);
      expect(textAt(tester, 'score'), 'Správně: ${++count}');
      await submit(tester);
      final newSuffix = modeAt(tester).hasMissingNumber
          ? textAt(tester, 'problem-suffix')
          : '';
      expect(
        '${textAt(tester, 'problem')}$newSuffix',
        isNot('$original$suffix'),
      );
      expect(modeAt(tester), isNot(mode));
    }
  });

  testWidgets('mixed practice accepts answers up to three digits', (
    tester,
  ) async {
    await openMath(tester);
    for (final digit in ['1', '0', '0', '9']) {
      await key(tester, digit);
    }
    expect(textAt(tester, 'answer'), '100');
    await key(tester, 'C');
    expect(textAt(tester, 'answer'), '?');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit7, character: '7');
    await tester.pump();
    expect(textAt(tester, 'answer'), '7');
  });

  for (final size in [
    const Size(320, 568),
    const Size(390, 844),
    const Size(844, 390),
  ]) {
    testWidgets('practice works without overflow at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await openMath(tester);
      for (var index = 0; index < PracticeMode.values.length; index++) {
        await answerCorrectly(tester);
        expect(find.text('Výborně! To je správně.'), findsOneWidget);
        await submit(tester);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
