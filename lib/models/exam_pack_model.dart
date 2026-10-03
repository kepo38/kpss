/// Deneme paketi API modeli.
class ExamPackModel {
  final String id;
  final String examTypeId;
  final String packKind;
  final String? subjectId;
  final String? subjectName;
  final String title;
  final String description;
  final int examCount;
  final int timeLimitMinutes;
  final String priceDisplay;
  final String playProductId;
  final int questionsPerExam;
  final List<ExamPackExamSummary> exams;

  const ExamPackModel({
    required this.id,
    required this.examTypeId,
    required this.packKind,
    this.subjectId,
    this.subjectName,
    required this.title,
    this.description = '',
    required this.examCount,
    required this.timeLimitMinutes,
    this.priceDisplay = '',
    this.playProductId = '',
    this.questionsPerExam = 0,
    this.exams = const [],
  });

  bool get isBranch => packKind == 'branch';

  factory ExamPackModel.fromJson(Map<String, dynamic> json) {
    final examsRaw = json['exams'];
    final exams = examsRaw is List
        ? examsRaw
            .map(
              (e) => ExamPackExamSummary.fromJson(
                Map<String, dynamic>.from(e as Map),
              ),
            )
            .toList()
        : const <ExamPackExamSummary>[];

    return ExamPackModel(
      id: json['id'] as String,
      examTypeId: json['examTypeId'] as String? ?? '',
      packKind: json['packKind'] as String? ?? 'branch',
      subjectId: json['subjectId'] as String?,
      subjectName: json['subjectName'] as String?,
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      examCount: json['examCount'] as int? ?? 1,
      timeLimitMinutes: json['timeLimitMinutes'] as int? ?? 130,
      priceDisplay: json['priceDisplay'] as String? ?? '',
      playProductId: json['playProductId'] as String? ?? '',
      questionsPerExam: json['questionsPerExam'] as int? ?? 0,
      exams: exams,
    );
  }
}

class ExamPackExamSummary {
  final int index;
  final String title;
  final int questionCount;

  const ExamPackExamSummary({
    required this.index,
    required this.title,
    required this.questionCount,
  });

  factory ExamPackExamSummary.fromJson(Map<String, dynamic> json) {
    return ExamPackExamSummary(
      index: json['index'] as int? ?? 1,
      title: json['title'] as String? ?? '',
      questionCount: json['questionCount'] as int? ?? 0,
    );
  }
}

/// Quiz başlatma / analiz köprüsü meta verisi.
class ExamPackQuizMeta {
  final String packId;
  final String packTitle;
  final int examIndex;
  final String examTitle;
  final String? branchSubjectName;

  const ExamPackQuizMeta({
    required this.packId,
    required this.packTitle,
    required this.examIndex,
    required this.examTitle,
    this.branchSubjectName,
  });
}
