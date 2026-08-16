import 'dart:async';

import 'package:flutter/material.dart';

import '../services/ad_free_campaign_service.dart';
import '../services/ad_manager.dart';
import '../services/premium_service.dart';
import '../theme/app_theme.dart';
import '../theme/subject_neon_palette.dart';
import 'scale_button.dart';

/// Ana sayfada 3 reklam → 12 saat reklamsız kampanya kartı.
class AdFreeCampaignCard extends StatefulWidget {
  const AdFreeCampaignCard({super.key});

  @override
  State<AdFreeCampaignCard> createState() => _AdFreeCampaignCardState();
}

class _AdFreeCampaignCardState extends State<AdFreeCampaignCard> {
  final _service = AdFreeCampaignService.instance;
  Timer? _tick;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _service.addListener(_onServiceChanged);
    _startTickerIfNeeded();
  }

  @override
  void dispose() {
    _tick?.cancel();
    _service.removeListener(_onServiceChanged);
    super.dispose();
  }

  void _onServiceChanged() {
    if (!mounted) return;
    _startTickerIfNeeded();
    setState(() {});
  }

  void _startTickerIfNeeded() {
    final needsTicker =
        _service.isAdFreeActive || _service.cooldownRemaining != null;
    if (needsTicker && (_tick == null || !_tick!.isActive)) {
      _tick?.cancel();
      _tick = Timer.periodic(const Duration(seconds: 30), (_) {
        if (!mounted) return;
        setState(() {});
        if (!_service.isAdFreeActive && _service.cooldownRemaining == null) {
          _tick?.cancel();
          _tick = null;
        }
      });
    } else if (!needsTicker) {
      _tick?.cancel();
      _tick = null;
    }
  }

  Future<void> _watchAd() async {
    if (_loading || !_service.canWatchNextAd) return;
    setState(() => _loading = true);

    final earned = await AdManager.instance.requestCampaignRewardedAd();
    if (earned && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _service.isAdFreeActive
                ? '12 saat reklamsız mod başladı!'
                : 'İlerleme kaydedildi (${_service.adsWatchedToday}/${AdFreeCampaignService.requiredAds})',
          ),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reklam yüklenemedi veya izlenmedi. Lütfen tekrar deneyin.'),
        ),
      );
    }

    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (PremiumService.instance.isPremium) {
      return const SizedBox.shrink();
    }

    return ListenableBuilder(
      listenable: _service,
      builder: (context, _) {
        final progress = _service.progress;
        final adFree = _service.isAdFreeActive;
        final canWatch = _service.canWatchNextAd && !_loading;

        return Container(
          margin: const EdgeInsets.fromLTRB(22, 12, 22, 4),
          padding: const EdgeInsets.all(16),
          decoration: SubjectNeonPalette.lightNeonModule(
            neon: AppTheme.neonEdge,
            accent: adFree,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(
                    adFree ? Icons.verified_outlined : Icons.movie_outlined,
                    color: adFree ? AppTheme.neonEdge : AppTheme.champagne,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      adFree ? 'Reklamsız mod' : 'Reklamsız çalışma hakkı',
                      style: TextStyle(
                        fontFamily: 'serif',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: adFree ? Colors.white : AppTheme.ink,
                      ),
                    ),
                  ),
                  Text(
                    adFree
                        ? '%100'
                        : '%${(progress * 100).round()}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: adFree
                          ? AppTheme.neonEdge
                          : AppTheme.champagne,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 8,
                  backgroundColor: adFree
                      ? Colors.white.withValues(alpha: 0.12)
                      : AppTheme.ink.withValues(alpha: 0.08),
                  color: adFree ? AppTheme.neonEdge : AppTheme.champagne,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                _service.subtitleLabel,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: adFree
                      ? Colors.white.withValues(alpha: 0.72)
                      : AppTheme.slate,
                ),
              ),
              if (!adFree) ...[
                const SizedBox(height: 12),
                ScaleButton(
                  onPressed: canWatch ? _watchAd : null,
                  child: FilledButton.icon(
                    onPressed: canWatch ? _watchAd : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: canWatch
                          ? AppTheme.neonEdge.withValues(alpha: 0.18)
                          : AppTheme.ink.withValues(alpha: 0.06),
                      foregroundColor:
                          canWatch ? AppTheme.ink : AppTheme.slate,
                      side: BorderSide(
                        color: canWatch
                            ? AppTheme.neonEdge.withValues(alpha: 0.65)
                            : AppTheme.ink.withValues(alpha: 0.1),
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: 12,
                        horizontal: 14,
                      ),
                    ),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_circle_outline, size: 20),
                    label: Text(
                      _loading ? 'Reklam yükleniyor…' : _service.ctaButtonLabel,
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}
