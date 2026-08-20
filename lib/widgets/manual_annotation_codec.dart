import 'dart:convert';

import 'package:flutter/material.dart';

import 'quiz_drawing_overlay.dart';

/// Kitap foto çizimleri — noktalar 0–1 normalize; farklı ekranda ölçeklenir.
class ManualAnnotationCodec {
  ManualAnnotationCodec._();

  static String encode(List<QuizStroke> strokes, Size size) {
    final w = size.width <= 0 ? 1.0 : size.width;
    final h = size.height <= 0 ? 1.0 : size.height;
    final payload = strokes.map((s) {
      return <String, dynamic>{
        'color': s.color.toARGB32(),
        'width': s.width,
        'eraser': s.eraser,
        'highlighter': s.highlighter,
        'points': [
          for (final p in s.points) [p.dx / w, p.dy / h],
        ],
      };
    }).toList();
    return jsonEncode(payload);
  }

  static List<QuizStroke> decode(String? raw, Size size) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final w = size.width <= 0 ? 1.0 : size.width;
      final h = size.height <= 0 ? 1.0 : size.height;
      final out = <QuizStroke>[];
      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final pointsRaw = map['points'];
        if (pointsRaw is! List || pointsRaw.length < 2) continue;
        final points = <Offset>[];
        for (final p in pointsRaw) {
          if (p is! List || p.length < 2) continue;
          final nx = (p[0] as num).toDouble();
          final ny = (p[1] as num).toDouble();
          points.add(Offset(nx * w, ny * h));
        }
        if (points.length < 2) continue;
        out.add(
          QuizStroke(
            points: points,
            color: Color((map['color'] as num?)?.toInt() ?? 0xFFE53935),
            width: (map['width'] as num?)?.toDouble() ?? 4.5,
            eraser: map['eraser'] == true,
            highlighter: map['highlighter'] == true,
          ),
        );
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
