import 'package:flutter_test/flutter_test.dart';
import 'package:kpss_akademi/services/ad_free_campaign_service.dart';

void main() {
  final base = DateTime(2026, 8, 9, 10, 0);

  test('campaign day key uses local calendar date', () {
    expect(
      AdFreeCampaignLogic.campaignDayKey(DateTime(2026, 8, 9, 23, 59)),
      '2026-08-09',
    );
  });

  test('progress follows 0 33 66 pattern before ad-free', () {
    expect(
      AdFreeCampaignLogic.progress(adsWatchedToday: 0, adFreeActive: false),
      0,
    );
    expect(
      AdFreeCampaignLogic.progress(adsWatchedToday: 1, adFreeActive: false),
      closeTo(0.333, 0.01),
    );
    expect(
      AdFreeCampaignLogic.progress(adsWatchedToday: 2, adFreeActive: false),
      closeTo(0.666, 0.01),
    );
    expect(
      AdFreeCampaignLogic.progress(adsWatchedToday: 0, adFreeActive: true),
      1,
    );
  });

  test('cannot watch during active ad-free window', () {
    final until = base.add(const Duration(hours: 6));
    expect(
      AdFreeCampaignLogic.isAdFreeActive(until, base.add(const Duration(hours: 1))),
      isTrue,
    );
    expect(
      AdFreeCampaignLogic.canWatchNextAd(
        adsWatchedToday: 0,
        lastRewardedAdAt: null,
        now: base,
        adFreeActive: true,
      ),
      isFalse,
    );
  });

  test('enforces four hour cooldown between campaign ads', () {
    final last = base;
    expect(
      AdFreeCampaignLogic.canWatchNextAd(
        adsWatchedToday: 1,
        lastRewardedAdAt: last,
        now: base.add(const Duration(hours: 3, minutes: 59)),
        adFreeActive: false,
      ),
      isFalse,
    );
    expect(
      AdFreeCampaignLogic.canWatchNextAd(
        adsWatchedToday: 1,
        lastRewardedAdAt: last,
        now: base.add(const Duration(hours: 4)),
        adFreeActive: false,
      ),
      isTrue,
    );
  });

  test('button labels state reward clearly for Google policy', () {
    expect(
      AdFreeCampaignLogic.ctaButtonLabel(
        adsWatchedToday: 0,
        adFreeActive: false,
        adFreeRemaining: null,
        canWatch: true,
        cooldownRemaining: null,
      ),
      'Reklam izle (1/3) — 12 saat reklamsız kazan',
    );
    expect(
      AdFreeCampaignLogic.ctaButtonLabel(
        adsWatchedToday: 2,
        adFreeActive: false,
        adFreeRemaining: null,
        canWatch: true,
        cooldownRemaining: null,
      ),
      'Son reklamı izle — 12 saat reklamsız başlat',
    );
    expect(
      AdFreeCampaignLogic.ctaButtonLabel(
        adsWatchedToday: 0,
        adFreeActive: true,
        adFreeRemaining: const Duration(hours: 8, minutes: 12),
        canWatch: false,
        cooldownRemaining: null,
      ),
      'Reklamsız mod aktif',
    );
  });

  test('cooldown label shows remaining wait time', () {
    expect(
      AdFreeCampaignLogic.ctaButtonLabel(
        adsWatchedToday: 1,
        adFreeActive: false,
        adFreeRemaining: null,
        canWatch: false,
        cooldownRemaining: const Duration(hours: 2, minutes: 15),
      ),
      'Sonraki reklam: 2s 15dk',
    );
  });
}
