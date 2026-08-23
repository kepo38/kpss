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

/// Bölüm üst etiketi (champagne küçük harf).
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.8,
            fontWeight: FontWeight.w700,
            color: AppTheme.champagne.withValues(alpha: 0.95),
          ),
        ),
        if (subtitle != null && subtitle!.isNotEmpty) ...[
          const SizedBox(height: 4),
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
