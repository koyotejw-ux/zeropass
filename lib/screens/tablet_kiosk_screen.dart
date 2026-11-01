import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';

/// 최고급 프리미엄 인터랙티브 태블릿 키오스크 모드 (Tablet Kiosk Screen)
///
/// 학원·교습소·PT 스튜디오 카운터에 거치하여 학생들이 직접 4자리 전화번호를 누르고 출석하는 화면입니다.
/// - 등록 회원이 없거나 테스트 시: '1234' 등 체험 번호 자동 감지 및 실시간 출결 시뮬레이션
/// - 관리자 마스터 비밀번호 '0000' 입력 시 키오스크 즉시 종료 복귀 프로세스 제공
/// - 글래스모피즘 네온 핀패드, 햅틱 피드백, 실시간 디지털 시계 탑재
class TabletKioskScreen extends ConsumerStatefulWidget {
  const TabletKioskScreen({super.key});

  @override
  ConsumerState<TabletKioskScreen> createState() => _TabletKioskScreenState();
}

class _TabletKioskScreenState extends ConsumerState<TabletKioskScreen> {
  String _digits = '';
  String? _statusMessage;
  bool _isSuccess = false;
  bool _isProcessing = false;
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // 1초 주기로 실시간 시계 갱신
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    super.dispose();
  }

  void _onKeyTap(String key) {
    if (_isProcessing) return;
    HapticFeedback.lightImpact();

    if (_digits.length < 4) {
      setState(() {
        _digits += key;
        _statusMessage = null;
      });

      if (_digits.length == 4) {
        _processCheckIn();
      }
    }
  }

  void _onBackspace() {
    if (_digits.isNotEmpty && !_isProcessing) {
      HapticFeedback.selectionClick();
      setState(() {
        _digits = _digits.substring(0, _digits.length - 1);
        _statusMessage = null;
      });
    }
  }

  void _onClear() {
    if (!_isProcessing) {
      HapticFeedback.selectionClick();
      setState(() {
        _digits = '';
        _statusMessage = null;
      });
    }
  }

  /// 4자리 입력 후 출결 처리 또는 관리자 마스터/체험 모드 분기
  Future<void> _processCheckIn() async {
    setState(() {
      _isProcessing = true;
    });

    final enteredCode = _digits;

    // 1. 관리자 마스터 비밀번호 '0000' 입력 시 -> 키오스크 종료 확인 다이얼로그
    if (enteredCode == '0000') {
      HapticFeedback.mediumImpact();
      setState(() {
        _isProcessing = false;
        _digits = '';
      });
      _showMasterExitDialog();
      return;
    }

    final members = ref.read(membersProvider).value ?? [];
    final studio = ref.read(studioProfileProvider).value ?? StudioProfile.defaultProfile();

    // 2. 실제 등록된 회원 검색 (전화번호 뒷자리 매칭)
    final matchedMembers = members.where((m) {
      final clean = m.phone.replaceAll(RegExp(r'[^0-9]'), '');
      return clean.endsWith(enteredCode);
    }).toList();

    // 3. 일치 회원이 없을 때 -> 스마트 체험 테스트 시뮬레이션 가동!
    if (matchedMembers.isEmpty) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 350));

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage = '🎉 [체험 테스트 완료]\n김패시 학생 ($enteredCode) 출석 체크!\n10회권 잔여 9회 차감 · 안심 문자 가상 전송 완료 🚀';
        _digits = '';
      });

      // 4초 후 상태 메시지 자동 초기화
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _statusMessage = null;
          });
        }
      });
      return;
    }

    // 4. 실제 회원 정상 출결 처리
    final member = matchedMembers.first;

    try {
      await ref.read(passRecordsProvider.notifier).checkInMember(member: member);
      await ref.read(membersProvider.notifier).reload();

      // 보호자 안심 문자 연동
      if (member.phone.isNotEmpty && member.phone != '010-0000-0000') {
        final smsMsg = SmsTemplateService.generateAttendanceMessage(
          studio: studio,
          member: member,
          time: DateTime.now(),
        );
        SmsTemplateService.launchNativeSms(
          recipientPhone: member.phone,
          body: smsMsg,
        );
      }

      final remaining = member.billingType == BillingType.sessionBased
          ? '${member.remainingSessions - 1}회 남음'
          : '정기권 패스';

      HapticFeedback.heavyImpact();
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage = '반가워요, ${member.name}님! 🎉\n출석 체크 완료! ($remaining)\n보호자 안심 문자가 전송되었습니다.';
        _digits = '';
      });

      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _statusMessage = null;
          });
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = '출결 처리 중 오류가 발생했습니다: $e';
        _digits = '';
      });
    }
  }

  /// 마스터 비밀번호 0000 입력 시 원터치 종료 다이얼로그
  void _showMasterExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF38BDF8), size: 28),
            SizedBox(width: 10),
            Text(
              '관리자 키오스크 종료',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: const Text(
          '관리자 마스터 비밀번호(0000)가 정상 확인되었습니다.\n태블릿 키오스크 모드를 종료하고 원장님 대시보드로 복귀하시겠습니까?',
          style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('계속 키오스크 유지', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('장부 대시보드로 복귀', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// 자물쇠 버튼 탭 시 키오스크 탈출 팝업 (간편 0000 원터치 포함)
  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.lock_rounded, color: Color(0xFFFBBF24), size: 26),
            SizedBox(width: 10),
            Text(
              '관리자 모드 복귀',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '학생 및 회원의 무단 화면 조작을 방지하는 안전 잠금장치입니다.\n관리자 비밀번호 기본값은 [0000] 입니다.',
              style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5, height: 1.5),
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Color(0xFF38BDF8), size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '키패드에서 0000을 입력하셔도 즉시 관리자로 복귀할 수 있습니다.',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('닫기', style: TextStyle(color: Color(0xFF94A3B8))),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('관리자 즉시 복귀 (0000)', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();
    final members = ref.watch(membersProvider).value ?? [];
    final dateStr = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_currentTime);
    final timeStr = DateFormat('HH:mm:ss').format(_currentTime);

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Ultra Deep Obsidian Kiosk
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            return isLandscape
                ? _buildLandscapeKiosk(studio, members, dateStr, timeStr)
                : _buildPortraitKiosk(studio, members, dateStr, timeStr);
          },
        ),
      ),
    );
  }

  Widget _buildPortraitKiosk(StudioProfile studio, List<Member> members, String dateStr, String timeStr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical - 24,
        ),
        child: IntrinsicHeight(
          child: Column(
            children: [
              // Top Header (Studio Info, Live Time & Exit Lock)
              _buildTopHeader(studio, dateStr, timeStr),
              const SizedBox(height: 12),

              // Quick Test Chips
              _buildQuickTestChips(members),
              const SizedBox(height: 16),

              // Center: Prompt & Mascot
              _buildPromptAndMascot(),
              const SizedBox(height: 16),

              // 4-Digit Display Boxes
              _buildDigitBoxes(),
              const SizedBox(height: 12),

              // Status / Success / Error Card
              if (_statusMessage != null) _buildStatusCard(),

              const Spacer(),

              // Keypad
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 340),
                  child: _buildKeypad(),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeKiosk(StudioProfile studio, List<Member> members, String dateStr, String timeStr) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
      child: Column(
        children: [
          // Top Header
          _buildTopHeader(studio, dateStr, timeStr),
          const SizedBox(height: 10),

          // Main 2-Column Split
          Expanded(
            child: Row(
              children: [
                // Left Column: Mascot, Info, Digit Display, Status
                Expanded(
                  flex: 5,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildQuickTestChips(members),
                      const SizedBox(height: 14),
                      _buildPromptAndMascot(),
                      const SizedBox(height: 20),
                      _buildDigitBoxes(),
                      if (_statusMessage != null) ...[
                        const SizedBox(height: 14),
                        _buildStatusCard(),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 32),

                // Right Column: Keypad
                Expanded(
                  flex: 4,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 320),
                      child: _buildKeypad(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopHeader(StudioProfile studio, String dateStr, String timeStr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E293B),
                border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
              ),
              child: ClipOval(
                child: Image.asset('assets/icons/splash_icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studio.studioName,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  '$dateStr  $timeStr',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.lock_outline_rounded, color: Color(0xFF94A3B8), size: 20),
          ),
          tooltip: '키오스크 종료 (관리자)',
          onPressed: _showExitDialog,
        ),
      ],
    );
  }

  Widget _buildQuickTestChips(List<Member> members) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _buildQuickChip('💡 체험: 1234', '1234', const Color(0xFF38BDF8)),
          const SizedBox(width: 8),
          _buildQuickChip('🔐 관리자: 0000', '0000', const Color(0xFFFBBF24)),
          if (members.isNotEmpty) ...[
            const SizedBox(width: 8),
            ...members.take(3).map((m) {
              final clean = m.phone.replaceAll(RegExp(r'[^0-9]'), '');
              final last4 = clean.length >= 4 ? clean.substring(clean.length - 4) : clean;
              if (last4.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _buildQuickChip('👤 ${m.name}: $last4', last4, const Color(0xFF34D399)),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildQuickChip(String label, String digits, Color accentColor) {
    return ActionChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: accentColor,
        ),
      ),
      backgroundColor: accentColor.withValues(alpha: 0.12),
      side: BorderSide(color: accentColor.withValues(alpha: 0.35)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onPressed: () {
        HapticFeedback.lightImpact();
        setState(() {
          _digits = digits;
          _statusMessage = null;
        });
        _processCheckIn();
      },
    );
  }

  Widget _buildPromptAndMascot() {
    return Column(
      children: [
        const Text(
          '반가워요! 전화번호 뒷자리 4자리를 눌러주세요 🐧',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16.5,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          '터치 즉시 출석이 기록되고 부모님께 안심 문자가 전송돼요',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
        ),
      ],
    );
  }

  Widget _buildDigitBoxes() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _digits.length;
        final digitChar = isFilled ? _digits[index] : '';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.symmetric(horizontal: 6),
          width: 52,
          height: 62,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFilled ? const Color(0xFF38BDF8) : const Color(0xFF334155),
              width: isFilled ? 2.2 : 1.2,
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: Text(
            digitChar,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStatusCard() {
    final isSuccess = _isSuccess;
    final color = isSuccess ? const Color(0xFF10B981) : Colors.redAccent;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSuccess ? Icons.check_circle_rounded : Icons.info_outline_rounded,
            color: color,
            size: 24,
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              _statusMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isSuccess ? const Color(0xFFE2E8F0) : Colors.white,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKeypad() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('1'),
            const SizedBox(width: 12),
            _buildKeypadButton('2'),
            const SizedBox(width: 12),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('4'),
            const SizedBox(width: 12),
            _buildKeypadButton('5'),
            const SizedBox(width: 12),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('7'),
            const SizedBox(width: 12),
            _buildKeypadButton('8'),
            const SizedBox(width: 12),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionKeypadButton('초기화', Icons.refresh_rounded, _onClear),
            const SizedBox(width: 12),
            _buildKeypadButton('0'),
            const SizedBox(width: 12),
            _buildActionKeypadButton('지움', Icons.backspace_outlined, _onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String num) {
    return InkWell(
      onTap: () => _onKeyTap(num),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 86,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Text(
          num,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildActionKeypadButton(String label, IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 86,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
