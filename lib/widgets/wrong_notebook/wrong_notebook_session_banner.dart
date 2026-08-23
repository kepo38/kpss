import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Test bazlı yanlış inceleme — üst bilgi şeridi.
class WrongNotebookSessionBanner extends StatelessWidget {
  final String title;
  final VoidCallback onViewAll;

  const WrongNotebookSessionBanner({
    super.key,
    required this.title,
    required this.onViewAll,
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
          color: _red.withValues(alpha: 0.08),
          border: Border.all(color: _red.withValues(alpha: 0.55), width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.filter_alt_outlined,
                    size: 20,
                    color: _redDeep.withValues(alpha: 0.9),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                        color: AppTheme.onPage(context),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: onViewAll,
                  style: TextButton.styleFrom(
                    foregroundColor: _redDeep,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text(
                    'Tüm Yanlışlarımı Gör',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
