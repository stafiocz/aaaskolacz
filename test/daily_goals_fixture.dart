Map<String, dynamic> goalsData({
  int math = 0,
  int vocabulary = 0,
  List<String> wordIds = const [],
}) => {
  'day': '2026-09-17',
  'resetsAt': DateTime.now()
      .toUtc()
      .add(const Duration(days: 1))
      .toIso8601String(),
  'target': 15,
  'math': math,
  'vocabulary': vocabulary,
  'wordIds': wordIds,
};
