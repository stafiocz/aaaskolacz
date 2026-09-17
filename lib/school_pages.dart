import 'package:flutter/material.dart';

import 'school_widgets.dart';
import 'progress_widgets.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) => SchoolPage(
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
      LessonCard(
        title: '7. třída',
        subtitle: 'Angličtina · slovíčka a fráze',
        icon: Icons.menu_book_rounded,
        onTap: () => Navigator.pushNamed(context, '/7-trida'),
      ),
      LessonCard(
        title: '5. třída',
        subtitle: 'Matematika a angličtina',
        icon: Icons.calculate_outlined,
        onTap: () => Navigator.pushNamed(context, '/5-trida'),
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
    return SchoolPage(
      title: '$grade. třída',
      children: [
        const Text(
          'Vyber si předmět',
          style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 24),
        if (grade == 3 || grade == 5)
          LessonCard(
            title: 'Matematika',
            subtitle: grade == 5
                ? 'Miliony · sčítání, odčítání, násobení, dělení a početní řetězce. Vše v jednom mixu.'
                : 'Násobilka, dělení, závorky a doplňování čísel. Vše v jednom mixu.',
            icon: Icons.calculate_outlined,
            onTap: () =>
                Navigator.pushNamed(context, '/$grade-trida/matematika'),
          ),
        if (grade == 5 || grade == 7)
          LessonCard(
            title: 'Angličtina',
            subtitle: grade == 7
                ? 'Introduction · New friends a The exchange students. Kartičky a zkoušení slovíček.'
                : 'Introduction a Me! · Škola, barvy, rodina a další slovíčka z učebnice. Kartičky a zkoušení.',
            icon: Icons.translate_rounded,
            onTap: () =>
                Navigator.pushNamed(context, '/$grade-trida/anglictina'),
          ),
      ],
    );
  }
}
