import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/studio_profile.dart';

/// ZeroPass 하이엔드 이그제큐티브 출결 브리핑 콕핏 (Signature Key Visual Hero)
///
/// Z-패턴 시선 처리(좌상단 브랜드 -> 우상단 출석률 -> 중앙 프로그레스 -> 하단 3열 실시간 KPI 그리드)를
/// 적용하여 불필요한 시각적 산만함을 제거하고 핵심 운영 지표를 0.5초 만에 파악할 수 있도록 설계된 컴포넌트입니다.
class SignatureKeyVisualHero extends StatelessWidget {
  final List<Member> members;
  final List<PassRecord> todayRecords;
  final StudioProfile? studio;
  final VoidCallback? onOpenKiosk;
  final VoidCallback? onOpenGuide;

  const SignatureKeyVisualHero({
    super.key,
    required this.members,
    required this.todayRecords,
    this.studio,
    this.onOpenKiosk,
    this.onOpenGuide,
  });

  @override
  Widget build(BuildContext context) {
    final totalCount = members.length;
    final checkedInIds = todayRecords.map((r) => r.memberId).toSet();
    final checkedCount = members.where((m) => checkedInIds.contains(m.id)).length;
    final waitingCount = (totalCount - checkedCount).clamp(0, 9999);
    final expiringCount = members
        .where((m) => m.billingType == BillingType.sessionBased && m.remainingSessions <= 2)
        .length;
    final attendanceRate = totalCount == 0 ? 0 : ((checkedCount / totalCount) * 100).toInt();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F172A), // Deep Slate Navy
              Color(0xFF18181B), // Obsidian Zinc
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.14),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.10),
            width: 1.0,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Mobile-First Identity Header (펭귄 마스코트 산뜻한 컬러 배경 + 상호명/시설 뱃지 분리 재레이아웃)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onOpenGuide?.call();
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // 1. 3D 펭귄 마스코트(Passy) 프로필 - 산뜻한 파스텔 스카이블루 그라데이션 컬러 배경 + 빛나는 아우라 링
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color(0xFFE0F2FE), // Soft Sky Pastel
                            Color(0xFFBAE6FD), // Vibrant Cyan Tint
                          ],
                        ),
                        border: Border.all(
                          color: const Color(0xFF38BDF8),
                          width: 1.8,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/icons/mascot_profile.png',
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // 2. 상호명 및 시설/출석 뱃지 분리 줄바꿈 재레이아웃 (상호 길이에 무관하게 단정한 정렬감 유지)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 2-1. 상호명: 전폭 독립 단일/복합행 (뱃지와 충돌 없이 시원하게 표시)
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  studio?.studioName ?? '체크앤페이 스튜디오',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    color: Colors.white,
                                    fontSize: 16.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.4,
                                    height: 1.15,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.chevron_right_rounded,
                                size: 16,
                                color: Colors.white.withValues(alpha: 0.35),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // 2-2. 시설 뱃지 & 실시간 출석률: 줄바꿈 분리된 독립 메타 뱃지 행
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              // 시설 / 업종 카테고리 뱃지
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.storefront_rounded,
                                      size: 11,
                                      color: Color(0xFF7DD3FC),
                                    ),
                                    const SizedBox(width: 3.5),
                                    Text(
                                      studio?.category ?? '피트니스 / PT',
                                      style: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFFE0F2FE),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 실시간 출석률 뱃지
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.45),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 5,
                                      height: 5,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF10B981),
                                      ),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '출석률 $attendanceRate%',
                                      style: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Color(0xFF6EE7B7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // 실시간 인원 요약 (0/6명)
                              Text(
                                '실시간 ($checkedCount/$totalCount명)',
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  color: Color(0xFF94A3B8),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  letterSpacing: -0.2,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Row 2: Slim Precision Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 5,
                  width: double.infinity,
                  child: Stack(
                    children: [
                      Container(
                        color: Colors.white.withValues(alpha: 0.10),
                      ),
                      FractionallySizedBox(
                        widthFactor: totalCount == 0
                            ? 0.04
                            : (checkedCount / totalCount).clamp(0.04, 1.0),
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Color(0xFF38BDF8),
                                Color(0xFF34D399),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Row 3: Strict 3-Column Real-Time Operational KPI Grid (Tier 3 Label Top -> Tier 1 Number Bottom)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    _buildKpiCell(
                      label: '출석 완료',
                      value: '$checkedCount명',
                      accentColor: const Color(0xFF34D399),
                      valueColor: Colors.white,
                    ),
                    _buildVerticalDivider(),
                    _buildKpiCell(
                      label: '출결 대기',
                      value: '$waitingCount명',
                      accentColor: const Color(0xFF38BDF8),
                      valueColor: Colors.white,
                    ),
                    _buildVerticalDivider(),
                    _buildKpiCell(
                      label: '만료 임박',
                      value: '$expiringCount명',
                      accentColor: const Color(0xFFFBBF24),
                      valueColor: expiringCount > 0 ? const Color(0xFFFDE68A) : Colors.white,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 32,
      color: Colors.white.withValues(alpha: 0.10),
    );
  }

  Widget _buildKpiCell({
    required String label,
    required String value,
    required Color accentColor,
    required Color valueColor,
  }) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accentColor,
                  ),
                ),
                const SizedBox(width: 5),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 3),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                  height: 1.15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
