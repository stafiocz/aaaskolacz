import '../tool/vocabulary_seed.dart';

import 'package:aaaskola/vocabulary.dart';
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
}
