class UserMessageModel {
  final int id;
  final String title;
  final String body;
  final bool isRead;
  final DateTime? createdAt;

  const UserMessageModel({
    required this.id,
    required this.title,
    required this.body,
    this.isRead = false,
    this.createdAt,
  });

  factory UserMessageModel.fromJson(Map<String, dynamic> json) {
    return UserMessageModel(
      id: json['id'] is int
          ? json['id'] as int
          : int.tryParse('${json['id']}') ?? 0,
      title: (json['title'] as String?)?.trim() ?? '',
      body: (json['body'] as String?)?.trim() ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse('${json['created_at']}')
          : null,
    );
  }
}
