import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Stüdyo hub hero — renkli ışık + geri + STÜDYO etiketi.
class HomeHeroSection extends StatelessWidget {
  final double topPad;
  final Animation<double> fadeEarly;
  final Animation<double> fadeType;

  const HomeHeroSection({
    super.key,
    required this.topPad,
    required this.fadeEarly,
    required this.fadeType,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          top: -90,
          right: -40,
          child: IgnorePointer(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.champagne.withValues(alpha: 0.32),
                    const Color(0xFFE8A87C).withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                  stops: const [0, 0.45, 1],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 40,
          left: -90,
          child: IgnorePointer(
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonEdge.withValues(alpha: 0.28),
                    AppTheme.neonEdge.withValues(alpha: 0.06),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 160,
          right: 40,
          child: IgnorePointer(
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE879A9).withValues(alpha: 0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(8, topPad + 2, 12, 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FadeTransition(
                opacity: fadeEarly,
                child: SizedBox(
                  height: kToolbarHeight,
                  width: double.infinity,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Full-width center — back button does not shift the title.
                      Center(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: _studioTitleWidth(),
                          ),
                          child: Container(
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppTheme.neonEdge.withValues(alpha: 0.45),
                              ),
                              color: AppTheme.neonEdge.withValues(alpha: 0.12),
                            ),
                            child: Text(
                              'STÜDYO',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 2.8,
                                color: AppTheme.neonEdge.withValues(alpha: 0.95),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: Icon(
                            Icons.arrow_back_ios_new,
                            size: 20,
                            color: Colors.white.withValues(alpha: 0.9),
                          ),
                          tooltip: 'Geri',
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              FadeTransition(
                opacity: fadeType,
                child: const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Eski beyaz «Stüdyo» başlığının genişliği — pill aynı min genişlikte.
  static double _studioTitleWidth() {
    final tp = TextPainter(
      text: const TextSpan(
        text: 'Stüdyo',
        style: TextStyle(
          fontFamily: 'serif',
          fontSize: 44,
          fontWeight: FontWeight.w700,
          height: 1.0,
          letterSpacing: -1.4,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    return tp.width;
  }
}
