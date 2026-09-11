import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';

class SmsTemplateService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###');

  /// 1. 청구서 수납 안내 문자 (사용자 정의 템플릿 치환)
  static String generateInvoiceMessage({
    required StudioProfile studio,
    required List<Member> members,
    required Invoice invoice,
    String? customBody,
  }) {
    if (customBody != null && customBody.trim().isNotEmpty) {
      return customBody.trim();
    }

    final memberNames = members.map((m) => m.name.split(' ').first).join(', ');
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final formattedAmount = _currencyFormat.format(invoice.amount);
    final dueDateStr = DateFormat('yyyy.MM.dd').format(invoice.dueDate);

    return studio.invoiceTemplate
        .replaceAll('#{상호명}', studio.studioName)
        .replaceAll('#{회원명}', memberNames)
        .replaceAll('#{청구제목}', invoice.title)
        .replaceAll('#{안내내용}', invoice.title)
        .replaceAll('#{금액}', formattedAmount)
        .replaceAll('#{계좌정보}', accountInfo)
        .replaceAll('#{납부기한}', dueDateStr)
        .trim();
  }

  /// 2. 출석 / 등원 확인 알림
  static String generateAttendanceMessage({
    required StudioProfile studio,
    required Member member,
    required DateTime time,
  }) {
    final timeStr = DateFormat('HH:mm').format(time);
    final isSession = member.billingType == BillingType.sessionBased;
    final sessionText = isSession ? '• 잔여 회차: ${member.remainingSessions}회' : '• 이용권: 정기 패스';

    return studio.attendanceTemplate
        .replaceAll('#{상호명}', studio.studioName)
        .replaceAll('#{회원명}', member.name.split(' ').first)
        .replaceAll('#{출석시간}', timeStr)
        .replaceAll('#{잔여회차}', sessionText)
        .trim();
  }

  /// 3. 하원 / 수업 종료 알림
  static String generateDepartureMessage({
    required StudioProfile studio,
    required Member member,
    required DateTime time,
  }) {
    return studio.departureTemplate
        .replaceAll('#{상호명}', studio.studioName)
        .replaceAll('#{회원명}', member.name.split(' ').first)
        .trim();
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
