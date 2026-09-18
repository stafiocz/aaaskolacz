import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'math_problem.dart';
import 'vocabulary.dart';

class SchoolCatalog {
  SchoolCatalog.fromJson(Map<String, dynamic> json)
    : grades = (json['grades'] as List).cast<Map<String, dynamic>>(),
      subjects = (json['subjects'] as List).cast<Map<String, dynamic>>(),
      courses = (json['courses'] as List).cast<Map<String, dynamic>>();
  final List<Map<String, dynamic>> grades;
  final List<Map<String, dynamic>> subjects;
  final List<Map<String, dynamic>> courses;

  Map<String, dynamic> subject(String id) =>
      subjects.singleWhere((s) => s['id'] == id);
  List<Map<String, dynamic>> coursesFor(int grade) =>
      courses.where((c) => c['grade'] == grade).toList();
  List<MathProblem> problems(Map<String, dynamic> course) => [
    for (final item in course['items'] as List)
      MathProblem.fromJson(item['data'] as Map<String, dynamic>),
  ];
  List<VocabularyEntry> words(Map<String, dynamic> course) => [
    for (final item in course['items'] as List)
      VocabularyEntry.fromJson(
        item['data'] as Map<String, dynamic>,
        id: item['id'] as String,
      ),
  ];
}

class CatalogController extends ChangeNotifier {
  CatalogController({http.Client? client, Uri? baseUrl, SchoolCatalog? initial})
    : _client = client ?? http.Client(),
      _base =
          baseUrl ??
          (Uri.base.hasScheme && Uri.base.scheme.startsWith('http')
              ? Uri.base
              : Uri.parse('https://aaaskola.cz')),
      data = initial;
  final http.Client _client;
  final Uri _base;
  SchoolCatalog? data;
  bool loading = false;
  String? error;
  bool _disposed = false;

  Future<void> load() async {
    if (loading || _disposed) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final response = await _client
          .get(_base.resolve('/api/catalog'))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) throw StateError('Catalog unavailable');
      final next = SchoolCatalog.fromJson(
        jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>,
      );
      if (!_disposed) data = next;
    } catch (_) {
      if (!_disposed) {
        error =
            'Nabídku cvičení se nepodařilo načíst. Zkontroluj připojení a zkus to znovu.';
      }
    } finally {
      loading = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _client.close();
    super.dispose();
  }
}

class CatalogScope extends InheritedNotifier<CatalogController> {
  const CatalogScope({
    super.key,
    required CatalogController controller,
    required super.child,
  }) : super(notifier: controller);
  static CatalogController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CatalogScope>()!.notifier!;
}
