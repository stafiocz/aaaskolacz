import 'dart:math';

enum PracticeMode {
  multiplication('MALÁ NÁSOBILKA'),
  division('DĚLENÍ BEZE ZBYTKU'),
  brackets('SČÍTÁNÍ A ODČÍTÁNÍ'),
  missingFactor('DOPLŇ NÁSOBENÍ'),
  missingDivisor('DOPLŇ DĚLENÍ');

  const PracticeMode(this.heading);

  final String heading;

  bool get hasMissingNumber => this == missingFactor || this == missingDivisor;
}

class MixedPractice {
  MixedPractice({Random? random}) : _random = random ?? Random();

  final Random _random;
  final List<PracticeMode> _remaining = [];
  MathProblem? _previous;

  MathProblem next() {
    if (_remaining.isEmpty) {
      _remaining.addAll(PracticeMode.values);
      _remaining.shuffle(_random);
      if (_remaining.last == _previous?.mode) {
        _remaining.insert(0, _remaining.removeLast());
      }
    }
    return _previous = MathProblem.next(
      _remaining.removeLast(),
      _random,
      previous: _previous,
    );
  }
}

class MathProblem {
  const MathProblem(
    this.mode,
    this.beforeAnswer,
    this.afterAnswer,
    this.answer,
  );

  final PracticeMode mode;
  final String beforeAnswer;
  final String afterAnswer;
  final int answer;

  String get question => '$beforeAnswer ? $afterAnswer'.trim();

  static MathProblem next(
    PracticeMode mode,
    Random random, {
    MathProblem? previous,
  }) {
    MathProblem problem;
    do {
      problem = _generate(mode, random);
    } while (problem.question == previous?.question);
    return problem;
  }

  static MathProblem _generate(PracticeMode mode, Random random) {
    switch (mode) {
      case PracticeMode.multiplication:
        final left = random.nextInt(9) + 1;
        final right = random.nextInt(9) + 1;
        return MathProblem(mode, '$left × $right =', '', left * right);
      case PracticeMode.division:
        final divisor = random.nextInt(9) + 1;
        final quotient = random.nextInt(11);
        return MathProblem(
          mode,
          '${divisor * quotient} : $divisor =',
          '',
          quotient,
        );
      case PracticeMode.missingFactor:
        final factor = random.nextInt(9) + 1;
        final missing = random.nextInt(11);
        return MathProblem(mode, '$factor ×', '= ${factor * missing}', missing);
      case PracticeMode.missingDivisor:
        final divisor = random.nextInt(9) + 1;
        final quotient = random.nextInt(10) + 1;
        return MathProblem(
          mode,
          '${divisor * quotient} :',
          '= $quotient',
          divisor,
        );
      case PracticeMode.brackets:
        final addInside = random.nextBool();
        final addOutside = random.nextBool();
        final left = random.nextInt(50) + 1;
        final right = random.nextInt(addInside ? 51 - left : left + 1);
        final inside = addInside ? left + right : left - right;
        final outside =
            random.nextInt(101 - inside) + (addOutside ? 0 : inside);
        final answer = addOutside ? outside + inside : outside - inside;
        final innerSign = addInside ? '+' : '−';
        final outerSign = addOutside ? '+' : '−';
        return MathProblem(
          mode,
          '$outside $outerSign ($left $innerSign $right) =',
          '',
          answer,
        );
    }
  }
}
