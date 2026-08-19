import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path/path.dart' as p;
import 'package:share_plus/share_plus.dart';

import '../../constants/brand_constants.dart';

/// Bugünün kürsüsü bloğunu PNG + metin olarak paylaşır.
class DailyMiniPodiumShare {
  DailyMiniPodiumShare._();

  static Future<bool> share({
    required GlobalKey boundaryKey,
    required String shareText,
  }) async {
    if (kIsWeb) {
      await Share.share(shareText);
      return true;
    }

    try {
      final context = boundaryKey.currentContext;
      if (context == null) {
        await Share.share(shareText);
        return false;
      }
      final boundary = context.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        await Share.share(shareText);
        return false;
      }

      final image = await boundary.toImage(pixelRatio: 3);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        await Share.share(shareText);
        return false;
      }

      final file = File(
        p.join(
          Directory.systemTemp.path,
          'hedef_kamu_kursu_${DateTime.now().millisecondsSinceEpoch}.png',
        ),
      );
      await file.writeAsBytes(bytes.buffer.asUint8List());

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text: shareText,
        subject: '${BrandConstants.appName} · Günün Kürsüsü',
      );
      return true;
    } catch (_) {
      await Share.share(shareText);
      return false;
    }
  }
}
