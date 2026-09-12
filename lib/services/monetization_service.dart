import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonetizationService extends ChangeNotifier {
  static final MonetizationService instance = MonetizationService._internal();
  MonetizationService._internal();

  // In-App Product IDs
  static const String productRemoveAdsMonthly = 'zeropass_remove_ads_monthly'; // 광고 제거 월간 구독
  static const String productRemoveAdsLifetime = 'zeropass_remove_ads_lifetime'; // 광고 제거 평생 소장
  static const String productKioskLifetime = 'zeropass_kiosk_pro_lifetime'; // 키오스크 자율출결 평생 소장권

  static const String productIdRemoveAdsMonthly = productRemoveAdsMonthly;
  static const String productIdRemoveAdsLifetime = productRemoveAdsLifetime;
  static const String productIdKioskPro = productKioskLifetime;

  static const Set<String> _kProductIds = {
    productRemoveAdsMonthly,
    productRemoveAdsLifetime,
    productKioskLifetime,
  };

  bool _isAdsRemoved = false;
  bool _isKioskProUnlocked = false;
  bool get isAdsRemoved => _isAdsRemoved;
  bool get isKioskProUnlocked => _isKioskProUnlocked;

  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;

  final ValueNotifier<bool> premiumStatusNotifier = ValueNotifier<bool>(false);

  Future<void> debugUnlockAll() async {
    await setDebugUnlock(adsRemoved: true, kioskPro: true);
  }

  Future<void> setDebugUnlock({bool? adsRemoved, bool? kioskPro}) async {
    final prefs = await SharedPreferences.getInstance();
    if (adsRemoved != null) {
      _isAdsRemoved = adsRemoved;
      await prefs.setBool('is_ads_removed', adsRemoved);
      premiumStatusNotifier.value = adsRemoved;
    }
    if (kioskPro != null) {
      _isKioskProUnlocked = kioskPro;
      await prefs.setBool('is_kiosk_pro_unlocked', kioskPro);
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    _isAdsRemoved = prefs.getBool('is_ads_removed') ?? false;
    _isKioskProUnlocked = prefs.getBool('is_kiosk_pro_unlocked') ?? false;
    premiumStatusNotifier.value = _isAdsRemoved;

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await MobileAds.instance.initialize();
        if (!_isAdsRemoved) {
          _loadInterstitialAd();
        }
      } catch (e) {
        debugPrint('AdMob initialize error: $e');
      }

      // Initialize IAP listener
      try {
        final Stream<List<PurchaseDetails>> purchaseUpdated = InAppPurchase.instance.purchaseStream;
        purchaseUpdated.listen(_listenToPurchaseUpdated, onDone: () {}, onError: (error) {
          debugPrint('IAP purchaseStream error: $error');
        });
      } catch (e) {
        debugPrint('IAP initialize error: $e');
      }
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        _handleSuccessfulPurchase(purchaseDetails.productID);
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    if (productId == productRemoveAdsMonthly || productId == productRemoveAdsLifetime) {
      _isAdsRemoved = true;
      await prefs.setBool('is_ads_removed', true);
      premiumStatusNotifier.value = true;
    } else if (productId == productKioskLifetime) {
      _isKioskProUnlocked = true;
      await prefs.setBool('is_kiosk_pro_unlocked', true);
    }
  }

  /// Manually unlock for testing or promo code
  Future<void> setDebugUnlock({bool? removeAds, bool? kioskPro}) async {
    final prefs = await SharedPreferences.getInstance();
    if (removeAds != null) {
      _isAdsRemoved = removeAds;
      await prefs.setBool('is_ads_removed', removeAds);
      premiumStatusNotifier.value = removeAds;
    }
    if (kioskPro != null) {
      _isKioskProUnlocked = kioskPro;
      await prefs.setBool('is_kiosk_pro_unlocked', kioskPro);
    }
  }

  // AdMob Banner Unit ID (Google official sample test IDs)
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/6300978111'; // Android sample banner
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/2934735716'; // iOS sample banner
    }
    return '';
  }

  // AdMob Interstitial Unit ID (Google official sample test IDs)
  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712'; // Android sample interstitial
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910'; // iOS sample interstitial
    }
    return '';
  }

  void _loadInterstitialAd() {
    if (_isAdsRemoved || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
        },
        onAdFailedToLoad: (error) {
          _isInterstitialAdLoaded = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Show interstitial ad periodically (e.g. after bulk invoice creation or export)
  void showInterstitialAdIfReady() {
    if (_isAdsRemoved) return;
    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _loadInterstitialAd();
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _loadInterstitialAd();
        },
      );
      _interstitialAd!.show();
      _isInterstitialAdLoaded = false;
      _interstitialAd = null;
    } else {
      _loadInterstitialAd();
    }
  }

  /// Fetch IAP products from Google Play
  Future<List<ProductDetails>> fetchProducts() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) return [];

    final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(_kProductIds);
    return response.productDetails;
  }

  /// Buy a product by string ID
  Future<void> buyProduct(String productId) async {
    try {
      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        debugPrint('In-App Purchase not available');
        return;
      }
      final response = await InAppPurchase.instance.queryProductDetails({productId});
      if (response.productDetails.isNotEmpty) {
        final product = response.productDetails.first;
        final purchaseParam = PurchaseParam(productDetails: product);
        await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        debugPrint('Product not found: $productId');
      }
    } catch (e) {
      debugPrint('buyProduct error: $e');
    }
  }

  /// Restore purchases
  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
  }
}
