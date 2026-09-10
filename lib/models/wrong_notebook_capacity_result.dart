/// Yanlış defterine ekleme sonrası kapasite özeti.
class WrongNotebookCapacityResult {
  final int added;
  final int skipped;

  const WrongNotebookCapacityResult({
    this.added = 0,
    this.skipped = 0,
  });

  static const none = WrongNotebookCapacityResult();

  bool get shouldPromptUpsell => skipped > 0;
}
