import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aaaskola/progress.dart';
import 'daily_goals_fixture.dart';

void main() {
  final saved = <String, String>{};
  String account = 'alice';
  int status = 201;
  final sent = <Map<String, dynamic>>[];
  late ProgressController controller;
  setUp(() {
    saved.clear();
    sent.clear();
    account = 'alice';
    status = 201;
    controller = ProgressController(
      enabled: true,
      baseUrl: Uri.parse('https://aaaskola.cz'),
      readPending: (user) => saved[user],
      writePending: (user, data) => saved[user] = data,
      client: MockClient((request) async {
        if (request.url.path == '/api/daily-goals') {
          return http.Response(jsonEncode(goalsData()), 200);
        }
        if (request.url.path == '/api/me') {
          return http.Response(
            jsonEncode({
              'user': {
                'id': account,
                'name': account,
                'email': '$account@example.test',
              },
              'csrf': 'csrf-$account',
              'loginAvailable': true,
              'today': '2026-09-17',
            }),
            200,
          );
        }
        if (request.url.path == '/api/attempts') {
          sent.add(jsonDecode(request.body) as Map<String, dynamic>);
          return http.Response('{}', status);
        }
        return http.Response('{}', 204);
      }),
    );
  });
  tearDown(() => controller.dispose());
  void answer() => controller.record(
    exerciseId: newExerciseId(),
    subject: 'math',
    grade: 5,
    correct: false,
    completed: false,
  );

  test(
    'guest answers are not recorded or later assigned to a signed-in user',
    () async {
      answer();
      expect(controller.pendingCount, 0);
      await controller.load();
      await controller.flush();
      expect(sent, isEmpty);
    },
  );
  test(
    'persists offline attempts before sending and retries the same ID exactly',
    () async {
      await controller.load();
      await controller.flush();
      status = 503;
      answer();
      await controller.flush();
      expect(controller.pendingCount, 1);
      expect((jsonDecode(saved['alice']!) as List).length, 1);
      final id = sent.single['id'];
      status = 201;
      await controller.flush();
      expect(sent.last['id'], id);
      expect(controller.pendingCount, 0);
      expect(jsonDecode(saved['alice']!), isEmpty);
    },
  );
  test(
    'session change never sends an old account queue under the new account',
    () async {
      await controller.load();
      await controller.flush();
      status = 403;
      answer();
      await controller.flush();
      expect(controller.signedIn, false);
      expect(jsonDecode(saved['alice']!), hasLength(1));
      account = 'bob';
      status = 201;
      await controller.load();
      await controller.flush();
      expect(controller.pendingCount, 0);
      expect(sent, hasLength(1));
      answer();
      await controller.flush();
      expect(jsonDecode(saved['alice']!), hasLength(1));
      account = 'alice';
      await controller.load();
      await controller.flush();
      expect(sent, hasLength(3));
      expect(sent.first['id'], sent.last['id']);
      expect(jsonDecode(saved['alice']!), isEmpty);
    },
  );
  test('waiting for flush waits for the ongoing request', () async {
    controller.dispose();
    final completion = Completer<http.Response>();
    controller = ProgressController(
      enabled: true,
      baseUrl: Uri.parse('https://aaaskola.cz'),
      readPending: (_) => null,
      writePending: (_, _) {},
      client: MockClient(
        (request) async => request.url.path == '/api/me'
            ? http.Response(
                '{"user":{"id":"alice"},"csrf":"csrf","loginAvailable":true}',
                200,
              )
            : request.url.path == '/api/daily-goals'
            ? http.Response(jsonEncode(goalsData()), 200)
            : completion.future,
      ),
    );
    await controller.load();
    await controller.flush();
    answer();
    var finished = false;
    final pending = controller.flush().then((_) => finished = true);
    await Future<void>.delayed(Duration.zero);
    expect(finished, false);
    completion.complete(http.Response('{}', 201));
    await pending;
    expect(finished, true);
    expect(controller.pendingCount, 0);
  });
}
