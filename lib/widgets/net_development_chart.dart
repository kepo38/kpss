import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';

/// Bir haftalık veya aylık deneme neti için grafik veri noktası.
class NetDevelopmentPoint {
  final String label;
  final double totalNet;
  final double? gyNet;
  final double? gkNet;

  const NetDevelopmentPoint({
    required this.label,
    required this.totalNet,
    this.gyNet,
    this.gkNet,
  });
}

/// Çok serili net gelişim grafiği; veri kaynağı haftalık/aylık nokta listesi.
class NetDevelopmentChart extends StatelessWidget {
  final List<NetDevelopmentPoint> points;
  final String primaryLabel;
  final String? secondaryLabel;
  final String? tertiaryLabel;
  final double height;

  const NetDevelopmentChart({
    super.key,
    required this.points,
    this.primaryLabel = 'Toplam',
    this.secondaryLabel = 'GY',
    this.tertiaryLabel = 'GK',
    this.height = 220,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: const Center(child: Text('Grafik için veri yok')),
      );
    }

    final gy = points.map((point) => point.gyNet).toList();
    final gk = points.map((point) => point.gkNet).toList();
    final hasGy = gy.every((value) => value != null);
    final hasGk = gk.every((value) => value != null);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 16,
          children: [
            _LegendDot(color: AppTheme.lightPrimary, label: primaryLabel),
            if (hasGy && secondaryLabel != null)
              _LegendDot(color: AppTheme.lightAccent, label: secondaryLabel!),
            if (hasGk && tertiaryLabel != null)
              _LegendDot(color: Colors.teal, label: tertiaryLabel!),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: _LineChartPainter(
              labels: points.map((point) => point.label).toList(),
              series: [
                _ChartSeries(
                  points.map((point) => point.totalNet).toList(),
                  AppTheme.lightPrimary,
                ),
                if (hasGy)
                  _ChartSeries(
                    gy.cast<double>(),
                    AppTheme.lightAccent,
                  ),
                if (hasGk) _ChartSeries(gk.cast<double>(), Colors.teal),
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

    final allValues = series.expand((item) => item.values).toList();
    var minY = allValues.reduce(math.min);
    var maxY = allValues.reduce(math.max);
    if (minY == maxY) {
      minY -= 5;
      maxY += 5;
    } else {
      final padding = (maxY - minY) * 0.1;
      minY -= padding;
      maxY += padding;
    }

    const leftPad = 36.0;
    const bottomPad = 28.0;
    final chartWidth = size.width - leftPad;
    final chartHeight = size.height - bottomPad;
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1;

    for (var i = 0; i <= 4; i++) {
      final y = chartHeight * i / 4;
      canvas.drawLine(Offset(leftPad, y), Offset(size.width, y), gridPaint);
      final value = maxY - (maxY - minY) * i / 4;
      final text = TextPainter(
        text: TextSpan(
          text: value.toStringAsFixed(0),
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(0, y - 6));
    }

    final count = series.first.values.length;
    for (final item in series) {
      final path = Path();
      final fillPath = Path();
      for (var i = 0; i < item.values.length; i++) {
        final x = count == 1
            ? leftPad + chartWidth / 2
            : leftPad + chartWidth * i / (count - 1);
        final y = chartHeight -
            ((item.values[i] - minY) / (maxY - minY)) * chartHeight;
        if (i == 0) {
          path.moveTo(x, y);
          fillPath
            ..moveTo(x, chartHeight)
            ..lineTo(x, y);
        } else {
          path.lineTo(x, y);
          fillPath.lineTo(x, y);
        }
        if (i == item.values.length - 1) fillPath.lineTo(x, chartHeight);
      }
      fillPath.close();
      canvas.drawPath(
        fillPath,
        Paint()..color = item.color.withValues(alpha: 0.08),
      );
      canvas.drawPath(
        path,
        Paint()
          ..color = item.color
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
      for (var i = 0; i < item.values.length; i++) {
        final x = count == 1
            ? leftPad + chartWidth / 2
            : leftPad + chartWidth * i / (count - 1);
        final y = chartHeight -
            ((item.values[i] - minY) / (maxY - minY)) * chartHeight;
        canvas.drawCircle(Offset(x, y), 4, Paint()..color = item.color);
      }
    }

    for (var i = 0; i < labels.length && i < count; i++) {
      final x = count == 1
          ? leftPad + chartWidth / 2
          : leftPad + chartWidth * i / (count - 1);
      final label = labels[i];
      final short = label.length > 8 ? '${label.substring(0, 7)}…' : label;
      final text = TextPainter(
        text: TextSpan(
          text: short,
          style: const TextStyle(fontSize: 9, color: Colors.grey),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 48);
      text.paint(canvas, Offset(x - text.width / 2, chartHeight + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}
