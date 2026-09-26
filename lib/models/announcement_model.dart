class AnnouncementModel {
  final int id;
  final String title;
  final String body;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? pushSentAt;

  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.createdAt,
    this.pushSentAt,
  });

  bool get hasImage => imageUrl != null && imageUrl!.trim().isNotEmpty;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    final rawImage = (json['imageUrl'] as String?)?.trim();
    return AnnouncementModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] as String?)?.trim() ?? '',
      body: (json['body'] as String?)?.trim() ?? '',
      imageUrl: (rawImage == null || rawImage.isEmpty) ? null : rawImage,
      createdAt: _parseDate(json['createdAt'] ?? json['created_at']),
      pushSentAt: _parseDate(json['pushSentAt'] ?? json['push_sent_at']),
    );
  }

  static DateTime? _parseDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString());
  }
}
