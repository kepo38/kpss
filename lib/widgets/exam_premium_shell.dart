import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Deneme sekmesi alt sayfaları — Gelişim hub ile uyumlu zemin.
class ExamPremiumBackground extends StatelessWidget {
  final Widget child;

  const ExamPremiumBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.pageTop(context),
            AppTheme.page(context),
            AppTheme.pageDeep(context),
          ],
        ),
      ),
      child: child,
    );
  }
}

/// Bölüm üst etiketi — Gelişim hub dilinde champagne accent.
class ExamPremiumSectionLabel extends StatelessWidget {
  final String label;
  final String? subtitle;

  const ExamPremiumSectionLabel({
    super.key,
    required this.label,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Container(
          width: 4,
          height: subtitle != null ? 34 : 26,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(99),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFE7B8),
                AppTheme.champagne,
                Color(0xFFB8924A),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  height: 1.15,
                  color: AppTheme.onPage(context),
                ),
              ),
              if (subtitle != null && subtitle!.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subtitle!,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: AppTheme.mutedOnPage(context),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Ink + champagne kenarlı premium kart çerçevesi.
class ExamPremiumCardShell extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final bool accentBar;

  const ExamPremiumCardShell({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.accentBar = true,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: dark ? 0.08 : 0.14),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppTheme.champagne.withValues(alpha: dark ? 0.28 : 0.38),
            ),
            color: dark ? AppTheme.inkSoft : Colors.white,
          ),
          child: Stack(
            children: [
              if (accentBar)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    width: 3,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppTheme.champagneLight,
                          AppTheme.champagne,
                          Color(0xFFB8924A),
                        ],
                      ),
                    ),
                  ),
                ),
              Padding(
                padding: padding,
                child: child,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
