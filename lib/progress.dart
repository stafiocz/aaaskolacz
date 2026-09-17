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

class ProgressController extends ChangeNotifier {
  ProgressController({
    http.Client? client,
    Uri? baseUrl,
    this.enabled = kIsWeb,
    this.readPending = storage.readPending,
    this.writePending = storage.writePending,
    this.openLogin = storage.openLogin,
  }) : _client = client ?? http.Client(),
       _base = baseUrl ?? Uri.base;

  final http.Client _client;
  final Uri _base;
  final bool enabled;
  final String? Function(String) readPending;
  final void Function(String, String) writePending;
  final void Function() openLogin;
  Map<String, dynamic>? user;
  String? _csrf;
  bool ready = false;
  bool loginAvailable = false;
  String? error;
  bool _saving = false;
  bool _loading = false;
  Future<void>? _flush;
  DateTime today = DateTime.now();
  bool _disposed = false;
  Timer? _retry;
  final List<Map<String, dynamic>> _pending = [];
  int get pendingCount => _pending.length;
  bool get signedIn => user != null;

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  Future<void> load() async {
    if (_saving || _loading || _disposed) return;
    if (!enabled) {
      ready = true;
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
      user = body['user'] as Map<String, dynamic>?;
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
    if (signedIn) unawaited(flush());
  }

  void record({
    required String exerciseId,
    required String subject,
    required int grade,
    required bool correct,
    required bool completed,
  }) {
    if (!signedIn) return;
    _pending.add({
      'id': newExerciseId(),
      'exerciseId': exerciseId,
      'subject': subject,
      'grade': grade,
      'correct': correct,
      'completed': completed,
      'occurredAt': DateTime.now().toUtc().toIso8601String(),
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
    _client.close();
    super.dispose();
  }
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
