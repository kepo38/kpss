import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_bank_service.dart';
import 'content_sync_service.dart';
import 'auth_service.dart';
import 'premium_service.dart';

enum OfflinePackDownloadStatus { idle, downloading, ready, error, denied }

/// Yıllık Premium için çevrimdışı soru paketi yönetimi.
class OfflinePackService extends ChangeNotifier {
  OfflinePackService._();
  static final OfflinePackService instance = OfflinePackService._();

  static const storageKey = 'offline_pack_meta_v1';

  DateTime? _lastDownloadedAt;
  int? _packVersion;
  int _questionCount = 0;
  int _testCount = 0;
  bool _ready = false;
  bool _initialized = false;
  OfflinePackDownloadStatus _status = OfflinePackDownloadStatus.idle;
  String? _lastError;

  bool get isInitialized => _initialized;
  bool get isReady => _ready && ContentBankService.instance.hasCachedPack;
  DateTime? get lastDownloadedAt => _lastDownloadedAt;
  int? get packVersion => _packVersion ?? ContentBankService.instance.packVersion;
  int get questionCount =>
      _questionCount > 0
          ? _questionCount
          : ContentBankService.instance.cachedQuestionCount;
  int get testCount =>
      _testCount > 0
          ? _testCount
          : ContentBankService.instance.cachedTestCount;
  OfflinePackDownloadStatus get status => _status;
  String? get lastError => _lastError;

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(storageKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final map = jsonDecode(raw) as Map<String, dynamic>;
        _lastDownloadedAt =
            DateTime.tryParse(map['lastDownloadedAt'] as String? ?? '');
        _packVersion = (map['packVersion'] as num?)?.toInt();
        _questionCount = (map['questionCount'] as num?)?.toInt() ?? 0;
        _testCount = (map['testCount'] as num?)?.toInt() ?? 0;
        _ready = map['ready'] as bool? ?? false;
      } catch (_) {}
    }

    // Daha önce indirilmiş yerel banka varsa hazır say.
    final bank = ContentBankService.instance;
    await bank.initialize();
    if (!_ready && bank.hasCachedPack && PremiumService.instance.canUseOfflinePack) {
      _ready = true;
      _packVersion = bank.packVersion;
      _questionCount = bank.cachedQuestionCount;
      _testCount = bank.cachedTestCount;
      _status = OfflinePackDownloadStatus.ready;
      await _persist();
    } else if (_ready && bank.hasCachedPack) {
      _status = OfflinePackDownloadStatus.ready;
    }

    _initialized = true;
    notifyListeners();
  }

  String statusLabel() {
    if (!PremiumService.instance.canUseOfflinePack) {
      return 'Yalnızca yıllık Premium';
    }
    if (isReady) {
      return 'Hazır · v${packVersion ?? '-'} · $questionCount soru';
    }
    return 'Henüz indirilmedi';
  }

  /// Wi‑Fi üzerinde tam paketi indirir ve çevrimdışı kullanıma damgalar.
  Future<bool> downloadPack({bool force = true}) async {
    if (!AuthService.instance.hasPermanentAccount) {
      _status = OfflinePackDownloadStatus.denied;
      _lastError = 'Offline paket için Google ile giriş gerekli.';
      notifyListeners();
      return false;
    }

    if (!PremiumService.instance.canUseOfflinePack) {
      _status = OfflinePackDownloadStatus.denied;
      _lastError =
          'Offline paket yalnızca yıllık Premium aboneliğinde kullanılabilir.';
      notifyListeners();
      return false;
    }

    _status = OfflinePackDownloadStatus.downloading;
    _lastError = null;
    notifyListeners();

    final outcome = await ContentSyncService.instance.syncPublishedPackOutcome(
      force: force,
      timeout: const Duration(seconds: 45),
    );

    final bank = ContentBankService.instance;
    await bank.initialize();

    if (!outcome.success || !bank.hasCachedPack) {
      _status = OfflinePackDownloadStatus.error;
      if (!outcome.success) {
        _lastError = outcome.message ??
            ContentSyncService.instance.lastPackError ??
            'Paket indirilemedi. İnternet bağlantınızı kontrol edin.';
      } else {
        _lastError = 'Paket indirildi ama içerik boş görünüyor.';
      }
      notifyListeners();
      return false;
    }

    _lastDownloadedAt = DateTime.now();
    _packVersion = bank.packVersion;
    _questionCount = bank.cachedQuestionCount;
    _testCount = bank.cachedTestCount;
    _ready = true;
    _status = OfflinePackDownloadStatus.ready;
    await _persist();
    notifyListeners();
    return true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      storageKey,
      jsonEncode({
        if (_lastDownloadedAt != null)
          'lastDownloadedAt': _lastDownloadedAt!.toIso8601String(),
        'packVersion': _packVersion,
        'questionCount': _questionCount,
        'testCount': _testCount,
        'ready': _ready,
      }),
    );
  }

  @visibleForTesting
  Future<void> resetForTesting() async {
    _lastDownloadedAt = null;
    _packVersion = null;
    _questionCount = 0;
    _testCount = 0;
    _ready = false;
    _status = OfflinePackDownloadStatus.idle;
    _lastError = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
    notifyListeners();
  }
}
