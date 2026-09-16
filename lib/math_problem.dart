import 'dart:math';

enum PracticeMode {
  multiplication('MALÁ NÁSOBILKA'),
  division('DĚLENÍ BEZE ZBYTKU'),
  brackets('SČÍTÁNÍ A ODČÍTÁNÍ'),
  missingFactor('DOPLŇ NÁSOBENÍ'),
  missingDivisor('DOPLŇ DĚLENÍ'),
  largeAddition('SČÍTÁNÍ VELKÝCH ČÍSEL'),
  largeSubtraction('ODČÍTÁNÍ VELKÝCH ČÍSEL'),
  extendedMultiplication('NÁSOBENÍ JEDNOCIFERNÝM ČÍSLEM'),
  extendedDivision('DĚLENÍ JEDNOCIFERNÝM ČÍSLEM'),
  powersOfTen('NÁSOBENÍ A DĚLENÍ 10, 100, 1 000'),
  multiples('NÁSOBENÍ A DĚLENÍ NÁSOBKY'),
  missingNumber('DOPLŇ CHYBĚJÍCÍ ČÍSLO'),
  numberChain('POČETNÍ ŘETĚZEC');

  const PracticeMode(this.heading);

  final String heading;

  bool get hasMissingNumber => this == missingFactor || this == missingDivisor;
}

const grade3Modes = [
  PracticeMode.multiplication,
  PracticeMode.division,
  PracticeMode.brackets,
  PracticeMode.missingFactor,
  PracticeMode.missingDivisor,
];

const grade5Modes = [
  PracticeMode.largeAddition,
  PracticeMode.largeSubtraction,
  PracticeMode.extendedMultiplication,
  PracticeMode.extendedDivision,
  PracticeMode.powersOfTen,
  PracticeMode.multiples,
  PracticeMode.missingNumber,
  PracticeMode.numberChain,
];

String formatMathNumber(int number) => number.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]}\u00a0',
);

class MixedPractice {
  MixedPractice({this.grade = 3, Random? random})
    : assert(grade == 3 || grade == 5),
      _random = random ?? Random();

  final int grade;
  final Random _random;
  final List<PracticeMode> _remaining = [];
  MathProblem? _previous;

  MathProblem next() {
    if (_remaining.isEmpty) {
      _remaining.addAll(grade == 5 ? grade5Modes : grade3Modes);
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
    this.answer, {
    this.instruction,
    this.verification,
    this.nextStep,
  });

  final PracticeMode mode;
  final String beforeAnswer;
  final String afterAnswer;
  final int answer;
  final String? instruction;
  final String? verification;
  final MathProblem? nextStep;

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
      case PracticeMode.largeAddition:
      case PracticeMode.largeSubtraction:
        final (scale, limit) = [
          (100, 9000),
          (10000, 100),
          (100000, 90),
          (1000, 9000),
        ][random.nextInt(4)];
        final left = (random.nextInt(limit - 1) + 1) * scale;
        final add = mode == PracticeMode.largeAddition;
        final right =
            (random.nextInt(add ? limit - left ~/ scale : left ~/ scale) + 1) *
            scale;
        final answer = add ? left + right : left - right;
        return MathProblem(
          mode,
          '${formatMathNumber(left)} ${add ? '+' : '−'} ${formatMathNumber(right)} =',
          '',
          answer,
          verification:
              '${formatMathNumber(answer)} ${add ? '−' : '+'} ${formatMathNumber(right)} = ${formatMathNumber(left)}',
        );
      case PracticeMode.extendedMultiplication:
        final left = random.nextBool()
            ? random.nextInt(99) + 1
            : (random.nextInt(120) + 1) * 10;
        return _product(mode, left, random.nextInt(8) + 2);
      case PracticeMode.extendedDivision:
        return _product(
          mode,
          random.nextInt(99) + 1,
          random.nextInt(8) + 2,
          divide: true,
        );
      case PracticeMode.powersOfTen:
        final power = [10, 100, 1000][random.nextInt(3)];
        final scale = [1, 10, 100][random.nextInt(3)];
        final left =
            (random.nextInt(min(900, 9000000 ~/ power ~/ scale)) + 1) * scale;
        return _product(
          mode,
          left,
          power,
          divide: random.nextBool(),
          missing: random.nextBool() ? 2 : random.nextInt(2),
        );
      case PracticeMode.multiples:
      case PracticeMode.missingNumber:
        const scales = [
          (1, 100),
          (1, 1000),
          (1, 10000),
          (10, 10),
          (10, 100),
          (100, 1),
          (100, 10),
          (100, 100),
          (1000, 10),
          (10, 1000),
          (1000, 100),
          (10, 10000),
        ];
        final (leftScale, rightScale) = scales[random.nextInt(scales.length)];
        final small = mode == PracticeMode.missingNumber && random.nextBool();
        final left = small
            ? random.nextInt(99) + 1
            : (random.nextInt(9) + 1) * leftScale;
        final right = (random.nextInt(9) + 1) * (small ? 1 : rightScale);
        final divide = random.nextBool();
        return _product(
          mode,
          left,
          right,
          divide: divide,
          missing: mode == PracticeMode.multiples
              ? 2
              : random.nextInt(divide ? 3 : 2),
        );
      case PracticeMode.numberChain:
        final start = (random.nextInt(9000) + 1) * 100;
        final middle = (random.nextInt(9000) + 1) * 100;
        final end = (random.nextInt(9000) + 1) * 100;
        return MathProblem(
          mode,
          '${formatMathNumber(start)} ${start <= middle ? '+' : '−'}',
          '= ${formatMathNumber(middle)}',
          (middle - start).abs(),
          instruction:
              'Krok 1 ze 2 · Doplň číslo, kterým dojdeš k ${formatMathNumber(middle)}.',
          nextStep: MathProblem(
            mode,
            '${formatMathNumber(middle)} ${middle <= end ? '+' : '−'}',
            '= ${formatMathNumber(end)}',
            (end - middle).abs(),
            instruction:
                'Krok 2 ze 2 · Navaž na výsledek ${formatMathNumber(middle)} a dokonči řetězec.',
          ),
        );
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

  static MathProblem _product(
    PracticeMode mode,
    int left,
    int right, {
    bool divide = false,
    int missing = 2,
  }) {
    final values = [
      divide ? left * right : left,
      right,
      divide ? left : left * right,
    ];
    final tokens = [
      formatMathNumber(values[0]),
      divide ? ':' : '×',
      formatMathNumber(values[1]),
      '=',
      formatMathNumber(values[2]),
    ];
    final label = divide
        ? ['dělence', 'dělitele', 'podíl'][missing]
        : missing == 2
        ? 'součin'
        : 'chybějícího činitele';
    return MathProblem(
      mode,
      tokens.take(missing * 2).join(' '),
      tokens.skip(missing * 2 + 1).join(' '),
      values[missing],
      instruction: 'Doplň $label a potvrď ho.',
    );
  }
}
