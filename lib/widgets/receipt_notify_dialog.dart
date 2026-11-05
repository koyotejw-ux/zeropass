import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/notification_log.dart';
import '../models/studio_profile.dart';
import '../services/database_service.dart';
import '../services/kakao_share_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';

class ReceiptNotifyDialog extends StatefulWidget {
  final Member member;
  final Invoice invoice;
  final StudioProfile studio;
  final Future<bool> Function(String text, String? subject)? onShareKakao;
  final Future<bool> Function(String phone, String body)? onSendSms;

  const ReceiptNotifyDialog({
    super.key,
    required this.member,
    required this.invoice,
    required this.studio,
    this.onShareKakao,
    this.onSendSms,
  });

  static Future<void> show({
    required BuildContext context,
    required Member member,
    required Invoice invoice,
    required StudioProfile studio,
    Future<bool> Function(String text, String? subject)? onShareKakao,
    Future<bool> Function(String phone, String body)? onSendSms,
  }) {
    return showDialog(
      context: context,
      builder: (ctx) => ReceiptNotifyDialog(
        member: member,
        invoice: invoice,
        studio: studio,
        onShareKakao: onShareKakao,
        onSendSms: onSendSms,
      ),
    );
  }

  @override
  State<ReceiptNotifyDialog> createState() => _ReceiptNotifyDialogState();
}

class _ReceiptNotifyDialogState extends State<ReceiptNotifyDialog> {
  late TextEditingController _messageController;
  bool _isSending = false;
  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    final defaultMsg = KakaoShareService.generateReceiptKakaoMessage(
      studio: widget.studio,
      member: widget.member,
      invoice: widget.invoice,
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
    final subject = '[${widget.studio.studioName}] 수납 영수증';

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
          content: Text('${widget.member.name} 보호자 카카오톡 영수증 전송 완료'),
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
      success = await widget.onSendSms!(widget.invoice.recipientPhone, msg);
    } else {
      success = await SmsTemplateService.launchNativeSms(
        recipientPhone: widget.invoice.recipientPhone,
        body: msg,
      );
    }

    await _logNotification(channel: 'SMS', message: msg, isSuccess: success);

    if (mounted) {
      setState(() => _isSending = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.member.name} 보호자 문자(SMS) 영수증 전송 완료'),
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
      await DatabaseService.instance.insertNotificationLog(
        NotificationLog(
          id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${widget.member.id}',
          type: NotificationType.receipt,
          memberId: widget.member.id,
          memberName: widget.member.name,
          recipientPhone: widget.invoice.recipientPhone,
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
    final amountStr = _currencyFormat.format(widget.invoice.amount);

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
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.receipt_long_rounded,
                      color: Color(0xFF10B981),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '수납 완료 영수증 알림장',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.member.name} • ${widget.invoice.title} ($amountStr원)',
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
                      '영수증 안내 문구 (발송 전 수정 가능)',
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _messageController,
                      maxLines: 5,
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
                          '카톡 영수증 0원 전송',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF191919)),
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
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white),
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
                  child: const Text('건너뛰기 / 닫기', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
