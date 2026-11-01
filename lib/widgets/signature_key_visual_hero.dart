import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/member.dart';
import '../models/pass_record.dart';

/// ZeroPass 포트폴리오급 대표 시그니처 키비주얼 (Signature Key Visual Hero)
///
/// 독창적이고 심미성 높은 3D 글래스모피즘 오로라 레이더 & 펭귄 마스코트 인터랙티브 비주얼 컴포넌트.
/// 베스트 UX/UI 포트폴리오(Behance / Dribbble) 규격의 미려한 디테일과 부드러운 애니메이션을 제공합니다.
class SignatureKeyVisualHero extends StatefulWidget {
  final List<Member> members;
  final List<PassRecord> todayRecords;
  final VoidCallback? onOpenKiosk;
  final VoidCallback? onOpenGuide;

  const SignatureKeyVisualHero({
    super.key,
    required this.members,
    required this.todayRecords,
    this.onOpenKiosk,
    this.onOpenGuide,
  });

  @override
  State<SignatureKeyVisualHero> createState() => _SignatureKeyVisualHeroState();
}

class _SignatureKeyVisualHeroState extends State<SignatureKeyVisualHero>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isTapped = false;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _pulseController,
      curve: Curves.easeInOutQuad,
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalCount = widget.members.length;
    final checkedInIds = widget.todayRecords.map((r) => r.memberId).toSet();
    final checkedCount = widget.members.where((m) => checkedInIds.contains(m.id)).length;
    final attendanceRate = totalCount == 0 ? 0 : ((checkedCount / totalCount) * 100).toInt();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          final pulseValue = _pulseAnimation.value;

          return Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFF0F172A), // Deep Slate Navy
                  Color(0xFF1E293B), // Obsidian Blue
                  Color(0xFF090D16), // Pure Void Navy
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF6366F1).withValues(alpha: 0.15 + (0.08 * pulseValue)),
                  blurRadius: 24,
                  spreadRadius: 2,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12 + (0.06 * pulseValue)),
                width: 1.2,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                children: [
                  // 1. Cyber Aurora Light Gradients in Background
                  Positioned(
                    top: -40,
                    right: -30,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF38BDF8).withValues(alpha: 0.22 + (0.06 * pulseValue)),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -50,
                    left: -30,
                    child: Container(
                      width: 190,
                      height: 190,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            const Color(0xFF10B981).withValues(alpha: 0.18 + (0.05 * pulseValue)),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),

                  // 2. Main Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Top Bar: Live Status Pill & Interactive Guide Trigger
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Glowing Live Status Pill
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981).withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: const Color(0xFF10B981).withValues(alpha: 0.4),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF34D399),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF34D399)
                                              .withValues(alpha: 0.8),
                                          blurRadius: 6,
                                          spreadRadius: 2,
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '100% 로컬 출결 레이더 가동 중',
                                    style: TextStyle(
                                      color: Color(0xFFE2E8F0),
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Kiosk Pro & Key Visual Badge
                            InkWell(
                              onTap: () {
                                HapticFeedback.lightImpact();
                                widget.onOpenKiosk?.call();
                              },
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [Color(0xFF3B82F6), Color(0xFF6366F1)],
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(0xFF3B82F6).withValues(alpha: 0.35),
                                      blurRadius: 8,
                                    ),
                                  ],
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.tablet_mac_rounded, size: 12, color: Colors.white),
                                    SizedBox(width: 4),
                                    Text(
                                      '무인 키오스크',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Centerpiece: 3D Mascot with Pulsating Halo + High-end Typography
                        Row(
                          children: [
                            // 3D Penguin Mascot with Dynamic Pulsing Concentric Rings
                            GestureDetector(
                              onTap: () {
                                HapticFeedback.mediumImpact();
                                setState(() => _isTapped = !_isTapped);
                                widget.onOpenGuide?.call();
                              },
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Outer Pulsing Aura Ring
                                  Container(
                                    width: 68 + (8 * pulseValue),
                                    height: 68 + (8 * pulseValue),
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF38BDF8)
                                            .withValues(alpha: 0.35 * (1.0 - pulseValue)),
                                        width: 1.8,
                                      ),
                                    ),
                                  ),
                                  // Middle Glow Ring
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          const Color(0xFF38BDF8)
                                              .withValues(alpha: 0.25 + (0.1 * pulseValue)),
                                          Colors.transparent,
                                        ],
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: const Color(0xFF38BDF8).withValues(alpha: 0.3),
                                          blurRadius: 14,
                                        ),
                                      ],
                                    ),
                                  ),
                                  // Mascot Circle (Clean Penguin without 0!)
                                  Container(
                                    width: 52,
                                    height: 52,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFF1E293B),
                                      border: Border.all(
                                        color: Colors.white.withValues(alpha: 0.6),
                                        width: 1.5,
                                      ),
                                    ),
                                    child: ClipOval(
                                      child: Image.asset(
                                        'assets/icons/splash_icon.png',
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),

                            // Headline and Dynamic Metrics
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Text(
                                        '오늘 출결 실시간',
                                        style: TextStyle(
                                          color: Color(0xFF94A3B8),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Container(
                                        padding:
                                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '$attendanceRate%',
                                          style: const TextStyle(
                                            color: Color(0xFF38BDF8),
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    checkedCount == 0 && totalCount == 0
                                        ? '첫 회원을 등록해 보세요'
                                        : '$checkedCount명 출석완료 / 총 $totalCount명',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  // Slim Precision Gauge Bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Stack(
                                      children: [
                                        Container(
                                          height: 5,
                                          width: double.infinity,
                                          color: Colors.white.withValues(alpha: 0.12),
                                        ),
                                        FractionallySizedBox(
                                          widthFactor: totalCount == 0
                                              ? 0.05
                                              : (checkedCount / totalCount).clamp(0.02, 1.0),
                                          child: Container(
                                            height: 5,
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
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // 3. Artistic Glass Capsule Metrics (3 Pillars)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.08),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              _buildPillarCapsule(
                                icon: Icons.bolt_rounded,
                                iconColor: const Color(0xFF38BDF8),
                                label: '1초 출결',
                                value: '원터치 차감',
                              ),
                              _buildVerticalDivider(),
                              _buildPillarCapsule(
                                icon: Icons.chat_bubble_rounded,
                                iconColor: const Color(0xFF34D399),
                                label: '0원 통신비',
                                value: '기본문자 발송',
                              ),
                              _buildVerticalDivider(),
                              _buildPillarCapsule(
                                icon: Icons.lock_outline_rounded,
                                iconColor: const Color(0xFFFBBF24),
                                label: '100% 로컬',
                                value: '외부유출 제로',
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
          );
        },
      ),
    );
  }

  Widget _buildVerticalDivider() {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white.withValues(alpha: 0.08),
    );
  }

  Widget _buildPillarCapsule({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
  }) {
    return Expanded(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
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
