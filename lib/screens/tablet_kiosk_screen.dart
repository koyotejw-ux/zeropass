import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/database_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mascot_avatar.dart';
import 'home_navigation_screen.dart';

/// 출석 완료 축하 오버레이 데이터 모델
class AttendanceCelebration {
  final String digits;
  final String memberName;
  final String? programTag;
  final String passStatus;
  final String timeStr;
  final bool isDemo;
  final bool isSuccess;
  final String smsMessage;
  final String? photoPath;

  const AttendanceCelebration({
    required this.digits,
    required this.memberName,
    this.programTag,
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
/// - [isTestMode] false (기본값): 실제 학생 운영용 키오스크 (체험 핀 일체 숨김, 미등록 번호 시 에러 안내)
/// - [isTestMode] true: 원장님 기능 테스트 모드 (1234 체험 핀 노출 및 출결 축하 결과 시뮬레이션 표출)
/// - 관리자 마스터 비밀번호 '0000' 입력 시 키오스크 즉시 종료 복귀 프로세스 제공
/// - 글래스모피즘 네온 핀패드, 햅틱 피드백, 실시간 디지털 시계 탑재
class TabletKioskScreen extends ConsumerStatefulWidget {
  final bool isTestMode;

  const TabletKioskScreen({
    super.key,
    this.isTestMode = false,
  });

  @override
  ConsumerState<TabletKioskScreen> createState() => _TabletKioskScreenState();
}

class _TabletKioskScreenState extends ConsumerState<TabletKioskScreen> {
  late bool _localTestMode;
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
    _localTestMode = widget.isTestMode;
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

    // 3. 기능 테스트 모드인 경우: 1234 또는 테스트 번호 입력 시 출결 축하 화면 즉시 표출
    if (_localTestMode) {
      HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 250));

      final celebration = AttendanceCelebration(
        digits: enteredCode,
        memberName: '김패시 학생',
        programTag: '기능 테스트 시뮬레이션',
        passStatus: '10회권 (잔여 9회)',
        timeStr: DateFormat('yyyy.MM.dd HH:mm:ss').format(DateTime.now()),
        isDemo: true,
        isSuccess: true,
        smsMessage: '[테스트 알림] 김패시 학생이 학원에 정상 출석하였습니다.',
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

    // 4. 학생용(운영용) 모드: 등록되지 않은 번호인 경우 가상 축하 화면 절대 노출 금지 및 에러 안내
    if (matchedMembers.isEmpty) {
      HapticFeedback.heavyImpact();
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = '등록되지 않은 번호($enteredCode)입니다.\n선생님께 확인을 요청해 주세요.';
        _digits = '';
      });
      return;
    }

    // 4. 실제 회원 정상 출결 처리
    final member = matchedMembers.first;

    try {
      await ref.read(passRecordsProvider.notifier).checkInMember(member: member);
      await ref.read(membersProvider.notifier).reload();

      // 키오스크 안전 연동: 무인 키오스크 화면 이탈 방지 및 원장님 알림 센터 등원 큐 자동 적립
      final smsMsg = SmsTemplateService.generateAttendanceMessage(
        studio: studio,
        member: member,
        time: DateTime.now(),
      );

      final remaining = member.billingType == BillingType.sessionBased
          ? '${member.remainingSessions - 1}회 남음'
          : '정기권 패스';

      final celebration = AttendanceCelebration(
        digits: enteredCode,
        memberName: member.primaryName,
        programTag: member.secondaryTag,
        passStatus: remaining,
        timeStr: DateFormat('yyyy.MM.dd HH:mm:ss').format(DateTime.now()),
        isDemo: false,
        isSuccess: true,
        smsMessage: smsMsg,
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

  void _exitToDashboard() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const HomeNavigationScreen()),
      );
    }
  }

  /// 마스터 비밀번호 0000 입력 시 원터치 종료 다이얼로그
  void _showMasterExitDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        actionsAlignment: MainAxisAlignment.end,
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
              _exitToDashboard();
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

  /// 자물쇠 버튼 탭 시 관리자 비밀번호 확인 다이얼로그 (학생의 무단 이탈 방지)
  void _showExitDialog() {
    final pinController = TextEditingController();
    String? errorMessage;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
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
                '학생의 무단 화면 조작을 방지하는 안전 잠금장치입니다.\n관리자 비밀번호 4자리를 입력해 주세요. (기본값: 0000)',
                style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: pinController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                obscureText: true,
                autofocus: true,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  letterSpacing: 10,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: '••••',
                  hintStyle: const TextStyle(color: Color(0xFF64748B), letterSpacing: 10),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  errorText: errorMessage,
                  errorStyle: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
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
                if (pinController.text.trim() == '0000') {
                  Navigator.pop(ctx);
                  _exitToDashboard();
                } else {
                  setDialogState(() {
                    errorMessage = '비밀번호가 일치하지 않습니다.';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: const Text('확인', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();
    final members = ref.watch(membersProvider).value ?? [];
    final dateStr = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(_currentTime);
    final timeStr = DateFormat('HH:mm:ss').format(_currentTime);

    final showEmptyState = members.isEmpty && !_localTestMode;

    return Scaffold(
      backgroundColor: const Color(0xFF0B0F19), // Ultra Deep Obsidian Kiosk
      body: SafeArea(
        child: Stack(
          children: [
            showEmptyState
                ? _buildEmptyMembersView(studio, dateStr, timeStr)
                : LayoutBuilder(
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

  /// 학생용 키오스크 실행 시 등록된 원생 데이터가 0명일 때 노출되는 빈 상태 안내 뷰
  Widget _buildEmptyMembersView(StudioProfile studio, String dateStr, String timeStr) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 24).clamp(0.0, double.infinity),
            ),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  _buildTopHeader(studio, dateStr, timeStr),
                  const Spacer(),
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 440),
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.45),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: const Icon(Icons.person_off_rounded, color: Color(0xFFFBBF24), size: 36),
                          ),
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text(
                              '학생 데이터 없음',
                              style: TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            '등록된 학생 데이터가 없어\n키오스크 모드를 실행할 수 없습니다',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            '키오스크는 등록된 학생의 전화번호 뒷자리로 확인됩니다.\n샘플 학생을 등록하거나 기능 테스트 모드로 체험해 보세요.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 13,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 22),
                          SizedBox(
                            width: double.infinity,
                            height: 48,
                            child: ElevatedButton.icon(
                              onPressed: _isProcessing
                                  ? null
                                  : () async {
                                      final messenger = ScaffoldMessenger.of(context);
                                      setState(() => _isProcessing = true);
                                      try {
                                        await DatabaseService.instance.restoreSampleData();
                                        await ref.read(membersProvider.notifier).reload();
                                        if (mounted) {
                                          messenger.showSnackBar(
                                            const SnackBar(content: Text('샘플 학생 5명이 등록되었습니다. 키오스크를 시작합니다.')),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(() => _isProcessing = false);
                                        }
                                      }
                                    },
                              icon: _isProcessing
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                    )
                                  : const Icon(Icons.group_add_rounded, size: 20),
                              label: Text(
                                _isProcessing ? '샘플 학생 생성 중...' : '샘플 학생 5명 바로 등록하기',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.primaryBlue,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 44,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _localTestMode = true;
                                });
                              },
                              icon: const Icon(Icons.science_rounded, size: 18, color: Color(0xFFA5B4FC)),
                              label: const Text(
                                '기능 테스트 모드로 체험하기',
                                style: TextStyle(color: Color(0xFFA5B4FC), fontWeight: FontWeight.w700, fontSize: 13.5),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.5)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            onPressed: _exitToDashboard,
                            icon: const Icon(Icons.arrow_back_rounded, size: 16, color: Color(0xFF94A3B8)),
                            label: const Text(
                              '관리자 대시보드로 복귀',
                              style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        );
      },
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

  Widget _buildKioskBrandLogo(StudioProfile studio, {double size = 44}) {
    final hasLogo = studio.logoPath != null && studio.logoPath!.isNotEmpty && File(studio.logoPath!).existsSync();
    if (hasLogo) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(size * 0.28),
          border: Border.all(color: Colors.white.withValues(alpha: 0.25), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(size * 0.28),
          child: Image.file(
            File(studio.logoPath!),
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => ZeroPassMascotAvatar(
              size: size,
              isLightMode: true,
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
          ),
        ),
      );
    }
    return ZeroPassMascotAvatar(
      size: size,
      isLightMode: true,
      border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
    );
  }

  Widget _buildTopHeader(StudioProfile studio, String dateStr, String timeStr) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Row(
            children: [
              _buildKioskBrandLogo(studio, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            studio.studioName.isNotEmpty ? studio.studioName : 'ZeroPass 무인 출결 키오스크',
                            softWrap: true,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                        if (_localTestMode) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF6366F1).withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFF818CF8), width: 0.8),
                            ),
                            child: const Text(
                              '테스트 모드',
                              style: TextStyle(
                                color: Color(0xFFA5B4FC),
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$dateStr  $timeStr',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                      ),
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
    // 학생용(운영용) 모드에서는 어떠한 경우에도 체험용 핀 칩을 일체 노출하지 않습니다.
    if (!_localTestMode) {
      return const SizedBox.shrink();
    }

    // 원장님 기능 테스트 모드에서만 상단 배지 및 1234 체험 칩 노출
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF312E81).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6366F1).withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.science_rounded, color: Color(0xFFA5B4FC), size: 18),
          const SizedBox(width: 8),
          const Flexible(
            child: Text(
              '원장님 테스트 모드',
              style: TextStyle(
                color: Color(0xFFA5B4FC),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildQuickPinBadge(
            const _QuickPinItem(pin: '1234', tag: '체험 PIN', color: Color(0xFF38BDF8)),
          ),
        ],
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

  /// 일반 매장 키오스크 방식의 전면 출석 완료 화면 (전면 대형 4자리 번호 표시 및 반응형 무결점 레이아웃)
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
                  final isCompact = constraints.maxHeight < 680;
                  final vGap = isLandscape ? 8.0 : (isCompact ? 10.0 : 16.0);
                  final avatarSize = isLandscape ? 72.0 : (isCompact ? 80.0 : 96.0);
                  final digitBoxWidth = ((constraints.maxWidth - 64) / 4).clamp(40.0, 58.0);
                  final digitBoxHeight = digitBoxWidth * 1.15;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 24 : 20,
                      vertical: isLandscape ? 12 : 16,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - (isLandscape ? 24 : 32),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // 1. Top Store Brand & Live Stamp Pill (FittedBox & Flexible로 오버플로우 방지)
                          ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: constraints.maxWidth - (isLandscape ? 48 : 24),
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildKioskBrandLogo(studio, size: 24),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      studio.studioName.isNotEmpty ? studio.studioName : 'ZeroPass 스마트 출결 키오스크',
                                      softWrap: true,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      celebration.timeStr,
                                      style: const TextStyle(
                                        color: Color(0xFF34D399),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          SizedBox(height: vGap),

                          // 2. Avatar Circle: Member Photo if registered, else Naturally Masked 3D Penguin
                          ZeroPassMascotAvatar(
                            size: avatarSize,
                            photoPath: celebration.photoPath,
                            isLightMode: true,
                            border: Border.all(color: const Color(0xFF10B981), width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 4),
                              ),
                            ],
                            badge: Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: const Color(0xFF10B981),
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.check_rounded, color: Colors.white, size: 16),
                            ),
                          ),

                          SizedBox(height: vGap),

                          // 3. Huge 전면 4자리 출결 번호 Display (반응형 FittedBox & 동적 스케일링으로 오버플로우 원천 차단)
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                '입력하신 출결 번호',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF94A3B8),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              SizedBox(height: vGap * 0.4),
                              FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: celebration.digits.split('').map((d) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 5),
                                      width: digitBoxWidth,
                                      height: digitBoxHeight,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF1E293B),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0xFF10B981),
                                          width: 1.8,
                                        ),
                                      ),
                                      child: Text(
                                        d,
                                        style: TextStyle(
                                          fontSize: digitBoxWidth * 0.52,
                                          fontWeight: FontWeight.w900,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),

                          SizedBox(height: vGap),

                          // 4. Main Celebratory Announcement & Member Name (1줄 순수 이름 + 부차 과정 배지 분리)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    celebration.memberName,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: isLandscape ? 22 : 26,
                                      fontWeight: FontWeight.w900,
                                      color: Colors.white,
                                      letterSpacing: -0.6,
                                    ),
                                  ),
                                ),
                                if (celebration.programTag != null &&
                                    celebration.programTag!.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF1E293B),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: Colors.white.withValues(alpha: 0.12), width: 0.8),
                                    ),
                                    child: Text(
                                      celebration.programTag!,
                                      style: const TextStyle(
                                        color: Color(0xFF38BDF8),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              '출석 체크가 정상 완료되었습니다!',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isLandscape ? 14 : 16,
                                fontWeight: FontWeight.w800,
                                color: const Color(0xFF34D399),
                                letterSpacing: -0.3,
                              ),
                            ),
                          ),

                          SizedBox(height: vGap),

                          // 5. Store-Grade Status Cards (Remaining Pass & Safe Parent SMS)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF111827).withValues(alpha: 0.85),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.confirmation_num_rounded, color: Color(0xFF38BDF8), size: 18),
                                            SizedBox(width: 8),
                                            Text(
                                              '이용권 잔여 현황',
                                              style: TextStyle(
                                                color: Color(0xFF94A3B8),
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Flexible(
                                        child: Text(
                                          celebration.passStatus,
                                          textAlign: TextAlign.end,
                                          style: const TextStyle(
                                            color: Color(0xFF10B981),
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Divider(color: Color(0xFF1F2937), height: 16),
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
                                              : '출결 기록 및 보호자 안심 알림 큐 적립 완료',
                                          style: TextStyle(
                                            color: celebration.isDemo ? const Color(0xFFFBBF24) : const Color(0xFFE2E8F0),
                                            fontSize: 12,
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

                          SizedBox(height: vGap),

                          // 6. Big Store-Style [확인] Action Button (Returns to PIN Check-in screen)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 440),
                            child: SizedBox(
                              width: double.infinity,
                              height: isLandscape ? 48 : 52,
                              child: ElevatedButton(
                                onPressed: () {
                                  HapticFeedback.lightImpact();
                                  _dismissCelebration();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF10B981),
                                  foregroundColor: Colors.white,
                                  elevation: 8,
                                  shadowColor: const Color(0xFF10B981).withValues(alpha: 0.5),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      '확인 (다음 출석하기)',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: vGap * 0.5),

                          const Text(
                            '확인 버튼 또는 화면을 터치하면 즉시 다음 출석을 진행합니다',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                          ),
                        ],
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
