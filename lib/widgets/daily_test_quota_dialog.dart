import 'package:flutter/material.dart';

import '../services/content_bank_service.dart';
import '../theme/app_theme.dart';
import 'scale_button.dart';

enum DailyQuotaAction { cancel, ad, premium }

/// Ücretsiz günlük test kotası dolduğunda gösterilen premium diyalog.
Future<DailyQuotaAction?> showDailyTestQuotaDialog({
  required BuildContext context,
  required String subjectName,
  required bool canWatchAd,
}) {
  return showDialog<DailyQuotaAction>(
    context: context,
    barrierColor: const Color(0xCC070B14),
    builder: (context) => DailyTestQuotaDialog(
      subjectName: subjectName,
      canWatchAd: canWatchAd,
    ),
  );
}

class DailyTestQuotaDialog extends StatelessWidget {
  final String subjectName;
  final bool canWatchAd;

  const DailyTestQuotaDialog({
    super.key,
    required this.subjectName,
    required this.canWatchAd,
  });

  static const int _freePerDay = ContentBankService.dailyFreeTestsPerSubject;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 400,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
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
                      tooltip: 'Vazgeç',
                      onPressed: () => Navigator.pop(
                        context,
                        DailyQuotaAction.cancel,
                      ),
                      icon: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
                    child: SingleChildScrollView(
                      child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _LimitSeal(),
                        const SizedBox(height: 16),
                        Text(
                          'ÜCRETSİZ PLAN',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.8,
                            color: AppTheme.champagneLight.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Günlük test limiti',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.6,
                            height: 1.15,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          canWatchAd
                              ? '$subjectName dersinde bugünkü test hakkınız doldu.'
                              : '$subjectName dersinde bugünkü test ve reklam bonusu hakkınız doldu.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.45,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Aynı Google hesabında telefon ve tablet günlük hakkı paylaşır. '
                          'Farklı Google hesaplarının hakları ayrıdır.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.55),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _QuotaStrip(
                          usedLabel: '$_freePerDay / $_freePerDay kullanıldı',
                          hint: canWatchAd
                              ? 'Her derste günde $_freePerDay test · reklamla o derse +1 hak'
                              : 'Ek hak için Premium gerekir',
                        ),
                        const SizedBox(height: 20),
                        if (canWatchAd) ...[
                          _DialogAction(
                            onPressed: () => Navigator.pop(
                              context,
                              DailyQuotaAction.ad,
                            ),
                            child: const _AdCta(),
                          ),
                          const SizedBox(height: 10),
                        ],
                        _DialogAction(
                          onPressed: () => Navigator.pop(
                            context,
                            DailyQuotaAction.premium,
                          ),
                          child: const _PremiumCta(),
                        ),
                        const SizedBox(height: 6),
                        TextButton(
                          onPressed: () => Navigator.pop(
                            context,
                            DailyQuotaAction.cancel,
                          ),
                          child: Text(
                            'Vazgeç',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withValues(alpha: 0.45),
                            ),
                          ),
                        ),
                      ],
                    ),
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

class _LimitSeal extends StatelessWidget {
  const _LimitSeal();

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
          Icons.hourglass_bottom_rounded,
          size: 26,
          color: AppTheme.champagneLight,
        ),
      ),
    );
  }
}

class _QuotaStrip extends StatelessWidget {
  final String usedLabel;
  final String hint;

  const _QuotaStrip({
    required this.usedLabel,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.white.withValues(alpha: 0.04),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.lock_clock_outlined,
                size: 16,
                color: AppTheme.champagneLight.withValues(alpha: 0.9),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  usedLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: const LinearProgressIndicator(
              value: 1,
              minHeight: 4,
              backgroundColor: Color(0x22FFFFFF),
              color: AppTheme.champagne,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hint,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _DialogAction extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;

  const _DialogAction({
    required this.onPressed,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: onPressed,
      child: child,
    );
  }
}

class _AdCta extends StatelessWidget {
  const _AdCta();

  @override
  Widget build(BuildContext context) {
    return Container(
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
                  '+1 test hakkı  ·  yaklaşık 30 sn',
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

class _PremiumCta extends StatelessWidget {
  const _PremiumCta();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFFFF6E8),
            Color(0xFFE2C998),
            AppTheme.champagne,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.32),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: const Row(
        children: [
          _CrownMark(),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium\'a geç',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                    color: AppTheme.ink,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Sınırsız test  ·  reklamsız',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: AppTheme.slate,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.arrow_forward_rounded,
            size: 18,
            color: AppTheme.ink,
          ),
        ],
      ),
    );
  }
}

class _CrownMark extends StatelessWidget {
  const _CrownMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      alignment: Alignment.center,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.ink,
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        size: 18,
        color: AppTheme.champagneLight,
      ),
    );
  }
}
