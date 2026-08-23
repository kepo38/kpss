import 'package:flutter/material.dart';

import '../screens/puan_hesaplama_screen.dart';
import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Deneme sekmesinde KPSS puan tahmini CTA — ink + champagne premium şerit.
class PuanHesaplamaButton extends StatelessWidget {
  final bool compact;

  const PuanHesaplamaButton({super.key, this.compact = false});

  void _open(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => const PuanHesaplamaScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: () => _open(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(18),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF1A2438),
                  Color(0xFF141C2E),
                  Color(0xFF0C1424),
                ],
                stops: [0, 0.55, 1],
              ),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.18),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: AppTheme.ink.withValues(alpha: 0.16),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -24,
                  top: -28,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          AppTheme.champagne.withValues(alpha: 0.2),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    height: 2,
                    decoration: const BoxDecoration(
                      borderRadius: BorderRadius.vertical(
                        bottom: Radius.circular(18),
                      ),
                      gradient: LinearGradient(
                        colors: [
                          Color(0xFF6B0F1A),
                          AppTheme.champagne,
                          Color(0xFFFFE7B8),
                        ],
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    compact ? 12 : 16,
                    compact ? 11 : 14,
                    compact ? 12 : 14,
                    compact ? 13 : 16,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: compact ? 36 : 44,
                        height: compact ? 36 : 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.champagne.withValues(alpha: 0.28),
                              AppTheme.champagne.withValues(alpha: 0.08),
                            ],
                          ),
                          border: Border.all(
                            color: AppTheme.champagneLight.withValues(
                              alpha: 0.5,
                            ),
                          ),
                        ),
                        child: Icon(
                          Icons.calculate_rounded,
                          color: AppTheme.champagneLight,
                          size: compact ? 18 : 22,
                        ),
                      ),
                      SizedBox(width: compact ? 10 : 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              'PUAN HESAPLAMA',
                              style: TextStyle(
                                fontFamily: 'serif',
                                fontSize: compact ? 14 : 16,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.4,
                                color: Colors.white,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: compact ? 2 : 4),
                            Text(
                              'Netlerine göre tahmini KPSS puanı',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: compact ? 11 : 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white.withValues(alpha: 0.62),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 30,
                        height: 30,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.08),
                          border: Border.all(
                            color: AppTheme.champagne.withValues(alpha: 0.35),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_rounded,
                          size: 16,
                          color: AppTheme.champagneLight,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
