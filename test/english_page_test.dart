import 'catalog_fixture.dart';
import '../tool/vocabulary_seed.dart';
import 'package:aaaskola/english_page.dart';
import 'package:aaaskola/vocabulary.dart';
import '../tool/vocabulary_grade5_seed.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const words = [
  VocabularyEntry('January', 'leden', 'Měsíce', 5),
  VocabularyEntry('library', 'knihovna', 'Ve škole', 6),
];

Future<void> tapText(WidgetTester tester, String text) async {
  await tester.pump();
  final target = find.text(text);
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Future<void> openEnglish(WidgetTester tester) async {
  await tester.pumpWidget(const MaterialApp(home: EnglishPage(entries: words)));
}

String prompt(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const ValueKey('vocabulary-prompt'))).data!;

Future<void> answer(WidgetTester tester) async {
  final value = prompt(tester) == 'leden' ? 'January' : 'library';
  await tester.enterText(
    find.byKey(const ValueKey('vocabulary-answer')),
    value,
  );
  await tapText(tester, 'Zkontrolovat');
  expect(find.text('Správně!'), findsOneWidget);
  await tapText(tester, 'Pokračovat');
}

void main() {
  testWidgets('home routes to grades and subjects and returns from English', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    expect(find.text('7. třída'), findsOneWidget);
    expect(find.text('5. třída'), findsOneWidget);
    expect(find.text('3. třída'), findsOneWidget);
    await tapText(tester, '7. třída');
    expect(find.text('Angličtina'), findsOneWidget);
    expect(find.text('Matematika'), findsNothing);
    await tapText(tester, 'Angličtina');
    expect(find.text('Slovíčka po malých krocích'), findsOneWidget);
    expect(find.text('Angličtina · 7. třída'), findsOneWidget);
    expect(
      tester.widget<EnglishPage>(find.byType(EnglishPage)).entries,
      isA<List<VocabularyEntry>>().having(
        (items) => items.map((w) => w.english).toSet(),
        'words',
        vocabulary.map((w) => w.english).toSet(),
      ),
    );
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, '3. třída');
    await tapText(tester, 'Matematika');
    expect(find.text('MIX'), findsOneWidget);
    await tapText(tester, 'Matematika · 3. třída');
    expect(find.text('Matematika'), findsOneWidget);
    expect(find.text('Angličtina'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tapText(tester, '5. třída');
    expect(find.text('Matematika'), findsOneWidget);
    await tapText(tester, 'Angličtina');
    expect(find.text('Angličtina · 5. třída'), findsOneWidget);
    expect(
      tester.widget<EnglishPage>(find.byType(EnglishPage)).entries,
      isA<List<VocabularyEntry>>().having(
        (items) => items.map((w) => w.english).toSet(),
        'words',
        vocabularyGrade5.map((w) => w.english).toSet(),
      ),
    );
    expect(
      find.textContaining('Introduction a Me! · strany 4–21'),
      findsOneWidget,
    );
    await tapText(tester, 'Prohlédnout všechna slovíčka');
    expect(find.text('Slovíčka · 5. třída'), findsOneWidget);
    await tapText(tester, 'Školní potřeby');
    expect(find.text('pencil'), findsOneWidget);
    expect(find.text('tužka'), findsOneWidget);
    expect(find.text('s. 4'), findsWidgets);
  });

  testWidgets('grade 5 quiz completes fifteen words and offers new ones', (
    tester,
  ) async {
    await tester.pumpWidget(testApp());
    await tapText(tester, '5. třída');
    await tapText(tester, 'Angličtina');
    await tapText(tester, 'Rovnou se vyzkoušet');
    final seen = <String>{};
    for (var index = 0; index < 15; index++) {
      final question = prompt(tester);
      expect(seen.add(question), isTrue);
      final word = vocabularyGrade5.singleWhere((e) => e.czech == question);
      await tester.enterText(find.byType(TextField), word.english);
      await tapText(tester, 'Zkontrolovat');
      expect(find.text('Správně!'), findsOneWidget);
      await tapText(tester, 'Pokračovat');
    }
    expect(find.text('Kolo je hotové!'), findsOneWidget);
    expect(find.textContaining('Na první pokus: 15 z 15'), findsOneWidget);
    await tapText(tester, 'Další kolo s kartičkami');
    await tapText(tester, 'Ukázat překlad');
    final next = tester
        .widget<Text>(find.byKey(const ValueKey('flashcard-czech')))
        .data;
    expect(seen, isNot(contains(next)));
    expect(vocabularyGrade5.map((e) => e.czech), contains(next));
  });

  testWidgets('flashcards reveal translations then start written recall', (
    tester,
  ) async {
    await openEnglish(tester);
    await tapText(tester, 'Učit se slovíčka');
    for (var index = 0; index < words.length; index++) {
      expect(find.byKey(const ValueKey('flashcard-english')), findsOneWidget);
      expect(find.byKey(const ValueKey('flashcard-czech')), findsNothing);
      await tapText(tester, 'Ukázat překlad');
      expect(find.byKey(const ValueKey('flashcard-czech')), findsOneWidget);
      await tapText(
        tester,
        index == 0 ? 'Další kartička' : 'Přejít na zkoušení',
      );
    }
    expect(find.byKey(const ValueKey('vocabulary-prompt')), findsOneWidget);
    expect(find.byKey(const ValueKey('vocabulary-solution')), findsNothing);
  });

  testWidgets('incorrect answers repeat after other words and finish a round', (
    tester,
  ) async {
    await openEnglish(tester);
    await tapText(tester, 'Rovnou se vyzkoušet');
    final original = prompt(tester);
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('vocabulary-submit')))
          .onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextField), 'wrong');
    await tapText(tester, 'Zkontrolovat');
    expect(find.text('Tohle si ještě zopakujeme.'), findsOneWidget);
    expect(tester.widget<TextField>(find.byType(TextField)).readOnly, isTrue);
    await tapText(tester, 'Pokračovat');
    expect(prompt(tester), isNot(original));
    await answer(tester);
    expect(prompt(tester), original);
    expect(find.text('Ještě jednou z paměti'), findsOneWidget);
    await answer(tester);
    expect(find.text('Kolo je hotové!'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const ValueKey('vocabulary-result'))).data,
      contains('Na první pokus: 1 z 2'),
    );
    await tapText(tester, 'Další kolo zkoušení');
    expect(find.text('ZKOUŠENÍ · Zvládnuto 0 / 2'), findsOneWidget);
  });

  testWidgets('revealing an unknown answer does not count as success', (
    tester,
  ) async {
    await openEnglish(tester);
    await tapText(tester, 'Rovnou se vyzkoušet');
    await tapText(tester, 'Nevím · ukázat odpověď');
    expect(find.byKey(const ValueKey('vocabulary-solution')), findsOneWidget);
    expect(find.text('ZKOUŠENÍ · Zvládnuto 0 / 2'), findsOneWidget);
    await tapText(tester, 'Pokračovat');
    await answer(tester);
    expect(find.text('Ještě jednou z paměti'), findsOneWidget);
  });

  testWidgets('vocabulary reference shows translations and source pages', (
    tester,
  ) async {
    await openEnglish(tester);
    await tapText(tester, 'Prohlédnout všechna slovíčka');
    await tapText(tester, 'Měsíce');
    expect(find.text('January'), findsOneWidget);
    expect(find.text('leden'), findsOneWidget);
    expect(find.text('s. 5'), findsOneWidget);
  });

  for (final grade in [5, 7]) {
    for (final size in [
      const Size(320, 568),
      const Size(390, 844),
      const Size(844, 390),
    ]) {
      testWidgets(
        'Grade $grade English fits $size including the on-screen keyboard',
        (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetViewInsets);
          await tester.pumpWidget(testApp());
          await tapText(tester, '$grade. třída');
          await tapText(tester, 'Angličtina');
          await tapText(tester, 'Rovnou se vyzkoušet');
          tester.view.viewInsets = const FakeViewPadding(bottom: 220);
          await tester.pump();
          await tester.enterText(find.byType(TextField), 'wrong');
          await tapText(tester, 'Zkontrolovat');
          await tapText(tester, 'Pokračovat');
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
