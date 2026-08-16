class CurrentInfoModel {
  final String id;
  final String baslik;
  final String aciklama;
  final String? imageUrl;
  final DateTime eklenmeTarihi;

  const CurrentInfoModel({
    required this.id,
    required this.baslik,
    required this.aciklama,
    this.imageUrl,
    required this.eklenmeTarihi,
  });

  factory CurrentInfoModel.fromJson(Map<String, dynamic> json) {
    return CurrentInfoModel(
      id: json['id'] as String,
      baslik: json['baslik'] as String,
      aciklama: json['aciklama'] as String,
      imageUrl: json['imageUrl'] as String?,
      eklenmeTarihi: DateTime.parse(json['eklenmeTarihi'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'baslik': baslik,
        'aciklama': aciklama,
        'imageUrl': imageUrl,
        'eklenmeTarihi': eklenmeTarihi.toIso8601String(),
      };
}
