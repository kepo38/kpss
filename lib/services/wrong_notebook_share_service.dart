import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../constants/brand_constants.dart';
import '../models/manual_question_model.dart';
import '../models/question_model.dart';
import '../widgets/account_link_card.dart';
import '../widgets/wrong_notebook/wrong_notebook_share_card.dart';
import 'ad_constants.dart';
import 'ad_manager.dart';
import 'ad_service.dart';
import 'premium_service.dart';
import 'screenshot_gate.dart';

/// Yanlış defteri → WhatsApp / sistem paylaşımı.
///
/// Soru metni asla düz metin olarak gitmez; yalnızca filigranlı görsel +
/// kısa yardım cümlesi paylaşılır.
class WrongNotebookShareService {
  WrongNotebookShareService._();
  static final WrongNotebookShareService instance =
      WrongNotebookShareService._();

  static const sharePrompt =
      'HEDEF KAMU uygulamasındaki bu soruyu anlamadım, yardımcı olur musun?';

  /// Son başarısız yakalama nedeni (log + snackbar kodu).
  static String? lastFailureCode;
  static String? lastFailureDetail;

  String get _caption => '$sharePrompt\n\n${BrandConstants.shareHashtag}';

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    // release logcat'te de görünsün
    developer.log(
      message,
      name: 'WrongNotebookShare',
      error: error,
      stackTrace: stackTrace,
    );
    debugPrint('WrongNotebookShare: $message${error != null ? ' | $error' : ''}');
  }

  void _fail(String code, String detail, {Object? error, StackTrace? st}) {
    lastFailureCode = code;
    lastFailureDetail = detail;
    _log('FAIL[$code] $detail', error: error, stackTrace: st);
  }

  /// Google + günlük kota + (ücretsizde reklam) kontrolü.
  Future<bool> ensureCanShare(BuildContext context) async {
    final linked = await AccountLinkCard.prompt(
      context,
      title: 'Paylaşım için Google girişi',
      subtitle:
          'Yanlış defterinden WhatsApp’a paylaşmak için Google ile giriş yapın.',
    );
    if (!linked) return false;

    final premium =
        PremiumService.instance.isPremium || AdManager.instance.isPremium;
    final remaining = await AdManager.instance
        .wrongNotebookSharesRemainingToday(premium: premium);
    if (remaining <= 0) {
      if (context.mounted) {
        final limit = AdManager.instance.wrongNotebookShareLimit(
          premium: premium,
        );
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              premium
                  ? 'Bugünkü paylaşım hakkın doldu ($limit/gün). '
                      'Ekran görüntüsü alınamaz; yarın tekrar dene.'
                  : 'Ücretsiz hesapta günde en fazla $limit paylaşım var. '
                      'Ekran görüntüsü alınamaz.',
            ),
          ),
        );
      }
      return false;
    }

    if (premium) return true;

    if (await AdManager.instance.hasWrongNotebookShareUnlockToday()) {
      return true;
    }

    if (!context.mounted) return false;
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Paylaşım hakkı'),
        content: Text(
          'Ekran görüntüsü yasaktır. Yanlış defterinden '
          'GÜNDE ${AdConstants.wrongNotebookSharesPerDayFree} SORU PAYLAŞABİLİRSİNİZ; '
          'bunun için kısa bir reklam izlemeniz gerekir. Devam edilsin mi?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reklam izle'),
          ),
        ],
      ),
    );
    if (proceed != true) return false;

    final earned = await AdService.showRewardedAd(
      kind: AdRewardKind.wrongNotebookShare,
    );
    if (!earned && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reklam izlenmedi veya yüklenemedi. Tekrar deneyin.'),
        ),
      );
    }
    return earned;
  }

  Future<bool> shareBankQuestion(
    BuildContext context,
    QuestionModel question, {
    Rect? shareOrigin,
  }) async {
    _log('shareBank start id=${question.id}');
    if (!await ensureCanShare(context)) {
      _log('shareBank aborted: ensureCanShare=false');
      return false;
    }
    if (!context.mounted) return false;

    return _shareRenderedCard(
      context,
      card: WrongNotebookShareCard.bank(question: question),
      shareOrigin: shareOrigin,
      waitForRemoteImage: question.imageUrl?.trim().isNotEmpty ?? false,
      kind: 'bank',
    );
  }

  Future<bool> shareManualQuestion(
    BuildContext context,
    ManualQuestionModel item, {
    Rect? shareOrigin,
  }) async {
    _log('shareManual start id=${item.id}');
    if (!await ensureCanShare(context)) {
      _log('shareManual aborted: ensureCanShare=false');
      return false;
    }
    if (!context.mounted) return false;

    final path = item.imagePath.trim();
    if (path.isEmpty || kIsWeb) {
      _fail('manual_path', 'path empty or web path="$path"');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Soru görseli bulunamadı; paylaşım iptal edildi.'),
          ),
        );
      }
      return false;
    }
    final exists = await File(path).exists();
    if (!context.mounted) return false;
    if (!exists) {
      _fail('manual_missing', 'file not found: $path');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Soru görseli bulunamadı; paylaşım iptal edildi.'),
        ),
      );
      return false;
    }

    return _shareRenderedCard(
      context,
      card: WrongNotebookShareCard.manual(item: item),
      shareOrigin: shareOrigin,
      waitForRemoteImage: false,
      kind: 'manual',
    );
  }

  Future<bool> _shareRenderedCard(
    BuildContext context, {
    required Widget card,
    Rect? shareOrigin,
    required bool waitForRemoteImage,
    required String kind,
  }) async {
    if (kIsWeb) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Web’de görsel paylaşım desteklenmiyor.'),
          ),
        );
      }
      return false;
    }

    lastFailureCode = null;
    lastFailureDetail = null;
    _log(
      'capture begin kind=$kind waitRemote=$waitForRemoteImage '
      'platform=${defaultTargetPlatform.name}',
    );

    File? file;
    try {
      file = await _captureCardImage(
        context,
        card: card,
        waitForRemoteImage: waitForRemoteImage,
      );
    } catch (e, st) {
      _fail('capture_throw', 'uncaught in capture', error: e, st: st);
    }

    if (file == null) {
      final code = lastFailureCode ?? 'unknown';
      _log('capture returned null code=$code detail=$lastFailureDetail');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Görsel oluşturulamadı ($code). '
              'Soru metni güvenlik için paylaşılmaz.',
            ),
          ),
        );
      }
      return false;
    }

    _log('capture ok bytes=${await file.length()} path=${file.path}');

    try {
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: _caption,
        subject: '${BrandConstants.appName} · Soru',
        sharePositionOrigin: shareOrigin,
      );
      _log('share sheet status=${result.status}');
      if (result.status != ShareResultStatus.dismissed) {
        final premium = PremiumService.instance.isPremium ||
            AdManager.instance.isPremium;
        await AdManager.instance.consumeWrongNotebookShare(premium: premium);
      }
      return true;
    } catch (e, st) {
      _fail('share_sheet', 'Share.shareXFiles failed', error: e, st: st);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Paylaşım açılamadı ($lastFailureCode).')),
        );
      }
      return false;
    }
  }

  /// Filigranlı kartı boyayıp PNG’ye alır (FLAG_SECURE geçici açık).
  Future<File?> _captureCardImage(
    BuildContext context, {
    required Widget card,
    required bool waitForRemoteImage,
  }) async {
    return ScreenshotGate.runAllowingCapture(() async {
      final gateOk = await ScreenshotGate.setAllowed(true);
      _log('ScreenshotGate allow=true ok=$gateOk');
      await Future<void>.delayed(const Duration(milliseconds: 100));
      if (!context.mounted) {
        _fail('unmounted', 'context unmounted after gate');
        return null;
      }

      final overlay = Overlay.maybeOf(context, rootOverlay: true);
      if (overlay == null) {
        _fail('no_overlay', 'Overlay.maybeOf rootOverlay returned null');
        return null;
      }

      final boundaryKey = GlobalKey();
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (ctx) {
          // Kart ekranda (görünmez) boyanır — negatif left bazı
          // cihazlarda layer’ı rasterize etmiyor.
          return Stack(
            fit: StackFit.expand,
            children: [
              Positioned(
                left: 0,
                top: 0,
                child: Opacity(
                  opacity: 0.02,
                  child: IgnorePointer(
                    child: Material(
                      type: MaterialType.transparency,
                      child: SizedBox(
                        width: WrongNotebookShareCard.cardWidth,
                        height: WrongNotebookShareCard.cardHeight,
                        child: OverflowBox(
                          alignment: Alignment.topLeft,
                          minWidth: WrongNotebookShareCard.cardWidth,
                          maxWidth: WrongNotebookShareCard.cardWidth,
                          minHeight: WrongNotebookShareCard.cardHeight,
                          maxHeight: WrongNotebookShareCard.cardHeight,
                          child: RepaintBoundary(
                            key: boundaryKey,
                            child: card,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const ModalBarrier(
                dismissible: false,
                color: Color(0xB8000000),
              ),
              const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 14),
                        Text('Paylaşım görseli hazırlanıyor…'),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      );

      overlay.insert(entry);
      _log('overlay inserted');
      try {
        final waitMs = waitForRemoteImage ? 1400 : 700;
        await Future<void>.delayed(Duration(milliseconds: waitMs));
        for (var i = 0; i < 5; i++) {
          await WidgetsBinding.instance.endOfFrame;
        }

        RenderRepaintBoundary? boundary;
        Size? lastSize;
        for (var attempt = 0; attempt < 10; attempt++) {
          final ctx = boundaryKey.currentContext;
          final ro = ctx?.findRenderObject();
          boundary = ro is RenderRepaintBoundary ? ro : null;
          lastSize = boundary?.hasSize == true ? boundary!.size : null;
          _log(
            'boundary try=$attempt hasCtx=${ctx != null} '
            'type=${ro.runtimeType} hasSize=${boundary?.hasSize} '
            'size=$lastSize',
          );
          if (boundary != null &&
              boundary.hasSize &&
              boundary.size.width > 8 &&
              boundary.size.height > 8) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
          await WidgetsBinding.instance.endOfFrame;
          boundary = null;
        }
        if (boundary == null) {
          _fail(
            'boundary',
            'RepaintBoundary ready değil lastSize=$lastSize',
          );
          return null;
        }

        if (kDebugMode && boundary.debugNeedsPaint) {
          _log('debugNeedsPaint=true, waiting extra frame');
          await Future<void>.delayed(const Duration(milliseconds: 200));
          await WidgetsBinding.instance.endOfFrame;
        }

        ui.Image? image;
        Object? lastErr;
        for (var attempt = 0; attempt < 4; attempt++) {
          final target = boundaryKey.currentContext?.findRenderObject();
          if (target is! RenderRepaintBoundary || !target.hasSize) {
            lastErr = 'missing on toImage attempt $attempt';
            _log('toImage skip: $lastErr');
            await Future<void>.delayed(const Duration(milliseconds: 120));
            await WidgetsBinding.instance.endOfFrame;
            continue;
          }
          try {
            _log(
              'toImage attempt=$attempt size=${target.size} '
              'pixelRatio=2.0',
            );
            image = await target.toImage(pixelRatio: 2.0);
            _log(
              'toImage ok ${image.width}x${image.height}',
            );
            break;
          } catch (e, st) {
            lastErr = e;
            _log('toImage retry $attempt failed', error: e, stackTrace: st);
            await Future<void>.delayed(const Duration(milliseconds: 150));
            await WidgetsBinding.instance.endOfFrame;
          }
        }
        if (image == null) {
          _fail('to_image', 'toImage failed after retries', error: lastErr);
          return null;
        }

        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final w = image.width;
        final h = image.height;
        image.dispose();
        if (png == null) {
          _fail('png_null', 'toByteData returned null (${w}x$h)');
          return null;
        }

        final bytes = png.buffer.asUint8List();
        _log('png bytes=${bytes.length} ${w}x$h');
        if (bytes.length < 64) {
          _fail('png_tiny', 'PNG too small: ${bytes.length} bytes');
          return null;
        }

        final file = File(
          p.join(
            Directory.systemTemp.path,
            'hedef_kamu_soru_${DateTime.now().millisecondsSinceEpoch}.png',
          ),
        );
        await file.writeAsBytes(bytes, flush: true);
        final written = await file.length();
        _log('wrote $written bytes → ${file.path}');
        if (written < 64) {
          _fail('write_tiny', 'file length $written after write');
          return null;
        }
        lastFailureCode = null;
        lastFailureDetail = null;
        return file;
      } catch (e, st) {
        _fail('raster', 'unexpected raster error', error: e, st: st);
        return null;
      } finally {
        entry.remove();
        _log('overlay removed');
      }
    });
  }
}
