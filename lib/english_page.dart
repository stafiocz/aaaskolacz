import 'package:flutter/material.dart';

import 'school_widgets.dart';
import 'vocabulary.dart';
import 'vocabulary_practice.dart';
import 'progress.dart';
import 'progress_widgets.dart';

enum _Stage { intro, cards, quiz, done }

class EnglishPage extends StatefulWidget {
  const EnglishPage({
    super.key,
    this.grade = 7,
    required this.entries,
    this.subject = 'english',
    this.subjectName = 'Angličtina',
    this.answerLanguage = 'anglicky',
    this.gradeName,
    this.sourceTitle = 'Introduction · strany 4–7',
  });

  final String? gradeName;
  final String subject;
  final String subjectName;
  final String answerLanguage;
  final int grade;
  final List<VocabularyEntry> entries;
  final String sourceTitle;

  @override
  State<EnglishPage> createState() => _EnglishPageState();
}

class _EnglishPageState extends State<EnglishPage> {
  late final _deck = VocabularyDeck(entries: widget.entries);
  final _answer = TextEditingController();
  final _answerFocus = FocusNode();
  _Stage _stage = _Stage.intro;
  List<VocabularyEntry> _round = [];
  late VocabularyQuiz _quiz;
  int _card = 0;
  bool _revealed = false;
  Map<VocabularyEntry, String> _exerciseIds = {};

  @override
  void dispose() {
    _answer.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  void _start({bool study = true}) {
    setState(() {
      _round = _deck.nextRound(
        learned: ProgressScope.of(context)?.goals?.wordIds ?? {},
      );
      _exerciseIds = {for (final word in _round) word: newExerciseId()};
      _card = 0;
      _revealed = false;
      _quiz = VocabularyQuiz(_round);
      _answer.clear();
      _stage = study ? _Stage.cards : _Stage.quiz;
    });
  }

  void _check({bool reveal = false}) {
    if (_quiz.correct != null || (!reveal && _answer.text.trim().isEmpty)) {
      return;
    }
    _answerFocus.unfocus();
    setState(() => _quiz.check(reveal ? '' : _answer.text));
    ProgressScope.of(context)?.record(
      exerciseId: _exerciseIds[_quiz.current]!,
      itemId: _quiz.current.id,
      subject: widget.subject,
      grade: widget.grade,
      correct: _quiz.correct!,
      completed: _quiz.correct!,
    );
  }

  void _next() {
    setState(() {
      _quiz.next();
      _answer.clear();
      if (_quiz.isFinished) _stage = _Stage.done;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _stage == _Stage.quiz) _answerFocus.requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) => SchoolPage(
    title:
        '${widget.subjectName} · ${widget.gradeName ?? '${widget.grade}. třída'}',
    children: [
      const DailyGoalsCard(kind: 'vocabulary'),
      ...switch (_stage) {
        _Stage.intro => _intro(),
        _Stage.cards => _cards(),
        _Stage.quiz => _question(),
        _Stage.done => _summary(),
      },
    ],
  );

  List<Widget> _intro() => [
    const Text(
      'Slovíčka po malých krocích',
      style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 10),
    Text(
      '${widget.sourceTitle}\n${widget.entries.length} slovíček a frází z tvých podkladů.',
      style: const TextStyle(color: Color(0xFF6E8177), height: 1.6),
    ),
    const SizedBox(height: 24),
    _panel([
      const Text(
        'Denní úkol: 15 slovíček',
        style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 16),
      Text(
        '1. Projdi kartičky a zkus si vybavit překlad.\n\n2. Napiš ${widget.answerLanguage} české slovíčko nebo frázi.\n\n3. Co se nepovede, vrátí se na konci kola.',
        style: TextStyle(fontSize: 16, height: 1.5),
      ),
    ]),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: () => _start(),
      icon: const Icon(Icons.style_outlined),
      label: const Text('Učit se slovíčka'),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      onPressed: () => _start(study: false),
      child: const Text('Rovnou se vyzkoušet'),
    ),
    const SizedBox(height: 18),
    const Text(
      'V kole je až 15 slovíček. Témata se míchají. Po přihlášení se dnešní zvládnutá slovíčka ukládají a další kolo nabídne dosud nezvládnutá.',
      style: TextStyle(color: Color(0xFF6E8177), height: 1.5),
    ),
    const SizedBox(height: 12),
    TextButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => VocabularyListPage(
            entries: widget.entries,
            grade: widget.grade,
            sourceTitle: widget.sourceTitle,
          ),
        ),
      ),
      icon: const Icon(Icons.list_alt_rounded),
      label: const Text('Prohlédnout všechna slovíčka'),
    ),
  ];

  List<Widget> _cards() {
    final word = _round[_card];
    return [
      Text(
        'SEZNÁMENÍ · ${_card + 1} / ${_round.length}',
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF226552),
        ),
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(
        value: (_card + 1) / _round.length,
        minHeight: 6,
        borderRadius: BorderRadius.circular(6),
      ),
      const SizedBox(height: 24),
      _panel([
        Text(word.topic, style: const TextStyle(color: Color(0xFF6E8177))),
        const SizedBox(height: 24),
        Text(
          word.english,
          key: const ValueKey('flashcard-english'),
          style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        if (_revealed)
          Text(
            word.czech,
            key: const ValueKey('flashcard-czech'),
            style: const TextStyle(fontSize: 24, color: Color(0xFF226552)),
          )
        else
          const Text(
            'Co to znamená česky? Zkus si odpověď říct nahlas.',
            style: TextStyle(fontSize: 16, height: 1.5),
          ),
        const SizedBox(height: 24),
        Text(
          'Učebnice · strana ${word.page}',
          style: const TextStyle(fontSize: 12, color: Color(0xFF6E8177)),
        ),
      ]),
      const SizedBox(height: 24),
      FilledButton(
        onPressed: () => setState(() {
          if (!_revealed) {
            _revealed = true;
          } else if (_card + 1 < _round.length) {
            _card++;
            _revealed = false;
          } else {
            _round.shuffle();
            _quiz = VocabularyQuiz(_round);
            _stage = _Stage.quiz;
          }
        }),
        child: Text(
          !_revealed
              ? 'Ukázat překlad'
              : _card + 1 < _round.length
              ? 'Další kartička'
              : 'Přejít na zkoušení',
        ),
      ),
    ];
  }

  List<Widget> _question() {
    final word = _quiz.current;
    final checked = _quiz.correct != null;
    return [
      const SaveStatus(),
      Text(
        'ZKOUŠENÍ · Zvládnuto ${_quiz.completed} / ${_quiz.total}',
        key: const ValueKey('vocabulary-progress'),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF226552),
        ),
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(
        value: _quiz.completed / _quiz.total,
        minHeight: 6,
        borderRadius: BorderRadius.circular(6),
      ),
      const SizedBox(height: 20),
      _panel([
        Text(
          _quiz.isRetry ? 'Ještě jednou z paměti' : word.topic,
          style: const TextStyle(color: Color(0xFF6E8177)),
        ),
        const SizedBox(height: 18),
        Text(
          'Jak se řekne ${widget.answerLanguage}…',
          style: const TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 8),
        Text(
          word.czech,
          key: const ValueKey('vocabulary-prompt'),
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        TextField(
          key: const ValueKey('vocabulary-answer'),
          controller: _answer,
          focusNode: _answerFocus,
          readOnly: checked,
          autocorrect: false,
          enableSuggestions: false,
          keyboardType: TextInputType.text,
          textInputAction: TextInputAction.done,
          decoration: InputDecoration(
            labelText: 'Napiš ${widget.answerLanguage}',
            border: const OutlineInputBorder(),
            filled: true,
            fillColor: const Color(0xFFF3F6EF),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) {
            if (checked) {
              _next();
            } else {
              _check();
            }
          },
        ),
        const SizedBox(height: 12),
        if (!checked)
          const Text(
            'Piš slovy. Velká písmena, spojovníky a koncovou interpunkci neřešíme.',
            style: TextStyle(
              fontSize: 12,
              color: Color(0xFF6E8177),
              height: 1.5,
            ),
          ),
        if (checked)
          Semantics(
            liveRegion: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _quiz.correct! ? 'Správně!' : 'Tohle si ještě zopakujeme.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _quiz.correct!
                        ? const Color(0xFF226552)
                        : const Color(0xFFAD552B),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  word.english,
                  key: const ValueKey('vocabulary-solution'),
                  style: const TextStyle(
                    fontSize: 23,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (!_quiz.correct!) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Přečti si správnou odpověď. Slovíčko se vrátí, až projdeš ostatní.',
                    style: TextStyle(height: 1.5),
                  ),
                ],
              ],
            ),
          ),
      ]),
      const SizedBox(height: 20),
      FilledButton(
        key: const ValueKey('vocabulary-submit'),
        onPressed: checked
            ? _next
            : _answer.text.trim().isEmpty
            ? null
            : () => _check(),
        child: Text(checked ? 'Pokračovat' : 'Zkontrolovat'),
      ),
      if (!checked) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _check(reveal: true),
          child: const Text('Nevím · ukázat odpověď'),
        ),
      ],
    ];
  }

  List<Widget> _summary() => [
    const Icon(
      Icons.check_circle_outline_rounded,
      size: 64,
      color: Color(0xFF226552),
    ),
    const SizedBox(height: 20),
    const Text(
      'Kolo je hotové!',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
    ),
    const SizedBox(height: 12),
    Text(
      'Na první pokus: ${_quiz.firstTryCorrect} z ${_quiz.total}\nTeď už jsi správně napsal/a všech ${_quiz.total}.',
      key: const ValueKey('vocabulary-result'),
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 18, height: 1.6),
    ),
    const SizedBox(height: 24),
    _panel([
      for (final word in _round)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Text(
            '${word.english} — ${word.czech}',
            style: const TextStyle(fontSize: 16, height: 1.4),
          ),
        ),
    ]),
    const SizedBox(height: 24),
    FilledButton(
      onPressed: () => _start(),
      child: const Text('Další kolo s kartičkami'),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      onPressed: () => _start(study: false),
      child: const Text('Další kolo zkoušení'),
    ),
    const SizedBox(height: 10),
    TextButton(
      onPressed: () => Navigator.pop(context),
      child: const Text('Zpět na předměty'),
    ),
  ];

  Widget _panel(List<Widget> children) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: const Color(0xFFE1E8DE)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: children,
    ),
  );
}

class VocabularyListPage extends StatelessWidget {
  const VocabularyListPage({
    super.key,
    required this.entries,
    required this.grade,
    required this.sourceTitle,
  });

  final List<VocabularyEntry> entries;
  final int grade;
  final String sourceTitle;

  @override
  Widget build(BuildContext context) => SchoolPage(
    title: 'Slovíčka · $grade. třída',
    children: [
      Text(
        sourceTitle,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 12),
      const Text(
        'Přepsáno z dodaných fotografií. U školních výrazů používáme britskou angličtinu.',
        style: TextStyle(height: 1.5),
      ),
      const SizedBox(height: 20),
      for (final topic in entries.map((e) => e.topic).toSet())
        ExpansionTile(
          title: Text(
            topic,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          children: [
            for (final word in entries.where((e) => e.topic == topic))
              ListTile(
                title: Text(word.english),
                subtitle: Text(word.czech),
                trailing: Text('s. ${word.page}'),
              ),
          ],
        ),
    ],
  );
}
