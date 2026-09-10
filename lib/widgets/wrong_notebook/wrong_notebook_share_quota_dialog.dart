import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ad_constants.dart';
import '../../theme/app_theme.dart';
import '../scale_button.dart';

/// Yanlış defteri paylaşımı — ücretsiz kullanıcı reklam onayı.
Future<bool?> showWrongNotebookShareQuotaDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: const Color(0xCC070B14),
    builder: (context) => const WrongNotebookShareQuotaDialog(),
  );
}

class WrongNotebookShareQuotaDialog extends StatelessWidget {
  const WrongNotebookShareQuotaDialog({super.key});

  static const _dailyLimit = AdConstants.wrongNotebookSharesPerDayFree;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.sizeOf(context).height * 0.82,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFE8D5A8),
                AppTheme.champagne,
                Color(0xFF8A6A32),
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.22),
                blurRadius: 36,
                offset: const Offset(0, 18),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.45),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(1.15),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20.8),
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF1B2A42),
                    Color(0xFF121C2E),
                    Color(0xFF0C1424),
                  ],
                ),
              ),
              child: Stack(
                children: [
                  const Positioned(
                    right: -36,
                    top: -48,
                    child: IgnorePointer(
                      child: SizedBox(
                        width: 160,
                        height: 160,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(
                              colors: [
                                Color(0x55C9A86C),
                                Color(0x00C9A86C),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: 6,
                    right: 6,
                    child: IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.pop(context, false),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _ShareSeal(),
                        const SizedBox(height: 16),
                        Text(
                          'PAYLAŞIM HAKKI',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                            color: AppTheme.champagneLight.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 14),
                        ShaderMask(
                          blendMode: BlendMode.srcIn,
                          shaderCallback: (bounds) => const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFF7EED8),
                              AppTheme.champagneLight,
                              AppTheme.neonGold,
                              AppTheme.champagne,
                            ],
                            stops: [0.0, 0.28, 0.55, 1.0],
                          ).createShader(bounds),
                          child: Text(
                            'GÜNDE $_dailyLimit SORU\nPAYLAŞABİLİRSİNİZ',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.manrope(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              height: 1.18,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ScaleButton(
                          onPressed: () => Navigator.pop(context, true),
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              color: AppTheme.neonEdge.withValues(alpha: 0.07),
                              border: Border.all(
                                color: AppTheme.neonEdge.withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Row(
                              children: [
                                _AdPlayMark(),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Reklam izle',
                                        style: TextStyle(
                                          fontSize: 14.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppTheme.neonEdge,
                                        ),
                                      ),
                                      SizedBox(height: 2),
                                      Text(
                                        'Paylaşımı aç  ·  yaklaşık 30 sn',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: Color(0xB35EEAD4),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
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
      ),
    );
  }
}

class _ShareSeal extends StatelessWidget {
  const _ShareSeal();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 58,
        height: 58,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A3A54),
              Color(0xFF152033),
            ],
          ),
          border: Border.all(
            color: AppTheme.champagne.withValues(alpha: 0.7),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.champagne.withValues(alpha: 0.28),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: const Icon(
          Icons.share_rounded,
          size: 24,
          color: AppTheme.champagneLight,
        ),
      ),
    );
  }
}

class _AdPlayMark extends StatelessWidget {
  const _AdPlayMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.neonEdge.withValues(alpha: 0.14),
        border: Border.all(
          color: AppTheme.neonEdge.withValues(alpha: 0.45),
        ),
      ),
      child: const Icon(
        Icons.play_arrow_rounded,
        size: 22,
        color: AppTheme.neonEdge,
      ),
    );
  }
}
