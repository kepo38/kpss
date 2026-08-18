class UserModel {
  final String id;
  final String isim;
  final String eposta;
  final bool isPremium;
  final bool isAnonymous;
  final DateTime? premiumBitisTarihi;
  final DateTime? premiumVerilisTarihi;
  final String? premiumGrantNote;
  final String? photoUrl;
  final DateTime? isimDegistirilebilirAt;

  /// Auth henüz hazır değilken onboarding için geçici misafir.
  factory UserModel.placeholderGuest() => const UserModel(
        id: 'guest-pending',
        isim: 'Misafir',
        eposta: '',
        isAnonymous: true,
      );

  const UserModel({
    required this.id,
    required this.isim,
    required this.eposta,
    this.isPremium = false,
    this.isAnonymous = false,
    this.premiumBitisTarihi,
    this.premiumVerilisTarihi,
    this.premiumGrantNote,
    this.photoUrl,
    this.isimDegistirilebilirAt,
  });

  bool get canChangeDisplayName {
    final at = isimDegistirilebilirAt;
    if (at == null) return true;
    return !at.isAfter(DateTime.now());
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: '${json['id']}',
      isim: (json['isim'] ?? json['display_name'] ?? '') as String,
      eposta: (json['eposta'] ?? json['email'] ?? '') as String,
      isPremium: json['isPremium'] as bool? ?? false,
      isAnonymous: json['isAnonymous'] as bool? ?? false,
      premiumBitisTarihi: json['premiumBitisTarihi'] != null
          ? DateTime.tryParse('${json['premiumBitisTarihi']}')
          : null,
      premiumVerilisTarihi: json['premiumVerilisTarihi'] != null
          ? DateTime.tryParse('${json['premiumVerilisTarihi']}')
          : null,
      premiumGrantNote: json['premiumGrantNote'] as String?,
      photoUrl: json['photoUrl'] as String?,
      isimDegistirilebilirAt: json['isimDegistirilebilirAt'] != null
          ? DateTime.tryParse('${json['isimDegistirilebilirAt']}')
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'isim': isim,
        'eposta': eposta,
        'isPremium': isPremium,
        'isAnonymous': isAnonymous,
        'premiumBitisTarihi': premiumBitisTarihi?.toIso8601String(),
        'premiumVerilisTarihi': premiumVerilisTarihi?.toIso8601String(),
        'premiumGrantNote': premiumGrantNote,
        'photoUrl': photoUrl,
      };

  UserModel copyWith({
    String? id,
    String? isim,
    String? eposta,
    bool? isPremium,
    bool? isAnonymous,
    DateTime? premiumBitisTarihi,
    DateTime? premiumVerilisTarihi,
    String? premiumGrantNote,
    String? photoUrl,
    DateTime? isimDegistirilebilirAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      isim: isim ?? this.isim,
      eposta: eposta ?? this.eposta,
      isPremium: isPremium ?? this.isPremium,
      isAnonymous: isAnonymous ?? this.isAnonymous,
      premiumBitisTarihi: premiumBitisTarihi ?? this.premiumBitisTarihi,
      premiumVerilisTarihi:
          premiumVerilisTarihi ?? this.premiumVerilisTarihi,
      premiumGrantNote: premiumGrantNote ?? this.premiumGrantNote,
      photoUrl: photoUrl ?? this.photoUrl,
      isimDegistirilebilirAt:
          isimDegistirilebilirAt ?? this.isimDegistirilebilirAt,
    );
  }
}
