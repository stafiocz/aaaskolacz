import 'dart:convert';
import 'dart:io';

import 'package:aaaskola/catalog.dart';
import 'package:aaaskola/english_page.dart';
import 'package:aaaskola/main.dart';
import 'package:aaaskola/progress.dart';
import 'package:aaaskola/test_session.dart';
import 'package:aaaskola/vocabulary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'english_page_test.dart' show tapText;

final seed =
    jsonDecode(File('server/german-seed.json').readAsStringSync())
        as Map<String, dynamic>;
final items = (seed['courses'][0]['items'] as List)
    .cast<Map<String, dynamic>>();
VocabularyEntry word(String id) => VocabularyEntry.fromJson(
  items.singleWhere((item) => item['id'] == '7-german-$id')['data'],
  id: '7-german-$id',
);

void main() {
  test(
    'German preserves article, noun capitalization, umlauts and formal Sie',
    () {
      expect(word('word-apfel').accepts('der Apfel!'), true);
      for (final answer in ['Apfel', 'das Apfel', 'der apfel']) {
        expect(word('word-apfel').accepts(answer), false);
      }
      expect(word('pronoun-sie-formal').accepts('Sie'), true);
      expect(word('pronoun-sie-formal').accepts('sie'), false);
      expect(word('pronoun-sie-plural').accepts('Sie'), false);
      expect(word('word-suess').accepts('suß'), false);
      expect(word('word-paprika').accepts('der Paprika'), true);
      expect(word('sentence-du-wein').accepts('Du hast den Wein'), true);
      expect(word('sentence-du-wein').accepts('Du hast der Wein'), false);
      expect(word('haben-du').accepts('habst'), false);
      expect(
        const VocabularyEntry(
          'January',
          'leden',
          'Měsíce',
          5,
        ).accepts('JANUARY'),
        true,
      );
    },
  );

  test(
    'German guest rounds mix grammar and words and persist delayed repairs',
    () async {
      final saved = <String, String?>{};
      ProgressController controller() => ProgressController(
        enabled: false,
        readPractice: (key) => saved[key],
        writePractice: (key, value) => saved[key] = value,
      );
      var progress = controller();
      TestSession session() => TestSession(
        progress: progress,
        kind: 'vocabulary',
        grade: 7,
        subject: 'german',
        items: items,
      );
      var quiz = session();
      final first = await quiz.load();
      final cards = first['cards'] as List;
      final grammarCount = cards
          .where((item) => item['data']['exerciseType'] == 'grammar')
          .length;
      expect(grammarCount, inInclusiveRange(7, 8));
      expect(cards.map((item) => item['id']).toSet().length, 15);
      Future<Map<String, dynamic>> answer(
        Map<String, dynamic> task,
        String value,
      ) => quiz.answer({
        'id': newExerciseId(),
        'exerciseId': task['exerciseId'],
        'step': 0,
        'revision': task['revision'],
        'answer': value,
      });
      expect((await answer(first, 'chyba'))['progress']['total'], 16);
      progress.dispose();
      progress = controller();
      quiz = session();
      for (var i = 0; i < 3; i++) {
        final next = await quiz.load(newRound: true);
        expect(next['exerciseId'], isNot(first['exerciseId']));
        await answer(next, next['problem']['english']);
      }
      final retry = await quiz.load();
      expect(retry['exerciseId'], first['exerciseId']);
      expect(retry['problem'], first['problem']);
      expect(retry['progress']['total'], 16);
      expect(retry['progress']['mistakes'], 1);
      progress.dispose();
    },
  );

  testWidgets(
    'German route shows mixed course and grammar cards conceal the solution',
    (tester) async {
      final progress = ProgressController(enabled: false);
      addTearDown(progress.dispose);
      final catalog = CatalogController(
        initial: SchoolCatalog.fromJson({
          'grades': [
            {'id': 7, 'name': '7. třída'},
          ],
          'subjects': seed['subjects'],
          'courses': [
            {
              ...seed['courses'][0] as Map<String, dynamic>,
              'items': [
                items.singleWhere(
                  (i) => i['id'] == '7-german-pronoun-sie-formal',
                ),
              ],
            },
          ],
        }),
      );
      addTearDown(catalog.dispose);
      await tester.pumpWidget(
        AaaSkolaApp(progress: progress, catalog: catalog),
      );
      await tapText(tester, '7. třída');
      await tapText(tester, 'Němčina');
      expect(find.text('Němčina · 7. třída'), findsOneWidget);
      expect(find.text('Slovíčka a gramatika'), findsOneWidget);
      await tapText(tester, 'Učit se s kartičkami');
      expect(find.text('Sie'), findsNothing);
      expect(find.text('Vy (zdvořilé vykání)'), findsOneWidget);
      await tapText(tester, 'Ukázat řešení');
      expect(find.text('Sie'), findsOneWidget);
      await tapText(tester, 'Přejít na zkoušení');
      await tester.enterText(find.byType(TextField), 'sie');
      await tapText(tester, 'Zkontrolovat');
      expect(find.text('Tohle si ještě zopakujeme.'), findsOneWidget);
      expect(find.text('Chyby: 1 · Úlohy navíc: 1'), findsOneWidget);
      expect(find.textContaining('Při vykání píšeme Sie vždy'), findsOneWidget);
      await tapText(tester, 'Pokračovat');
      expect(tester.testTextInput.hasAnyClients, isTrue);
      expect(tester.testTextInput.setClientArgs!['readOnly'], isFalse);
      await tester.enterText(find.byType(TextField), 'Sie');
      await tapText(tester, 'Zkontrolovat');
      expect(find.text('Správně!'), findsOneWidget);
    },
  );

  testWidgets(
    'German special characters insert at the cursor on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: EnglishPage(
            entries: [word('word-suess')],
            subject: 'german',
            subjectName: 'Němčina',
            answerLanguage: 'německy',
          ),
        ),
      );
      await tapText(tester, 'Rovnou se vyzkoušet');
      await tester.enterText(find.byType(TextField), 's');
      await tester.pumpAndSettle();
      await tapText(tester, 'ü');
      await tapText(tester, 'ß');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'süß',
      );
      await tapText(tester, 'Zkontrolovat');
      expect(find.text('Správně!'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
