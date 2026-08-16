import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/offline_pack_service.dart';
import '../../services/play_billing_service.dart';
import '../../services/premium_service.dart';
import '../../theme/app_theme.dart';
import '../../theme/subject_neon_palette.dart';
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
    PlayBillingService.instance.premiumNotifier.addListener(_onChanged);
    if (!_service.isInitialized) {
      _service.initialize();
    }
  }

  @override
  void dispose() {
    _service.removeListener(_onChanged);
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
    final yearly = PremiumService.instance.canUseOfflinePack;
    final ready = _service.isReady;
    final dateText = _service.lastDownloadedAt == null
        ? 'Henüz indirilmedi'
        : DateFormat('d.MM.yyyy · HH:mm').format(_service.lastDownloadedAt!);

    return Scaffold(
      backgroundColor: AppTheme.page(context),
      appBar: AppBar(
        backgroundColor: AppTheme.page(context),
        foregroundColor: AppTheme.onPage(context),
        leading: const AppBackButton(),
        title: const Text(
          'Offline Paket',
          style: TextStyle(fontFamily: 'serif', fontWeight: FontWeight.w600),
        ),
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppTheme.pageTop(context),
              AppTheme.page(context),
              AppTheme.pageDeep(context),
            ],
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 40),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: SubjectNeonPalette.lightNeonModule(
                neon: AppTheme.champagne,
                accent: true,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        ready
                            ? Icons.offline_pin_outlined
                            : Icons.cloud_download_outlined,
                        color: AppTheme.champagneLight,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Kütüphane modu',
                          style: TextStyle(
                            fontFamily: 'serif',
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.champagne.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: AppTheme.champagne.withValues(alpha: 0.55),
                          ),
                        ),
                        child: const Text(
                          'YILLIK',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: AppTheme.champagneLight,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    yearly
                        ? 'Wi‑Fi’deyken paketi indirin. Sonra internet olmadan '
                            'konu testlerini çözebilirsiniz.'
                        : 'Offline paket yalnızca yıllık Premium aboneliğinde '
                            'açılır. Aylık planda bu özellik yoktur.',
                    style: TextStyle(
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.72),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InfoTile(
              label: 'Durum',
              value: yearly
                  ? (ready ? 'Çevrimdışı kullanıma hazır' : 'İndirme gerekli')
                  : 'Yıllık Premium gerekli',
            ),
            _InfoTile(label: 'Paket sürümü', value: 'v${_service.packVersion ?? '-'}'),
            _InfoTile(
              label: 'İçerik',
              value: '${_service.questionCount} soru · ${_service.testCount} test',
            ),
            _InfoTile(label: 'Son indirme', value: dateText),
            const SizedBox(height: 20),
            if (!yearly) ...[
              ScaleButton(
                onPressed: _openPaywall,
                child: FilledButton.icon(
                  onPressed: _openPaywall,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.champagne,
                    foregroundColor: AppTheme.ink,
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  icon: const Icon(Icons.workspace_premium_outlined),
                  label: const Text('Yıllık Premium\'a geç'),
                ),
              ),
            ] else ...[
              ScaleButton(
                onPressed: _busy ? null : _download,
                child: FilledButton.icon(
                  onPressed: _busy ? null : _download,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppTheme.neonEdge.withValues(alpha: 0.2),
                    foregroundColor: AppTheme.ink,
                    side: BorderSide(
                      color: AppTheme.neonEdge.withValues(alpha: 0.65),
                    ),
                    minimumSize: const Size(double.infinity, 52),
                  ),
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          ready ? Icons.sync : Icons.download_outlined,
                        ),
                  label: Text(
                    _busy
                        ? 'İndiriliyor…'
                        : ready
                            ? 'Paketi güncelle'
                            : 'Offline paketi indir',
                  ),
                ),
              ),
            ],
            if (_service.lastError != null) ...[
              const SizedBox(height: 12),
              Text(
                _service.lastError!,
                style: TextStyle(
                  color: Colors.red.shade700,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 22),
            Text(
              'Nasıl kullanılır?',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: AppTheme.slate.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 8),
            const _Step(n: '1', text: 'Evde / kafede Wi‑Fi ile paketi indirin.'),
            const _Step(
              n: '2',
              text: 'Kütüphanede uçak modunda uygulamayı açın.',
            ),
            const _Step(
              n: '3',
              text: 'Dersler sekmesinden konu testlerini normal şekilde çözün.',
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String label;
  final String value;

  const _InfoTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.ink.withValues(alpha: 0.07)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: AppTheme.slate.withValues(alpha: 0.8),
              fontSize: 13,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.ink,
              ),
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppTheme.champagne.withValues(alpha: 0.2),
            child: Text(
              n,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppTheme.ink,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                height: 1.35,
                color: AppTheme.slate.withValues(alpha: 0.9),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
