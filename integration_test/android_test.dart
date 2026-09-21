import 'package:aaaskola/catalog.dart';
import 'package:aaaskola/main.dart';
import 'package:aaaskola/mobile_platform_native.dart';
import 'package:aaaskola/test_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Android loads live classes and preserves a guest test across app initialization',
    (tester) async {
      const secure = FlutterSecureStorage();
      await secure.write(key: 'integration-probe', value: 'encrypted-value');
      expect(await secure.read(key: 'integration-probe'), 'encrypted-value');
      await secure.delete(key: 'integration-probe');

      final catalog = CatalogController();
      await catalog.load();
      expect(catalog.error, isNull);
      expect(
        catalog.data!.grades.map((grade) => grade['id']),
        containsAll([2, 3, 5, 7]),
      );
      final progress = (await createMobileProgress())!;
      await progress.load();
      expect(progress.sessionResolved, true);
      expect(progress.loginAvailable, true);
      expect(progress.signedIn, false);
      final course = catalog.data!.courses.singleWhere(
        (c) => c['grade'] == 2 && c['subject'] == 'math',
      );
      final items = (course['items'] as List).cast<Map<String, dynamic>>();
      expect(items.length, greaterThanOrEqualTo(15));
      final test = TestSession(
        progress: progress,
        kind: 'math',
        grade: 2,
        subject: 'math',
        items: items,
      );
      final first = await test.load();
      await tester.pumpWidget(
        AaaSkolaApp(progress: progress, catalog: catalog),
      );
      await tester.pumpAndSettle();
      expect(find.text('2. třída'), findsOneWidget);
      expect(find.text('Přihlásit se přes Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      progress.dispose();

      final reopened = (await createMobileProgress())!;
      await reopened.load();
      final resumed = await TestSession(
        progress: reopened,
        kind: 'math',
        grade: 2,
        subject: 'math',
        items: items,
      ).load();
      expect(resumed['exerciseId'], first['exerciseId']);
      expect(resumed['problem'], first['problem']);
      expect(resumed['progress'], first['progress']);
      reopened.dispose();
      catalog.dispose();
    },
  );
}
