import 'dart:convert';
import 'package:web/web.dart' as web;

final _known = <String, Set<String>>{};

String? readPending(String userId) {
  final store = web.window.localStorage;
  final prefix = 'aaaskola.pending.$userId.';
  final records = <Map<String, dynamic>>[];
  for (var index = 0; index < store.length; index++) {
    final key = store.key(index);
    if (key != null && key.startsWith(prefix)) {
      final value = store.getItem(key);
      if (value != null) records.add(jsonDecode(value) as Map<String, dynamic>);
    }
  }
  records.sort(
    (a, b) => (a['occurredAt'] as String).compareTo(b['occurredAt'] as String),
  );
  _known[userId] = records.map((record) => record['id'] as String).toSet();
  return jsonEncode(records);
}

void writePending(String userId, String value) {
  final store = web.window.localStorage;
  final prefix = 'aaaskola.pending.$userId.';
  final records = (jsonDecode(value) as List).cast<Map<String, dynamic>>();
  final ids = records.map((record) => record['id'] as String).toSet();
  for (final id in (_known[userId] ?? <String>{}).difference(ids)) {
    store.removeItem('$prefix$id');
  }
  for (final record in records) {
    store.setItem('$prefix${record['id']}', jsonEncode(record));
  }
  _known[userId] = ids;
}

void openLogin() => web.window.location.assign('/login');

String? readPractice(String course) =>
    web.window.localStorage.getItem('aaaskola.math.guest.$course');

void writePractice(String course, String? value) {
  final key = 'aaaskola.math.guest.$course';
  if (value == null) {
    web.window.localStorage.removeItem(key);
  } else {
    web.window.localStorage.setItem(key, value);
  }
}
