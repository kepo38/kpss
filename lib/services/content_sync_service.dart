import 'dart:async';

import 'dart:convert';



import 'package:flutter/foundation.dart';

import 'package:http/http.dart' as http;



import '../config/api_config.dart';

import 'content_bank_service.dart';



/// Django yayın paketini çeker; sürüm değişince anında günceller.

class ContentSyncService {

  ContentSyncService._();

  static final ContentSyncService instance = ContentSyncService._();



  Timer? _pollTimer;

  Completer<bool>? _activeSync;

  DateTime? _lastSyncAt;



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



  Future<int?> fetchRemoteVersion({

    Duration timeout = const Duration(seconds: 6),

  }) async {

    try {

      final response = await http

          .get(

            ApiConfig.packVersionUri(),

            headers: {'Accept': 'application/json'},

          )

          .timeout(timeout);

      if (response.statusCode != 200) return null;

      final body =

          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      final v = body['version'];

      if (v is int) return v;

      if (v is num) return v.toInt();

      return int.tryParse('$v');

    } catch (_) {

      return null;

    }

  }



  /// Sürüm değişmediyse paket indirme.

  Future<bool> syncIfNeeded({

    Duration timeout = const Duration(seconds: 12),

  }) async {

    await ContentBankService.instance.initialize();

    final remote = await fetchRemoteVersion(timeout: timeout);

    if (remote == null) return false;

    final local = ContentBankService.instance.packVersion;

    if (local != null && local == remote) return true;

    return syncCatalog(timeout: timeout, force: true);

  }



  /// Konu/test öncesi — önce sürüm kontrolü, gerekirse tam paket indirir.

  Future<ContentSyncOutcome> ensureFreshContent({

    Duration timeout = const Duration(seconds: 15),

    bool forceDownload = false,

  }) async {

    await ContentBankService.instance.initialize();

    final remote = await fetchRemoteVersion(timeout: timeout);

    if (remote == null) {
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

        message:

            'Sunucuya ulaşılamadı (${ApiConfig.baseUrl}). '

            'Telefon ve bilgisayar aynı Wi‑Fi\'de olmalı.',

      );

    }



    final local = ContentBankService.instance.packVersion;

    final needsDownload =

        forceDownload || local == null || local != remote;

    if (!needsDownload) {

      return const ContentSyncOutcome(

        success: true,

        downloaded: false,

        message: null,

      );

    }



    final ok = await syncCatalog(timeout: timeout, force: true);

    if (!ok) {

      return ContentSyncOutcome(

        success: false,

        downloaded: false,

        message:

            'İçerik güncellenemedi (${ApiConfig.baseUrl}). '

            'Django sunucusunun çalıştığından emin olun.',

      );

    }

    return ContentSyncOutcome(

      success: true,

      downloaded: true,

      message: null,

      remoteVersion: ContentBankService.instance.packVersion,

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

      final body =
          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
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

            ApiConfig.packUri(),

            headers: {'Accept': 'application/json'},

          )

          .timeout(timeout);

      if (response.statusCode != 200) {

        debugPrint('Content sync HTTP ${response.statusCode}');

        completer.complete(false);

        return false;

      }



      final body =

          jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

      await ContentBankService.instance.applyPublishedPack(body);

      _lastSyncAt = DateTime.now();

      debugPrint(

        'Content sync OK v${ContentBankService.instance.packVersion}',

      );

      completer.complete(true);

      return true;

    } catch (e) {

      debugPrint('Content sync failed: $e');

      completer.complete(false);

      return false;

    } finally {

      _activeSync = null;

    }

  }

}



class ContentSyncOutcome {
  final bool success;
  final bool downloaded;
  final bool usedOfflineCache;
  final String? message;
  final int? remoteVersion;

  const ContentSyncOutcome({
    required this.success,
    required this.downloaded,
    this.usedOfflineCache = false,
    this.message,
    this.remoteVersion,
  });
}


