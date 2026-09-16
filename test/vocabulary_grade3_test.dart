import 'dart:math';

import 'package:aaaskola/vocabulary.dart';
import 'package:aaaskola/vocabulary_grade3.dart';
import 'package:aaaskola/vocabulary_practice.dart';
import 'package:flutter_test/flutter_test.dart';

VocabularyEntry entry(String english) =>
    vocabularyGrade3.singleWhere((word) => word.english == english);

void main() {
  test('grade 3 covers all supplied pages with unique words and prompts', () {
    expect(vocabularyGrade3.map((e) => e.page).toSet(), {
      for (var page = 4; page <= 21; page++) page,
    });
    expect(
      vocabularyGrade3.map((e) => normalizeAnswer(e.english)).toSet(),
      hasLength(vocabularyGrade3.length),
    );
    expect(
      vocabularyGrade3.map((e) => e.czech).toSet(),
      hasLength(vocabularyGrade3.length),
    );
    for (final word in vocabularyGrade3) {
      expect(word.czech.trim(), isNotEmpty);
      expect(word.topic.trim(), isNotEmpty);
      expect(word.accepts(word.english), isTrue);
      expect(word.accepts(''), isFalse);
      for (final alternative in word.alternatives) {
        expect(word.accepts(alternative), isTrue);
      }
    }
  });

  test('photographed vocabulary tables and final chapters are included', () {
    final groups = <int, List<String>>{
      4: [
        'pencil',
        'rubber',
        'ruler',
        'sharpener',
        'pen',
        'crayon',
        'notebook',
        'book',
        'scissors',
        'calculator',
        'pencil case',
        'school bag',
      ],
      5: [
        'red',
        'orange',
        'yellow',
        'light green',
        'dark green',
        'light blue',
        'dark blue',
        'purple',
        'black',
        'white',
        'grey',
        'brown',
        'pink',
      ],
      6: [
        'one',
        'two',
        'three',
        'four',
        'five',
        'six',
        'seven',
        'eight',
        'nine',
        'ten',
        'eleven',
        'twelve',
        'thirteen',
        'fourteen',
        'fifteen',
        'sixteen',
        'seventeen',
        'eighteen',
        'nineteen',
        'twenty',
      ],
      7: [
        'England',
        'Scottish',
        'Ireland',
        'Welsh',
        'Hungary',
        'Croatian',
        'Serbia',
        'Slovenian',
        'the Czech Republic',
        'Chinese',
        'Spain',
        'Indian',
      ],
      8: [
        'play basketball',
        'spell',
        'play football',
        'run',
        'play the guitar',
        'ride a bike',
        'climb a tree',
        'walk',
        'draw',
        'speak Chinese',
        'rollerblade',
        'swim',
        'sing',
      ],
      10: [
        'scared',
        'angry',
        'tired',
        'hungry',
        'excited',
        'sad',
        'cold',
        'happy',
        'bored',
        'hot',
        'thirsty',
        'sleepy',
      ],
      12: [
        'grandmother',
        'grandfather',
        'mother',
        'father',
        'aunt',
        'uncle',
        'brother',
        'sister',
        'thirty',
        'forty',
        'fifty',
        'sixty',
        'seventy',
        'eighty',
        'ninety',
        'one hundred',
      ],
      15: [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ],
      16: ['Art', 'History', 'Maths', 'Music', 'PE', 'Science', 'Technology'],
      17: [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
        'quarter past three',
        'half past three',
        'quarter to four',
      ],
      18: ['break', 'lesson'],
      19: ['feelings', 'school bus', 'drama club', 'supermarket', 'bed'],
      20: [
        'the UK',
        'the USA',
        'Canada',
        'South Africa',
        'Australia',
        'New Zealand',
        'Jamaica',
        'Singapore',
        'flag',
        'cross',
        'star',
        'leaf',
        'moon',
      ],
      21: ['sundial', 'shadow', 'stick', 'stones', 'chalk', 'watch', 'bucket'],
    };
    for (final group in groups.entries) {
      for (final english in group.value) {
        expect(entry(english).page, group.key, reason: english);
      }
    }
    expect(vocabularyGrade3.any((e) => e.english == 'staffroom'), isFalse);
    expect(vocabulary.any((e) => e.english == 'staffroom'), isTrue);
  });

  test(
    'valid variants pass but different meanings and misspellings do not',
    () {
      expect(entry('rubber').accepts('eraser'), isTrue);
      expect(entry('grey').accepts('GRAY'), isTrue);
      expect(entry('mother').accepts('mum'), isTrue);
      expect(entry('mother').accepts('mom'), isTrue);
      expect(entry('Maths').accepts('math'), isTrue);
      expect(entry('PE').accepts('physical education'), isTrue);
      expect(entry('quarter to four').accepts('three forty five'), isTrue);
      expect(entry('twenty-third').accepts('twenty third'), isTrue);
      expect(entry('scissors').accepts('scisors'), isFalse);
      expect(entry('thirteen').accepts('thirty'), isFalse);
      expect(entry('hungry').accepts('angry'), isFalse);
      expect(entry('quarter past three').accepts('quarter to three'), isFalse);
      expect(entry('month').accepts('moon'), isFalse);
      expect(entry('Slovenian').accepts('Slovak'), isFalse);
    },
  );

  test('grade 3 rounds cover only its own deck before repeating', () {
    final deck = VocabularyDeck(entries: vocabularyGrade3, random: Random(3));
    final seen = <VocabularyEntry>[];
    while (seen.length < vocabularyGrade3.length) {
      final round = deck.nextRound();
      expect(round.length, inInclusiveRange(1, 8));
      expect(round.toSet().intersection(seen.toSet()), isEmpty);
      seen.addAll(round);
    }
    expect(seen, unorderedEquals(vocabularyGrade3));
    expect(deck.nextRound(), hasLength(8));
  });
}
