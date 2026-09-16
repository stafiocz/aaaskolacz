import 'dart:math';

enum PracticeMode {
  multiplication('Násobilka', 'MALÁ NÁSOBILKA', '1–9'),
  division('Dělení', 'DĚLENÍ BEZE ZBYTKU', 'do 90'),
  brackets('Závorky', 'SČÍTÁNÍ A ODČÍTÁNÍ', 'do 100'),
  missingFactor('Doplň násobení', 'DOPLŇ NÁSOBENÍ', '0–10'),
  missingDivisor('Doplň dělení', 'DOPLŇ DĚLENÍ', '1–9');

  const PracticeMode(this.label, this.heading, this.range);

  final String label;
  final String heading;
  final String range;

  bool get hasMissingNumber => this == missingFactor || this == missingDivisor;
}

class MathProblem {
  const MathProblem(this.beforeAnswer, this.afterAnswer, this.answer);

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
        return MathProblem('$left × $right =', '', left * right);
      case PracticeMode.division:
        final divisor = random.nextInt(9) + 1;
        final quotient = random.nextInt(11);
        return MathProblem('${divisor * quotient} : $divisor =', '', quotient);
      case PracticeMode.missingFactor:
        final factor = random.nextInt(9) + 1;
        final missing = random.nextInt(11);
        return MathProblem('$factor ×', '= ${factor * missing}', missing);
      case PracticeMode.missingDivisor:
        final divisor = random.nextInt(9) + 1;
        final quotient = random.nextInt(10) + 1;
        return MathProblem('${divisor * quotient} :', '= $quotient', divisor);
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
          '$outside $outerSign ($left $innerSign $right) =',
          '',
          answer,
        );
    }
  }
}
