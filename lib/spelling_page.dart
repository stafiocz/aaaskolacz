import 'dart:math';

import 'package:flutter/material.dart';

import 'progress.dart';
import 'progress_widgets.dart';
import 'school_widgets.dart';

class SpellingPage extends StatefulWidget {
  const SpellingPage({
    super.key,
    required this.grade,
    required this.gradeName,
    required this.subject,
    required this.subjectName,
    required this.items,
  });

  final int grade;
  final String gradeName;
  final String subject;
  final String subjectName;
  final List<Map<String, dynamic>> items;

  @override
  State<SpellingPage> createState() => _SpellingPageState();
}

class _SpellingPageState extends State<SpellingPage> {
  ProgressController? _progress;
  String? _owner;
  Map<String, dynamic>? _exercise;
  Map<String, dynamic>? _request;
  final List<Map<String, dynamic>> _remaining = [];
  bool _busy = false;
  bool _completed = false;
  bool _incorrect = false;
  String? _error;
  int _version = 0;

  String get _course => 'spelling/${widget.grade}/${widget.subject}';
  Map<String, dynamic> get _problem =>
      _exercise!['problem'] as Map<String, dynamic>;
  int get _step => _exercise!['step'] as int;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _progress = ProgressScope.of(context);
    if (_progress != null && !_progress!.sessionResolved) return;
    final owner = _progress?.user?['id'] as String? ?? 'guest';
    if (_owner == owner) return;
    _owner = owner;
    _exercise = null;
    _request = null;
    _remaining.clear();
    _load();
  }

  Future<void> _load() async {
    final version = ++_version;
    final owner = _owner;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      Map<String, dynamic>? exercise;
      if (owner != 'guest') {
        exercise = await _progress!.practiceRequest('spelling', 'exercise', {
          'grade': widget.grade,
          'subject': widget.subject,
        });
      } else {
        exercise = _progress?.guestMath(_course);
        if (exercise == null) {
          if (_remaining.isEmpty) {
            _remaining.addAll(widget.items);
            _remaining.shuffle(Random());
          }
          final item = _remaining.removeLast();
          final problem = Map<String, dynamic>.from(item['data'] as Map);
          problem['reasons'] = List<dynamic>.from(problem['reasons'] as List)
            ..shuffle(Random());
          exercise = {
            'exerciseId': newExerciseId(),
            'itemId': item['id'],
            'step': 0,
            'problem': problem,
          };
          _progress?.saveGuestMath(_course, exercise);
        }
        _remaining.removeWhere((item) => item['id'] == exercise!['itemId']);
      }
      if (!mounted || version != _version || owner != _owner) return;
      setState(() {
        _exercise = exercise;
        _request = null;
        _completed = false;
        _incorrect = false;
      });
    } catch (_) {
      if (mounted && version == _version && owner == _owner) {
        setState(
          () => _error =
              'Rozpracovanou úlohu se nepodařilo načíst. Zkus to znovu.',
        );
      }
    } finally {
      if (mounted && version == _version && owner == _owner) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _answer(String answer) async {
    if (_busy || _completed || _exercise == null) return;
    final version = _version;
    final owner = _owner;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      bool correct;
      if (owner != 'guest') {
        _request ??= {
          'id': newExerciseId(),
          'exerciseId': _exercise!['exerciseId'],
          'step': _step,
          'answer': answer,
        };
        final result = await _progress!.practiceRequest(
          'spelling',
          'answer',
          _request!,
        );
        correct = result['correct'] as bool;
      } else {
        correct = answer == _problem[_step == 0 ? 'letter' : 'reason'];
        if (correct) {
          _progress?.saveGuestMath(
            _course,
            _step == 1 ? null : {..._exercise!, 'step': 1},
          );
        }
      }
      if (!mounted || version != _version || owner != _owner) return;
      setState(() {
        _request = null;
        _incorrect = !correct;
        if (correct) {
          _completed = _step == 1;
          _exercise = {..._exercise!, 'step': 1};
        }
      });
    } on MathExerciseChanged {
      if (!mounted || version != _version || owner != _owner) return;
      setState(() {
        _exercise = null;
        _request = null;
        _error = 'Úloha už pokročila v jiné kartě. Načti aktuální zadání.';
      });
    } catch (_) {
      if (!mounted || version != _version || owner != _owner) return;
      setState(
        () => _error = 'Odpověď se nepodařilo ověřit. Zkus odeslání znovu.',
      );
    } finally {
      if (mounted && version == _version && owner == _owner) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_busy && !_completed && _request == null;
    return SchoolPage(
      title: '${widget.subjectName} · ${widget.gradeName}',
      children: [
        const Text(
          'Měkké i, tvrdé y',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Nejdřív doplň písmeno. Potom vyber správné zdůvodnění. Úloha je hotová až po obou krocích.',
        ),
        const SizedBox(height: 24),
        if (_exercise != null) ...[
          Text(
            _completed
                ? 'Oba kroky zvládnuté'
                : '${_step + 1}/2 · ${_step == 0 ? 'Doplň písmeno' : 'Zdůvodni pravopis'}',
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF226552),
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(value: _completed ? 1 : _step / 2),
          const SizedBox(height: 24),
          Card(
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: (_problem['sentence'] as String).split('_').first,
                    ),
                    TextSpan(
                      text: _step == 0 ? '＿' : _problem['letter'] as String,
                      style: const TextStyle(
                        color: Color(0xFF226552),
                        fontWeight: FontWeight.w900,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                    TextSpan(
                      text: (_problem['sentence'] as String).split('_').last,
                    ),
                  ],
                ),
                key: const Key('spelling-sentence'),
                style: const TextStyle(fontSize: 27, height: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 18),
          if (!_completed && _step == 0) ...[
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                for (final letter in ['i', 'í', 'y', 'ý', 'a'])
                  OutlinedButton(
                    key: Key('letter-$letter'),
                    onPressed: enabled ? () => _answer(letter) : null,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(68, 64),
                    ),
                    child: Text(letter, style: const TextStyle(fontSize: 28)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Pozor i na délku samohlásky. Někdy patří do koncovky a.',
              textAlign: TextAlign.center,
            ),
          ],
          if (!_completed && _step == 1) ...[
            const Text(
              'Písmeno je správně. Proč ho sem píšeme?',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 12),
            for (final reason in _problem['reasons'] as List)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: OutlinedButton(
                  key: Key('reason-${reason['id']}'),
                  onPressed: enabled
                      ? () => _answer(reason['id'] as String)
                      : null,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.all(18),
                    alignment: Alignment.centerLeft,
                  ),
                  child: Text(
                    reason['text'] as String,
                    style: const TextStyle(fontSize: 17, height: 1.4),
                  ),
                ),
              ),
          ],
          if (_incorrect)
            Semantics(
              liveRegion: true,
              child: Text(
                _step == 0
                    ? 'Ještě to není správně. Podívej se na celou větu a zkus to znovu.'
                    : 'Toto zdůvodnění nesedí. Urči podmět, nebo pád a vzor podstatného jména. Zkus to znovu.',
                style: const TextStyle(color: Color(0xFF9A451C), fontSize: 17),
              ),
            ),
          if (_completed) ...[
            Semantics(
              liveRegion: true,
              child: const Text(
                'Správně! Písmeno i zdůvodnění.',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF226552),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _problem['explanation'] as String,
              style: const TextStyle(fontSize: 18, height: 1.5),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _busy ? null : _load,
              icon: const Icon(Icons.arrow_forward),
              label: const Text('Další úloha'),
            ),
          ],
        ],
        if (_busy || (_progress != null && !_progress!.ready)) ...[
          const SizedBox(height: 20),
          const Center(child: CircularProgressIndicator()),
        ],
        if (!_busy &&
            (_error != null ||
                (_exercise == null && _progress?.ready == true))) ...[
          const SizedBox(height: 20),
          Text(_error ?? 'Účet se nepodařilo načíst. Zkus to znovu.'),
          FilledButton(
            onPressed: () {
              if (_progress != null && !_progress!.sessionResolved) {
                _progress!.load();
              } else if (_request != null) {
                _answer(_request!['answer'] as String);
              } else {
                _load();
              }
            },
            child: const Text('Zkusit znovu'),
          ),
        ],
        const SizedBox(height: 24),
        const SaveStatus(),
      ],
    );
  }
}
