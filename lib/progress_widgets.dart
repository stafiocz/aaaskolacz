import 'package:flutter/material.dart';

import 'progress.dart';
import 'school_widgets.dart';

class AccountCard extends StatelessWidget {
  const AccountCard({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    if (progress == null || !progress.enabled) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!progress.ready)
              const Text('Načítám účet…')
            else if (progress.signedIn) ...[
              Text(
                progress.user!['name'] as String,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(progress.user!['email'] as String),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.pushNamed(context, '/vysledky'),
                icon: const Icon(Icons.bar_chart_rounded),
                label: const Text('Moje výsledky'),
              ),
              TextButton(
                onPressed: progress.logout,
                child: const Text('Odhlásit se'),
              ),
            ] else ...[
              const Text(
                'Každý den uvidíš, jak se ti daří.',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: progress.loginAvailable ? progress.openLogin : null,
                child: const Text('Přihlásit se přes Google'),
              ),
              Text(
                progress.loginAvailable
                    ? 'Bez přihlášení můžeš procvičovat, výsledky se ale neukládají.'
                    : 'Přihlašování zatím není připravené. Procvičovat můžeš bez ukládání.',
              ),
            ],
            if (progress.error != null) ...[
              const SizedBox(height: 8),
              Text(
                progress.error!,
                style: const TextStyle(color: Color(0xFFAD552B)),
              ),
              TextButton(
                onPressed: progress.signedIn ? progress.flush : progress.load,
                child: const Text('Zkusit znovu'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class SaveStatus extends StatelessWidget {
  const SaveStatus({super.key});

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    if (progress == null || !progress.enabled) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        progress.error ??
            (!progress.ready
                ? 'Načítám účet…'
                : !progress.signedIn
                ? 'Procvičuješ bez ukládání. Pro denní přehled se přihlas na úvodu.'
                : progress.pendingCount > 0
                ? 'Čeká na uložení: ${progress.pendingCount}'
                : 'Výsledky se ukládají k tvému účtu.'),
        style: TextStyle(
          fontSize: 12,
          color: progress.error == null
              ? const Color(0xFF6E8177)
              : const Color(0xFFAD552B),
        ),
      ),
    );
  }
}

class ResultsPage extends StatefulWidget {
  const ResultsPage({super.key});
  @override
  State<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends State<ResultsPage> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);
  Future<List<Map<String, dynamic>>>? _result;
  String? _userId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final progress = ProgressScope.of(context);
    if (progress?.signedIn == true && _userId != progress!.user!['id']) {
      _userId = progress.user!['id'] as String;
      _month = DateTime(progress.today.year, progress.today.month);
      _result = progress.stats(_month);
    }
  }

  void _reload([int offset = 0]) => setState(() {
    _month = DateTime(_month.year, _month.month + offset);
    _result = ProgressScope.of(context)!.stats(_month);
  });

  @override
  Widget build(BuildContext context) {
    final progress = ProgressScope.of(context);
    if (progress?.signedIn != true) {
      return const SchoolPage(
        title: 'Moje výsledky',
        children: [AccountCard()],
      );
    }
    final now = progress!.today;
    final isCurrent = _month.year == now.year && _month.month == now.month;
    return SchoolPage(
      title: 'Moje výsledky',
      children: [
        Text(
          progress.user!['name'] as String,
          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
        ),
        const SaveStatus(),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              onPressed: () => _reload(-1),
              tooltip: 'Předchozí měsíc',
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${_month.month}. ${_month.year}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: isCurrent ? null : () => _reload(1),
              tooltip: 'Další měsíc',
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton(
              onPressed: _reload,
              tooltip: 'Obnovit výsledky',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const Text(
          'Správně a chybně = potvrzené odpovědi, včetně oprav. „Nevím“ je chybná odpověď. Dokončený příklad se počítá jednou; řetězec až po obou krocích. Dny jsou podle českého času.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        FutureBuilder<List<Map<String, dynamic>>>(
          future: _result,
          builder: (context, snapshot) {
            if (snapshot.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Column(
                children: [
                  const Text('Výsledky se nepodařilo načíst.'),
                  TextButton(
                    onPressed: _reload,
                    child: const Text('Zkusit znovu'),
                  ),
                ],
              );
            }
            final rows = snapshot.data ?? [];
            final maxDay = isCurrent
                ? now.day
                : DateTime(_month.year, _month.month + 1, 0).day;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _totals('Celý měsíc', rows),
                for (var day = maxDay; day >= 1; day--) ...[
                  const SizedBox(height: 10),
                  _totals(
                    '$day. ${_month.month}. ${_month.year}',
                    rows
                        .where(
                          (r) =>
                              r['day'] ==
                              '${_month.year}-${_month.month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}',
                        )
                        .toList(),
                  ),
                ],
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _totals(String title, List<Map<String, dynamic>> rows) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          if (rows.isEmpty)
            const Text('Zatím žádné procvičování.')
          else
            for (final subject in ['math', 'english'])
              for (final grade in [3, 5, 7])
                if (rows.any(
                  (r) => r['subject'] == subject && r['grade'] == grade,
                )) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${subject == 'math' ? 'Matematika' : 'Angličtina'} · $grade. třída',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    _counts(
                      rows.where(
                        (r) => r['subject'] == subject && r['grade'] == grade,
                      ),
                      subject,
                    ),
                  ),
                ],
        ],
      ),
    ),
  );

  String _counts(Iterable<Map<String, dynamic>> rows, String subject) {
    int sum(String key) => rows.fold(0, (total, r) => total + (r[key] as int));
    return '${subject == 'math' ? 'Dokončeno příkladů' : 'Zvládnuto slovíček'}: ${sum('completed')}\nSprávně: ${sum('correct')}   ·   Chybně: ${sum('incorrect')}';
  }
}
