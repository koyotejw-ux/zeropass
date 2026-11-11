import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../screens/pro_store_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/responsive_dialog_actions.dart';

/// 개별 스토어 상품 및 기간제 이용권의 현재 상태
enum ProductPurchaseState {
  notOwned,
  pending,
  active,
  coveredByVip,
  expired,
}

/// 스토어 결제 / 복원 / 만료 이벤트 유형
enum StoreEventType {
  none,
  purchased,
  pending,
  restored,
  expired,
  canceled,
  error,
}

/// 구독 또는 기간제 일회성 상품의 이용 권한(Entitlement) 기록
class PurchasedEntitlement {
  final String productId;
  final DateTime purchasedAt;
  final DateTime expiresAt;
  final bool isSubscription;
  final bool isRestored;

  const PurchasedEntitlement({
    required this.productId,
    required this.purchasedAt,
    required this.expiresAt,
    required this.isSubscription,
    this.isRestored = false,
  });

  bool isActiveAt(DateTime now) => now.isBefore(expiresAt);

  Duration remainingAt(DateTime now) =>
      isActiveAt(now) ? expiresAt.difference(now) : Duration.zero;

  Map<String, dynamic> toJson() => {
        'productId': productId,
        'purchasedAt': purchasedAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'isSubscription': isSubscription,
        'isRestored': isRestored,
      };

  factory PurchasedEntitlement.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return PurchasedEntitlement(
      productId: json['productId'] as String? ?? '',
      purchasedAt: DateTime.tryParse(json['purchasedAt'] as String? ?? '') ?? now,
      expiresAt: DateTime.tryParse(json['expiresAt'] as String? ?? '') ?? now,
      isSubscription: json['isSubscription'] as bool? ?? true,
      isRestored: json['isRestored'] as bool? ?? false,
    );
  }
}

/// 최고 수익률(High eCPM)을 위한 AdMob 전면/오프닝/보상형/배너 통합 관리 서비스
class MonetizationService extends ChangeNotifier with WidgetsBindingObserver {
  static final MonetizationService instance = MonetizationService._internal();
  MonetizationService._internal();

  // In-App Product IDs (100% Recurring Subscriptions + Period Pass)
  static const String productSubRemoveAdsMonthly = 'zeropass_sub_ads_monthly'; // 광고 제거 월간 (₩1,900/월)
  static const String productSubKioskMonthly = 'zeropass_sub_kiosk_monthly'; // 태블릿 키오스크 월간 (₩4,900/월)
  static const String productSubAllInOneMonthly = 'zeropass_sub_vip_monthly'; // 올인원 VIP 패키지 월간 (₩5,900/월)
  static const String productSubAllInOneYearly = 'zeropass_sub_vip_yearly'; // 올인원 VIP 패키지 연간 (₩59,000/년)
  static const String productPassTemporaryVip1h = 'zeropass_pass_temp_vip_1h'; // 1시간 기간제 무료 VIP 체험 패스

  static const String productIdRemoveAdsMonthly = productSubRemoveAdsMonthly;
  static const String productIdKioskMonthly = productSubKioskMonthly;
  static const String productIdAllInOneMonthly = productSubAllInOneMonthly;
  static const String productIdAllInOneYearly = productSubAllInOneYearly;

  static const Set<String> _kProductIds = {
    productSubRemoveAdsMonthly,
    productSubKioskMonthly,
    productSubAllInOneMonthly,
    productSubAllInOneYearly,
  };

  // 실서비스 발급 애드몹 광고 단위 ID
  static const String _adMobAppOpenId = 'ca-app-pub-1377047377548020/4836032810';
  static const String _adMobBannerId = 'ca-app-pub-1377047377548020/4097666213';
  static const String _adMobInterstitialId = 'ca-app-pub-1377047377548020/8371953140';
  static const String _adMobRewardedId = 'ca-app-pub-1377047377548020/6149114482';
  static const String _adMobRewardedInterstitialId = 'ca-app-pub-1377047377548020/8921697616';
  static const String _adMobNativeId = 'ca-app-pub-1377047377548020/9883425494';

  // 구글 공식 테스트 단위 ID (디버그 모드용)
  static const String _testBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _testInterstitialId = 'ca-app-pub-3940256099942544/1033173712';
  static const String _testAppOpenId = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testRewardedId = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedInterstitialId = 'ca-app-pub-3940256099942544/5354046379';
  static const String _testNativeId = 'ca-app-pub-3940256099942544/2247696110';

  static const String _prefsEntitlementsKey = 'bm_entitlements_v2';

  bool _isAdsRemoved = false;
  bool _isKioskProUnlocked = false;
  bool _isDebugUnlocked = false;
  DateTime? _rewardedAdFreeUntil;
  DateTime? _rewardedKioskPassUntil;

  final Map<String, PurchasedEntitlement> _entitlements = {};
  final Set<String> _expiredNotifiedProductIds = {};
  final Set<String> _restoreSessionProductIds = {};
  String? _pendingPurchaseProductId;
  bool _isRestoringPurchases = false;
  StoreEventType _lastStoreEventType = StoreEventType.none;
  String? _lastStoreNotice;
  final Map<String, ProductDetails> _storeProducts = {};
  bool _storeProductsChecked = false;
  String? _storeQueryError;

  // 선순환 리텐션 & 누적 ROI 가치 측정 지표 (Retention Flywheel Metrics)
  int _activeStreakDays = 1;
  String? _lastActiveDateStr;
  int _cumulativeSavedSmsCount = 128; // 안심 문자/청구서 발송 누적 건수 (기본 시드 + 실사용 누적)
  int _cumulativeCheckInCount = 342; // 누적 출결 처리 건수
  int _cumulativeTaxLedgerCount = 18; // 누적 세무/정산 자동화 건수

  String? get pendingProductId => _pendingPurchaseProductId;
  bool get isRestoringPurchases => _isRestoringPurchases;
  StoreEventType get lastStoreEventType => _lastStoreEventType;
  String? get lastStoreNotice => _lastStoreNotice;
  bool get hasStoreProductsChecked => _storeProductsChecked;
  bool get hasStoreProductsLoaded => _storeProducts.isNotEmpty;
  String? get storeQueryError => _storeQueryError;
  ProductDetails? getStoreProduct(String productId) => _storeProducts[productId];
  List<PurchasedEntitlement> get activeEntitlements {
    final now = DateTime.now();
    return _entitlements.values.where((e) => e.isActiveAt(now)).toList();
  }

  /// 상품별 기본 이용 기간 (정기 구독 30일/365일, 기간제 체험 1시간)
  Duration periodDurationForProduct(String productId) {
    if (productId == productSubAllInOneYearly) return const Duration(days: 365);
    if (productId == productPassTemporaryVip1h) return const Duration(hours: 1);
    return const Duration(days: 30);
  }

  /// 상품 ID에 대응하는 표시 이름
  String productDisplayName(String productId) {
    switch (productId) {
      case productSubRemoveAdsMonthly:
        return '광고 제거 단독 (월간)';
      case productSubKioskMonthly:
        return '태블릿 키오스크 (월간)';
      case productSubAllInOneMonthly:
        return '올인원 VIP (월간)';
      case productSubAllInOneYearly:
        return '올인원 VIP (연간)';
      case productPassTemporaryVip1h:
        return '1시간 무료 VIP 체험';
      default:
        return productId;
    }
  }

  String formatShortDate(DateTime dt) {
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  PurchasedEntitlement? getEntitlement(String productId) => _entitlements[productId];

  bool _hasActiveVipBundle(DateTime now) {
    final monthly = _entitlements[productSubAllInOneMonthly];
    final yearly = _entitlements[productSubAllInOneYearly];
    return (monthly != null && monthly.isActiveAt(now)) ||
        (yearly != null && yearly.isActiveAt(now));
  }

  /// 개별 상품 및 기간제 이용권의 현재 상태 조회
  ProductPurchaseState getProductState(String productId, {DateTime? now}) {
    final checkNow = now ?? DateTime.now();
    if (_pendingPurchaseProductId == productId) {
      return ProductPurchaseState.pending;
    }
    final ent = _entitlements[productId];
    if (ent != null && ent.isActiveAt(checkNow)) {
      return ProductPurchaseState.active;
    }
    if (productId == productSubAllInOneMonthly) {
      final yearly = _entitlements[productSubAllInOneYearly];
      if (yearly != null && yearly.isActiveAt(checkNow)) {
        return ProductPurchaseState.coveredByVip;
      }
    }
    if (productId == productSubRemoveAdsMonthly ||
        productId == productSubKioskMonthly ||
        productId == productPassTemporaryVip1h) {
      if (_hasActiveVipBundle(checkNow)) {
        return ProductPurchaseState.coveredByVip;
      }
      if (productId == productPassTemporaryVip1h && _isAdsRemoved && _isKioskProUnlocked) {
        return ProductPurchaseState.coveredByVip;
      }
    }
    if (productId == productPassTemporaryVip1h) {
      if ((_rewardedAdFreeUntil != null && checkNow.isBefore(_rewardedAdFreeUntil!)) ||
          (_rewardedKioskPassUntil != null && checkNow.isBefore(_rewardedKioskPassUntil!))) {
        return ProductPurchaseState.active;
      }
      if (ent != null || _rewardedAdFreeUntil != null || _rewardedKioskPassUntil != null) {
        return ProductPurchaseState.expired;
      }
      return ProductPurchaseState.notOwned;
    }
    if (ent != null && !ent.isActiveAt(checkNow)) {
      return ProductPurchaseState.expired;
    }
    return ProductPurchaseState.notOwned;
  }

  /// 활성 이용 권한(또는 상위 VIP 번들)의 만료 시각 반환
  DateTime? getProductExpiry(String productId, {DateTime? now}) {
    final checkNow = now ?? DateTime.now();
    final state = getProductState(productId, now: checkNow);
    if (state == ProductPurchaseState.active) {
      if (productId == productPassTemporaryVip1h) {
        return _entitlements[productId]?.expiresAt ?? _rewardedAdFreeUntil ?? _rewardedKioskPassUntil;
      }
      return _entitlements[productId]?.expiresAt;
    }
    if (state == ProductPurchaseState.coveredByVip) {
      final yearly = _entitlements[productSubAllInOneYearly];
      if (yearly != null && yearly.isActiveAt(checkNow)) return yearly.expiresAt;
      final monthly = _entitlements[productSubAllInOneMonthly];
      if (monthly != null && monthly.isActiveAt(checkNow)) return monthly.expiresAt;
    }
    return _entitlements[productId]?.expiresAt;
  }

  bool isProductActive(String productId, {DateTime? now}) {
    final state = getProductState(productId, now: now);
    return state == ProductPurchaseState.active || state == ProductPurchaseState.coveredByVip;
  }

  bool canPurchaseProduct(String productId, {DateTime? now}) {
    if (_pendingPurchaseProductId != null) return false;
    return !isProductActive(productId, now: now);
  }

  bool get canClaimTemporaryPass {
    if (_pendingPurchaseProductId == productPassTemporaryVip1h) return false;
    if (isPermanentVip) return false;
    return !isTemporaryPassActive;
  }

  bool get _hasTrackedAdsEntitlement =>
      _entitlements.containsKey(productSubRemoveAdsMonthly) ||
      _entitlements.containsKey(productSubAllInOneMonthly) ||
      _entitlements.containsKey(productSubAllInOneYearly);

  bool get _hasTrackedKioskEntitlement =>
      _entitlements.containsKey(productSubKioskMonthly) ||
      _entitlements.containsKey(productSubAllInOneMonthly) ||
      _entitlements.containsKey(productSubAllInOneYearly);

  bool get isSubscriptionAdsRemoved {
    final now = DateTime.now();
    if (isProductActive(productSubRemoveAdsMonthly, now: now) || _hasActiveVipBundle(now)) {
      return true;
    }
    return !_hasTrackedAdsEntitlement && _isAdsRemoved;
  }

  bool get isSubscriptionKioskPro {
    final now = DateTime.now();
    if (isProductActive(productSubKioskMonthly, now: now) || _hasActiveVipBundle(now)) {
      return true;
    }
    return !_hasTrackedKioskEntitlement && _isKioskProUnlocked;
  }

  bool get isSubscriptionAllInOne =>
      _hasActiveVipBundle(DateTime.now()) || (isSubscriptionAdsRemoved && isSubscriptionKioskPro);

  bool get isAdsRemoved {
    if (isSubscriptionAdsRemoved) return true;
    if (_rewardedAdFreeUntil != null && DateTime.now().isBefore(_rewardedAdFreeUntil!)) {
      return true;
    }
    return false;
  }

  bool get isKioskProUnlocked {
    if (isSubscriptionKioskPro) return true;
    if (_rewardedKioskPassUntil != null && DateTime.now().isBefore(_rewardedKioskPassUntil!)) {
      return true;
    }
    return false;
  }

  bool get isPermanentVip => isSubscriptionAdsRemoved && isSubscriptionKioskPro;

  /// 올인원 VIP 무제한 이용 가능 여부 (정기 구독 VIP 또는 1시간 무료 VIP 체험 패스 포함)
  bool get isUnlimitedVip => isPermanentVip || isTemporaryPassActive;

  /// 단일 기능 구독(광고 제거 단독 또는 키오스크 단독)만 활성화된 상태 여부 (비-VIP 제한 플랜)
  bool get isStandalonePaidPlan => !isUnlimitedVip && (isAdsRemoved || isKioskProUnlocked);

  String get membershipPlanLabel {
    if (isPermanentVip) return '올인원 VIP 멤버십 (무제한)';
    if (isTemporaryPassActive) return '1시간 VIP 무료 체험 (무제한)';
    if (isSubscriptionAdsRemoved) return '광고 제거 단독 (제한형)';
    if (isSubscriptionKioskPro) return '키오스크 단독 (제한형)';
    return '무료 플랜 (체험 한도)';
  }

  // 비-VIP 등록 개수 & 월 수정 횟수 한도 (-1 = 무제한)
  static const int freeMaxMembers = 10;
  static const int standaloneMaxMembers = 30;
  static const int freeMaxInvoices = 15;
  static const int standaloneMaxInvoices = 40;
  static const int freeMaxExpenses = 10;
  static const int standaloneMaxExpenses = 30;
  static const int freeMaxVendors = 5;
  static const int standaloneMaxVendors = 15;
  static const int freeMaxSchedules = 10;
  static const int standaloneMaxSchedules = 25;
  static const int freeMaxTemplates = 5;
  static const int standaloneMaxTemplates = 8;
  static const int freeMaxMonthlyEdits = 5;
  static const int standaloneMaxMonthlyEdits = 15;

  int get maxMemberLimit => isUnlimitedVip ? -1 : (isStandalonePaidPlan ? standaloneMaxMembers : freeMaxMembers);
  int get maxInvoiceLimit => isUnlimitedVip ? -1 : (isStandalonePaidPlan ? standaloneMaxInvoices : freeMaxInvoices);
  int get maxExpenseLimit => isUnlimitedVip ? -1 : (isStandalonePaidPlan ? standaloneMaxExpenses : freeMaxExpenses);
  int get maxVendorLimit => isUnlimitedVip ? -1 : (isStandalonePaidPlan ? standaloneMaxVendors : freeMaxVendors);
  int get maxScheduleLimit => isUnlimitedVip ? -1 : (isStandalonePaidPlan ? standaloneMaxSchedules : freeMaxSchedules);
  int get maxCustomTemplateLimit => isUnlimitedVip ? -1 : (isStandalonePaidPlan ? standaloneMaxTemplates : freeMaxTemplates);
  int get maxMonthlyEditLimit => isUnlimitedVip ? -1 : (isStandalonePaidPlan ? standaloneMaxMonthlyEdits : freeMaxMonthlyEdits);

  int _monthlyEditCount = 0;
  String _editCountMonthKey = '';

  int get usedMonthlyEditCount => _monthlyEditCount;
  int get remainingMonthlyEditCount {
    final limit = maxMonthlyEditLimit;
    if (limit < 0) return -1;
    return (limit - _monthlyEditCount).clamp(0, limit);
  }

  bool canCreateItem({required int currentCount, required int limit}) {
    if (limit < 0) return true;
    return currentCount < limit;
  }

  bool get canPerformEdit {
    final limit = maxMonthlyEditLimit;
    if (limit < 0) return true;
    return _monthlyEditCount < limit;
  }

  String _currentMonthKey() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  Future<void> _syncMonthlyEditCounter(SharedPreferences prefs) async {
    final nowKey = _currentMonthKey();
    final savedKey = prefs.getString('bm_monthly_edit_month') ?? '';
    if (savedKey != nowKey) {
      _monthlyEditCount = 0;
      _editCountMonthKey = nowKey;
      await prefs.setString('bm_monthly_edit_month', nowKey);
      await prefs.setInt('bm_monthly_edit_count', 0);
    } else {
      _editCountMonthKey = savedKey;
      _monthlyEditCount = prefs.getInt('bm_monthly_edit_count') ?? 0;
    }
  }

  Future<void> recordEditUsage() async {
    if (isUnlimitedVip) return;
    final prefs = await SharedPreferences.getInstance();
    final nowKey = _currentMonthKey();
    if (_editCountMonthKey != nowKey) {
      _monthlyEditCount = 0;
      _editCountMonthKey = nowKey;
      await prefs.setString('bm_monthly_edit_month', nowKey);
    }
    _monthlyEditCount++;
    await prefs.setInt('bm_monthly_edit_count', _monthlyEditCount);
    notifyListeners();
  }

  bool get isTemporaryPassActive =>
      (!_isAdsRemoved && _rewardedAdFreeUntil != null && DateTime.now().isBefore(_rewardedAdFreeUntil!)) ||
      (!_isKioskProUnlocked && _rewardedKioskPassUntil != null && DateTime.now().isBefore(_rewardedKioskPassUntil!));

  Duration get remainingTemporaryPassDuration {
    final now = DateTime.now();
    DateTime? latest;
    if (_rewardedAdFreeUntil != null && now.isBefore(_rewardedAdFreeUntil!)) {
      latest = _rewardedAdFreeUntil;
    }
    if (_rewardedKioskPassUntil != null && now.isBefore(_rewardedKioskPassUntil!)) {
      if (latest == null || _rewardedKioskPassUntil!.isAfter(latest)) {
        latest = _rewardedKioskPassUntil;
      }
    }
    if (latest == null) return Duration.zero;
    return latest.difference(now);
  }

  /// 보상형 패스 잔여 시간 포맷 (1시간 기준 분/시간 단위 자동 표기)
  String get remainingTemporaryPassFormatted {
    final d = remainingTemporaryPassDuration;
    if (d.inHours >= 1) {
      final mins = d.inMinutes % 60;
      return mins > 0 ? '${d.inHours}시간 $mins분 남음' : '${d.inHours}시간 남음';
    }
    final mins = d.inMinutes.clamp(1, 60);
    return '$mins분 남음';
  }

  int get activeStreakDays => _activeStreakDays;
  int get cumulativeSavedSmsCount => _cumulativeSavedSmsCount;
  int get cumulativeCheckInCount => _cumulativeCheckInCount;
  int get cumulativeTaxLedgerCount => _cumulativeTaxLedgerCount;

  /// 원장님이 체크앤페이를 통해 절감한 누적 경제적 가치(원)
  /// - 건당 알림톡/장문 문자 비용 25원 절감 + 타사 키오스크/ERP 기본료 월 35,000원 절감 효과 환산
  int get estimatedTotalSavedKRW =>
      (_cumulativeSavedSmsCount * 25) + (_cumulativeCheckInCount * 15) + 35000;

  /// 매장 운영 등급 (습관화 리텐션 배지)
  String get retentionTierTitle {
    if (isPermanentVip) return '로열 VIP 마스터';
    if (_activeStreakDays >= 14) return '골든 마스터';
    if (_activeStreakDays >= 3) return '스마트 케어 파트너';
    return '스타트업 파트너';
  }

  // 루트 네비게이터 키 (전역 CRUD 광고 종료 후 구독 전환 팝업 노출용)
  static final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

  static const double defaultCrudAdProbability = 0.45; // CRUD 1회당 45% 확률로 전면 광고 노출
  static const int defaultCrudCooldownSeconds = 18; // 연속 작업 시 최소 18초 쿨다운

  // 광고 객체 및 로드 상태
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdLoaded = false;
  DateTime? _lastInterstitialShownTime;
  DateTime? _lastUpsellDialogShownTime;
  bool _isShowingUpsellDialog = false;
  int _actionCounter = 0; // 스마트 빈도 조절용 액션 카운터
  int _crudAdExposureCount = 0; // 이번 세션 CRUD 광고/업셀 노출 횟수
  final Random _random = Random();

  @visibleForTesting
  bool allowCrudAdInTests = false;
  @visibleForTesting
  void Function(String actionLabel)? onTestInterstitialTriggered;
  @visibleForTesting
  void Function(String actionLabel)? onTestUpsellTriggered;

  int get crudAdExposureCount => _crudAdExposureCount;

  AppOpenAd? _appOpenAd;
  bool _isAppOpenAdLoaded = false;
  bool _isShowingAppOpenAd = false;
  DateTime? _appOpenAdLoadTime;
  DateTime? _lastAppOpenShownTime;
  DateTime? _externalIntentSuppressedUntil; // 문자/카톡/공유 외부 인텐트 복귀 시 전면/오프닝 광고 차단 보호막

  /// 외부 앱(문자 SMS, 카카오톡 공유, 토스/은행 링크, 엑셀 파일 공유 등)을 열기 직전 호출하여
  /// 원장님이 다시 앱으로 돌아왔을 때 전체화면 오프닝 광고가 업무 맥락을 끊지 않도록 보호합니다.
  void suppressAppOpenAdTemporarily({int seconds = 45}) {
    _externalIntentSuppressedUntil = DateTime.now().add(Duration(seconds: seconds));
  }

  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;

  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isRewardedInterstitialAdLoaded = false;

  final ValueNotifier<bool> premiumStatusNotifier = ValueNotifier<bool>(false);

  // 단위 ID Getter (릴리즈/디버그 자동 분기)
  static String get bannerAdUnitId {
    if (kIsWeb) return '';
    return kReleaseMode ? _adMobBannerId : _testBannerId;
  }

  static String get interstitialAdUnitId {
    if (kIsWeb) return '';
    return kReleaseMode ? _adMobInterstitialId : _testInterstitialId;
  }

  static String get appOpenAdUnitId {
    if (kIsWeb) return '';
    return kReleaseMode ? _adMobAppOpenId : _testAppOpenId;
  }

  static String get rewardedAdUnitId {
    if (kIsWeb) return '';
    return kReleaseMode ? _adMobRewardedId : _testRewardedId;
  }

  static String get rewardedInterstitialAdUnitId {
    if (kIsWeb) return '';
    return kReleaseMode ? _adMobRewardedInterstitialId : _testRewardedInterstitialId;
  }

  static String get nativeAdUnitId {
    if (kIsWeb) return '';
    return kReleaseMode ? _adMobNativeId : _testNativeId;
  }

  Future<void> _persistEntitlements(SharedPreferences prefs) async {
    final encoded = jsonEncode(
      _entitlements.map((key, value) => MapEntry(key, value.toJson())),
    );
    await prefs.setString(_prefsEntitlementsKey, encoded);
  }

  void _loadEntitlementsFromPrefs(SharedPreferences prefs) {
    _entitlements.clear();
    final raw = prefs.getString(_prefsEntitlementsKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw) as Map<String, dynamic>;
        decoded.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            final ent = PurchasedEntitlement.fromJson(value);
            if (ent.productId.isNotEmpty) {
              _entitlements[ent.productId] = ent;
            }
          }
        });
      } catch (e) {
        debugPrint('Entitlement decode error: $e');
      }
    }
  }

  Future<void> _recomputeAccessFlags(
    SharedPreferences prefs, {
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    final adsActive = _hasTrackedAdsEntitlement
        ? (isProductActive(productSubRemoveAdsMonthly, now: checkNow) ||
            _hasActiveVipBundle(checkNow))
        : _isAdsRemoved;
    final kioskActive = _hasTrackedKioskEntitlement
        ? (isProductActive(productSubKioskMonthly, now: checkNow) ||
            _hasActiveVipBundle(checkNow))
        : _isKioskProUnlocked;

    _isAdsRemoved = adsActive;
    _isKioskProUnlocked = kioskActive;
    await prefs.setBool('is_ads_removed', _isAdsRemoved);
    await prefs.setBool('is_kiosk_pro_unlocked', _isKioskProUnlocked);

    final bool tempPassStillActive =
        (_rewardedAdFreeUntil != null && checkNow.isBefore(_rewardedAdFreeUntil!)) ||
            (_rewardedKioskPassUntil != null && checkNow.isBefore(_rewardedKioskPassUntil!));
    premiumStatusNotifier.value = _isAdsRemoved || tempPassStillActive;
  }

  /// 활성 이용 기간(정기 구독 및 1시간 무료 기간권)이 만료되었는지 점검하고 권한을 회수합니다.
  /// 만료되어 권한이 회수된 상품 ID 목록을 반환합니다.
  Future<List<String>> checkEntitlementExpirations({DateTime? now}) async {
    final wallNow = DateTime.now();
    final checkNow = now ?? wallNow;
    final prefs = await SharedPreferences.getInstance();
    final expiredProductIds = <String>[];
    bool updatedExpiryTimestamp = false;

    for (final key in _entitlements.keys.toList()) {
      final ent = _entitlements[key]!;
      if (!ent.isActiveAt(checkNow)) {
        if (ent.expiresAt.isAfter(wallNow)) {
          _entitlements[key] = PurchasedEntitlement(
            productId: ent.productId,
            purchasedAt: ent.purchasedAt,
            expiresAt: wallNow,
            isSubscription: ent.isSubscription,
            isRestored: ent.isRestored,
          );
          updatedExpiryTimestamp = true;
        }
        if (!_expiredNotifiedProductIds.contains(key)) {
          _expiredNotifiedProductIds.add(key);
          expiredProductIds.add(key);
        }
      }
    }
    if (updatedExpiryTimestamp) {
      await _persistEntitlements(prefs);
    }

    if (_rewardedAdFreeUntil != null && !checkNow.isBefore(_rewardedAdFreeUntil!)) {
      _rewardedAdFreeUntil = null;
      await prefs.remove('rewarded_ad_free_until');
      if (!_expiredNotifiedProductIds.contains(productPassTemporaryVip1h) &&
          !expiredProductIds.contains(productPassTemporaryVip1h)) {
        _expiredNotifiedProductIds.add(productPassTemporaryVip1h);
        expiredProductIds.add(productPassTemporaryVip1h);
      }
    }
    if (_rewardedKioskPassUntil != null && !checkNow.isBefore(_rewardedKioskPassUntil!)) {
      _rewardedKioskPassUntil = null;
      await prefs.remove('rewarded_kiosk_pass_until');
    }

    await _recomputeAccessFlags(prefs, now: checkNow);

    if (expiredProductIds.isNotEmpty) {
      final firstTitle = productDisplayName(expiredProductIds.first);
      _lastStoreEventType = StoreEventType.expired;
      _lastStoreNotice = '$firstTitle 이용 기간이 만료되었습니다. 필요 시 다시 구매/구독할 수 있습니다.';
      notifyListeners();
    }
    return expiredProductIds;
  }

  @visibleForTesting
  Future<void> seedEntitlementForTest(PurchasedEntitlement entitlement) async {
    final prefs = await SharedPreferences.getInstance();
    _entitlements[entitlement.productId] = entitlement;
    if (entitlement.isActiveAt(DateTime.now())) {
      _expiredNotifiedProductIds.remove(entitlement.productId);
    }
    if (entitlement.productId == productPassTemporaryVip1h) {
      _rewardedAdFreeUntil = entitlement.expiresAt;
      _rewardedKioskPassUntil = entitlement.expiresAt;
      await prefs.setString(
        'rewarded_ad_free_until',
        entitlement.expiresAt.toIso8601String(),
      );
      await prefs.setString(
        'rewarded_kiosk_pass_until',
        entitlement.expiresAt.toIso8601String(),
      );
    }
    await _persistEntitlements(prefs);
    await _recomputeAccessFlags(prefs);
    notifyListeners();
  }

  Future<void> debugUnlockAll() async {
    await setDebugUnlock(adsRemoved: true, kioskPro: true);
  }

  /// 개발/검수용 모든 구독 초기화 (무료 체험 및 구독 전체 리셋)
  Future<void> debugResetAll() async {
    _isDebugUnlocked = false;
    _entitlements.clear();
    _expiredNotifiedProductIds.clear();
    _restoreSessionProductIds.clear();
    _pendingPurchaseProductId = null;
    _isRestoringPurchases = false;
    _lastPurchaseMessage = null;
    _lastStoreNotice = null;
    _lastStoreEventType = StoreEventType.none;
    _rewardedAdFreeUntil = null;
    _rewardedKioskPassUntil = null;
    _lastInterstitialShownTime = null;
    _lastUpsellDialogShownTime = null;
    _crudAdExposureCount = 0;
    _monthlyEditCount = 0;
    _editCountMonthKey = _currentMonthKey();
    final prefs = await SharedPreferences.getInstance();
    _isAdsRemoved = false;
    _isKioskProUnlocked = false;
    premiumStatusNotifier.value = false;
    await prefs.remove(_prefsEntitlementsKey);
    await prefs.setBool('is_ads_removed', false);
    await prefs.setBool('is_kiosk_pro_unlocked', false);
    await prefs.remove('rewarded_ad_free_until');
    await prefs.remove('rewarded_kiosk_pass_until');
    await prefs.setInt('bm_monthly_edit_count', 0);
    await prefs.setString('bm_monthly_edit_month', _editCountMonthKey);
    notifyListeners();
  }

  Future<void> setDebugUnlock({bool? adsRemoved, bool? kioskPro}) async {
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime.now();
    if (adsRemoved == true && kioskPro == true) {
      _isDebugUnlocked = true;
      _entitlements[productSubAllInOneMonthly] = PurchasedEntitlement(
        productId: productSubAllInOneMonthly,
        purchasedAt: now,
        expiresAt: now.add(periodDurationForProduct(productSubAllInOneMonthly)),
        isSubscription: true,
      );
      _expiredNotifiedProductIds.remove(productSubAllInOneMonthly);
    } else {
      if (adsRemoved == true) {
        _isDebugUnlocked = true;
        _entitlements[productSubRemoveAdsMonthly] = PurchasedEntitlement(
          productId: productSubRemoveAdsMonthly,
          purchasedAt: now,
          expiresAt: now.add(periodDurationForProduct(productSubRemoveAdsMonthly)),
          isSubscription: true,
        );
        _expiredNotifiedProductIds.remove(productSubRemoveAdsMonthly);
      } else if (adsRemoved == false) {
        _entitlements.remove(productSubRemoveAdsMonthly);
        _entitlements.remove(productSubAllInOneMonthly);
        _entitlements.remove(productSubAllInOneYearly);
      }

      if (kioskPro == true) {
        _isDebugUnlocked = true;
        _entitlements[productSubKioskMonthly] = PurchasedEntitlement(
          productId: productSubKioskMonthly,
          purchasedAt: now,
          expiresAt: now.add(periodDurationForProduct(productSubKioskMonthly)),
          isSubscription: true,
        );
        _expiredNotifiedProductIds.remove(productSubKioskMonthly);
      } else if (kioskPro == false) {
        _entitlements.remove(productSubKioskMonthly);
        _entitlements.remove(productSubAllInOneMonthly);
        _entitlements.remove(productSubAllInOneYearly);
      }
    }
    if (adsRemoved == false && kioskPro == false) {
      _isDebugUnlocked = false;
    }

    await _persistEntitlements(prefs);
    await _recomputeAccessFlags(prefs, now: now);
    notifyListeners();
  }

  /// 기간제 1시간 무료 VIP 체험 시작 (이미 이용 중이거나 VIP 구독 중이면 재발급 차단)
  Future<({bool granted, String message})> claimTemporaryVipPass({
    int hours = 1,
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    await checkEntitlementExpirations(now: checkNow);
    if (isPermanentVip) {
      return (
        granted: false,
        message: '이미 올인원 VIP 구독을 이용 중입니다.',
      );
    }
    if (isTemporaryPassActive) {
      return (
        granted: false,
        message: '이미 1시간 무료 VIP 체험 중($remainingTemporaryPassFormatted)입니다. 기간 만료 후 다시 이용할 수 있습니다.',
      );
    }
    await grantTemporaryAdFreeHours(hours, includeKiosk: true, now: checkNow);
    final expiry = checkNow.add(Duration(hours: hours));
    final expiryTime = '${expiry.hour.toString().padLeft(2, '0')}:${expiry.minute.toString().padLeft(2, '0')}';
    return (
      granted: true,
      message: '$hours시간 무료 VIP 체험이 시작되었습니다! ($expiryTime까지 이용 가능)',
    );
  }

  /// 앱 전역에서 1시간 기간제 무료 VIP 체험을 시작하는 통합 진입점 (중복 발급 차단 + 보상형 광고/폴백 + 스낵바 안내)
  Future<void> launchTemporaryPassFlow(
    BuildContext context, {
    VoidCallback? onGranted,
    bool preferRewardedInterstitial = false,
  }) async {
    await checkEntitlementExpirations();
    if (!canClaimTemporaryPass) {
      final res = await claimTemporaryVipPass(hours: 1);
      final messengerCtx = context.mounted ? context : rootNavigatorKey.currentContext;
      if (messengerCtx != null && messengerCtx.mounted) {
        ScaffoldMessenger.of(messengerCtx).showSnackBar(
          SnackBar(content: Text(res.message), behavior: SnackBarBehavior.floating),
        );
      }
      return;
    }

    Future<void> finishClaim() async {
      final res = await claimTemporaryVipPass(hours: 1);
      final messengerCtx = context.mounted ? context : rootNavigatorKey.currentContext;
      if (messengerCtx != null && messengerCtx.mounted) {
        ScaffoldMessenger.of(messengerCtx).showSnackBar(
          SnackBar(content: Text(res.message), behavior: SnackBarBehavior.floating),
        );
      }
      if (res.granted) {
        onGranted?.call();
      }
    }

    if (isAnyRewardedAdAvailable) {
      showBestRewardedAd(
        preferRewardedInterstitial: preferRewardedInterstitial,
        onRewarded: finishClaim,
        onFailed: finishClaim,
      );
    } else {
      await finishClaim();
    }
  }

  /// 보상형 광고 시청 후 N시간 동안 광고 제거 + 태블릿 키오스크 VIP 혜택 부여 (Reverse-Trial Funnel)
  Future<void> grantTemporaryAdFreeHours(
    int hours, {
    bool includeKiosk = true,
    DateTime? now,
  }) async {
    final start = now ?? DateTime.now();
    final expiry = start.add(Duration(hours: hours));
    _rewardedAdFreeUntil = expiry;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rewarded_ad_free_until', expiry.toIso8601String());
    if (includeKiosk) {
      _rewardedKioskPassUntil = expiry;
      await prefs.setString('rewarded_kiosk_pass_until', expiry.toIso8601String());
    }
    _entitlements[productPassTemporaryVip1h] = PurchasedEntitlement(
      productId: productPassTemporaryVip1h,
      purchasedAt: start,
      expiresAt: expiry,
      isSubscription: false,
    );
    _expiredNotifiedProductIds.remove(productPassTemporaryVip1h);
    _lastStoreEventType = StoreEventType.purchased;
    _lastStoreNotice = '$hours시간 무료 VIP 체험이 활성화되었습니다. 이용 기간 종료 후 다시 이용하실 수 있습니다.';
    await _persistEntitlements(prefs);
    await _recomputeAccessFlags(prefs, now: start);
    notifyListeners();
  }

  /// 실사용 모드 전환 시 연습용 시드 ROI 지표를 0으로 초기화합니다.
  Future<void> resetMetricsForRealUsage() async {
    _cumulativeSavedSmsCount = 0;
    _cumulativeCheckInCount = 0;
    _cumulativeTaxLedgerCount = 0;
    _activeStreakDays = 1;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('bm_saved_sms_count', 0);
    await prefs.setInt('bm_checkin_count', 0);
    await prefs.setInt('bm_tax_count', 0);
    await prefs.setInt('bm_active_streak_days', 1);
    notifyListeners();
  }

  /// 출결/안심문자/청구서/세무정산 실행 시 원장님 누적 ROI 절감액 기록 (Retention Flywheel)
  Future<void> recordValueAction({
    int smsCount = 0,
    int checkInCount = 0,
    int taxCount = 0,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (smsCount > 0) {
      _cumulativeSavedSmsCount += smsCount;
      await prefs.setInt('bm_saved_sms_count', _cumulativeSavedSmsCount);
    }
    if (checkInCount > 0) {
      _cumulativeCheckInCount += checkInCount;
      await prefs.setInt('bm_checkin_count', _cumulativeCheckInCount);
    }
    if (taxCount > 0) {
      _cumulativeTaxLedgerCount += taxCount;
      await prefs.setInt('bm_tax_count', _cumulativeTaxLedgerCount);
    }
    await _updateDailyStreak(prefs);
    notifyListeners();
  }

  Future<void> _updateDailyStreak(SharedPreferences prefs) async {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    if (_lastActiveDateStr == todayStr) return;

    if (_lastActiveDateStr != null) {
      final lastDate = DateTime.tryParse(_lastActiveDateStr!);
      if (lastDate != null) {
        final diffDays = DateTime(now.year, now.month, now.day)
            .difference(DateTime(lastDate.year, lastDate.month, lastDate.day))
            .inDays;
        if (diffDays == 1) {
          _activeStreakDays++;
        } else if (diffDays > 1) {
          _activeStreakDays = 1;
        }
      }
    } else {
      _activeStreakDays = prefs.getInt('bm_active_streak_days') ?? 7; // 초기 경험 강화를 위한 기본 7일 연속 배지 시드
    }

    _lastActiveDateStr = todayStr;
    await prefs.setString('bm_last_active_date', todayStr);
    await prefs.setInt('bm_active_streak_days', _activeStreakDays);
  }

  Future<void> initialize() async {
    WidgetsBinding.instance.addObserver(this);

    final prefs = await SharedPreferences.getInstance();
    _loadEntitlementsFromPrefs(prefs);
    _isAdsRemoved = prefs.getBool('is_ads_removed') ?? false;
    _isKioskProUnlocked = prefs.getBool('is_kiosk_pro_unlocked') ?? false;

    // 기존 버전(boolean 플래그만 저장)에서 업그레이드된 경우 기본 30일 권한 레코드로 마이그레이션
    if (_entitlements.isEmpty && (_isAdsRemoved || _isKioskProUnlocked)) {
      final now = DateTime.now();
      if (_isAdsRemoved && _isKioskProUnlocked) {
        _entitlements[productSubAllInOneMonthly] = PurchasedEntitlement(
          productId: productSubAllInOneMonthly,
          purchasedAt: now,
          expiresAt: now.add(periodDurationForProduct(productSubAllInOneMonthly)),
          isSubscription: true,
        );
      } else if (_isAdsRemoved) {
        _entitlements[productSubRemoveAdsMonthly] = PurchasedEntitlement(
          productId: productSubRemoveAdsMonthly,
          purchasedAt: now,
          expiresAt: now.add(periodDurationForProduct(productSubRemoveAdsMonthly)),
          isSubscription: true,
        );
      } else if (_isKioskProUnlocked) {
        _entitlements[productSubKioskMonthly] = PurchasedEntitlement(
          productId: productSubKioskMonthly,
          purchasedAt: now,
          expiresAt: now.add(periodDurationForProduct(productSubKioskMonthly)),
          isSubscription: true,
        );
      }
      await _persistEntitlements(prefs);
    }

    _cumulativeSavedSmsCount = prefs.getInt('bm_saved_sms_count') ?? 128;
    _cumulativeCheckInCount = prefs.getInt('bm_checkin_count') ?? 342;
    _cumulativeTaxLedgerCount = prefs.getInt('bm_tax_count') ?? 18;
    _activeStreakDays = prefs.getInt('bm_active_streak_days') ?? 7;
    _lastActiveDateStr = prefs.getString('bm_last_active_date');
    await _updateDailyStreak(prefs);
    await _syncMonthlyEditCounter(prefs);

    final adFreeStr = prefs.getString('rewarded_ad_free_until');
    if (adFreeStr != null) {
      _rewardedAdFreeUntil = DateTime.tryParse(adFreeStr);
    }

    final kioskPassStr = prefs.getString('rewarded_kiosk_pass_until');
    if (kioskPassStr != null) {
      _rewardedKioskPassUntil = DateTime.tryParse(kioskPassStr);
    }

    await checkEntitlementExpirations();

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await MobileAds.instance.initialize();

        // 고수익 풀(Fill) 보장을 위한 백그라운드 프리로드
        if (!isAdsRemoved) {
          _loadAppOpenAd();
          _loadInterstitialAd();
        }
        if (!isPermanentVip) {
          _loadRewardedAd();
          _loadRewardedInterstitialAd();
        }
      } catch (e) {
        debugPrint('AdMob initialize error: $e');
      }

      // 인앱 결제 스트림 초기화
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(checkEntitlementExpirations());
      // 앱으로 복귀했을 때 앱 오프닝 광고 트리거 (수익 극대화)
      showAppOpenAdIfAvailable();
    }
  }

  // ==========================================
  // 1. 앱 오프닝 광고 (App Open Ad) - 초고단가 eCPM
  // ==========================================
  void _loadAppOpenAd() {
    if (isAdsRemoved || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          _appOpenAd = ad;
          _isAppOpenAdLoaded = true;
          _appOpenAdLoadTime = DateTime.now();
          debugPrint('AppOpenAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
          _isAppOpenAdLoaded = false;
          _appOpenAd = null;
        },
      ),
    );
  }

  bool _isAppOpenAdValid() {
    return _isAppOpenAdLoaded &&
        _appOpenAd != null &&
        _appOpenAdLoadTime != null &&
        DateTime.now().difference(_appOpenAdLoadTime!).inHours < 4;
  }

  void showAppOpenAdIfAvailable() {
    if (isAdsRemoved || _isShowingAppOpenAd) return;

    final now = DateTime.now();
    // 외부 인텐트(문자/카톡/공유) 복귀 보호 시간 내에는 앱 오프닝 광고를 띄우지 않음
    if (_externalIntentSuppressedUntil != null && now.isBefore(_externalIntentSuppressedUntil!)) {
      return;
    }
    // 앱 오프닝 광고 최소 15분 쿨다운 (업무 방해 원천 차단 및 리텐션 보호)
    if (_lastAppOpenShownTime != null && now.difference(_lastAppOpenShownTime!).inMinutes < 15) {
      return;
    }
    // 최근 60초 이내에 전면 광고가 노출되었다면 오프닝 광고 중복 노출 차단
    if (_lastInterstitialShownTime != null && now.difference(_lastInterstitialShownTime!).inSeconds < 60) {
      return;
    }

    if (!_isAppOpenAdValid()) {
      _loadAppOpenAd();
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAppOpenAd = true;
        _lastAppOpenShownTime = DateTime.now();
      },
      onAdDismissedFullScreenContent: (ad) {
        _isShowingAppOpenAd = false;
        _lastAppOpenShownTime = DateTime.now();
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenAdLoaded = false;
        _loadAppOpenAd(); // 다음 복귀를 위해 프리로드
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        _isShowingAppOpenAd = false;
        ad.dispose();
        _appOpenAd = null;
        _isAppOpenAdLoaded = false;
        _loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
  }

  // ==========================================
  // 2. 전면 광고 (Interstitial Ad) - 스마트 쿨다운 & 최고 수익
  // ==========================================
  void _loadInterstitialAd() {
    if (isAdsRemoved || kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _interstitialAd = ad;
          _isInterstitialAdLoaded = true;
          debugPrint('InterstitialAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('InterstitialAd failed to load: $error');
          _isInterstitialAdLoaded = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// 주요 사용자 액션(수납 저장, 명단 등록, 백업 등) 발생 시 호출
  /// [forceShow]: 쿨다운 무시 강제 노출 여부
  /// [cooldownSeconds]: 기본 40초 쿨다운
  /// [actionThreshold]: N회 액션마다 1회 노출
  void triggerSmartInterstitialAd({
    bool forceShow = false,
    int cooldownSeconds = 40,
    int actionThreshold = 2,
    VoidCallback? onDismissed,
  }) {
    if (isAdsRemoved) {
      onDismissed?.call();
      return;
    }

    _actionCounter++;
    final now = DateTime.now();
    final bool isCooldownOver = _lastInterstitialShownTime == null ||
        now.difference(_lastInterstitialShownTime!).inSeconds >= cooldownSeconds;

    final bool shouldShow = forceShow || (_actionCounter >= actionThreshold && isCooldownOver);

    if (shouldShow && _isInterstitialAdLoaded && _interstitialAd != null) {
      _showLoadedInterstitial(
        actionLabel: '업무 저장',
        onDismissed: onDismissed,
      );
    } else {
      if (!_isInterstitialAdLoaded) {
        _loadInterstitialAd();
      }
      onDismissed?.call();
    }
  }

  /// 모든 메뉴(회원/출결/청구/지출/거래처/일정/템플릿/설정)의 CRUD(등록·수정·삭제) 완료 시
  /// [probability] 확률로 전면 광고를 띄우고, 광고 종료 후 자연스럽게 광고 제거 구독(결제)을 유도합니다.
  bool triggerCrudInterstitialAd({
    String actionLabel = '데이터 등록·수정·삭제',
    double probability = defaultCrudAdProbability,
    int cooldownSeconds = defaultCrudCooldownSeconds,
    Random? random,
    VoidCallback? onDismissed,
  }) {
    if (isAdsRemoved) {
      onDismissed?.call();
      return false;
    }

    final isMobileRuntime = !kIsWeb && (Platform.isAndroid || Platform.isIOS);
    if (!isMobileRuntime && !allowCrudAdInTests) {
      onDismissed?.call();
      return false;
    }

    final now = DateTime.now();
    if (_externalIntentSuppressedUntil != null && now.isBefore(_externalIntentSuppressedUntil!)) {
      onDismissed?.call();
      return false;
    }

    final isCooldownOver = _lastInterstitialShownTime == null ||
        now.difference(_lastInterstitialShownTime!).inSeconds >= cooldownSeconds;
    if (!isCooldownOver) {
      onDismissed?.call();
      return false;
    }

    final roll = (random ?? _random).nextDouble();
    if (roll >= probability.clamp(0.0, 1.0)) {
      if (!_isInterstitialAdLoaded && isMobileRuntime) {
        _loadInterstitialAd();
      }
      onDismissed?.call();
      return false;
    }

    _crudAdExposureCount++;

    if (allowCrudAdInTests) {
      _lastInterstitialShownTime = DateTime.now();
      _actionCounter = 0;
      onTestInterstitialTriggered?.call(actionLabel);
      _maybeShowAdRemovalUpsell(actionLabel: actionLabel);
      onDismissed?.call();
      return true;
    }

    if (_isInterstitialAdLoaded && _interstitialAd != null) {
      _showLoadedInterstitial(
        actionLabel: actionLabel,
        onDismissed: onDismissed,
      );
      return true;
    }

    // 전면 광고가 아직 로드되지 않았을 때는 즉시 프리로드 + 일정 간격으로 구독 유도 다이얼로그 노출
    _loadInterstitialAd();
    _maybeShowAdRemovalUpsell(actionLabel: actionLabel, cooldownSeconds: 60);
    onDismissed?.call();
    return false;
  }

  void _showLoadedInterstitial({
    required String actionLabel,
    VoidCallback? onDismissed,
  }) {
    _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _lastInterstitialShownTime = DateTime.now();
        _actionCounter = 0;
        _loadInterstitialAd();
        onDismissed?.call();
        _maybeShowAdRemovalUpsell(actionLabel: actionLabel, cooldownSeconds: 45);
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _loadInterstitialAd();
        onDismissed?.call();
      },
    );
    _interstitialAd!.show();
    _isInterstitialAdLoaded = false;
    _interstitialAd = null;
  }

  void _maybeShowAdRemovalUpsell({
    required String actionLabel,
    int cooldownSeconds = 45,
  }) {
    if (isAdsRemoved || _isShowingUpsellDialog) return;

    final now = DateTime.now();
    if (_lastUpsellDialogShownTime != null &&
        now.difference(_lastUpsellDialogShownTime!).inSeconds < cooldownSeconds) {
      return;
    }

    if (allowCrudAdInTests && onTestUpsellTriggered != null) {
      _lastUpsellDialogShownTime = now;
      onTestUpsellTriggered!(actionLabel);
      return;
    }

    final navCtx = rootNavigatorKey.currentContext;
    if (navCtx == null || !navCtx.mounted) return;

    _lastUpsellDialogShownTime = now;
    Future.microtask(() {
      final ctx = rootNavigatorKey.currentContext;
      if (ctx != null && ctx.mounted && !isAdsRemoved && !_isShowingUpsellDialog) {
        showAdRemovalUpsellDialog(ctx, actionLabel: actionLabel);
      }
    });
  }

  /// 전면 광고 직후 또는 반복 CRUD 시 자연스럽게 광고 제거 구독 결제를 유도하는 다이얼로그
  Future<void> showAdRemovalUpsellDialog(
    BuildContext context, {
    String actionLabel = '데이터 등록·수정·삭제',
  }) async {
    if (isAdsRemoved || _isShowingUpsellDialog) return;
    _isShowingUpsellDialog = true;
    try {
      await showDialog<void>(
        context: context,
        useRootNavigator: true,
        builder: (dlgCtx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 22),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  '광고 없이 바로 저장할까요?',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                ),
              ),
            ],
          ),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '무료 버전에서는 \'$actionLabel\' 등 주요 작업마다 일정 확률로 전면 광고가 표시됩니다.',
                  style: const TextStyle(fontSize: 13.5, color: AppTheme.textPrimary, height: 1.45, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• 등록·수정·삭제 전면 광고 100% 영구 제거', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45)),
                      Text('• 하단 배너 / 오프닝 / 리스트 내 광고 완전 차단', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45)),
                      Text('• 언제든 Google Play에서 위약금 없이 해지 가능', style: TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ResponsiveDialogActions(
                  breakpoint: 360,
                  primaryFirstInColumn: true,
                  primary: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(dlgCtx);
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(builder: (_) => const ProStoreScreen()),
                      );
                    },
                    icon: const Icon(Icons.bolt_rounded, size: 18),
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('월 1,900원 광고 완전 제거', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  secondary: canClaimTemporaryPass
                      ? OutlinedButton.icon(
                          onPressed: () {
                            Navigator.pop(dlgCtx);
                            launchTemporaryPassFlow(context);
                          },
                          icon: const Icon(Icons.play_circle_outline_rounded, size: 17, color: Color(0xFFD97706)),
                          label: const FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text('1시간 무료 체험', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFB45309))),
                          ),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFFCD34D)),
                            padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        )
                      : null,
                ),
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () => Navigator.pop(dlgCtx),
                  child: const Text(
                    '계속 광고 보며 이용하기',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    } finally {
      _isShowingUpsellDialog = false;
    }
  }

  /// 비-VIP 플랜의 신규 등록 개수 한도를 검사하고, 초과 시 VIP 무제한 업그레이드 다이얼로그를 표시합니다.
  Future<bool> ensureCreateAllowed(
    BuildContext context, {
    required String itemLabel,
    required int currentCount,
    required int limit,
  }) async {
    if (canCreateItem(currentCount: currentCount, limit: limit)) {
      return true;
    }
    if (context.mounted) {
      await showVipLimitUpgradeDialog(
        context,
        title: '$itemLabel 등록 한도에 도달했습니다',
        reason: '$membershipPlanLabel에서는 $itemLabel 등록이 최대 $limit개(명)까지 가능합니다. (현재 $currentCount/$limit)',
      );
    }
    return false;
  }

  /// 비-VIP 플랜의 월간 수정 횟수 한도를 검사하고, 소진 시 VIP 무제한 업그레이드 다이얼로그를 표시합니다.
  Future<bool> ensureEditAllowed(
    BuildContext context, {
    required String itemLabel,
  }) async {
    if (canPerformEdit) {
      return true;
    }
    if (context.mounted) {
      await showVipLimitUpgradeDialog(
        context,
        title: '이번 달 수정 한도를 모두 사용했습니다',
        reason: '$membershipPlanLabel에서는 정보 수정($itemLabel 등)을 월 $maxMonthlyEditLimit회까지 이용할 수 있습니다. ($_monthlyEditCount/$maxMonthlyEditLimit회 사용)',
      );
    }
    return false;
  }

  /// 등록 개수 제한 및 수정 횟수 제한 도달 시 올인원 VIP 무제한 구독으로 유도하는 다이얼로그
  Future<void> showVipLimitUpgradeDialog(
    BuildContext context, {
    required String title,
    required String reason,
  }) async {
    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.diamond_rounded, color: Color(0xFFD97706), size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                reason,
                style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.45, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '👑 올인원 VIP 멤버십 무제한 혜택',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w900, color: Color(0xFFFBBF24)),
                    ),
                    SizedBox(height: 6),
                    Text('• 회원 · 청구 · 지출 · 거래처 · 일정 등록 개수 무제한', style: TextStyle(fontSize: 12, color: Colors.white, height: 1.45)),
                    Text('• 맞춤 서식 / 템플릿 생성 및 모든 수정 횟수 무제한', style: TextStyle(fontSize: 12, color: Colors.white, height: 1.45)),
                    Text('• 무인 태블릿 키오스크 + 전면/배너 광고 100% 제거', style: TextStyle(fontSize: 12, color: Colors.white, height: 1.45)),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ResponsiveDialogActions(
                breakpoint: 360,
                primaryFirstInColumn: true,
                primary: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(dlgCtx);
                    Navigator.of(context, rootNavigator: true).push(
                      MaterialPageRoute(builder: (_) => const ProStoreScreen()),
                    );
                  },
                  icon: const Icon(Icons.workspace_premium_rounded, size: 18),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('올인원 VIP 무제한 (₩5,900)', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD97706),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                secondary: canClaimTemporaryPass
                    ? OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(dlgCtx);
                          launchTemporaryPassFlow(context);
                        },
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 17, color: AppTheme.primaryBlue),
                        label: const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text('1시간 VIP 체험', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                        ),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Color(0xFF93C5FD)),
                          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      )
                    : null,
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: () => Navigator.pop(dlgCtx),
                child: const Text(
                  '닫기',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ==========================================
  // 3. 보상형 광고 (Rewarded Ad) - 자발적 시청 & 최고 eCPM
  // ==========================================
  void _loadRewardedAd() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isRewardedAdLoaded = true;
          debugPrint('RewardedAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _isRewardedAdLoaded = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  bool get isRewardedAdAvailable => _isRewardedAdLoaded && _rewardedAd != null;
  bool get isRewardedInterstitialAdAvailable =>
      _isRewardedInterstitialAdLoaded && _rewardedInterstitialAd != null;
  bool get isAnyRewardedAdAvailable => isRewardedAdAvailable || isRewardedInterstitialAdAvailable;

  /// 보상형 광고 재생 (성공 시 onRewarded 콜백 실행)
  void showRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
    VoidCallback? onFailed,
  }) {
    if (_isRewardedAdLoaded && _rewardedAd != null) {
      bool earned = false;
      _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
          _loadRewardedAd();
          if (earned) {
            onRewarded();
          } else {
            onDismissed?.call();
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
          _loadRewardedAd();
          onFailed?.call();
        },
      );

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          earned = true;
        },
      );
    } else {
      _loadRewardedAd();
      onFailed?.call();
    }
  }

  // ==========================================
  // 3-B. 보상형 전면 광고 (Rewarded Interstitial Ad)
  // ==========================================
  void _loadRewardedInterstitialAd() {
    if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) return;

    RewardedInterstitialAd.load(
      adUnitId: rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialAdLoaded = true;
          debugPrint('RewardedInterstitialAd loaded successfully');
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedInterstitialAd failed to load: $error');
          _isRewardedInterstitialAdLoaded = false;
          _rewardedInterstitialAd = null;
        },
      ),
    );
  }

  /// 보상형 전면 광고 재생 (성공 시 onRewarded 콜백 실행)
  void showRewardedInterstitialAd({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
    VoidCallback? onFailed,
  }) {
    if (_isRewardedInterstitialAdLoaded && _rewardedInterstitialAd != null) {
      bool earned = false;
      _rewardedInterstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          ad.dispose();
          _rewardedInterstitialAd = null;
          _isRewardedInterstitialAdLoaded = false;
          _loadRewardedInterstitialAd();
          if (earned) {
            onRewarded();
          } else {
            onDismissed?.call();
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          ad.dispose();
          _rewardedInterstitialAd = null;
          _isRewardedInterstitialAdLoaded = false;
          _loadRewardedInterstitialAd();
          onFailed?.call();
        },
      );

      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          earned = true;
        },
      );
    } else {
      _loadRewardedInterstitialAd();
      onFailed?.call();
    }
  }

  /// 일반 보상형 광고 → 보상형 전면 광고 순서로 자동 풀(Fill) 보장 재생
  void showBestRewardedAd({
    required VoidCallback onRewarded,
    VoidCallback? onDismissed,
    VoidCallback? onFailed,
    bool preferRewardedInterstitial = false,
  }) {
    if (preferRewardedInterstitial && isRewardedInterstitialAdAvailable) {
      showRewardedInterstitialAd(
        onRewarded: onRewarded,
        onDismissed: onDismissed,
        onFailed: () {
          if (isRewardedAdAvailable) {
            showRewardedAd(onRewarded: onRewarded, onDismissed: onDismissed, onFailed: onFailed);
          } else {
            onFailed?.call();
          }
        },
      );
      return;
    }

    if (isRewardedAdAvailable) {
      showRewardedAd(
        onRewarded: onRewarded,
        onDismissed: onDismissed,
        onFailed: () {
          if (isRewardedInterstitialAdAvailable) {
            showRewardedInterstitialAd(onRewarded: onRewarded, onDismissed: onDismissed, onFailed: onFailed);
          } else {
            onFailed?.call();
          }
        },
      );
    } else if (isRewardedInterstitialAdAvailable) {
      showRewardedInterstitialAd(
        onRewarded: onRewarded,
        onDismissed: onDismissed,
        onFailed: onFailed,
      );
    } else {
      _loadRewardedAd();
      _loadRewardedInterstitialAd();
      onFailed?.call();
    }
  }

  // ==========================================
  // 4. 인앱 결제 (IAP) 처리
  // ==========================================
  String? _lastPurchaseMessage;
  String? get lastPurchaseMessage => _lastPurchaseMessage;

  DateTime? _parseTransactionDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final millis = int.tryParse(raw);
    if (millis != null) {
      return DateTime.fromMillisecondsSinceEpoch(millis);
    }
    return DateTime.tryParse(raw);
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    unawaited(_processPurchaseUpdates(purchaseDetailsList));
  }

  @visibleForTesting
  Future<void> processPurchaseUpdatesForTest(
    List<PurchaseDetails> purchaseDetailsList, {
    DateTime? now,
  }) {
    return _processPurchaseUpdates(
      purchaseDetailsList,
      now: now,
      completePlatformPurchase: false,
    );
  }

  Future<void> _processPurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList, {
    DateTime? now,
    bool completePlatformPurchase = true,
  }) async {
    final checkNow = now ?? DateTime.now();
    for (final purchaseDetails in purchaseDetailsList) {
      final productId = purchaseDetails.productID;
      if (purchaseDetails.status == PurchaseStatus.pending) {
        _pendingPurchaseProductId = productId;
        _lastStoreEventType = StoreEventType.pending;
        _lastStoreNotice = '${productDisplayName(productId)} 결제가 승인 대기 중입니다.';
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.purchased) {
        if (_pendingPurchaseProductId == productId) {
          _pendingPurchaseProductId = null;
        }
        _lastPurchaseMessage = null;
        final txTime = _parseTransactionDate(purchaseDetails.transactionDate) ?? checkNow;
        await _handleSuccessfulPurchase(
          productId,
          now: txTime,
          isRestored: false,
        );
        _lastStoreEventType = StoreEventType.purchased;
        _lastStoreNotice = '${productDisplayName(productId)} 이용이 시작되었습니다.';
        notifyListeners();
        if (completePlatformPurchase && purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.restored) {
        if (_pendingPurchaseProductId == productId) {
          _pendingPurchaseProductId = null;
        }
        _lastPurchaseMessage = null;
        _restoreSessionProductIds.add(productId);
        final txTime = _parseTransactionDate(purchaseDetails.transactionDate);
        await _handleSuccessfulPurchase(
          productId,
          now: checkNow,
          isRestored: true,
          originalPurchaseDate: txTime,
        );
        _lastStoreEventType = StoreEventType.restored;
        _lastStoreNotice = '${productDisplayName(productId)} 구독이 복원되었습니다.';
        notifyListeners();
        if (completePlatformPurchase && purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        if (_pendingPurchaseProductId == productId) {
          _pendingPurchaseProductId = null;
        }
        _lastStoreEventType = StoreEventType.error;
        _lastPurchaseMessage = purchaseDetails.error?.message ?? '결제 처리 중 오류가 발생했습니다.';
        _lastStoreNotice = _lastPurchaseMessage;
        if (completePlatformPurchase && purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        if (_pendingPurchaseProductId == productId) {
          _pendingPurchaseProductId = null;
        }
        _lastStoreEventType = StoreEventType.canceled;
        _lastPurchaseMessage = '결제가 취소되었습니다.';
        _lastStoreNotice = _lastPurchaseMessage;
        if (completePlatformPurchase && purchaseDetails.pendingCompletePurchase) {
          await InAppPurchase.instance.completePurchase(purchaseDetails);
        }
        notifyListeners();
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(
    String productId, {
    DateTime? now,
    bool isRestored = false,
    DateTime? originalPurchaseDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final checkNow = now ?? DateTime.now();
    final period = periodDurationForProduct(productId);
    final purchasedAt = originalPurchaseDate ?? checkNow;
    DateTime expiresAt = purchasedAt.add(period);
    // 스토어에서 복원(restored) 이벤트가 전달되었다면 자동 갱신 중인 유효 구독이므로 최소 현재 시점 + 잔여 주기를 보장합니다.
    if (isRestored && !checkNow.isBefore(expiresAt)) {
      expiresAt = checkNow.add(period);
    }

    _isDebugUnlocked = false;
    _entitlements[productId] = PurchasedEntitlement(
      productId: productId,
      purchasedAt: purchasedAt,
      expiresAt: expiresAt,
      isSubscription: _kProductIds.contains(productId),
      isRestored: isRestored,
    );
    _expiredNotifiedProductIds.remove(productId);

    await _persistEntitlements(prefs);
    await _recomputeAccessFlags(prefs, now: checkNow);
    notifyListeners();
  }

  Future<List<ProductDetails>> fetchProducts() async {
    try {
      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        _storeProductsChecked = true;
        _storeQueryError = null;
        notifyListeners();
        return [];
      }
      final bool available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        _storeProductsChecked = true;
        _storeQueryError = 'Google Play 스토어 연결 불가';
        notifyListeners();
        return [];
      }

      final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(_kProductIds);
      _storeProducts.clear();
      for (final p in response.productDetails) {
        _storeProducts[p.id] = p;
      }
      _storeProductsChecked = true;
      _storeQueryError = response.error?.message;
      notifyListeners();
      return response.productDetails;
    } catch (e) {
      debugPrint('fetchProducts error: $e');
      _storeProductsChecked = true;
      _storeQueryError = e.toString();
      notifyListeners();
      return [];
    }
  }

  Future<({bool started, String? errorMessage})> buyProduct(String productId) async {
    try {
      await checkEntitlementExpirations();

      if (_pendingPurchaseProductId != null) {
        return (
          started: false,
          errorMessage: '${productDisplayName(_pendingPurchaseProductId!)} 결제가 처리 중입니다. 잠시만 기다려 주세요.',
        );
      }

      if (isProductActive(productId)) {
        final expiry = getProductExpiry(productId);
        final expiryMsg = expiry != null ? ' (${formatShortDate(expiry)} 기간 종료 후 재구매 가능)' : '';
        return (
          started: false,
          errorMessage: '이미 이용 중인 상품입니다.$expiryMsg',
        );
      }

      if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
        return (started: false, errorMessage: '인앱 결제는 모바일 기기(Google Play / App Store)에서만 지원됩니다.');
      }

      final available = await InAppPurchase.instance.isAvailable();
      if (!available) {
        return (started: false, errorMessage: 'Google Play 스토어에 연결할 수 없습니다. 로그인 및 네트워크 상태를 확인해 주세요.');
      }

      final response = await InAppPurchase.instance.queryProductDetails({productId});
      if (response.error != null) {
        return (started: false, errorMessage: '스토어 상품 조회 오류: ${response.error!.message}');
      }
      if (response.productDetails.isEmpty) {
        return (
          started: false,
          errorMessage: '스토어에 구독 상품($productId)이 아직 등록되지 않았거나 심사 중입니다.',
        );
      }

      final product = response.productDetails.first;
      final purchaseParam = PurchaseParam(productDetails: product);
      _pendingPurchaseProductId = productId;
      notifyListeners();

      final started = await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started && _pendingPurchaseProductId == productId) {
        _pendingPurchaseProductId = null;
        notifyListeners();
      }
      return (started: started, errorMessage: started ? null : '결제 창을 열지 못했습니다.');
    } catch (e) {
      if (_pendingPurchaseProductId == productId) {
        _pendingPurchaseProductId = null;
        notifyListeners();
      }
      debugPrint('buyProduct error: $e');
      return (started: false, errorMessage: '결제 요청 중 오류가 발생했습니다: $e');
    }
  }

  /// 스토어 구독 복원 및 로컬 이용 상태 동기화
  Future<({int restoredCount, bool hadError, String message})> restorePurchases({
    Duration settleDuration = const Duration(milliseconds: 1200),
    Future<void> Function()? platformRestoreOverride,
    DateTime? now,
  }) async {
    final checkNow = now ?? DateTime.now();
    _isRestoringPurchases = true;
    _restoreSessionProductIds.clear();
    _lastPurchaseMessage = null;
    notifyListeners();

    try {
      if (platformRestoreOverride == null) {
        if (kIsWeb || (!Platform.isAndroid && !Platform.isIOS)) {
          await checkEntitlementExpirations(now: checkNow);
          return (
            restoredCount: 0,
            hadError: true,
            message: '구독 복원은 모바일 기기(Google Play / App Store)에서 이용할 수 있습니다.',
          );
        }
        final available = await InAppPurchase.instance.isAvailable();
        if (!available) {
          await checkEntitlementExpirations(now: checkNow);
          return (
            restoredCount: 0,
            hadError: true,
            message: 'Google Play 스토어에 연결할 수 없어 로컬 이용 상태만 확인했습니다.',
          );
        }
      }

      await (platformRestoreOverride != null
          ? platformRestoreOverride()
          : InAppPurchase.instance.restorePurchases());

      if (settleDuration > Duration.zero) {
        await Future.delayed(settleDuration);
      }

      final restoredIds = Set<String>.from(_restoreSessionProductIds);
      bool expiredStaleLocal = false;

      if (!_isDebugUnlocked) {
        final prefs = await SharedPreferences.getInstance();
        for (final id in _kProductIds) {
          final existing = _entitlements[id];
          if (existing != null &&
              existing.isActiveAt(checkNow) &&
              !restoredIds.contains(id)) {
            _entitlements[id] = PurchasedEntitlement(
              productId: id,
              purchasedAt: existing.purchasedAt,
              expiresAt: checkNow,
              isSubscription: true,
              isRestored: existing.isRestored,
            );
            _expiredNotifiedProductIds.add(id);
            expiredStaleLocal = true;
          }
        }
        await _persistEntitlements(prefs);
        await _recomputeAccessFlags(prefs, now: checkNow);
      }

      await checkEntitlementExpirations(now: checkNow);

      if (_lastPurchaseMessage != null) {
        _lastStoreEventType = StoreEventType.error;
        _lastStoreNotice = _lastPurchaseMessage;
        return (
          restoredCount: restoredIds.length,
          hadError: true,
          message: _lastPurchaseMessage!,
        );
      }

      if (restoredIds.isNotEmpty) {
        final names = restoredIds.map(productDisplayName).join(', ');
        final msg = '구독 ${restoredIds.length}건($names)이 정상 복원되었습니다.';
        _lastStoreEventType = StoreEventType.restored;
        _lastStoreNotice = msg;
        return (restoredCount: restoredIds.length, hadError: false, message: msg);
      }

      final msg = expiredStaleLocal
          ? '스토어에 유효한 활성 구독이 없어 만료 상태로 동기화되었습니다.'
          : '복원할 활성 구독 내역이 없습니다.';
      _lastStoreEventType =
          expiredStaleLocal ? StoreEventType.expired : StoreEventType.none;
      _lastStoreNotice = msg;
      return (restoredCount: 0, hadError: false, message: msg);
    } catch (e) {
      debugPrint('restorePurchases error: $e');
      final msg = '구독 복원 중 오류가 발생했습니다: $e';
      _lastStoreEventType = StoreEventType.error;
      _lastStoreNotice = msg;
      return (restoredCount: 0, hadError: true, message: msg);
    } finally {
      _isRestoringPurchases = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _interstitialAd?.dispose();
    _appOpenAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    super.dispose();
  }
}
