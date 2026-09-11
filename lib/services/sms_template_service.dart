import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';

enum SmsTemplateType {
  attendanceNotice, // 출석/등원 알림
  departureNotice,  // 하원/퇴실 알림
  invoiceNotice,    // 수납/청구 안내
  receiptNotice,    // 수납 완료 영수 안내
  expiryNotice,     // 회차 만료 임박 안내
}

class SmsTemplateService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###');

  /// 1. 청구서 수납 안내 문자
  static String generateInvoiceMessage({
    required StudioProfile studio,
    required List<Member> members,
    required Invoice invoice,
  }) {
    final memberNames = members.map((m) => m.name.split(' ').first).join(', ');
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final formattedAmount = _currencyFormat.format(invoice.amount);
    final dueDateStr = DateFormat('yyyy.MM.dd').format(invoice.dueDate);

    return '''
[${studio.studioName}] 수강료 청구 안내
안녕하세요, ${studio.studioName}입니다.
$memberNames 회원님의 ${invoice.title}이 발행되었습니다.

• 수납 금액: $formattedAmount원
• 입금 계좌: $accountInfo
• 납부 기한: $dueDateStr까지

기한 내 입금 부탁드리며, 확인 즉시 패스가 안전하게 자동 갱신됩니다. 감사합니다.
'''.trim();
  }

  /// 2. 출석 / 등원 확인 알림 (출결선생 스타일 학부모/회원 안심 문자)
  static String generateAttendanceMessage({
    required StudioProfile studio,
    required Member member,
    required DateTime time,
    String? customNote,
  }) {
    final timeStr = DateFormat('HH:mm').format(time);
    final isSession = member.billingType == BillingType.sessionBased;
    final sessionText = isSession ? '\n• 잔여 회차: ${member.remainingSessions}회' : '';
    final noteText = (customNote != null && customNote.isNotEmpty) ? '\n• 전달 사항: $customNote' : '';

    return '''
[${studio.studioName}] 출석 확인
안녕하세요.
${member.name.split(' ').first} 회원님이 오늘 $timeStr에 정상 출석(등원)하였습니다.$sessionText$noteText

오늘도 즐겁고 유익한 수업이 되도록 정성을 다하겠습니다.
'''.trim();
  }

  /// 3. 하원 / 수업 종료 알림
  static String generateDepartureMessage({
    required StudioProfile studio,
    required Member member,
    required DateTime time,
  }) {
    final timeStr = DateFormat('HH:mm').format(time);

    return '''
[${studio.studioName}] 하원 안내
안녕하세요.
${member.name.split(' ').first} 회원님이 오늘 $timeStr에 수업을 마치고 안전하게 귀가(하원)하였습니다.

가정에서 따뜻한 격려 부탁드립니다. 감사합니다.
'''.trim();
  }

  /// 4. 수납 완료 / 영수 확인 알림
  static String generatePaymentReceiptMessage({
    required StudioProfile studio,
    required Member member,
    required int amount,
    required String paymentMethod,
    int? remainingSessions,
  }) {
    final methodStr = paymentMethod == 'TRANSFER'
        ? '계좌이체'
        : (paymentMethod == 'OFFLINE_CARD' ? '카드결제' : '현금결제');
    final formattedAmount = _currencyFormat.format(amount);
    final sessionStr = remainingSessions != null ? '\n• 갱신 잔여 회차: $remainingSessions회' : '';

    return '''
[${studio.studioName}] 수납 확인 완료
안녕하세요, ${studio.studioName}입니다.
${member.name.split(' ').first} 회원님의 수강료가 정상 확인되었습니다.

• 수납 금액: $formattedAmount원
• 결제 수단: $methodStr$sessionStr

항상 신뢰해 주셔서 감사드리며 더욱 알찬 수업으로 보답하겠습니다!
'''.trim();
  }

  /// 5. 회차 만료 임박(1회 이하) 재등록 안내 알림
  static String generateExpiryWarningMessage({
    required StudioProfile studio,
    required Member member,
  }) {
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final fee = _currencyFormat.format(member.defaultFee);

    return '''
[${studio.studioName}] 패스 만료 임박 안내
안녕하세요, ${studio.studioName}입니다.
${member.name.split(' ').first} 회원님의 잔여 패스가 [${member.remainingSessions}회] 남았습니다.

원활한 수업 예약 및 연속적인 지도를 위해 재등록 안내를 드립니다.
• 재등록 수강료: $fee원
• 입금 계좌: $accountInfo

문의사항이 있으시면 언제든 편하게 연락 부탁드립니다. 감사합니다!
'''.trim();
  }

  /// Launches the native SMS app with recipient and prefilled body.
  /// Zero server cost, direct telecom native messaging.
  static Future<bool> launchNativeSms({
    required String recipientPhone,
    required String body,
  }) async {
    final cleanPhone = recipientPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: cleanPhone,
      queryParameters: <String, String>{
        'body': body,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri);
      } else {
        final fallbackUri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(body)}');
        return await launchUrl(fallbackUri);
      }
    } catch (_) {
      return false;
    }
  }
}
