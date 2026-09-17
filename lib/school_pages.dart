import 'package:flutter/material.dart';
import 'catalog.dart';
import 'main.dart' show PracticePage;
import 'english_page.dart';
import 'school_widgets.dart';
import 'progress_widgets.dart';

class CatalogRoute extends StatelessWidget {
  const CatalogRoute({super.key, required this.path});
  final String path;

  @override
  Widget build(BuildContext context) {
    final controller = CatalogScope.of(context);
    final catalog = controller.data;
    if (catalog == null) {
      return SchoolPage(
        title: 'AAA škola',
        children: [
          const SchoolBrand(),
          if (controller.loading)
            const Center(child: CircularProgressIndicator())
          else ...[
            Text(controller.error ?? 'Nabídka zatím není připravená.'),
            FilledButton(
              onPressed: controller.load,
              child: const Text('Zkusit znovu'),
            ),
          ],
        ],
      );
    }
    if (path == '/') return const HomePage();
    final match = RegExp(r'^/(\d+)-trida(?:/([a-z0-9-]+))?$').firstMatch(path);
    if (match != null) {
      final grade = int.parse(match[1]!);
      final grades = catalog.grades.where((g) => g['id'] == grade);
      if (grades.isNotEmpty) {
        final gradeName = grades.first['name'] as String;
        if (match[2] == null) {
          return GradePage(grade: grade, gradeName: gradeName);
        }
        for (final course in catalog.coursesFor(grade)) {
          final subject = catalog.subject(course['subject'] as String);
          if (subject['slug'] != match[2]) continue;
          if ((course['items'] as List).isEmpty) {
            return SchoolPage(
              title: '${subject['name']} · $gradeName',
              children: const [
                Text('Cvičení se připravuje. Zkus se vrátit později.'),
              ],
            );
          }
          if (subject['kind'] == 'math') {
            return PracticePage(
              grade: grade,
              gradeName: gradeName,
              subject: subject['id'] as String,
              subjectName: subject['name'] as String,
              maxDigits: course['maxDigits'] as int,
              problems: catalog.problems(course),
            );
          }
          return EnglishPage(
            grade: grade,
            gradeName: gradeName,
            subject: subject['id'] as String,
            subjectName: subject['name'] as String,
            answerLanguage: subject['answerLanguage'] as String,
            sourceTitle: course['sourceTitle'] as String,
            entries: catalog.words(course),
          );
        }
      }
    }
    return SchoolPage(
      title: 'Cvičení není dostupné',
      children: [
        const Text('Tato třída nebo předmět už nejsou v nabídce.'),
        TextButton(
          onPressed: () =>
              Navigator.pushNamedAndRemoveUntil(context, '/', (_) => false),
          child: const Text('Zpět do školy'),
        ),
      ],
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = CatalogScope.of(context);
    final catalog = controller.data!;
    return SchoolPage(
      title: 'Vítej ve škole',
      children: [
        const SchoolBrand(),
        const AccountCard(),
        const SizedBox(height: 24),
        const Text(
          'Co dnes procvičíme?',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        const Text(
          'Vyber si třídu. Každý malý krok se počítá.',
          style: TextStyle(fontSize: 16, color: Color(0xFF6E8177)),
        ),
        const SizedBox(height: 28),
        for (final grade in catalog.grades)
          LessonCard(
            title: grade['name'] as String,
            subtitle: catalog
                .coursesFor(grade['id'] as int)
                .map((c) => catalog.subject(c['subject'] as String)['name'])
                .join(' · '),
            icon: Icons.school_outlined,
            onTap: () => Navigator.pushNamed(context, '/${grade['id']}-trida'),
          ),
        if (catalog.grades.isEmpty) const Text('Cvičení se připravují.'),
        if (controller.error != null) Text(controller.error!),
        TextButton.icon(
          onPressed: controller.loading ? null : controller.load,
          icon: const Icon(Icons.refresh),
          label: Text(controller.loading ? 'Načítám…' : 'Obnovit nabídku'),
        ),
      ],
    );
  }
}

class GradePage extends StatelessWidget {
  const GradePage({super.key, required this.grade, required this.gradeName});
  final int grade;
  final String gradeName;
  @override
  Widget build(BuildContext context) {
    final catalog = CatalogScope.of(context).data!;
    final courses = catalog.coursesFor(grade);
    return SchoolPage(
      title: gradeName,
      children: [
        const Text(
          'Vyber si předmět',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        if (courses.isEmpty) const Text('Předměty se připravují.'),
        for (final course in courses)
          LessonCard(
            title:
                catalog.subject(course['subject'] as String)['name'] as String,
            subtitle: course['description'] as String,
            icon: catalog.subject(course['subject'] as String)['kind'] == 'math'
                ? Icons.calculate_outlined
                : Icons.translate_rounded,
            onTap: () => Navigator.pushNamed(
              context,
              '/$grade-trida/${catalog.subject(course['subject'] as String)['slug']}',
            ),
          ),
      ],
    );
  }
}
