import '../constants/brand_constants.dart';
import '../models/exam_pack_model.dart';
import '../models/practice_exam_model.dart';
import '../models/question_model.dart';
import '../models/quiz_result.dart';
import '../services/practice_exam_service.dart';

/// Deneme paketi quiz bitince PracticeExam kaydı — HEDEF KAMU yayın evi.
class ExamPackAnalyticsBridge {
  ExamPackAnalyticsBridge._();

  static void record({
    required ExamPackQuizMeta meta,
    required QuizResult result,
    required List<QuestionModel> questions,
    required List<String?> answers,
  }) async {
    final dersSonuclari = _buildSubjectResults(
      questions: questions,
      answers: answers,
      branchSubjectName: meta.branchSubjectName,
    );
    if (dersSonuclari.isEmpty) return;

    PracticeExamService.instance.addExam(
      PracticeExamModel(
        id: 'ep_${meta.packId}_${meta.examIndex}_${DateTime.now().millisecondsSinceEpoch}',
        denemeAdi: '${meta.packTitle} · ${meta.examTitle}',
        yayinEvi: BrandConstants.appName,
        tarih: DateTime.now(),
        dersSonuclari: dersSonuclari,
        notlar: 'Uygulama içi deneme paketi',
        sourcePackId: meta.packId,
        isInAppGenerated: true,
      ),
    );
  }

  static Map<String, DersSonuc> _buildSubjectResults({
    required List<QuestionModel> questions,
    required List<String?> answers,
    String? branchSubjectName,
  }) {
    final totals = <String, _MutableScore>{};

    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final subject = branchSubjectName?.trim().isNotEmpty == true
          ? branchSubjectName!.trim()
          : q.dersAdi.trim();
      if (subject.isEmpty) continue;

      totals.putIfAbsent(subject, _MutableScore.new);
      final selected = i < answers.length ? answers[i] : null;
      if (selected == null || selected.isEmpty) {
        totals[subject]!.bos++;
      } else if (selected.toUpperCase() == q.dogruCevap.toUpperCase()) {
        totals[subject]!.dogru++;
      } else {
        totals[subject]!.yanlis++;
      }
    }

    return totals.map(
      (key, value) => MapEntry(
        key,
        DersSonuc(
          dogru: value.dogru,
          yanlis: value.yanlis,
          bos: value.bos,
        ),
      ),
    );
  }
}

class _MutableScore {
  int dogru = 0;
  int yanlis = 0;
  int bos = 0;
}
