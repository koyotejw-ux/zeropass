import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';

/// 출석 완료 축하 오버레이 데이터 모델
class AttendanceCelebration {
  final String digits;
  final String memberName;
  final String passStatus;
  final String timeStr;
  final bool isDemo;
  final bool isSuccess;
  final String smsMessage;
  final String? photoPath;

  const AttendanceCelebration({
    required this.digits,
    required this.memberName,
    required this.passStatus,
    required this.timeStr,
    required this.isDemo,
    required this.isSuccess,
    required this.smsMessage,
    this.photoPath,
  });
}

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
  Timer? _celebrationTimer;
  DateTime _currentTime = DateTime.now();
  AttendanceCelebration? _celebration;

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
    _celebrationTimer?.cancel();
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
      await Future.delayed(const Duration(milliseconds: 250));

      final celebration = AttendanceCelebration(
        digits: enteredCode,
        memberName: '김패시 학생',
        passStatus: '10회권 (잔여 9회)',
        timeStr: DateFormat('yyyy.MM.dd HH:mm:ss').format(DateTime.now()),
        isDemo: true,
        isSuccess: true,
        smsMessage: '김패시 학생이 학원에 정상 출석하였습니다.',
      );

      _celebrationTimer?.cancel();
      _celebrationTimer = Timer(const Duration(seconds: 8), _dismissCelebration);

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _celebration = celebration;
        _statusMessage = null;
        _digits = '';
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

      final celebration = AttendanceCelebration(
        digits: enteredCode,
        memberName: member.name,
        passStatus: remaining,
        timeStr: DateFormat('yyyy.MM.dd HH:mm:ss').format(DateTime.now()),
        isDemo: false,
        isSuccess: true,
        smsMessage: '${member.name}님이 학원에 정상 출석하였습니다.',
        photoPath: member.photoPath,
      );

      _celebrationTimer?.cancel();
      _celebrationTimer = Timer(const Duration(seconds: 8), _dismissCelebration);

      HapticFeedback.heavyImpact();
      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _celebration = celebration;
        _statusMessage = null;
        _digits = '';
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

  /// 출석 완료 축하 화면 닫기 및 출결 입력창으로 즉시 복귀
  void _dismissCelebration() {
    _celebrationTimer?.cancel();
    if (mounted) {
      setState(() {
        _celebration = null;
        _statusMessage = null;
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
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = constraints.maxWidth > constraints.maxHeight;

                return isLandscape
                    ? _buildLandscapeKiosk(studio, members, dateStr, timeStr)
                    : _buildPortraitKiosk(studio, members, dateStr, timeStr);
              },
            ),
            if (_celebration != null)
              _buildFullScreenAttendanceSuccess(_celebration!, studio),
          ],
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

              // Keypad (FittedBox to prevent overflow on small screens)
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: _buildKeypad(),
                  ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 20).clamp(0.0, double.infinity),
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Top Header
                  _buildTopHeader(studio, dateStr, timeStr),
                  const SizedBox(height: 8),

                  // Main 2-Column Split
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left Column: Mascot, Info, Digit Display, Status
                        Expanded(
                          flex: 5,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              _buildQuickTestChips(members),
                              const SizedBox(height: 10),
                              _buildPromptAndMascot(),
                              const SizedBox(height: 14),
                              _buildDigitBoxes(),
                              if (_statusMessage != null) ...[
                                const SizedBox(height: 10),
                                _buildStatusCard(),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 24),

                        // Right Column: Keypad (FittedBox to prevent any vertical/horizontal overflow)
                        Expanded(
                          flex: 4,
                          child: Center(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 320),
                                child: _buildKeypad(),
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
          ),
        );
      },
    );
  }

  Widget _buildTopHeader(StudioProfile studio, String dateStr, String timeStr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
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
                  child: Transform.scale(
                    scale: 1.18,
                    child: Image.asset('assets/icons/splash_icon.png', fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      studio.studioName.isNotEmpty ? studio.studioName : 'ZeroPass 무인 출결 키오스크',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    Text(
                      '$dateStr  $timeStr',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
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
    // Unique test PINs deduplicated cleanly
    final seenPins = <String>{'1234', '0000'};
    final items = <_QuickPinItem>[
      const _QuickPinItem(pin: '1234', tag: '체험 PIN', color: Color(0xFF38BDF8)),
      const _QuickPinItem(pin: '0000', tag: '관리자 PIN', color: Color(0xFFFBBF24)),
    ];

    for (final m in members) {
      final clean = m.phone.replaceAll(RegExp(r'[^0-9]'), '');
      final last4 = clean.length >= 4 ? clean.substring(clean.length - 4) : clean;
      if (last4.length == 4 && !seenPins.contains(last4)) {
        seenPins.add(last4);
        items.add(_QuickPinItem(pin: last4, tag: m.name, color: const Color(0xFF34D399)));
        if (items.length >= 5) break;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: items.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildQuickPinBadge(item),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickPinBadge(_QuickPinItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          setState(() {
            _digits = item.pin;
            _statusMessage = null;
          });
          _processCheckIn();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: item.color.withValues(alpha: 0.55), width: 1.2),
            boxShadow: [
              BoxShadow(
                color: item.color.withValues(alpha: 0.12),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                item.tag,
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  item.pin,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: item.color,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPromptAndMascot() {
    return const Column(
      children: [
        Text(
          '전화번호 뒷자리 4자리를 입력해주세요',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        SizedBox(height: 5),
        Text(
          '터치 즉시 출석이 기록되고 부모님께 안심 문자가 전송됩니다',
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
          width: 56,
          height: 66,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isFilled ? const Color(0xFF38BDF8) : const Color(0xFF475569),
              width: isFilled ? 2.4 : 1.4,
            ),
            boxShadow: isFilled
                ? [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                      blurRadius: 12,
                      spreadRadius: 1,
                    ),
                  ]
                : [],
          ),
          child: isFilled
              ? Text(
                  digitChar,
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                )
              : const Text(
                  '—',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF64748B),
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

  /// 일반 매장 키오스크 방식의 전면 출석 완료 화면 (전면 대형 4자리 번호 표시 및 애니메이션)
  Widget _buildFullScreenAttendanceSuccess(AttendanceCelebration celebration, StudioProfile studio) {
    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _dismissCelebration,
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeOutBack,
          tween: Tween(begin: 0.0, end: 1.0),
          builder: (context, value, child) {
            return Opacity(
              opacity: value.clamp(0.0, 1.0),
              child: Transform.scale(
                scale: 0.9 + (0.1 * value),
                child: child,
              ),
            );
          },
          child: Container(
          width: double.infinity,
          height: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A), // Clean, simple high-end slate void
          ),
          child: SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLandscape = constraints.maxWidth > constraints.maxHeight;

                return SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isLandscape ? 32 : 24,
                    vertical: isLandscape ? 14 : 20,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight - (isLandscape ? 28 : 40),
                    ),
                    child: IntrinsicHeight(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 1. Top Store Brand & Live Stamp Pill
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E293B),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ClipOval(
                                  child: Transform.scale(
                                    scale: 1.18,
                                    child: Image.asset(
                                      'assets/icons/splash_icon.png',
                                      width: 22,
                                      height: 22,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  studio.studioName.isNotEmpty ? studio.studioName : 'ZeroPass 스마트 출결 키오스크',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    celebration.timeStr,
                                    style: const TextStyle(
                                      color: Color(0xFF34D399),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 2. Avatar Circle: Member Photo if registered, else Edge-to-edge Penguin
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              Container(
                                width: isLandscape ? 90 : 108,
                                height: isLandscape ? 90 : 108,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: const Color(0xFF1E293B),
                                  border: Border.all(color: const Color(0xFF10B981), width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.35),
                                      blurRadius: 18,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: celebration.photoPath != null &&
                                          celebration.photoPath!.isNotEmpty &&
                                          File(celebration.photoPath!).existsSync()
                                      ? Image.file(
                                          File(celebration.photoPath!),
                                          fit: BoxFit.cover,
                                        )
                                      : Transform.scale(
                                          scale: 1.18,
                                          child: Image.asset(
                                            'assets/icons/splash_icon.png',
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.all(5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF10B981),
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white, width: 2),
                                ),
                                child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // 3. Huge 전면 4자리 출결 번호 Display
                          Column(
                            children: [
                              const Text(
                                '입력하신 출결 번호',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: celebration.digits.split('').map((d) {
                                  return Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 6),
                                    width: isLandscape ? 56 : 64,
                                    height: isLandscape ? 64 : 74,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: const Color(0xFF10B981),
                                        width: 1.8,
                                      ),
                                    ),
                                    child: Text(
                                      d,
                                      style: TextStyle(
                                        fontSize: isLandscape ? 28 : 34,
                                        fontWeight: FontWeight.w900,
                                        color: Colors.white,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),

                          const SizedBox(height: 22),

                          // 4. Main Celebratory Announcement & Member Name
                          Text(
                            celebration.memberName,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isLandscape ? 24 : 28,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.6,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '출석 체크가 정상 완료되었습니다!',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isLandscape ? 15 : 17,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFF34D399),
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 18),

                          // 5. Store-Grade Status Cards (Remaining Pass & Safe Parent SMS)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Row(
                                        children: [
                                          Icon(Icons.confirmation_num_rounded, color: Color(0xFF38BDF8), size: 18),
                                          SizedBox(width: 8),
                                          Text(
                                            '이용권 잔여 현황',
                                            style: TextStyle(
                                              color: Color(0xFF94A3B8),
                                              fontSize: 13.5,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        celebration.passStatus,
                                        style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w900,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Color(0xFF1F2937), height: 18),
                                  Row(
                                    children: [
                                      Icon(
                                        celebration.isDemo ? Icons.tips_and_updates_rounded : Icons.mark_chat_read_rounded,
                                        color: celebration.isDemo ? const Color(0xFFFBBF24) : const Color(0xFF38BDF8),
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          celebration.isDemo
                                              ? '스마트 체험 시뮬레이션: 가상 1회 차감 및 알림 발송 완료'
                                              : '학부모님 안심 알림(문자) 전송 완료',
                                          style: TextStyle(
                                            color: celebration.isDemo ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 24),

                          // 6. Big Store-Style [확인] Action Button (Returns to PIN Check-in screen)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _dismissCelebration();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 12,
                                  shadowColor: const Color(0xFF10B981).withValues(alpha: 0.6),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 24),
                                    SizedBox(width: 10),
                                    Text(
                                      '확인 (다음 출석하기)',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 12),

                          const Text(
                            '확인 버튼 또는 화면을 터치하면 즉시 다음 출석을 진행합니다',
                            style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );
  }
}

class _QuickPinItem {
  final String pin;
  final String tag;
  final Color color;

  const _QuickPinItem({
    required this.pin,
    required this.tag,
    required this.color,
  });
}
