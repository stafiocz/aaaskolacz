import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'math_problem.dart';
import 'school_pages.dart';
import 'catalog.dart';
import 'progress.dart';
import 'progress_widgets.dart';

void main() => runApp(const AaaSkolaApp());

const _green = Color(0xFF226552);
const _ink = Color(0xFF243C34);
const _muted = Color(0xFF6E8177);
const _background = Color(0xFFF3F6EF);

class AaaSkolaApp extends StatefulWidget {
  const AaaSkolaApp({super.key, this.progress, this.catalog});

  final ProgressController? progress;
  final CatalogController? catalog;

  @override
  State<AaaSkolaApp> createState() => _AaaSkolaAppState();
}

class _AaaSkolaAppState extends State<AaaSkolaApp> with WidgetsBindingObserver {
  late final _catalog = widget.catalog ?? CatalogController();
  late final _progress = widget.progress ?? ProgressController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _progress.load();
    if (_catalog.data == null) _catalog.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.progress == null) _progress.dispose();
    if (widget.catalog == null) _catalog.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _progress.refreshGoals();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AAA škola',
      debugShowCheckedModeBanner: false,
      builder: (context, child) => ProgressScope(
        controller: _progress,
        child: CatalogScope(controller: _catalog, child: child!),
      ),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _green),
        scaffoldBackgroundColor: _background,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: _ink,
          displayColor: _ink,
        ),
        useMaterial3: true,
      ),
      onGenerateRoute: (settings) => MaterialPageRoute(
        settings: settings,
        builder: (_) => settings.name == '/vysledky'
            ? const ResultsPage()
            : CatalogRoute(path: settings.name ?? '/'),
      ),
    );
  }
}

class PracticePage extends StatefulWidget {
  const PracticePage({
    super.key,
    required this.grade,
    required this.problems,
    this.subject = 'math',
    this.subjectName = 'Matematika',
    this.maxDigits = 3,
    this.gradeName,
  });

  final int grade;
  final String? gradeName;
  final String subject;
  final String subjectName;
  final int maxDigits;
  final List<MathProblem> problems;

  @override
  State<PracticePage> createState() => _PracticePageState();
}

class _PracticePageState extends State<PracticePage> {
  late final _practice = MixedPractice(problems: widget.problems);
  final _keyboardFocus = FocusNode();
  late MathProblem _problem;
  String _answer = '';
  bool _incorrect = false;
  bool _solved = false;
  int _correctCount = 0;
  String _exerciseId = newExerciseId();

  @override
  void initState() {
    super.initState();
    _problem = _practice.next();
  }

  @override
  void dispose() {
    _keyboardFocus.dispose();
    super.dispose();
  }

  void _digit(String digit) {
    if (_solved) return;
    setState(() {
      if (_incorrect || _answer == '0') _answer = '';
      _incorrect = false;
      if (_answer.length < widget.maxDigits) _answer += digit;
    });
  }

  void _erase({bool all = false}) {
    if (_solved) return;
    setState(() {
      _incorrect = false;
      _answer = all || _answer.isEmpty
          ? ''
          : _answer.substring(0, _answer.length - 1);
    });
  }

  void _submit() {
    if (_solved) {
      setState(() {
        if (_problem.nextStep == null) _exerciseId = newExerciseId();
        _problem = _problem.nextStep ?? _practice.next();
        _answer = '';
        _incorrect = false;
        _solved = false;
      });
    } else if (_answer.isNotEmpty) {
      setState(() {
        _solved = int.parse(_answer) == _problem.answer;
        _incorrect = !_solved;
        if (_solved && _problem.nextStep == null) _correctCount++;
      });
      ProgressScope.of(context)?.record(
        exerciseId: _exerciseId,
        subject: widget.subject,
        grade: widget.grade,
        correct: _solved,
        completed: _solved && _problem.nextStep == null,
      );
    }
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final character = event.character;
    if (character != null && RegExp(r'^[0-9]$').hasMatch(character)) {
      _digit(character);
    } else if (key == LogicalKeyboardKey.backspace) {
      _erase();
    } else if (key == LogicalKeyboardKey.delete ||
        key == LogicalKeyboardKey.escape) {
      _erase(all: true);
    } else if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      _submit();
    } else {
      return KeyEventResult.ignored;
    }
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _incorrect ? const Color(0xFFAD552B) : _green;
    final feedback = _solved
        ? 'Výborně! To je správně.'
        : _incorrect
        ? 'To ještě není ono. Zkus to znovu.'
        : _problem.instruction ?? 'Napiš výsledek a potvrď ho.';

    return Scaffold(
      body: Focus(
        focusNode: _keyboardFocus,
        autofocus: true,
        onKeyEvent: _onKey,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxHeight < 800;
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: compact ? 12 : 28,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SaveStatus(),
                        const DailyGoalsCard(kind: 'math'),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(Icons.arrow_back_rounded),
                            label: Text(
                              '${widget.subjectName} · ${widget.gradeName ?? '${widget.grade}. třída'}',
                            ),
                          ),
                        ),
                        Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: Image.asset(
                                'assets/branding/aaaskola-icon-v3-128.png',
                                width: 42,
                                height: 42,
                                excludeFromSemantics: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'A',
                                        style: TextStyle(color: _green),
                                      ),
                                      TextSpan(
                                        text: 'A',
                                        style: TextStyle(
                                          color: Color(0xFF3C8B72),
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'A',
                                        style: TextStyle(
                                          color: Color(0xFFC58B24),
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' škola',
                                        style: TextStyle(
                                          color: _ink,
                                          fontSize: 27,
                                          fontWeight: FontWeight.w700,
                                          fontVariations: [
                                            FontVariation('wght', 700),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  semanticsLabel: 'AAA škola',
                                  style: TextStyle(
                                    fontFamily: 'Nunito',
                                    fontSize: 30,
                                    fontWeight: FontWeight.w900,
                                    fontVariations: [
                                      FontVariation('wght', 900),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE3EBDD),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'MIX',
                                style: TextStyle(
                                  color: _green,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 14),
                          const Text(
                            'Malé kroky, velké pokroky.',
                            style: TextStyle(color: _muted, fontSize: 16),
                          ),
                        ],
                        SizedBox(height: compact ? 16 : 26),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: EdgeInsets.all(compact ? 16 : 24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(26),
                            border: Border.all(
                              color: _solved
                                  ? const Color(0xFF9ACCB1)
                                  : const Color(0xFFE1E8DE),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 12,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    _problem.heading,
                                    style: const TextStyle(
                                      color: _muted,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.8,
                                    ),
                                  ),
                                  Text(
                                    'Správně: $_correctCount',
                                    key: const ValueKey('score'),
                                    style: const TextStyle(
                                      color: _green,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: compact ? 16 : 22),
                              if (widget.maxDigits > 3) ...[
                                Text(
                                  _problem.question,
                                  key: const ValueKey('problem'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                _answerBox(statusColor, compact),
                              ] else
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _problem.beforeAnswer,
                                        key: const ValueKey('problem'),
                                        style: const TextStyle(
                                          fontSize: 46,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      _answerBox(statusColor, compact),
                                      if (_problem.afterAnswer.isNotEmpty) ...[
                                        const SizedBox(width: 12),
                                        Text(
                                          _problem.afterAnswer,
                                          key: const ValueKey('problem-suffix'),
                                          style: const TextStyle(
                                            fontSize: 46,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              SizedBox(height: compact ? 14 : 20),
                              Semantics(
                                liveRegion: true,
                                child: Text(
                                  feedback,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: _solved || _incorrect
                                        ? statusColor
                                        : _muted,
                                    fontSize: 14,
                                    fontWeight: _solved
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                  ),
                                ),
                              ),
                              if (_solved && _problem.verification != null) ...[
                                const SizedBox(height: 12),
                                Text(
                                  'Zkouška: ${_problem.verification}',
                                  key: const ValueKey('verification'),
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    color: _green,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 16 : 22),
                        for (final row in [
                          ['1', '2', '3'],
                          ['4', '5', '6'],
                          ['7', '8', '9'],
                          ['C', '0', '⌫'],
                        ])
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Row(
                              children: [
                                for (var index = 0; index < row.length; index++)
                                  Expanded(
                                    child: Padding(
                                      padding: EdgeInsets.only(
                                        left: index == 0 ? 0 : 5,
                                        right: index == 2 ? 0 : 5,
                                      ),
                                      child: _KeyButton(
                                        label: row[index],
                                        height: compact ? 50 : 62,
                                        onPressed: _solved
                                            ? null
                                            : () {
                                                final key = row[index];
                                                if (key == 'C') {
                                                  _erase(all: true);
                                                } else if (key == '⌫') {
                                                  _erase();
                                                } else {
                                                  _digit(key);
                                                }
                                              },
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 4),
                        FilledButton.icon(
                          key: const ValueKey('submit'),
                          onPressed: _answer.isEmpty ? null : _submit,
                          icon: Icon(
                            _solved
                                ? Icons.arrow_forward_rounded
                                : Icons.check_rounded,
                            size: 23,
                          ),
                          label: Text(
                            !_solved
                                ? 'Zkontrolovat'
                                : _problem.nextStep != null
                                ? 'Další krok'
                                : 'Další příklad',
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _green,
                            foregroundColor: Colors.white,
                            minimumSize: Size.fromHeight(compact ? 52 : 58),
                            textStyle: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                        ),
                        if (!compact) ...[
                          const SizedBox(height: 20),
                          const Text(
                            'V klidu. Každý příklad se počítá.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: _muted, fontSize: 13),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _answerBox(Color statusColor, bool compact) => Semantics(
    label: _problem.afterAnswer.isNotEmpty
        ? 'Chybějící číslo'
        : 'Tvoje odpověď',
    value: _answer.isEmpty ? 'Prázdná' : _answer,
    excludeSemantics: true,
    child: Container(
      width: widget.maxDigits > 3
          ? double.infinity
          : compact
          ? 80
          : 96,
      height: compact ? 64 : 76,
      padding: EdgeInsets.symmetric(horizontal: widget.maxDigits > 3 ? 12 : 0),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _incorrect ? const Color(0xFFFFF1E7) : const Color(0xFFEDF5EE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: _incorrect ? const Color(0xFFDAA078) : const Color(0xFFB8D6BF),
          width: 1.5,
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          _answer.isEmpty
              ? '?'
              : widget.maxDigits > 3
              ? formatMathNumber(int.parse(_answer))
              : _answer,
          key: const ValueKey('answer'),
          style: TextStyle(
            color: _answer.isEmpty ? const Color(0xFF95B69E) : statusColor,
            fontSize: 38,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    ),
  );
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.label,
    required this.height,
    required this.onPressed,
  });

  final String label;
  final double height;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final utility = label == 'C' || label == '⌫';
    return Semantics(
      label: label == 'C'
          ? 'Vymazat vše'
          : label == '⌫'
          ? 'Smazat poslední číslici'
          : label,
      excludeSemantics: true,
      button: true,
      enabled: onPressed != null,
      onTap: onPressed,
      child: OutlinedButton(
        key: ValueKey('key-$label'),
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: utility ? const Color(0xFFE8EDE3) : Colors.white,
          foregroundColor: utility ? _muted : _ink,
          disabledForegroundColor: const Color(0xFFABB7AD),
          minimumSize: Size.fromHeight(height),
          padding: EdgeInsets.zero,
          side: BorderSide(
            color: utility ? Colors.transparent : const Color(0xFFDDE5D9),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(17),
          ),
          textStyle: TextStyle(
            fontSize: utility ? 21 : 27,
            fontWeight: FontWeight.w600,
          ),
        ),
        child: label == '⌫'
            ? const Icon(Icons.backspace_outlined, size: 24)
            : Text(label),
      ),
    );
  }
}
