class VocabularyEntry {
  const VocabularyEntry(
    this.english,
    this.czech,
    this.topic,
    this.page, {
    this.alternatives = const [],
  });

  final String english;
  final String czech;
  final String topic;
  final int page;
  final List<String> alternatives;

  factory VocabularyEntry.fromJson(Map<String, dynamic> data) =>
      VocabularyEntry(
        data['english'] as String,
        data['czech'] as String,
        data['topic'] as String,
        data['page'] as int,
        alternatives: (data['alternatives'] as List).cast<String>(),
      );

  bool accepts(String answer) {
    final normalized = normalizeAnswer(answer);
    return [
      english,
      ...alternatives,
    ].any((value) => normalizeAnswer(value) == normalized);
  }
}

String normalizeAnswer(String answer) => answer
    .trim()
    .toLowerCase()
    .replaceAll(RegExp('[’‘]'), "'")
    .replaceAll(RegExp(r'[.!?,]+$'), '')
    .replaceAll(RegExp(r'[-–]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();
