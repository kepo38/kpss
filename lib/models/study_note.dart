class StudyNote {
  final String id;
  final String subjectId;
  final String subjectName;
  final String title;
  final String body;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StudyNote({
    required this.id,
    required this.subjectId,
    required this.subjectName,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.updatedAt,
  });

  StudyNote copyWith({
    String? subjectId,
    String? subjectName,
    String? title,
    String? body,
    DateTime? updatedAt,
  }) =>
      StudyNote(
        id: id,
        subjectId: subjectId ?? this.subjectId,
        subjectName: subjectName ?? this.subjectName,
        title: title ?? this.title,
        body: body ?? this.body,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
}
