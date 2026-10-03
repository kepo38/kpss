import 'package:flutter/material.dart';

import '../models/subject_performance.dart';
import '../theme/app_theme.dart';

/// Gelişim sekmesi başarı özeti — net oranı odaklı hero.
class AnalyticsSuccessHero extends StatelessWidget {
  final OverallPerformance overall;

  const AnalyticsSuccessHero({super.key, required this.overall});

  @override
  Widget build(BuildContext context) {
    final hasData = overall.solved > 0;
    final netPct = (overall.netAccuracy * 100).round();
    final rawPct = (overall.successRate * 100).round();
    final netLabel = overall.net.toStringAsFixed(2);
    // Yay dolumu 0..1; negatif net oranı 0 gösterilir (etikette gerçek net kalır).
    final arcRatio = overall.netAccuracy.clamp(0.0, 1.0);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1E2C42),
            Color(0xFF0C1424),
            Color(0xFF080E18),
          ],
          stops: [0.0, 0.55, 1.0],
        ),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.4),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -36,
            right: -28,
            child: IgnorePointer(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.champagne.withValues(alpha: 0.14),
                      AppTheme.champagne.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 8,
            left: -20,
            child: IgnorePointer(
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.neonEdge.withValues(alpha: 0.07),
                      AppTheme.neonEdge.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'BAŞARI',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 2.8,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.champagne.withValues(alpha: 0.88),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Konu testleri',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withValues(alpha: 0.42),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              if (hasData) ...[
                SizedBox(
                  height: 156,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: arcRatio),
                    duration: reduceMotion
                        ? Duration.zero
                        : const Duration(milliseconds: 700),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      return CustomPaint(
                        painter: _NetRatioArcPainter(
                          progress: value,
                          trackColor: Colors.white.withValues(alpha: 0.08),
                          progressColor: AppTheme.neonEdge,
                          accentColor: AppTheme.champagne,
                        ),
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '%$netPct',
                                  style: const TextStyle(
                                    fontFamily: 'serif',
                                    fontSize: 42,
                                    fontWeight: FontWeight.w700,
                                    height: 0.95,
                                    color: AppTheme.champagneLight,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Net oranı',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.4,
                                    color: AppTheme.neonEdge.withValues(
                                      alpha: 0.92,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Net $netLabel',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'serif',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.champagneLight,
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
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _HeroMetric(
                        label: 'Doğru',
                        value: '${overall.correct}',
                        color: const Color(0xFF4ADE80),
                      ),
                    ),
                    const _HeroMetricDivider(),
                    Expanded(
                      child: _HeroMetric(
                        label: 'Yanlış',
                        value: '${overall.wrong}',
                        color: const Color(0xFFF87171),
                      ),
                    ),
                    const _HeroMetricDivider(),
                    Expanded(
                      child: _HeroMetric(
                        label: 'Boş',
                        value: '${overall.blank}',
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Text(
                      '${overall.solved} çözülen',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${overall.totalQuestions} soruluk havuz',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.white.withValues(alpha: 0.42),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  height: 132,
                  child: CustomPaint(
                    painter: _NetRatioArcPainter(
                      progress: 0,
                      trackColor: Colors.white.withValues(alpha: 0.08),
                      progressColor: AppTheme.neonEdge,
                      accentColor: AppTheme.champagne,
                    ),
                    child: const Center(
                      child: Padding(
                        padding: EdgeInsets.only(top: 22),
                        child: Text(
                          'Henüz ölçüm yok',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Konu testlerini çözdükçe net oranın burada toplanır.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// ~240° yay: KPSS net oranını görsel odak olarak çizer.
class _NetRatioArcPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final Color accentColor;

  const _NetRatioArcPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.accentColor,
  });

  static const double _sweep = 4.1887902047863905; // 240°
  static const double _start = 2.6179938779914944; // 150°

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.shortestSide * 0.065;
    final radius = (size.shortestSide - stroke) / 2.05;
    final center = Offset(size.width / 2, size.height * 0.58);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep, false, track);

    final t = progress.clamp(0.0, 1.0);
    if (t <= 0) return;

    final fill = Paint()
      ..color = Color.lerp(progressColor, accentColor, t * 0.35)!
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, _start, _sweep * t, false, fill);
  }

  @override
  bool shouldRepaint(covariant _NetRatioArcPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.accentColor != accentColor;
  }
}

class _HeroMetricDivider extends StatelessWidget {
  const _HeroMetricDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.12),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _HeroMetric({
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
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
            color: Colors.white.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

