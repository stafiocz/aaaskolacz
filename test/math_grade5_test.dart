import 'dart:math';

import 'package:aaaskola/math_problem.dart';
import 'package:flutter_test/flutter_test.dart';

List<int> checkEquation(String equation) {
  final compact = equation.replaceAll(RegExp(r'\s'), '');
  final match = RegExp(r'^(\d+)([+−×:])(\d+)=(\d+)$').firstMatch(compact);
  expect(match, isNotNull, reason: equation);
  final left = int.parse(match![1]!);
  final right = int.parse(match[3]!);
  final result = int.parse(match[4]!);
  expect([left, right, result], everyElement(inInclusiveRange(0, 9000000)));
  switch (match[2]) {
    case '+':
      expect(left + right, result, reason: equation);
    case '−':
      expect(left - right, result, reason: equation);
    case '×':
      expect(left * right, result, reason: equation);
    case ':':
      expect(right, greaterThan(0));
      expect(left % right, 0);
      expect(left ~/ right, result, reason: equation);
  }
  return [left, right, result];
}

void main() {
  test('grade 5 mixes its eight types and keeps grade 3 separate', () {
    expect(grade3Modes.toSet().intersection(grade5Modes.toSet()), isEmpty);
    for (var seed = 0; seed < 20; seed++) {
      final practice = MixedPractice(grade: 5, random: Random(seed));
      MathProblem? previous;
      for (var round = 0; round < 10; round++) {
        final modes = <PracticeMode>{};
        for (var index = 0; index < grade5Modes.length; index++) {
          final problem = practice.next();
          expect(problem.mode, isNot(previous?.mode));
          modes.add(problem.mode);
          previous = problem;
        }
        expect(modes, unorderedEquals(grade5Modes));
      }
    }
  });

  for (final mode in grade5Modes) {
    test('${mode.name}: equations, unknowns and checks are valid', () {
      final random = Random(515);
      MathProblem? previous;
      final operations = <String>{};
      final missingPositions = <int>{};
      var hasMillions = false;
      var hasSmallQuotient = false;
      var hasSmallDivisor = false;
      for (var index = 0; index < 600; index++) {
        final problem = MathProblem.next(mode, random, previous: previous);
        expect(problem.question, isNot(previous?.question));
        expect(problem.answer, inInclusiveRange(0, 9000000));
        final values = checkEquation(
          problem.question.replaceFirst('?', '${problem.answer}'),
        );
        operations.add(RegExp(r'[+−×:]').firstMatch(problem.question)![0]!);
        missingPositions.add(
          problem.beforeAnswer.isEmpty
              ? 0
              : problem.afterAnswer.isEmpty
              ? 2
              : 1,
        );
        hasMillions |= values.any((value) => value >= 1000000);
        if (problem.question.contains(':')) {
          hasSmallQuotient |= values[2] < 10 && values[1] >= 100;
          hasSmallDivisor |= values[1] < 10 && values[2] >= 100;
        }
        if (mode == PracticeMode.largeAddition ||
            mode == PracticeMode.largeSubtraction) {
          expect(problem.verification, isNotNull);
          final check = checkEquation(problem.verification!);
          expect(check, [values[2], values[1], values[0]]);
        }
        if (mode == PracticeMode.extendedMultiplication) {
          expect(values[0], inInclusiveRange(1, 1200));
          expect(values[1], inInclusiveRange(2, 9));
        }
        if (mode == PracticeMode.extendedDivision) {
          expect(values[1], inInclusiveRange(2, 9));
          expect(values[2], inInclusiveRange(1, 99));
        }
        if (mode == PracticeMode.powersOfTen) {
          expect([10, 100, 1000], contains(values[1]));
        }
        if (problem.nextStep case final next?) {
          expect(mode, PracticeMode.numberChain);
          final continuation = checkEquation(
            next.question.replaceFirst('?', '${next.answer}'),
          );
          expect(continuation[0], values[2]);
          expect(next.nextStep, isNull);
          expect(problem.instruction, startsWith('Krok 1 ze 2'));
          expect(next.instruction, startsWith('Krok 2 ze 2'));
        } else {
          expect(mode, isNot(PracticeMode.numberChain));
        }
        previous = problem;
      }
      if ([
        PracticeMode.powersOfTen,
        PracticeMode.multiples,
        PracticeMode.missingNumber,
      ].contains(mode)) {
        expect(operations, containsAll(['×', ':']));
      }
      if (mode == PracticeMode.multiples ||
          mode == PracticeMode.missingNumber) {
        expect(hasSmallQuotient, isTrue);
        expect(hasSmallDivisor, isTrue);
      }
      if ([
        PracticeMode.powersOfTen,
        PracticeMode.missingNumber,
      ].contains(mode)) {
        expect(missingPositions, {0, 1, 2});
      }
      if ([
        PracticeMode.largeAddition,
        PracticeMode.largeSubtraction,
        PracticeMode.powersOfTen,
        PracticeMode.multiples,
      ].contains(mode)) {
        expect(hasMillions, isTrue);
      }
    });
  }

  test('millions are grouped without breaking individual numbers', () {
    expect(formatMathNumber(0), '0');
    expect(formatMathNumber(999), '999');
    expect(formatMathNumber(1500000), '1\u00a0500\u00a0000');
    expect(formatMathNumber(6231000), '6\u00a0231\u00a0000');
  });
}
