import 'package:flutter/services.dart';
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
    
    // Clean account for 1-touch copy format (e.g. "토스뱅크 1000-2026-8899 김서연")
    final copyAccountText = '${studio.bankName} ${studio.accountNumber} ${studio.accountHolder}';
    
    // Free 0-cost Toss Deep Link: Opens Toss app directly to remittance screen
    final cleanAccountOnly = studio.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final tossLink = 'supertoss://send?bank=${Uri.encodeComponent(studio.bankName)}&account=$cleanAccountOnly&amount=${invoice.amount}';

    // 0-cost Remote Card Payment Link (Toss Payments / PayApp / etc.)
    final cardLink = studio.getFormattedCardPaymentUrl(
      amount: invoice.amount,
      orderTitle: invoice.title,
      customerName: memberNames,
    );

    String rendered = studio.invoiceTemplate
        .replaceAll('#{상호명}', studio.studioName)
        .replaceAll('#{회원명}', memberNames)
        .replaceAll('#{청구제목}', invoice.title)
        .replaceAll('#{안내내용}', invoice.title)
        .replaceAll('#{금액}', formattedAmount)
        .replaceAll('#{계좌정보}', accountInfo)
        .replaceAll('#{계좌복사용}', copyAccountText)
        .replaceAll('#{토스송금링크}', tossLink)
        .replaceAll('#{카드결제링크}', cardLink)
        .replaceAll('{카드결제링크}', cardLink)
        .replaceAll('#{납부기한}', dueDateStr);

    if (cardLink.isEmpty) {
      // If card payment is not enabled or empty, remove dangling card payment labels
      rendered = rendered
          .replaceAll(RegExp(r'•\s*(?:비대면\s*)?카드(?:결제)?\s*:\s*\n?', multiLine: true), '')
          .replaceAll(RegExp(r'\[비대면\s*카드\s*결제\]\s*\n?', multiLine: true), '');
    }

    return rendered.trim();
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
    String methodStr = '현금결제';
    if (paymentMethod == 'TRANSFER') {
      methodStr = '계좌이체';
    } else if (paymentMethod == 'OFFLINE_CARD') {
      methodStr = '신용카드(현장)';
    } else if (paymentMethod == 'ONLINE_CARD') {
      methodStr = '비대면 신용카드(원격)';
    } else if (paymentMethod == 'EASY_PAY') {
      methodStr = '간편결제(카카오/토스/제로페이)';
    } else if (paymentMethod == 'VOUCHER') {
      methodStr = '바우처/지역화폐';
    }
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

  /// 6. 미납 수강료 1초 리마인드 알림 (친근하고 정중한 사장님 맞춤 양식)
  static String generateUnpaidReminderMessage({
    required StudioProfile studio,
    required List<Member> members,
    required Invoice invoice,
  }) {
    final memberNames = members.map((m) => m.name.split(' ').first).join(', ');
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final copyAccountText = '${studio.bankName} ${studio.accountNumber} ${studio.accountHolder}';
    final formattedAmount = _currencyFormat.format(invoice.amount);
    final dueDateStr = DateFormat('yyyy.MM.dd').format(invoice.dueDate);

    final cardLink = studio.getFormattedCardPaymentUrl(
      amount: invoice.amount,
      orderTitle: invoice.title,
      customerName: memberNames,
    );
    final cardSection = cardLink.isNotEmpty ? '\n• 비대면 카드결제 : $cardLink' : '';

    return '''[${studio.studioName}] 입금 안내 리마인드
  
안녕하세요, ${studio.studioName}입니다.
$memberNames 회원님의 [${invoice.title}] 납부 기한($dueDateStr)이 도래하여 정중히 안내드립니다.

────────────────
[입금 안내]
• 입금 금액 : $formattedAmount원
• 납부 기한 : $dueDateStr까지
• 입금 계좌 : $accountInfo
────────────────

[간편 입금 안내]
• 복사용 계좌 : $copyAccountText
(계좌번호를 복사 후 토스나 은행 앱을 여시면 바로 송금됩니다)$cardSection

기한 내 확인 부탁드리며, 이미 입금하신 경우 본 안내는 너그러이 양해 부탁드립니다.
감사합니다.'''.trim();
  }

  static const MethodChannel _channel = MethodChannel('com.zeropass.app/sms_launcher');

  /// Launches the native SMS app with recipient and prefilled body.
  /// Uses native Android MethodChannel (Intent.ACTION_SENDTO + extras) to completely bypass
  /// URI length restrictions and URL truncation, allowing full long LMS/MMS messages.
  static Future<bool> launchNativeSms({
    required String recipientPhone,
    required String body,
  }) async {
    final cleanPhone = recipientPhone.replaceAll(RegExp(r'[^0-9]'), '');

    // 1. Try native MethodChannel first (Android: supports 100% full text via Intent Extras, no 80-char/URL limit)
    try {
      final result = await _channel.invokeMethod<bool>('launchNativeSms', {
        'phone': cleanPhone,
        'body': body,
      });
      if (result == true) return true;
    } catch (_) {
      // Fall through to fallback
    }

    // 2. Fallback via url_launcher (iOS, Web, Windows)
    final encodedBody = Uri.encodeComponent(body).replaceAll('+', '%20');
    final Uri smsUri = Uri.parse('sms:$cleanPhone?body=$encodedBody');

    try {
      if (await canLaunchUrl(smsUri)) {
        return await launchUrl(smsUri);
      } else {
        final Uri fallbackUri = Uri(
          scheme: 'sms',
          path: cleanPhone,
          query: 'body=$encodedBody',
        );
        return await launchUrl(fallbackUri);
      }
    } catch (_) {
      return false;
    }
  }
}
