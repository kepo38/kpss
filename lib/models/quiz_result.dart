import '../models/question_model.dart';

/// Quiz oturumu sonucu — istatistik kaydı için.
class QuizResult {
  final int correct;
  final int wrong;
  final int blank;
  final int total;
  final Duration duration;
  final bool completed;
  final List<String> questionIds;
  final List<String> wrongQuestionIds;
  final List<String> correctQuestionIds;
  final List<String?> selectedAnswers;

  const QuizResult({
    required this.correct,
    required this.wrong,
    required this.blank,
    required this.total,
    required this.duration,
    this.completed = true,
    this.questionIds = const [],
    this.wrongQuestionIds = const [],
    this.correctQuestionIds = const [],
    this.selectedAnswers = const [],
  });

  double get accuracy => total == 0 ? 0 : correct / total;
  double get net => correct - (wrong / 4);

  /// Toplam sürenin soru sayısına bölünmesi.
  Duration get averageQuestionDuration {
    if (total <= 0) return Duration.zero;
    return Duration(
      milliseconds: duration.inMilliseconds ~/ total,
    );
  }

  /// Örn. `42 sn`, `1 dk 05 sn`, `1:02:03`
  static String formatDuration(Duration d) {
    if (d.inHours > 0) {
      final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
      final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
      return '${d.inHours}:$m:$s';
    }
    if (d.inMinutes > 0) {
      final s = d.inSeconds.remainder(60);
      return s > 0 ? '${d.inMinutes} dk ${s.toString().padLeft(2, '0')} sn' : '${d.inMinutes} dk';
    }
    final sec = d.inSeconds;
    if (sec > 0) return '$sec sn';
    return '0 sn';
  }
}

/// Tek soru cevabı durumu.
enum AnswerState { correct, wrong, blank }

AnswerState gradeAnswer(QuestionModel question, String? selected) {
  if (selected == null || selected.isEmpty) return AnswerState.blank;
  if (selected == question.dogruCevap) return AnswerState.correct;
  return AnswerState.wrong;
}
