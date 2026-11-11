import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import 'monetization_service.dart';
import 'localization_service.dart';
import 'region_workflow_service.dart';

/// 카카오톡 0원 직접 공유 & 글로벌 시스템 공유 서비스
class KakaoShareService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###');

  static String _formatDisplayAmount(num amount) {
    if (LocalizationService.currentCurrency == AppCurrency.krw &&
        LocalizationService.currentLanguage == AppLanguage.korean) {
      return '${_currencyFormat.format(amount)}원';
    }
    return LocalizationService.formatAmount(amount);
  }

  static String _formatDateShort(DateTime date) {
    if (LocalizationService.currentLanguage == AppLanguage.korean) {
      return DateFormat('yyyy년 M월 d일').format(date);
    }
    return LocalizationService.formatDate(date);
  }

  static String _formatTimeShort(DateTime time) {
    if (LocalizationService.currentLanguage == AppLanguage.korean) {
      return DateFormat('HH시 mm분').format(time);
    }
    return DateFormat('HH:mm').format(time);
  }

  /// 1. 청구서 수납 안내 메시지
  static String generateInvoiceKakaoMessage({
    required StudioProfile studio,
    required List<Member> members,
    required Invoice invoice,
  }) {
    final lang = LocalizationService.currentLanguage;
    final currency = LocalizationService.currentCurrency;
    final memberNames = members.map((m) => m.name.split(' ').first).join(', ');
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final copyAccount = '${studio.bankName} ${studio.accountNumber} ${studio.accountHolder}';
    final displayAmount = _formatDisplayAmount(invoice.amount);
    final dueDateStr = _formatDateShort(invoice.dueDate);

    final cleanAccountOnly = studio.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final supportsToss = RegionWorkflowService.supportsTossTransfer(currency);
    final tossLink = supportsToss
        ? 'supertoss://send?bank=${Uri.encodeComponent(studio.bankName)}&account=$cleanAccountOnly&amount=${invoice.amount}'
        : '';

    final cardLink = studio.getFormattedCardPaymentUrl(
      amount: invoice.amount,
      orderTitle: invoice.title,
      customerName: memberNames,
    );

    if (lang == AppLanguage.korean) {
      final cardSection = cardLink.isNotEmpty
          ? '''

💳 [비대면 카드 결제]
$cardLink
(카드 무이자 할부 및 카드사 결제를 원하실 경우 위 링크를 눌러주세요)'''
          : '';

      final transferSection = supportsToss
          ? '''
⚡ [토스 1초 간편 송금]
$tossLink
(링크를 누르시면 금액과 계좌가 토스에 자동 채워집니다)'''
          : '''
🌍 [현지/해외 결제 채널]
• 지원 수단 : ${currency.paymentChannels}''';

      return '''
[📢 ${studio.studioName} ${studio.feeWord} 청구 안내]

안녕하세요, ${studio.studioName}입니다.
$memberNames ${studio.memberWord}님의 ${studio.feeWord} 안내장을 보내드립니다.

────────────────
📋 청구 항목 : ${invoice.title}
💰 납부 금액 : $displayAmount
📅 납부 기한 : $dueDateStr까지
────────────────

💳 [입금 계좌 안내]
• $accountInfo
• 계좌 복사용 : $copyAccount

$transferSection$cardSection

감사합니다. 즐겁고 유익한 수업으로 보답하겠습니다!

────────────────
⚡ 스마트 출결·수납 체크앤페이
'''.trim();
    }

    final cardSectionGlobal = cardLink.isNotEmpty ? '\n💳 Card Link: $cardLink' : '';
    switch (lang) {
      case AppLanguage.english:
        return '''
[📢 ${studio.studioName} — ${studio.feeWord} Invoice]

Hello from ${studio.studioName}.
Here is the ${studio.feeWord} invoice for $memberNames:

────────────────
📋 Item: ${invoice.title}
💰 Amount Due: $displayAmount
📅 Due Date: $dueDateStr
────────────────

💳 [Payment Methods]
• Account: $accountInfo
• Channels: ${currency.paymentChannels}$cardSectionGlobal

Thank you! We appreciate your prompt payment.
'''.trim();
      case AppLanguage.japanese:
        return '''
[📢 ${studio.studioName} — ${studio.feeWord}のご請求]

${studio.studioName}です。
$memberNames 様の${studio.feeWord}ご案内をお送りいたします。

────────────────
📋 項目 : ${invoice.title}
💰 ご請求金額 : $displayAmount
📅 お支払期限 : $dueDateStrまで
────────────────

💳 [お支払い先]
• 口座 : $accountInfo
• 対応決済 : ${currency.paymentChannels}$cardSectionGlobal

ご確認のほどよろしくお願いいたします。
'''.trim();
      case AppLanguage.chinese:
        return '''
[📢 ${studio.studioName} — ${studio.feeWord}账单通知]

您好，这里是 ${studio.studioName}。
以下是 $memberNames 的${studio.feeWord}账单详情：

────────────────
📋 账单项目 : ${invoice.title}
💰 应付金额 : $displayAmount
📅 截止日期 : $dueDateStr
────────────────

💳 [收款方式]
• 收款账户 : $accountInfo
• 支持渠道 : ${currency.paymentChannels}$cardSectionGlobal

感谢您的支持与配合！
'''.trim();
      case AppLanguage.vietnamese:
        return '''
[📢 ${studio.studioName} — Thông báo ${studio.feeWord}]

Xin chào từ ${studio.studioName}.
Thông tin thanh toán ${studio.feeWord} cho $memberNames:

────────────────
📋 Nội dung: ${invoice.title}
💰 Số tiền: $displayAmount
📅 Hạn thanh toán: $dueDateStr
────────────────

💳 [Thông tin chuyển khoản]
• Tài khoản: $accountInfo
• Kênh thanh toán: ${currency.paymentChannels}$cardSectionGlobal

Xin cảm ơn bạn đã đồng hành cùng chúng tôi!
'''.trim();
      case AppLanguage.spanish:
        return '''
[📢 ${studio.studioName} — Aviso de ${studio.feeWord}]

Hola de parte de ${studio.studioName}.
Aquí tienes el detalle de ${studio.feeWord} para $memberNames:

────────────────
📋 Concepto: ${invoice.title}
💰 Importe: $displayAmount
📅 Vencimiento: $dueDateStr
────────────────

💳 [Métodos de pago]
• Cuenta: $accountInfo
• Canales: ${currency.paymentChannels}$cardSectionGlobal

¡Muchas gracias!
'''.trim();
      case AppLanguage.korean:
        return '';
    }
  }

  /// 2. 출석 / 등원 확인 알림
  static String generateAttendanceKakaoMessage({
    required StudioProfile studio,
    required Member member,
    required DateTime time,
  }) {
    final lang = LocalizationService.currentLanguage;
    final timeStr = _formatTimeShort(time);
    final isSession = member.billingType == BillingType.sessionBased;
    final name = member.name.split(' ').first;

    switch (lang) {
      case AppLanguage.korean:
        final sessionText = isSession ? '• 잔여 회차 : ${member.remainingSessions}회' : '• 이용권 : 정기 패스';
        return '''
[🔔 ${studio.studioName} 출석 체크 알림]

$name ${studio.memberWord}님이 안전하게 출석(등원)하였습니다.

• 출석 시각 : $timeStr
$sessionText

오늘도 즐겁고 알찬 시간 되도록 정성을 다해 함께하겠습니다. 감사합니다!

────────────────
⚡ 스마트 출결·수납 체크앤페이
'''.trim();
      case AppLanguage.english:
        final sessionText = isSession
            ? '• Remaining Sessions: ${member.remainingSessions}'
            : '• Pass: Monthly Plan';
        return '''
[🔔 ${studio.studioName} Check-in Alert]

$name has safely checked in.

• Time: $timeStr
$sessionText

Wishing a great session today!
'''.trim();
      case AppLanguage.japanese:
        final sessionText = isSession ? '• 残回数 : ${member.remainingSessions}回' : '• ご利用券 : 定額パス';
        return '''
[🔔 ${studio.studioName} 出席通知]

$name 様が安全にチェックインされました。

• チェックイン時刻 : $timeStr
$sessionText

本日もよろしくお願いいたします！
'''.trim();
      case AppLanguage.chinese:
        final sessionText = isSession ? '• 剩余课时 : ${member.remainingSessions}次' : '• 会员卡 : 包月卡';
        return '''
[🔔 ${studio.studioName} 签到通知]

$name 已安全完成到校签到。

• 签到时间 : $timeStr
$sessionText

祝今天学习/锻炼愉快！
'''.trim();
      case AppLanguage.vietnamese:
        final sessionText = isSession
            ? '• Số buổi còn lại: ${member.remainingSessions} buổi'
            : '• Gói tập: Gói tháng';
        return '''
[🔔 ${studio.studioName} Thông báo điểm danh]

$name đã điểm danh an toàn.

• Thời gian: $timeStr
$sessionText

Chúc bạn có một buổi học thật tốt!
'''.trim();
      case AppLanguage.spanish:
        final sessionText = isSession
            ? '• Sesiones restantes: ${member.remainingSessions}'
            : '• Pase: Plan mensual';
        return '''
[🔔 ${studio.studioName} Aviso de llegada]

$name ha registrado su entrada correctamente.

• Hora: $timeStr
$sessionText

¡Que tengas una excelente sesión!
'''.trim();
    }
  }

  /// 3. 하원 / 수업 종료 알림
  static String generateDepartureKakaoMessage({
    required StudioProfile studio,
    required Member member,
    required DateTime time,
  }) {
    final lang = LocalizationService.currentLanguage;
    final timeStr = _formatTimeShort(time);
    final name = member.name.split(' ').first;

    switch (lang) {
      case AppLanguage.korean:
        return '''
[👋 ${studio.studioName} 하원·퇴실 알림]

$name ${studio.memberWord}님이 일정을 마치고 안전하게 귀가(퇴실)하였습니다.

• 퇴실 시각 : $timeStr

오늘 하루도 수고 많으셨습니다. 편안한 하루 되세요!

────────────────
⚡ 스마트 출결·수납 체크앤페이
'''.trim();
      case AppLanguage.english:
        return '''
[👋 ${studio.studioName} Check-out Notice]

$name has completed today's session and checked out safely.

• Check-out Time: $timeStr

Thank you and have a wonderful day!
'''.trim();
      case AppLanguage.japanese:
        return '''
[👋 ${studio.studioName} 退室完了のお知らせ]

$name 様が本日のスケジュールを終え、無事に退室されました。

• 退室時刻 : $timeStr

本日もお疲れ様でした！
'''.trim();
      case AppLanguage.chinese:
        return '''
[👋 ${studio.studioName} 签退离校通知]

$name 已完成今日课程并安全离校。

• 签退时间 : $timeStr

祝您生活愉快！
'''.trim();
      case AppLanguage.vietnamese:
        return '''
[👋 ${studio.studioName} Thông báo ra về]

$name đã hoàn tất buổi học và ra về an toàn.

• Thời gian ra về: $timeStr

Chúc bạn một ngày tốt lành!
'''.trim();
      case AppLanguage.spanish:
        return '''
[👋 ${studio.studioName} Aviso de salida]

$name ha finalizado su sesión de hoy y salido correctamente.

• Hora de salida: $timeStr

¡Gracias y feliz día!
'''.trim();
    }
  }

  /// 4. 수납 확인 완료 영수증
  static String generateReceiptKakaoMessage({
    required StudioProfile studio,
    required Member member,
    required Invoice invoice,
  }) {
    final lang = LocalizationService.currentLanguage;
    final displayAmount = _formatDisplayAmount(invoice.amount);
    final paidAt = invoice.paidAt ?? DateTime.now();
    final paidDate = lang == AppLanguage.korean
        ? DateFormat('yyyy년 M월 d일 HH:mm').format(paidAt)
        : '${LocalizationService.formatDate(paidAt)} ${DateFormat('HH:mm').format(paidAt)}';

    final rawMethod = invoice.paymentMethod ?? 'TRANSFER';
    String methodLabel;
    if (lang == AppLanguage.korean) {
      methodLabel = rawMethod;
      if (rawMethod == 'TRANSFER') {
        methodLabel = '계좌이체';
      } else if (rawMethod == 'OFFLINE_CARD') {
        methodLabel = '신용카드(현장)';
      } else if (rawMethod == 'ONLINE_CARD') {
        methodLabel = '비대면 신용카드(원격)';
      } else if (rawMethod == 'EASY_PAY') {
        methodLabel = '간편결제';
      } else if (rawMethod == 'VOUCHER') {
        methodLabel = '바우처/지역화폐';
      } else if (rawMethod == 'CASH') {
        methodLabel = '현금';
      }
    } else {
      methodLabel = LocalizationService.paymentMethodLabel(rawMethod);
    }

    final name = member.name.split(' ').first;
    switch (lang) {
      case AppLanguage.korean:
        return '''
[🧾 ${studio.studioName} 수납 확인 영수증]

안녕하세요, ${studio.studioName}입니다.
$name ${studio.memberWord}님의 ${studio.feeWord} 입금이 정상 확인되었습니다.

────────────────
• 수납 항목 : ${invoice.title}
• 수납 금액 : $displayAmount
• 결제 수단 : $methodLabel
• 확인 일시 : $paidDate
────────────────

항상 저희 ${studio.studioName}을 믿고 맡겨주셔서 진심으로 감사드립니다!

────────────────
⚡ 스마트 출결·수납 체크앤페이
'''.trim();
      case AppLanguage.english:
        return '''
[🧾 ${studio.studioName} Payment Receipt]

Hello from ${studio.studioName}.
Your payment for ${studio.feeWord} ($name) has been confirmed.

────────────────
• Item: ${invoice.title}
• Paid Amount: $displayAmount
• Method: $methodLabel
• Date: $paidDate
────────────────

Thank you for your business!
'''.trim();
      case AppLanguage.japanese:
        return '''
[🧾 ${studio.studioName} 領収書（入金確認）]

${studio.studioName}です。
$name 様の${studio.feeWord}のご入金を確認いたしました。

────────────────
• 内容 : ${invoice.title}
• 金額 : $displayAmount
• 方法 : $methodLabel
• 確認日時 : $paidDate
────────────────

いつもご利用いただきありがとうございます。
'''.trim();
      case AppLanguage.chinese:
        return '''
[🧾 ${studio.studioName} 收款凭证]

您好，这里是 ${studio.studioName}。
已确认收到 $name 的${studio.feeWord}付款：

────────────────
• 收费项目 : ${invoice.title}
• 实收金额 : $displayAmount
• 支付方式 : $methodLabel
• 确认时间 : $paidDate
────────────────

感谢您的支持与信任！
'''.trim();
      case AppLanguage.vietnamese:
        return '''
[🧾 ${studio.studioName} Biên nhận thanh toán]

Xin chào từ ${studio.studioName}.
Đã xác nhận thanh toán ${studio.feeWord} cho $name:

────────────────
• Hạng mục: ${invoice.title}
• Số tiền: $displayAmount
• Hình thức: $methodLabel
• Thời gian: $paidDate
────────────────

Xin cảm ơn sự tin tưởng của bạn!
'''.trim();
      case AppLanguage.spanish:
        return '''
[🧾 ${studio.studioName} Recibo de pago]

Hola de parte de ${studio.studioName}.
Confirmamos el cobro de ${studio.feeWord} de $name:

────────────────
• Concepto: ${invoice.title}
• Importe: $displayAmount
• Método: $methodLabel
• Fecha: $paidDate
────────────────

¡Muchas gracias por tu confianza!
'''.trim();
    }
  }

  /// 5. 거래처 발주서 및 입금 확인증 (B2B 지출 알림)
  static String generateVendorOrderKakaoMessage({
    required StudioProfile studio,
    required String vendorName,
    required String title,
    required int amount,
    String? bankInfo,
    String? memo,
  }) {
    final lang = LocalizationService.currentLanguage;
    final displayAmount = _formatDisplayAmount(amount);
    final nowStr = _formatDateShort(DateTime.now());

    switch (lang) {
      case AppLanguage.korean:
        return '''
[📦 ${studio.studioName} 발주 및 입금 확인 안내]

안녕하세요, $vendorName 담당자님.
${studio.studioName}(${studio.roleTitle}: ${studio.instructorName})에서 대금 이체 및 발주 내역을 전달드립니다.

────────────────
• 발주/정산 내용 : $title
• 송금 금액 : $displayAmount
• 이체 일자 : $nowStr
${bankInfo != null && bankInfo.isNotEmpty ? '• 수신 계좌 : $bankInfo\n' : ''}${memo != null && memo.isNotEmpty ? '• 요청 메모 : $memo\n' : ''}────────────────

내용 확인 부탁드리며, 이상이 있으시면 편하게 회신 주시기 바랍니다. 감사합니다!

────────────────
⚡ 사업장 경영 관리 체크앤페이
'''.trim();
      case AppLanguage.english:
        return '''
[📦 ${studio.studioName} Purchase Order & Remittance]

Hello $vendorName team,
From ${studio.studioName} (${studio.roleTitle}: ${studio.instructorName}) — payment & order details:

────────────────
• Order / Item: $title
• Amount Paid: $displayAmount
• Date: $nowStr
${bankInfo != null && bankInfo.isNotEmpty ? '• Bank/Account: $bankInfo\n' : ''}${memo != null && memo.isNotEmpty ? '• Note: $memo\n' : ''}────────────────

Please confirm receipt. Thank you!
'''.trim();
      case AppLanguage.japanese:
        return '''
[📦 ${studio.studioName} 発注・振込完了のご案内]

$vendorName ご担当者様
${studio.studioName}（${studio.instructorName}）より、発注・振込明細をお送りいたします。

────────────────
• 内容 : $title
• 金額 : $displayAmount
• 支払日 : $nowStr
${bankInfo != null && bankInfo.isNotEmpty ? '• 振込先 : $bankInfo\n' : ''}${memo != null && memo.isNotEmpty ? '• メモ : $memo\n' : ''}────────────────

ご確認のほどよろしくお願いいたします。
'''.trim();
      case AppLanguage.chinese:
        return '''
[📦 ${studio.studioName} 采购付款与对账通知]

您好，$vendorName：
${studio.studioName}（${studio.instructorName}）向您发送本次采购与打款明细：

────────────────
• 采购/结算项目 : $title
• 付款金额 : $displayAmount
• 付款日期 : $nowStr
${bankInfo != null && bankInfo.isNotEmpty ? '• 收款账户 : $bankInfo\n' : ''}${memo != null && memo.isNotEmpty ? '• 备注 : $memo\n' : ''}────────────────

请查收确认，如有问题请随时联系！
'''.trim();
      case AppLanguage.vietnamese:
        return '''
[📦 ${studio.studioName} Đơn đặt hàng & Xác nhận chuyển khoản]

Kính gửi $vendorName,
Từ ${studio.studioName} (${studio.instructorName}):

────────────────
• Nội dung: $title
• Số tiền: $displayAmount
• Ngày chuyển: $nowStr
${bankInfo != null && bankInfo.isNotEmpty ? '• Tài khoản nhận: $bankInfo\n' : ''}${memo != null && memo.isNotEmpty ? '• Ghi chú: $memo\n' : ''}────────────────

Vui lòng kiểm tra và xác nhận. Xin cảm ơn!
'''.trim();
      case AppLanguage.spanish:
        return '''
[📦 ${studio.studioName} Orden de compra y pago]

Hola $vendorName,
Desde ${studio.studioName} (${studio.instructorName}) enviamos el detalle del pago:

────────────────
• Concepto: $title
• Importe: $displayAmount
• Fecha: $nowStr
${bankInfo != null && bankInfo.isNotEmpty ? '• Cuenta: $bankInfo\n' : ''}${memo != null && memo.isNotEmpty ? '• Nota: $memo\n' : ''}────────────────

Por favor confirma la recepción. ¡Gracias!
'''.trim();
    }
  }

  /// 6. 강사/코치 수당 정산서 (국가별 원천징수 지원)
  static String generateStaffSettlementKakaoMessage({
    required StudioProfile studio,
    required String staffName,
    required int amount,
    required String period,
    String? details,
    bool isWithholdingApplied = false,
    int withholdingTax = 0,
    int? grossAmount,
    String? bankAccount,
  }) {
    final lang = LocalizationService.currentLanguage;
    final currency = LocalizationService.currentCurrency;
    final displayAmount = _formatDisplayAmount(amount);

    if (lang == AppLanguage.korean && currency == AppCurrency.krw) {
      String taxSection = '';
      if (isWithholdingApplied && withholdingTax > 0) {
        final gross = grossAmount ?? (amount + withholdingTax);
        final incomeTax = (gross * 0.03).round();
        final localTax = (gross * 0.003).round();
        taxSection = '''
• 총 지급액 (공제 전) : ${_formatDisplayAmount(gross)}
• 사업소득세 (국세 3.0%) : -${_formatDisplayAmount(incomeTax)}
• 지방소득세 (지방세 0.3%) : -${_formatDisplayAmount(localTax)}
• 원천징수 합계 (3.3%) : -${_formatDisplayAmount(withholdingTax)}
''';
      }

      final bankSection = bankAccount != null && bankAccount.isNotEmpty
          ? '• 입금 계좌 : $bankAccount\n'
          : '';

      return '''
[💼 ${studio.studioName} $period 강사료/수당 정산 명세서]

안녕하세요, $staffName 강사님.
$period 수업 활동에 대한 정산 내역서를 전달드립니다.

────────────────
• 수령인 : $staffName 선생님
• 정산 대상 기간 : $period
$taxSection────────────────
• 실수령 입금액 : $displayAmount
$bankSection${details != null && details.isNotEmpty ? '• 정산 산출 근거 :\n$details\n' : ''}────────────────

늘 열정으로 지도해주셔서 감사드리며, 문의사항은 편하게 말씀해주세요!

────────────────
⚡ 스마트 강사 정산 볼트 체크앤페이
'''.trim();
    }

    final gross = grossAmount ?? (amount + withholdingTax);
    final taxBlock = (isWithholdingApplied && withholdingTax > 0)
        ? '• Gross: ${_formatDisplayAmount(gross)}\n• Tax Withheld: -${_formatDisplayAmount(withholdingTax)}\n'
        : '';
    final bankLine = (bankAccount != null && bankAccount.isNotEmpty)
        ? '• Bank / Payout Account: $bankAccount\n'
        : '';

    switch (lang) {
      case AppLanguage.korean:
      case AppLanguage.english:
        return '''
[💼 ${studio.studioName} $period Instructor Payout Statement]

Hello $staffName,
Here is your payout statement for $period:

────────────────
• Recipient: $staffName
• Period: $period
$taxBlock────────────────
• Net Payout: $displayAmount
$bankLine${details != null && details.isNotEmpty ? '• Breakdown:\n$details\n' : ''}────────────────

Thank you for your great work!
'''.trim();
      case AppLanguage.japanese:
        final jpTax = (isWithholdingApplied && withholdingTax > 0)
            ? '• 総支給額: ${_formatDisplayAmount(gross)}\n• 源泉徴収税額: -${_formatDisplayAmount(withholdingTax)}\n'
            : '';
        return '''
[💼 ${studio.studioName} $period 報酬支払明細書]

$staffName 様
$period のお支払い明細をお送りいたします。

────────────────
• 対象期間 : $period
$jpTax────────────────
• 差引振込額 : $displayAmount
$bankLine${details != null && details.isNotEmpty ? '• 内訳 :\n$details\n' : ''}────────────────

いつもありがとうございます。
'''.trim();
      case AppLanguage.chinese:
        final zhTax = (isWithholdingApplied && withholdingTax > 0)
            ? '• 税前总额: ${_formatDisplayAmount(gross)}\n• 预扣税额: -${_formatDisplayAmount(withholdingTax)}\n'
            : '';
        return '''
[💼 ${studio.studioName} $period 讲师课时费结算单]

$staffName 老师，您好：
以下是您在 $period 的课酬结算明细：

────────────────
• 结算周期 : $period
$zhTax────────────────
• 实发金额 : $displayAmount
$bankLine${details != null && details.isNotEmpty ? '• 明细 :\n$details\n' : ''}────────────────

感谢您的辛勤付出！
'''.trim();
      case AppLanguage.vietnamese:
        final viTax = (isWithholdingApplied && withholdingTax > 0)
            ? '• Tổng trước thuế: ${_formatDisplayAmount(gross)}\n• Khấu trừ thuế: -${_formatDisplayAmount(withholdingTax)}\n'
            : '';
        return '''
[💼 ${studio.studioName} Bảng quyết toán kỳ $period]

Xin chào $staffName,
Chi tiết thanh toán kỳ $period:

────────────────
• Kỳ thanh toán: $period
$viTax────────────────
• Thực nhận: $displayAmount
$bankLine${details != null && details.isNotEmpty ? '• Chi tiết:\n$details\n' : ''}────────────────

Cảm ơn sự đóng góp của bạn!
'''.trim();
      case AppLanguage.spanish:
        final esTax = (isWithholdingApplied && withholdingTax > 0)
            ? '• Importe bruto: ${_formatDisplayAmount(gross)}\n• Retención: -${_formatDisplayAmount(withholdingTax)}\n'
            : '';
        return '''
[💼 ${studio.studioName} Liquidación $period]

Hola $staffName,
Resumen de pagos del periodo $period:

────────────────
• Periodo: $period
$esTax────────────────
• Importe neto: $displayAmount
$bankLine${details != null && details.isNotEmpty ? '• Detalle:\n$details\n' : ''}────────────────

¡Gracias por tu excelente labor!
'''.trim();
    }
  }

  /// 7. 앱 추천 및 초대장
  static String generateAppInviteKakaoMessage({
    required StudioProfile studio,
  }) {
    final lang = LocalizationService.currentLanguage;
    switch (lang) {
      case AppLanguage.korean:
        return '''
[🎁 100% 무료 출결·수납·간편장부 앱 추천]

안녕하세요! ${studio.studioName}에서 유용하게 쓰고 있는 '체크앤페이'를 소개해 드립니다.

• 문자비 0원! 안심 출결 알림 & 무인 키오스크
• 은행 입금 푸시 알림 자동 매칭 (미납 완벽 해결)
• 토스 1초 무료 송금 딥링크로 결제 수수료 0원
• 업종 맞춤형 회원 관리 & 간편 지출 장부

매장 태블릿이나 스마트폰에 설치해 지금 바로 무료로 사용해보세요!
👉 구글 플레이스토어에서 '체크앤페이' 검색
'''.trim();
      case AppLanguage.english:
        return '''
[🎁 Check & Pay — Smart Studio Check-in & Billing App]

Hi! We use Check & Pay at ${studio.studioName} to manage attendance, billing, and tax-ready ledgers with zero platform fees.
Search "Check & Pay" on Google Play Store!
'''.trim();
      case AppLanguage.japanese:
        return '''
[🎁 Check & Pay — 教室・スタジオ向け出席＆請求管理アプリ]

${studio.studioName}で利用中の「Check & Pay」をご紹介します。キオスク出席・請求書・経費帳簿までこれひとつで管理できます！
'''.trim();
      case AppLanguage.chinese:
        return '''
[🎁 Check & Pay — 工作室智能考勤与收银管理]

向您推荐 ${studio.studioName} 正在使用的 Check & Pay：自助签到终端、账单催收、多国税务台账一站搞定！
'''.trim();
      case AppLanguage.vietnamese:
        return '''
[🎁 Check & Pay — Quản lý điểm danh & học phí thông minh]

Giới thiệu Check & Pay đang được sử dụng tại ${studio.studioName}: Kiosk điểm danh, hóa đơn & sổ thu chi tiện lợi!
'''.trim();
      case AppLanguage.spanish:
        return '''
[🎁 Check & Pay — Gestión inteligente de asistencia y cobros]

Te recomendamos Check & Pay, la app que usamos en ${studio.studioName} para quiosco, facturas y control fiscal.
'''.trim();
    }
  }

  /// 카카오톡 직접 공유 또는 글로벌 시스템 공유 호출 (비용 0원)
  static Future<bool> shareMessage({
    required String text,
    String? subject,
  }) async {
    MonetizationService.instance.suppressAppOpenAdTemporarily(seconds: 60);
    MonetizationService.instance.recordValueAction(smsCount: 1);
    // 1. 편리한 붙여넣기를 위해 클립보드에 우선 복사
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}

    // 2. 국내 사용자의 경우 카카오톡 스킴 URL 우선 시도
    if (LocalizationService.isDomestic) {
      final encoded = Uri.encodeComponent(text);
      final kakaoUri = Uri.parse('kakaotalk://msg/send?text=$encoded');

      try {
        if (await canLaunchUrl(kakaoUri)) {
          final launched = await launchUrl(kakaoUri);
          if (launched) return true;
        }
      } catch (_) {}
    }

    // 3. 글로벌 사용자 및 카카오톡 미설치 시 시스템 네이티브 공유 시트(WhatsApp/Messages/LINE 등)로 자동 연동
    try {
      // ignore: deprecated_member_use
      final result = await Share.share(
        text,
        subject: subject,
      );
      return result.status != ShareResultStatus.dismissed;
    } catch (_) {
      return false;
    }
  }
}
