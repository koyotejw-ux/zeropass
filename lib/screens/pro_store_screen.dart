import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/localization_service.dart';
import '../services/monetization_service.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import 'tablet_kiosk_screen.dart';

class ProStoreScreen extends StatefulWidget {
  const ProStoreScreen({super.key});

  @override
  State<ProStoreScreen> createState() => _ProStoreScreenState();
}

class _ProStoreScreenState extends State<ProStoreScreen> {
  Future<void> _startPurchase(String productId) async {
    final result = await MonetizationService.instance.buyProduct(productId);
    if (!result.started && mounted && result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _openPlaySubscriptions() async {
    final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Google Play 스토어 앱 > 프로필 > [결제 및 정기 결제]에서 관리하실 수 있습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isDomestic = LocalizationService.isDomestic;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        toolbarHeight: isLandscape ? 50 : 56,
        title: Text(
          LocalizationService.proStoreTitle,
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: isLandscape ? 18 : 20,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.4,
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ZeroButton.tint(
              label: LocalizationService.proStoreRestore,
              icon: Icons.restore_rounded,
              size: ZeroButtonSize.medium,
              onPressed: () async {
                await MonetizationService.instance.restorePurchases();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        isDomestic
                            ? '구독 구매 복원 처리가 완료되었습니다.'
                            : 'Subscription restore completed.',
                      ),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: MonetizationService.instance,
        builder: (context, _) {
          final bm = MonetizationService.instance;
          // 실제 구글 플레이 결제 기반 정기 구독 상태 (1시간 임시 패스 제외)
          final isSubNoAds = bm.isSubscriptionAdsRemoved;
          final isSubKiosk = bm.isSubscriptionKioskPro;
          final isSubAllInOne = bm.isSubscriptionAllInOne;
          final currencyFmt = NumberFormat('#,###');

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              isLandscape ? 6 : 10,
              16,
              isLandscape ? 36 : 90,
            ),
            children: [
              // 1. Pro Value Proposition Hero Card
              Container(
                padding: EdgeInsets.all(isLandscape ? 16 : 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Retention Tier & Streak Pill (Wrap for small viewport resilience)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_rounded, size: 13, color: Color(0xFFFBBF24)),
                              const SizedBox(width: 4),
                              Text(
                                bm.retentionTierTitle,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, size: 13, color: Color(0xFFF97316)),
                              const SizedBox(width: 4),
                              Text(
                                isDomestic
                                    ? '연속 ${bm.activeStreakDays}일 운영 중'
                                    : 'Active Day ${bm.activeStreakDays}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.diamond_rounded, color: Color(0xFFFBBF24), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSubAllInOne
                                    ? (isDomestic ? '올인원 VIP 정기 구독 이용 중' : 'All-in-One VIP Active')
                                    : (bm.isTemporaryPassActive
                                        ? (isDomestic ? '1시간 올인원 VIP 무료 체험 이용 중' : '1-Hour Free VIP Pass Active')
                                        : (isDomestic
                                            ? '지금까지 약 ${currencyFmt.format(bm.estimatedTotalSavedKRW)}원 절감!'
                                            : 'Smart Local Attendance & Billing')),
                                style: TextStyle(
                                  fontSize: isLandscape ? 16 : 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                softWrap: true,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isSubAllInOne
                                    ? (isDomestic
                                        ? '무인 태블릿 키오스크와 100% 광고 없는 최적의 매장 환경이 활성화되어 있습니다.'
                                        : 'Tablet kiosk and 100% ad-free experience are permanently active.')
                                    : (bm.isTemporaryPassActive
                                        ? (isDomestic
                                            ? '현재 1시간 무료 VIP 체험권이 작동 중입니다 (${bm.remainingTemporaryPassFormatted}). 마음에 드시면 아래 정기 플랜을 구독하세요.'
                                            : '1-Hour VIP Free Pass is active (${bm.remainingTemporaryPassFormatted}). Subscribe below for uninterrupted access.')
                                        : (isDomestic
                                            ? '무료 문자(${bm.cumulativeSavedSmsCount}건)와 자동 출결(${bm.cumulativeCheckInCount}건)로 아낀 운영비의 일부로 100% 쾌적한 VIP 매장을 완성하세요.'
                                            : 'Save telecom and server costs with autonomous on-device check-in and billing.')),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  height: 1.45,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ROI Comparison Strip (100% Full-Width)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            LocalizationService.proStoreComparisonOld,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            LocalizationService.proStoreComparisonNew,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Feature Pills: 2x2 Grid with 50%:50% Even Split for 100% Width
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildFeaturePill(
                                Icons.autorenew_rounded,
                                isDomestic ? '위약금 0원 즉시 해지' : 'Cancel Anytime',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFeaturePill(
                                Icons.tablet_android_rounded,
                                isDomestic ? '태블릿 출결 키오스크' : 'Tablet Kiosk Pass',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFeaturePill(
                                Icons.block_flipped,
                                isDomestic ? '광고 100% 완전 차단' : '100% Ad-Free Space',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFeaturePill(
                                Icons.verified_user_outlined,
                                isDomestic ? '구글 안전 정기 결제' : 'Google Play Billing',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1-B. Reverse-Trial Bridge Card (100% Full-Width Button)
              if (!isSubAllInOne) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isDomestic ? '결제 전 무료 VIP 체험' : 'Free VIP Trial',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bm.isTemporaryPassActive
                                  ? (isDomestic
                                      ? '1시간 VIP 패스 이용 중 (${bm.remainingTemporaryPassFormatted})'
                                      : '1-Hour VIP Active (${bm.remainingTemporaryPassFormatted})')
                                  : (isDomestic
                                      ? '광고 제거 & 태블릿 키오스크 1시간 무료'
                                      : 'Try 1-Hour Ad-Free Kiosk for Free'),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E40AF),
                              ),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        isDomestic
                            ? '광고 1회 시청 시 1시간 동안 광고 완전 제거 및 무인 키오스크를 즉시 이용합니다.'
                            : 'Watch one short video to unlock 1 hour of ad-free kiosk mode. Cancel or subscribe anytime.',
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      ZeroButton.primary(
                        label: bm.isTemporaryPassActive
                            ? (isDomestic ? '1시간 무료 체험 연장하기' : 'Extend 1-Hour VIP Pass')
                            : (isDomestic ? '1시간 무료 VIP 시작하기 (광고 1회)' : 'Start 1-Hour VIP Pass (1 Ad)'),
                        icon: Icons.play_circle_fill_rounded,
                        fullWidth: true,
                        size: ZeroButtonSize.large,
                        onPressed: () {
                          if (bm.isAnyRewardedAdAvailable) {
                            bm.showBestRewardedAd(
                              onRewarded: () async {
                                await bm.grantTemporaryAdFreeHours(1, includeKiosk: true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isDomestic
                                            ? '1시간 올인원 VIP 패스(광고 제거 + 키오스크)가 활성화되었습니다!'
                                            : '1-Hour All-in-One VIP Pass is active!',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              onFailed: () async {
                                await bm.grantTemporaryAdFreeHours(1, includeKiosk: true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        isDomestic
                                            ? '응원 혜택으로 1시간 올인원 VIP 패스가 즉시 지급되었습니다!'
                                            : '1-Hour All-in-One VIP Pass granted!',
                                      ),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            );
                          } else {
                            bm.grantTemporaryAdFreeHours(1, includeKiosk: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  isDomestic
                                      ? '1시간 올인원 VIP 패스(광고 제거 + 키오스크)가 즉시 활성화되었습니다!'
                                      : '1-Hour All-in-One VIP Pass is active!',
                                ),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],

              // 2. Section Title
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Text(
                      isDomestic ? '정기 구독 플랜 (Google Play)' : 'Subscription Plans (Google Play)',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ],
                ),
              ),

              // Plan 1: [Best] 올인원 VIP 패키지 (월간 ₩5,900 / 연간 ₩59,000)
              _buildStoreProductCard(
                context: context,
                badgeIcon: Icons.star_rounded,
                badgeText: isDomestic ? '가장 인기 있는 올인원 VIP' : 'Most Popular: All-in-One VIP',
                badgeColor: const Color(0xFFD97706),
                badgeBgColor: const Color(0xFFFEF3C7),
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFFD97706),
                title: isDomestic ? '올인원 VIP 패키지 구독 (추천)' : 'All-in-One VIP Pass (Recommended)',
                description: isDomestic
                    ? '무인 태블릿 키오스크 + 광고 완전 제거를 하나의 정기 구독으로 모두 누리는 최고 가성비 플랜입니다.'
                    : 'Tablet Kiosk + 100% Ad-Free experience combined into one convenient subscription.',
                features: isDomestic
                    ? const [
                        '안 쓰는 태블릿/휴대폰을 거치형 무인 출결기로 즉시 변신',
                        '학생/회원이 뒷번호 4자리 터치 시 1초 자동 출결 & 회차 차감',
                        '관리자 4자리 암호 잠금 및 비상 탈출 방지 장치',
                        '앱 내 모든 배너 및 전면 광고 완전 차단',
                        '기기 변경 시에도 구글 계정으로 원클릭 구독 복원',
                      ]
                    : const [
                        'Transform any tablet into an entrance attendance kiosk',
                        'Instant 4-digit check-in and session deduction',
                        'PIN-protected admin exit lock system',
                        '100% ad-free app experience',
                        'One-click Google Play subscription restore across devices',
                      ],
                priceText: isDomestic ? '₩5,900 / 월' : '\$4.99 / mo',
                priceSubtext: isDomestic
                    ? '또는 연간 결제 시 ₩59,000 / 년 (2개월 할인)'
                    : 'Or save 2 months with annual billing (\$49.99/year)',
                isUnlocked: isSubAllInOne,
                actionButtonText: isSubAllInOne
                    ? (isDomestic ? 'VIP 이용 중 (키오스크 바로가기)' : 'VIP Active (Launch Kiosk)')
                    : (isDomestic ? '올인원 VIP 구독 시작 (₩5,900/월)' : 'Start All-in-One VIP (\$4.99/mo)'),
                actionIcon: isSubAllInOne ? Icons.tablet_mac_rounded : Icons.star_rounded,
                secondaryButtonText: isSubAllInOne
                    ? null
                    : (isDomestic
                        ? '연간 구독 2개월 할인 (₩59,000/년)'
                        : 'Save 2 Months with Annual Plan (\$49.99/yr)'),
                onAction: () {
                  if (isSubAllInOne) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TabletKioskScreen()),
                    );
                  } else {
                    _startPurchase(MonetizationService.productIdAllInOneMonthly);
                  }
                },
                onSecondaryAction: isSubAllInOne
                    ? null
                    : () {
                        _startPurchase(MonetizationService.productIdAllInOneYearly);
                      },
              ),
              const SizedBox(height: 18),

              // Plan 2: 태블릿 자율출결 키오스크 단독 구독 (월 ₩4,900)
              _buildStoreProductCard(
                context: context,
                badgeIcon: Icons.tablet_mac_rounded,
                badgeText: isDomestic ? '태블릿 무인 출결 전용' : 'Tablet Kiosk Only',
                badgeColor: const Color(0xFF2563EB),
                badgeBgColor: const Color(0xFFEFF6FF),
                icon: Icons.tablet_mac_rounded,
                iconColor: const Color(0xFF2563EB),
                title: isDomestic ? '태블릿 키오스크 단독 구독' : 'Tablet Kiosk Standalone',
                description: isDomestic
                    ? '학원·공방·피트니스 센터 입구 공기계 태블릿에 거치해두고 회원들이 자율 출석 체크하는 기능만 가볍게 구독하세요.'
                    : 'Place an extra tablet at your studio entrance for autonomous self check-ins.',
                features: isDomestic
                    ? const [
                        '입구 거치형 무인 출결 키오스크 단독 무제한 이용',
                        '회원 뒷번호 4자리 터치 출결 & 자동 회차 차감',
                        '관리자 설정 잠금 비밀번호 보호',
                        '정기 결제로 가볍게 시작하고 원할 때 해지',
                      ]
                    : const [
                        'Unlimited entrance self-check-in kiosk mode',
                        '4-digit number touch check-in & auto session deduction',
                        'Admin PIN lock security protection',
                        'Flexible monthly subscription, cancel anytime',
                      ],
                priceText: isSubKiosk
                    ? (isDomestic ? '키오스크 이용 중' : 'Kiosk Active (Subscribed)')
                    : (isDomestic ? '₩4,900 / 월' : '\$3.99 / mo'),
                priceSubtext: isDomestic
                    ? '구글 플레이 매월 자동 갱신 (언제든 취소 가능)'
                    : 'Google Play auto-renewal (Cancel anytime)',
                isUnlocked: isSubKiosk,
                actionButtonText: isSubKiosk
                    ? (isDomestic ? '키오스크 바로 실행' : 'Launch Kiosk Mode')
                    : (isDomestic ? '키오스크 구독 시작 (₩4,900/월)' : 'Start Kiosk Subscription (\$3.99/mo)'),
                actionIcon: Icons.tablet_mac_rounded,
                onAction: () {
                  if (isSubKiosk) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TabletKioskScreen()),
                    );
                  } else {
                    _startPurchase(MonetizationService.productIdKioskMonthly);
                  }
                },
              ),
              const SizedBox(height: 18),

              // Plan 3: 광고 제거 단독 구독 (월 ₩1,900 - 한 달)
              _buildStoreProductCard(
                context: context,
                badgeIcon: Icons.block_flipped,
                badgeText: isDomestic ? '광고 없는 쾌적함' : 'Ad-Free Experience',
                badgeColor: const Color(0xFF059669),
                badgeBgColor: const Color(0xFFECFDF5),
                icon: Icons.block_flipped,
                iconColor: const Color(0xFF059669),
                title: isDomestic ? '광고 제거 단독 구독' : 'Remove Ads Standalone',
                description: isDomestic
                    ? '하단 배너 및 팝업 광고를 완전히 없애 화면을 널찍하고 쾌적하게 사용하고 싶을 때 추천합니다.'
                    : 'Remove all bottom banner ads and enjoy a clean, wide workspace.',
                features: isDomestic
                    ? const [
                        '하단 광고 배너 완전 숨김',
                        '가로/세로 화면 공간 100% 온전 활용',
                        '월 1,900원(한 달 구독)으로 쾌적한 장부 관리',
                      ]
                    : const [
                        'Completely hide bottom banner ads',
                        '100% full screen utilization in portrait & landscape',
                        'Affordable monthly pass (\$1.49/mo)',
                      ],
                priceText: isSubNoAds
                    ? (isDomestic ? '광고 제거 이용 중' : 'Ad-Free Active (Subscribed)')
                    : (isDomestic ? '₩1,900 / 월 (한 달)' : '\$1.49 / mo (1 Month)'),
                priceSubtext: isDomestic
                    ? '부담 없는 한 달 정기 구독 (언제든 구글 플레이에서 해지)'
                    : 'Affordable monthly subscription (Cancel anytime)',
                isUnlocked: isSubNoAds,
                actionButtonText: isSubNoAds
                    ? (isDomestic ? '광고 제거 이용 중' : 'Ad-Free Active')
                    : (isDomestic ? '광고 제거 한 달 구독 (월 ₩1,900)' : 'Subscribe to Remove Ads (\$1.49/mo)'),
                actionIcon: Icons.block_flipped,
                onAction: () {
                  if (!isSubNoAds) {
                    _startPurchase(MonetizationService.productIdRemoveAdsMonthly);
                  }
                },
              ),
              const SizedBox(height: 22),

              // 3. Subscription Management Notice (100% Full-Width Card & CTA Button)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          isDomestic ? '정기 구독 안내 및 해지 방법' : 'Subscription Terms & Cancellation',
                          style: const TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isDomestic
                          ? '• 모든 플랜은 구글 플레이(Google Play) 공식 정기 결제로 안전하게 결제됩니다.\n• 언제든지 [Google Play 스토어 앱 > 우측 상단 프로필 > 결제 및 정기 결제]에서 터치 한 번으로 위약금 없이 즉시 해지하실 수 있습니다.\n• 스마트폰을 교체하거나 재설치하셔도 상단 [구독 복원] 버튼으로 이용 권한이 즉시 동기화됩니다.'
                          : '• All subscriptions are securely billed through Google Play.\n• You can cancel anytime without penalties in Google Play Store > Profile > Payments & subscriptions.\n• Easily restore your purchase anytime with the [Restore Purchases] button.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ZeroButton.secondary(
                      label: isDomestic ? 'Google Play 정기 결제 관리' : 'Manage Google Play Subscriptions',
                      icon: Icons.open_in_new_rounded,
                      fullWidth: true,
                      size: ZeroButtonSize.medium,
                      onPressed: _openPlaySubscriptions,
                    ),
                  ],
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 18),

                // Developer Testing Unlock & Reset Row (Debug mode only)
                Row(
                  children: [
                    Expanded(
                      child: ZeroButton.tint(
                        label: isDomestic ? '[테스트] 전체 언락' : '[Test] Unlock All',
                        icon: Icons.flash_on_rounded,
                        size: ZeroButtonSize.medium,
                        fullWidth: true,
                        onPressed: () {
                          MonetizationService.instance.debugUnlockAll();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isDomestic
                                    ? '[테스트용] 모든 PRO 구독 기능이 활성화되었습니다.'
                                    : '[Test] All PRO features unlocked.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ZeroButton.tint(
                        label: isDomestic ? '[테스트] 초기화' : '[Test] Reset All',
                        icon: Icons.refresh_rounded,
                        size: ZeroButtonSize.medium,
                        fullWidth: true,
                        onPressed: () {
                          MonetizationService.instance.debugResetAll();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                isDomestic
                                    ? '[테스트용] 모든 구독과 체험권이 초기화되었습니다 (무료 모드).'
                                    : '[Test] All subscriptions and trial passes reset.',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFBBF24)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreProductCard({
    required BuildContext context,
    IconData? badgeIcon,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBgColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> features,
    required String priceText,
    required String priceSubtext,
    required bool isUnlocked,
    required String actionButtonText,
    IconData? actionIcon,
    required VoidCallback onAction,
    String? secondaryButtonText,
    VoidCallback? onSecondaryAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFF10B981)
              : const Color(0xFFE2E8F0),
          width: isUnlocked ? 1.8 : 1.0,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Badge & Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeBgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeIcon != null) ...[
                      Icon(badgeIcon, size: 14, color: badgeColor),
                      const SizedBox(width: 5),
                    ],
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title & Description
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Features List
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_rounded, size: 15, color: AppTheme.softMint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderSubtle, height: 1),
          const SizedBox(height: 14),

          // Price & Subtext
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                priceText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isUnlocked ? const Color(0xFF059669) : const Color(0xFFD97706),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                priceSubtext,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Action Button (100% Full Width)
          ZeroButton.primary(
            label: actionButtonText,
            icon: isUnlocked ? Icons.check_circle_rounded : actionIcon,
            fullWidth: true,
            size: ZeroButtonSize.large,
            onPressed: onAction,
          ),

          // Optional Secondary Action Button (100% Full Width)
          if (secondaryButtonText != null && onSecondaryAction != null) ...[
            const SizedBox(height: 10),
            ZeroButton.secondary(
              label: secondaryButtonText,
              icon: Icons.savings_rounded,
              fullWidth: true,
              size: ZeroButtonSize.large,
              onPressed: onSecondaryAction,
            ),
          ],
        ],
      ),
    );
  }
}
