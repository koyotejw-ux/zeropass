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

/// 최고 수익률(High eCPM)을 위한 AdMob 전면/오프닝/보상형/배너 통합 관리 서비스
class MonetizationService extends ChangeNotifier with WidgetsBindingObserver {
  static final MonetizationService instance = MonetizationService._internal();
  MonetizationService._internal();

  // In-App Product IDs (100% Recurring Subscriptions)
  static const String productSubRemoveAdsMonthly = 'zeropass_sub_ads_monthly'; // 광고 제거 월간 (₩1,900/월)
  static const String productSubKioskMonthly = 'zeropass_sub_kiosk_monthly'; // 태블릿 키오스크 월간 (₩4,900/월)
  static const String productSubAllInOneMonthly = 'zeropass_sub_vip_monthly'; // 올인원 VIP 패키지 월간 (₩5,900/월)
  static const String productSubAllInOneYearly = 'zeropass_sub_vip_yearly'; // 올인원 VIP 패키지 연간 (₩59,000/년)

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

  bool _isAdsRemoved = false;
  bool _isKioskProUnlocked = false;
  DateTime? _rewardedAdFreeUntil;
  DateTime? _rewardedKioskPassUntil;

  // 선순환 리텐션 & 누적 ROI 가치 측정 지표 (Retention Flywheel Metrics)
  int _activeStreakDays = 1;
  String? _lastActiveDateStr;
  int _cumulativeSavedSmsCount = 128; // 안심 문자/청구서 발송 누적 건수 (기본 시드 + 실사용 누적)
  int _cumulativeCheckInCount = 342; // 누적 출결 처리 건수
  int _cumulativeTaxLedgerCount = 18; // 누적 세무/정산 자동화 건수

  bool get isAdsRemoved {
    if (_isAdsRemoved) return true;
    if (_rewardedAdFreeUntil != null && DateTime.now().isBefore(_rewardedAdFreeUntil!)) {
      return true;
    }
    return false;
  }

  bool get isKioskProUnlocked {
    if (_isKioskProUnlocked) return true;
    if (_rewardedKioskPassUntil != null && DateTime.now().isBefore(_rewardedKioskPassUntil!)) {
      return true;
    }
    return false;
  }

  bool get isPermanentVip => _isAdsRemoved && _isKioskProUnlocked;

  /// 실제 구글 플레이 광고 제거 정기 구독 여부 (임시 1시간 무료 패스 제외)
  bool get isSubscriptionAdsRemoved => _isAdsRemoved;

  /// 실제 구글 플레이 키오스크 정기 구독 여부 (임시 1시간 무료 패스 제외)
  bool get isSubscriptionKioskPro => _isKioskProUnlocked;

  /// 실제 구글 플레이 올인원 정기 구독 여부 (임시 1시간 무료 패스 제외)
  bool get isSubscriptionAllInOne => _isAdsRemoved && _isKioskProUnlocked;

  /// 올인원 VIP 무제한 이용 가능 여부 (정기 구독 VIP 또는 1시간 무료 VIP 체험 패스 포함)
  bool get isUnlimitedVip => isPermanentVip || isTemporaryPassActive;

  /// 단일 기능 구독(광고 제거 단독 또는 키오스크 단독)만 활성화된 상태 여부 (비-VIP 제한 플랜)
  bool get isStandalonePaidPlan => !isUnlimitedVip && (isAdsRemoved || isKioskProUnlocked);

  String get membershipPlanLabel {
    if (isPermanentVip) return '올인원 VIP 멤버십 (무제한)';
    if (isTemporaryPassActive) return '1시간 VIP 무료 체험 (무제한)';
    if (_isAdsRemoved) return '광고 제거 단독 (제한형)';
    if (_isKioskProUnlocked) return '키오스크 단독 (제한형)';
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

  Future<void> debugUnlockAll() async {
    await setDebugUnlock(adsRemoved: true, kioskPro: true);
  }

  /// 개발/검수용 모든 구독 초기화 (무료 체험 및 구독 전체 리셋)
  Future<void> debugResetAll() async {
    await setDebugUnlock(adsRemoved: false, kioskPro: false);
    _rewardedAdFreeUntil = null;
    _rewardedKioskPassUntil = null;
    _lastInterstitialShownTime = null;
    _lastUpsellDialogShownTime = null;
    _crudAdExposureCount = 0;
    _monthlyEditCount = 0;
    _editCountMonthKey = _currentMonthKey();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('rewarded_ad_free_until');
    await prefs.remove('rewarded_kiosk_pass_until');
    await prefs.setInt('bm_monthly_edit_count', 0);
    await prefs.setString('bm_monthly_edit_month', _editCountMonthKey);
    notifyListeners();
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

  /// 보상형 광고 시청 후 N시간 동안 광고 제거 + 태블릿 키오스크 VIP 혜택 부여 (Reverse-Trial Funnel)
  Future<void> grantTemporaryAdFreeHours(int hours, {bool includeKiosk = true}) async {
    final expiry = DateTime.now().add(Duration(hours: hours));
    _rewardedAdFreeUntil = expiry;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('rewarded_ad_free_until', expiry.toIso8601String());
    if (includeKiosk) {
      _rewardedKioskPassUntil = expiry;
      await prefs.setString('rewarded_kiosk_pass_until', expiry.toIso8601String());
    }
    premiumStatusNotifier.value = true;
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
    _isAdsRemoved = prefs.getBool('is_ads_removed') ?? false;
    _isKioskProUnlocked = prefs.getBool('is_kiosk_pro_unlocked') ?? false;
    _cumulativeSavedSmsCount = prefs.getInt('bm_saved_sms_count') ?? 128;
    _cumulativeCheckInCount = prefs.getInt('bm_checkin_count') ?? 342;
    _cumulativeTaxLedgerCount = prefs.getInt('bm_tax_count') ?? 18;
    _activeStreakDays = prefs.getInt('bm_active_streak_days') ?? 7;
    _lastActiveDateStr = prefs.getString('bm_last_active_date');
    await _updateDailyStreak(prefs);
    await _syncMonthlyEditCounter(prefs);

    final adFreeStr = prefs.getString('rewarded_ad_free_until');
    if (adFreeStr != null) {
      final expiry = DateTime.tryParse(adFreeStr);
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        _rewardedAdFreeUntil = expiry;
      }
    }

    final kioskPassStr = prefs.getString('rewarded_kiosk_pass_until');
    if (kioskPassStr != null) {
      final expiry = DateTime.tryParse(kioskPassStr);
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        _rewardedKioskPassUntil = expiry;
      }
    }

    premiumStatusNotifier.value = isAdsRemoved;

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
                  secondary: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(dlgCtx);
                      showBestRewardedAd(
                        onRewarded: () async {
                          await grantTemporaryAdFreeHours(1, includeKiosk: true);
                          final snackCtx = rootNavigatorKey.currentContext;
                          if (snackCtx != null && snackCtx.mounted) {
                            ScaffoldMessenger.of(snackCtx).showSnackBar(
                              const SnackBar(
                                content: Text('1시간 동안 모든 CRUD/배너 광고가 제거되었습니다!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        onFailed: () {
                          Navigator.of(context, rootNavigator: true).push(
                            MaterialPageRoute(builder: (_) => const ProStoreScreen()),
                          );
                        },
                      );
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
                  ),
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
                secondary: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(dlgCtx);
                    showBestRewardedAd(
                      onRewarded: () async {
                        await grantTemporaryAdFreeHours(1, includeKiosk: true);
                        final snackCtx = rootNavigatorKey.currentContext;
                        if (snackCtx != null && snackCtx.mounted) {
                          ScaffoldMessenger.of(snackCtx).showSnackBar(
                            const SnackBar(
                              content: Text('1시간 VIP 무제한 체험권이 활성화되었습니다!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      onFailed: () {
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(builder: (_) => const ProStoreScreen()),
                        );
                      },
                    );
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
                ),
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

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
        _lastPurchaseMessage = null;
        _handleSuccessfulPurchase(purchaseDetails.productID);
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
      } else if (purchaseDetails.status == PurchaseStatus.error) {
        _lastPurchaseMessage = purchaseDetails.error?.message ?? '결제 처리 중 오류가 발생했습니다.';
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
        notifyListeners();
      } else if (purchaseDetails.status == PurchaseStatus.canceled) {
        _lastPurchaseMessage = '결제가 취소되었습니다.';
        if (purchaseDetails.pendingCompletePurchase) {
          InAppPurchase.instance.completePurchase(purchaseDetails);
        }
        notifyListeners();
      }
    }
  }

  Future<void> _handleSuccessfulPurchase(String productId) async {
    final prefs = await SharedPreferences.getInstance();
    if (productId == productSubRemoveAdsMonthly) {
      _isAdsRemoved = true;
      await prefs.setBool('is_ads_removed', true);
      premiumStatusNotifier.value = true;
    } else if (productId == productSubKioskMonthly) {
      _isKioskProUnlocked = true;
      await prefs.setBool('is_kiosk_pro_unlocked', true);
    } else if (productId == productSubAllInOneMonthly || productId == productSubAllInOneYearly) {
      _isAdsRemoved = true;
      _isKioskProUnlocked = true;
      await prefs.setBool('is_ads_removed', true);
      await prefs.setBool('is_kiosk_pro_unlocked', true);
      premiumStatusNotifier.value = true;
    }
    notifyListeners();
  }

  Future<List<ProductDetails>> fetchProducts() async {
    final bool available = await InAppPurchase.instance.isAvailable();
    if (!available) return [];

    final ProductDetailsResponse response = await InAppPurchase.instance.queryProductDetails(_kProductIds);
    return response.productDetails;
  }

  Future<({bool started, String? errorMessage})> buyProduct(String productId) async {
    try {
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
      final started = await InAppPurchase.instance.buyNonConsumable(purchaseParam: purchaseParam);
      return (started: started, errorMessage: started ? null : '결제 창을 열지 못했습니다.');
    } catch (e) {
      debugPrint('buyProduct error: $e');
      return (started: false, errorMessage: '결제 요청 중 오류가 발생했습니다: $e');
    }
  }

  Future<void> restorePurchases() async {
    await InAppPurchase.instance.restorePurchases();
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
