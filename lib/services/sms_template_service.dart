import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import 'monetization_service.dart';
import 'localization_service.dart';
import 'region_workflow_service.dart';
import 'package:share_plus/share_plus.dart';

class SmsTemplateService {
  static String _formatDisplayAmount(num amount) {
    if (LocalizationService.currentCurrency == AppCurrency.krw &&
        LocalizationService.currentLanguage == AppLanguage.korean) {
      return '${NumberFormat('#,###').format(amount)}원';
    }
    return LocalizationService.formatAmount(amount);
  }

  static String _formatPaymentMethod(String paymentMethod) {
    final lang = LocalizationService.currentLanguage;
    if (lang == AppLanguage.korean) {
      if (paymentMethod == 'TRANSFER') return '계좌이체';
      if (paymentMethod == 'OFFLINE_CARD' || paymentMethod == 'CARD') return '신용카드(현장)';
      if (paymentMethod == 'ONLINE_CARD') return '비대면 신용카드(원격)';
      if (paymentMethod == 'EASY_PAY') return '간편결제(카카오/토스/제로페이)';
      if (paymentMethod == 'VOUCHER') return '바우처/지역화폐';
      return '현금결제';
    }
    switch (paymentMethod) {
      case 'TRANSFER':
        return RegionWorkflowService.paymentMethodLabel('TRANSFER', lang);
      case 'OFFLINE_CARD':
      case 'CARD':
        return RegionWorkflowService.paymentMethodLabel('CARD', lang);
      case 'ONLINE_CARD':
        return RegionWorkflowService.paymentMethodLabel('ONLINE_CARD', lang);
      case 'EASY_PAY':
      case 'VOUCHER':
        return LocalizationService.currentCurrency.paymentChannels.first;
      default:
        return RegionWorkflowService.paymentMethodLabel('CASH', lang);
    }
  }

  static String _applyProfilePlaceholders(String template, StudioProfile studio) {
    return template
        .replaceAll('#{상호명}', studio.studioName)
        .replaceAll('#{담당자}', studio.instructorName)
        .replaceAll('#{대표자}', studio.instructorName)
        .replaceAll('#{강사명}', studio.instructorName)
        .replaceAll('#{직함}', studio.roleTitle)
        .replaceAll('#{고객호칭}', studio.memberWord)
        .replaceAll('#{비용호칭}', studio.feeWord)
        .replaceAll('#{장소호칭}', studio.placeTitle);
  }

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

    final lang = LocalizationService.currentLanguage;
    final currency = LocalizationService.currentCurrency;
    final memberNames = members.map((m) => m.name.split(' ').first).join(', ');
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final numericOnly = NumberFormat('#,###').format(invoice.amount);
    final displayAmount = _formatDisplayAmount(invoice.amount);
    final dueDateStr = lang == AppLanguage.korean
        ? DateFormat('yyyy.MM.dd').format(invoice.dueDate)
        : LocalizationService.formatDate(invoice.dueDate);

    // Clean account for 1-touch copy format
    final copyAccountText = '${studio.bankName} ${studio.accountNumber} ${studio.accountHolder}';

    // Korea-only 0-cost Toss Deep Link
    final cleanAccountOnly = studio.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final tossLink = RegionWorkflowService.supportsTossTransfer(currency)
        ? 'supertoss://send?bank=${Uri.encodeComponent(studio.bankName)}&account=$cleanAccountOnly&amount=${invoice.amount}'
        : '';

    // 0-cost Remote Card Payment Link (Stripe / Square / PayApp / Toss Payments etc.)
    final cardLink = studio.getFormattedCardPaymentUrl(
      amount: invoice.amount,
      orderTitle: invoice.title,
      customerName: memberNames,
    );

    String baseTemplate = studio.invoiceTemplate;
    // Prevent duplicate '원' suffix if non-KRW or non-Korean user runs on a legacy stored template
    if (currency != AppCurrency.krw || lang != AppLanguage.korean) {
      baseTemplate = RegionWorkflowService.stripDuplicateWonSuffix(baseTemplate, currency);
    }

    final amountForTemplate = (currency == AppCurrency.krw && lang == AppLanguage.korean && baseTemplate.contains('#{금액}원'))
        ? numericOnly
        : displayAmount;

    String rendered = _applyProfilePlaceholders(baseTemplate, studio)
        .replaceAll('#{회원명}', memberNames)
        .replaceAll('#{청구제목}', invoice.title)
        .replaceAll('#{안내내용}', invoice.title)
        .replaceAll('#{금액}', amountForTemplate)
        .replaceAll('#{계좌정보}', accountInfo)
        .replaceAll('#{계좌복사용}', copyAccountText)
        .replaceAll('#{결제수단안내}', currency.paymentChannelsSummary)
        .replaceAll('#{토스송금링크}', tossLink)
        .replaceAll('#{카드결제링크}', cardLink)
        .replaceAll('{카드결제링크}', cardLink)
        .replaceAll('#{납부기한}', dueDateStr);

    if (cardLink.isEmpty) {
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

  /// 2. 출석 / 등원 확인 알림
  static String generateAttendanceMessage({
    required StudioProfile studio,
    required Member member,
    required DateTime time,
  }) {
    final lang = LocalizationService.currentLanguage;
    final timeStr = DateFormat('HH:mm').format(time);
    final isSession = member.billingType == BillingType.sessionBased;
    final String sessionText;
    if (isSession) {
      final unit = LocalizationService.trParams('common_sessions_unit', {'n': '${member.remainingSessions}'});
      switch (lang) {
        case AppLanguage.korean:
          sessionText = '• 잔여 회차: ${member.remainingSessions}회';
          break;
        case AppLanguage.english:
          sessionText = '• Remaining: $unit';
          break;
        case AppLanguage.japanese:
          sessionText = '• 残回数: $unit';
          break;
        case AppLanguage.chinese:
          sessionText = '• 剩余课时: $unit';
          break;
        case AppLanguage.vietnamese:
          sessionText = '• Số buổi còn lại: $unit';
          break;
        case AppLanguage.spanish:
          sessionText = '• Sesiones restantes: $unit';
          break;
      }
    } else {
      switch (lang) {
        case AppLanguage.korean:
          sessionText = '• 이용권: 정기 패스';
          break;
        case AppLanguage.english:
          sessionText = '• Pass: ${LocalizationService.tr('common_monthly_pass')}';
          break;
        case AppLanguage.japanese:
          sessionText = '• ご利用プラン: ${LocalizationService.tr('common_monthly_pass')}';
          break;
        case AppLanguage.chinese:
          sessionText = '• 会员卡: ${LocalizationService.tr('common_monthly_pass')}';
          break;
        case AppLanguage.vietnamese:
          sessionText = '• Gói tập: ${LocalizationService.tr('common_monthly_pass')}';
          break;
        case AppLanguage.spanish:
          sessionText = '• Pase: ${LocalizationService.tr('common_monthly_pass')}';
          break;
      }
    }

    return _applyProfilePlaceholders(studio.attendanceTemplate, studio)
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
    return _applyProfilePlaceholders(studio.departureTemplate, studio)
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
    final lang = LocalizationService.currentLanguage;
    final methodStr = _formatPaymentMethod(paymentMethod);
    final formattedAmount = _formatDisplayAmount(amount);
    final memberName = member.name.split(' ').first;

    switch (lang) {
      case AppLanguage.korean:
        final sessionStr = remainingSessions != null ? '\n• 갱신 잔여 회차: $remainingSessions회' : '';
        return '''
[${studio.studioName}] 수납 확인 완료
안녕하세요, ${studio.studioName}입니다.
$memberName ${studio.memberWord}님의 ${studio.feeWord}가 정상 확인되었습니다.

• 수납 금액: $formattedAmount
• 결제 수단: $methodStr$sessionStr

항상 신뢰해 주셔서 감사드리며 더욱 알찬 수업으로 보답하겠습니다!
'''.trim();
      case AppLanguage.english:
        final sessionStr = remainingSessions != null ? '\n• Updated Balance: $remainingSessions sessions' : '';
        return '''
[${studio.studioName}] Payment Receipt Confirmed
Hello from ${studio.studioName}.
We have confirmed your ${studio.feeWord} payment for $memberName.

• Paid Amount: $formattedAmount
• Payment Method: $methodStr$sessionStr

Thank you for your payment and continued trust!
'''.trim();
      case AppLanguage.japanese:
        final sessionStr = remainingSessions != null ? '\n• 更新後残回数: $remainingSessions回' : '';
        return '''
[${studio.studioName}] ご入金確認のお知らせ
${studio.studioName}です。
$memberName 様の${studio.feeWord}のご入金を確認いたしました。

• お支払い金額: $formattedAmount
• 決済方法: $methodStr$sessionStr

いつもご利用ありがとうございます。引き続きよろしくお願いいたします。
'''.trim();
      case AppLanguage.chinese:
        final sessionStr = remainingSessions != null ? '\n• 最新剩余课时: $remainingSessions次' : '';
        return '''
[${studio.studioName}] 收款确认回执
您好，这里是 ${studio.studioName}。
已收到 $memberName 的${studio.feeWord}付款。

• 实收金额: $formattedAmount
• 支付方式: $methodStr$sessionStr

感谢您的信任与支持！
'''.trim();
      case AppLanguage.vietnamese:
        final sessionStr = remainingSessions != null ? '\n• Số buổi còn lại: $remainingSessions buổi' : '';
        return '''
[${studio.studioName}] Xác nhận đã thanh toán
Xin chào từ ${studio.studioName}.
Chúng tôi đã xác nhận khoản ${studio.feeWord} của $memberName.

• Số tiền đã thu: $formattedAmount
• Hình thức: $methodStr$sessionStr

Cảm ơn bạn đã tin tưởng và đồng hành!
'''.trim();
      case AppLanguage.spanish:
        final sessionStr = remainingSessions != null ? '\n• Sesiones restantes: $remainingSessions' : '';
        return '''
[${studio.studioName}] Recibo de pago confirmado
Hola de parte de ${studio.studioName}.
Confirmamos el pago de ${studio.feeWord} de $memberName.

• Importe pagado: $formattedAmount
• Método de pago: $methodStr$sessionStr

¡Gracias por tu confianza!
'''.trim();
    }
  }

  /// 5. 회차 만료 임박(1회 이하) 재등록 안내 알림
  static String generateExpiryWarningMessage({
    required StudioProfile studio,
    required Member member,
  }) {
    final lang = LocalizationService.currentLanguage;
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final fee = _formatDisplayAmount(member.defaultFee);
    final memberName = member.name.split(' ').first;

    switch (lang) {
      case AppLanguage.korean:
        return '''
[${studio.studioName}] 패스 만료 임박 안내
안녕하세요, ${studio.studioName}입니다.
$memberName ${studio.memberWord}님의 잔여 패스가 [${member.remainingSessions}회] 남았습니다.

원활한 수업 예약 및 연속적인 지도를 위해 재등록 안내를 드립니다.
• 재등록 ${studio.feeWord}: $fee
• 입금 계좌: $accountInfo

문의사항이 있으시면 언제든 편하게 연락 부탁드립니다. 감사합니다!
'''.trim();
      case AppLanguage.english:
        return '''
[${studio.studioName}] Pass Renewal Reminder
Hello from ${studio.studioName}.
$memberName has [${member.remainingSessions} session(s)] remaining on their current pass.

To keep your schedule uninterrupted, here are the renewal details:
• Renewal ${studio.feeWord}: $fee
• Payment Account: $accountInfo

Please reach out anytime if you have questions. Thank you!
'''.trim();
      case AppLanguage.japanese:
        return '''
[${studio.studioName}] 回数券更新のご案内
${studio.studioName}です。
$memberName 様の残り回数が【残り${member.remainingSessions}回】となりました。

スムーズなご予約継続のため、更新案内をお送りいたします。
• 更新${studio.feeWord}: $fee
• お振込先: $accountInfo

ご不明点がございましたらお気軽にご連絡ください。
'''.trim();
      case AppLanguage.chinese:
        return '''
[${studio.studioName}] 课时即将到期续费提醒
您好，这里是 ${studio.studioName}。
$memberName 的当前套餐仅剩【${member.remainingSessions}次】课时。

为方便您顺利预约后续课程，现附上续费信息：
• 续费${studio.feeWord}: $fee
• 收款账户: $accountInfo

如有任何疑问请随时联系，感谢配合！
'''.trim();
      case AppLanguage.vietnamese:
        return '''
[${studio.studioName}] Nhắc nhở gia hạn gói buổi
Xin chào từ ${studio.studioName}.
$memberName hiện chỉ còn [${member.remainingSessions} buổi] trong gói hiện tại.

Thông tin gia hạn dự kiến:
• ${studio.feeWord} gia hạn: $fee
• Tài khoản nhận: $accountInfo

Vui lòng liên hệ nếu cần hỗ trợ thêm. Cảm ơn bạn!
'''.trim();
      case AppLanguage.spanish:
        return '''
[${studio.studioName}] Aviso de renovación de bono
Hola de parte de ${studio.studioName}.
A $memberName le quedan [${member.remainingSessions} sesiones] en su bono actual.

Te enviamos los datos para renovar sin interrupciones:
• ${studio.feeWord} de renovación: $fee
• Cuenta de pago: $accountInfo

¡Contáctanos ante cualquier duda!
'''.trim();
    }
  }

  /// 6. 미납 수강료 1초 리마인드 알림
  static String generateUnpaidReminderMessage({
    required StudioProfile studio,
    required List<Member> members,
    required Invoice invoice,
  }) {
    final lang = LocalizationService.currentLanguage;
    final currency = LocalizationService.currentCurrency;
    final memberNames = members.map((m) => m.name.split(' ').first).join(', ');
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final copyAccountText = '${studio.bankName} ${studio.accountNumber} ${studio.accountHolder}';
    final displayAmount = _formatDisplayAmount(invoice.amount);
    final dueDateStr = lang == AppLanguage.korean
        ? DateFormat('yyyy.MM.dd').format(invoice.dueDate)
        : LocalizationService.formatDate(invoice.dueDate);

    final cardLink = studio.getFormattedCardPaymentUrl(
      amount: invoice.amount,
      orderTitle: invoice.title,
      customerName: memberNames,
    );

    switch (lang) {
      case AppLanguage.korean:
        final cardSection = cardLink.isNotEmpty ? '\n• 비대면 카드결제 : $cardLink' : '';
        final quickGuide = RegionWorkflowService.supportsTossTransfer(currency)
            ? '[간편 입금 안내]\n• 복사용 계좌 : $copyAccountText\n(계좌번호를 복사 후 토스나 은행 앱을 여시면 바로 송금됩니다)$cardSection'
            : '[결제 수단 안내]\n• 지원 수단 : ${currency.paymentChannels}$cardSection';
        return '''[${studio.studioName}] 입금 안내 리마인드
  
안녕하세요, ${studio.studioName}입니다.
$memberNames ${studio.memberWord}님의 [${invoice.title}] 납부 기한($dueDateStr)이 도래하여 정중히 안내드립니다.

────────────────
[입금 안내]
• 입금 금액 : $displayAmount
• 납부 기한 : $dueDateStr까지
• 입금 계좌 : $accountInfo
────────────────

$quickGuide

기한 내 확인 부탁드리며, 이미 입금하신 경우 본 안내는 너그러이 양해 부탁드립니다.
감사합니다.'''.trim();
      case AppLanguage.english:
        final cardSection = cardLink.isNotEmpty ? '\n• Online Card Link: $cardLink' : '';
        return '''[${studio.studioName}] Friendly Payment Reminder

Hello from ${studio.studioName}.
This is a gentle reminder that payment for [${invoice.title}] ($memberNames) is due by $dueDateStr.

────────────────
[Payment Details]
• Amount Due: $displayAmount
• Due Date: $dueDateStr
• Pay To: $accountInfo
• Channels: ${currency.paymentChannels}$cardSection
────────────────

If you have already sent this payment, please disregard this notice. Thank you!'''.trim();
      case AppLanguage.japanese:
        final cardSection = cardLink.isNotEmpty ? '\n• オンライン決済リンク: $cardLink' : '';
        return '''[${studio.studioName}] お支払い期限のご案内

いつもお世話になっております。${studio.studioName}です。
$memberNames 様の「${invoice.title}」のお支払期限（$dueDateStr）をお知らせいたします。

────────────────
[お支払い内容]
• 金額: $displayAmount
• 期限: $dueDateStrまで
• お振込先: $accountInfo
• 対応方法: ${currency.paymentChannels}$cardSection
────────────────

すでにお支払い済みの場合は行き違いをご容赦ください。よろしくお願いいたします。'''.trim();
      case AppLanguage.chinese:
        final cardSection = cardLink.isNotEmpty ? '\n• 在线支付链接: $cardLink' : '';
        return '''[${studio.studioName}] 付款到期提醒

您好，这里是 ${studio.studioName}。
温馨提醒您，$memberNames 的【${invoice.title}】即将到期（截止 $dueDateStr）。

────────────────
[付款信息]
• 应付金额: $displayAmount
• 截止日期: $dueDateStr
• 收款账户: $accountInfo
• 支付方式: ${currency.paymentChannels}$cardSection
────────────────

如您已完成支付，请忽略本条提醒。感谢配合！'''.trim();
      case AppLanguage.vietnamese:
        final cardSection = cardLink.isNotEmpty ? '\n• Link thanh toán thẻ: $cardLink' : '';
        return '''[${studio.studioName}] Nhắc thanh toán học phí

Xin chào từ ${studio.studioName}.
Thông báo khoản [${invoice.title}] của $memberNames sắp đến hạn ($dueDateStr).

────────────────
[Thông tin thanh toán]
• Số tiền: $displayAmount
• Hạn thanh toán: $dueDateStr
• Tài khoản nhận: $accountInfo
• Kênh hỗ trợ: ${currency.paymentChannels}$cardSection
────────────────

Nếu bạn đã thanh toán, vui lòng bỏ qua tin nhắn này. Cảm ơn bạn!'''.trim();
      case AppLanguage.spanish:
        final cardSection = cardLink.isNotEmpty ? '\n• Enlace tarjeta: $cardLink' : '';
        return '''[${studio.studioName}] Recordatorio de pago

Hola de parte de ${studio.studioName}.
Te recordamos que la cuota [${invoice.title}] ($memberNames) vence el $dueDateStr.

────────────────
[Datos de pago]
• Importe: $displayAmount
• Fecha límite: $dueDateStr
• Cuenta: $accountInfo
• Métodos: ${currency.paymentChannels}$cardSection
────────────────

Si ya realizaste el pago, por favor ignora este mensaje. ¡Gracias!'''.trim();
    }
  }

  static const MethodChannel _channel = MethodChannel('com.zeropass.app/sms_launcher');

  /// Launches the native SMS app with recipient and prefilled body.
  /// Uses native Android MethodChannel (Intent.ACTION_SENDTO + extras) to completely bypass
  /// URI length restrictions and URL truncation, allowing full long LMS/MMS messages.
  static Future<bool> launchNativeSms({
    required String recipientPhone,
    required String body,
  }) async {
    MonetizationService.instance.suppressAppOpenAdTemporarily(seconds: 60);
    MonetizationService.instance.recordValueAction(smsCount: 1);
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

  /// Launches WhatsApp with recipient and prefilled message for international users.
  static Future<bool> launchWhatsApp({
    required String recipientPhone,
    required String body,
  }) async {
    MonetizationService.instance.suppressAppOpenAdTemporarily(seconds: 60);
    MonetizationService.instance.recordValueAction(smsCount: 1);
    final cleanPhone = recipientPhone.replaceAll(RegExp(r'[^0-9]'), '');
    final encoded = Uri.encodeComponent(body);
    final uri = Uri.parse('https://wa.me/$cleanPhone?text=$encoded');
    try {
      if (await canLaunchUrl(uri)) {
        return await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
    return false;
  }

  /// Launches system universal share dialog (WhatsApp, Messenger, Email, Slack, etc.)
  static Future<void> launchUniversalShare({
    required String title,
    required String body,
  }) async {
    MonetizationService.instance.suppressAppOpenAdTemporarily(seconds: 60);
    MonetizationService.instance.recordValueAction(smsCount: 1);
    // ignore: deprecated_member_use
    await Share.share(body, subject: title);
  }
}
