import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';

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
    switch (type) {
      case DispatchTemplateType.billing:
        return '수강료 수납/미납 안내';
      case DispatchTemplateType.notice:
        return '학원/센터 공지사항';
      case DispatchTemplateType.sessionExpiry:
        return '회차 만료 재등록 안내';
      case DispatchTemplateType.custom:
        return '원장님 직접 작성 공지';
    }
  }

  static String getDefaultTemplate(DispatchTemplateType type) {
    switch (type) {
      case DispatchTemplateType.billing:
        return '''
[📢 #{상호명} 수강료 납부 안내]

안녕하세요, #{상호명}입니다.
#{회원명} 회원님의 수강료 안내장을 전송해 드립니다.

────────────────
• 수납 대상 : #{회원명} (#{그룹명})
• 납부 금액 : #{금액}
• 납부 기한 : #{납부기한}
• 입금 계좌 : #{계좌정보}
────────────────

⚡ [토스 1초 간편 송금]
#{토스송금링크}
(위 링크를 누르시면 금액과 계좌가 토스에 자동 채워집니다)

감사합니다. 알찬 수업으로 보답하겠습니다!
'''.trim();

      case DispatchTemplateType.notice:
        return '''
[📢 #{상호명} 안내사항]

안녕하세요, #{상호명}입니다.
#{회원명} 회원님 및 학부모님께 공지사항을 안내해 드립니다.

────────────────
[공지 내용]
• 수업 일정 및 주요 전달사항을 확인해 주세요.
• 문의사항이 있으시면 편하게 회신 주시기 바랍니다.
────────────────

늘 최선을 다해 지도하겠습니다. 감사합니다!
'''.trim();

      case DispatchTemplateType.sessionExpiry:
        return '''
[🔔 #{상호명} 잔여 회차 만료 안내]

안녕하세요, #{상호명}입니다.
#{회원명} 회원님의 잔여 수업 회차가 [#{잔여회차}] 남았습니다.

원활한 수업 예약 및 연속적인 지도를 위해 재등록 안내를 드립니다.
• 재등록 수강료 : #{금액}
• 입금 계좌 : #{계좌정보}

문의사항은 언제든 편하게 말씀해주세요. 감사합니다!
'''.trim();

      case DispatchTemplateType.custom:
        return '''
[#{상호명}] 안녕하세요, #{회원명} 회원님.
'''.trim();
    }
  }

  /// 템플릿 변수를 특정 회원 및 청구서 정보로 치환합니다.
  static String renderMessage({
    required String template,
    required StudioProfile studio,
    required Member member,
    Invoice? invoice,
  }) {
    final memberName = member.name.split(' ').first;
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final copyAccount = '${studio.bankName} ${studio.accountNumber} ${studio.accountHolder}';

    final amountNum = invoice?.amount ?? member.defaultFee;
    final formattedAmount = '${_currencyFormat.format(amountNum)}원';

    final dueDateStr = invoice != null
        ? DateFormat('yyyy년 M월 d일').format(invoice.dueDate)
        : '정기 결제일';

    final cleanAccountOnly = studio.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final tossLink = 'supertoss://send?bank=${Uri.encodeComponent(studio.bankName)}&account=$cleanAccountOnly&amount=$amountNum';

    final sessionText = member.billingType == BillingType.sessionBased
        ? '${member.remainingSessions}회'
        : '정기 패스';

    return template
        .replaceAll('#{상호명}', studio.studioName)
        .replaceAll('{상호명}', studio.studioName)
        .replaceAll('#{원명}', studio.studioName)
        .replaceAll('{원명}', studio.studioName)
        .replaceAll('#{회원명}', memberName)
        .replaceAll('{회원명}', memberName)
        .replaceAll('#{학생명}', memberName)
        .replaceAll('{학생명}', memberName)
        .replaceAll('#{그룹명}', member.groupName)
        .replaceAll('{그룹명}', member.groupName)
        .replaceAll('#{금액}', formattedAmount)
        .replaceAll('{금액}', formattedAmount)
        .replaceAll('#{납부기한}', dueDateStr)
        .replaceAll('{납부기한}', dueDateStr)
        .replaceAll('#{계좌정보}', accountInfo)
        .replaceAll('{계좌정보}', accountInfo)
        .replaceAll('#{계좌복사용}', copyAccount)
        .replaceAll('{계좌복사용}', copyAccount)
        .replaceAll('#{토스송금링크}', tossLink)
        .replaceAll('{토스송금링크}', tossLink)
        .replaceAll('#{잔여회차}', sessionText)
        .replaceAll('{잔여회차}', sessionText)
        .trim();
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

