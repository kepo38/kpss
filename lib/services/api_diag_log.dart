import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../config/api_config.dart';

/// API / katalog senkron teşhisi — logcat + dosya + ekranda kısa ipucu.
class ApiDiagLog {
  ApiDiagLog._();

  static const fileName = 'api-diag.log';
  static const maxBytes = 80 * 1024;

  /// Son senkron özeti — UI banner / SnackBar için.
  static final ValueNotifier<ApiDiagEntry?> lastEntry =
      ValueNotifier<ApiDiagEntry?>(null);

  static Future<File?> _file() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final logs = Directory('${dir.path}/logs');
      if (!await logs.exists()) {
        await logs.create(recursive: true);
      }
      return File('${logs.path}/$fileName');
    } catch (e) {
      debugPrint('ApiDiagLog path: $e');
      return null;
    }
  }

  static Future<String?> filePath() async {
    final f = await _file();
    return f?.path;
  }

  /// Hata sınıfı + kullanıcıya gösterilecek kısa Türkçe ipucu.
  static ({String kind, String tip}) classify(Object error) {
    final raw = error.toString();
    final lower = raw.toLowerCase();

    if (lower.contains('timeout') || lower.contains('timed out')) {
      return (
        kind: 'timeout',
        tip: 'Sunucu yanıt vermedi. Telefon Wi‑Fi kapalıysa basla-telefon.bat '
            'ile USB reverse kullanın; açıkken PC ile aynı Wi‑Fi’de olun.',
      );
    }
    if (lower.contains('connection refused') ||
        lower.contains('connection reset') ||
        lower.contains('network is unreachable') ||
        lower.contains('no route to host') ||
        lower.contains('failed host lookup') ||
        lower.contains('socketexception')) {
      return (
        kind: 'unreachable',
        tip: 'API’ye ulaşılamadı (${ApiConfig.baseUrl}). Django ayakta mı? '
            'Wi‑Fi kapalıysa USB reverse şart; LAN ise güvenlik duvarı 8000.',
      );
    }
    if (lower.contains('handshake') || lower.contains('certificate')) {
      return (
        kind: 'tls',
        tip: 'TLS/sertifika hatası — geliştirmede http:// kullanın.',
      );
    }
    return (
      kind: 'other',
      tip: 'İçerik senkronu başarısız (${ApiConfig.baseUrl}).',
    );
  }

  static Future<void> record({
    required String event,
    required bool ok,
    int? statusCode,
    int? elapsedMs,
    Object? error,
    String? detail,
  }) async {
    final classified =
        error != null ? classify(error) : (kind: ok ? 'ok' : 'fail', tip: '');
    final entry = ApiDiagEntry(
      at: DateTime.now(),
      event: event,
      ok: ok,
      apiBase: ApiConfig.baseUrl,
      statusCode: statusCode,
      elapsedMs: elapsedMs,
      kind: classified.kind,
      tip: classified.tip.isNotEmpty
          ? classified.tip
          : (ok
              ? 'Katalog senkronu tamam.'
              : 'İçerik senkronu başarısız (${ApiConfig.baseUrl}).'),
      detail: detail ?? (error?.toString() ?? ''),
    );
    lastEntry.value = entry;

    final line = entry.toLogLine();
    debugPrint(line);

    final file = await _file();
    if (file == null) return;
    try {
      if (await file.exists() && await file.length() > maxBytes) {
        final keep = await file.readAsString();
        final trimmed = keep.length > maxBytes ~/ 2
            ? keep.substring(keep.length - maxBytes ~/ 2)
            : keep;
        await file.writeAsString('$trimmed\n--- truncated ---\n');
      }
      await file.writeAsString('$line\n', mode: FileMode.append);
    } catch (e) {
      debugPrint('ApiDiagLog write: $e');
    }
  }
}

class ApiDiagEntry {
  final DateTime at;
  final String event;
  final bool ok;
  final String apiBase;
  final int? statusCode;
  final int? elapsedMs;
  final String kind;
  final String tip;
  final String detail;

  const ApiDiagEntry({
    required this.at,
    required this.event,
    required this.ok,
    required this.apiBase,
    required this.kind,
    required this.tip,
    this.statusCode,
    this.elapsedMs,
    this.detail = '',
  });

  String toLogLine() {
    final ts = at.toIso8601String();
    final code = statusCode != null ? ' http=$statusCode' : '';
    final ms = elapsedMs != null ? ' ${elapsedMs}ms' : '';
    final err = detail.isNotEmpty ? ' err=$detail' : '';
    return '[ApiDiag] $ts event=$event ok=$ok kind=$kind api=$apiBase$code$ms$err | $tip';
  }

  /// SnackBar / banner kısa metin.
  String get shortMessage {
    if (ok) return tip;
    return tip;
  }
}
