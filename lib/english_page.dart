import 'package:flutter/material.dart';

import 'school_widgets.dart';
import 'vocabulary.dart';
import 'test_session.dart';
import 'test_progress.dart';
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
  late TestSession _test;
  ProgressController? _progress;
  String? _owner;
  int _version = 0;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _exercise;
  Map<String, dynamic>? _request;
  Map<String, dynamic> _roundProgress = {
    'total': 15,
    'completed': 0,
    'mistakes': 0,
  };
  bool? _correct;
  VocabularyEntry get _word => VocabularyEntry.fromJson(
    _exercise!['problem'] as Map<String, dynamic>,
    id: _exercise!['itemId'] as String?,
  );
  final _answer = TextEditingController();
  final _answerFocus = FocusNode();
  _Stage _stage = _Stage.intro;
  List<VocabularyEntry> _round = [];
  int _card = 0;
  bool _revealed = false;

  @override
  void dispose() {
    _answer.dispose();
    _answerFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress = ProgressScope.of(context);
    if (_progress != null && !_progress!.sessionResolved) return;
    final owner = _progress?.user?['id'] as String? ?? 'guest';
    if (_owner == owner) return;
    _owner = owner;
    _version++;
    _stage = _Stage.intro;
    _request = null;
    _busy = false;
    _error = null;
    _test = TestSession(
      progress: _progress,
      kind: 'vocabulary',
      grade: widget.grade,
      subject: widget.subject,
      items: [
        for (final word in widget.entries)
          {
            'id': word.id ?? word.english,
            'data': {
              'english': word.english,
              'czech': word.czech,
              'topic': word.topic,
              'page': word.page,
              'alternatives': word.alternatives,
            },
          },
      ],
    );
  }

  Future<void> _start({bool study = true}) =>
      _load(study: study, newRound: _stage == _Stage.done);

  Future<void> _load({bool study = false, bool newRound = false}) async {
    if (_owner == null || _busy) return;
    final version = ++_version;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final exercise = await _test.load(newRound: newRound);
      if (!mounted || version != _version) return;
      setState(() {
        _exercise = exercise;
        _roundProgress = exercise['progress'] as Map<String, dynamic>;
        _correct = null;
        _request = null;
        _answer.clear();
        if (_roundProgress['finished'] == true) {
          _stage = _Stage.done;
        } else {
          final cards = [
            for (final item in exercise['cards'] as List)
              VocabularyEntry.fromJson(item['data'], id: item['id']),
          ];
          if (_stage == _Stage.intro || newRound) {
            _round = cards;
          } else {
            for (final card in cards) {
              if (!_round.any((word) => word.id == card.id)) _round.add(card);
            }
          }
          _card = 0;
          _revealed = false;
          _stage = study && _roundProgress['started'] != true
              ? _Stage.cards
              : _Stage.quiz;
        }
      });
    } catch (_) {
      if (mounted && version == _version) {
        setState(() => _error = 'Kolo se nepodařilo načíst. Zkus to znovu.');
      }
    } finally {
      if (mounted && version == _version) setState(() => _busy = false);
    }
  }

  Future<void> _check({bool reveal = false}) async {
    if (_busy ||
        _correct != null ||
        (!reveal && _request == null && _answer.text.trim().isEmpty)) {
      return;
    }
    final version = _version;
    _answerFocus.unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      _request ??= {
        'id': newExerciseId(),
        'exerciseId': _exercise!['exerciseId'],
        'step': 0,
        'revision': _exercise!['revision'] ?? 0,
        'answer': reveal ? '' : _answer.text,
      };
      final result = await _test.answer(_request!);
      if (!mounted || version != _version) return;
      setState(() {
        _correct = result['correct'] as bool;
        _roundProgress = result['progress'] as Map<String, dynamic>;
        _request = null;
      });
    } on MathExerciseChanged {
      if (!mounted || version != _version) return;
      setState(() {
        _request = null;
        _stage = _Stage.intro;
        _error = 'Kolo pokročilo v jiné kartě. Načti aktuální zadání.';
      });
    } catch (_) {
      if (mounted && version == _version) {
        setState(
          () => _error = 'Odpověď se nepodařilo ověřit. Zkus odeslání znovu.',
        );
      }
    } finally {
      if (mounted && version == _version) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    await _load();
    if (mounted && _stage == _Stage.quiz) _answerFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) => SchoolPage(
    title:
        '${widget.subjectName} · ${widget.gradeName ?? '${widget.grade}. třída'}',
    children: [
      const DailyGoalsCard(kind: 'vocabulary'),
      if (_owner == null && _progress?.ready == true) ...[
        const Text('Účet se nepodařilo načíst. Zkus to znovu.'),
        FilledButton(
          onPressed: () => _progress!.load(),
          child: const Text('Načíst účet'),
        ),
      ],
      if (_busy) const Center(child: CircularProgressIndicator()),
      if (_error != null) ...[
        Text(_error!),
        FilledButton(
          onPressed: _busy ? null : () => _request != null ? _check() : _load(),
          child: const Text('Zkusit znovu'),
        ),
      ],
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
        '1. Projdi kartičky a zkus si vybavit překlad.\n\n2. Napiš ${widget.answerLanguage} české slovíčko nebo frázi.\n\n3. Chybné slovíčko se vrátí po třech dalších zadáních. Každá chyba přidá jedno další slovíčko.',
        style: TextStyle(fontSize: 16, height: 1.5),
      ),
    ]),
    const SizedBox(height: 20),
    FilledButton.icon(
      onPressed: _busy || _owner == null ? null : () => _start(),
      icon: const Icon(Icons.style_outlined),
      label: const Text('Učit se slovíčka'),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      onPressed: _busy || _owner == null ? null : () => _start(study: false),
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
    final word = _word;
    final checked = _correct != null;
    return [
      const SaveStatus(),
      Text(
        'ZKOUŠENÍ · Zvládnuto ${_roundProgress['completed']} / ${_roundProgress['total']}',
        key: const ValueKey('vocabulary-progress'),
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: Color(0xFF226552),
        ),
      ),
      Text(
        'Chyby: ${_roundProgress['mistakes']} · Slovíčka navíc: ${_roundProgress['mistakes']}',
      ),
      const SizedBox(height: 12),
      LinearProgressIndicator(
        value:
            (_roundProgress['completed'] as int) /
            (_roundProgress['total'] as int),
        minHeight: 6,
        borderRadius: BorderRadius.circular(6),
      ),
      const SizedBox(height: 20),
      _panel([
        Text(
          (_exercise!['revision'] as int? ?? 0) > 0
              ? 'Ještě jednou z paměti'
              : word.topic,
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
          readOnly: checked || _busy || _request != null,
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
                  _correct! ? 'Správně!' : 'Tohle si ještě zopakujeme.',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: _correct!
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
                if (!_correct!) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Přečti si správnou odpověď. $retryFeedback',
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
        onPressed: _busy || _request != null
            ? null
            : checked
            ? _next
            : _answer.text.trim().isEmpty
            ? null
            : () => _check(),
        child: Text(checked ? 'Pokračovat' : 'Zkontrolovat'),
      ),
      if (!checked) ...[
        const SizedBox(height: 8),
        TextButton(
          onPressed: _busy || _request != null
              ? null
              : () => _check(reveal: true),
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
      'Zvládnuto: ${_roundProgress['completed']} z ${_roundProgress['total']}\nChyby: ${_roundProgress['mistakes']} · Slovíčka navíc: ${_roundProgress['mistakes']}',
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
      onPressed: _busy || _owner == null ? null : () => _start(),
      child: const Text('Další kolo s kartičkami'),
    ),
    const SizedBox(height: 10),
    OutlinedButton(
      onPressed: _busy || _owner == null ? null : () => _start(study: false),
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
