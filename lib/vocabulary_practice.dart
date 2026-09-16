import 'dart:math';

import 'vocabulary.dart';

class VocabularyDeck {
  VocabularyDeck({List<VocabularyEntry>? entries, Random? random})
    : _entries = entries ?? vocabulary,
      _random = random ?? Random();

  final List<VocabularyEntry> _entries;
  final Random _random;
  final List<VocabularyEntry> _remaining = [];

  List<VocabularyEntry> nextRound() {
    if (_remaining.isEmpty) {
      _remaining.addAll(_entries);
      _remaining.shuffle(_random);
    }
    final count = min(8, _remaining.length);
    final round = _remaining.take(count).toList();
    _remaining.removeRange(0, count);
    return round;
  }
}

class VocabularyQuiz {
  VocabularyQuiz(List<VocabularyEntry> words)
    : _pending = [...words],
      total = words.length;

  final List<VocabularyEntry> _pending;
  final Set<VocabularyEntry> _missed = {};
  final int total;
  int completed = 0;
  int firstTryCorrect = 0;
  bool? correct;

  bool get isFinished => _pending.isEmpty;
  VocabularyEntry get current => _pending.first;
  bool get isRetry => _missed.contains(current);

  void check(String answer) {
    if (isFinished || correct != null) return;
    correct = current.accepts(answer);
    if (correct!) {
      completed++;
      if (!_missed.contains(current)) firstTryCorrect++;
    } else {
      _missed.add(current);
    }
  }

  void next() {
    if (isFinished || correct == null) return;
    final word = _pending.removeAt(0);
    if (!correct!) _pending.add(word);
    correct = null;
  }
}
