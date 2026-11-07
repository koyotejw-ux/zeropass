import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/studio_profile.dart';
import 'brand_emblem.dart';

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
              // Row 1: Mobile-First Identity Header (No truncation on Studio Name!)
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onOpenGuide?.call();
                },
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const ZeroPassBrandEmblem(size: 30, withGlow: false),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studio?.category ?? '전문교육',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            studio?.studioName ?? '나의 스튜디오',
                            softWrap: true,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: const Color(0xFF10B981).withValues(alpha: 0.35),
                          width: 0.9,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF34D399),
                            ),
                          ),
                          const SizedBox(width: 5),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(fontFamily: 'Pretendard'),
                              children: [
                                const TextSpan(
                                  text: '출석률 ',
                                  style: TextStyle(
                                    color: Color(0xFFA7F3D0),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                TextSpan(
                                  text: '$attendanceRate%',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

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
