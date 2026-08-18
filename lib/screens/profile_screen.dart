import 'dart:async';
import 'dart:math' as math;

import 'package:intl/intl.dart';
import 'package:flutter/material.dart';

import '../constants/brand_constants.dart';
import '../models/user_model.dart';
import '../services/announcement_service.dart';
import '../services/auth_service.dart';
import '../services/gamification_service.dart';
import '../services/kpss_preference_service.dart';
import '../services/store_rating_service.dart';
import '../services/user_message_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import '../widgets/account_link_card.dart';
import '../widgets/app_back_button.dart';
import '../widgets/exam_track_picker_sheet.dart';
import '../widgets/notification_settings_section.dart';
import '../widgets/theme_preference_picker.dart';
import 'announcements_screen.dart';
import 'premium/badges_screen.dart';
import 'premium/premium_paywall_screen.dart';
import 'support_contact_screen.dart';
import 'user_messages_screen.dart';

/// Öğrenci profili — ana sayfa ile aynı neon modül dili.
class ProfileScreen extends StatefulWidget {
  final UserModel user;

  const ProfileScreen({super.key, required this.user});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _announcements = AnnouncementService.instance;
  final _messages = UserMessageService.instance;
  final _auth = AuthService.instance;

  static const _cyan = AppTheme.neonEdge;
  static const _gold = AppTheme.neonGold;

  @override
  void initState() {
    super.initState();
    _announcements.addListener(_onChanged);
    _messages.addListener(_onChanged);
    _auth.addListener(_onChanged);
    KpssPreferenceService.instance.addListener(_onChanged);
    GamificationService.instance.addListener(_onChanged);
    _announcements.refresh();
    _messages.refresh();
    unawaited(GamificationService.instance.initialize());
  }

  @override
  void dispose() {
    _announcements.removeListener(_onChanged);
    _messages.removeListener(_onChanged);
    _auth.removeListener(_onChanged);
    KpssPreferenceService.instance.removeListener(_onChanged);
    GamificationService.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  UserModel get _user => _auth.user ?? widget.user;

  Future<void> _editName() async {
    if (_auth.isAnonymous) {
      await AccountLinkCard.prompt(
        context,
        title: 'Adını kaydet',
        subtitle: 'Görünen adını kaydetmek için Google hesabını bağla.',
      );
      return;
    }
    final current = _user.isim;
    final controller = TextEditingController(text: current);
    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: AppTheme.inkSoft,
          title: const Text(
            'Adını düzenle',
            style: TextStyle(color: Colors.white, fontFamily: 'serif'),
          ),
          content: TextField(
            controller: controller,
            autofocus: true,
            maxLength: 160,
            style: const TextStyle(color: Colors.white),
            cursorColor: _cyan,
            textInputAction: TextInputAction.done,
            decoration: InputDecoration(
              hintText: 'Görünen ad',
              hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.35)),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              focusedBorder: const UnderlineInputBorder(
                borderSide: BorderSide(color: _cyan),
              ),
            ),
            onSubmitted: (v) => Navigator.of(ctx).pop(v.trim()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(
                'İptal',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.55)),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
              child: const Text('Kaydet', style: TextStyle(color: _cyan)),
            ),
          ],
        );
      },
    );
    controller.dispose();
    if (newName == null || !mounted) return;
    if (newName.isEmpty || newName == current) return;

    // Dialog overlay animasyonu bitmeden ağ/notify tetikleme.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;

    final ok = await _auth.updateDisplayName(newName);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Ad güncellendi.' : (_auth.lastError ?? 'Ad güncellenemedi.'),
        ),
      ),
    );
  }

  void _openNotificationSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.smokeDeep,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            16,
            18,
            18 + MediaQuery.paddingOf(ctx).bottom,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: _gold.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(99),
                    boxShadow: SubjectNeonPalette.glow(_gold, blur: 6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _NeonIconBadge(neon: _gold, icon: Icons.notifications_active_outlined),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Bildirim ayarları',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                decoration: SubjectNeonPalette.lightNeonModule(
                  neon: _gold,
                  accent: true,
                  radius: 16,
                ),
                child: const NotificationSettingsSection(
                  embedded: true,
                  neon: true,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final stats = GamificationService.instance.stats;
    final displayName =
        user.isim.isEmpty ? BrandConstants.defaultProfileName : user.isim;
    final msgUnread = _messages.unreadCount;
    final annUnread = _announcements.unreadCount;
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
            stops: const [0.0, 0.42, 1.0],
          ),
        ),
        child: Stack(
          children: [
            const _NeonBackdrop(),
            CustomScrollView(
              physics: const BouncingScrollPhysics(
                parent: AlwaysScrollableScrollPhysics(),
              ),
              slivers: [
                SliverAppBar(
                  pinned: true,
                  elevation: 0,
                  scrolledUnderElevation: 0,
                  backgroundColor: Colors.transparent,
                  foregroundColor: AppTheme.onPage(context),
                  leading: const AppBackButton(),
                  title: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ShaderMask(
                        shaderCallback: (bounds) => const LinearGradient(
                          colors: [_cyan, AppTheme.champagneLight],
                        ).createShader(bounds),
                        child: Text(
                          'Profil',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontWeight: FontWeight.w700,
                            color: AppTheme.onPage(context),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.person_rounded,
                        size: 22,
                        color: AppTheme.champagneLight.withValues(alpha: 0.95),
                      ),
                    ],
                  ),
                  actions: [
                    if (user.isPremium)
                      Padding(
                        padding: const EdgeInsets.only(right: 10),
                        child: _ProfileRateAction(
                          onTap: StoreRatingService.openStoreListing,
                        ),
                      ),
                  ],
                ),
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(16, 4, 16, 32),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _ProfileHero(
                        user: user.copyWith(
                          isAnonymous: user.isAnonymous || _auth.isAnonymous,
                        ),
                        displayName: displayName,
                        email: _auth.isAnonymous ? 'Misafir oturum' : user.eposta,
                        level: stats.seviye,
                        xp: stats.xp,
                        streak: stats.streak,
                        sonrakiSeviyeXp: stats.sonrakiSeviyeXp,
                        onEditName: _auth.busy ? null : _editName,
                        onPremiumTap: user.isPremium
                            ? null
                            : () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (_) => const PremiumPaywallScreen(),
                                  ),
                                ),
                        onBadgesTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const BadgesScreen(),
                          ),
                        ),
                      ),
                      if (_auth.isAnonymous) ...[
                        const SizedBox(height: 12),
                        const AccountLinkCard(margin: EdgeInsets.zero),
                      ],
                      const SizedBox(height: 16),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 1.35,
                        children: [
                          _NeonTile(
                            neon: _cyan,
                            icon: Icons.forum_outlined,
                            title: 'Mesajlar',
                            subtitle: msgUnread > 0 ? '$msgUnread yeni' : 'Gelen kutusu',
                            badge: msgUnread > 0 ? msgUnread : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const UserMessagesScreen(),
                              ),
                            ),
                          ),
                          _NeonTile(
                            neon: _gold,
                            icon: Icons.campaign_outlined,
                            title: 'Duyurular',
                            subtitle:
                                annUnread > 0 ? '$annUnread yeni' : 'ÖSYM & uygulama',
                            badge: annUnread > 0 ? annUnread : null,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const AnnouncementsScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      _SectionTitle(context, 'Kontrol merkezi'),
                      const SizedBox(height: 12),
                      _ProfileModuleRow(
                        neon: _cyan,
                        icon: Icons.school_outlined,
                        title: 'Hedef sınav & sayaç',
                        subtitle: KpssPreferenceService.instance.examTrack.label,
                        onTap: () => ExamTrackPickerSheet.show(context),
                      ),
                      const SizedBox(height: 10),
                      _ProfileModuleRow(
                        neon: _cyan,
                        icon: Icons.palette_outlined,
                        title: 'Görünüm',
                        subtitle: 'Gece · gündüz · sistem',
                        expanded: true,
                        child: const ThemePreferencePicker(
                          embedded: true,
                          neon: true,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _ProfileModuleRow(
                        neon: _gold,
                        icon: Icons.notifications_active_outlined,
                        title: 'Bildirim ayarları',
                        subtitle: 'Hatırlatmalar ve çalışma uyarıları',
                        onTap: _openNotificationSheet,
                      ),
                      const SizedBox(height: 10),
                      _ProfileModuleRow(
                        neon: const Color(0xFF34D399),
                        icon: Icons.support_agent_outlined,
                        title: 'Destek ve İletişim',
                        subtitle: '',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const SupportContactScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _SignOutButton(
                        label: _auth.isAnonymous
                            ? 'Misafir oturumu kapat'
                            : 'Çıkış yap',
                        onPressed: () async {
                          await AuthService.instance.signOut();
                          if (!context.mounted) return;
                          Navigator.of(context)
                              .popUntil((route) => route.isFirst);
                        },
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Hedef Kamu · v1.0.0',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 1.4,
                          color: _cyan.withValues(alpha: 0.72),
                        ),
                      ),
                      SizedBox(height: topPad > 0 ? 0 : 8),
                    ]),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

}

class _ProfileRateAction extends StatelessWidget {
  final VoidCallback onTap;

  const _ProfileRateAction({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          splashColor: AppTheme.champagne.withValues(alpha: 0.22),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFE8C87A),
                  Color(0xFFC9A86C),
                  Color(0xFF8B6914),
                ],
              ),
              border: Border.all(
                color: AppTheme.champagneLight.withValues(alpha: 0.85),
                width: 1.1,
              ),
              boxShadow: SubjectNeonPalette.glow(AppTheme.champagne, blur: 12),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 12, 7),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.thumb_up_alt_rounded,
                    size: 14,
                    color: Colors.white.withValues(alpha: 0.96),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Değerlendir',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.15,
                      color: Colors.white.withValues(alpha: 0.96),
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

class _NeonBackdrop extends StatelessWidget {
  const _NeonBackdrop();

  @override
  Widget build(BuildContext context) {
    final strong = !AppTheme.isDark(context);
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -30,
            child: _GlowOrb(
              color: AppTheme.neonEdge,
              size: 240,
              opacity: strong ? 0.38 : 0.28,
            ),
          ),
          Positioned(
            top: 220,
            left: -80,
            child: _GlowOrb(
              color: AppTheme.neonGold,
              size: 200,
              opacity: strong ? 0.28 : 0.2,
            ),
          ),
          Positioned(
            bottom: 80,
            right: -20,
            child: _GlowOrb(
              color: const Color(0xFFA78BFA),
              size: 180,
              opacity: strong ? 0.22 : 0.16,
            ),
          ),
        ],
      ),
    );
  }
}

class _GlowOrb extends StatelessWidget {
  final Color color;
  final double size;
  final double opacity;

  const _GlowOrb({
    required this.color,
    required this.size,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            color.withValues(alpha: opacity),
            color.withValues(alpha: opacity * 0.35),
            color.withValues(alpha: 0),
          ],
          stops: const [0.0, 0.45, 1.0],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final BuildContext context;
  final String title;

  const _SectionTitle(this.context, this.title);

  @override
  Widget build(BuildContext context) {
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
            boxShadow: SubjectNeonPalette.glow(AppTheme.neonEdge, blur: 8),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontFamily: 'serif',
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: AppTheme.onPage(context),
            letterSpacing: -0.4,
          ),
        ),
      ],
    );
  }
}

/// Ana sayfa modül satırı ile aynı neon kart dili.
class _ProfileModuleRow extends StatefulWidget {
  final Color neon;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool expanded;
  final Widget? child;

  const _ProfileModuleRow({
    required this.neon,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.expanded = false,
    this.child,
  });

  @override
  State<_ProfileModuleRow> createState() => _ProfileModuleRowState();
}

class _ProfileModuleRowState extends State<_ProfileModuleRow> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final tappable = widget.onTap != null;
    final showBody = widget.expanded && _open && widget.child != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: tappable
            ? widget.onTap
            : widget.expanded
                ? () => setState(() => _open = !_open)
                : null,
        borderRadius: BorderRadius.circular(14),
        splashColor: widget.neon.withValues(alpha: 0.12),
        child: Ink(
          decoration: SubjectNeonPalette.lightNeonModule(
            neon: widget.neon,
            accent: true,
            radius: 14,
          ),
          child: Stack(
            children: [
              Positioned(
                top: -16,
                right: -8,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        widget.neon.withValues(alpha: 0.32),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(14, 14, 14, showBody ? 10 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _NeonIconBadge(
                          neon: widget.neon,
                          icon: widget.icon,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.title,
                                style: const TextStyle(
                                  fontFamily: 'serif',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              if (widget.subtitle.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  widget.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: widget.neon.withValues(alpha: 0.88),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        Icon(
                          tappable
                              ? Icons.arrow_forward_ios_rounded
                              : widget.expanded
                                  ? (_open
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded)
                                  : Icons.arrow_forward_ios_rounded,
                          size: tappable ? 14 : 22,
                          color: widget.neon.withValues(alpha: 0.9),
                        ),
                      ],
                    ),
                    if (showBody) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 1,
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              widget.neon.withValues(alpha: 0),
                              widget.neon.withValues(alpha: 0.5),
                              widget.neon.withValues(alpha: 0),
                            ],
                          ),
                        ),
                      ),
                      widget.child!,
                    ],
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

class _NeonIconBadge extends StatelessWidget {
  final Color neon;
  final IconData icon;

  const _NeonIconBadge({required this.neon, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            neon.withValues(alpha: 0.32),
            neon.withValues(alpha: 0.1),
          ],
        ),
        border: Border.all(color: neon.withValues(alpha: 0.65)),
        boxShadow: SubjectNeonPalette.glow(neon, blur: 8),
      ),
      child: Icon(icon, size: 22, color: neon),
    );
  }
}

class _NeonTile extends StatelessWidget {
  final Color neon;
  final IconData icon;
  final String title;
  final String subtitle;
  final int? badge;
  final VoidCallback onTap;

  const _NeonTile({
    required this.neon,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        splashColor: neon.withValues(alpha: 0.12),
        child: Ink(
          decoration: SubjectNeonPalette.lightNeonModule(
            neon: neon,
            accent: true,
            radius: 14,
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: -12,
                right: -6,
                child: Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        neon.withValues(alpha: 0.34),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 14, 9),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            neon.withValues(alpha: 0.28),
                            neon.withValues(alpha: 0.08),
                          ],
                        ),
                        border: Border.all(color: neon.withValues(alpha: 0.65)),
                        boxShadow: SubjectNeonPalette.glow(neon, blur: 6),
                      ),
                      child: Icon(icon, size: 20, color: neon),
                    ),
                    const Spacer(),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontFamily: 'serif',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: neon.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              if (badge != null)
                Positioned(
                  top: 8,
                  right: 8,
                  child: _UnreadCountBadge(count: badge!, neon: neon),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnreadCountBadge extends StatelessWidget {
  final int count;
  final Color neon;

  const _UnreadCountBadge({required this.count, required this.neon});

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            neon,
            AppTheme.champagneLight,
          ],
        ),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.85),
          width: 1.2,
        ),
        boxShadow: SubjectNeonPalette.glow(neon, blur: 10),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: const TextStyle(
          color: AppTheme.ink,
          fontWeight: FontWeight.w800,
          fontSize: 11,
          height: 1,
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  final UserModel user;
  final String displayName;
  final String email;
  final int level;
  final int xp;
  final int streak;
  final int sonrakiSeviyeXp;
  final VoidCallback? onEditName;
  final VoidCallback? onPremiumTap;
  final VoidCallback? onBadgesTap;

  const _ProfileHero({
    required this.user,
    required this.displayName,
    required this.email,
    required this.level,
    required this.xp,
    required this.streak,
    required this.sonrakiSeviyeXp,
    this.onEditName,
    this.onPremiumTap,
    this.onBadgesTap,
  });

  static const _violet = Color(0xFFA78BFA);
  static const _heroSide = 82.0;

  @override
  Widget build(BuildContext context) {
    final neon = user.isPremium ? AppTheme.champagne : AppTheme.neonEdge;

    return Container(
      decoration: SubjectNeonPalette.lightNeonModule(
        neon: neon,
        accent: true,
        radius: 18,
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            top: -40,
            left: -20,
            child: _GlowOrb(color: neon, size: 140, opacity: 0.35),
          ),
          Positioned(
            bottom: -30,
            right: -10,
            child: _GlowOrb(
              color: AppTheme.neonGold,
              size: 120,
              opacity: 0.25,
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                height: 3,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.neonEdge,
                      AppTheme.neonGold,
                      AppTheme.neonEdge,
                    ],
                  ),
                  boxShadow: SubjectNeonPalette.glow(AppTheme.neonEdge, blur: 14),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        SizedBox(
                          width: _heroSide,
                          child: Center(
                            child: _AvatarRing(
                              user: user,
                              displayName: displayName,
                              neon: neon,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              InkWell(
                                onTap: onEditName,
                                borderRadius: BorderRadius.circular(8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        displayName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontFamily: 'serif',
                                          fontSize: 24,
                                          fontWeight: FontWeight.w700,
                                          height: 1.05,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                    if (onEditName != null)
                                      Icon(
                                        Icons.edit_rounded,
                                        size: 17,
                                        color: neon.withValues(alpha: 0.95),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                email,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: neon.withValues(alpha: 0.82),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: _heroSide,
                          child: onBadgesTap == null
                              ? const SizedBox.shrink()
                              : _HeroBadgesButton(
                                  neon: _violet,
                                  level: level,
                                  xp: xp,
                                  sonrakiSeviyeXp: sonrakiSeviyeXp,
                                  onTap: onBadgesTap!,
                                ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            children: [
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                runSpacing: 6,
                                children: [
                                  _StatChip(
                                    neon: AppTheme.neonEdge,
                                    label: 'Lv.$level',
                                  ),
                                  _StatChip(
                                    neon: AppTheme.neonGold,
                                    label: '$xp XP',
                                  ),
                                  _StatChip(
                                    neon: const Color(0xFF34D399),
                                    label: '$streak gün',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              if (user.isPremium)
                                _PremiumStatChip(user: user)
                              else
                                _StatChip(
                                  neon: AppTheme.champagne,
                                  label: 'Standart → Premium',
                                  onTap: onPremiumTap,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroBadgesButton extends StatelessWidget {
  final Color neon;
  final int level;
  final int xp;
  final int sonrakiSeviyeXp;
  final VoidCallback onTap;

  const _HeroBadgesButton({
    required this.neon,
    required this.level,
    required this.xp,
    required this.sonrakiSeviyeXp,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        splashColor: neon.withValues(alpha: 0.18),
        child: Ink(
          width: 82,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                neon.withValues(alpha: 0.22),
                AppTheme.champagne.withValues(alpha: 0.08),
              ],
            ),
            border: Border.all(color: neon.withValues(alpha: 0.55), width: 1.1),
            boxShadow: SubjectNeonPalette.glow(neon, blur: 10),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.military_tech_rounded, color: neon, size: 22),
              const SizedBox(height: 4),
              const Text(
                'Rozetler',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                  height: 1.1,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'Lv.$level',
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: neon.withValues(alpha: 0.92),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvatarRing extends StatelessWidget {
  final UserModel user;
  final String displayName;
  final Color neon;

  const _AvatarRing({
    required this.user,
    required this.displayName,
    required this.neon,
  });

  @override
  Widget build(BuildContext context) {
    final photo = user.photoUrl?.trim();
    return Container(
      width: 76,
      height: 76,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(
          colors: [neon, AppTheme.neonEdge, AppTheme.neonGold, neon],
        ),
        boxShadow: SubjectNeonPalette.glow(neon, blur: 16),
      ),
      child: Container(
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: AppTheme.smokeDeep,
        ),
        clipBehavior: Clip.antiAlias,
        child: user.isAnonymous
            ? Image.asset(
                BrandConstants.appIconAsset,
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) =>
                    _InitialsAvatar(name: displayName),
              )
            : photo != null && photo.isNotEmpty
                ? Image.network(
                    photo,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) =>
                        _InitialsAvatar(name: displayName),
                  )
                : _InitialsAvatar(name: displayName),
      ),
    );
  }
}

class _InitialsAvatar extends StatelessWidget {
  final String name;

  const _InitialsAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.neonEdge.withValues(alpha: 0.22),
            AppTheme.smokeDeep,
          ],
        ),
      ),
      child: Text(
        _initials(name),
        style: const TextStyle(
          fontFamily: 'serif',
          fontWeight: FontWeight.w800,
          fontSize: 24,
          color: Colors.white,
        ),
      ),
    );
  }

  static String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'HK';
    if (parts.length == 1) {
      return parts.first
          .substring(0, math.min(2, parts.first.length))
          .toUpperCase();
    }
    return '${parts.first[0]}${parts[1][0]}'.toUpperCase();
  }
}

void _showPremiumInfoSheet(BuildContext context, UserModel user) {
  final hasMeta = user.premiumBitisTarihi != null ||
      user.premiumVerilisTarihi != null ||
      (user.premiumGrantNote?.trim().isNotEmpty ?? false);

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: AppTheme.inkSoft,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.verified_outlined,
                  color: AppTheme.champagne,
                  size: 22,
                ),
                const SizedBox(width: 10),
                Text(
                  'Premium üyelik',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white.withValues(alpha: 0.92),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (hasMeta)
              _PremiumMetaBody(user: user)
            else
              Text(
                'Aktif premium üyelik',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _PremiumStatChip extends StatelessWidget {
  final UserModel user;

  const _PremiumStatChip({required this.user});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _showPremiumInfoSheet(context, user),
        borderRadius: BorderRadius.circular(999),
        splashColor: AppTheme.champagne.withValues(alpha: 0.18),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppTheme.champagne.withValues(alpha: 0.38),
                const Color(0xFF3A2E14).withValues(alpha: 0.92),
                AppTheme.neonGold.withValues(alpha: 0.28),
              ],
            ),
            border: Border.all(
              color: AppTheme.champagneLight.withValues(alpha: 0.85),
              width: 1.15,
            ),
            boxShadow: [
              ...SubjectNeonPalette.glow(AppTheme.champagne, blur: 12),
              BoxShadow(
                color: AppTheme.neonGold.withValues(alpha: 0.18),
                blurRadius: 16,
                spreadRadius: -2,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.workspace_premium_rounded,
                size: 15,
                color: AppTheme.champagneLight,
              ),
              const SizedBox(width: 6),
              const Text(
                'PREMIUM',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  height: 1,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 20,
                height: 20,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.inkSoft.withValues(alpha: 0.72),
                  border: Border.all(
                    color: AppTheme.champagneLight.withValues(alpha: 0.7),
                  ),
                ),
                child: const Icon(
                  Icons.info_outline_rounded,
                  size: 12,
                  color: AppTheme.champagneLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final Color neon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _StatChip({
    required this.neon,
    required this.label,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: filled ? neon.withValues(alpha: 0.24) : Colors.transparent,
        border: Border.all(color: neon.withValues(alpha: filled ? 0.85 : 0.55)),
        boxShadow: SubjectNeonPalette.glow(neon, blur: filled ? 10 : 6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: filled ? Colors.white : neon,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: filled ? 1.0 : 0.1,
        ),
      ),
    );
    if (onTap == null) return chip;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: chip,
      ),
    );
  }
}

class _PremiumMetaBody extends StatelessWidget {
  final UserModel user;

  const _PremiumMetaBody({required this.user});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (user.premiumBitisTarihi != null) {
      parts.add(
        'Bitiş: ${DateFormat('d MMM yyyy').format(user.premiumBitisTarihi!.toLocal())}',
      );
    }
    if (user.premiumVerilisTarihi != null) {
      parts.add(
        'Veriliş: ${DateFormat('d MMM yyyy').format(user.premiumVerilisTarihi!.toLocal())}',
      );
    }
    final note = user.premiumGrantNote?.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (parts.isNotEmpty)
          Text(
            parts.join('  ·  '),
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withValues(alpha: 0.72),
            ),
          ),
        if (note != null && note.isNotEmpty) ...[
          if (parts.isNotEmpty) const SizedBox(height: 6),
          Text(
            note,
            style: TextStyle(
              fontSize: 12,
              color: AppTheme.champagne.withValues(alpha: 0.78),
              height: 1.35,
            ),
          ),
        ],
      ],
    );
  }
}

class _SignOutButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SignOutButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final dark = AppTheme.isDark(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: AppTheme.neonEdge.withValues(alpha: dark ? 0.45 : 0.65),
            ),
            gradient: LinearGradient(
              colors: [
                AppTheme.neonEdge.withValues(alpha: dark ? 0.1 : 0.14),
                Colors.transparent,
              ],
            ),
            boxShadow: SubjectNeonPalette.glow(
              AppTheme.neonEdge,
              blur: dark ? 8 : 12,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout_rounded,
                  size: 18,
                  color: AppTheme.onPage(context).withValues(alpha: 0.72),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    color: AppTheme.onPage(context).withValues(alpha: 0.82),
                    fontWeight: FontWeight.w600,
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
