import 'package:flutter/material.dart';

class SchoolBrand extends StatelessWidget {
  const SchoolBrand({super.key});

  @override
  Widget build(BuildContext context) => Row(
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/branding/aaaskola-icon-v3-128.png',
          width: 48,
          height: 48,
          excludeFromSemantics: true,
        ),
      ),
      const SizedBox(width: 12),
      const Flexible(
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'A',
                style: TextStyle(color: Color(0xFF226552)),
              ),
              TextSpan(
                text: 'A',
                style: TextStyle(color: Color(0xFF3C8B72)),
              ),
              TextSpan(
                text: 'A',
                style: TextStyle(color: Color(0xFFC58B24)),
              ),
              TextSpan(text: ' škola'),
            ],
          ),
          semanticsLabel: 'AAA škola',
          style: TextStyle(
            fontFamily: 'Nunito',
            fontSize: 30,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    ],
  );
}

class SchoolPage extends StatelessWidget {
  const SchoolPage({super.key, required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      backgroundColor: const Color(0xFFF3F6EF),
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

class LessonCard extends StatelessWidget {
  const LessonCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Card(
      margin: EdgeInsets.zero,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFE1E8DE)),
        borderRadius: BorderRadius.circular(24),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Row(
            children: [
              Icon(icon, size: 32, color: const Color(0xFF226552)),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 23,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF6E8177),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.arrow_forward_rounded, size: 22),
            ],
          ),
        ),
      ),
    ),
  );
}
