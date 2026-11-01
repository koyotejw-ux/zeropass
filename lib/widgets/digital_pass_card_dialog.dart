import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/studio_profile.dart';
import '../theme/app_theme.dart';

/// Toss/Apple Wallet-style Digital Membership & Check-in Pass Card Dialog
/// Allows instant mobile pass verification & sharing via KakaoTalk/SMS
class DigitalPassCardDialog extends StatelessWidget {
  final Member member;
  final StudioProfile studio;
  final PassRecord? latestRecord;

  const DigitalPassCardDialog({
    super.key,
    required this.member,
    required this.studio,
    this.latestRecord,
  });

  static Future<void> show({
    required BuildContext context,
    required Member member,
    required StudioProfile studio,
    PassRecord? latestRecord,
  }) {
    HapticFeedback.mediumImpact();
    return showDialog(
      context: context,
      barrierColor: Colors.black.withAlpha((255 * 0.65).round()),
      builder: (ctx) => DigitalPassCardDialog(
        member: member,
        studio: studio,
        latestRecord: latestRecord,
      ),
    );
  }

  void _sharePass(BuildContext context) async {
    final statusText = latestRecord != null
        ? '오늘 출석 완료 (${DateFormat('HH:mm').format(latestRecord!.timestamp)})'
        : '수업 대기 중';

    final sessionInfo = member.billingType == BillingType.sessionBased
        ? '남은 횟수: ${member.remainingSessions}회 / 총 ${member.totalSessions}회'
        : '이용 구분: 월 정기권';

    final text = '''
[${studio.studioName}] 모바일 스마트 출결패스 🎫
━━━━━━━━━━━━━━━━
• 회원명: ${member.name}
• 등록반: ${member.groupName}
• 상태: $statusText
• $sessionInfo
• 담당: ${studio.instructorName} ${studio.roleTitle}
━━━━━━━━━━━━━━━━
안전하고 편리한 원터치 출결 체크앤페이
''';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: '[${studio.studioName}] ${member.name}님의 모바일 출결패스',
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final text = '[${studio.studioName}] ${member.name} 모바일 패스 확인되었습니다.';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('출결패스 정보가 클립보드에 복사되었습니다.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasAttendedToday = latestRecord != null;
    final phoneTail = member.phone.length >= 4
        ? member.phone.substring(member.phone.length - 4)
        : member.phone;

    final progressRatio = member.billingType == BillingType.sessionBased && member.totalSessions > 0
        ? (member.remainingSessions / member.totalSessions).clamp(0.0, 1.0)
        : 1.0;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pass Card Body
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF1E293B),
                      Color(0xFF0F172A),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withAlpha((255 * 0.25).round()),
                      blurRadius: 30,
                      offset: const Offset(0, 12),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withAlpha((255 * 0.12).round()),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative glow circle
                    Positioned(
                      top: -40,
                      right: -40,
                      child: Container(
                        width: 140,
                        height: 140,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryBlue.withAlpha((255 * 0.2).round()),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.all(26),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Studio Name & Brand Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      studio.studioName,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 17,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.3,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${studio.category} · ${studio.instructorName} ${studio.roleTitle}',
                                      style: TextStyle(
                                        color: Colors.white.withAlpha((255 * 0.65).round()),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: AppTheme.primaryBlue.withAlpha((255 * 0.25).round()),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: AppTheme.primaryBlue.withAlpha((255 * 0.6).round()),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, color: AppTheme.primaryBlue, size: 13),
                                    SizedBox(width: 4),
                                    Text(
                                      'PASS',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 28),

                          // Member Main Info
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha((255 * 0.1).round()),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        member.groupName,
                                        style: const TextStyle(
                                          color: Color(0xFF93C5FD),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      member.name,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 26,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Attendance Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                decoration: BoxDecoration(
                                  color: hasAttendedToday
                                      ? const Color(0xFF10B981).withAlpha((255 * 0.25).round())
                                      : const Color(0xFF64748B).withAlpha((255 * 0.25).round()),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: hasAttendedToday
                                        ? const Color(0xFF10B981)
                                        : const Color(0xFF94A3B8),
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
                                        color: hasAttendedToday
                                            ? const Color(0xFF10B981)
                                            : const Color(0xFF94A3B8),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      hasAttendedToday ? '오늘 출석 완료' : '수업 대기',
                                      style: TextStyle(
                                        color: hasAttendedToday
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFFCBD5E1),
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Divider Line with Ticket Cutouts
                          Row(
                            children: List.generate(
                              24,
                              (i) => Expanded(
                                child: Container(
                                  height: 1,
                                  color: i.isEven
                                      ? Colors.white.withAlpha((255 * 0.15).round())
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Session or Period Progress
                          if (member.billingType == BillingType.sessionBased) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '잔여 회차',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha((255 * 0.7).round()),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${member.remainingSessions}',
                                        style: TextStyle(
                                          color: member.remainingSessions <= 2
                                              ? const Color(0xFFF87171)
                                              : const Color(0xFF60A5FA),
                                          fontSize: 17,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      TextSpan(
                                        text: ' / ${member.totalSessions}회',
                                        style: TextStyle(
                                          color: Colors.white.withAlpha((255 * 0.6).round()),
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: progressRatio,
                                minHeight: 8,
                                backgroundColor: Colors.white.withAlpha((255 * 0.1).round()),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  member.remainingSessions <= 2
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF3B82F6),
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '수강 형태',
                                  style: TextStyle(
                                    color: Colors.white.withAlpha((255 * 0.7).round()),
                                    fontSize: 13,
                                  ),
                                ),
                                const Text(
                                  '매월 정기 수강권',
                                  style: TextStyle(
                                    color: Color(0xFF60A5FA),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 18),

                          // Pass Metadata Footer (Phone & Last Check-In)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha((255 * 0.05).round()),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.dialpad_rounded, color: Color(0xFF94A3B8), size: 16),
                                    const SizedBox(width: 6),
                                    Text(
                                      '인증키 [뒷자리 $phoneTail]',
                                      style: const TextStyle(
                                        color: Color(0xFFCBD5E1),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                if (latestRecord != null)
                                  Text(
                                    DateFormat('yyyy.MM.dd HH:mm').format(latestRecord!.timestamp),
                                    style: TextStyle(
                                      color: Colors.white.withAlpha((255 * 0.5).round()),
                                      fontSize: 11,
                                    ),
                                  )
                                else
                                  Text(
                                    '최근 출석 기록 없음',
                                    style: TextStyle(
                                      color: Colors.white.withAlpha((255 * 0.4).round()),
                                      fontSize: 11,
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

              const SizedBox(height: 18),

              // Action Buttons Row
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _sharePass(context),
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('카톡 / 문자 공유'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filledTonal(
                    onPressed: () => _copyToClipboard(context),
                    icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha((255 * 0.15).round()),
                      padding: const EdgeInsets.all(14),
                    ),
                    tooltip: '출결패스 복사',
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, color: Colors.white, size: 20),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withAlpha((255 * 0.15).round()),
                      padding: const EdgeInsets.all(14),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
