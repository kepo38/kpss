import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../constants/brand_constants.dart';
import '../models/quiz_result.dart';
import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';

/// Test sonucu görsel kartı — paylaşıma hazır marka yüzeyi.
class ShareableResultCard extends StatelessWidget {
  final String testTitle;
  final QuizResult result;

  const ShareableResultCard({
    super.key,
    required this.testTitle,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    final pct = (result.accuracy * 100).round();
    final net = result.net.toStringAsFixed(2);

    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF162338),
            Color(0xFF0C1424),
            Color(0xFF101A2C),
          ],
        ),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.18),
            blurRadius: 22,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const BrandMark(dark: true, logoSize: 34, compact: true),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppTheme.champagne.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppTheme.champagne.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  testTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.2,
                    color: AppTheme.champagneLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.28),
              ),
            ),
            child: Column(
              children: [
                Text(
                  'NET',
                  style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.champagne.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  net,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 44,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: AppTheme.champagneLight,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '%$pct başarı',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.neonEdge.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _StatCell(
                  label: 'Doğru',
                  value: '${result.correct}',
                  color: const Color(0xFF4ADE80),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  label: 'Yanlış',
                  value: '${result.wrong}',
                  color: const Color(0xFFF87171),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _StatCell(
                  label: 'Boş',
                  value: '${result.blank}',
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: Colors.white.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 6),
              Text(
                QuizResult.formatDuration(result.duration),
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
              const Spacer(),
              Text(
                '${result.total} soru',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 12),
          Text(
            'Ben de ${BrandConstants.appName} ile çalışıyorum',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sonuç kartını PNG olarak kaydedip paylaşır.
class ResultCardShare {
  ResultCardShare._();

  static Future<bool> share({
    required GlobalKey boundaryKey,
    required String testTitle,
    required QuizResult result,
  }) async {
    if (kIsWeb) {
      await Share.share(_shareText(testTitle, result));
      return true;
    }

    try {
      final context = boundaryKey.currentContext;
      if (context == null) return false;
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return false;

      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return false;

      final dir = Directory.systemTemp;
      final file = File(
        p.join(
          dir.path,
          'hedef_kamu_sonuc_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: _shareText(testTitle, result),
        subject: '${BrandConstants.appName} Test Sonucum',
      );
      return true;
    } catch (_) {
      await Share.share(_shareText(testTitle, result));
      return false;
    }
  }

  static String shareText(String title, QuizResult result) {
    final pct = (result.accuracy * 100).round();
    return '${BrandConstants.appName} · $title\n'
        'Net ${result.net.toStringAsFixed(2)} · %$pct başarı\n'
        'Doğru ${result.correct} · Yanlış ${result.wrong} · Boş ${result.blank}\n'
        '${BrandConstants.shareHashtag}';
  }

  static String _shareText(String title, QuizResult result) =>
      shareText(title, result);
}
