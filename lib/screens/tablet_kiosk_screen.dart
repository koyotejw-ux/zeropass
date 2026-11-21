import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/localization_service.dart';
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
  bool _isNameSearchMode = false;
  final TextEditingController _nameSearchCtrl = TextEditingController();
  String _nameQuery = '';
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
    _nameSearchCtrl.dispose();
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

      final matched = matchedMembers.isNotEmpty ? matchedMembers.first : null;
      final celebration = AttendanceCelebration(
        digits: enteredCode,
        memberName: matched != null ? matched.name : '강지훈 회원',
        programTag: matched != null ? matched.groupName : 'PT 화목반',
        passStatus: matched != null ? '잔여 11회 (1회 차감 완료)' : '10회권 (잔여 9회)', 
        timeStr: DateFormat('yyyy.MM.dd HH:mm:ss').format(DateTime.now()),
        isDemo: true,
        isSuccess: true,
        smsMessage: LocalizationService.tr('kiosk_success_headline'),
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
        _statusMessage = LocalizationService.trParams('kiosk_pin_not_found', {'code': enteredCode});
        _digits = '';
      });
      return;
    }

    // 4. 실제 회원 정상 출결 처리
    await _checkInMatchedMember(matchedMembers.first, enteredCode, studio);
  }

  Future<void> _checkInMatchedMember(
    Member member,
    String enteredCode,
    StudioProfile studio,
  ) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = null;
    });
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
          ? LocalizationService.trParams('common_sessions_left', {'n': '${member.remainingSessions - 1}'})
          : LocalizationService.tr('common_monthly_pass');

      final celebration = AttendanceCelebration(
        digits: enteredCode,
        memberName: member.name,
        programTag: member.groupName.isNotEmpty ? member.groupName : member.secondaryTag,
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
        _nameSearchCtrl.clear();
        _nameQuery = '';
        _statusMessage = null;
        _digits = '';
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = '${LocalizationService.tr('kiosk_pin_not_found')} ($e)';
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
        title: Row(
          children: [
            const Icon(Icons.admin_panel_settings_rounded, color: Color(0xFF38BDF8), size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LocalizationService.tr('kiosk_master_exit_title'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Text(
          LocalizationService.tr('kiosk_master_exit_desc'),
          style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(LocalizationService.tr('common_cancel'), style: const TextStyle(color: Color(0xFF94A3B8))),
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
            child: Text(
              LocalizationService.tr('kiosk_empty_back_btn'),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  /// 언어 간편 전환 다이얼로그 (키오스크 이용 학생/회원 편의)
  void _showLanguageSwitchDialog() {
    final curLang = LocalizationService.currentLanguage;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            const Icon(Icons.language_rounded, color: Color(0xFF38BDF8), size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                LocalizationService.tr('language'),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: AppLanguage.values.map((lang) {
              final isSelected = lang == curLang;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(languageProvider.notifier).setLanguage(lang, autoUpdateCurrency: false);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? const Color(0xFF0284C7).withValues(alpha: 0.25) : const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected ? const Color(0xFF38BDF8) : Colors.white.withValues(alpha: 0.08),
                        width: isSelected ? 1.5 : 1.0,
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(lang.flag, style: const TextStyle(fontSize: 22)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                lang.label,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
                                  fontSize: 14.5,
                                ),
                              ),
                              Text(
                                lang.englishLabel,
                                style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const Icon(Icons.check_circle_rounded, color: Color(0xFF38BDF8), size: 20),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              LocalizationService.tr('btn_cancel'),
              style: const TextStyle(color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
            ),
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
          title: Row(
            children: [
              const Icon(Icons.lock_rounded, color: Color(0xFFFBBF24), size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LocalizationService.tr('kiosk_exit_title'),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocalizationService.tr('kiosk_exit_desc'),
                style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 13.5, height: 1.5),
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
              child: Text(LocalizationService.tr('common_close'), style: const TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              onPressed: () {
                if (pinController.text.trim() == '0000') {
                  Navigator.pop(ctx);
                  _exitToDashboard();
                } else {
                  setDialogState(() {
                    errorMessage = LocalizationService.tr('kiosk_pin_mismatch');
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              ),
              child: Text(LocalizationService.tr('common_confirm'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    final studio = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();
    final members = ref.watch(membersProvider).value ?? [];
    final dateStr = DateFormat.yMMMEd(LocalizationService.currentLanguage.code).format(_currentTime);
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
                            child: Text(
                              LocalizationService.pick(
                                ko: '운영 데이터 안내',
                                en: 'Setup Needed',
                                ja: '登録案内',
                                zh: '数据提示',
                                vi: 'Thông báo dữ liệu',
                                es: 'Aviso de configuración',
                              ),
                              style: const TextStyle(
                                color: Color(0xFFFBBF24),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            LocalizationService.tr('kiosk_empty_title'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                              height: 1.35,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            LocalizationService.tr('kiosk_empty_desc'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
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
                                            SnackBar(content: Text(LocalizationService.tr('kiosk_empty_seed_btn'))),
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
                                LocalizationService.tr('kiosk_empty_seed_btn'),
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
                              label: Text(
                                LocalizationService.tr('kiosk_empty_demo_btn'),
                                style: const TextStyle(color: Color(0xFFA5B4FC), fontWeight: FontWeight.w700, fontSize: 13.5),
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
                            label: Text(
                              LocalizationService.tr('kiosk_empty_back_btn'),
                              style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12.5),
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
    if (_isNameSearchMode) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          children: [
            _buildTopHeader(studio, dateStr, timeStr),
            const SizedBox(height: 12),
            _buildQuickTestChips(members),
            const SizedBox(height: 16),
            _buildPromptAndMascot(),
            const SizedBox(height: 16),
            Expanded(child: _buildNameLookupPanel(members, studio)),
          ],
        ),
      );
    }

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

              const Spacer(flex: 1),

              // Center: Prompt & Mode Toggle
              _buildPromptAndMascot(),
              const SizedBox(height: 20),

              // 4-Digit Display Boxes
              _buildDigitBoxes(),
              if (_statusMessage != null) ...[
                const SizedBox(height: 16),
                _buildStatusCard(),
              ],

              const Spacer(flex: 2),

              // Keypad (FittedBox to prevent overflow on small screens)
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width >= 600 ? 460 : 340),
                    child: _buildKeypad(),
                  ),
                ),
              ),
              const Spacer(flex: 2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeKiosk(StudioProfile studio, List<Member> members, String dateStr, String timeStr) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Column(
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

                  // Right Column: Keypad OR Name Lookup
                  Expanded(
                    flex: 4,
                    child: _isNameSearchMode
                        ? _buildNameLookupPanel(members, studio)
                        : Center(
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
        );

        if (_isNameSearchMode) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: SizedBox(
              height: (constraints.maxHeight - 20).clamp(0.0, double.infinity),
              child: content,
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight: (constraints.maxHeight - 20).clamp(0.0, double.infinity),
            ),
            child: IntrinsicHeight(child: content),
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
      showMascot: false,
      useBrandEmblem: true,
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
                            studio.studioName.isNotEmpty
                                ? studio.studioName
                                : LocalizationService.tr('kiosk_brand_title'),
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
                            child: Text(
                              LocalizationService.tr('kiosk_demo_badge'),
                              style: const TextStyle(
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
            child: const Icon(Icons.language_rounded, color: Color(0xFF38BDF8), size: 20),
          ),
          tooltip: LocalizationService.tr('language'),
          onPressed: _showLanguageSwitchDialog,
        ),
        const SizedBox(width: 4),
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
          tooltip: LocalizationService.tr('kiosk_exit_prompt'),
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
          Flexible(
            child: Text(
              LocalizationService.tr('kiosk_demo_admin_badge'),
              style: const TextStyle(
                color: Color(0xFFA5B4FC),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          _buildQuickPinBadge(
            _QuickPinItem(pin: '1234', tag: LocalizationService.tr('kiosk_demo_pin_label'), color: const Color(0xFF38BDF8)),
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
    return Column(
      children: [
        Text(
          _isNameSearchMode
              ? LocalizationService.tr('kiosk_name_search_hint')
              : LocalizationService.tr('kiosk_prompt'),
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          LocalizationService.tr('kiosk_sub_prompt'),
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12.5, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildModePill(
                label: LocalizationService.tr('kiosk_mode_pin'),
                selected: !_isNameSearchMode,
                onTap: () => setState(() => _isNameSearchMode = false),
              ),
              _buildModePill(
                label: LocalizationService.tr('kiosk_mode_name'),
                selected: _isNameSearchMode,
                onTap: () => setState(() => _isNameSearchMode = true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildModePill({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? const Color(0xFF38BDF8) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: selected ? const Color(0xFF0B0F19) : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildNameLookupPanel(List<Member> members, StudioProfile studio) {
    final query = _nameQuery.trim().toLowerCase();
    final filtered = members.where((m) {
      if (query.isEmpty) return true;
      return m.name.toLowerCase().contains(query) || m.groupName.toLowerCase().contains(query);
    }).toList();

    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _nameSearchCtrl,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            onChanged: (val) => setState(() => _nameQuery = val),
            decoration: InputDecoration(
              hintText: LocalizationService.tr('kiosk_name_search_hint'),
              hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
              prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFF38BDF8)),
              filled: true,
              fillColor: const Color(0xFF0F172A),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Text(
                      LocalizationService.tr('kiosk_name_empty'),
                      style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                    ),
                  )
                : ListView.separated(
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 6),
                    itemBuilder: (_, idx) {
                      final m = filtered[idx];
                      final clean = m.phone.replaceAll(RegExp(r'[^0-9]'), '');
                      final last4 = clean.length >= 4 ? clean.substring(clean.length - 4) : '0000';
                      return Material(
                        color: Colors.transparent,
                        child: ListTile(
                          tileColor: const Color(0xFF0F172A),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          title: Text(
                            m.primaryName,
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                          ),
                          subtitle: Text(
                            LocalizationService.localizeBuiltInLabel(m.groupName),
                            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                          ),
                          trailing: ElevatedButton(
                            onPressed: _isProcessing ? null : () => _checkInMatchedMember(m, last4, studio),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: Text(LocalizationService.tr('kiosk_tap_checkin'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDigitBoxes() {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final boxW = isTablet ? 76.0 : 56.0;
    final boxH = isTablet ? 90.0 : 66.0;
    final fontSz = isTablet ? 42.0 : 32.0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (index) {
        final isFilled = index < _digits.length;
        final digitChar = isFilled ? _digits[index] : '';

        return AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.symmetric(horizontal: isTablet ? 10 : 6),
          width: boxW,
          height: boxH,
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
                  style: TextStyle(
                    fontSize: fontSz,
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
            _buildActionKeypadButton(LocalizationService.tr('common_reset'), Icons.refresh_rounded, _onClear),
            const SizedBox(width: 12),
            _buildKeypadButton('0'),
            const SizedBox(width: 12),
            _buildActionKeypadButton(LocalizationService.tr('common_backspace'), Icons.backspace_outlined, _onBackspace),
          ],
        ),
      ],
    );
  }

  Widget _buildKeypadButton(String num) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final btnW = isTablet ? 116.0 : 86.0;
    final btnH = isTablet ? 84.0 : 68.0;
    final fontSz = isTablet ? 36.0 : 28.0;

    return InkWell(
      onTap: () => _onKeyTap(num),
      borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
      child: Container(
        width: btnW,
        height: btnH,
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
          style: TextStyle(
            fontSize: fontSz,
            fontWeight: FontWeight.w900,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildActionKeypadButton(String label, IconData icon, VoidCallback onTap) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final btnW = isTablet ? 116.0 : 86.0;
    final btnH = isTablet ? 84.0 : 68.0;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
      child: Container(
        width: btnW,
        height: btnH,
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
                  final isTablet = constraints.maxWidth >= 600;
                  final isCompact = constraints.maxHeight < 680;
                  final vGap = isLandscape ? 8.0 : (isTablet ? 24.0 : (isCompact ? 10.0 : 16.0));
                  final avatarSize = isLandscape ? 72.0 : (isTablet ? 124.0 : (isCompact ? 80.0 : 96.0));
                  final digitBoxWidth = isTablet ? 72.0 : ((constraints.maxWidth - 64) / 4).clamp(40.0, 58.0);
                  final digitBoxHeight = digitBoxWidth * 1.18;

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
                                      studio.studioName.isNotEmpty
                                          ? studio.studioName
                                          : LocalizationService.tr('kiosk_brand_title'),
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

                          // 2. Avatar Circle: Member Photo if registered, else Naturally Masked 3D Penguin (축하 활짝 웃음)
                          ZeroPassMascotAvatar(
                            size: avatarSize,
                            name: celebration.memberName,
                            photoPath: celebration.photoPath,
                            showMascot: false,
                            useBrandEmblem: false,
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
                              Text(
                                LocalizationService.trParams('kiosk_success_pin_label', {'code': celebration.digits}),
                                style: const TextStyle(
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
                              LocalizationService.tr('kiosk_success_headline'),
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
                                      Flexible(
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.confirmation_num_rounded, color: Color(0xFF38BDF8), size: 18),
                                            const SizedBox(width: 8),
                                            Flexible(
                                              child: Text(
                                                LocalizationService.tr('kiosk_success_pass_label'),
                                                style: const TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w600,
                                                ),
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
                                          LocalizationService.tr('kiosk_success_queue_note'),
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
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.check_circle_rounded, size: 22),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(
                                        LocalizationService.tr('kiosk_success_confirm_btn'),
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: -0.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),

                          SizedBox(height: vGap * 0.5),

                          Text(
                            LocalizationService.tr('kiosk_success_auto_hint'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
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
