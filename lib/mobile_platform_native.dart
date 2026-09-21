import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_web_auth_2/flutter_web_auth_2.dart';
import 'package:path_provider/path_provider.dart';

import 'mobile_client.dart';
import 'mobile_storage.dart';
import 'progress.dart';

Future<ProgressController?> createMobileProgress() async {
  if (!Platform.isAndroid) return null;
  final base = Uri.parse('https://aaaskola.cz');
  const secure = FlutterSecureStorage();
  final directory = await getApplicationSupportDirectory();
  final storage = MobilePracticeStorage(
    File('${directory.path}/practice.json'),
  );
  final client = MobileClient(
    base: base,
    readToken: () => secure.read(key: 'session'),
    clearToken: () => secure.delete(key: 'session'),
  );
  String randomToken() => List.generate(
    32,
    (_) => Random.secure().nextInt(256),
  ).map((n) => n.toRadixString(16).padLeft(2, '0')).join();
  return ProgressController(
    enabled: true,
    baseUrl: base,
    client: client,
    readPending: (user) => storage.read('pending.$user'),
    writePending: (user, value) => storage.write('pending.$user', value),
    readPractice: (course) => storage.read('practice.$course'),
    writePractice: (course, value) => storage.write('practice.$course', value),
    nativeLogin: () async {
      final verifier = randomToken(), state = randomToken();
      final login = base
          .resolve('/login')
          .replace(
            queryParameters: {
              'mobile_challenge': sha256
                  .convert(utf8.encode(verifier))
                  .toString(),
              'state': state,
            },
          );
      final callback = Uri.parse(
        await FlutterWebAuth2.authenticate(
          url: login.toString(),
          callbackUrlScheme: 'cz.aaaskola.app',
        ),
      );
      if (callback.scheme != 'cz.aaaskola.app' ||
          callback.path != '/login' ||
          callback.queryParameters['state'] != state ||
          !RegExp(
            r'^[a-f0-9]{64}$',
          ).hasMatch(callback.queryParameters['code'] ?? '')) {
        throw StateError('Invalid login callback');
      }
      final response = await client
          .post(
            base.resolve('/api/auth/mobile'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'code': callback.queryParameters['code'],
              'verifier': verifier,
            }),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw StateError('Login exchange failed');
      final token =
          (jsonDecode(response.body) as Map<String, dynamic>)['token']
              as String;
      if (!RegExp(r'^[a-f0-9]{64}$').hasMatch(token)) {
        throw StateError('Invalid session');
      }
      await secure.write(key: 'session', value: token);
    },
  );
}
