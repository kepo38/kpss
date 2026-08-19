import 'package:flutter/material.dart';

import '../screens/puan_hesaplama_screen.dart';
import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Gelişim / Deneme sekmelerinde KPSS puan tahmini CTA.
class PuanHesaplamaButton extends StatelessWidget {
  const PuanHesaplamaButton({super.key});

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
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFF6E3),
                  Color(0xFFF1DEB8),
                  Color(0xFFE2C885),
                ],
              ),
              border: Border.all(color: const Color(0xFFD4AF6A), width: 1.1),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.34),
                  blurRadius: 14,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Row(
              children: [
                _IconBadge(),
                SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PUAN HESAPLAMA',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: AppTheme.ink,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Netlerine göre tahmini KPSS puanı',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xCC1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: AppTheme.ink,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.ink.withValues(alpha: 0.1),
      ),
      child: const Icon(
        Icons.calculate_rounded,
        color: AppTheme.ink,
        size: 20,
      ),
    );
  }
}
