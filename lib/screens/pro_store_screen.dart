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
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFF59E0B), Color(0xFFD97706)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.workspace_premium_rounded, color: Colors.white, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'PRO 샵',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              '멤버십 & 소장권',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await MonetizationService.instance.restorePurchases();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('구매 복원 처리가 완료되었습니다.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            icon: const Icon(Icons.restore, size: 16, color: Color(0xFF94A3B8)),
            label: const Text(
              '구매 복원',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: AnimatedBuilder(
        animation: MonetizationService.instance,
        builder: (context, _) {
          final isNoAds = MonetizationService.instance.isAdsRemoved;
          final isKiosk = MonetizationService.instance.isKioskProUnlocked;

          return ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              isLandscape ? 8 : 14,
              18,
              isLandscape ? 40 : 90,
            ),
            children: [
              // 1. Pro Value Proposition Hero Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E293B), Color(0xFF334155)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
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
                                isNoAds && isKiosk
                                    ? '대표님은 영구 VIP 회원입니다 👑'
                                    : '원장님을 위한 1회 결제 평생 소장권',
                                style: const TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                isNoAds && isKiosk
                                    ? '태블릿 키오스크와 광고 없는 쾌적한 환경이 모두 활성화되어 있습니다.'
                                    : '매달 나가는 고정 서버비 없이, 한 번 결제하면 영구히 내 폰에 보관됩니다.',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.7),
                                  height: 1.4,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildFeaturePill(Icons.check_circle_rounded, '월 서버 유지비 0원'),
                        _buildFeaturePill(Icons.tablet_android_rounded, '공기계 태블릿 키오스크'),
                        _buildFeaturePill(Icons.block_flipped, '광고 완전 차단'),
                        _buildFeaturePill(Icons.lock_rounded, '기기 로컬 100% 암호화'),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Product Items
              const Padding(
                padding: EdgeInsets.only(left: 4, bottom: 12),
                child: Text(
                  '프리미엄 기능 패키지',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFE2E8F0),
                  ),
                ),
              ),

              // Product 1: 태블릿 자율출결 키오스크 PRO (1회 결제 평생)
              _buildStoreProductCard(
                context: context,
                badgeText: '인기 No.1 영구 소장',
                badgeColor: const Color(0xFFF59E0B),
                icon: Icons.tablet_mac_rounded,
                iconColor: const Color(0xFF60A5FA),
                title: '태블릿 자율출결 키오스크 PRO',
                description: '학원·공방·센터 입구에 안 쓰는 공기계 태블릿을 거치하고, 회원들이 뒷번호 4자리로 스스로 출결 체크하는 완벽 무인 모드입니다.',
                features: const [
                  '안 쓰는 태블릿/휴대폰을 거치형 무인 출결기로 즉시 변신',
                  '학생/회원이 전화번호 뒤 4자리 터치 시 1초 자동 출결 & 회차 차감',
                  '관리자 4자리 암호 잠금 및 비상 탈출 방지 장치',
                  '월 관리비 없는 평생 영구 라이선스',
                ],
                priceText: isKiosk ? '활성화 완료 (영구 소장)' : '₩19,900',
                priceSubtext: isKiosk ? '언제든 무제한 이용 가능' : '1회 결제 후 평생 소장 (월 결제 없음)',
                isUnlocked: isKiosk,
                actionButtonText: isKiosk ? '키오스크 모드 바로 열기 🚀' : '키오스크 모드 평생 소장하기',
                onAction: () {
                  if (isKiosk) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TabletKioskScreen()),
                    );
                  } else {
                    MonetizationService.instance.buyProduct(MonetizationService.productIdKioskPro);
                  }
                },
              ),
              const SizedBox(height: 18),

              // Product 2: 평생 광고 제거권
              _buildStoreProductCard(
                context: context,
                badgeText: '원장님 추천',
                badgeColor: const Color(0xFF10B981),
                icon: Icons.block_flipped,
                iconColor: const Color(0xFF34D399),
                title: '평생 광고 제거권 (광고 프리)',
                description: '하단 배너 및 앱 내 모든 광고를 완벽하게 영구 제거하여 앱 실행 속도를 200% 높이고 더욱 쾌적하게 사용하세요.',
                features: const [
                  '하단 광고 배너 완전 영구 제거',
                  '모든 화면 수직 높이 100% 최적화 (가로/세로 최적 뷰)',
                  '기기 변경 시에도 구글 계정으로 원클릭 복원',
                ],
                priceText: isNoAds ? '활성화 완료 (영구 소장)' : '₩9,900',
                priceSubtext: isNoAds ? '광고 없이 쾌적하게 사용 중' : '평생 영구 소장 (추가 요금 없음)',
                isUnlocked: isNoAds,
                actionButtonText: isNoAds ? '광고 제거 활성화됨 ✨' : '평생 광고 제거권 구매하기',
                onAction: () {
                  if (!isNoAds) {
                    MonetizationService.instance.buyProduct(MonetizationService.productIdRemoveAdsLifetime);
                  }
                },
              ),
              const SizedBox(height: 18),

              // Product 3: 월간 광고 제거 구독권
              if (!isNoAds) ...[
                _buildStoreProductCard(
                  context: context,
                  badgeText: '가벼운 월정액',
                  badgeColor: const Color(0xFF64748B),
                  icon: Icons.autorenew_rounded,
                  iconColor: const Color(0xFF94A3B8),
                  title: '월간 광고 제거 구독',
                  description: '부담 없는 커피 1/3잔 가격으로 한 달간 광고 없이 쾌적하게 사용해 보세요. 언제든 구글 플레이에서 해지 가능합니다.',
                  features: const [
                    '월 1,200원으로 모든 광고 제거',
                    '구글 플레이 정기 결제 관리에서 1초 만에 해지 가능',
                  ],
                  priceText: '₩1,200 / 월',
                  priceSubtext: '매월 자동 갱신 (언제든 취소 가능)',
                  isUnlocked: false,
                  actionButtonText: '월간 구독 시작하기 (₩1,200/월)',
                  onAction: () {
                    MonetizationService.instance.buyProduct(MonetizationService.productIdRemoveAdsMonthly);
                  },
                ),
                const SizedBox(height: 18),
              ],

              // 3. Guarantee and Local Safety Notice
              Container(
                padding: const EdgeInsets.all(18),
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
                        Icon(Icons.shield_outlined, color: AppTheme.softMint, size: 20),
                        SizedBox(width: 8),
                        Text(
                          '구글 인앱 결제 100% 안전 보증',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• 모든 결제는 Google Play 결제 시스템을 통해 안전하게 암호화 처리됩니다.\n• 스마트폰을 변경하거나 앱을 재설치하셔도 상단 [구매 복원] 버튼을 누르면 즉시 복원됩니다.\n• 결제 후 만족스럽지 않으실 경우 Google Play 환불 규정에 따라 환불받으실 수 있습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Developer Testing Unlock Button
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    MonetizationService.instance.debugUnlockAll();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✨ [테스트용] 모든 PRO 기능이 활성화되었습니다!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  icon: const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF64748B)),
                  label: const Text(
                    '개발/테스트 전체 기능 언락 (스토어 심사용)',
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFFFBBF24)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11.5,
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
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFF10B981).withValues(alpha: 0.5)
              : const Color(0xFF334155),
          width: isUnlocked ? 1.5 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
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
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
                ),
                child: Text(
                  badgeText,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: badgeColor,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title & Description
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.7),
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
                    child: Icon(Icons.check, size: 14, color: AppTheme.softMint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: Color(0xFFCBD5E1),
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 14),

          // Price & Action Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    priceText,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: isUnlocked ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    priceSubtext,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: isUnlocked
                    ? const Color(0xFF065F46)
                    : const Color(0xFFF59E0B),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: Text(
                actionButtonText,
                style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
