import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/notification_log.dart';
import '../models/studio_profile.dart';
import '../services/database_service.dart';
import '../services/kakao_share_service.dart';
import '../services/localization_service.dart';
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
    final subject = '[${widget.studio.studioName}] ${LocalizationService.pick(ko: '수납 영수증', en: 'Payment Receipt', ja: '領収書', zh: '收款凭据', vi: 'Biên lai thanh toán', es: 'Recibo de pago')}';

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
              ko: '${widget.member.name} 보호자 카카오톡 영수증 전송 완료',
              en: 'Receipt shared for ${widget.member.name}',
              ja: '${widget.member.name} 様の領収書を共有しました',
              zh: '已发送 ${widget.member.name} 的收款凭据',
              vi: 'Đã chia sẻ biên lai cho ${widget.member.name}',
              es: 'Recibo compartido para ${widget.member.name}',
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
          content: Text(
            LocalizationService.pick(
              ko: '${widget.member.name} 보호자 문자(SMS) 영수증 전송 완료',
              en: 'SMS receipt sent for ${widget.member.name}',
              ja: '${widget.member.name} 様のSMS領収書を送信しました',
              zh: '已发送 ${widget.member.name} 的短信凭据',
              vi: 'Đã gửi SMS biên lai cho ${widget.member.name}',
              es: 'Recibo SMS enviado para ${widget.member.name}',
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
    final amountStr = (LocalizationService.currentCurrency == AppCurrency.krw && LocalizationService.isDomestic)
        ? '${_currencyFormat.format(widget.invoice.amount)}원'
        : LocalizationService.formatAmount(widget.invoice.amount);

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
                        Text(
                          LocalizationService.pick(
                            ko: '수납 완료 영수증 알림장',
                            en: 'Payment Receipt Notice',
                            ja: '領収書・ご入金確認',
                            zh: '收款确认电子凭证',
                            vi: 'Gửi biên lai xác nhận',
                            es: 'Enviar recibo de pago',
                          ),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${widget.member.name} • ${widget.invoice.title} ($amountStr)',
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
                    Text(
                      LocalizationService.pick(
                        ko: '영수증 안내 문구 (발송 전 수정 가능)',
                        en: 'Receipt Message (Editable)',
                        ja: '領収書メッセージ（編集可能）',
                        zh: '凭据内容预览（可修改）',
                        vi: 'Nội dung biên lai (Có thể sửa)',
                        es: 'Texto del recibo (Editable)',
                      ),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
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
              const SizedBox(height: 14),

              // 국가별 세무/현금영수증 지원 바
              if (LocalizationService.supportsTossTransfer)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.receipt_long_outlined, size: 15, color: Color(0xFF475569)),
                              const SizedBox(width: 5),
                              Text(
                                LocalizationService.pick(
                                  ko: '현금영수증 발급 지원',
                                  en: 'Cash Receipt Support',
                                  ja: '領収書発行サポート',
                                  zh: '发票 / 收据开具支持',
                                  vi: 'Hỗ trợ xuất biên lai',
                                  es: 'Soporte de Recibo Fiscal',
                                ),
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                              ),
                            ],
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              InkWell(
                                onTap: () {
                                  Clipboard.setData(ClipboardData(text: widget.member.phone.replaceAll('-', '')));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(LocalizationService.pick(
                                        ko: '현금영수증 발급용 휴대폰 번호(${widget.member.phone})가 복사되었습니다.',
                                        en: 'Copied member phone number (${widget.member.phone}) for receipt issuance.',
                                        ja: '領収書用電話番号（${widget.member.phone}）をコピーしました。',
                                        zh: '已复制开票手机号（${widget.member.phone}）。',
                                        vi: 'Đã sao chép SĐT (${widget.member.phone}) để xuất biên lai.',
                                        es: 'Número (${widget.member.phone}) copiado para el recibo.',
                                      )),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFCBD5E1)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.copy_rounded, size: 12, color: AppTheme.primaryBlue),
                                      const SizedBox(width: 3),
                                      Text(
                                        LocalizationService.pick(
                                          ko: '번호 복사',
                                          en: 'Copy No.',
                                          ja: '番号コピー',
                                          zh: '复制号码',
                                          vi: 'Sao chép',
                                          es: 'Copiar',
                                        ),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              InkWell(
                                onTap: () async {
                                  final uri = Uri.parse('https://www.hometax.go.kr');
                                  if (await canLaunchUrl(uri)) {
                                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF10B981).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.open_in_new_rounded, size: 12, color: Color(0xFF059669)),
                                      const SizedBox(width: 3),
                                      Text(
                                        LocalizationService.pick(
                                          ko: '홈택스 열기',
                                          en: 'Open Tax Portal',
                                          ja: '税務ポータル',
                                          zh: '税务门户',
                                          vi: 'Cổng thuế',
                                          es: 'Portal Fiscal',
                                        ),
                                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text(
                        LocalizationService.pick(
                          ko: '💡 홈택스 접속 후 [전자세금계산서·현금영수증 > 현금영수증 발급]에서 1분 만에 발행 가능합니다.',
                          en: '💡 Log in to your national tax portal to issue digital receipts easily.',
                          ja: '💡 国税ポータルより電子領収書を簡単に発行できます。',
                          zh: '💡 可登录国税电子税务局快速开具数电发票或收款收据。',
                          vi: '💡 Đăng nhập cổng thuế điện tử để xuất hóa đơn/biên lai nhanh chóng.',
                          es: '💡 Emite facturas electrónicas o recibos desde el portal fiscal oficial.',
                        ),
                        style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), height: 1.3),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.verified_outlined, size: 15, color: Color(0xFF475569)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${LocalizationService.tr('tax_policy_badge')}: ${LocalizationService.currentCurrency.taxPolicy}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 14),

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
                        LocalizationService.isDomestic ? '카톡 영수증 0원 전송' : LocalizationService.shareMessengerLabel,
                        style: TextStyle(
                          fontSize: isSenior ? 15 : 13,
                          fontWeight: FontWeight.w800,
                          color: const Color(0xFF191919),
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE500),
                      minimumSize: isSenior ? const Size(double.infinity, 50) : Size.zero,
                      padding: EdgeInsets.symmetric(vertical: isSenior ? 14 : 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );

                  final smsBtn = ElevatedButton.icon(
                    onPressed: _isSending ? null : _sendViaSms,
                    icon: const Icon(Icons.sms_outlined, size: 16, color: Colors.white),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        LocalizationService.tr('common_send_sms'),
                        style: TextStyle(
                          fontSize: isSenior ? 15 : 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      minimumSize: isSenior ? const Size(double.infinity, 50) : Size.zero,
                      padding: EdgeInsets.symmetric(vertical: isSenior ? 14 : 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
                    LocalizationService.tr('common_close'),
                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
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
