class SpecialTestItem {
  final String id;
  final String title;
  final int questionCount;
  final List<String> questionIds;

  const SpecialTestItem({
    required this.id,
    required this.title,
    required this.questionCount,
    required this.questionIds,
  });

  factory SpecialTestItem.fromJson(Map<String, dynamic> json) {
    return SpecialTestItem(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Test',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      questionIds: (json['questionIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
    );
  }
}

class SpecialTestCategory {
  final String id;
  final String title;
  final String subjectId;
  final int questionCount;
  final List<SpecialTestItem> tests;

  const SpecialTestCategory({
    required this.id,
    required this.title,
    required this.subjectId,
    required this.questionCount,
    required this.tests,
  });

  factory SpecialTestCategory.fromJson(Map<String, dynamic> json) {
    return SpecialTestCategory(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      subjectId: json['subjectId'] as String? ?? '',
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      tests: (json['tests'] as List<dynamic>?)
              ?.map(
                (e) => SpecialTestItem.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          const [],
    );
  }
}
