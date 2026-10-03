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
    final netPct = (result.netAccuracy * 100).round();
    final rawPct = (result.accuracy * 100).round();
    final net = result.net.toStringAsFixed(2);

    return Container(
      width: 320,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF1A283C),
            Color(0xFF0C1424),
            Color(0xFF0A101C),
          ],
        ),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.38),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const BrandMark(dark: true, logoSize: 36, compact: true),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  testTitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.25,
                    letterSpacing: 0.15,
                    color: AppTheme.champagneLight,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 28),
          Text(
            'NET',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 3.2,
              fontWeight: FontWeight.w600,
              color: AppTheme.champagne.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            net,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 52,
              fontWeight: FontWeight.w700,
              height: 0.95,
              color: AppTheme.champagneLight,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Net oranı %$netPct',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppTheme.neonEdge.withValues(alpha: 0.95),
            ),
          ),
          if (rawPct != netPct) ...[
            const SizedBox(height: 4),
            Text(
              'Ham %$rawPct',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
                color: Colors.white.withValues(alpha: 0.38),
              ),
            ),
          ],
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Colors.white.withValues(alpha: 0.04),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _MetricStripItem(
                    label: 'Doğru',
                    value: '${result.correct}',
                    color: const Color(0xFF4ADE80),
                  ),
                ),
                _MetricDivider(),
                Expanded(
                  child: _MetricStripItem(
                    label: 'Yanlış',
                    value: '${result.wrong}',
                    color: const Color(0xFFF87171),
                  ),
                ),
                _MetricDivider(),
                Expanded(
                  child: _MetricStripItem(
                    label: 'Boş',
                    value: '${result.blank}',
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 14,
                color: Colors.white.withValues(alpha: 0.42),
              ),
              const SizedBox(width: 6),
              Text(
                QuizResult.formatDuration(result.duration),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
              const Spacer(),
              Text(
                '${result.total} soru · ort. ${QuizResult.formatDuration(result.averageQuestionDuration)}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.07),
          ),
          const SizedBox(height: 12),
          Text(
            'Ben de ${BrandConstants.appName} ile çalışıyorum',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
              color: Colors.white.withValues(alpha: 0.42),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      color: Colors.white.withValues(alpha: 0.1),
    );
  }
}

class _MetricStripItem extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MetricStripItem({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.1,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
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
    final netPct = (result.netAccuracy * 100).round();
    return '${BrandConstants.appName} · $title\n'
        'Net ${result.net.toStringAsFixed(2)} · Net oranı %$netPct\n'
        'Doğru ${result.correct} · Yanlış ${result.wrong} · Boş ${result.blank}\n'
        '${BrandConstants.shareHashtag}';
  }

  static String _shareText(String title, QuizResult result) =>
      shareText(title, result);
}
