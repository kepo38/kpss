enum TaskPriority { dusuk, orta, yuksek }

extension TaskPriorityExtension on TaskPriority {
  String get label {
    switch (this) {
      case TaskPriority.dusuk:
        return 'Düşük';
      case TaskPriority.orta:
        return 'Orta';
      case TaskPriority.yuksek:
        return 'Yüksek';
    }
  }
}

/// Haftalık çalışma görevi.
class StudyTaskModel {
  final String id;
  final String baslik;
  final String dersEtiketi;
  final TaskPriority oncelik;
  final DateTime hedefTarih;
  final bool tamamlandi;
  final DateTime olusturmaTarihi;

  const StudyTaskModel({
    required this.id,
    required this.baslik,
    required this.dersEtiketi,
    this.oncelik = TaskPriority.orta,
    required this.hedefTarih,
    this.tamamlandi = false,
    required this.olusturmaTarihi,
  });

  StudyTaskModel copyWith({
    String? baslik,
    String? dersEtiketi,
    TaskPriority? oncelik,
    DateTime? hedefTarih,
    bool? tamamlandi,
  }) {
    return StudyTaskModel(
      id: id,
      baslik: baslik ?? this.baslik,
      dersEtiketi: dersEtiketi ?? this.dersEtiketi,
      oncelik: oncelik ?? this.oncelik,
      hedefTarih: hedefTarih ?? this.hedefTarih,
      tamamlandi: tamamlandi ?? this.tamamlandi,
      olusturmaTarihi: olusturmaTarihi,
    );
  }
}
