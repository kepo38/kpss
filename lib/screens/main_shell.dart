import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../models/user_model.dart';
import '../services/ad_manager.dart';
import '../services/auth_service.dart';
import '../services/content_bank_service.dart';
import '../services/database_service.dart';
import '../services/kpss_preference_service.dart';
import '../services/play_billing_service.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_shell_top_bar.dart';
import '../widgets/countdown_widget.dart';
import '../widgets/wrong_notebook_promo_bubble.dart';
import 'analytics_hub_screen.dart';
import 'home_screen.dart';
import 'premium/premium_paywall_screen.dart';
import 'premium/statistics_screen.dart';
import 'profile_screen.dart';
import 'study_hub_screen.dart';

/// Ana kabuk — altta Ana Sayfa / Dersler / Gelişim / Deneme sekmeleri.
class MainShell extends StatefulWidget {
  final UserModel user;

  const MainShell({super.key, required this.user});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;
  final ValueNotifier<KpssType> _selectedType =
      ValueNotifier(KpssType.lisans);
  final ValueNotifier<bool> _isPremium =
      ValueNotifier(PremiumService.instance.isPremium);

  @override
  void initState() {
    super.initState();
    _selectedType.value = KpssPreferenceService.instance.kpssType;
    KpssPreferenceService.instance.addListener(_onKpssPrefChanged);
    AdManager.instance.setPremium(_isPremium.value);
    DatabaseService.instance.setCurrentUser(widget.user);
    PlayBillingService.instance.premiumNotifier.addListener(_onPremiumChanged);
    AuthService.instance.addListener(_onPremiumChanged);
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(const Duration(milliseconds: 400), () {
        unawaited(ContentBankService.instance.initialize());
      });
    });
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
    AuthService.instance.removeListener(_onPremiumChanged);
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

  Future<void> _openPaywall() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PremiumPaywallScreen(),
      ),
    );
    _onPremiumChanged();
  }

  Future<void> _openProfile() async {
    if (!mounted) return;
    final user = AuthService.instance.user ?? widget.user;
    unawaited(AdManager.instance.onPageTransition());
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileScreen(user: user),
      ),
    );
  }

  Future<void> _openMore() async {
    if (!mounted) return;
    // Stüdyo hub — geçiş reklamı yok (hemen açılsın).
    AdManager.instance.skipNextPageTransition();
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HomeScreen(user: widget.user),
      ),
    );
    _onPremiumChanged();
  }

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      body: Stack(
        children: [
          Column(
            children: [
              AppShellTopBar(
                topPad: topPad,
                isPremium: _isPremium,
                onPremiumTap: _openPaywall,
                onMoreTap: _openMore,
              ),
              Expanded(
                child: ValueListenableBuilder<KpssType>(
                  valueListenable: _selectedType,
                  builder: (context, type, _) {
                    switch (_index) {
                      case 1:
                        return StudyHubScreen(
                          kpssType: type,
                          embedded: true,
                          pane: StudyHubPane.subjects,
                          shellTopBarVisible: true,
                        );
                      case 2:
                        return AnalyticsHubScreen(
                          kpssType: type,
                          embedded: true,
                        );
                      case 3:
                        return const StatisticsScreen(embedded: true);
                      case 0:
                      default:
                        return StudyHubScreen(
                          kpssType: type,
                          embedded: true,
                          pane: StudyHubPane.home,
                          selectedType: _selectedType,
                          onKpssTypeChanged: _onExamTypeChanged,
                          isPremium: _isPremium,
                          onPremiumTap: _openPaywall,
                          onMoreTap: _openMore,
                          shellTopBarVisible: true,
                        );
                    }
                  },
                ),
              ),
            ],
          ),
          WrongNotebookPromoBubble(homeVisible: _index == 0),
        ],
      ),
      bottomNavigationBar: _PremiumBottomBar(
        index: _index,
        onChanged: (i) => setState(() => _index = i),
        onProfileTap: _openProfile,
      ),
    );
  }
}

class _PremiumBottomBar extends StatelessWidget {
  final int index;
  final ValueChanged<int> onChanged;
  final VoidCallback? onProfileTap;

  const _PremiumBottomBar({
    required this.index,
    required this.onChanged,
    this.onProfileTap,
  });

  static const _items = [
    (Icons.home_outlined, Icons.home_rounded, 'Ana Sayfa'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Dersler'),
    (Icons.trending_up_outlined, Icons.trending_up, 'Gelişim'),
    (Icons.assignment_outlined, Icons.assignment, 'Deneme'),
  ];

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final dark = AppTheme.isDark(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.barSurface(context),
        border: Border(
          top: BorderSide(color: AppTheme.hairline(context)),
        ),
        boxShadow: [
          BoxShadow(
            color: (dark ? Colors.black : AppTheme.ink).withValues(alpha: 0.18),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(6, 8, 8, bottom > 0 ? bottom : 10),
        child: Row(
          children: [
            for (var i = 0; i < _items.length; i++)
              Expanded(
                child: _NavItem(
                  icon: index == i ? _items[i].$2 : _items[i].$1,
                  label: _items[i].$3,
                  selected: index == i,
                  onTap: () => onChanged(i),
                ),
              ),
            const SizedBox(width: 8),
            _ProfileButton(onTap: onProfileTap),
          ],
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final on = AppTheme.onPage(context);
    final color = selected
        ? on
        : AppTheme.mutedOnPage(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: selected
                ? AppTheme.champagne.withValues(alpha: 0.18)
                : Colors.transparent,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 22,
                color: selected ? AppTheme.champagne : color,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  letterSpacing: selected ? 0.2 : 0,
                  color: selected ? AppTheme.champagne : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileButton extends StatelessWidget {
  final VoidCallback? onTap;

  const _ProfileButton({this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: AppTheme.champagne.withValues(alpha: 0.2),
        highlightColor: AppTheme.champagne.withValues(alpha: 0.08),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFFFFF8EE),
                Color(0xFFF5E6C8),
                Color(0xFFE8CF98),
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.champagne.withValues(alpha: 0.35),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFF2A3548),
                        AppTheme.ink,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.ink.withValues(alpha: 0.22),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 14,
                    color: AppTheme.champagneLight,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Profil',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
