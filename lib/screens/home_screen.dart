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
import '../widgets/ad_free_campaign_card.dart';
import '../widgets/daily_mission_center.dart';
import '../widgets/home_hero_section.dart';
import '../widgets/home_module_row.dart';
import '../widgets/home_premium_module_list.dart';
import '../widgets/home_section_header.dart';
import '../widgets/home_study_shortcuts.dart';
import '../widgets/home_subject_chip_grid.dart';
import '../widgets/home_tools_module_list.dart';
import '../widgets/premium_gate.dart';
import 'premium/premium_paywall_screen.dart';
import 'profile_screen.dart';
import 'smart_review_screen.dart';
import 'study_hub_screen.dart';

/// Premium ana sayfa — marka hero + odaklı modül navigasyonu.
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
      duration: const Duration(milliseconds: 280),
      value: 1.0,
    );
    _fadeEarly = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOut),
    );
    _fadeMid = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.15, 0.55, curve: Curves.easeOut),
    );
    _fadeLate = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.35, 0.8, curve: Curves.easeOut),
    );
    _fadeType = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
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
    await AdManager.instance.onPageTransition();
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
      backgroundColor: AppTheme.page(context),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.pageTop(context),
              AppTheme.pageDeep(context),
              AppTheme.page(context),
            ],
            stops: const [0.0, 0.45, 1.0],
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
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
              sliver: SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeMid,
                  child: ValueListenableBuilder<KpssType>(
                    valueListenable: _selectedType,
                    builder: (context, type, _) {
                      return DailyMissionCenter(
                        kpssType: type,
                        onSubjectTap: (subject) => _navigateTo(
                          SubjectTopicsScreen(
                            kpssType: type,
                            subject: subject,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeLate,
                child: const AdFreeCampaignCard(),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 0),
              sliver: SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeLate,
                  child: ValueListenableBuilder<KpssType>(
                    valueListenable: _selectedType,
                    builder: (context, type, _) {
                      return HomeStudyShortcuts(
                        kpssType: type,
                        onSmartReview: () => _navigateTo(
                          SmartReviewScreen(kpssType: type),
                        ),
                        onStudyHub: () => _navigateTo(
                          StudyHubScreen(kpssType: type),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              sliver: SliverToBoxAdapter(
                child: FadeTransition(
                  opacity: _fadeLate,
                  child: ValueListenableBuilder<KpssType>(
                    valueListenable: _selectedType,
                    builder: (context, type, _) {
                      return HomeSubjectChipGrid(
                        kpssType: type,
                        onSubjectTap: (subject) => _navigateTo(
                          SubjectTopicsScreen(
                            kpssType: type,
                            subject: subject,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SliverPadding(
              padding: EdgeInsets.fromLTRB(22, 24, 22, 4),
              sliver: SliverToBoxAdapter(
                child: HomeSectionHeader('Diğer araçlar'),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              sliver: SliverToBoxAdapter(
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
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
              sliver: SliverToBoxAdapter(
                child: ValueListenableBuilder<bool>(
                  valueListenable: _isPremium,
                  builder: (context, premium, _) {
                    return HomeSectionHeader(
                      'Premium',
                      trailing: premium
                          ? null
                          : const Icon(
                              Icons.lock_outline,
                              size: 16,
                              color: AppTheme.champagne,
                            ),
                    );
                  },
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
              sliver: SliverToBoxAdapter(
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
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 48),
              sliver: SliverToBoxAdapter(
                child: HomeModuleRow(
                  icon: Icons.person_outline,
                  title: 'Profil',
                  subtitle: 'Hesap · ${BrandConstants.appName} v1.0.0',
                  onTap: () => _navigateTo(ProfileScreen(user: widget.user)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
