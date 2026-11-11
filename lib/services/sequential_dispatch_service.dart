import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import 'localization_service.dart';
import 'region_workflow_service.dart';

enum DispatchTemplateType {
  billing,
  notice,
  sessionExpiry,
  custom,
}

class SequentialDispatchItem {
  final Member member;
  final Invoice? invoice;
  final String recipientPhone;
  String message;
  bool isSent;
  String? sentChannel; // 'KAKAO', 'SMS', 'SKIPPED'

  SequentialDispatchItem({
    required this.member,
    this.invoice,
    required this.recipientPhone,
    required this.message,
    this.isSent = false,
    this.sentChannel,
  });

  SequentialDispatchItem copyWith({
    Member? member,
    Invoice? invoice,
    String? recipientPhone,
    String? message,
    bool? isSent,
    String? sentChannel,
  }) {
    return SequentialDispatchItem(
      member: member ?? this.member,
      invoice: invoice ?? this.invoice,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      message: message ?? this.message,
      isSent: isSent ?? this.isSent,
      sentChannel: sentChannel ?? this.sentChannel,
    );
  }
}

class SequentialDispatchService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###');

  static String getTemplateName(DispatchTemplateType type) {
    final lang = LocalizationService.currentLanguage;
    switch (type) {
      case DispatchTemplateType.billing:
        return const {
              'ko': '수강료 수납/미납 안내',
              'en': 'Tuition / Overdue Notice',
              'ja': '月謝・未納のご案内',
              'zh': '学费/催缴通知',
              'vi': 'Thông báo học phí',
              'es': 'Aviso de pago / cuota',
            }[lang.code] ??
            'Tuition Notice';
      case DispatchTemplateType.notice:
        return const {
              'ko': '매장 공지사항',
              'en': 'Studio Announcement',
              'ja': 'スタジオお知らせ',
              'zh': '门店通知公告',
              'vi': 'Thông báo chung',
              'es': 'Aviso general',
            }[lang.code] ??
            'Announcement';
      case DispatchTemplateType.sessionExpiry:
        return const {
              'ko': '회차 만료 재등록 안내',
              'en': 'Session Renewal Notice',
              'ja': '回数券更新のご案内',
              'zh': '课时续费提醒',
              'vi': 'Nhắc gia hạn buổi',
              'es': 'Aviso de renovación',
            }[lang.code] ??
            'Renewal Notice';
      case DispatchTemplateType.custom:
        return const {
              'ko': '직접 작성 공지',
              'en': 'Custom Message',
              'ja': '自由入力メッセージ',
              'zh': '自定义消息',
              'vi': 'Tin nhắn tùy chỉnh',
              'es': 'Mensaje personalizado',
            }[lang.code] ??
            'Custom Message';
    }
  }

  static String getDefaultTemplate(DispatchTemplateType type) {
    final lang = LocalizationService.currentLanguage;
    final currency = LocalizationService.currentCurrency;
    final supportsToss = RegionWorkflowService.supportsTossTransfer(currency);

    if (lang == AppLanguage.korean) {
      switch (type) {
        case DispatchTemplateType.billing:
          final transferBlock = supportsToss
              ? '''⚡ [토스 1초 간편 송금]
#{토스송금링크}
(위 링크를 누르시면 금액과 계좌가 토스에 자동 채워집니다)'''
              : '''🌍 [결제 수단 안내]
• 지원 채널 : ${currency.paymentChannels}''';
          return '''
[📢 #{상호명} #{비용호칭} 납부 안내]

안녕하세요, #{상호명}입니다.
#{회원명} #{고객호칭}님의 #{비용호칭} 안내장을 전송해 드립니다.

────────────────
• 수납 대상 : #{회원명} (#{그룹명})
• 납부 금액 : #{금액}
• 납부 기한 : #{납부기한}
• 입금 계좌 : #{계좌정보}
────────────────

$transferBlock

감사합니다. 알찬 서비스로 보답하겠습니다!
'''.trim();

        case DispatchTemplateType.notice:
          return '''
[📢 #{상호명} 안내사항]

안녕하세요, #{상호명}입니다.
#{회원명} #{고객호칭}님께 주요 안내사항을 전달해 드립니다.

────────────────
[공지 내용]
• 일정 및 주요 전달사항을 확인해 주세요.
• 문의사항이 있으시면 편하게 회신 주시기 바랍니다.
────────────────

늘 최선을 다해 함께하겠습니다. 감사합니다!
'''.trim();

        case DispatchTemplateType.sessionExpiry:
          return '''
[🔔 #{상호명} 잔여 회차 만료 안내]

안녕하세요, #{상호명}입니다.
#{회원명} #{고객호칭}님의 잔여 회차가 [#{잔여회차}] 남았습니다.

원활한 예약 및 연속적인 이용을 위해 재등록 안내를 드립니다.
• 재등록 #{비용호칭} : #{금액}
• 입금 계좌 : #{계좌정보}

문의사항은 언제든 편하게 말씀해주세요. 감사합니다!
'''.trim();

        case DispatchTemplateType.custom:
          return '''
[#{상호명}] 안녕하세요, #{회원명} #{고객호칭}님.
'''.trim();
      }
    }

    switch (type) {
      case DispatchTemplateType.billing:
        return {
          'en': '''[📢 #{상호명} #{비용호칭} Notice]
Hello #{회원명}, here are your payment details:
• Group: #{그룹명}
• Amount Due: #{금액}
• Due Date: #{납부기한}
• Pay To: #{계좌정보}
Thank you!''',
          'ja': '''[📢 #{상호명} #{비용호칭}のご案内]
#{회원명} 様、いつもありがとうございます。
• クラス: #{그룹명}
• ご請求額: #{금액}
• お支払期限: #{납부기한}
• お振込先: #{계좌정보}
よろしくお願いいたします。''',
          'zh': '''[📢 #{상호명} #{비용호칭}账单通知]
您好 #{회원명}，请查收本期账单：
• 班级/分组: #{그룹명}
• 应付金额: #{금액}
• 截止日期: #{납부기한}
• 收款账户: #{계좌정보}
感谢配合！''',
          'vi': '''[📢 #{상호명} Thông báo #{비용호칭}]
Xin chào #{회원명}, chi tiết thanh toán:
• Nhóm: #{그룹명}
• Số tiền: #{금액}
• Hạn thanh toán: #{납부기한}
• Tài khoản: #{계좌정보}
Xin cảm ơn!''',
          'es': '''[📢 #{상호명} Aviso de #{비용호칭}]
Hola #{회원명}, aquí tienes tu recibo pendiente:
• Grupo: #{그룹명}
• Importe: #{금액}
• Vencimiento: #{납부기한}
• Cuenta: #{계좌정보}
¡Gracias!''',
        }[lang.code]!;
      case DispatchTemplateType.notice:
        return {
          'en': '[📢 #{상호명} Notice]\nHello #{회원명}, please note our latest schedule update. Reply anytime if you have questions!',
          'ja': '[📢 #{상호명} お知らせ]\n#{회원명} 様、スケジュール・運営に関するご案内をお送りいたします。',
          'zh': '[📢 #{상호명} 通知公告]\n您好 #{회원명}，请查看最新课程与营业安排通知，如有疑问欢迎联系。',
          'vi': '[📢 #{상호명} Thông báo]\nXin chào #{회원명}, vui lòng cập nhật thông tin lịch học mới nhất của chúng tôi.',
          'es': '[📢 #{상호명} Aviso]\nHola #{회원명}, te compartimos novedades importantes de horario.',
        }[lang.code]!;
      case DispatchTemplateType.sessionExpiry:
        return {
          'en': '[🔔 #{상호명} Renewal Notice]\nHello #{회원명}, you have [#{잔여회차}] left.\n• Renewal Fee: #{금액}\n• Pay To: #{계좌정보}',
          'ja': '[🔔 #{상호명} 回数券更新]\n#{회원명} 様の残り回数は【#{잔여회차}】です。\n• 更新料: #{금액}\n• お振込先: #{계좌정보}',
          'zh': '[🔔 #{상호명} 续费提醒]\n您好 #{회원명}，您的剩余课时为【#{잔여회차}】。\n• 续费金额: #{금액}\n• 收款账户: #{계좌정보}',
          'vi': '[🔔 #{상호명} Nhắc gia hạn]\nXin chào #{회원명}, bạn còn [#{잔여회차}].\n• Phí gia hạn: #{금액}\n• Tài khoản: #{계좌정보}',
          'es': '[🔔 #{상호명} Renovación]\nHola #{회원명}, te quedan [#{잔여회차}].\n• Cuota: #{금액}\n• Cuenta: #{계좌정보}',
        }[lang.code]!;
      case DispatchTemplateType.custom:
        return '[#{상호명}] ${LocalizationService.trParams('kiosk_success_greeting', {'name': '#{회원명}', 'term': ''})}';
    }
  }

  /// 템플릿 변수를 특정 회원 및 청구서 정보로 치환합니다.
  static String renderMessage({
    required String template,
    required StudioProfile studio,
    required Member member,
    Invoice? invoice,
  }) {
    final lang = LocalizationService.currentLanguage;
    final currency = LocalizationService.currentCurrency;
    final memberName = member.name.split(' ').first;
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final copyAccount = '${studio.bankName} ${studio.accountNumber} ${studio.accountHolder}';

    final amountNum = invoice?.amount ?? member.defaultFee;
    final formattedAmount = (currency == AppCurrency.krw && lang == AppLanguage.korean)
        ? '${_currencyFormat.format(amountNum)}원'
        : LocalizationService.formatAmount(amountNum);

    final dueDateStr = invoice != null
        ? (lang == AppLanguage.korean
            ? DateFormat('yyyy년 M월 d일').format(invoice.dueDate)
            : LocalizationService.formatDate(invoice.dueDate))
        : (const {
              'ko': '정기 결제일',
              'en': 'Regular Billing Cycle',
              'ja': '定期決済日',
              'zh': '定期结算日',
              'vi': 'Kỳ thanh toán định kỳ',
              'es': 'Fecha habitual de cobro',
            }[lang.code] ??
            'Billing Date');

    final cleanAccountOnly = studio.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final tossLink = RegionWorkflowService.supportsTossTransfer(currency)
        ? 'supertoss://send?bank=${Uri.encodeComponent(studio.bankName)}&account=$cleanAccountOnly&amount=$amountNum'
        : '';

    final cardPaymentLink = studio.getFormattedCardPaymentUrl(
      amount: amountNum,
      orderTitle: invoice?.title ?? studio.feeWord,
      customerName: memberName,
    );

    final sessionText = member.billingType == BillingType.sessionBased
        ? LocalizationService.trParams('common_sessions_unit', {'n': '${member.remainingSessions}'})
        : LocalizationService.tr('common_monthly_pass');

    String rendered = template
        .replaceAll('#{상호명}', studio.studioName)
        .replaceAll('{상호명}', studio.studioName)
        .replaceAll('#{원명}', studio.studioName)
        .replaceAll('{원명}', studio.studioName)
        .replaceAll('#{회원명}', memberName)
        .replaceAll('{회원명}', memberName)
        .replaceAll('#{학생명}', memberName)
        .replaceAll('{학생명}', memberName)
        .replaceAll('#{그룹명}', LocalizationService.localizeBuiltInLabel(member.groupName))
        .replaceAll('{그룹명}', LocalizationService.localizeBuiltInLabel(member.groupName))
        .replaceAll('#{금액}', formattedAmount)
        .replaceAll('{금액}', formattedAmount)
        .replaceAll('#{납부기한}', dueDateStr)
        .replaceAll('{납부기한}', dueDateStr)
        .replaceAll('#{계좌정보}', accountInfo)
        .replaceAll('{계좌정보}', accountInfo)
        .replaceAll('#{계좌복사용}', copyAccount)
        .replaceAll('{계좌복사용}', copyAccount)
        .replaceAll('#{결제수단안내}', currency.paymentChannelsSummary)
        .replaceAll('#{토스송금링크}', tossLink)
        .replaceAll('{토스송금링크}', tossLink)
        .replaceAll('#{카드결제링크}', cardPaymentLink)
        .replaceAll('{카드결제링크}', cardPaymentLink)
        .replaceAll('#{잔여회차}', sessionText)
        .replaceAll('{잔여회차}', sessionText)
        .replaceAll('#{담당자}', studio.instructorName)
        .replaceAll('{담당자}', studio.instructorName)
        .replaceAll('#{대표자}', studio.instructorName)
        .replaceAll('{대표자}', studio.instructorName)
        .replaceAll('#{직함}', studio.roleTitle)
        .replaceAll('{직함}', studio.roleTitle)
        .replaceAll('#{고객호칭}', studio.memberWord)
        .replaceAll('{고객호칭}', studio.memberWord)
        .replaceAll('#{비용호칭}', studio.feeWord)
        .replaceAll('{비용호칭}', studio.feeWord)
        .replaceAll('#{장소호칭}', studio.placeTitle)
        .replaceAll('{장소호칭}', studio.placeTitle);

    if (cardPaymentLink.isEmpty) {
      rendered = rendered
          .replaceAll(RegExp(r'•\s*(?:비대면\s*)?카드(?:결제)?\s*:\s*\n?', multiLine: true), '')
          .replaceAll(RegExp(r'•\s*(?:Pay by Card|カード決済リンク|在线刷卡支付|Thanh toán thẻ|Pagar con tarjeta)\s*:\s*\n?', multiLine: true), '')
          .replaceAll(RegExp(r'\[비대면\s*카드\s*결제\]\s*\n?', multiLine: true), '');
    }
    if (tossLink.isEmpty) {
      rendered = rendered
          .replaceAll(RegExp(r'.*토스송금링크.*\n?', multiLine: true), '');
    }

    return rendered.trim();
  }

  /// 회원 목록과 청구 목록을 기반으로 순차 발송 큐 아이템을 생성합니다.
  static List<SequentialDispatchItem> buildDispatchItems({
    required List<Member> members,
    required StudioProfile studio,
    required String template,
    List<Invoice>? invoices,
  }) {
    final invoiceMap = <String, Invoice>{};
    if (invoices != null) {
      for (final inv in invoices) {
        for (final mId in inv.memberIds) {
          invoiceMap[mId] = inv;
        }
      }
    }

    return members.map((m) {
      final inv = invoiceMap[m.id];
      final rendered = renderMessage(
        template: template,
        studio: studio,
        member: m,
        invoice: inv,
      );

      final phone = inv?.recipientPhone.isNotEmpty == true
          ? inv!.recipientPhone
          : m.phone;

      return SequentialDispatchItem(
        member: m,
        invoice: inv,
        recipientPhone: phone,
        message: rendered,
      );
    }).toList();
  }
}

