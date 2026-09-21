import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;

import 'progress_storage.dart' as storage;

String newExerciseId() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

class DailyGoals {
  DailyGoals.fromJson(Map<String, dynamic> data)
    : day = DateTime.parse(data['day'] as String),
      resetsAt = DateTime.parse(data['resetsAt'] as String),
      target = data['target'] as int,
      math = data['math'] as int,
      vocabulary = data['vocabulary'] as int,
      wordIds = (data['wordIds'] as List).cast<String>().toSet();

  final DateTime day;
  final DateTime resetsAt;
  final int target;
  final int math;
  final int vocabulary;
  final Set<String> wordIds;
  bool get completed => math >= target && vocabulary >= target;
}

class ProgressController extends ChangeNotifier {
  ProgressController({
    http.Client? client,
    Uri? baseUrl,
    DateTime Function()? now,
    this.enabled = kIsWeb,
    this.readPending = storage.readPending,
    this.writePending = storage.writePending,
    this.openLogin = storage.openLogin,
    this.nativeLogin,
    this.readPractice = storage.readPractice,
    this.writePractice = storage.writePractice,
  }) : _client = client ?? http.Client(),
       _now = now ?? DateTime.now,
       _base = baseUrl ?? Uri.base;

  final http.Client _client;
  final DateTime Function() _now;
  final Uri _base;
  final bool enabled;
  final String? Function(String) readPending;
  final void Function(String, String) writePending;
  final void Function() openLogin;
  final Future<void> Function()? nativeLogin;
  bool signingIn = false;
  final String? Function(String) readPractice;
  final void Function(String, String?) writePractice;
  final Map<String, Map<String, dynamic>?> _guestMath = {};
  Map<String, dynamic>? user;
  String? _csrf;
  bool ready = false;
  bool sessionResolved = false;
  bool loginAvailable = false;
  String? error;
  bool _saving = false;
  bool _loading = false;
  Future<void>? _flush;
  DateTime today = DateTime.now();
  bool _disposed = false;
  Timer? _retry;
  Timer? _goalsTimer;
  int _goalsVersion = 0;
  DailyGoals? goals;
  String? goalsError;
  final List<Map<String, dynamic>> _pending = [];
  int get pendingCount => _pending.length;
  bool get signedIn => user != null;

  Future<void> signIn() async {
    if (signingIn) return;
    if (nativeLogin == null) {
      openLogin();
      return;
    }
    signingIn = true;
    error = null;
    _changed();
    try {
      await nativeLogin!();
      await load();
    } catch (_) {
      error = 'Přihlášení nebylo dokončeno. Zkus to znovu.';
    } finally {
      signingIn = false;
      _changed();
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_saving || _loading || _disposed) return;
    if (!enabled) {
      ready = true;
      sessionResolved = true;
      _changed();
      return;
    }
    _loading = true;
    try {
      final response = await _client
          .get(_base.resolve('/api/me'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw StateError('Session unavailable');
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      sessionResolved = true;
      final nextUser = body['user'] as Map<String, dynamic>?;
      if (nextUser?['id'] != user?['id']) _clearGoals();
      user = nextUser;
      _csrf = body['csrf'] as String?;
      loginAvailable = body['loginAvailable'] == true;
      today =
          DateTime.tryParse(body['today'] as String? ?? '') ?? DateTime.now();
      _pending.clear();
      if (user != null) {
        final saved = readPending(user!['id'] as String);
        if (saved != null) {
          _pending.addAll(
            (jsonDecode(saved) as List).cast<Map<String, dynamic>>(),
          );
        }
      }
      error = null;
    } catch (_) {
      error = 'Připojení k účtu se nepodařilo. Zkus to znovu.';
    }
    ready = true;
    _loading = false;
    _changed();
    if (signedIn) {
      await flush();
      await refreshGoals();
    }
  }

  void record({
    required String exerciseId,
    required String subject,
    required int grade,
    required bool correct,
    required bool completed,
    String? itemId,
  }) {
    if (!signedIn) return;
    _pending.add({
      'id': newExerciseId(),
      'exerciseId': exerciseId,
      'subject': subject,
      'grade': grade,
      'correct': correct,
      'completed': completed,
      'itemId': ?itemId,
      'occurredAt': _now().toUtc().toIso8601String(),
    });
    _persist();
    _changed();
    unawaited(flush());
  }

  void _persist() {
    try {
      writePending(user!['id'] as String, jsonEncode(_pending));
    } catch (_) {
      error =
          'Úložiště není dostupné. Neobnovuj stránku, dokud se odpovědi neodešlou.';
    }
  }

  Future<void> flush() => _flush ??= _send().whenComplete(() => _flush = null);

  Future<void> _send() async {
    if (_saving || !signedIn || _disposed || _pending.isEmpty) return;
    _saving = true;
    _retry?.cancel();
    try {
      while (_pending.isNotEmpty && signedIn && !_disposed) {
        final response = await _client
            .post(
              _base.resolve('/api/attempts'),
              headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': _csrf!,
              },
              body: jsonEncode(_pending.first),
            )
            .timeout(const Duration(seconds: 15));
        if (response.statusCode == 401 || response.statusCode == 403) {
          _clearGoals();
          user = null;
          _csrf = null;
          error =
              'Přihlášení vypršelo. Přihlas se znovu stejným účtem, aby se čekající výsledky uložily.';
          break;
        }
        if (response.statusCode != 200 && response.statusCode != 201) {
          throw StateError('Save failed');
        }
        _pending.removeAt(0);
        _persist();
      }
      if (_pending.isEmpty) error = null;
    } catch (_) {
      error = 'Výsledky čekají na odeslání. Po obnovení spojení je uložíme.';
      _retry = Timer(const Duration(seconds: 30), () => unawaited(flush()));
    } finally {
      _saving = false;
      _changed();
    }
    if (signedIn) unawaited(refreshGoals());
  }

  void _clearGoals() {
    _goalsVersion++;
    _goalsTimer?.cancel();
    goals = null;
    goalsError = null;
  }

  Future<void> refreshGoals() async {
    if (!enabled || !signedIn || _disposed) return;
    final userId = user!['id'];
    final version = ++_goalsVersion;
    _goalsTimer?.cancel();
    if (goals != null && !_now().toUtc().isBefore(goals!.resetsAt)) {
      goals = null;
      _changed();
    }
    try {
      final response = await _client
          .get(_base.resolve('/api/daily-goals'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) {
        throw StateError('Daily goals unavailable');
      }
      final next = DailyGoals.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>,
      );
      if (_disposed || version != _goalsVersion || user?['id'] != userId) {
        return;
      }
      goals = next;
      today = next.day;
      goalsError = null;
    } catch (_) {
      if (_disposed || version != _goalsVersion || user?['id'] != userId) {
        return;
      }
      goalsError = 'Denní pokrok se nepodařilo obnovit. Zkus to znovu.';
    } finally {
      if (!_disposed && version == _goalsVersion && user?['id'] == userId) {
        var delay = const Duration(minutes: 1);
        final untilReset = goals?.resetsAt.difference(_now().toUtc());
        if (untilReset != null && untilReset < delay) {
          delay = untilReset.isNegative
              ? const Duration(seconds: 1)
              : untilReset;
        }
        _goalsTimer = Timer(delay, () => unawaited(refreshGoals()));
        _changed();
      }
    }
  }

  Future<List<Map<String, dynamic>>> stats(DateTime month) async {
    await flush();
    final first = DateTime(month.year, month.month);
    final last = DateTime(month.year, month.month + 1, 0);
    String date(DateTime value) => value.toIso8601String().substring(0, 10);
    final response = await _client
        .get(
          _base
              .resolve('/api/stats')
              .replace(
                queryParameters: {'from': date(first), 'to': date(last)},
              ),
        )
        .timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw StateError('Statistics unavailable');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    today = DateTime.tryParse(body['today'] as String? ?? '') ?? today;
    _changed();
    return (body['days'] as List).cast<Map<String, dynamic>>();
  }

  Map<String, dynamic>? guestMath(String course) {
    if (!_guestMath.containsKey(course)) {
      final saved = readPractice(course);
      _guestMath[course] = saved == null
          ? null
          : jsonDecode(saved) as Map<String, dynamic>;
    }
    return _guestMath[course];
  }

  void saveGuestMath(String course, Map<String, dynamic>? exercise) {
    writePractice(course, exercise == null ? null : jsonEncode(exercise));
    _guestMath[course] = exercise;
  }

  Future<Map<String, dynamic>> mathRequest(
    String action,
    Map<String, dynamic> body,
  ) => practiceRequest('math', action, body);

  Future<Map<String, dynamic>> practiceRequest(
    String kind,
    String action,
    Map<String, dynamic> body,
  ) async {
    final owner = user?['id'];
    if (owner == null) throw StateError('Sign in required');
    final response = await _client
        .post(
          _base.resolve('/api/$kind/$action'),
          headers: {'Content-Type': 'application/json', 'X-CSRF-Token': _csrf!},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 15));
    if (_disposed || user?['id'] != owner) throw StateError('Account changed');
    if (response.statusCode == 401 || response.statusCode == 403) {
      await load();
      throw StateError('Session expired');
    }
    if (response.statusCode == 409) throw const MathExerciseChanged();
    if (response.statusCode != 200) throw StateError('Practice request failed');
    if (action == 'answer') unawaited(refreshGoals());
    return jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
  }

  Future<void> logout() async {
    if (_saving) {
      error = 'Probíhá ukládání. Za chvíli zkus odhlášení znovu.';
      _changed();
      return;
    }
    await flush();
    if (!signedIn) return;
    try {
      final response = await _client
          .post(_base.resolve('/api/logout'), headers: {'X-CSRF-Token': _csrf!})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 204) throw StateError('Logout failed');
      _retry?.cancel();
      _clearGoals();
      user = null;
      _csrf = null;
      _pending.clear();
      error = null;
    } catch (_) {
      error = 'Odhlášení se nepodařilo. Zkus to znovu.';
    }
    _changed();
  }

  @override
  void dispose() {
    _disposed = true;
    _retry?.cancel();
    _goalsTimer?.cancel();
    _client.close();
    super.dispose();
  }
}

class MathExerciseChanged implements Exception {
  const MathExerciseChanged();
}

class ProgressScope extends InheritedNotifier<ProgressController> {
  const ProgressScope({
    super.key,
    required ProgressController controller,
    required super.child,
  }) : super(notifier: controller);
  static ProgressController? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProgressScope>()?.notifier;
}
