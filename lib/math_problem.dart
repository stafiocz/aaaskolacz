import 'dart:math';

String formatMathNumber(int number) => number.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
  (match) => '${match[1]}\u00a0',
);

class MathProblem {
  MathProblem.fromJson(Map<String, dynamic> data)
    : group = data['group'] as String,
      heading = data['heading'] as String,
      beforeAnswer = data['beforeAnswer'] as String,
      afterAnswer = data['afterAnswer'] as String,
      answer = data['answer'] as int,
      instruction = data['instruction'] as String?,
      verification = data['verification'] as String?,
      nextStep = data['nextStep'] == null
          ? null
          : MathProblem.fromJson(data['nextStep'] as Map<String, dynamic>);

  final String group;
  final String heading;
  final String beforeAnswer;
  final String afterAnswer;
  final int answer;
  final String? instruction;
  final String? verification;
  final MathProblem? nextStep;
  String get question => '$beforeAnswer ? $afterAnswer'.trim();
}

class MixedPractice {
  MixedPractice({required List<MathProblem> problems, Random? random})
    : _random = random ?? Random() {
    for (final problem in problems) {
      (_groups[problem.group] ??= []).add(problem);
    }
    if (_groups.isEmpty) throw ArgumentError('Procvičování nemá zadání.');
  }
  final Random _random;
  final Map<String, List<MathProblem>> _groups = {};
  final Map<String, List<MathProblem>> _decks = {};
  final List<String> _remaining = [];
  final Map<String, MathProblem> _previous = {};
  String? _lastGroup;

  MathProblem next() {
    if (_remaining.isEmpty) {
      _remaining.addAll(_groups.keys);
      _remaining.shuffle(_random);
      if (_remaining.length > 1 && _remaining.last == _lastGroup) {
        _remaining.insert(0, _remaining.removeLast());
      }
    }
    final group = _lastGroup = _remaining.removeLast();
    final deck = _decks[group] ??= [];
    if (deck.isEmpty) {
      deck.addAll(_groups[group]!);
      deck.shuffle(_random);
      if (deck.length > 1 && deck.last.question == _previous[group]?.question) {
        final other = deck.indexWhere((p) => p.question != deck.last.question);
        if (other >= 0) {
          final last = deck.last;
          deck[deck.length - 1] = deck[other];
          deck[other] = last;
        }
      }
    }
    return _previous[group] = deck.removeLast();
  }
}
