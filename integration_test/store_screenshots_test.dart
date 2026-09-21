import 'package:aaaskola/catalog.dart';
import 'package:aaaskola/main.dart';
import 'package:aaaskola/mobile_platform_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('capture the live Android guest experience', (tester) async {
    final catalog = CatalogController();
    await catalog.load();
    expect(catalog.error, isNull);
    final progress = (await createMobileProgress())!;
    await progress.load();
    expect(progress.signedIn, false);
    await tester.pumpWidget(AaaSkolaApp(progress: progress, catalog: catalog));
    await tester.pumpAndSettle();
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(seconds: 1)),
    );
    await binding.takeScreenshot('01-home');
    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    for (final screen in {
      '02-grade-7': '/7-trida',
      '03-math': '/2-trida/matematika',
      '04-english': '/5-trida/anglictina',
      '05-czech': '/7-trida/cestina',
      '06-german': '/7-trida/nemcina',
    }.entries) {
      navigator.pushNamed(screen.value);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (screen.key == '03-math') {
        await tester.ensureVisible(find.text('Zkontrolovat'));
        await tester.pumpAndSettle();
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(seconds: 1)),
      );
      await binding.takeScreenshot(screen.key);
      navigator.pop();
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox());
    progress.dispose();
    catalog.dispose();
  });
}
