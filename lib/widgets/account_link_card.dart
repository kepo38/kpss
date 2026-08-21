import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import 'google_g_mark.dart';

/// Misafir kullanıcıya Google hesabı bağlama CTA'sı.
class AccountLinkCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final EdgeInsetsGeometry? margin;

  const AccountLinkCard({
    super.key,
    this.title = 'İlerlemeni kaydet',
    this.subtitle =
        'Google ile giriş yap; başarı panelin, istatistiklerin ve premium hesabına bağlansın.',
    this.margin,
  });

  static Future<bool> prompt(
    BuildContext context, {
    String? title,
    String? subtitle,
  }) async {
    final auth = AuthService.instance;
    if (auth.hasPermanentAccount) return true;

    final link = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: AppTheme.inkSoft,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            24 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title ?? 'Google ile giriş yap',
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                subtitle ?? 'Bu işlem için hesabını bağlaman gerekiyor.',
                style: TextStyle(
                  fontSize: 14,
                  height: 1.45,
                  color: Colors.white.withValues(alpha: 0.62),
                ),
              ),
              const SizedBox(height: 20),
              const _LinkButton(compact: false),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: Text(
                  'Şimdilik geç',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    return link == true || auth.hasPermanentAccount;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        if (AuthService.instance.hasPermanentAccount) {
          return const SizedBox.shrink();
        }
        return Container(
          margin: margin,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.16),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: AppTheme.ink.withValues(alpha: 0.12),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            // Solid base — transparent Material + Ink let underlying scroll
            // layers (AppBar "Profil", stacked labels) show through as ghosts.
            color: const Color(0xFF101828),
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(16),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppTheme.champagne.withValues(alpha: 0.44),
                  width: 1.1,
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A2840),
                    AppTheme.inkSoft,
                    Color(0xFF101828),
                  ],
                  stops: [0, 0.5, 1],
                ),
              ),
              child: Stack(
                children: [
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
                            Color(0xFFF3E2B8),
                            AppTheme.champagneLight,
                            AppTheme.champagne,
                            Color(0xFF8F6E32),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: -24,
                    top: -36,
                    child: IgnorePointer(
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.neonGold.withValues(alpha: 0.2),
                              AppTheme.champagne.withValues(alpha: 0.06),
                              AppTheme.champagne.withValues(alpha: 0),
                            ],
                            stops: const [0, 0.45, 1],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 28,
                    bottom: -40,
                    child: IgnorePointer(
                      child: Container(
                        width: 90,
                        height: 90,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.champagne.withValues(alpha: 0.08),
                              AppTheme.champagne.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 16, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppTheme.champagne
                                      .withValues(alpha: 0.35),
                                ),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    AppTheme.champagne.withValues(alpha: 0.22),
                                    AppTheme.champagne.withValues(alpha: 0.06),
                                  ],
                                ),
                              ),
                              child: Icon(
                                Icons.cloud_sync_outlined,
                                size: 18,
                                color: AppTheme.champagneLight
                                    .withValues(alpha: 0.95),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 20,
                                      height: 1.1,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withValues(alpha: 0.58),
                          ),
                        ),
                        const SizedBox(height: 14),
                        const _LinkButton(compact: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _LinkButton extends StatefulWidget {
  final bool compact;

  const _LinkButton({required this.compact});

  @override
  State<_LinkButton> createState() => _LinkButtonState();
}

class _LinkButtonState extends State<_LinkButton> {
  Future<void> _link() async {
    final auth = AuthService.instance;
    final ok = await auth.signInWithGoogle();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).maybePop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Hesabın bağlandı.')),
      );
      return;
    }
    if (auth.lastError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.lastError!)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = AuthService.instance.busy;
    return SizedBox(
      height: widget.compact ? 44 : 50,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              AppTheme.champagne.withValues(alpha: 0.95),
              AppTheme.champagneLight,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.champagne.withValues(alpha: 0.28),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: busy ? null : _link,
            borderRadius: BorderRadius.circular(12),
            child: Center(
              child: busy
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.ink.withValues(alpha: 0.85),
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const GoogleGMark(size: 20),
                        const SizedBox(width: 10),
                        Text(
                          'Google ile giriş yap',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: widget.compact ? 14 : 15,
                            letterSpacing: 0.15,
                            color: AppTheme.ink.withValues(alpha: 0.92),
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
