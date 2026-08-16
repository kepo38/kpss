import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';

import '../../constants/brand_constants.dart';
import '../../services/auth_service.dart';
import '../../services/iap_constants.dart';
import '../../services/play_billing_service.dart';
import '../../services/premium_service.dart';
import '../../services/promo_code_service.dart';
import '../../services/user_savings_insight_service.dart';
import '../../services/daily_mini_exam_service.dart';
import '../../services/content_bank_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/account_link_card.dart';
import '../../widgets/scale_button.dart';

enum _PlanKind { monthly, yearly }

/// Google Play abonelik satın alma ekranı.
class PremiumPaywallScreen extends StatefulWidget {
  const PremiumPaywallScreen({super.key});

  @override
  State<PremiumPaywallScreen> createState() => _PremiumPaywallScreenState();
}

class _PremiumPaywallScreenState extends State<PremiumPaywallScreen> {
  final _billing = PlayBillingService.instance;
  final _promoController = TextEditingController();
  _PlanKind _selected = _PlanKind.yearly;
  bool _redeemingPromo = false;

  @override
  void initState() {
    super.initState();
    _billing.premiumNotifier.addListener(_onPremiumChanged);
    _billing.uiStateNotifier.addListener(_onUiStateChanged);
    _refreshProducts();
  }

  @override
  void dispose() {
    _promoController.dispose();
    _billing.premiumNotifier.removeListener(_onPremiumChanged);
    _billing.uiStateNotifier.removeListener(_onUiStateChanged);
    super.dispose();
  }

  Future<void> _refreshProducts() async {
    await _billing.queryProducts();
    if (mounted) setState(() {});
  }

  void _onPremiumChanged() {
    if (_billing.premiumNotifier.value && mounted) {
      Navigator.pop(context, true);
    }
  }

  void _onUiStateChanged() => setState(() {});

  ProductDetails? get _selectedProduct {
    return _selected == _PlanKind.yearly
        ? _billing.yearlyProduct
        : _billing.monthlyProduct;
  }

  IconData _iconFor(String name) {
    switch (name) {
      case 'offline':
        return Icons.offline_pin_outlined;
      case 'checklist':
        return Icons.checklist_rtl;
      case 'timer':
        return Icons.timer_outlined;
      case 'analytics':
        return Icons.analytics_outlined;
      case 'notebook':
        return Icons.note_alt_outlined;
      case 'task':
        return Icons.task_alt;
      case 'emoji_events':
        return Icons.emoji_events_outlined;
      case 'cloud':
        return Icons.cloud_outlined;
      case 'leaderboard':
        return Icons.leaderboard_outlined;
      default:
        return Icons.star_outline;
    }
  }

  bool get _isBusy {
    if (_redeemingPromo) return true;
    final state = _billing.uiStateNotifier.value;
    return state == BillingUiState.purchasing ||
        state == BillingUiState.restoring ||
        state == BillingUiState.loading;
  }

  Future<void> _redeemPromo() async {
    if (_redeemingPromo) return;
    setState(() => _redeemingPromo = true);
    try {
      final result =
          await PromoCodeService.instance.redeem(_promoController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
      if (result.success && PremiumService.instance.isPremium) {
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _redeemingPromo = false);
    }
  }

  Future<void> _subscribe() async {
    if (AuthService.instance.isAnonymous) {
      final linked = await AccountLinkCard.prompt(
        context,
        title: 'Premium için giriş yap',
        subtitle:
            'Aboneliğini kaybetmemek için Google hesabını bağla, ardından satın al.',
      );
      if (!linked || !mounted) return;
    }

    var product = _selectedProduct;
    if (product == null) {
      await _refreshProducts();
      product = _selectedProduct;
    }
    if (!mounted) return;

    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _billing.isStoreAvailable
                ? 'Plan fiyatı Play Store’dan alınamadı. '
                    'Daha sonra tekrar deneyin.'
                : (_billing.lastError ??
                    'Google Play Store bağlantısı kurulamadı.'),
          ),
        ),
      );
      return;
    }

    await _billing.purchase(product);
  }

  @override
  Widget build(BuildContext context) {
    final monthly = _billing.monthlyProduct;
    final yearly = _billing.yearlyProduct;
    final loading =
        _billing.uiStateNotifier.value == BillingUiState.loading;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _isBusy ? null : () => Navigator.pop(context, false),
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    ListenableBuilder(
                      listenable: Listenable.merge([
                        UserSavingsInsightService.instance,
                        ContentBankService.instance,
                        DailyMiniExamService.instance,
                        _billing.uiStateNotifier,
                      ]),
                      builder: (context, _) {
                        final headline =
                            UserSavingsInsightService.instance.paywallHeadline(
                          monthlyPriceLabel: UserSavingsInsightService
                              .instance
                              .monthlyPriceLabelForPaywall,
                        );
                        return Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 20),
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                AppTheme.champagne.withValues(alpha: 0.22),
                                AppTheme.neonEdge.withValues(alpha: 0.1),
                              ],
                            ),
                            border: Border.all(
                              color: AppTheme.champagne.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                headline,
                                style: GoogleFonts.inter(
                                  fontSize: 14,
                                  height: 1.45,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.lightPrimary,
                                ),
                              ),
                              if (DailyMiniExamService.instance
                                      .pdfUpsellMessage(isPremium: false) !=
                                  null) ...[
                                const SizedBox(height: 10),
                                Text(
                                  DailyMiniExamService.instance
                                      .pdfUpsellMessage(isPremium: false)!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13,
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.lightPrimary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),
                    const Icon(Icons.workspace_premium,
                        size: 64, color: AppTheme.lightAccent),
                    const SizedBox(height: 16),
                    Text(
                      '${BrandConstants.appName} Premium',
                      style: GoogleFonts.inter(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.lightPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Google Play üzerinden güvenli abonelik',
                      style: GoogleFonts.inter(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 32),
                    ...PremiumService.features.map(
                      (f) => _FeatureRow(
                        icon: _iconFor(f.iconName),
                        title: f.title,
                        description: f.description,
                        yearlyOnly: f.yearlyOnly,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Paket planları',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.lightPrimary,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (!_billing.isStoreAvailable)
                      _ErrorBanner(
                        message: _billing.lastError ??
                            'Google Play Store bağlantısı kurulamadı.',
                      )
                    else if (_billing.lastError != null &&
                        _billing.uiStateNotifier.value == BillingUiState.error)
                      _ErrorBanner(message: _billing.lastError!),
                    _PlanCard(
                      title: '1 aylık abonelik',
                      subtitle: _monthlySubtitle(monthly),
                      price: _monthlyPrice(monthly),
                      priceCaption: _monthlyCaption(monthly),
                      badge: 'İlk ay indirimli',
                      selected: _selected == _PlanKind.monthly,
                      loading: loading && monthly == null,
                      onTap: () => setState(() => _selected = _PlanKind.monthly),
                    ),
                    const SizedBox(height: 12),
                    _PlanCard(
                      title: '1 yıllık abonelik',
                      subtitle: _yearlySubtitle(yearly),
                      price: _yearlyPrice(yearly),
                      priceCaption: 'yıllık · otomatik yenilenir',
                      badge: 'Offline paket dahil',
                      selected: _selected == _PlanKind.yearly,
                      loading: loading && yearly == null,
                      onTap: () => setState(() => _selected = _PlanKind.yearly),
                    ),
                    if (monthly == null && yearly == null && !loading) ...[
                      const SizedBox(height: 10),
                      Text(
                        'Gösterilen tutarlar referans fiyattır. '
                        'Ödeme anında Google Play kesin tutarı gösterir.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.5),
                        ),
                      ),
                    ],
                    if (!PremiumService.instance.isPremium &&
                        AuthService.instance.hasBackendSession) ...[
                      const SizedBox(height: 20),
                      _PromoCodeSection(
                        controller: _promoController,
                        busy: _isBusy,
                        onRedeem: _redeemPromo,
                      ),
                    ],
                    const SizedBox(height: 24),
                    ScaleButton(
                      onPressed: _isBusy ? null : _subscribe,
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _isBusy ? null : _subscribe,
                          child: _isBusy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  _selected == _PlanKind.monthly
                                      ? 'Aylık plana abone ol'
                                      : 'Yıllık plana abone ol',
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed:
                          _isBusy ? null : () => _billing.restorePurchases(),
                      child: const Text('Satın Alımları Geri Yükle'),
                    ),
                    TextButton(
                      onPressed:
                          _isBusy ? null : () => Navigator.pop(context, false),
                      child: const Text('Daha sonra'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Abonelik otomatik yenilenir. İstediğiniz zaman Google Play '
                      '→ Abonelikler üzerinden iptal edebilirsiniz.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.45),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _monthlyPrice(ProductDetails? product) {
    final intro = _introPhase(product);
    if (intro != null) return intro.formattedPrice;
    if (product != null) return product.price;
    return IapConstants.monthlyIntroFallbackPrice;
  }

  String _monthlyCaption(ProductDetails? product) {
    final regular = _regularPhase(product);
    if (regular != null) {
      return 'ilk ay · sonra ${regular.formattedPrice}/ay';
    }
    if (product != null) return 'aylık · otomatik yenilenir';
    return 'ilk ay · sonra ${IapConstants.monthlyFallbackPrice}/ay';
  }

  String _monthlySubtitle(ProductDetails? product) {
    final intro = _introPhase(product);
    if (intro != null) {
      return 'İlk dönem indirimli, ardından normal aylık ücret';
    }
    return 'İlk ay indirimli başlangıç, sonra aylık yenilenir';
  }

  String _yearlyPrice(ProductDetails? product) {
    if (product != null) return product.price;
    return IapConstants.yearlyFallbackPrice;
  }

  String _yearlySubtitle(ProductDetails? product) {
    if (product != null) {
      return 'En avantajlı paket · offline kütüphane dahil';
    }
    return 'En avantajlı paket · offline kütüphane dahil';
  }

  PricingPhaseWrapper? _introPhase(ProductDetails? product) {
    final phases = _pricingPhases(product);
    if (phases == null || phases.length < 2) return null;
    if (phases.first.priceAmountMicros < phases[1].priceAmountMicros) {
      return phases.first;
    }
    return null;
  }

  PricingPhaseWrapper? _regularPhase(ProductDetails? product) {
    final phases = _pricingPhases(product);
    if (phases == null || phases.isEmpty) return null;
    if (phases.length >= 2 &&
        phases.first.priceAmountMicros < phases[1].priceAmountMicros) {
      return phases[1];
    }
    return phases.first;
  }

  List<PricingPhaseWrapper>? _pricingPhases(ProductDetails? product) {
    if (product is! GooglePlayProductDetails) return null;
    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return null;
    return offers[index].pricingPhases;
  }
}

class _PlanCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String price;
  final String priceCaption;
  final String? badge;
  final bool selected;
  final bool loading;
  final VoidCallback onTap;

  const _PlanCard({
    required this.title,
    required this.subtitle,
    required this.price,
    required this.priceCaption,
    this.badge,
    required this.selected,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.lightPrimary.withValues(alpha: 0.08)
          : Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(AppTheme.borderRadius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            border: Border.all(
              color: selected ? AppTheme.lightPrimary : AppTheme.lightAccent,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppTheme.lightPrimary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.lightAccent,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              badge!,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.6),
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (loading)
                      const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else ...[
                      Text(
                        price,
                        style: GoogleFonts.inter(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.lightPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        priceCaption,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
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

class _PromoCodeSection extends StatelessWidget {
  final TextEditingController controller;
  final bool busy;
  final VoidCallback onRedeem;

  const _PromoCodeSection({
    required this.controller,
    required this.busy,
    required this.onRedeem,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AppTheme.champagne.withValues(alpha: 0.08),
        border: Border.all(
          color: AppTheme.champagne.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Promosyon kodun var mı?',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppTheme.lightPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: 'Kodu gir',
                    isDense: true,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: busy ? null : onRedeem,
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.ink,
                  foregroundColor: AppTheme.champagneLight,
                  minimumSize: const Size(88, 44),
                ),
                child: const Text('Uygula'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Text(message, style: GoogleFonts.inter(fontSize: 13)),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool yearlyOnly;

  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.description,
    this.yearlyOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppTheme.lightPrimary.withValues(alpha: 0.1),
            child: Icon(icon, size: 20, color: AppTheme.lightPrimary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                    if (yearlyOnly) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.champagne.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'YILLIK',
                          style: GoogleFonts.inter(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.champagne,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  description,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
