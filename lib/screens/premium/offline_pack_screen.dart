import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/app_config_service.dart';
import '../../services/offline_pack_service.dart';
import '../../services/play_billing_service.dart';
import '../../services/premium_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/scale_button.dart';
import 'premium_paywall_screen.dart';

/// Yıllık Premium: kütüphane / internetsiz çalışma paketi.
class OfflinePackScreen extends StatefulWidget {
  const OfflinePackScreen({super.key});

  @override
  State<OfflinePackScreen> createState() => _OfflinePackScreenState();
}

class _OfflinePackScreenState extends State<OfflinePackScreen> {
  final _service = OfflinePackService.instance;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onChanged);
    AppConfigService.instance.addListener(_onChanged);
    PlayBillingService.instance.premiumNotifier.addListener(_onChanged);
    if (!_service.isInitialized) {
      _service.initialize();
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
    AppConfigService.instance.removeListener(_onChanged);
    PlayBillingService.instance.premiumNotifier.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _openPaywall({bool preferYearly = true}) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PremiumPaywallScreen(),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _download() async {
    if (_busy) return;
    if (!PremiumService.instance.isOfflinePackModuleEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Offline paket şu an kullanıma kapalı.'),
        ),
      );
      return;
    }
    if (!PremiumService.instance.canUseOfflinePack) {
      await _openPaywall();
      return;
    }

    setState(() => _busy = true);
    final ok = await _service.downloadPack(force: true);
    if (!mounted) return;
    setState(() => _busy = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? 'Offline paket hazır. İnternet olmadan test çözebilirsiniz.'
              : (_service.lastError ?? 'İndirme başarısız.'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moduleOn = PremiumService.instance.isOfflinePackModuleEnabled;
    final yearly = PremiumService.instance.canUseOfflinePack;
    final ready = _service.isReady;
    final dateText = _service.lastDownloadedAt == null
        ? 'Henüz indirilmedi'
        : DateFormat('d.MM.yyyy · HH:mm').format(_service.lastDownloadedAt!);
    final statusValue = !moduleOn
        ? 'Geçici olarak kapalı'
        : yearly
            ? (ready ? 'Çevrimdışı kullanıma hazır' : 'İndirme gerekli')
            : 'Yıllık Premium gerekli';

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: AppTheme.onPage(context),
        leading: const AppBackButton(),
        title: const Text(
          'Offline Paket',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600),
        ),
      ),
      extendBodyBehindAppBar: false,
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: const [0.0, 0.38, 0.72, 1.0],
            colors: [
              Color.lerp(AppTheme.pageTop(context), AppTheme.champagne, 0.08)!,
              AppTheme.page(context),
              Color.lerp(AppTheme.page(context), AppTheme.ink, 0.04)!,
              AppTheme.pageDeep(context),
            ],
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: -80,
              right: -60,
              child: IgnorePointer(
                child: Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.champagne.withValues(alpha: 0.18),
                        AppTheme.champagne.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 40,
              left: -70,
              child: IgnorePointer(
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        AppTheme.ink.withValues(alpha: 0.07),
                        AppTheme.ink.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            ListView(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 40),
              children: [
                _HeroCard(yearly: yearly, ready: ready),
                const SizedBox(height: 20),
                _StatusPanel(
                  statusValue: statusValue,
                  ready: ready,
                  yearly: yearly,
                  packVersion: 'v${_service.packVersion ?? '-'}',
                  contentValue:
                      '${_service.questionCount} soru · ${_service.testCount} test',
                  lastDownload: dateText,
                ),
                const SizedBox(height: 22),
                if (!moduleOn) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF94A3B8).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Text(
                      'Offline paket yönetici tarafından geçici olarak '
                      'kapatıldı. İndirme ve satın alma şu an mümkün değil.',
                      style: TextStyle(
                        color: AppTheme.ink.withValues(alpha: 0.78),
                        height: 1.4,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ] else if (!yearly) ...[
                  ScaleButton(
                    onPressed: _openPaywall,
                    child: _PrimaryCta(
                      onPressed: _openPaywall,
                      busy: false,
                      icon: Icons.workspace_premium_outlined,
                      label: 'Yıllık Premium\'a geç',
                    ),
                  ),
                ] else ...[
                  ScaleButton(
                    onPressed: _busy ? null : _download,
                    child: _PrimaryCta(
                      onPressed: _busy ? null : _download,
                      busy: _busy,
                      icon: ready ? Icons.sync : Icons.download_outlined,
                      label: _busy
                          ? 'İndiriliyor…'
                          : ready
                              ? 'Paketi güncelle'
                              : 'Offline paketi indir',
                      emphasis: ready ? _CtaEmphasis.update : _CtaEmphasis.download,
                    ),
                  ),
                ],
                if (_service.lastError != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.red.shade200.withValues(alpha: 0.8),
                      ),
                    ),
                    child: Text(
                      _service.lastError!,
                      style: TextStyle(
                        color: Colors.red.shade800,
                        height: 1.35,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  'Nasıl kullanılır?',
                  style: TextStyle(
                    fontFamily: 'serif',
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink.withValues(alpha: 0.92),
                  ),
                ),
                const SizedBox(height: 12),
                const _Step(
                  n: '1',
                  text: 'Evde / kafede Wi‑Fi ile paketi indirin.',
                ),
                const _Step(
                  n: '2',
                  text: 'Kütüphanede uçak modunda uygulamayı açın.',
                ),
                const _Step(
                  n: '3',
                  text:
                      'Dersler sekmesinden konu testlerini normal şekilde çözün.',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _CtaEmphasis { download, update }

class _HeroCard extends StatelessWidget {
  final bool yearly;
  final bool ready;

  const _HeroCard({required this.yearly, required this.ready});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF162338),
            Color(0xFF0C1424),
            Color(0xFF101828),
          ],
        ),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.45),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.champagne.withValues(alpha: 0.22),
            blurRadius: 28,
            offset: const Offset(0, 10),
          ),
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.28),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            top: -30,
            right: -20,
            child: IgnorePointer(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.champagne.withValues(alpha: 0.22),
                      AppTheme.champagne.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppTheme.champagne.withValues(alpha: 0.14),
                      border: Border.all(
                        color: AppTheme.champagne.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Icon(
                      ready
                          ? Icons.offline_pin_outlined
                          : Icons.cloud_download_outlined,
                      color: AppTheme.champagneLight,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Kütüphane modu',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 24,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.champagne.withValues(alpha: 0.35),
                          AppTheme.champagne.withValues(alpha: 0.18),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppTheme.champagneLight.withValues(alpha: 0.65),
                      ),
                    ),
                    child: const Text(
                      'YILLIK',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: AppTheme.champagneLight,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                yearly
                    ? 'Wi‑Fi’deyken paketi indirin. Sonra internet olmadan '
                        'konu testlerini çözebilirsiniz.'
                    : 'Offline paket yalnızca yıllık Premium aboneliğinde '
                        'açılır. Aylık planda bu özellik yoktur.',
                style: TextStyle(
                  height: 1.45,
                  fontSize: 14.5,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  final String statusValue;
  final bool ready;
  final bool yearly;
  final String packVersion;
  final String contentValue;
  final String lastDownload;

  const _StatusPanel({
    required this.statusValue,
    required this.ready,
    required this.yearly,
    required this.packVersion,
    required this.contentValue,
    required this.lastDownload,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = !yearly
        ? AppTheme.slate
        : ready
            ? const Color(0xFF2F6B4F)
            : AppTheme.champagne;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withValues(alpha: 0.88),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.ink.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _StatusRow(
            icon: Icons.circle,
            iconColor: statusColor,
            label: 'Durum',
            value: statusValue,
            valueColor: statusColor,
            emphasize: true,
            showDivider: true,
          ),
          _StatusRow(
            icon: Icons.tag_outlined,
            iconColor: AppTheme.slate.withValues(alpha: 0.7),
            label: 'Paket sürümü',
            value: packVersion,
            showDivider: true,
          ),
          _StatusRow(
            icon: Icons.library_books_outlined,
            iconColor: AppTheme.slate.withValues(alpha: 0.7),
            label: 'İçerik',
            value: contentValue,
            showDivider: true,
          ),
          _StatusRow(
            icon: Icons.history_outlined,
            iconColor: AppTheme.slate.withValues(alpha: 0.7),
            label: 'Son indirme',
            value: lastDownload,
            showDivider: false,
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool emphasize;
  final bool showDivider;

  const _StatusRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.emphasize = false,
    required this.showDivider,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            emphasize ? 16 : 13,
            16,
            emphasize ? 16 : 13,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: emphasize ? 11 : 18,
                color: iconColor,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: AppTheme.slate.withValues(alpha: 0.85),
                  fontSize: emphasize ? 13.5 : 13,
                  fontWeight: emphasize ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.end,
                  style: TextStyle(
                    fontWeight: emphasize ? FontWeight.w700 : FontWeight.w600,
                    fontSize: emphasize ? 14.5 : 14,
                    color: valueColor ?? AppTheme.ink,
                    height: 1.25,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          Divider(
            height: 1,
            thickness: 1,
            indent: 16,
            endIndent: 16,
            color: AppTheme.ink.withValues(alpha: 0.05),
          ),
      ],
    );
  }
}

class _PrimaryCta extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool busy;
  final IconData icon;
  final String label;
  final _CtaEmphasis emphasis;

  const _PrimaryCta({
    required this.onPressed,
    required this.busy,
    required this.icon,
    required this.label,
    this.emphasis = _CtaEmphasis.download,
  });

  @override
  Widget build(BuildContext context) {
    final isUpdate = emphasis == _CtaEmphasis.update;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: onPressed == null
            ? const []
            : [
                BoxShadow(
                  color: AppTheme.champagne.withValues(alpha: 0.42),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: isUpdate ? AppTheme.ink : AppTheme.champagne,
          foregroundColor: isUpdate ? AppTheme.champagneLight : AppTheme.ink,
          disabledBackgroundColor: AppTheme.champagne.withValues(alpha: 0.45),
          disabledForegroundColor: AppTheme.ink.withValues(alpha: 0.55),
          elevation: 0,
          minimumSize: const Size(double.infinity, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: isUpdate
                ? BorderSide(
                    color: AppTheme.champagne.withValues(alpha: 0.55),
                  )
                : BorderSide.none,
          ),
        ),
        icon: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: isUpdate ? AppTheme.champagneLight : AppTheme.ink,
                ),
              )
            : Icon(icon, size: 22),
        label: Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  final String n;
  final String text;

  const _Step({required this.n, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppTheme.champagne.withValues(alpha: 0.35),
                  AppTheme.champagne.withValues(alpha: 0.16),
                ],
              ),
              border: Border.all(
                color: AppTheme.champagne.withValues(alpha: 0.5),
              ),
            ),
            child: Text(
              n,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.ink,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                text,
                style: TextStyle(
                  height: 1.4,
                  fontSize: 14.5,
                  color: AppTheme.slate.withValues(alpha: 0.95),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
