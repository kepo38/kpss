enum RepetitionPeriod { gunluk, haftalik, aylik }

extension RepetitionPeriodExtension on RepetitionPeriod {
  String get label {
    switch (this) {
      case RepetitionPeriod.gunluk:
        return 'Günlük';
      case RepetitionPeriod.haftalik:
        return 'Haftalık';
      case RepetitionPeriod.aylik:
        return 'Aylık';
    }
  }

  Duration get duration {
    switch (this) {
      case RepetitionPeriod.gunluk:
        return const Duration(days: 1);
      case RepetitionPeriod.haftalik:
        return const Duration(days: 7);
      case RepetitionPeriod.aylik:
        return const Duration(days: 30);
    }
  }
}

enum TimeFilter { bugun, buHafta, buAy, tumu }

extension TimeFilterExtension on TimeFilter {
  String get label {
    switch (this) {
      case TimeFilter.bugun:
        return 'Bugün';
      case TimeFilter.buHafta:
        return 'Bu Hafta';
      case TimeFilter.buAy:
        return 'Bu Ay';
      case TimeFilter.tumu:
        return 'Tümü';
    }
  }

  bool matches(DateTime date) {
    final now = DateTime.now();
    switch (this) {
      case TimeFilter.bugun:
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case TimeFilter.buHafta:
        final start = now.subtract(Duration(days: now.weekday - 1));
        final startDay = DateTime(start.year, start.month, start.day);
        return !date.isBefore(startDay);
      case TimeFilter.buAy:
        return date.year == now.year && date.month == now.month;
      case TimeFilter.tumu:
        return true;
    }
  }
}

/// Fiziksel denemeden manuel kaydedilen yanlış soru defteri girişi.
class WrongNotebookEntry {
  final String id;
  final String dersAdi;
  final String konuAdi;
  final String soruNotu;
  final String cozumNotu;
  final String? yayinEvi;
  final String? denemeAdi;
  final RepetitionPeriod tekrarPeriyodu;
  final DateTime sonrakiTekrarTarihi;
  final int hatirlatmaSaati;
  final int hatirlatmaDakikasi;
  final DateTime olusturmaTarihi;
  final int tekrarSayisi;
  final bool arsivlendi;

  const WrongNotebookEntry({
    required this.id,
    required this.dersAdi,
    required this.konuAdi,
    required this.soruNotu,
    required this.cozumNotu,
    this.yayinEvi,
    this.denemeAdi,
    this.tekrarPeriyodu = RepetitionPeriod.haftalik,
    required this.sonrakiTekrarTarihi,
    this.hatirlatmaSaati = 20,
    this.hatirlatmaDakikasi = 0,
    required this.olusturmaTarihi,
    this.tekrarSayisi = 0,
    this.arsivlendi = false,
  });

  bool get tekrarVakti =>
      !arsivlendi && !sonrakiTekrarTarihi.isAfter(DateTime.now());

  WrongNotebookEntry copyWith({
    String? dersAdi,
    String? konuAdi,
    String? soruNotu,
    String? cozumNotu,
    String? yayinEvi,
    String? denemeAdi,
    RepetitionPeriod? tekrarPeriyodu,
    DateTime? sonrakiTekrarTarihi,
    int? hatirlatmaSaati,
    int? hatirlatmaDakikasi,
    int? tekrarSayisi,
    bool? arsivlendi,
  }) {
    return WrongNotebookEntry(
      id: id,
      dersAdi: dersAdi ?? this.dersAdi,
      konuAdi: konuAdi ?? this.konuAdi,
      soruNotu: soruNotu ?? this.soruNotu,
      cozumNotu: cozumNotu ?? this.cozumNotu,
      yayinEvi: yayinEvi ?? this.yayinEvi,
      denemeAdi: denemeAdi ?? this.denemeAdi,
      tekrarPeriyodu: tekrarPeriyodu ?? this.tekrarPeriyodu,
      sonrakiTekrarTarihi: sonrakiTekrarTarihi ?? this.sonrakiTekrarTarihi,
      hatirlatmaSaati: hatirlatmaSaati ?? this.hatirlatmaSaati,
      hatirlatmaDakikasi: hatirlatmaDakikasi ?? this.hatirlatmaDakikasi,
      olusturmaTarihi: olusturmaTarihi,
      tekrarSayisi: tekrarSayisi ?? this.tekrarSayisi,
      arsivlendi: arsivlendi ?? this.arsivlendi,
    );
  }

  factory WrongNotebookEntry.fromJson(Map<String, dynamic> json) {
    return WrongNotebookEntry(
      id: json['id'] as String,
      dersAdi: json['dersAdi'] as String,
      konuAdi: json['konuAdi'] as String,
      soruNotu: json['soruNotu'] as String,
      cozumNotu: json['cozumNotu'] as String,
      yayinEvi: json['yayinEvi'] as String?,
      denemeAdi: json['denemeAdi'] as String?,
      tekrarPeriyodu: RepetitionPeriod.values.byName(
        json['tekrarPeriyodu'] as String? ?? 'haftalik',
      ),
      sonrakiTekrarTarihi:
          DateTime.parse(json['sonrakiTekrarTarihi'] as String),
      hatirlatmaSaati: json['hatirlatmaSaati'] as int? ?? 20,
      hatirlatmaDakikasi: json['hatirlatmaDakikasi'] as int? ?? 0,
      olusturmaTarihi: DateTime.parse(json['olusturmaTarihi'] as String),
      tekrarSayisi: json['tekrarSayisi'] as int? ?? 0,
      arsivlendi: json['arsivlendi'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'dersAdi': dersAdi,
        'konuAdi': konuAdi,
        'soruNotu': soruNotu,
        'cozumNotu': cozumNotu,
        'yayinEvi': yayinEvi,
        'denemeAdi': denemeAdi,
        'tekrarPeriyodu': tekrarPeriyodu.name,
        'sonrakiTekrarTarihi': sonrakiTekrarTarihi.toIso8601String(),
        'hatirlatmaSaati': hatirlatmaSaati,
        'hatirlatmaDakikasi': hatirlatmaDakikasi,
        'olusturmaTarihi': olusturmaTarihi.toIso8601String(),
        'tekrarSayisi': tekrarSayisi,
        'arsivlendi': arsivlendi,
      };
}
