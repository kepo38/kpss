import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Normal testte defterdeki soru açılınca 5 sn’lik bilgi.
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
        duration: const Duration(milliseconds: 280),
        child: Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: const Color(0xFF1C2A42).withValues(alpha: 0.94),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.7),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.28),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 18,
                      color: AppTheme.champagneLight,
                    ),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'BU SORU YANLIŞ DEFTERİMDE KAYITLI',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.45,
                          color: Colors.white,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
