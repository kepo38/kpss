import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../screens/daily_mini_rewards_screen.dart';
import '../../theme/app_theme.dart';

/// Yuvarlak premium ÖDÜL CTA — nabız + champagne parıltı.
class DailyMiniOdulButton extends StatefulWidget {
  final VoidCallback onPressed;
  final double size;

  const DailyMiniOdulButton({
    super.key,
    required this.onPressed,
    this.size = 48,
  });

  @override
  State<DailyMiniOdulButton> createState() => _DailyMiniOdulButtonState();
}

/// Kürsü panelinin üst kenarından sarkan ÖDÜL madalyonu.
class DailyMiniOdulHangBadge extends StatefulWidget {
  final VoidCallback onPressed;

  const DailyMiniOdulHangBadge({super.key, required this.onPressed});

  @override
  State<DailyMiniOdulHangBadge> createState() => _DailyMiniOdulHangBadgeState();
}

class _DailyMiniOdulHangBadgeState extends State<DailyMiniOdulHangBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Ödül kuralları',
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          final sway = math.sin(_ctrl.value * math.pi) * 0.06;
          return Transform.rotate(
            angle: sway,
            alignment: Alignment.topCenter,
            child: child,
          );
        },
        child: SizedBox(
          width: 52,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // İğne / ip — tıklama geçirsin (CTA sol/orta alanı kapanmasın).
              IgnorePointer(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE8C878),
                        border: Border.all(
                          color: const Color(0xFF8F6E32),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.champagne.withValues(alpha: 0.55),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 2.2,
                      height: 14,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Color(0xFFF5E6BC),
                            AppTheme.champagne,
                            Color(0xFF8F6E32),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Yalnızca madalya hit-test — ÖDÜL ekranı.
              GestureDetector(
                onTap: widget.onPressed,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF8EE),
                        Color(0xFFF3E2B8),
                        Color(0xFFE8C878),
                        AppTheme.champagne,
                      ],
                    ),
                    border: Border.all(
                      color: const Color(0xFFD4AF6A),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.champagne.withValues(alpha: 0.45),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.emoji_events_rounded,
                        size: 15,
                        color: AppTheme.ink,
                      ),
                      Text(
                        'ÖDÜL',
                        style: TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                          height: 1,
                          color: AppTheme.ink,
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
    );
  }
}

class _DailyMiniOdulButtonState extends State<DailyMiniOdulButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    return Tooltip(
      message: 'Ödül kuralları',
      child: GestureDetector(
        onTap: widget.onPressed,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (context, child) {
            final t = _ctrl.value;
            final pulse = 1.0 + 0.06 * math.sin(t * math.pi * 2);
            final glow = 0.35 + 0.25 * (0.5 + 0.5 * math.sin(t * math.pi * 2));
            return Transform.scale(
              scale: pulse,
              child: Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFFFF8EE),
                      Color(0xFFF3E2B8),
                      Color(0xFFE8C878),
                      AppTheme.champagne,
                    ],
                  ),
                  border: Border.all(
                    color: const Color(0xFFD4AF6A),
                    width: 1.4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.champagne.withValues(alpha: glow),
                      blurRadius: 14,
                      spreadRadius: 1,
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: child,
              ),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.emoji_events_rounded,
                size: size * 0.34,
                color: AppTheme.ink,
              ),
              Text(
                'ÖDÜL',
                style: TextStyle(
                  fontSize: size * 0.168,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  height: 1,
                  color: AppTheme.ink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Ödül şartları — kapatılabilir şık kart.
Future<void> showDailyMiniOdulInfoCard(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Kapat',
    barrierColor: Colors.black.withValues(alpha: 0.72),
    transitionDuration: const Duration(milliseconds: 280),
    pageBuilder: (ctx, anim, secondary) {
      return SafeArea(
        child: Center(
          child: FadeTransition(
            opacity: CurvedAnimation(parent: anim, curve: Curves.easeOut),
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.92, end: 1).animate(
                CurvedAnimation(parent: anim, curve: Curves.easeOutBack),
              ),
              child: const _OdulInfoCard(),
            ),
          ),
        ),
      );
    },
  );
}

class _OdulInfoCard extends StatelessWidget {
  const _OdulInfoCard();

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        width: math.min(340, MediaQuery.sizeOf(context).width - 40),
        margin: const EdgeInsets.symmetric(horizontal: 20),
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2A2438),
              Color(0xFF151A28),
              Color(0xFF0C1424),
            ],
          ),
          border: Border.all(
            color: AppTheme.champagne.withValues(alpha: 0.55),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.champagne.withValues(alpha: 0.22),
              blurRadius: 28,
              spreadRadius: -2,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [Color(0xFFF5E6BC), AppTheme.champagne],
                    ),
                  ),
                  child: const Icon(
                    Icons.workspace_premium_rounded,
                    size: 20,
                    color: AppTheme.ink,
                  ),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Premium ödül',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.champagneLight,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Kapat',
                  icon: Icon(
                    Icons.close_rounded,
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Günün mini denemesinde haftalık ve aylık toplam doğruya göre '
              'ilk 3’e Premium verilir. Eşitlikte daha kısa süre önde.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 16),
            const _RewardRow(place: '1.', days: '3 gün Premium'),
            const SizedBox(height: 8),
            const _RewardRow(place: '2.', days: '2 gün Premium'),
            const SizedBox(height: 8),
            const _RewardRow(place: '3.', days: '1 gün Premium'),
            const SizedBox(height: 14),
            Text(
              'Haftalık ve aylık dönemlerde aynı ödüller geçerlidir. '
              'Sıralama ve geçmiş kazananlar herkese açıktır.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.35,
                fontStyle: FontStyle.italic,
                color: Colors.white.withValues(alpha: 0.5),
              ),
            ),
            const SizedBox(height: 16),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const DailyMiniRewardsScreen(),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(14),
                child: Ink(
                  height: 50,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFFFF8EE),
                        Color(0xFFF3E2B8),
                        Color(0xFFE8C878),
                        AppTheme.champagne,
                      ],
                      stops: [0.0, 0.35, 0.72, 1.0],
                    ),
                    border: Border.all(
                      color: const Color(0xFFD4AF6A).withValues(alpha: 0.75),
                      width: 1.15,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.champagne.withValues(alpha: 0.42),
                        blurRadius: 16,
                        offset: const Offset(0, 5),
                      ),
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.28),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.leaderboard_rounded,
                          size: 18,
                          color: AppTheme.ink,
                        ),
                        SizedBox(width: 10),
                        Text(
                          'Sıralamayı gör',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.2,
                            height: 1.1,
                            color: AppTheme.ink,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Kapat',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.65),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardRow extends StatelessWidget {
  final String place;
  final String days;

  const _RewardRow({required this.place, required this.days});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.28),
        ),
      ),
      child: Row(
        children: [
          Text(
            place,
            style: const TextStyle(
              fontFamily: 'serif',
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.champagneLight,
            ),
          ),
          const SizedBox(width: 12),
          Text(
            days,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
