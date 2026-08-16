import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../constants/brand_constants.dart';
import '../data/kpss_curriculum.dart';
import '../models/user_model.dart';
import '../services/ad_manager.dart';
import '../services/content_bank_service.dart';
import '../services/database_service.dart';
import '../services/kpss_preference_service.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../services/smart_review_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/brand_mark.dart';
import '../widgets/ad_free_campaign_card.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/daily_mission_center.dart';
import '../widgets/exam_focus_panel.dart';
import '../widgets/premium_header_button.dart';
import '../widgets/premium_gate.dart';
import '../widgets/scale_button.dart';
import 'analytics_hub_screen.dart';
import 'current_info_screen.dart';
import 'favorites_screen.dart';
import 'premium/badges_screen.dart';
import 'premium/cloud_sync_screen.dart';
import 'premium/focus_mode_screen.dart';
import 'premium/leaderboard_screen.dart';
import 'premium/offline_pack_screen.dart';
import 'premium/premium_paywall_screen.dart';
import 'premium/statistics_screen.dart';
import 'premium/task_management_screen.dart';
import 'premium/topic_tracking_screen.dart';
import 'profile_screen.dart';
import 'smart_review_screen.dart';
import 'study_and_solve_screen.dart';
import 'study_hub_screen.dart';
import 'wrong_questions_screen.dart';

/// Premium ana sayfa — marka hero + odaklı modül navigasyonu (60 FPS).
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
  late final Animation<double> _fadeCountdown;
  late final Animation<Offset> _slideMid;

  /// Tip seçimi — tüm ağacı değil, sadece dinleyenleri yeniler.
  final ValueNotifier<KpssType> _selectedType =
      ValueNotifier(KpssType.lisans);
  final ValueNotifier<bool> _isPremium =
      ValueNotifier(PremiumService.instance.isPremium);

  static final _sectionTitleStyle = TextStyle(
    fontFamily: 'serif',
    fontSize: 26,
    fontWeight: FontWeight.w600,
    color: AppTheme.ink,
    letterSpacing: -0.5,
  );

  Widget _sectionHeader(String title, {Widget? trailing}) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 22,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppTheme.neonEdge, AppTheme.champagne],
            ),
            boxShadow: SubjectNeonPalette.glow(AppTheme.neonEdge, blur: 6),
          ),
        ),
        const SizedBox(width: 10),
        Text(title, style: _sectionTitleStyle),
        if (trailing != null) ...[
          const SizedBox(width: 10),
          trailing,
        ],
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    // Ana sayfa içeriği ilk karede görünür (fade ile gecikme yok).
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
    _slideMid = Tween<Offset>(
      begin: Offset.zero,
      end: Offset.zero,
    ).animate(_enter);
    _fadeType = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
    );
    _fadeCountdown = CurvedAnimation(
      parent: _enter,
      curve: const Interval(0.4, 0.85, curve: Curves.easeOut),
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

  void _onExamTypeChanged(KpssType type) {
    _selectedType.value = type;
    unawaited(KpssPreferenceService.instance.setKpssType(type));
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
    // Gereksiz setState yok — ekran dönüşünde premium değişmediyse rebuild gerekmez.
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
            child: _HeroSection(
              topPad: topPad,
              selectedType: _selectedType,
              isPremium: _isPremium,
              fadeEarly: _fadeEarly,
              fadeMid: _fadeMid,
              fadeType: _fadeType,
              fadeCountdown: _fadeCountdown,
              slideMid: _slideMid,
              onPremiumTap: _openPaywall,
              onKpssTypeChanged: _onExamTypeChanged,
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
                child: Column(
                  children: [
                    ScaleButton(
                      onPressed: () => _navigateTo(
                        SmartReviewScreen(kpssType: _selectedType.value),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: SubjectNeonPalette.lightNeonModule(
                          neon: AppTheme.neonEdge,
                          accent: true,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                color:
                                    AppTheme.neonEdge.withValues(alpha: 0.16),
                                border: Border.all(
                                  color: AppTheme.neonEdge
                                      .withValues(alpha: 0.55),
                                ),
                              ),
                              child: const Icon(
                                Icons.auto_awesome_outlined,
                                color: AppTheme.neonEdge,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Akıllı tekrar',
                                    style: TextStyle(
                                      fontFamily: 'serif',
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  ListenableBuilder(
                                    listenable: Listenable.merge([
                                      SmartReviewService.instance,
                                      ContentBankService.instance,
                                    ]),
                                    builder: (context, _) {
                                      return Text(
                                        SmartReviewService.instance
                                            .subtitleFor(_selectedType.value),
                                        style: const TextStyle(
                                          fontSize: 12.5,
                                          color: Color(0xB8FFFFFF),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 14,
                              color: AppTheme.neonEdge.withValues(alpha: 0.9),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ScaleButton(
                      onPressed: () => _navigateTo(
                        StudyHubScreen(kpssType: _selectedType.value),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 13,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          color: Colors.white.withValues(alpha: 0.88),
                          border: Border.all(
                            color: AppTheme.ink.withValues(alpha: 0.08),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.menu_book_outlined,
                              color: AppTheme.champagne.withValues(alpha: 0.9),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                'Müfredata git · konu testi çöz',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.ink,
                                ),
                              ),
                            ),
                            Icon(
                              Icons.arrow_forward_ios_rounded,
                              size: 13,
                              color: AppTheme.slate.withValues(alpha: 0.45),
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
            sliver: SliverToBoxAdapter(
              child: FadeTransition(
                opacity: _fadeLate,
                child: ValueListenableBuilder<KpssType>(
                  valueListenable: _selectedType,
                  builder: (context, type, _) {
                    final subjects = KpssCurriculum.subjectsFor(type);
                    final bank = ContentBankService.instance;
                    return Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final subject in subjects)
                          _HomeSubjectChip(
                            name: subject.name,
                            icon: subjectIcon(subject.id),
                            neon: SubjectNeonPalette.forSubject(subject.id),
                            subtitle:
                                '${bank.catalogQuestionCountForSubject(type, subject.id)} soru',
                            onTap: () => _navigateTo(
                              SubjectTopicsScreen(
                                kpssType: type,
                                subject: subject,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 24, 22, 4),
            sliver: SliverToBoxAdapter(
              child: _sectionHeader('Diğer araçlar'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 8),
            sliver: SliverList(
              delegate: SliverChildListDelegate.fixed([
                _ModuleRow(
                  index: 0,
                  animation: _enter,
                  icon: Icons.menu_book_outlined,
                  title: 'Mikro Öğrenme',
                  subtitle: 'Kısa anlatım, hızlı pekiştirme',
                  onTap: () => _navigateTo(_mikroOgrenmeScreen),
                ),
                _ModuleRow(
                  index: 1,
                  animation: _enter,
                  icon: Icons.favorite_border,
                  title: 'Favorilerim',
                  subtitle: 'İşaretlediğin sorular',
                  onTap: () => _navigateTo(const FavoritesScreen()),
                ),
                _ModuleRow(
                  index: 2,
                  animation: _enter,
                  icon: Icons.note_alt_outlined,
                  title: 'Yanlış Defteri',
                  subtitle: 'Testlerde yanlış yaptığın sorular',
                  onTap: () => _navigateTo(const WrongQuestionsScreen()),
                ),
                _ModuleRow(
                  index: 3,
                  animation: _enter,
                  icon: Icons.timer_outlined,
                  title: 'Odak · Pomodoro',
                  subtitle: 'İdeal 25 dk · derin çalışma',
                  accent: true,
                  onTap: () =>
                      _navigatePremium(() => const FocusModeScreen()),
                ),
                _ModuleRow(
                  index: 4,
                  animation: _enter,
                  icon: Icons.insights_outlined,
                  title: 'Performans',
                  subtitle: 'Ders bazlı performans özeti',
                  accent: true,
                  onTap: () => _navigateTo(
                    AnalyticsHubScreen(kpssType: _selectedType.value),
                  ),
                ),
                _ModuleRow(
                  index: 5,
                  animation: _enter,
                  icon: Icons.analytics_outlined,
                  title: 'Deneme Analizi',
                  subtitle: 'GK/GY, yayın evi, haftalık özet',
                  onTap: () =>
                      _navigatePremium(() => const StatisticsScreen()),
                ),
                _ModuleRow(
                  index: 6,
                  animation: _enter,
                  icon: Icons.newspaper_outlined,
                  title: 'Güncel Bilgiler',
                  subtitle: 'Sınava özel gelişmeler',
                  onTap: () => _navigateTo(const CurrentInfoScreen()),
                ),
                _ModuleRow(
                  index: 7,
                  animation: _enter,
                  icon: Icons.emoji_events_outlined,
                  title: 'Rozetler',
                  subtitle: 'XP, seri, günlük hedef',
                  accent: true,
                  onTap: () => _navigateTo(const BadgesScreen()),
                ),
              ]),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
            sliver: SliverToBoxAdapter(
              child: ValueListenableBuilder<bool>(
                valueListenable: _isPremium,
                builder: (context, premium, _) {
                  return _sectionHeader(
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
                  return Column(
                    children: [
                      _ModuleRow(
                        index: 7,
                        animation: _enter,
                        icon: Icons.offline_pin_outlined,
                        title: 'Offline Paket',
                        subtitle: premium &&
                                PremiumService.instance.canUseOfflinePack
                            ? 'Kütüphanede internetsiz test'
                            : 'Yalnızca yıllık Premium',
                        locked: !PremiumService.instance.canUseOfflinePack,
                        accent: true,
                        onTap: () => _navigateTo(const OfflinePackScreen()),
                      ),
                      _ModuleRow(
                        index: 8,
                        animation: _enter,
                        icon: Icons.checklist_rtl,
                        title: 'Konu Takibi',
                        subtitle: 'Müfredat ilerlemeni işaretle',
                        locked: !premium,
                        accent: true,
                        onTap: () => _navigatePremium(
                          () => TopicTrackingScreen(
                            kpssType: _selectedType.value,
                          ),
                        ),
                      ),
                      _ModuleRow(
                        index: 9,
                        animation: _enter,
                        icon: Icons.task_alt,
                        title: 'Görev Yönetimi',
                        subtitle: 'Haftalık plan ve öncelikler',
                        locked: !premium,
                        accent: true,
                        onTap: () => _navigatePremium(
                          () => const TaskManagementScreen(),
                        ),
                      ),
                      _ModuleRow(
                        index: 10,
                        animation: _enter,
                        icon: Icons.cloud_outlined,
                        title: 'Bulut Senkron',
                        subtitle: 'Cihazlar arası senkron',
                        locked: !premium,
                        accent: true,
                        onTap: () =>
                            _navigatePremium(() => const CloudSyncScreen()),
                      ),
                      _ModuleRow(
                        index: 11,
                        animation: _enter,
                        icon: Icons.leaderboard_outlined,
                        title: 'Sıralama',
                        subtitle: 'Haftalık ve aylık XP',
                        locked: !premium,
                        accent: true,
                        onTap: () =>
                            _navigatePremium(() => const LeaderboardScreen()),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(22, 12, 22, 48),
            sliver: SliverToBoxAdapter(
              child: _ModuleRow(
                index: 13,
                animation: _enter,
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

class _HomeSubjectChip extends StatelessWidget {
  final String name;
  final IconData icon;
  final Color neon;
  final String subtitle;
  final VoidCallback onTap;

  const _HomeSubjectChip({
    required this.name,
    required this.icon,
    required this.neon,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Ink(
          width: (MediaQuery.sizeOf(context).width - 18 * 2 - 6) / 2,
          padding: const EdgeInsets.fromLTRB(10, 9, 10, 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.inkSoft.withValues(alpha: 0.96),
                AppTheme.ink.withValues(alpha: 0.94),
              ],
            ),
            border: Border.all(color: neon.withValues(alpha: 0.5)),
            boxShadow: SubjectNeonPalette.glow(neon, blur: 7),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: neon),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: neon.withValues(alpha: 0.85),
                      ),
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
const _mikroOgrenmeScreen = StudyAndSolveScreen(
  dersAdi: 'Türkçe',
  konuAdi: 'Anlam Bilgisi',
  altKonuAdi: 'Sözcükte Anlam',
  anlatimMetni:
      'Sözcükte anlam, bir kelimenin cümle içindeki kullanımına '
      'göre kazandığı anlamdır. Gerçek anlam, kelimenin ilk '
      'akla gelen temel anlamıdır. Mecaz anlam ise kelimenin '
      'gerçek anlamından uzaklaşarak kazandığı yeni anlamdır.\n\n'
      'Yan anlam, kelimenin gerçek anlamından türeyen ve '
      'yakınlık bağı bulunan anlamlardır. Terim anlam ise '
      'belirli bir bilim veya sanat dalında kullanılan özel '
      'anlamdır.',
);

class _HeroSection extends StatelessWidget {
  final double topPad;
  final ValueNotifier<KpssType> selectedType;
  final ValueNotifier<bool> isPremium;
  final Animation<double> fadeEarly;
  final Animation<double> fadeMid;
  final Animation<double> fadeType;
  final Animation<double> fadeCountdown;
  final Animation<Offset> slideMid;
  final VoidCallback onPremiumTap;
  final ValueChanged<KpssType> onKpssTypeChanged;

  const _HeroSection({
    required this.topPad,
    required this.selectedType,
    required this.isPremium,
    required this.fadeEarly,
    required this.fadeMid,
    required this.fadeType,
    required this.fadeCountdown,
    required this.slideMid,
    required this.onPremiumTap,
    required this.onKpssTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFF9F5EE),
                  Color(0xFFF3F0EA),
                  Color(0xFFEEE8DF),
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),
        ),
        Positioned(
          top: -56,
          right: -40,
          child: SizedBox(
            width: 200,
            height: 200,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.champagne.withValues(alpha: 0.18),
                    AppTheme.champagne.withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          top: 80,
          left: -60,
          child: SizedBox(
            width: 180,
            height: 180,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppTheme.neonGold.withValues(alpha: 0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            height: 1.5,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  AppTheme.champagne.withValues(alpha: 0.45),
                  AppTheme.champagne.withValues(alpha: 0.65),
                  AppTheme.champagne.withValues(alpha: 0.35),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(20, topPad + 8, 20, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              FadeTransition(
                opacity: fadeEarly,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: const BrandMark.topBar(),
                      ),
                    ),
                    ValueListenableBuilder<bool>(
                      valueListenable: isPremium,
                      builder: (context, premium, _) {
                        return PremiumHeaderButton(
                          isPremium: premium,
                          onTap: premium ? null : onPremiumTap,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: fadeType,
                child: const ExamFocusPanel(light: true),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ModuleRow extends StatefulWidget {
  final int index;
  final AnimationController animation;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool locked;
  final bool accent;

  const _ModuleRow({
    required this.index,
    required this.animation,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.locked = false,
    this.accent = false,
  });

  @override
  State<_ModuleRow> createState() => _ModuleRowState();
}

class _ModuleRowState extends State<_ModuleRow> {
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    // Ana sayfa açılır açılmaz satırlar görünür.
    _fade = const AlwaysStoppedAnimation(1.0);
    _slide = const AlwaysStoppedAnimation(Offset.zero);
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ScaleButton(
          onPressed: widget.onTap,
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
            decoration: SubjectNeonPalette.lightNeonModule(
              neon: widget.accent ? AppTheme.neonEdge : AppTheme.champagne,
              accent: widget.accent,
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: widget.accent
                        ? LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AppTheme.neonEdge.withValues(alpha: 0.32),
                              AppTheme.neonGold.withValues(alpha: 0.14),
                            ],
                          )
                        : null,
                    color: widget.accent
                        ? null
                        : AppTheme.ink.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: widget.accent
                        ? Border.all(
                            color: AppTheme.neonEdge.withValues(alpha: 0.55),
                          )
                        : null,
                    boxShadow: widget.accent
                        ? SubjectNeonPalette.glow(AppTheme.neonEdge, blur: 8)
                        : null,
                  ),
                  child: Icon(
                    widget.icon,
                    size: 22,
                    color: widget.accent ? AppTheme.neonEdge : AppTheme.ink,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              widget.title,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: widget.accent
                                    ? Colors.white
                                    : AppTheme.ink,
                              ),
                            ),
                          ),
                          if (widget.locked) ...const [
                            SizedBox(width: 6),
                            Icon(
                              Icons.lock,
                              size: 13,
                              color: AppTheme.champagne,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.subtitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: widget.accent
                              ? Colors.white.withValues(alpha: 0.72)
                              : AppTheme.slate,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: widget.accent
                      ? AppTheme.neonEdge.withValues(alpha: 0.85)
                      : AppTheme.slate.withValues(alpha: 0.45),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
