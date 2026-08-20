/// Yerel depolama sabitleri — 1 yıl saklama politikası.
class StorageConstants {
  StorageConstants._();

  /// Veriler en fazla 365 gün saklanır; daha eskiler otomatik silinir.
  static const int retentionDays = 365;

  static const String dbName = 'kpss_akademi.db';
  static const int dbVersion = 4;

  static const String tablePracticeExams = 'practice_exams';
  static const String tableWrongNotebook = 'wrong_notebook';
  static const String tableStudyNotes = 'study_notes';
  static const String tableManualWrongQuestions = 'manual_wrong_questions';

  /// Web önizlemesi için SharedPreferences anahtarları.
  static const String webExamsKey = 'web_practice_exams';
  static const String webNotebookKey = 'web_wrong_notebook';
  static const String webManualWrongQuestionsKey = 'web_manual_wrong_questions';
}
