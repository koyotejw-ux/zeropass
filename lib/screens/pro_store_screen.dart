import 'package:flutter/material.dart';
import '../services/monetization_service.dart';
import '../theme/app_theme.dart';
import 'tablet_kiosk_screen.dart';

class ProStoreScreen extends StatefulWidget {
  const ProStoreScreen({super.key});

  @override
  State<ProStoreScreen> createState() => _ProStoreScreenState();
}

class _ProStoreScreenState extends State<ProStoreScreen> {
  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Luxury Pro Theme
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        toolbarHeight: isLandscape ? 50 : 56,
        title: Text(
          'PRO 멤버십 구독',
          style: TextStyle(
            color: Colors.white,
            fontSize: isLandscape ? 17 : 19,
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await MonetizationService.instance.restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('구독 구매 복원 처리가 완료되었습니다.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.restore, size: 15, color: Color(0xFF94A3B8)),
            label: const Text(
              '구독 복원',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: AnimatedBuilder(
        animation: MonetizationService.instance,
        builder: (context, _) {
          final isNoAds = MonetizationService.instance.isAdsRemoved;
          final isKiosk = MonetizationService.instance.isKioskProUnlocked;
          final isAllInOne = isNoAds && isKiosk;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              isLandscape ? 6 : 12,
              16,
              isLandscape ? 36 : 90,
            ),
            children: [
              // 1. Pro Value Proposition Hero Card (100% Subscription Focus)
              Container(
                padding: EdgeInsets.all(isLandscape ? 16 : 20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFF59E0B).withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
                      blurRadius: 20,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.diamond_rounded, color: Color(0xFFFBBF24), size: 26),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isAllInOne
                                    ? '대표님은 올인원 VIP 구독 이용 중'
                                    : '부담 없는 월정액 구독 멤버십',
                                style: TextStyle(
                                  fontSize: isLandscape ? 15 : 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isAllInOne
                                    ? '태블릿 키오스크와 광고 없는 최적의 매장 환경이 활성화되어 있습니다.'
                                    : '월 커피 한두 잔 비용으로 학원/매장의 출결과 장부를 스마트하게 혁신하세요.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildFeaturePill(Icons.autorenew_rounded, '언제든 위약금 0원 해지'),
                        _buildFeaturePill(Icons.tablet_android_rounded, '공기계 태블릿 키오스크'),
                        _buildFeaturePill(Icons.block_flipped, '100% 광고 없는 쾌적함'),
                        _buildFeaturePill(Icons.verified_user_outlined, '구글 플레이 안전 정기결제'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // 2. Section Title
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 10),
                child: Text(
                  '월간 정기 구독 플랜 (구글 플레이)',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),

              // Plan 1: [Best] 올인원 VIP 패키지 (월간 ₩5,900 / 연간 ₩59,000)
              _buildStoreProductCard(
                context: context,
                badgeIcon: Icons.star_rounded,
                badgeText: '가장 인기 있는 올인원 VIP',
                badgeColor: const Color(0xFFF59E0B),
                icon: Icons.auto_awesome_rounded,
                iconColor: const Color(0xFFFBBF24),
                title: '올인원 VIP 패키지 구독 (추천)',
                description: '무인 태블릿 키오스크 + 광고 완전 제거를 하나의 정기 구독으로 모두 누리는 최고 가성비 플랜입니다.',
                features: const [
                  '안 쓰는 태블릿/휴대폰을 거치형 무인 출결기로 즉시 변신',
                  '학생/회원이 뒷번호 4자리 터치 시 1초 자동 출결 & 회차 차감',
                  '관리자 4자리 암호 잠금 및 비상 탈출 방지 장치',
                  '앱 내 모든 배너 및 전면 광고 완전 차단',
                  '기기 변경 시에도 구글 계정으로 원클릭 구독 복원',
                ],
                priceText: '₩5,900 / 월',
                priceSubtext: '또는 연간 결제 시 ₩59,000 / 년 (2개월 무료 혜택)',
                isUnlocked: isAllInOne,
                actionButtonText: isAllInOne ? 'VIP 구독 활성화 완료 (이용 중)' : '올인원 VIP 구독 시작하기 (₩5,900/월)',
                secondaryButtonText: isAllInOne ? null : '연간 구독으로 2개월 할인받기 (₩59,000/년)',
                onAction: () {
                  if (isAllInOne) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TabletKioskScreen()),
                    );
                  } else {
                    MonetizationService.instance.buyProduct(MonetizationService.productIdAllInOneMonthly);
                  }
                },
                onSecondaryAction: isAllInOne
                    ? null
                    : () {
                        MonetizationService.instance.buyProduct(MonetizationService.productIdAllInOneYearly);
                      },
              ),
              const SizedBox(height: 16),

              // Plan 2: 태블릿 자율출결 키오스크 단독 구독 (월 ₩4,900)
              _buildStoreProductCard(
                context: context,
                badgeIcon: Icons.tablet_mac_rounded,
                badgeText: '태블릿 무인 출결 전용',
                badgeColor: const Color(0xFF3B82F6),
                icon: Icons.tablet_mac_rounded,
                iconColor: const Color(0xFF60A5FA),
                title: '태블릿 키오스크 단독 구독',
                description: '학원·공방·피트니스 센터 입구 공기계 태블릿에 거치해두고 회원들이 자율 출석 체크하는 기능만 가볍게 구독하세요.',
                features: const [
                  '입구 거치형 무인 출결 키오스크 단독 무제한 이용',
                  '회원 뒷번호 4자리 터치 출결 & 자동 회차 차감',
                  '관리자 설정 잠금 비밀번호 보호',
                  '정기 결제로 가볍게 시작하고 원할 때 해지',
                ],
                priceText: isKiosk ? '키오스크 활성화 완료 (이용 중)' : '₩4,900 / 월',
                priceSubtext: '구글 플레이 매월 자동 갱신 (언제든 취소 가능)',
                isUnlocked: isKiosk,
                actionButtonText: isKiosk ? '키오스크 모드 바로 실행' : '키오스크 구독 시작하기 (₩4,900/월)',
                onAction: () {
                  if (isKiosk) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TabletKioskScreen()),
                    );
                  } else {
                    MonetizationService.instance.buyProduct(MonetizationService.productIdKioskMonthly);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Plan 3: 광고 제거 단독 구독 (월 ₩1,900)
              _buildStoreProductCard(
                context: context,
                badgeIcon: Icons.block_flipped,
                badgeText: '광고 없는 쾌적함',
                badgeColor: const Color(0xFF10B981),
                icon: Icons.block_flipped,
                iconColor: const Color(0xFF34D399),
                title: '광고 제거 단독 구독',
                description: '하단 배너 및 팝업 광고를 완전히 없애 화면을 널찍하고 쾌적하게 사용하고 싶으신 대표님께 추천합니다.',
                features: const [
                  '하단 광고 배너 완전 숨김',
                  '가로/세로 화면 공간 100% 온전 활용',
                  '월 커피 반 잔 가격으로 쾌적한 장부 관리',
                ],
                priceText: isNoAds ? '광고 제거 활성화 완료 (이용 중)' : '₩1,900 / 월',
                priceSubtext: '부담 없는 월정액 (언제든 구글 플레이에서 해지)',
                isUnlocked: isNoAds,
                actionButtonText: isNoAds ? '광고 제거 구독 중' : '광고 제거 구독하기 (₩1,900/월)',
                onAction: () {
                  if (!isNoAds) {
                    MonetizationService.instance.buyProduct(MonetizationService.productIdRemoveAdsMonthly);
                  }
                },
              ),
              const SizedBox(height: 18),

              // 3. Subscription Management Notice
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFF334155)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.help_outline, color: AppTheme.softMint, size: 18),
                        SizedBox(width: 8),
                        Text(
                          '정기 구독 안내 및 해지 방법',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 모든 플랜은 구글 플레이(Google Play) 공식 정기 결제로 안전하게 결제됩니다.\n• 언제든지 [Google Play 스토어 앱 > 우측 상단 프로필 > 결제 및 정기 결제]에서 터치 한 번으로 위약금 없이 즉시 해지하실 수 있습니다.\n• 스마트폰을 교체하거나 재설치하셔도 상단 [구독 복원] 버튼으로 이용 권한이 즉시 동기화됩니다.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Developer Testing Unlock Button
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    MonetizationService.instance.debugUnlockAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('[테스트용] 모든 PRO 구독 기능이 활성화되었습니다.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF64748B)),
                  label: const Text(
                    '개발/검수용 전체 구독 기능 언락 (스토어 심사용)',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: const Color(0xFFFBBF24)),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.white,
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
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> features,
    required String priceText,
    required String priceSubtext,
    required bool isUnlocked,
    required String actionButtonText,
    required VoidCallback onAction,
    String? secondaryButtonText,
    VoidCallback? onSecondaryAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : const Color(0xFF334155),
          width: isUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Badge & Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (badgeIcon != null) ...[
                      Icon(badgeIcon, size: 12, color: badgeColor),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      badgeText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: badgeColor,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 20, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Title & Description
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            style: TextStyle(
              fontSize: 12.5,
              color: Colors.white.withValues(alpha: 0.7),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),

          // Features List
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 5),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check, size: 13, color: AppTheme.softMint),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 12),

          // Price & Subtext with Wrap to prevent right overflow
          Wrap(
            direction: Axis.vertical,
            spacing: 2,
            children: [
              Text(
                priceText,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: isUnlocked ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                priceSubtext,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Primary Action Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnlocked
                    ? const Color(0xFF065F46)
                    : const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                elevation: 0,
              ),
              child: Text(
                actionButtonText,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
              ),
            ),
          ),

          // Optional Secondary Action Button (e.g. Yearly discount)
          if (secondaryButtonText != null && onSecondaryAction != null) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: onSecondaryAction,
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFF59E0B)),
                  foregroundColor: const Color(0xFFFBBF24),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(
                  secondaryButtonText,
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
