import 'dart:math';

import 'package:aaaskola/math_problem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mix covers every type in each round without adjacent repeats', () {
    for (var seed = 0; seed < 20; seed++) {
      final practice = MixedPractice(random: Random(seed));
      MathProblem? previous;
      for (var round = 0; round < 20; round++) {
        final modes = <PracticeMode>{};
        for (var index = 0; index < grade3Modes.length; index++) {
          final problem = practice.next();
          expect(problem.mode, isNot(previous?.mode));
          expect(problem.question, isNot(previous?.question));
          modes.add(problem.mode);
          previous = problem;
        }
        expect(modes, unorderedEquals(grade3Modes));
      }
    }
  });

  for (final mode in grade3Modes) {
    test('${mode.name}: generated equations are valid and do not repeat', () {
      final random = Random(2026);
      MathProblem? previous;
      final answers = <int>{};
      final signs = <String>{};
      for (var index = 0; index < 2000; index++) {
        final problem = MathProblem.next(mode, random, previous: previous);
        expect(problem.mode, mode);
        expect(problem.question, isNot(previous?.question));
        expect(problem.answer, inInclusiveRange(0, 100));
        answers.add(problem.answer);
        final equation = problem.question.replaceFirst(
          '?',
          '${problem.answer}',
        );
        final numbers = RegExp(
          r'\d+',
        ).allMatches(equation).map((match) => int.parse(match[0]!)).toList();

        switch (mode) {
          case PracticeMode.additionSubtraction:
            expect(numbers, everyElement(inInclusiveRange(0, 100)));
            expect(
              equation.contains('+')
                  ? numbers[0] + numbers[1]
                  : numbers[0] - numbers[1],
              numbers[2],
            );
          case PracticeMode.multiplication:
          case PracticeMode.missingFactor:
            expect(equation, matches(r'^\d+ × \d+ = \d+$'));
            expect(numbers[0], inInclusiveRange(1, 9));
            expect(
              numbers[1],
              mode == PracticeMode.multiplication
                  ? inInclusiveRange(1, 9)
                  : inInclusiveRange(0, 10),
            );
            expect(numbers[0] * numbers[1], numbers[2]);
          case PracticeMode.division:
          case PracticeMode.missingDivisor:
            expect(equation, matches(r'^\d+ : \d+ = \d+$'));
            expect(numbers[0], inInclusiveRange(0, 90));
            expect(numbers[1], inInclusiveRange(1, 9));
            expect(numbers[2], inInclusiveRange(0, 10));
            expect(numbers[0] % numbers[1], 0);
            expect(numbers[0] / numbers[1], numbers[2]);
            if (mode == PracticeMode.missingDivisor) {
              expect(numbers[0], greaterThan(0));
              expect(numbers[2], greaterThan(0));
            }
          case PracticeMode.brackets:
            final match = RegExp(
              r'^(\d+) ([+−]) \((\d+) ([+−]) (\d+)\) = (\d+)$',
            ).firstMatch(equation);
            expect(match, isNotNull);
            signs.add('${match![2]}${match[4]}');
            final inside = match[4] == '+'
                ? numbers[1] + numbers[2]
                : numbers[1] - numbers[2];
            expect(inside, inInclusiveRange(0, 100));
            expect(numbers, everyElement(inInclusiveRange(0, 100)));
            expect(
              match[2] == '+' ? numbers[0] + inside : numbers[0] - inside,
              numbers[3],
            );
          default:
            fail('Unexpected mode for grade 3: $mode');
        }
        previous = problem;
      }
      if (mode == PracticeMode.division || mode == PracticeMode.missingFactor) {
        expect(answers, containsAll([0, 10]));
      }
      if (mode == PracticeMode.brackets) {
        expect(signs, containsAll(['++', '+−', '−+', '−−']));
        expect(answers, containsAll([0, 100]));
      }
    });
  }

  test('notebook examples all appear with recalculated answers', () {
    final random = Random(17);
    final questions = <String, int>{};
    for (var i = 0; i < 2000; i++) {
      final problem = MathProblem.next(
        PracticeMode.additionSubtraction,
        random,
      );
      questions[problem.question] = problem.answer;
    }
    expect(questions.length, 24);
    expect(questions['72 − 30 = ?'], 42);
    expect(questions['17 − 12 = ?'], 5);
    expect(questions['100 − 36 = ?'], 64);
    expect(questions['84 − 60 = ?'], 24);
    expect(questions['86 − 24 = ?'], 62);
    expect(questions['72 − 19 = ?'], 53);
  });
}
