import 'package:flutter/material.dart';

import '../services/support_contact_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/app_back_button.dart';

/// Destek ve iletişim — deneme paketi talepleri, hata bildirimi yönlendirmesi.
class SupportContactScreen extends StatelessWidget {
  const SupportContactScreen({super.key});

  static const _neon = AppTheme.neonEdge;
  static const _gold = AppTheme.champagne;

  Future<void> _contact(BuildContext context) async {
    final opened = await SupportContactService.openSupportEmail();
    if (!context.mounted) return;
    if (!opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'E-posta uygulaması açılamadı. Lütfen cihazınızın '
            'posta ayarlarını kontrol edin.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.ink,
      appBar: AppBar(
        backgroundColor: AppTheme.ink,
        foregroundColor: Colors.white,
        elevation: 0,
        leading: const AppBackButton(),
        title: const Text(
          'Destek ve İletişim',
          style: TextStyle(
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.ink,
              AppTheme.inkSoft.withValues(alpha: 0.35),
              AppTheme.ink,
            ],
          ),
        ),
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            28 + MediaQuery.paddingOf(context).bottom,
          ),
          children: [
            const _HeroCard(),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: Text(
                'Nasıl yardımcı olabiliriz?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const _InfoBlock(
              icon: Icons.school_outlined,
              title: 'Deneme paketleri',
              body:
                  'Özel okul ve kurs deneme paketleri talepleri için '
                  'ekibimizle iletişime geçebilirsiniz.',
            ),
            const SizedBox(height: 16),
            const _InfoBlock(
              icon: Icons.report_outlined,
              title: 'Soru hata bildirimi',
              body:
                  'Sorulardaki hatalar için soru ekranında sağ üstten '
                  'hata bildirimi yapabilirsiniz.',
              warning: true,
            ),
            const SizedBox(height: 32),
            _ContactButton(onTap: () => _contact(context)),
          ],
        ),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 26, 22, 26),
      decoration: SubjectNeonPalette.darkGlassCard(
        neon: SupportContactScreen._gold,
        radius: 20,
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  SupportContactScreen._gold.withValues(alpha: 0.22),
                  SupportContactScreen._neon.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(
                color: SupportContactScreen._gold.withValues(alpha: 0.45),
              ),
            ),
            child: const Icon(
              Icons.support_agent_rounded,
              color: SupportContactScreen._gold,
              size: 32,
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Hedef Kamu Destek',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'serif',
              fontSize: 22,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Kurumsal talepler ve teknik destek için doğrudan ekibimize ulaşın.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              height: 1.55,
              color: Colors.white.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoBlock extends StatelessWidget {
  /// Soft amber / bronz — marka champagne ailesi.
  static const _warn = Color(0xFFC9A66B);

  final IconData icon;
  final String title;
  final String body;
  final bool warning;

  const _InfoBlock({
    required this.icon,
    required this.title,
    required this.body,
    this.warning = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent = warning ? _warn : SupportContactScreen._gold;
    // Bilgi satırı — büyük çerçeveli buton gibi durmasın.
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 52,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(99),
              color: accent.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(width: 14),
          Icon(
            icon,
            size: 22,
            color: accent.withValues(alpha: 0.9),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'serif',
                          fontSize: 16.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    if (warning) ...[
                      const SizedBox(width: 10),
                      Container(
                        margin: const EdgeInsets.only(right: 2),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: _warn.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _warn.withValues(alpha: 0.4),
                          ),
                        ),
                        child: const Text(
                          'UYARI',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: _warn,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.5,
                    color: Colors.white.withValues(alpha: 0.68),
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

class _ContactButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ContactButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        splashColor: SupportContactScreen._gold.withValues(alpha: 0.18),
        child: Ink(
          height: 54,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                SupportContactScreen._gold,
                SupportContactScreen._gold.withValues(alpha: 0.88),
              ],
            ),
            boxShadow: SubjectNeonPalette.glow(
              SupportContactScreen._gold,
              blur: 16,
            ),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.mail_outline_rounded, color: AppTheme.ink, size: 22),
              SizedBox(width: 10),
              Text(
                'İletişime Geç',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.ink,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
