import 'dart:convert';
import 'dart:math';

import 'progress.dart';
import 'math_problem.dart';
import 'vocabulary.dart';

class TestSession {
  TestSession({
    required this.progress,
    required this.kind,
    required this.grade,
    required this.subject,
    required this.items,
  });

  final ProgressController? progress;
  final String kind;
  final int grade;
  final String subject;
  final List<Map<String, dynamic>> items;
  Map<String, dynamic>? _memory;
  String get _key =>
      kind == 'math' ? '$grade.$subject' : '$kind/$grade/$subject';

  Map<String, dynamic> _copy(Map<String, dynamic> value) =>
      jsonDecode(jsonEncode(value)) as Map<String, dynamic>;

  Map<String, dynamic> _pick(Map<String, dynamic> state) {
    final used = (state['used'] as List).cast<String>();
    var options = items.where((item) => !used.contains(item['id'])).toList();
    if (options.isEmpty) {
      used.clear();
      options = List.of(items);
    }
    options.shuffle();
    if (kind == 'math') {
      final counts = <String, int>{};
      for (final id in used) {
        final matches = items.where((item) => item['id'] == id);
        if (matches.isNotEmpty) {
          final group = matches.first['data']['group'] as String;
          counts[group] = (counts[group] ?? 0) + 1;
        }
      }
      options.sort((a, b) {
        final order = (counts[a['data']['group']] ?? 0).compareTo(
          counts[b['data']['group']] ?? 0,
        );
        if (order != 0 || used.isEmpty) return order;
        final last = state['lastGroup'];
        return (a['data']['group'] == last ? 1 : 0).compareTo(
          b['data']['group'] == last ? 1 : 0,
        );
      });
    }
    final item = options.first;
    state['lastGroup'] = item['data']['group'];
    used.add(item['id'] as String);
    state['used'] = used;
    final problem = _copy(item['data'] as Map<String, dynamic>);
    if (kind == 'spelling') (problem['reasons'] as List).shuffle();
    return {
      'exerciseId': newExerciseId(),
      'itemId': item['id'],
      'step': 0,
      'revision': 0,
      'problem': problem,
    };
  }

  Map<String, dynamic> _stats(Map<String, dynamic> state) => {
    'total': state['total'],
    'completed': state['completed'],
    'mistakes': state['mistakes'],
    'finished': (state['queue'] as List).isEmpty,
    'started': state['started'],
  };

  Map<String, dynamic> _problem(Map<String, dynamic> entry) {
    var problem = entry['problem'] as Map<String, dynamic>;
    if (kind == 'math') {
      for (var i = 0; i < (entry['step'] as int); i++) {
        problem = problem['nextStep'] as Map<String, dynamic>;
      }
    }
    return problem;
  }

  void _save(Map<String, dynamic> state) {
    progress?.saveGuestMath(_key, state);
    _memory = state;
  }

  Future<Map<String, dynamic>> load({bool newRound = false}) async {
    if (progress?.signedIn == true) {
      return progress!.practiceRequest(kind, 'exercise', {
        'grade': grade,
        'subject': subject,
        'newRound': newRound,
      });
    }
    var state = progress?.guestMath(_key) ?? _memory;
    if (state == null ||
        state['queue'] == null ||
        (newRound && (state['queue'] as List).isEmpty)) {
      final legacy = state?['exerciseId'] != null ? _copy(state!) : null;
      final previousUsed = state?['used'] ?? <String>[];
      final lastGroup = state?['lastGroup'];
      final count = kind == 'vocabulary' ? min(15, items.length) : 15;
      state = {
        'queue': <Map<String, dynamic>>[],
        'used': previousUsed,
        'lastGroup': lastGroup,
        'total': count,
        'completed': 0,
        'mistakes': 0,
        'started': legacy != null,
      };
      final queue = state['queue'] as List;
      if (legacy != null) {
        // Older guest math snapshots already contain the current step as their root.
        queue.add({
          ...legacy,
          'step': kind == 'math' ? 0 : legacy['step'],
          'revision': 0,
        });
      }
      while (queue.length < count) {
        queue.add(_pick(state));
      }
      _save(state);
    }
    final queue = state['queue'] as List;
    return {
      if (queue.isNotEmpty) ...{
        ...queue.first as Map<String, dynamic>,
        'problem': _problem(queue.first),
      },
      'progress': _stats(state),
      if (kind == 'vocabulary')
        'cards': [
          for (final entry in queue)
            {'id': entry['itemId'], 'data': entry['problem']},
        ],
    };
  }

  Future<Map<String, dynamic>> answer(Map<String, dynamic> request) async {
    if (progress?.signedIn == true) {
      return progress!.practiceRequest(kind, 'answer', request);
    }
    final state = _copy(progress?.guestMath(_key) ?? _memory!);
    final queue = state['queue'] as List;
    final entry = queue.first as Map<String, dynamic>;
    if (entry['exerciseId'] != request['exerciseId'] ||
        entry['step'] != request['step'] ||
        entry['revision'] != request['revision']) {
      throw const MathExerciseChanged();
    }
    final problem = _problem(entry);
    final value = request['answer'];
    final correct = switch (kind) {
      'math' => value == MathProblem.fromJson(problem).answer,
      'spelling' => value == problem[entry['step'] == 0 ? 'letter' : 'reason'],
      _ => VocabularyEntry.fromJson(problem).accepts(value as String),
    };
    final completed =
        correct &&
        switch (kind) {
          'math' => problem['nextStep'] == null,
          'spelling' => entry['step'] == 1,
          _ => true,
        };
    state['started'] = true;
    if (!correct) {
      final extra = _pick(state);
      queue.removeAt(0);
      queue.add(extra);
      entry['step'] = 0;
      entry['revision'] = (entry['revision'] as int) + 1;
      queue.insert(min(3, queue.length), entry);
      state['mistakes'] = (state['mistakes'] as int) + 1;
      state['total'] = (state['total'] as int) + 1;
    } else if (completed) {
      queue.removeAt(0);
      state['completed'] = (state['completed'] as int) + 1;
    } else {
      entry['step'] = (entry['step'] as int) + 1;
    }
    _save(state);
    return {
      'correct': correct,
      'completed': completed,
      'progress': _stats(state),
    };
  }
}
