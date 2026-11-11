import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/notification_log.dart';
import '../models/studio_profile.dart';
import '../services/database_service.dart';
import '../services/kakao_share_service.dart';
import '../services/localization_service.dart';
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
    final subject = '[${widget.studio.studioName}] ${widget.type == AttendanceNotifyType.checkIn ? LocalizationService.pick(ko: "등원 알림", en: "Check-in Alert", ja: "入室通知", zh: "签到通知", vi: "Thông báo điểm danh", es: "Aviso de entrada") : LocalizationService.pick(ko: "하원 알림", en: "Check-out Alert", ja: "退室通知", zh: "签退通知", vi: "Thông báo ra về", es: "Aviso de salida")}';

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
          content: Text(
            LocalizationService.pick(
              ko: '${widget.member.name} 보호자 카카오톡 안심 알림 전송 완료',
              en: 'Messenger check-in notice sent for ${widget.member.name}',
              ja: '${widget.member.name} 様のメッセージ通知を送信しました',
              zh: '已发送 ${widget.member.name} 的微信/社交软件通知',
              vi: 'Đã chia sẻ thông báo cho ${widget.member.name}',
              es: 'Aviso enviado para ${widget.member.name}',
            ),
          ),
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
          content: Text(
            LocalizationService.pick(
              ko: '${widget.member.name} 보호자 문자(SMS) 안심 알림 전송 완료',
              en: 'SMS notice sent for ${widget.member.name}',
              ja: '${widget.member.name} 様のSMS通知を送信しました',
              zh: '已发送 ${widget.member.name} 的短信通知',
              vi: 'Đã gửi SMS thông báo cho ${widget.member.name}',
              es: 'SMS enviado para ${widget.member.name}',
            ),
          ),
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
    final timeStr = LocalizationService.isDomestic
        ? DateFormat('a h시 mm분', 'ko_KR').format(widget.time)
        : DateFormat.jm(LocalizationService.currentLanguage.code).format(widget.time);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Container(
        padding: const EdgeInsets.all(22),
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
                                color: Colors.black.withAlpha((255 * 0.04).round()),
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
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFFE0F2FE), Color(0xFFBAE6FD)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            border: Border.all(color: const Color(0xFF38BDF8), width: 1.5),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/icons/mascot_profile.png',
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Icon(
                                isCheckIn ? Icons.login_rounded : Icons.logout_rounded,
                                color: isCheckIn ? const Color(0xFF10B981) : AppTheme.primaryBlue,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCheckIn
                              ? LocalizationService.pick(
                                  ko: '안심 등원 알림장 발송',
                                  en: 'Send Check-in Notice',
                                  ja: '入室安心通知を送信',
                                  zh: '发送到校签到通知',
                                  vi: 'Gửi thông báo đã đến',
                                  es: 'Enviar aviso de llegada',
                                )
                              : LocalizationService.pick(
                                  ko: '안심 하원 알림장 발송',
                                  en: 'Send Check-out Notice',
                                  ja: '退室安心通知を送信',
                                  zh: '发送离校签退通知',
                                  vi: 'Gửi thông báo ra về',
                                  es: 'Enviar aviso de salida',
                                ),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.member.name} (${widget.member.phone}) • $timeStr',
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Message Edit Area
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.9),
                ),
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService.pick(
                        ko: '보호자 전송 문구 (발송 전 수정 가능)',
                        en: 'Message Preview (Editable)',
                        ja: '送信メッセージ内容（編集可能）',
                        zh: '通知内容预览（发送前可修改）',
                        vi: 'Nội dung tin nhắn (Có thể sửa)',
                        es: 'Mensaje a enviar (Editable)',
                      ),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _messageController,
                      maxLines: 4,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        height: 1.45,
                        color: AppTheme.textPrimary,
                      ),
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

              // Action Buttons (1 Column Full-Width in Senior Mode)
              Builder(
                builder: (context) {
                  final isSenior = Theme.of(context).primaryColor == AppTheme.seniorPrimaryBlue;
                  final kakaoBtn = ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendViaKakao,
                    icon: const Icon(Icons.chat_bubble_rounded, size: 16, color: Color(0xFF191919)),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        LocalizationService.isDomestic ? '카톡 0원 전송' : LocalizationService.shareMessengerLabel,
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: isSenior ? 15.5 : 13.5,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF191919),
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE500),
                      minimumSize: isSenior ? const Size(double.infinity, 50) : Size.zero,
                      padding: EdgeInsets.symmetric(vertical: isSenior ? 14 : 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  );

                  final smsBtn = ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendViaSms,
                    icon: const Icon(Icons.sms_outlined, size: 16, color: Colors.white),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        LocalizationService.pick(
                          ko: '문자(SMS) 전송',
                          en: 'Send SMS',
                          ja: 'SMS送信',
                          zh: '发送短信',
                          vi: 'Gửi SMS',
                          es: 'Enviar SMS',
                        ),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: isSenior ? 15.5 : 13.5,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      minimumSize: isSenior ? const Size(double.infinity, 50) : Size.zero,
                      padding: EdgeInsets.symmetric(vertical: isSenior ? 14 : 13),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  );

                  if (isSenior) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        kakaoBtn,
                        const SizedBox(height: 10),
                        smsBtn,
                      ],
                    );
                  }

                  return Row(
                    children: [
                      Expanded(child: kakaoBtn),
                      const SizedBox(width: 8),
                      Expanded(child: smsBtn),
                    ],
                  );
                },
              ),
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    LocalizationService.pick(
                      ko: '나중에 전송 / 닫기',
                      en: 'Send Later / Close',
                      ja: 'あとで送信 / 閉じる',
                      zh: '稍后发送 / 关闭',
                      vi: 'Để sau / Đóng',
                      es: 'Enviar después / Cerrar',
                    ),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
