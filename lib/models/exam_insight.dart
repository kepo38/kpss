/// Kurumsal / yayınevi denemesi kaydı sonrası kişisel analiz özeti.
class ExamInsight {
  final String examLabel;
  final int netDelta;
  final String? decliningSubject;
  final String? recommendedTopic;
  final String message;

  const ExamInsight({
    required this.examLabel,
    required this.netDelta,
    required this.message,
    this.decliningSubject,
    this.recommendedTopic,
  });
}

/// Deneme kayıt sheet'i kapanış sonucu.
class ExamSaveResult {
  final ExamInsight? insight;

  const ExamSaveResult({this.insight});
}
