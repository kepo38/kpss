import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ad_manager.dart';
import 'database_service.dart';
import 'iap_constants.dart';
import 'premium_sync_service.dart';

enum BillingUiState { idle, loading, purchasing, restoring, error }

/// Google Play Store uygulama içi satın alma servisi (Android).
class PlayBillingService {
  PlayBillingService._();
  static final PlayBillingService instance = PlayBillingService._();

  final InAppPurchase _iap = InAppPurchase.instance;

  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  final ValueNotifier<bool> premiumNotifier = ValueNotifier(false);
  final ValueNotifier<int> packOwnershipRevision = ValueNotifier(0);
  final ValueNotifier<BillingUiState> uiStateNotifier =
      ValueNotifier(BillingUiState.idle);

  List<ProductDetails> _products = [];
  List<ProductDetails> _packProducts = [];
  Set<String> _packProductIds = {};
  Set<String> _ownedPackProductIds = {};
  String? _lastError;
  String? _activeProductId;
  bool _storeAvailable = false;
  Future<void>? _hydrateCachedPremiumFuture;

  List<ProductDetails> get products => List.unmodifiable(_products);
  List<ProductDetails> get packProducts => List.unmodifiable(_packProducts);
  Set<String> get ownedPackProductIds => Set.unmodifiable(_ownedPackProductIds);
  bool get isStoreAvailable => _storeAvailable;
  String? get lastError => _lastError;
  String? get activeProductId => _activeProductId;
  bool get isYearlyPremium =>
      premiumNotifier.value &&
      _activeProductId == IapConstants.yearlySubscriptionId;

  ProductDetails? get monthlyProduct =>
      _bestOfferFor(IapConstants.monthlySubscriptionId);
  ProductDetails? get yearlyProduct =>
      _bestOfferFor(IapConstants.yearlySubscriptionId);

  /// Aynı product ID için birden fazla offer gelebilir; indirimli / intro
  /// fazı olanı tercih et.
  ProductDetails? _bestOfferFor(String id) {
    final matches = _products.where((p) => p.id == id).toList();
    if (matches.isEmpty) return null;

    for (final product in matches) {
      if (_hasIntroductoryPhase(product)) return product;
    }
    return matches.first;
  }

  bool _hasIntroductoryPhase(ProductDetails product) {
    if (product is! GooglePlayProductDetails) return false;
    final index = product.subscriptionIndex;
    final offers = product.productDetails.subscriptionOfferDetails;
    if (index == null || offers == null || index >= offers.length) return false;
    final phases = offers[index].pricingPhases;
    return phases.length >= 2 &&
        phases.first.priceAmountMicros < phases[1].priceAmountMicros;
  }

  /// Play Store'a gitmeden yerel Premium önbelleğini yükler (VPN kapısı).
  Future<void> hydrateCachedPremium() {
    if (kIsWeb) return Future.value();
    return _hydrateCachedPremiumFuture ??= _loadCachedPremium();
  }

  Future<void> initialize() async {
    if (kIsWeb) return;

    await hydrateCachedPremium();
    await _loadOwnedPacks();

    _storeAvailable = await _iap.isAvailable();
    if (!_storeAvailable) {
      _lastError = 'Google Play Store kullanılamıyor.';
      return;
    }

    _purchaseSub?.cancel();
    _purchaseSub = _iap.purchaseStream.listen(
      _handlePurchaseUpdates,
      onError: (Object e) {
        _lastError = e.toString();
        uiStateNotifier.value = BillingUiState.error;
      },
    );

    await queryProducts();
    await restorePurchases(silent: true);
  }

  Future<void> queryProducts() async {
    if (!_storeAvailable) return;

    uiStateNotifier.value = BillingUiState.loading;
    _lastError = null;

    final response =
        await _iap.queryProductDetails(IapConstants.subscriptionIds);

    if (response.error != null) {
      _lastError = response.error!.message;
      uiStateNotifier.value = BillingUiState.error;
      return;
    }

    if (response.notFoundIDs.isNotEmpty && kDebugMode) {
      _lastError =
          'Play Console\'da tanımlanmamış ürünler: ${response.notFoundIDs.join(', ')}';
    }

    _products = response.productDetails;
    await _queryPackProducts();
    uiStateNotifier.value = BillingUiState.idle;
  }

  Future<void> syncPackProductIds(Iterable<String> ids) async {
    _packProductIds = ids.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet();
    if (_storeAvailable) {
      await _queryPackProducts();
    }
  }

  Future<void> _queryPackProducts() async {
    if (!_storeAvailable || _packProductIds.isEmpty) {
      _packProducts = [];
      return;
    }
    final response = await _iap.queryProductDetails(_packProductIds);
    _packProducts = response.productDetails;
  }

  bool ownsPackProduct(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return false;
    return _ownedPackProductIds.contains(id);
  }

  String? priceForPackProduct(String productId) {
    final id = productId.trim();
    if (id.isEmpty) return null;
    for (final product in _packProducts) {
      if (product.id == id) return product.price;
    }
    return null;
  }

  ProductDetails? packProduct(String productId) {
    final id = productId.trim();
    for (final product in _packProducts) {
      if (product.id == id) return product;
    }
    return null;
  }

  Future<bool> purchasePack(String productId) async {
    final product = packProduct(productId);
    if (product == null) {
      _lastError = 'Paket mağazada bulunamadı.';
      return false;
    }
    return purchase(product);
  }

  Future<bool> purchase(ProductDetails product) async {
    if (!_storeAvailable) {
      _lastError = 'Mağaza kullanılamıyor.';
      return false;
    }

    uiStateNotifier.value = BillingUiState.purchasing;
    _lastError = null;

    late PurchaseParam param;
    if (defaultTargetPlatform == TargetPlatform.android &&
        product is GooglePlayProductDetails) {
      param = GooglePlayPurchaseParam(productDetails: product);
    } else {
      param = PurchaseParam(productDetails: product);
    }

    try {
      final started = await _iap.buyNonConsumable(purchaseParam: param);
      if (!started) {
        _lastError = 'Satın alma başlatılamadı.';
        uiStateNotifier.value = BillingUiState.error;
      }
      return started;
    } catch (e) {
      _lastError = e.toString();
      uiStateNotifier.value = BillingUiState.error;
      return false;
    }
  }

  Future<void> restorePurchases({bool silent = false}) async {
    if (!_storeAvailable) return;

    if (!silent) uiStateNotifier.value = BillingUiState.restoring;
    _lastError = null;

    try {
      await _iap.restorePurchases();
      if (!silent) uiStateNotifier.value = BillingUiState.idle;
    } catch (e) {
      _lastError = e.toString();
      uiStateNotifier.value = BillingUiState.error;
    }
  }

  Future<void> _handlePurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.pending:
          uiStateNotifier.value = BillingUiState.purchasing;
          break;
        case PurchaseStatus.error:
          _lastError = purchase.error?.message ?? 'Satın alma hatası';
          uiStateNotifier.value = BillingUiState.error;
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (IapConstants.subscriptionIds.contains(purchase.productID)) {
            await _grantPremium(purchase);
          } else if (_packProductIds.contains(purchase.productID)) {
            await _grantPackOwnership(purchase.productID);
          }
          uiStateNotifier.value = BillingUiState.idle;
          break;
        case PurchaseStatus.canceled:
          uiStateNotifier.value = BillingUiState.idle;
          break;
      }

      if (purchase.pendingCompletePurchase) {
        await _iap.completePurchase(purchase);
      }
    }
  }

  Future<void> _grantPremium(PurchaseDetails purchase) async {
    final productId = purchase.productID;
    if (!IapConstants.subscriptionIds.contains(productId)) return;

    // Production: purchase.verificationData.serverVerificationData
    // backend'de Google Play Developer API ile doğrulanmalıdır.
    final expiry = _estimateExpiry(productId);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(IapConstants.premiumPrefsKey, true);
    await prefs.setString(IapConstants.premiumProductPrefsKey, productId);
    await prefs.setString(
      IapConstants.premiumExpiryPrefsKey,
      expiry.toIso8601String(),
    );

    _applyPremiumState(true, productId: productId, expiry: expiry);
    unawaited(
      PremiumSyncService.instance.syncToBackend(
        isPremium: true,
        productId: productId,
        expiresAt: expiry,
      ),
    );
  }

  Future<void> _grantPackOwnership(String productId) async {
    _ownedPackProductIds.add(productId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      IapConstants.ownedPackProductsPrefsKey,
      _ownedPackProductIds.toList(),
    );
    packOwnershipRevision.value++;
  }

  Future<void> _loadOwnedPacks() async {
    final prefs = await SharedPreferences.getInstance();
    _ownedPackProductIds =
        prefs.getStringList(IapConstants.ownedPackProductsPrefsKey)?.toSet() ??
            {};
  }

  DateTime _estimateExpiry(String productId) {
    final now = DateTime.now();
    if (productId == IapConstants.yearlySubscriptionId) {
      return now.add(const Duration(days: 365));
    }
    return now.add(const Duration(days: 30));
  }

  Future<void> _loadCachedPremium() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(IapConstants.premiumPrefsKey) ?? false;
    if (!active) return;

    final expiryStr = prefs.getString(IapConstants.premiumExpiryPrefsKey);
    if (expiryStr != null) {
      final expiry = DateTime.tryParse(expiryStr);
      if (expiry != null && expiry.isBefore(DateTime.now())) {
        await _revokePremium();
        return;
      }
    }

    final productId = prefs.getString(IapConstants.premiumProductPrefsKey);
    _applyPremiumState(true, productId: productId);
  }

  Future<void> _revokePremium() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(IapConstants.premiumPrefsKey);
    await prefs.remove(IapConstants.premiumProductPrefsKey);
    await prefs.remove(IapConstants.premiumExpiryPrefsKey);
    _applyPremiumState(false);
    unawaited(
      PremiumSyncService.instance.syncToBackend(
        isPremium: false,
        productId: '',
        expiresAt: null,
      ),
    );
  }

  void _applyPremiumState(
    bool isPremium, {
    String? productId,
    DateTime? expiry,
  }) {
    premiumNotifier.value = isPremium;
    _activeProductId = isPremium ? productId : null;

    final user = DatabaseService.instance.currentUser;
    if (user != null) {
      DatabaseService.instance.setCurrentUser(
        user.copyWith(
          isPremium: isPremium,
          premiumBitisTarihi: isPremium ? expiry : null,
        ),
      );
    }

    AdManager.instance.setPremium(isPremium);

    if (kDebugMode && isPremium) {
      debugPrint('Premium aktif: $productId');
    }
  }

  void shutdown() {
    _purchaseSub?.cancel();
  }
}
