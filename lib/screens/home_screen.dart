import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../constants/brand_constants.dart';
import '../models/user_model.dart';
import '../widgets/countdown_widget.dart';
import '../services/ad_manager.dart';
import '../services/database_service.dart';
import '../services/kpss_preference_service.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/home_hero_section.dart';
import '../widgets/home_module_row.dart';
import '../widgets/home_premium_module_list.dart';
import '../widgets/home_section_header.dart';
import '../widgets/home_tools_module_list.dart';
import '../widgets/premium_gate.dart';
import 'premium/premium_paywall_screen.dart';
import 'profile_screen.dart';

/// Stüdyo — üst bardaki kare ikondan açılan araçlar & Premium hub.
class HomeScreen extends StatefulWidget {
  final UserModel user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fadeEarly;
  late final Animation<double> _fadeMid;
  late final Animation<double> _fadeLate;
  late final Animation<double> _fadeType;

  final ValueNotifier<KpssType> _selectedType =
      ValueNotifier(KpssType.lisans);
  final ValueNotifier<bool> _isPremium =
      ValueNotifier(PremiumService.instance.isPremium);

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: 1.0, // Stüdyo içeriği hemen görünsün (boş ekran riski yok)
    );
    _fadeEarly = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOutCubic),
    );
    _fadeMid = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.18, 0.7, curve: Curves.easeOutCubic),
    );
    _fadeLate = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.35, 1.0, curve: Curves.easeOutCubic),
    );
    _fadeType = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.25, 0.75, curve: Curves.easeOut),
    );

    _selectedType.value = KpssPreferenceService.instance.kpssType;
    KpssPreferenceService.instance.addListener(_onKpssPrefChanged);

    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bindServicesAfterAnimationFrame();
    });
  }

  void _bindServicesAfterAnimationFrame() {
    AdManager.instance.setPremium(_isPremium.value);
    DatabaseService.instance.setCurrentUser(widget.user);
    PlayBillingService.instance.premiumNotifier.addListener(_onPremiumChanged);
  }

  void _onKpssPrefChanged() {
    final next = KpssPreferenceService.instance.kpssType;
    if (_selectedType.value == next) return;
    _selectedType.value = next;
  }

  @override
  void dispose() {
    KpssPreferenceService.instance.removeListener(_onKpssPrefChanged);
    PlayBillingService.instance.premiumNotifier
        .removeListener(_onPremiumChanged);
    _enter.dispose();
    _selectedType.dispose();
    _isPremium.dispose();
    super.dispose();
  }

  void _onPremiumChanged() {
    final next = PremiumService.instance.isPremium;
    if (_isPremium.value == next) return;
    AdManager.instance.setPremium(next);
    _isPremium.value = next;
  }

  Future<void> _navigateTo(Widget screen) async {
    // Navigasyonu reklam yüklemesiyle bloklama — interstitial arka planda.
    unawaited(AdManager.instance.onPageTransition());
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  Future<void> _navigatePremium(Widget Function() screenBuilder) async {
    await PremiumGate.navigate(context, screenBuilder);
    _onPremiumChanged();
  }

  Future<void> _openPaywall() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PremiumPaywallScreen(),
      ),
    );
    _onPremiumChanged();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.ink,
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1C2A44),
              Color(0xFF152038),
              AppTheme.ink,
              Color(0xFF0A101C),
            ],
            stops: [0.0, 0.28, 0.62, 1.0],
          ),
        ),
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: HomeHeroSection(
                topPad: topPad,
                isPremium: _isPremium,
                fadeEarly: _fadeEarly,
                fadeType: _fadeType,
                onPremiumTap: _openPaywall,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
              sliver: SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeMid,
                  child: const HomeSectionHeader(
                    'Çalışma araçları',
                    eyebrow: 'Ücretsiz',
                    accent: Color(0xFF5EEAD4),
                  ),
                ),
              ),
            ),
            ContainedSliverFade(
              fade: _fadeMid,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: ValueListenableBuilder<KpssType>(
                valueListenable: _selectedType,
                builder: (context, type, _) {
                  return HomeToolsModuleList(
                    kpssType: type,
                    onNavigate: _navigateTo,
                    onNavigatePremium: _navigatePremium,
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 4),
              sliver: SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeLate,
                  child: ValueListenableBuilder<bool>(
                    valueListenable: _isPremium,
                    builder: (context, premium, _) {
                      return HomeSectionHeader(
                        'Premium suite',
                        eyebrow: premium ? 'Dahil' : 'Kilidi aç',
                        accent: AppTheme.champagne,
                        trailing: Icon(
                          premium
                              ? Icons.verified_rounded
                              : Icons.lock_outline_rounded,
                          size: 18,
                          color: AppTheme.champagne.withValues(alpha: 0.85),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            ContainedSliverFade(
              fade: _fadeLate,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: ValueListenableBuilder<bool>(
                valueListenable: _isPremium,
                builder: (context, premium, _) {
                  return ValueListenableBuilder<KpssType>(
                    valueListenable: _selectedType,
                    builder: (context, type, _) {
                      return HomePremiumModuleList(
                        kpssType: type,
                        isPremium: premium,
                        onNavigate: _navigateTo,
                        onNavigatePremium: _navigatePremium,
                      );
                    },
                  );
                },
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 48),
              sliver: SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeLate,
                  child: HomeModuleRow(
                    icon: Icons.person_outline_rounded,
                    title: 'Profil',
                    subtitle: 'Hesap · ${BrandConstants.appName}',
                    tint: const Color(0xFF94A3B8),
                    onTap: () => _navigateTo(ProfileScreen(user: widget.user)),
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

/// Fade + padding sarmalayıcı (yerel yardımcı).
class ContainedSliverFade extends StatelessWidget {
  final Animation<double> fade;
  final EdgeInsets padding;
  final Widget child;

  const ContainedSliverFade({
    super.key,
    required this.fade,
    required this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverToBoxAdapter(
        child: FadeTransition(
          opacity: fade,
          child: child,
        ),
      ),
    );
  }
}
