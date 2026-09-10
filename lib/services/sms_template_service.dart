import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';

class SmsTemplateService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###');

  /// Default format template:
  /// [#{상호명}] #{회원명}님 수강 패스 안내
  /// - 안내내용: #{안내내용}
  /// - 결제금액: #{금액}원
  /// - 입금계좌: #{계좌정보}
  /// 감사합니다.
  static String generateInvoiceMessage({
    required StudioProfile studio,
    required List<Member> members,
    required Invoice invoice,
  }) {
    final memberNames = members.map((m) => m.name).join(', ');
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final formattedAmount = _currencyFormat.format(invoice.amount);

    final template = '''
[#{상호명}] #{회원명} 수납 안내
안녕하세요, #{상호명}입니다.
#{회원명} #{안내내용}이 발행되었습니다.

• 수납 금액: #{금액}원
• 입금 계좌: #{계좌정보}
• 납부 기한: #{납부기한}까지

기한 내 입금 부탁드리며, 확인 즉시 출석 패스가 갱신됩니다. 감사합니다!
''';

    final dueDateStr = DateFormat('yyyy.MM.dd').format(invoice.dueDate);

    return template
        .replaceAll('#{상호명}', studio.studioName)
        .replaceAll('#{회원명}', memberNames)
        .replaceAll('#{안내내용}', invoice.title)
        .replaceAll('#{금액}', formattedAmount)
        .replaceAll('#{계좌정보}', accountInfo)
        .replaceAll('#{납부기한}', dueDateStr)
        .trim();
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
        // Fallback for some Android versions requiring raw query string
        final fallbackUri = Uri.parse('sms:$cleanPhone?body=${Uri.encodeComponent(body)}');
        return await launchUrl(fallbackUri);
      }
    } catch (e) {
      return false;
    }
  }
}
