import 'dart:io';

import 'package:aaaskola/mobile_client.dart';
import 'package:aaaskola/mobile_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test(
    'mobile requests keep credentials on the API origin and logout clears them',
    () async {
      final base = Uri.parse('https://aaaskola.cz');
      String? token = 'secret';
      var sent = 0;
      final client = MobileClient(
        base: base,
        readToken: () async => token,
        clearToken: () async {
          token = null;
        },
        client: MockClient((request) async {
          sent++;
          expect(request.headers['Authorization'], 'Bearer secret');
          expect(request.followRedirects, false);
          return http.Response(
            '',
            request.url.path == '/api/logout' ? 204 : 200,
          );
        }),
      );
      await client.get(base.resolve('/api/me'));
      await expectLater(
        client.get(Uri.parse('https://other.test/api/me')),
        throwsStateError,
      );
      expect(sent, 1);
      await client.post(base.resolve('/api/logout'));
      expect(token, isNull);
      client.close();
    },
  );

  test(
    'mobile practice survives reopening and keeps separate courses and users',
    () {
      final directory = Directory.systemTemp.createTempSync('aaaskola-test-');
      addTearDown(() => directory.deleteSync(recursive: true));
      final file = File('${directory.path}/practice.json');
      final first = MobilePracticeStorage(file);
      expect(first.read('practice.math'), isNull);
      first.write('practice.math', 'unfinished test');
      first.write('practice.german', 'vocabulary');
      first.write('pending.alice', 'answer');
      final reopened = MobilePracticeStorage(file);
      expect(reopened.read('practice.math'), 'unfinished test');
      expect(reopened.read('practice.german'), 'vocabulary');
      expect(reopened.read('pending.bob'), isNull);
      reopened.write('pending.alice', null);
      expect(first.read('pending.alice'), isNull);
      expect(first.read('practice.math'), 'unfinished test');
    },
  );
}
