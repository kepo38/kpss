import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class WrongNotebookHeaderTitle extends StatelessWidget {
  const WrongNotebookHeaderTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);

    return Text(
      'Yanlış Defterim',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: 'serif',
        fontWeight: FontWeight.w700,
        fontSize: 17,
        height: 1.05,
        letterSpacing: -0.25,
        color: on,
      ),
    );
  }
}

class WrongNotebookHeaderTitleBlock extends StatelessWidget {
  const WrongNotebookHeaderTitleBlock({super.key});

  @override
  Widget build(BuildContext context) {
    return const WrongNotebookHeaderTitle();
  }
}

/// Kitaptan foto ile eklenen yanlışlar — pembe vurgu (iki satır, dar).
class WrongNotebookBookMistakesButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  const WrongNotebookBookMistakesButton({
    super.key,
    required this.count,
    required this.onTap,
  });

  static const _pink = Color(0xFFE879A9);
  static const _pinkDeep = Color(0xFFDB4F86);
  static const _pinkLight = Color(0xFFFBCFE8);

  static const _titleStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 11.5,
    fontWeight: FontWeight.w800,
    letterSpacing: 0.45,
    height: 1.05,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    _pinkLight.withValues(alpha: 0.55),
                    _pink.withValues(alpha: 0.22),
                    _pinkDeep.withValues(alpha: 0.14),
                  ],
                ),
                border: Border.all(
                  color: _pink.withValues(alpha: 0.48),
                ),
                boxShadow: [
                  BoxShadow(
                    color: _pinkDeep.withValues(alpha: 0.12),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.72),
                      border: Border.all(
                        color: _pink.withValues(alpha: 0.35),
                      ),
                    ),
                    child: const Icon(
                      Icons.menu_book_rounded,
                      size: 17,
                      color: _pinkDeep,
                    ),
                  ),
                  const SizedBox(width: 10),
                  ShaderMask(
                    shaderCallback: (bounds) => const LinearGradient(
                      colors: [_pinkDeep, _pink, Color(0xFFC73672)],
                    ).createShader(bounds),
                    child: const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('KİTAPTAKİ', style: _titleStyle),
                        Text('YANLIŞLARIM', style: _titleStyle),
                      ],
                    ),
                  ),
                  if (count > 0) ...[
                    const SizedBox(width: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: _pinkDeep,
                        borderRadius: BorderRadius.circular(99),
                        boxShadow: [
                          BoxShadow(
                            color: _pinkDeep.withValues(alpha: 0.28),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        '$count',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: _pinkDeep.withValues(alpha: 0.85),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class WrongNotebookHeaderPill extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool filled;
  final IconData? icon;

  const WrongNotebookHeaderPill({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: filled ? null : AppTheme.champagne.withValues(alpha: 0.1),
          gradient: filled
              ? const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFF8E7C0),
                    Color(0xFFE2C998),
                    Color(0xFFC9A86C),
                  ],
                )
              : null,
          border: Border.all(
            color: filled
                ? const Color(0xFFD4AF6A)
                : AppTheme.champagne.withValues(alpha: 0.42),
          ),
          boxShadow: filled
              ? [
                  BoxShadow(
                    color: AppTheme.champagne.withValues(alpha: 0.22),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: filled ? AppTheme.ink : on),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              maxLines: 1,
              softWrap: false,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.05,
                height: 1.1,
                color: filled ? AppTheme.ink : on,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class WrongNotebookAddQuestionAction extends StatelessWidget {
  final VoidCallback? onTap;
  final bool loading;
  final bool expanded;

  const WrongNotebookAddQuestionAction({
    super.key,
    required this.onTap,
    this.loading = false,
    this.expanded = false,
  });

  static const _labelStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 9.5,
    fontWeight: FontWeight.w800,
    height: 1.0,
    letterSpacing: 1.15,
    color: Colors.white,
  );

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: loading ? null : onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          width: expanded ? double.infinity : null,
          padding: EdgeInsets.fromLTRB(
            expanded ? 14 : 10,
            expanded ? 12 : 5,
            expanded ? 12 : 8,
            expanded ? 12 : 5,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: AppTheme.champagne.withValues(alpha: 0.08),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: 0.38),
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: expanded ? MainAxisSize.max : MainAxisSize.min,
            mainAxisAlignment: expanded
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppTheme.champagneLight,
                    AppTheme.champagne,
                    Color(0xFFB8925A),
                  ],
                ).createShader(bounds),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('SORU', style: _labelStyle),
                    Text('EKLE', style: _labelStyle),
                  ],
                ),
              ),
              SizedBox(width: expanded ? 10 : 7),
              if (loading)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.champagne,
                  ),
                )
              else
                Icon(
                  Icons.add_a_photo_outlined,
                  size: expanded ? 24 : 21,
                  color: AppTheme.champagne,
                ),
            ],
          ),
        ),
      ),
    );

    if (expanded) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
        child: button,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: button,
    );
  }
}
