import 'package:flutter/material.dart';

import 'school_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => SchoolPage(
    title: 'Vítej ve škole',
    children: [
      const SchoolBrand(),
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
      LessonCard(
        title: '7. třída',
        subtitle: 'Angličtina · slovíčka a fráze',
        icon: Icons.menu_book_rounded,
        onTap: () => Navigator.pushNamed(context, '/7-trida'),
      ),
      LessonCard(
        title: '3. třída',
        subtitle: 'Matematika · mix příkladů',
        icon: Icons.calculate_outlined,
        onTap: () => Navigator.pushNamed(context, '/3-trida'),
      ),
    ],
  );
}

class GradePage extends StatelessWidget {
  const GradePage({super.key, required this.grade});

  final int grade;

  @override
  Widget build(BuildContext context) {
    final english = grade == 7;
    return SchoolPage(
      title: '$grade. třída',
      children: [
        const Text(
          'Vyber si předmět',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        LessonCard(
          title: english ? 'Angličtina' : 'Matematika',
          subtitle: english
              ? 'Introduction · New friends a The exchange students. Kartičky a zkoušení slovíček.'
              : 'Násobilka, dělení, závorky a doplňování čísel. Vše v jednom mixu.',
          icon: english ? Icons.translate_rounded : Icons.calculate_outlined,
          onTap: () => Navigator.pushNamed(
            context,
            english ? '/7-trida/anglictina' : '/3-trida/matematika',
          ),
        ),
      ],
    );
  }
}
