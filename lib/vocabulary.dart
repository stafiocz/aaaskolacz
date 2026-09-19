class VocabularyEntry {
  const VocabularyEntry(
    this.english,
    this.czech,
    this.topic,
    this.page, {
    this.id,
    this.alternatives = const [],
    this.exerciseType = 'vocabulary',
    this.instruction,
    this.explanation,
    this.caseSensitive = false,
  });

  final String english;
  final String? id;
  final String czech;
  final String topic;
  final int page;
  final List<String> alternatives;
  final String exerciseType;
  final String? instruction;
  final String? explanation;
  final bool caseSensitive;
  bool get isGrammar => exerciseType == 'grammar';

  Map<String, dynamic> toJson() => {
    'english': english,
    'czech': czech,
    'topic': topic,
    'page': page,
    'alternatives': alternatives,
    'exerciseType': exerciseType,
    if (instruction != null) 'instruction': instruction,
    if (explanation != null) 'explanation': explanation,
    'caseSensitive': caseSensitive,
  };

  factory VocabularyEntry.fromJson(Map<String, dynamic> data, {String? id}) =>
      VocabularyEntry(
        data['english'] as String,
        data['czech'] as String,
        data['topic'] as String,
        data['page'] as int,
        id: id,
        alternatives: (data['alternatives'] as List).cast<String>(),
        exerciseType: data['exerciseType'] as String? ?? 'vocabulary',
        instruction: data['instruction'] as String?,
        explanation: data['explanation'] as String?,
        caseSensitive: data['caseSensitive'] as bool? ?? false,
      );

  bool accepts(String answer) {
    final normalized = normalizeAnswer(answer, caseSensitive: caseSensitive);
    return [english, ...alternatives].any(
      (value) =>
          normalizeAnswer(value, caseSensitive: caseSensitive) == normalized,
    );
  }
}

String normalizeAnswer(String answer, {bool caseSensitive = false}) =>
    (caseSensitive ? answer : answer.toLowerCase())
        .trim()
        .replaceAll(RegExp('[’‘]'), "'")
        .replaceAll(RegExp(r'[.!?,]+$'), '')
        .replaceAll(RegExp(r'[-–]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
