import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Çok serili çizgi grafik — net gelişim trendi.
class NetLineChart extends StatelessWidget {
  final List<String> labels;
  final List<double> primaryValues;
  final List<double>? secondaryValues;
  final List<double>? tertiaryValues;
  final String primaryLabel;
  final String? secondaryLabel;
  final String? tertiaryLabel;
  final double height;

  const NetLineChart({
    super.key,
    required this.labels,
    required this.primaryValues,
    this.secondaryValues,
    this.tertiaryValues,
    this.primaryLabel = 'Toplam Net',
    this.secondaryLabel,
    this.tertiaryLabel,
    this.height = 200,
  });

  @override
  Widget build(BuildContext context) {
    if (primaryValues.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Grafik için veri yok')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            _LegendDot(color: AppTheme.lightPrimary, label: primaryLabel),
            if (secondaryValues != null && secondaryLabel != null)
              _LegendDot(color: AppTheme.lightAccent, label: secondaryLabel!),
            if (tertiaryValues != null && tertiaryLabel != null)
              _LegendDot(color: Colors.teal, label: tertiaryLabel!),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(
              labels: labels,
              series: [
                _ChartSeries(primaryValues, AppTheme.lightPrimary),
                if (secondaryValues != null)
                  _ChartSeries(secondaryValues!, AppTheme.lightAccent),
                if (tertiaryValues != null)
                  _ChartSeries(tertiaryValues!, Colors.teal),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 12)),
      ],
    );
  }
}

class _ChartSeries {
  final List<double> values;
  final Color color;
  const _ChartSeries(this.values, this.color);
}

class _LineChartPainter extends CustomPainter {
  final List<String> labels;
  final List<_ChartSeries> series;

  _LineChartPainter({required this.labels, required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty || series.first.values.isEmpty) return;

    final allValues = series.expand((s) => s.values).toList();
    var minY = allValues.reduce(math.min);
    var maxY = allValues.reduce(math.max);
    if (minY == maxY) {
      minY -= 5;
      maxY += 5;
    } else {
      final pad = (maxY - minY) * 0.1;
      minY -= pad;
      maxY += pad;
    }

    const leftPad = 36.0;
    const bottomPad = 28.0;
    final chartW = size.width - leftPad;
    final chartH = size.height - bottomPad;

    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chartH * i / 4;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final val = maxY - (maxY - minY) * i / 4;
      final tp = TextPainter(
        text: TextSpan(
          text: val.toStringAsFixed(0),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, y - 6));
    }

    final count = series.first.values.length;
    if (count == 1) {
      for (final s in series) {
        final x = leftPad + chartW / 2;
        final y = chartH - ((s.values.first - minY) / (maxY - minY)) * chartH;
        canvas.drawCircle(Offset(x, y), 5, Paint()..color = s.color);
      }
    } else {
      for (final s in series) {
        final path = Path();
        final fillPath = Path();
        for (var i = 0; i < s.values.length; i++) {
          final x = leftPad + (chartW * i / (count - 1));
          final y = chartH - ((s.values[i] - minY) / (maxY - minY)) * chartH;
          if (i == 0) {
            path.moveTo(x, y);
            fillPath.moveTo(x, chartH);
            fillPath.lineTo(x, y);
          } else {
            path.lineTo(x, y);
            fillPath.lineTo(x, y);
          }
          if (i == s.values.length - 1) fillPath.lineTo(x, chartH);
        }
        fillPath.close();
        canvas.drawPath(
          fillPath,
          Paint()..color = s.color.withValues(alpha: 0.08),
        );
        canvas.drawPath(
          path,
          Paint()
            ..color = s.color
            ..strokeWidth = 2.5
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round,
        );
        for (var i = 0; i < s.values.length; i++) {
          final x = leftPad + (chartW * i / (count - 1));
          final y = chartH - ((s.values[i] - minY) / (maxY - minY)) * chartH;
          canvas.drawCircle(Offset(x, y), 4, Paint()..color = s.color);
        }
      }
    }

    for (var i = 0; i < labels.length && i < count; i++) {
      final x = count == 1
          ? leftPad + chartW / 2
          : leftPad + (chartW * i / (count - 1));
      final label = labels[i];
      final short = label.length > 8 ? '${label.substring(0, 7)}…' : label;
      final tp = TextPainter(
        text: TextSpan(
          text: short,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 48);
      tp.paint(canvas, Offset(x - tp.width / 2, chartH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}
