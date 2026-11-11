import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/studio_profile.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import 'member_name_badge.dart';

/// Toss / Apple Wallet-style Luxury Digital Pass & QR Code Dialog
/// Renders authentic vector QR matrix with 3D penguin mascot center emblem,
/// attendance status, remaining sessions progress, and instant Kakao/SMS share.
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
      barrierColor: Colors.black.withAlpha((255 * 0.70).round()),
      builder: (ctx) => DigitalPassCardDialog(
        member: member,
        studio: studio,
        latestRecord: latestRecord,
      ),
    );
  }

  void _sharePass(BuildContext context) async {
    final statusText = latestRecord != null
        ? '${LocalizationService.tr('checked_in')} (${DateFormat('HH:mm').format(latestRecord!.timestamp)})'
        : LocalizationService.tr('waiting_checkin');

    final sessionInfo = member.billingType == BillingType.sessionBased
        ? '${member.remainingSessions} / ${member.totalSessions}'
        : LocalizationService.tr('common_monthly_pass');

    final text = '''
[${studio.studioName}] ${LocalizationService.tr('kiosk_mode_pin')} / Pass
━━━━━━━━━━━━━━━━
• ${member.primaryName}${member.secondaryTag != null ? ' (${member.secondaryTag})' : ''}
• ${LocalizationService.localizeBuiltInLabel(member.groupName)}
• $statusText
• $sessionInfo
• ${studio.instructorName} ${studio.roleTitle}
━━━━━━━━━━━━━━━━
''';

    await SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: '[${studio.studioName}] ${member.primaryName}',
      ),
    );
  }

  void _copyToClipboard(BuildContext context) {
    final text = '[${studio.studioName}] ${member.primaryName}';
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(LocalizationService.tr('common_copied')),
        duration: const Duration(seconds: 2),
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
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Pass Card Container (Toss / Apple Wallet Luxury Styling)
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxWidth: 380),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF0F172A), // Dark slate navy
                      Color(0xFF1E293B),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withAlpha((255 * 0.3).round()),
                      blurRadius: 32,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withAlpha((255 * 0.4).round()),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withAlpha((255 * 0.25).round()),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  children: [
                    // Ambient decorative gradient circle in top corner
                    Positioned(
                      top: -30,
                      right: -30,
                      child: Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppTheme.primaryBlue.withAlpha((255 * 0.15).round()),
                        ),
                      ),
                    ),

                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Header: Studio Name & Pass Badge
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    FittedBox(
                                      fit: BoxFit.scaleDown,
                                      alignment: Alignment.centerLeft,
                                      child: Text(
                                        studio.studioName,
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Colors.white,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                          letterSpacing: -0.3,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${studio.category} · ${studio.instructorName} ${studio.roleTitle}',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Colors.white.withAlpha((255 * 0.65).round()),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withAlpha((255 * 0.35).round()),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: const Color(0xFF38BDF8).withAlpha((255 * 0.6).round()),
                                    width: 1,
                                  ),
                                ),
                                child: const Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.verified_rounded, color: Color(0xFF38BDF8), size: 13),
                                    SizedBox(width: 4),
                                    Text(
                                      'PASS',
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
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

                          const SizedBox(height: 20),

                          // 2. Member Name & Attendance Status Badge
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withAlpha((255 * 0.12).round()),
                                        borderRadius: BorderRadius.circular(7),
                                      ),
                                      child: Text(
                                        member.groupName,
                                        style: const TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Color(0xFF93C5FD),
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    MemberNameBadge(
                                      member: member,
                                      isDark: true,
                                      nameStyle: const TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Colors.white,
                                        fontSize: 24,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: -0.4,
                                      ),
                                      showGroupName: false,
                                    ),
                                  ],
                                ),
                              ),

                              // Attendance Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: hasAttendedToday
                                      ? const Color(0xFF10B981).withAlpha((255 * 0.22).round())
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
                                    const SizedBox(width: 5),
                                    Text(
                                      hasAttendedToday
                                          ? LocalizationService.tr('checked_in')
                                          : LocalizationService.tr('waiting_checkin'),
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: hasAttendedToday
                                            ? const Color(0xFF34D399)
                                            : const Color(0xFFCBD5E1),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 18),

                          // 3. Central Vector QR Code Card with Mascot Watermark
                          Center(
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withAlpha((255 * 0.2).round()),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Vector QR Matrix with Center 3D Mascot Emblem
                                  SizedBox(
                                    width: 170,
                                    height: 170,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CustomPaint(
                                          size: const Size(170, 170),
                                          painter: _PassQrVectorPainter(
                                            seed: '${member.id}_${member.phone}_${studio.studioName}',
                                          ),
                                        ),
                                        // Center Mascot Emblem
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: const LinearGradient(
                                              colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                            ),
                                            border: Border.all(color: Colors.white, width: 2.5),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withAlpha((255 * 0.15).round()),
                                                blurRadius: 6,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: ClipOval(
                                            child: Image.asset(
                                              'assets/icons/mascot_profile.png',
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => const Icon(
                                                Icons.stars_rounded,
                                                color: AppTheme.primaryBlue,
                                                size: 26,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    LocalizationService.pick(
                                      ko: '키오스크 스캐너 또는 카메라에 비춰주세요',
                                      en: 'Present pass or PIN at the kiosk scanner',
                                      ja: 'キオスクまたは受付で提示してください',
                                      zh: '请向前台考勤终端出示此电子凭证',
                                      vi: 'Quét mã hoặc nhập PIN tại quầy Kiosk',
                                      es: 'Presenta tu pase en el quiosco',
                                    ),
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF475569),
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'ID: ${member.id} · PIN [$phoneTail]',
                                    style: const TextStyle(
                                      fontFamily: 'Pretendard',
                                      color: Color(0xFF94A3B8),
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 18),

                          // 4. Ticket Perforated Cutout Divider
                          Row(
                            children: List.generate(
                              24,
                              (i) => Expanded(
                                child: Container(
                                  height: 1,
                                  color: i.isEven
                                      ? Colors.white.withAlpha((255 * 0.2).round())
                                      : Colors.transparent,
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // 5. Remaining Sessions or Period Progress
                          if (member.billingType == BillingType.sessionBased) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  LocalizationService.tr('kiosk_success_pass_label'),
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    color: Colors.white.withAlpha((255 * 0.7).round()),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                RichText(
                                  text: TextSpan(
                                    children: [
                                      TextSpan(
                                        text: '${member.remainingSessions}',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: member.remainingSessions <= 2
                                              ? const Color(0xFFF87171)
                                              : const Color(0xFF38BDF8),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      TextSpan(
                                        text: LocalizationService.isDomestic
                                            ? ' / ${member.totalSessions}회'
                                            : ' / ${member.totalSessions}',
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          color: Colors.white.withAlpha((255 * 0.6).round()),
                                          fontSize: 12.5,
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
                                minHeight: 7,
                                backgroundColor: Colors.white.withAlpha((255 * 0.12).round()),
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  member.remainingSessions <= 2
                                      ? const Color(0xFFEF4444)
                                      : const Color(0xFF0284C7),
                                ),
                              ),
                            ),
                          ] else ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  LocalizationService.tr('billing_type_monthly'),
                                  style: TextStyle(
                                    fontFamily: 'Pretendard',
                                    color: Colors.white.withAlpha((255 * 0.7).round()),
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  LocalizationService.tr('common_monthly_pass'),
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    color: Color(0xFF38BDF8),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          const SizedBox(height: 14),

                          // 6. Pass Metadata Footer
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.white.withAlpha((255 * 0.06).round()),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.touch_app_rounded, color: Color(0xFF94A3B8), size: 14),
                                    const SizedBox(width: 5),
                                    Text(
                                      LocalizationService.pick(
                                        ko: '마지막 출석',
                                        en: 'Last Check-in',
                                        ja: '最終出席',
                                        zh: '最近签到',
                                        vi: 'Lần cuối',
                                        es: 'Última visita',
                                      ),
                                      style: TextStyle(
                                        fontFamily: 'Pretendard',
                                        color: Colors.white.withAlpha((255 * 0.6).round()),
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  latestRecord != null
                                      ? DateFormat('yyyy.MM.dd HH:mm').format(latestRecord!.timestamp)
                                      : '-',
                                  style: const TextStyle(
                                    fontFamily: 'Pretendard',
                                    color: Color(0xFFCBD5E1),
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
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

              const SizedBox(height: 16),

              // Action Buttons Row (Kakao/SMS share, Copy, Close)
              Container(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _sharePass(context),
                        icon: const Icon(Icons.share_rounded, size: 17, color: Colors.white),
                        label: Text(
                          LocalizationService.pick(
                            ko: '카톡 / 문자 공유',
                            en: 'Share / Send Pass',
                            ja: '共有・メッセージ送信',
                            zh: '分享 / 发送电子卡',
                            vi: 'Chia sẻ / Gửi thẻ',
                            es: 'Compartir / Enviar',
                          ),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: Colors.white,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: () => _copyToClipboard(context),
                      icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 19),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha((255 * 0.16).round()),
                        padding: const EdgeInsets.all(13),
                      ),
                      tooltip: LocalizationService.pick(
                        ko: '출결패스 복사',
                        en: 'Copy Pass',
                        ja: 'パスをコピー',
                        zh: '复制通行证',
                        vi: 'Sao chép thẻ',
                        es: 'Copiar pase',
                      ),
                    ),
                    const SizedBox(width: 6),
                    IconButton.filledTonal(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: Colors.white, size: 19),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white.withAlpha((255 * 0.16).round()),
                        padding: const EdgeInsets.all(13),
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
  }
}

/// High-Definition Vector QR Code Matrix Painter with Standard Finder Patterns
class _PassQrVectorPainter extends CustomPainter {
  final String seed;

  _PassQrVectorPainter({required this.seed});

  @override
  void paint(Canvas canvas, Size size) {
    const int gridSize = 25; // 25x25 QR Version 2
    final double moduleSize = size.width / gridSize;

    final Paint darkPaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.fill;

    // Deterministic pseudo-random matrix based on seed hash
    final int hash = seed.hashCode.abs();
    final Random random = Random(hash);

    // Reserved area check (Finder patterns & Center logo)
    bool isFinderPattern(int r, int c) {
      // Top-Left (0..6, 0..6)
      if (r <= 6 && c <= 6) return true;
      // Top-Right (0..6, 18..24)
      if (r <= 6 && c >= 18) return true;
      // Bottom-Left (18..24, 0..6)
      if (r >= 18 && c <= 6) return true;
      return false;
    }

    bool isCenterLogoArea(int r, int c) {
      // Center 7x7 cutout for mascot avatar (r: 9..15, c: 9..15)
      return (r >= 9 && r <= 15 && c >= 9 && c <= 15);
    }

    bool isTimingPattern(int r, int c) {
      if (r == 6 && c > 6 && c < 18) return true;
      if (c == 6 && r > 6 && r < 18) return true;
      return false;
    }

    // 1. Draw Data Modules
    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        if (isFinderPattern(r, c) || isCenterLogoArea(r, c)) continue;

        if (isTimingPattern(r, c)) {
          if ((r == 6 && c % 2 == 0) || (c == 6 && r % 2 == 0)) {
            final rect = Rect.fromLTWH(
              c * moduleSize + 0.5,
              r * moduleSize + 0.5,
              moduleSize - 1,
              moduleSize - 1,
            );
            canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1.2)), darkPaint);
          }
          continue;
        }

        // Pseudo-random data module with seed
        if (random.nextBool()) {
          final rect = Rect.fromLTWH(
            c * moduleSize + 0.4,
            r * moduleSize + 0.4,
            moduleSize - 0.8,
            moduleSize - 0.8,
          );
          canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1.2)), darkPaint);
        }
      }
    }

    // 2. Draw 3 Standard Finder Patterns (7x7 outer, 5x5 white inner, 3x3 black center)
    void drawFinder(double startX, double startY) {
      // Outer 7x7 box
      final outerRect = Rect.fromLTWH(startX, startY, 7 * moduleSize, 7 * moduleSize);
      canvas.drawRRect(RRect.fromRectAndRadius(outerRect, Radius.circular(moduleSize * 1.5)), darkPaint);

      // Inner 5x5 white cutout
      final whitePaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      final innerWhiteRect = Rect.fromLTWH(
        startX + moduleSize,
        startY + moduleSize,
        5 * moduleSize,
        5 * moduleSize,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(innerWhiteRect, Radius.circular(moduleSize * 1.0)), whitePaint);

      // Center 3x3 solid box
      final centerRect = Rect.fromLTWH(
        startX + 2 * moduleSize,
        startY + 2 * moduleSize,
        3 * moduleSize,
        3 * moduleSize,
      );
      canvas.drawRRect(RRect.fromRectAndRadius(centerRect, Radius.circular(moduleSize * 0.8)), darkPaint);
    }

    // Top-Left Finder
    drawFinder(0, 0);
    // Top-Right Finder
    drawFinder((gridSize - 7) * moduleSize, 0);
    // Bottom-Left Finder
    drawFinder(0, (gridSize - 7) * moduleSize);
  }

  @override
  bool shouldRepaint(covariant _PassQrVectorPainter oldDelegate) => oldDelegate.seed != seed;
}
