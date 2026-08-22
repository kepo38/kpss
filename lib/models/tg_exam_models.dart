import '../constants/tg_exam_constants.dart';

/// Türkiye Geneli deneme durumları — karşılama ekranı buton mantığı.
enum TgExamStatus {
  notStarted,
  active,
  inProgress,
  submittedWaiting,
  ended,
  results;

  static TgExamStatus fromApi(String raw) {
    switch (raw) {
      case 'not_started':
        return TgExamStatus.notStarted;
      case 'active':
        return TgExamStatus.active;
      case 'in_progress':
        return TgExamStatus.inProgress;
      case 'submitted_waiting':
        return TgExamStatus.submittedWaiting;
      case 'ended':
        return TgExamStatus.ended;
      case 'results':
        return TgExamStatus.results;
      default:
        return TgExamStatus.notStarted;
    }
  }
}

class TgExamAttemptModel {
  final int correct;
  final int wrong;
  final int blank;
  final double net;
  final Map<String, double> subjectNets;
  final int durationSeconds;
  final bool isSubmitted;
  final int currentIndex;
  final int elapsedSeconds;
  final Map<String, String> answers;
  final int? ranking;
  final double? successPercent;

  const TgExamAttemptModel({
    this.correct = 0,
    this.wrong = 0,
    this.blank = 0,
    this.net = 0,
    this.subjectNets = const {},
    this.durationSeconds = 0,
    this.isSubmitted = false,
    this.currentIndex = 0,
    this.elapsedSeconds = 0,
    this.answers = const {},
    this.ranking,
    this.successPercent,
  });

  factory TgExamAttemptModel.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      return const TgExamAttemptModel();
    }
    final subjectRaw = json['subjectNets'];
    final subjectNets = <String, double>{};
    if (subjectRaw is Map) {
      subjectRaw.forEach((key, value) {
        subjectNets['$key'] = (value as num?)?.toDouble() ?? 0;
      });
    }
    final answersRaw = json['answers'];
    final answers = <String, String>{};
    if (answersRaw is Map) {
      answersRaw.forEach((key, value) {
        answers['$key'] = '$value';
      });
    }
    return TgExamAttemptModel(
      correct: (json['correct'] as num?)?.toInt() ?? 0,
      wrong: (json['wrong'] as num?)?.toInt() ?? 0,
      blank: (json['blank'] as num?)?.toInt() ?? 0,
      net: (json['net'] as num?)?.toDouble() ?? 0,
      subjectNets: subjectNets,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt() ?? 0,
      isSubmitted: json['isSubmitted'] == true,
      currentIndex: (json['currentIndex'] as num?)?.toInt() ?? 0,
      elapsedSeconds: (json['elapsedSeconds'] as num?)?.toInt() ?? 0,
      answers: answers,
      ranking: (json['ranking'] as num?)?.toInt(),
      successPercent: (json['successPercent'] as num?)?.toDouble(),
    );
  }
}

class TgExamModel {
  final int id;
  final String title;
  final String kpssType;
  final DateTime startAt;
  final DateTime endAt;
  final int durationMinutes;
  final int questionCount;
  final List<String> questionIds;
  final bool isResultsPublished;
  final TgExamStatus status;
  final TgExamAttemptModel? myAttempt;
  final int participantCount;
  final double? averageNet;

  const TgExamModel({
    required this.id,
    required this.title,
    required this.kpssType,
    required this.startAt,
    required this.endAt,
    required this.durationMinutes,
    required this.questionCount,
    this.questionIds = const [],
    required this.isResultsPublished,
    required this.status,
    this.myAttempt,
    this.participantCount = 0,
    this.averageNet,
  });

  factory TgExamModel.fromJson(Map<String, dynamic> json) {
    return TgExamModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: '${json['title'] ?? ''}',
      kpssType: '${json['kpssType'] ?? 'lisans'}',
      startAt: DateTime.parse('${json['startAt']}').toLocal(),
      endAt: DateTime.parse('${json['endAt']}').toLocal(),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ??
          TgExamConstants.examDurationMinutes,
      questionCount: (json['questionCount'] as num?)?.toInt() ?? 0,
      questionIds: (json['questionIds'] as List<dynamic>?)
              ?.map((e) => '$e')
              .toList() ??
          const [],
      isResultsPublished: json['isResultsPublished'] == true,
      status: TgExamStatus.fromApi('${json['status'] ?? ''}'),
      myAttempt: TgExamAttemptModel.fromJson(
        json['myAttempt'] as Map<String, dynamic>?,
      ),
      participantCount: (json['participantCount'] as num?)?.toInt() ?? 0,
      averageNet: (json['averageNet'] as num?)?.toDouble(),
    );
  }

  bool get hasSubmittedAttempt => myAttempt?.isSubmitted == true;

  /// Türkiye geneli deneme penceresi hâlâ açık (bitiş saatine kadar).
  bool get isExamWindowOpen => DateTime.now().isBefore(endAt);

  /// Soru çözümleri ve sıralama — sonuçlar otomatik yayınlanınca açılır.
  bool get canAccessSolutions =>
      hasSubmittedAttempt && isResultsPublished;

  /// Sıralama ve detaylı analiz — sonuçlar ilan edilince açılır.
  bool get canAccessDetailedAnalysis =>
      hasSubmittedAttempt && isResultsPublished;

  /// Katılım penceresi kapandı, sonuçlar henüz yayınlanmadı.
  bool get isAwaitingResultsPublication =>
      hasSubmittedAttempt &&
      !isResultsPublished &&
      !DateTime.now().isBefore(endAt);

  /// Kart özeti: sınav gönderildi, sonuçlar henüz ilan edilmedi.
  bool get isScoreCalculatedWaitingResults =>
      hasSubmittedAttempt && !isResultsPublished;

  double get displaySuccessPercent {
    if (myAttempt?.successPercent != null) {
      return myAttempt!.successPercent!;
    }
    if (questionCount <= 0) return 0;
    return (myAttempt?.correct ?? 0) / questionCount * 100;
  }
}

class TgExamQuestionsPayload {
  final int examId;
  final String title;
  final int durationMinutes;
  final List<String> questionIds;

  const TgExamQuestionsPayload({
    required this.examId,
    required this.title,
    required this.durationMinutes,
    required this.questionIds,
  });

  factory TgExamQuestionsPayload.fromJson(Map<String, dynamic> json) {
    return TgExamQuestionsPayload(
      examId: (json['examId'] as num?)?.toInt() ?? 0,
      title: '${json['title'] ?? ''}',
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ??
          TgExamConstants.examDurationMinutes,
      questionIds: (json['questionIds'] as List<dynamic>?)
              ?.map((e) => '$e')
              .toList() ??
          const [],
    );
  }
}

/// Ders slug → Türkçe etiket (sonuç ekranı).
const tgExamSubjectLabels = <String, String>{
  'tarih': 'Tarih',
  'cografya': 'Coğrafya',
  'vatandaslik': 'Vatandaşlık',
  'turkce_anlam': 'Türkçe',
  'turkce_dilbilgisi': 'Türkçe',
  'diger': 'Diğer',
};

String tgExamSubjectLabel(String slug) =>
    tgExamSubjectLabels[slug] ?? slug;
