import '../widgets/countdown_widget.dart';

/// Müfredat alt konusu ilerleme kaydı.
class TopicProgressModel {
  final String id;
  final KpssType kpssType;
  final String dersAdi;
  final String konuAdi;
  final String altKonuAdi;
  final bool tamamlandi;
  final DateTime? tamamlanmaTarihi;

  const TopicProgressModel({
    required this.id,
    required this.kpssType,
    required this.dersAdi,
    required this.konuAdi,
    required this.altKonuAdi,
    this.tamamlandi = false,
    this.tamamlanmaTarihi,
  });

  TopicProgressModel copyWith({
    bool? tamamlandi,
    DateTime? tamamlanmaTarihi,
  }) {
    return TopicProgressModel(
      id: id,
      kpssType: kpssType,
      dersAdi: dersAdi,
      konuAdi: konuAdi,
      altKonuAdi: altKonuAdi,
      tamamlandi: tamamlandi ?? this.tamamlandi,
      tamamlanmaTarihi: tamamlanmaTarihi ?? this.tamamlanmaTarihi,
    );
  }
}
