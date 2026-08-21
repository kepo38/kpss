import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import 'auth_service.dart';
import 'content_bank_isolate.dart';
import 'content_bank_service.dart';

/// Django yayın paketini çeker; sürüm değişince anında günceller.
class ContentSyncService {
  ContentSyncService._();
  static final ContentSyncService instance = ContentSyncService._();

  Timer? _pollTimer;
  Completer<bool>? _activeSync;
  DateTime? _lastSyncAt;
  String? _lastPackError;

  String? get lastPackError => _lastPackError;

  /// Periyodik katalog kontrolü — varsayılan kapalı (pil/ağ tasarrufu).
  /// Gerekirse manuel veya push bildirimiyle tetiklenir.
  void startAutoSync({Duration interval = const Duration(minutes: 30)}) {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(interval, (_) {
      unawaited(syncIfNeeded());
    });
  }

  void stopAutoSync() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  /// Offline paket sürümü — Bearer + yıllık premium gerekir.
  Future<int?> fetchRemoteVersion({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final outcome = await fetchRemoteVersionOutcome(timeout: timeout);
    return outcome.version;
  }

  Future<PackVersionOutcome> fetchRemoteVersionOutcome({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    try {
      final response = await http
          .get(
            ApiConfig.packVersionUri(),
            headers: AuthService.instance.authHeaders,
          )
          .timeout(timeout);
      if (response.statusCode == 401) {
        return const PackVersionOutcome(
          error: 'Google ile giriş gerekli',
          statusCode: 401,
        );
      }
      if (response.statusCode == 403) {
        return PackVersionOutcome(
          error: _yearlyPremiumMessage(response),
          statusCode: 403,
        );
      }
      if (response.statusCode != 200) {
        return PackVersionOutcome(
          error: 'Sürüm alınamadı (HTTP ${response.statusCode})',
          statusCode: response.statusCode,
        );
      }
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final v = body['version'];
      int? version;
      if (v is int) {
        version = v;
      } else if (v is num) {
        version = v.toInt();
      } else {
        version = int.tryParse('$v');
      }
      return PackVersionOutcome(version: version, statusCode: 200);
    } catch (_) {
      return const PackVersionOutcome(
        error: 'Sunucuya ulaşılamadı',
      );
    }
  }

  /// Sürüm değişmediyse paket indirme.
  /// Pack/version yıllık premium ister; katalog herkese açıktır.
  Future<bool> syncIfNeeded({
    Duration timeout = const Duration(seconds: 12),
  }) async {
    await ContentBankService.instance.initialize();
    return syncCatalog(timeout: timeout, force: false);
  }

  /// Konu/test öncesi — katalog ile güncelle (tam pack değil).
  Future<ContentSyncOutcome> ensureFreshContent({
    Duration timeout = const Duration(seconds: 15),
    bool forceDownload = false,
  }) async {
    await ContentBankService.instance.initialize();

    final ok = await syncCatalog(timeout: timeout, force: forceDownload);
    if (ok) {
      return ContentSyncOutcome(
        success: true,
        downloaded: true,
        message: null,
        remoteVersion: ContentBankService.instance.packVersion,
      );
    }

    final bank = ContentBankService.instance;
    if (bank.hasCachedPack) {
      return ContentSyncOutcome(
        success: true,
        downloaded: false,
        usedOfflineCache: true,
        message: 'İnternet yok · çevrimdışı paket kullanılıyor '
            '(v${bank.packVersion}).',
        remoteVersion: bank.packVersion,
      );
    }
    if (bank.hasCachedCatalog) {
      return ContentSyncOutcome(
        success: true,
        downloaded: false,
        usedOfflineCache: true,
        message:
            'İnternet yok · test listesi yerelde. Sorular bağlantı gelince yüklenecek.',
        remoteVersion: bank.packVersion,
      );
    }

    return ContentSyncOutcome(
      success: false,
      downloaded: false,
      message: 'Sunucuya ulaşılamadı (${ApiConfig.baseUrl}). '
          'Telefon ve bilgisayar aynı Wi‑Fi\'de olmalı.',
    );
  }

  /// Hafif katalog — test/ders listesi; soru gövdeleri indirilmez.
  Future<bool> syncCatalog({
    Duration timeout = const Duration(seconds: 12),
    bool force = false,
  }) async {
    final inFlight = _activeSync;
    if (inFlight != null) {
      return inFlight.future;
    }

    if (!force &&
        _lastSyncAt != null &&
        DateTime.now().difference(_lastSyncAt!) < const Duration(seconds: 3)) {
      return true;
    }

    final completer = Completer<bool>();
    _activeSync = completer;
    try {
      final response = await http
          .get(
            ApiConfig.catalogUri(),
            headers: {'Accept': 'application/json'},
          )
          .timeout(timeout);
      if (response.statusCode != 200) {
        debugPrint('Catalog sync HTTP ${response.statusCode}');
        completer.complete(false);
        return false;
      }

      final body = await Isolate.run(
        () => decodeJsonUtf8Bytes(response.bodyBytes),
      );
      await ContentBankService.instance.applyCatalogPack(body);
      _lastSyncAt = DateTime.now();
      debugPrint(
        'Catalog sync OK v${ContentBankService.instance.packVersion}',
      );
      completer.complete(true);
      return true;
    } catch (e) {
      debugPrint('Catalog sync failed: $e');
      completer.complete(false);
      return false;
    } finally {
      _activeSync = null;
    }
  }

  /// Tam paket — yalnızca offline premium indirmesi için.
  Future<bool> syncPublishedPack({
    Duration timeout = const Duration(seconds: 12),
    bool force = false,
  }) async {
    final outcome = await syncPublishedPackOutcome(
      timeout: timeout,
      force: force,
    );
    return outcome.success;
  }

  Future<ContentSyncOutcome> syncPublishedPackOutcome({
    Duration timeout = const Duration(seconds: 12),
    bool force = false,
  }) async {
    final inFlight = _activeSync;
    if (inFlight != null) {
      final ok = await inFlight.future;
      return ContentSyncOutcome(
        success: ok,
        downloaded: ok,
        message: ok ? null : (_lastPackError ?? 'Paket indirilemedi.'),
      );
    }

    if (!force &&
        _lastSyncAt != null &&
        DateTime.now().difference(_lastSyncAt!) < const Duration(seconds: 3)) {
      return const ContentSyncOutcome(
        success: true,
        downloaded: false,
      );
    }

    final completer = Completer<bool>();
    _activeSync = completer;
    _lastPackError = null;
    try {
      final response = await http
          .get(
            ApiConfig.packUri(),
            headers: AuthService.instance.authHeaders,
          )
          .timeout(timeout);

      if (response.statusCode == 401) {
        _lastPackError = 'Google ile giriş gerekli';
        completer.complete(false);
        return ContentSyncOutcome(
          success: false,
          downloaded: false,
          message: _lastPackError,
          statusCode: 401,
        );
      }
      if (response.statusCode == 403) {
        _lastPackError = _yearlyPremiumMessage(response);
        completer.complete(false);
        return ContentSyncOutcome(
          success: false,
          downloaded: false,
          message: _lastPackError,
          statusCode: 403,
        );
      }
      if (response.statusCode != 200) {
        _lastPackError = 'Paket indirilemedi (HTTP ${response.statusCode}).';
        debugPrint('Content sync HTTP ${response.statusCode}');
        completer.complete(false);
        return ContentSyncOutcome(
          success: false,
          downloaded: false,
          message: _lastPackError,
          statusCode: response.statusCode,
        );
      }

      final body = await Isolate.run(
        () => decodeJsonUtf8Bytes(response.bodyBytes),
      );
      await ContentBankService.instance.applyPublishedPack(body);
      _lastSyncAt = DateTime.now();
      debugPrint(
        'Content sync OK v${ContentBankService.instance.packVersion}',
      );
      completer.complete(true);
      return ContentSyncOutcome(
        success: true,
        downloaded: true,
        remoteVersion: ContentBankService.instance.packVersion,
      );
    } catch (e) {
      _lastPackError = 'Paket indirilemedi. İnternet bağlantınızı kontrol edin.';
      debugPrint('Content sync failed: $e');
      completer.complete(false);
      return ContentSyncOutcome(
        success: false,
        downloaded: false,
        message: _lastPackError,
      );
    } finally {
      _activeSync = null;
    }
  }

  static String _yearlyPremiumMessage(http.Response response) {
    try {
      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final code = '${body['code'] ?? ''}';
      if (code == 'yearly_premium_required') {
        return 'Yıllık Premium gerekli';
      }
      final detail = (body['detail'] as String?)?.trim();
      if (detail != null && detail.isNotEmpty) return detail;
    } catch (_) {}
    return 'Yıllık Premium gerekli';
  }
}

class PackVersionOutcome {
  final int? version;
  final String? error;
  final int? statusCode;

  const PackVersionOutcome({
    this.version,
    this.error,
    this.statusCode,
  });
}

class ContentSyncOutcome {
  final bool success;
  final bool downloaded;
  final bool usedOfflineCache;
  final String? message;
  final int? remoteVersion;
  final int? statusCode;

  const ContentSyncOutcome({
    required this.success,
    required this.downloaded,
    this.usedOfflineCache = false,
    this.message,
    this.remoteVersion,
    this.statusCode,
  });
}
