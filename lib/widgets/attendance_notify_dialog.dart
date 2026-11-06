import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/notification_log.dart';
import '../models/studio_profile.dart';
import '../services/database_service.dart';
import '../services/kakao_share_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';


enum AttendanceNotifyType {
  checkIn, // 등원 / 출석
  checkOut, // 하원 / 귀가
}

class AttendanceNotifyDialog extends StatefulWidget {
  final Member member;
  final StudioProfile studio;
  final AttendanceNotifyType type;
  final DateTime time;
  final Future<bool> Function(String text, String? subject)? onShareKakao;
  final Future<bool> Function(String phone, String body)? onSendSms;

  const AttendanceNotifyDialog({
    super.key,
    required this.member,
    required this.studio,
    required this.type,
    required this.time,
    this.onShareKakao,
    this.onSendSms,
  });

  static Future<void> show({
    required BuildContext context,
    required Member member,
    required StudioProfile studio,
    required AttendanceNotifyType type,
    DateTime? time,
    Future<bool> Function(String text, String? subject)? onShareKakao,
    Future<bool> Function(String phone, String body)? onSendSms,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => AttendanceNotifyDialog(
        member: member,
        studio: studio,
        type: type,
        time: time ?? DateTime.now(),
        onShareKakao: onShareKakao,
        onSendSms: onSendSms,
      ),
    );
  }

  @override
  State<AttendanceNotifyDialog> createState() => _AttendanceNotifyDialogState();
}

class _AttendanceNotifyDialogState extends State<AttendanceNotifyDialog> {
  late TextEditingController _messageController;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    final defaultMsg = widget.type == AttendanceNotifyType.checkIn
        ? SmsTemplateService.generateAttendanceMessage(
            studio: widget.studio,
            member: widget.member,
            time: widget.time,
          )
        : SmsTemplateService.generateDepartureMessage(
            studio: widget.studio,
            member: widget.member,
            time: widget.time,
          );
    _messageController = TextEditingController(text: defaultMsg);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendViaKakao() async {
    setState(() => _isSending = true);
    final msg = _messageController.text.trim();
    final subject = '[${widget.studio.studioName}] ${widget.type == AttendanceNotifyType.checkIn ? "등원 알림" : "하원 알림"}';

    bool success = false;
    if (widget.onShareKakao != null) {
      success = await widget.onShareKakao!(msg, subject);
    } else {
      success = await KakaoShareService.shareMessage(text: msg, subject: subject);
    }

    await _logNotification(channel: 'KAKAO', message: msg, isSuccess: success);

    if (mounted) {
      setState(() => _isSending = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.member.name} 보호자 카카오톡 안심 알림 전송 완료'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _sendViaSms() async {
    setState(() => _isSending = true);
    final msg = _messageController.text.trim();

    bool success = false;
    if (widget.onSendSms != null) {
      success = await widget.onSendSms!(widget.member.phone, msg);
    } else {
      success = await SmsTemplateService.launchNativeSms(
        recipientPhone: widget.member.phone,
        body: msg,
      );
    }

    await _logNotification(channel: 'SMS', message: msg, isSuccess: success);

    if (mounted) {
      setState(() => _isSending = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.member.name} 보호자 문자(SMS) 안심 알림 전송 완료'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _logNotification({
    required String channel,
    required String message,
    required bool isSuccess,
  }) async {
    try {
      final notifType = widget.type == AttendanceNotifyType.checkIn
          ? NotificationType.attendance
          : NotificationType.departure;

      await DatabaseService.instance.insertNotificationLog(
        NotificationLog(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${widget.member.id}',
          type: notifType,
          memberId: widget.member.id,
          memberName: widget.member.name,
          recipientPhone: widget.member.phone,
          channel: channel,
          message: message,
          sentAt: DateTime.now(),
          isSuccess: isSuccess,
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final isCheckIn = widget.type == AttendanceNotifyType.checkIn;
    final timeStr = DateFormat('a h시 mm분', 'ko_KR').format(widget.time);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(20),
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  (widget.studio.logoPath != null &&
                          widget.studio.logoPath!.isNotEmpty &&
                          File(widget.studio.logoPath!).existsSync())
                      ? Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(
                              File(widget.studio.logoPath!),
                              fit: BoxFit.cover,
                            ),
                          ),
                        )
                      : Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCheckIn
                                ? const Color(0xFF10B981).withValues(alpha: 0.12)
                                : const Color(0xFF3182F6).withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                            color: isCheckIn ? const Color(0xFF10B981) : AppTheme.primaryBlue,
                            size: 24,
                          ),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCheckIn ? '안심 등원 알림장 발송' : '안심 하원 알림장 발송',
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.member.name} (${widget.member.phone}) • $timeStr',
                          style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Message Edit Area
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '보호자 전송 문구 (발송 전 수정 가능)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 13, height: 1.45),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendViaKakao,
                      icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF191919)),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '카톡 0원 전송',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Color(0xFF191919)),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEE500),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isSending ? null : _sendViaSms,
                      icon: const Icon(Icons.sms_outlined, size: 16, color: Colors.white),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '문자(SMS) 전송',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: Colors.white),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('나중에 전송 / 닫기', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
