import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_theme.dart';
import '../widgets/brand_mark.dart';
import '../widgets/instagram_link_button.dart';
import '../widgets/premium_header_button.dart';
import '../widgets/scale_button.dart';

/// Sabit üst bar — Hedef Kamu + sekme bilincinde CTA (Pro / Pomodoro).
///
/// Gelişim sekmesinde (index 2) sağ üstte Pomodoro açılır; diğer sekmelerde
/// Pro Üyelik / Premium rozeti gösterilir.
class AppShellTopBar extends StatelessWidget {
  /// [MainShell] alt nav: 0 Ana Sayfa, 1 Dersler, 2 Gelişim, 3 Deneme.
  static const int gelisimTabIndex = 2;

  final double topPad;
  final ValueNotifier<bool> isPremium;
  final VoidCallback? onPremiumTap;
  final VoidCallback? onMoreTap;
  final int selectedTabIndex;
  final VoidCallback? onPomodoroTap;

  const AppShellTopBar({
    super.key,
    required this.topPad,
    required this.isPremium,
    this.onPremiumTap,
    this.onMoreTap,
    this.selectedTabIndex = 0,
    this.onPomodoroTap,
  });

  bool get _showPomodoroCta => selectedTabIndex == gelisimTabIndex;

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
          ],
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, topPad + 6, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    GestureDetector(
                      onTap: onMoreTap,
                      behavior: HitTestBehavior.opaque,
                      child: const Tooltip(
                        message: 'Stüdyo',
                        child: BrandMark.topBar(),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Tooltip(
                      message: '@hedefkamu.app',
                      child: InstagramLinkButton(size: 32),
                    ),
                  ],
                ),
              ),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: isPremium,
              builder: (context, premium, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (_showPomodoroCta)
                      _PomodoroHeaderButton(onTap: onPomodoroTap)
                    else
                      PremiumHeaderButton(
                        isPremium: premium,
                        onTap: premium ? null : onPremiumTap,
                      ),
                    const SizedBox(width: 8),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: onMoreTap,
                        borderRadius: BorderRadius.circular(999),
                        child: Tooltip(
                          message: 'Stüdyo · Araçlar & Premium',
                          child: Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: AppTheme.isDark(context)
                                    ? const [
                                        Color(0xFF2A3548),
                                        Color(0xFF1A2436),
                                      ]
                                    : const [
                                        Color(0xFFFFF8EE),
                                        Color(0xFFF0E0BC),
                                      ],
                              ),
                              border: Border.all(
                                color: AppTheme.champagne.withValues(alpha: 0.65),
                                width: 1.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.champagne.withValues(alpha: 0.28),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              Icons.auto_awesome_rounded,
                              size: 18,
                              color: AppTheme.isDark(context)
                                  ? AppTheme.champagneLight
                                  : const Color(0xFF8F6E32),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// Gelişim sağ üst — ink + champagne «ODAK» pill (Focus Mode marka dili).
class _PomodoroHeaderButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _PomodoroHeaderButton({this.onTap});

  @override
  State<_PomodoroHeaderButton> createState() => _PomodoroHeaderButtonState();
}

class _PomodoroHeaderButtonState extends State<_PomodoroHeaderButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleButton(
      onPressed: widget.onTap,
      child: Tooltip(
        message: 'Odak Modu · Pomodoro',
        child: AnimatedBuilder(
          animation: _pulse,
          builder: (context, child) {
            final glow = 0.22 + (_pulse.value * 0.28);
            return Container(
              height: 36,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF1A2740),
                    AppTheme.ink,
                    Color(0xFF070C14),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
                border: Border.all(
                  color: Color.lerp(
                    const Color(0xFFC9A44E),
                    AppTheme.champagneLight,
                    _pulse.value,
                  )!,
                  width: 1.35,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.champagne.withValues(alpha: glow),
                    blurRadius: 12 + (_pulse.value * 6),
                    spreadRadius: -1,
                    offset: const Offset(0, 3),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: child,
            );
          },
          child: Stack(
            children: [
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: 14,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.white.withValues(alpha: 0.14),
                        Colors.white.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -6,
                bottom: -8,
                child: Icon(
                  Icons.timer_outlined,
                  size: 28,
                  color: AppTheme.champagne.withValues(alpha: 0.08),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 0, 12, 0),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const _TimerJewel(),
                    const SizedBox(width: 7),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ODAK',
                          style: GoogleFonts.cormorantGaramond(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.6,
                            height: 1,
                            color: AppTheme.champagneLight,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Pomodoro',
                          style: GoogleFonts.manrope(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            height: 1,
                            color: AppTheme.champagne.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimerJewel extends StatelessWidget {
  const _TimerJewel();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFFF3E2B8),
            AppTheme.champagne,
            Color(0xFFA67C3D),
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.35),
          width: 0.9,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.45),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(
        Icons.timer_rounded,
        size: 13,
        color: AppTheme.ink,
      ),
    );
  }
}
