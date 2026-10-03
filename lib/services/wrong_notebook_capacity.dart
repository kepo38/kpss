/// Yanlış defteri arşiv kapasitesi — saf hesap (test edilebilir).
class WrongNotebookCapacity {
  WrongNotebookCapacity._();

  /// Yeni eklenebilecek yanlış ID'leri döner; sınır doluysa boşaltır.
  static ({List<String> allowed, int skipped}) capNewIds({
    required bool isPremium,
    required int archivedCount,
    required int freeLimit,
    required Iterable<String> candidateIds,
    required Set<String> existingIds,
  }) {
    final newlyWrong = candidateIds
        .where((id) => !existingIds.contains(id))
        .toList(growable: false);
    if (newlyWrong.isEmpty) {
      return (allowed: const [], skipped: 0);
    }
    if (isPremium) {
      return (allowed: newlyWrong, skipped: 0);
    }
    final slots = (freeLimit - archivedCount).clamp(0, freeLimit);
    if (slots <= 0) {
      return (allowed: const [], skipped: newlyWrong.length);
    }
    final allowed = newlyWrong.take(slots).toList(growable: false);
    return (allowed: allowed, skipped: newlyWrong.length - allowed.length);
  }
}
