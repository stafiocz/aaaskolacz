import '../tool/vocabulary_seed.dart';
import 'dart:math';

import 'package:aaaskola/vocabulary.dart';
import 'package:aaaskola/vocabulary_practice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all photographed pages and vocabulary groups are represented', () {
    expect(vocabulary.map((e) => e.page).toSet(), {4, 5, 6, 7});
    expect(vocabulary.map((e) => e.english).toSet().length, vocabulary.length);
    expect(vocabulary.where((e) => e.topic == 'Měsíce').length, 12);
    for (final entry in vocabulary) {
      expect(entry.czech.trim(), isNotEmpty);
      expect(entry.accepts(entry.english), isTrue);
      expect(entry.accepts(''), isFalse);
      for (final answer in entry.alternatives) {
        expect(entry.accepts(answer), isTrue);
      }
    }
    expect(
      vocabulary.map((e) => e.english),
      containsAll([
        'prize',
        'twenty-second',
        'Swiss',
        'Slovenian',
        'Slovak',
        'playground',
        'staffroom',
        'science lab',
        "Head's office",
        'usually',
        'never',
      ]),
    );
  });

  test(
    'answers accept case, spacing, punctuation and explicit alternatives',
    () {
      VocabularyEntry entry(String english) =>
          vocabulary.singleWhere((e) => e.english == english);
      expect(entry('January').accepts('  JANUARY!  '), isTrue);
      expect(entry('twenty-second').accepts('twenty  second'), isTrue);
      expect(entry("What's your name?").accepts('What’s your name'), isTrue);
      expect(entry("What's your name?").accepts('What is your name?'), isTrue);
      expect(entry('favourite').accepts('favorite'), isTrue);
      expect(entry('library').accepts('libary'), isFalse);
      expect(entry('first').accepts('1st'), isFalse);
      expect(entry('Slovenian').accepts('Slovak'), isFalse);
    },
  );

  test(
    'rounds cover the whole deck before repeating, including its last part',
    () {
      final deck = VocabularyDeck(entries: vocabulary, random: Random(19));
      final seen = <VocabularyEntry>[];
      while (seen.length < vocabulary.length) {
        final round = deck.nextRound();
        expect(round.length, inInclusiveRange(1, 15));
        expect(round.toSet().intersection(seen.toSet()), isEmpty);
        seen.addAll(round);
      }
      expect(seen, unorderedEquals(vocabulary));
      expect(deck.nextRound(), hasLength(15));
    },
  );

  test(
    'wrong and revealed answers return after other words, score counts once',
    () {
      final words = vocabulary.take(3).toList();
      final quiz = VocabularyQuiz(words);
      quiz.next();
      expect(quiz.current, words[0]);
      quiz.check('incorrect');
      quiz.check(words[0].english);
      expect(quiz.correct, isFalse);
      quiz.next();
      expect(quiz.current, words[1]);
      quiz.check('');
      quiz.next();
      expect(quiz.current, words[2]);
      quiz.check(words[2].english);
      quiz.check(words[2].english);
      expect(quiz.completed, 1);
      expect(quiz.firstTryCorrect, 1);
      quiz.next();
      expect(quiz.current, words[0]);
      expect(quiz.isRetry, isTrue);
      quiz.check(words[0].english);
      quiz.next();
      expect(quiz.current, words[1]);
      quiz.check(words[1].english);
      quiz.next();
      expect(quiz.isFinished, isTrue);
      expect(quiz.completed, 3);
      expect(quiz.firstTryCorrect, 1);
    },
  );
}
