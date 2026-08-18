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
        SnackBar(
          content: Text(
            'E-posta uygulaması açılamadı. '
            '${SupportContactService.supportEmail} adresine yazabilirsiniz.',
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
            Text(
              'Nasıl yardımcı olabiliriz?',
              style: TextStyle(
                fontFamily: 'serif',
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.95),
              ),
            ),
            const SizedBox(height: 14),
            const _InfoBlock(
              icon: Icons.school_outlined,
              title: 'Deneme paketleri',
              body:
                  'Özel okul ve kurs deneme paketleri talepleri için '
                  'ekibimizle iletişime geçebilirsiniz.',
            ),
            const SizedBox(height: 12),
            const _InfoBlock(
              icon: Icons.report_rounded,
              title: 'Soru hata bildirimi',
              body:
                  'Sorulardaki hatalar için soru ekranında sağ üstten '
                  'hata bildirimi yapabilirsiniz.',
              warning: true,
            ),
            const SizedBox(height: 32),
            _ContactButton(onTap: () => _contact(context)),
            const SizedBox(height: 16),
            Center(
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: _gold.withValues(alpha: 0.4),
                  ),
                ),
                child: Text(
                  SupportContactService.supportEmail,
                  style: TextStyle(
                    fontSize: 13,
                    letterSpacing: 0.15,
                    color: _gold.withValues(alpha: 0.95),
                  ),
                ),
              ),
            ),
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
  static const _warn = Color(0xFFFF8A4C);

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
    final neon = warning ? _warn : SupportContactScreen._gold;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: warning
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF3A2218).withValues(alpha: 0.98),
                  AppTheme.smokeDeep.withValues(alpha: 0.96),
                ],
              ),
              border: Border.all(color: _warn.withValues(alpha: 0.72), width: 1.35),
              boxShadow: SubjectNeonPalette.glow(_warn, blur: 18),
            )
          : SubjectNeonPalette.darkGlassCard(neon: neon, radius: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: neon.withValues(alpha: warning ? 0.22 : 0.14),
              border: Border.all(
                color: neon.withValues(alpha: warning ? 0.55 : 0.32),
              ),
            ),
            child: Icon(icon, color: neon, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'serif',
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: warning ? _warn : Colors.white,
                        ),
                      ),
                    ),
                    if (warning)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: _warn.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: _warn.withValues(alpha: 0.55),
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
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.55,
                    color: Colors.white.withValues(alpha: 0.86),
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
