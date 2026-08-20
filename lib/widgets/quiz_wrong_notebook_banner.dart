import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Normal testte defterdeki soru açılınca 1 sn gecikmeyle ortada premium toast.
class QuizWrongNotebookBanner extends StatelessWidget {
  final bool visible;

  const QuizWrongNotebookBanner({
    super.key,
    required this.visible,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: visible ? 1 : 0,
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        child: AnimatedScale(
          scale: visible ? 1 : 0.94,
          duration: const Duration(milliseconds: 520),
          curve: Curves.easeOutCubic,
          child: Align(
            alignment: Alignment.center,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 320),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        const Color(0xFF152238).withValues(alpha: 0.96),
                        AppTheme.ink.withValues(alpha: 0.94),
                      ],
                    ),
                    border: Border.all(
                      color: AppTheme.champagne.withValues(alpha: 0.72),
                      width: 1.15,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.32),
                        blurRadius: 22,
                        offset: const Offset(0, 10),
                      ),
                      BoxShadow(
                        color: AppTheme.champagne.withValues(alpha: 0.12),
                        blurRadius: 18,
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppTheme.champagne.withValues(alpha: 0.16),
                            border: Border.all(
                              color: AppTheme.champagne.withValues(alpha: 0.55),
                              width: 1,
                            ),
                          ),
                          child: const Icon(
                            Icons.menu_book_rounded,
                            size: 18,
                            color: AppTheme.champagneLight,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'YANLIŞ DEFTERİMDE',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.7,
                            color: Colors.white,
                            height: 1.2,
                          ),
                        ),
                        const Text(
                          'KAYITLI',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                            color: AppTheme.champagneLight,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Daha önce yanlış yapmıştın',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.15,
                            color: Colors.white.withValues(alpha: 0.72),
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
