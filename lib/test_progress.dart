import 'package:flutter/material.dart';

const retryFeedback =
    'Úloha se vrátí po několika dalších zadáních. Za chybu přibyla jedna nová úloha.';

class TestProgress extends StatelessWidget {
  const TestProgress({
    super.key,
    required this.progress,
    required this.onNewRound,
  });
  final Map<String, dynamic>? progress;
  final VoidCallback? onNewRound;

  @override
  Widget build(BuildContext context) {
    if (progress == null) return const SizedBox.shrink();
    final done = progress!['finished'] == true;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            done
                ? 'Kolo je hotové!'
                : 'TEST · Hotovo ${progress!['completed']} / ${progress!['total']}',
            key: const Key('test-progress'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Chyby: ${progress!['mistakes']} · Úlohy navíc: ${progress!['mistakes']}',
          ),
          if (done) ...[
            const SizedBox(height: 16),
            FilledButton(
              onPressed: onNewRound,
              child: const Text('Začít další kolo'),
            ),
          ],
        ],
      ),
    );
  }
}
