import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaaskola/main.dart';

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
  final factors = RegExp(r'\d+')
      .allMatches(textAt(tester, 'problem'))
      .map((match) => int.parse(match.group(0)!))
      .toList();
  expect(factors, hasLength(2));
  expect(factors.every((value) => value >= 1 && value <= 9), isTrue);
  return factors[0] * factors[1];
}

Future<void> answerCorrectly(WidgetTester tester) async {
  for (final digit in result(tester).toString().split('')) {
    await key(tester, digit);
  }
  await submit(tester);
}

void main() {
  testWidgets(
    'screen keypad edits a two-digit answer and rejects empty input',
    (tester) async {
      await tester.pumpWidget(const AaaSkolaApp());
      expect(
        tester
            .widget<FilledButton>(find.byKey(const ValueKey('submit')))
            .onPressed,
        isNull,
      );
      expect(find.byType(TextField), findsNothing);
      await key(tester, '0');
      await key(tester, '4');
      expect(textAt(tester, 'answer'), '4');
      await key(tester, '2');
      await key(tester, '7');
      expect(textAt(tester, 'answer'), '42');
      await key(tester, '⌫');
      expect(textAt(tester, 'answer'), '4');
      await key(tester, 'C');
      await key(tester, '⌫');
      expect(textAt(tester, 'answer'), '?');
    },
  );

  testWidgets(
    'incorrect answer can be replaced, success unlocks next problem',
    (tester) async {
      await tester.pumpWidget(const AaaSkolaApp());
      final original = textAt(tester, 'problem');
      await key(tester, '0');
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
    'a full practice session keeps factors in range and scores once',
    (tester) async {
      await tester.pumpWidget(const AaaSkolaApp());
      for (var count = 1; count <= 25; count++) {
        final original = textAt(tester, 'problem');
        await answerCorrectly(tester);
        expect(textAt(tester, 'score'), 'Správně: $count');
        await submit(tester);
        expect(textAt(tester, 'problem'), isNot(original));
        expect(textAt(tester, 'answer'), '?');
      }
    },
  );

  testWidgets('physical keyboard supports digits, erase, and checking', (
    tester,
  ) async {
    await tester.pumpWidget(const AaaSkolaApp());
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.digit4, character: '4');
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2, character: '2');
    await tester.pump();
    expect(textAt(tester, 'answer'), '42');
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pump();
    expect(textAt(tester, 'answer'), '4');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit0, character: '0');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('To ještě není ono. Zkus to znovu.'), findsOneWidget);
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
      await tester.pumpWidget(const AaaSkolaApp());
      await answerCorrectly(tester);
      expect(find.text('Výborně! To je správně.'), findsOneWidget);
      await submit(tester);
      expect(tester.takeException(), isNull);
    });
  }
}
