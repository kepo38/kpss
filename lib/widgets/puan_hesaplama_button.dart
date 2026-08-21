import 'package:flutter/material.dart';

import '../screens/puan_hesaplama_screen.dart';
import '../theme/app_theme.dart';
import 'scale_button.dart';

/// Deneme sekmesinde KPSS puan tahmini CTA.
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
    final radius = compact ? 12.0 : 16.0;
    final pad = compact
        ? const EdgeInsets.fromLTRB(10, 8, 10, 8)
        : const EdgeInsets.fromLTRB(14, 14, 14, 14);
    final titleSize = compact ? 13.0 : 15.0;
    final subtitleSize = compact ? 10.0 : 11.5;
    final iconBox = compact ? 28.0 : 38.0;
    final iconSize = compact ? 16.0 : 20.0;
    final arrowSize = compact ? 14.0 : 16.0;

    return ScaleButton(
      onPressed: () => _open(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _open(context),
          borderRadius: BorderRadius.circular(radius),
          child: Ink(
            padding: pad,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(radius),
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
                  blurRadius: compact ? 8 : 14,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                _IconBadge(size: iconBox, iconSize: iconSize),
                SizedBox(width: compact ? 8 : 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'PUAN HESAPLAMA',
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: titleSize,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                          color: AppTheme.ink,
                        ),
                      ),
                      SizedBox(height: compact ? 1 : 2),
                      Text(
                        'Netlerine göre tahmini',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: subtitleSize,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xCC1F2937),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: arrowSize,
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
  final double size;
  final double iconSize;

  const _IconBadge({required this.size, required this.iconSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.ink.withValues(alpha: 0.1),
      ),
      child: Icon(
        Icons.calculate_rounded,
        color: AppTheme.ink,
        size: iconSize,
      ),
    );
  }
}
