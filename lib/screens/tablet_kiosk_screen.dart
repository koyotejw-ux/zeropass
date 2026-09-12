import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/localization_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';

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

  void _onKeyTap(String key) {
    if (_isProcessing) return;
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
      setState(() {
        _digits = _digits.substring(0, _digits.length - 1);
        _statusMessage = null;
      });
    }
  }

  void _onClear() {
    if (!_isProcessing) {
      setState(() {
        _digits = '';
        _statusMessage = null;
      });
    }
  }

  Future<void> _processCheckIn() async {
    setState(() {
      _isProcessing = true;
    });

    final members = ref.read(membersProvider).value ?? [];
    final studio = ref.read(studioProfileProvider).value ?? StudioProfile.defaultProfile();

    // Find member by last 4 digits of phone number
    final matchedMembers = members.where((m) {
      final clean = m.phone.replaceAll(RegExp(r'[^0-9]'), '');
      return clean.endsWith(_digits);
    }).toList();

    if (matchedMembers.isEmpty) {
      setState(() {
        _isProcessing = false;
        _isSuccess = false;
        _statusMessage = '일치하는 회원을 찾을 수 없습니다.\n원장님께 번호 등록을 문의해 주세요.';
        _digits = '';
      });
      return;
    }

    // Process check-in for the matched member (or first one)
    final member = matchedMembers.first;

    try {
      await ref.read(passRecordsProvider.notifier).checkInMember(member: member);
      await ref.read(membersProvider.notifier).reload();

      // Send attendance SMS if phone is provided
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

      setState(() {
        _isProcessing = false;
        _isSuccess = true;
        _statusMessage = '반가워요, ${member.name}님! 🎉\n출석 체크 완료! ($remaining)\n보호자 안심 문자가 전송되었습니다.';
        _digits = '';
      });

      // Auto clear success message after 4 seconds
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

  void _showExitDialog() {
    final passwordCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('관리자 키오스크 모드 종료'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '회원들의 무단 화면 조작 방지를 위해 관리자 종료 번호를 입력해주세요.\n(기본 번호: 0000)',
                style: TextStyle(fontSize: 13, height: 1.4, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: passwordCtrl,
                keyboardType: TextInputType.number,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: '관리자 비밀번호',
                  border: OutlineInputBorder(),
                ),
                autofocus: true,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              if (passwordCtrl.text.trim() == '0000') {
                Navigator.pop(ctx);
                Navigator.pop(context);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('비밀번호가 올바르지 않습니다.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('종료하고 장부로 복귀', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();
    final now = DateTime.now();
    final dateStr = DateFormat('yyyy년 MM월 dd일 (E)', 'ko_KR').format(now);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Dark Navy Premium Kiosk
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            return isLandscape
                ? _buildLandscapeKiosk(studio, dateStr)
                : _buildPortraitKiosk(studio, dateStr);
          },
        ),
      ),
    );
  }

  Widget _buildPortraitKiosk(StudioProfile studio, String dateStr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical - 24,
        ),
        child: IntrinsicHeight(
          child: Column(
            children: [
              // Top Header (Studio Info & Exit Button)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1E293B),
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/icons/splash_icon.png', fit: BoxFit.cover),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            studio.studioName,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            dateStr,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.lock_outline, color: Color(0xFF64748B)),
                    tooltip: '키오스크 종료 (관리자)',
                    onPressed: _showExitDialog,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Main Prompt & Mascot
              Text(
                LocalizationService.tr('kiosk_prompt'),
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFE2E8F0),
                ),
              ),
              const SizedBox(height: 14),

              // Digits Box Display
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final isFilled = index < _digits.length;
                  final char = isFilled ? _digits[index] : '';

                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 6),
                    width: 52,
                    height: 60,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isFilled ? AppTheme.softMint : const Color(0xFF334155),
                        width: isFilled ? 2.5 : 1.2,
                      ),
                      boxShadow: isFilled
                          ? [
                              BoxShadow(
                                color: AppTheme.softMint.withValues(alpha: 0.3),
                                blurRadius: 10,
                              ),
                            ]
                          : null,
                    ),
                    child: Text(
                      char,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 12),

              // Status Feedback Banner
              if (_statusMessage != null)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _isSuccess ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _statusMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.35,
                    ),
                  ),
                )
              else
                const SizedBox(height: 20),

              const Spacer(),

              // Number Keypad
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 320),
                  child: _buildKeypad(),
                ),
              ),
              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLandscapeKiosk(StudioProfile studio, String dateStr) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.vertical - 24,
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Studio Info, Mascot, Display
              Expanded(
                flex: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          studio.studioName,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                        IconButton(
                          icon: const Icon(Icons.lock_outline, color: Color(0xFF64748B)),
                          onPressed: _showExitDialog,
                        ),
                      ],
                    ),
                    Text(dateStr, style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8))),
                    const SizedBox(height: 16),
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF1E293B),
                        ),
                        child: ClipOval(
                          child: Image.asset('assets/icons/splash_icon.png', fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Center(
                      child: Text(
                        '전화번호 뒷자리 4자리를 누르면\n1초 만에 출결 체크 & 안심 문자가 전송돼요!',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: Color(0xFFCBD5E1), height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(4, (index) {
                        final isFilled = index < _digits.length;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 5),
                          width: 44,
                          height: 52,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isFilled ? AppTheme.softMint : const Color(0xFF334155),
                              width: isFilled ? 2.5 : 1,
                            ),
                          ),
                          child: Text(
                            isFilled ? _digits[index] : '',
                            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                          ),
                        );
                      }),
                    ),
                    if (_statusMessage != null) ...[
                      const SizedBox(height: 10),
                      Center(
                        child: Text(
                          _statusMessage!,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: _isSuccess ? AppTheme.softMint : Colors.redAccent,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 24),

              // Right: Keypad
              Expanded(
                flex: 4,
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 300),
                    child: _buildKeypad(),
                  ),
                ),
              ),
            ],
          ),
        ),
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
            const SizedBox(width: 14),
            _buildKeypadButton('2'),
            const SizedBox(width: 14),
            _buildKeypadButton('3'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('4'),
            const SizedBox(width: 14),
            _buildKeypadButton('5'),
            const SizedBox(width: 14),
            _buildKeypadButton('6'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildKeypadButton('7'),
            const SizedBox(width: 14),
            _buildKeypadButton('8'),
            const SizedBox(width: 14),
            _buildKeypadButton('9'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildActionKeypadButton('초기화', Icons.refresh, _onClear),
            const SizedBox(width: 14),
            _buildKeypadButton('0'),
            const SizedBox(width: 14),
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
        width: 82,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155), width: 1.2),
        ),
        child: Text(
          num,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
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
        width: 82,
        height: 68,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 22, color: const Color(0xFF94A3B8)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}
