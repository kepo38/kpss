import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Test bazlı yanlış inceleme — üst bilgi şeridi.
class WrongNotebookSessionBanner extends StatelessWidget {
  final String title;

  const WrongNotebookSessionBanner({
    super.key,
    required this.title,
  });

  static const _red = Color(0xFFF87171);
  static const _redDeep = Color(0xFFDC2626);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _red.withValues(alpha: 0.12),
              AppTheme.champagne.withValues(alpha: 0.08),
            ],
          ),
          border: Border.all(color: _red.withValues(alpha: 0.45), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: AppTheme.champagne.withValues(alpha: 0.08),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _redDeep.withValues(alpha: 0.12),
                  border: Border.all(color: _red.withValues(alpha: 0.35)),
                ),
                child: Icon(
                  Icons.filter_alt_rounded,
                  size: 18,
                  color: _redDeep.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppTheme.onPage(context),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Bu testteki yanlış sorular aşağıda listelenir.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: AppTheme.mutedOnPage(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
