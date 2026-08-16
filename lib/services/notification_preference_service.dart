import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının açıp kapatabildiği bildirim türleri.
enum NotificationKind {
  morningMotivation,
  eveningFomo,
  weeklySummary,
  savingsMilestone,
  announcements,
}

class NotificationKindMeta {
  final String title;
  final String subtitle;
  final NotificationKind kind;

  const NotificationKindMeta({
    required this.kind,
    required this.title,
    required this.subtitle,
  });
}

/// Profil ayarlarındaki bildirim anahtarları.
class NotificationPreferenceService extends ChangeNotifier {
  NotificationPreferenceService._();
  static final NotificationPreferenceService instance =
      NotificationPreferenceService._();

  static const _prefix = 'notif_pref_v1_';

  /// Kullanıcının kapatamadığı türler: kazanç fırsatı ve panel duyuruları.
  static const lockedKinds = <NotificationKind>{
    NotificationKind.savingsMilestone,
    NotificationKind.announcements,
  };

  static const kinds = <NotificationKindMeta>[
    NotificationKindMeta(
      kind: NotificationKind.morningMotivation,
      title: 'Sabah motivasyon',
      subtitle: 'Her gün 09:00 · ücretsiz test hatırlatması',
    ),
    NotificationKindMeta(
      kind: NotificationKind.eveningFomo,
      title: 'Gece hatırlatması',
      subtitle: '21:00 · 4 görev dolunca son ders uyarısı',
    ),
    NotificationKindMeta(
      kind: NotificationKind.weeklySummary,
      title: 'Haftalık özet',
      subtitle: 'Pazar 15:00 · net ve yanlış defteri',
    ),
  ];

  final Map<NotificationKind, bool> _enabled = {
    for (final k in NotificationKind.values) k: true,
  };
  bool _initialized = false;

  bool get isInitialized => _initialized;

  bool isEnabled(NotificationKind kind) {
    if (lockedKinds.contains(kind)) return true;
    return _enabled[kind] ?? true;
  }

  bool get allEnabled =>
      kinds.every((meta) => isEnabled(meta.kind));

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    for (final kind in NotificationKind.values) {
      if (lockedKinds.contains(kind)) {
        _enabled[kind] = true;
        continue;
      }
      _enabled[kind] = prefs.getBool('$_prefix${kind.name}') ?? true;
    }
    _initialized = true;
    notifyListeners();
  }

  Future<void> setEnabled(NotificationKind kind, bool value) async {
    if (lockedKinds.contains(kind)) return;
    if (_enabled[kind] == value) return;
    _enabled[kind] = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_prefix${kind.name}', value);
  }

  Future<void> setAll(bool value) async {
    var changed = false;
    for (final meta in kinds) {
      if (_enabled[meta.kind] != value) {
        _enabled[meta.kind] = value;
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    for (final meta in kinds) {
      await prefs.setBool('$_prefix${meta.kind.name}', value);
    }
  }
}
