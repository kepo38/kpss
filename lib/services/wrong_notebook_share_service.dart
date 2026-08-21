import 'dart:async';
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

  String get _caption => '$sharePrompt\n\n${BrandConstants.shareHashtag}';

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
          'Ekran görüntüsü yasaktır. Yanlış defterinden günde '
          '${AdConstants.wrongNotebookSharesPerDayFree} soru paylaşabilirsin; '
          'bunun için kısa bir reklam izlemen gerekir. Devam edilsin mi?',
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
    if (!await ensureCanShare(context)) return false;
    if (!context.mounted) return false;

    return _shareRenderedCard(
      context,
      card: WrongNotebookShareCard.bank(question: question),
      shareOrigin: shareOrigin,
      waitForRemoteImage: question.imageUrl?.trim().isNotEmpty ?? false,
    );
  }

  Future<bool> shareManualQuestion(
    BuildContext context,
    ManualQuestionModel item, {
    Rect? shareOrigin,
  }) async {
    if (!await ensureCanShare(context)) return false;
    if (!context.mounted) return false;

    final path = item.imagePath.trim();
    if (path.isEmpty || kIsWeb) {
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
    );
  }

  Future<bool> _shareRenderedCard(
    BuildContext context, {
    required Widget card,
    Rect? shareOrigin,
    required bool waitForRemoteImage,
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

    File? file;
    try {
      file = await _captureCardImage(
        context,
        card: card,
        waitForRemoteImage: waitForRemoteImage,
      );
    } catch (e) {
      debugPrint('WrongNotebookShare capture: $e');
    }

    if (file == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Görsel oluşturulamadı. Soru metni güvenlik için paylaşılmaz.',
            ),
          ),
        );
      }
      return false;
    }

    try {
      final result = await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: _caption,
        subject: '${BrandConstants.appName} · Soru',
        sharePositionOrigin: shareOrigin,
      );
      // İptal (dismissed) hariç kotayı düş — Android'de success yerine
      // unavailable da gelebilir; sheet açıldıysa sızıntı riski var.
      if (result.status != ShareResultStatus.dismissed) {
        final premium = PremiumService.instance.isPremium ||
            AdManager.instance.isPremium;
        await AdManager.instance.consumeWrongNotebookShare(premium: premium);
      }
      return true;
    } catch (e) {
      debugPrint('WrongNotebookShare share: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Paylaşım açılamadı.')),
        );
      }
      return false;
    }
  }

  /// Filigranlı kartı ekranda boyayıp (yükleme örtüsü altında) PNG’ye alır.
  Future<File?> _captureCardImage(
    BuildContext context, {
    required Widget card,
    required bool waitForRemoteImage,
  }) async {
    return ScreenshotGate.runAllowingCapture(() async {
      final boundaryKey = GlobalKey();
      final completer = Completer<File?>();

      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          barrierColor: Colors.black.withValues(alpha: 0.72),
          builder: (dialogContext) {
            WidgetsBinding.instance.addPostFrameCallback((_) async {
              try {
                // Layout + font/görsel için birkaç kare bekle.
                final waitMs = waitForRemoteImage ? 1200 : 500;
                await Future<void>.delayed(Duration(milliseconds: waitMs));
                for (var i = 0; i < 3; i++) {
                  await WidgetsBinding.instance.endOfFrame;
                }

                final boundary = boundaryKey.currentContext?.findRenderObject()
                    as RenderRepaintBoundary?;
                if (boundary == null || !boundary.hasSize) {
                  if (dialogContext.mounted) {
                    Navigator.of(dialogContext).pop();
                  }
                  if (!completer.isCompleted) completer.complete(null);
                  return;
                }

                // Release’te debugNeedsPaint kullanma — assert fırlatır.
                if (kDebugMode && boundary.debugNeedsPaint) {
                  await Future<void>.delayed(const Duration(milliseconds: 160));
                  await WidgetsBinding.instance.endOfFrame;
                }

                final image = await boundary.toImage(pixelRatio: 2.5);
                final png =
                    await image.toByteData(format: ui.ImageByteFormat.png);
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (png == null) {
                  if (!completer.isCompleted) completer.complete(null);
                  return;
                }
                final file = File(
                  p.join(
                    Directory.systemTemp.path,
                    'hedef_kamu_soru_${DateTime.now().millisecondsSinceEpoch}.png',
                  ),
                );
                await file.writeAsBytes(png.buffer.asUint8List(), flush: true);
                if (!completer.isCompleted) completer.complete(file);
              } catch (e) {
                debugPrint('WrongNotebookShare raster: $e');
                if (dialogContext.mounted) {
                  Navigator.of(dialogContext).pop();
                }
                if (!completer.isCompleted) completer.complete(null);
              }
            });

            return Stack(
              fit: StackFit.expand,
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: SingleChildScrollView(
                    child: RepaintBoundary(
                      key: boundaryKey,
                      child: card,
                    ),
                  ),
                ),
                const ColoredBox(color: Color(0xB8000000)),
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
        ).then((_) {
          if (!completer.isCompleted) completer.complete(null);
        }),
      );

      return completer.future.timeout(
        const Duration(seconds: 20),
        onTimeout: () => null,
      );
    });
  }
}
