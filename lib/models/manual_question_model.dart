enum ManualQuestionStatus { fresh, repeat, solved }

class ManualQuestionModel {
  final String id;
  final String userId;
  final String imagePath;
  final String? subject;
  final String? topic;
  final String? note;
  final ManualQuestionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  const ManualQuestionModel({
    required this.id,
    required this.userId,
    required this.imagePath,
    this.subject,
    this.topic,
    this.note,
    this.status = ManualQuestionStatus.fresh,
    required this.createdAt,
    required this.updatedAt,
  });

  String get subjectLabel {
    final value = subject?.trim() ?? '';
    return value.isEmpty ? 'Etiketsiz' : value;
  }

  String get topicLabel {
    final value = topic?.trim() ?? '';
    return value.isEmpty ? 'Konu belirtilmedi' : value;
  }

  String get noteText => (note ?? '').trim();

  bool get hasNote => noteText.isNotEmpty;

  ManualQuestionModel copyWith({
    String? id,
    String? userId,
    String? imagePath,
    String? subject,
    bool clearSubject = false,
    String? topic,
    bool clearTopic = false,
    String? note,
    bool clearNote = false,
    ManualQuestionStatus? status,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return ManualQuestionModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      imagePath: imagePath ?? this.imagePath,
      subject: clearSubject ? null : (subject ?? this.subject),
      topic: clearTopic ? null : (topic ?? this.topic),
      note: clearNote ? null : (note ?? this.note),
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
