import 'dart:convert';

import 'package:flutter/material.dart';

import 'quiz_drawing_overlay.dart';

/// Quiz içeriği üzerinde mutlak koordinatlarla kaydedilmiş çizimler.
class QuizStrokeCodec {
  QuizStrokeCodec._();

  static String encode(List<QuizStroke> strokes) {
    final payload = strokes.map((stroke) {
      return <String, dynamic>{
        'color': stroke.color.toARGB32(),
        'width': stroke.width,
        'eraser': stroke.eraser,
        'highlighter': stroke.highlighter,
        'points': [
          for (final point in stroke.points) [point.dx, point.dy],
        ],
      };
    }).toList();
    return jsonEncode(payload);
  }

  static List<QuizStroke> decode(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final list = jsonDecode(raw);
      if (list is! List) return const [];
      final out = <QuizStroke>[];
      for (final item in list) {
        if (item is! Map) continue;
        final map = Map<String, dynamic>.from(item);
        final pointsRaw = map['points'];
        if (pointsRaw is! List) continue;
        final points = <Offset>[];
        for (final point in pointsRaw) {
          if (point is! List || point.length < 2) continue;
          points.add(
            Offset(
              (point[0] as num).toDouble(),
              (point[1] as num).toDouble(),
            ),
          );
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
