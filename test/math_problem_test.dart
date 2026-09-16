import 'dart:math';

import 'package:aaaskola/math_problem.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final mode in PracticeMode.values) {
    test('${mode.name}: generated equations are valid and do not repeat', () {
      final random = Random(2026);
      MathProblem? previous;
      final answers = <int>{};
      final signs = <String>{};
      for (var index = 0; index < 2000; index++) {
        final problem = MathProblem.next(mode, random, previous: previous);
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
}
