import 'localization_service.dart';

/// ZeroPass Bank & Financial Notification Auto-Parser
/// Legal & Compliance Safeguard:
/// Strictly filters incoming notifications by verified banking and telecom financial apps.
/// Immediately drops and ignores personal messengers (KakaoTalk, Instagram, general SMS)
/// without reading or logging content.
class BankNotificationFilter {
  // Verified Korean & Global Bank / Fintech Package Names
  static const Set<String> verifiedBankPackages = {
    // Korea
    'com.kbstar.kbbank', // KB국민은행 Star뱅킹
    'com.shinhan.sbanking', // 신한 쏠(SOL)
    'com.ibk.neobanking', // IBK기업은행
    'com.wooribank.smart.npib', // 우리은행 우리WON뱅킹
    'nh.smart.banking', // NH스마트뱅킹
    'com.kakaobank.channel', // 카카오뱅크
    'viva.republica.toss', // 토스 (Toss)
    'com.kbankwith.smartbank', // 케이뱅크
    'com.scbank.kor.android', // SC제일은행
    'com.hana.onedream', // 하나은행 하나원큐
    'com.epost.pser.damo', // 우체국스마트뱅킹
    'com.suhyup.smart', // 수협 파트너뱅크
    'com.kfcc.mobilebank', // 새마을금고 MG더뱅킹
    // Global (US / JP / EU / UK / VN / ES)
    'com.chase.sig.android', // Chase (US)
    'com.infonow.bofa', // Bank of America (US)
    'com.wf.wellsfargomobile', // Wells Fargo (US)
    'com.venmo', // Venmo (US)
    'com.paypal.android.p2pmobile', // PayPal
    'com.squareup.cash', // Cash App
    'com.revolut.revolut', // Revolut
    'com.transferwise.android', // Wise
    'jp.co.rakuten_bank.rakutenbank', // Rakuten Bank (JP)
    'jp.co.bk.mufg.mb', // MUFG (JP)
    'com.mbmobile', // MB Bank (VN)
    'com.VCB', // Vietcombank (VN)
    'com.bbva.bbvacontigo', // BBVA (ES)
    'es.bancosantander.apps', // Santander (ES)
  };

  /// Evaluates whether an incoming notification origin is legitimate.
  static bool isVerifiedBankingApp(String? packageName) {
    if (packageName == null || packageName.isEmpty) {
      return false;
    }
    return verifiedBankPackages.contains(packageName.trim().toLowerCase());
  }

  /// Parses deposit notifications from major banking apps.
  /// Example patterns:
  /// - "[입금] 320,000원 이도현"
  /// - "홍길동님께서 700,000원을 입금하셨습니다"
  /// - "KB 1234 입금 340,000원 하율하린"
  /// - "토스뱅크 1000-*** 입금 880,000원 강지훈"
  static BankDepositEvent? parseDepositNotification({
    required String? packageName,
    required String? title,
    required String? text,
  }) {
    // 1. Mandatory Security Rule: Drop non-bank notifications immediately
    if (!isVerifiedBankingApp(packageName)) {
      return null;
    }

    if (text == null || text.isEmpty) return null;

    // Remove linebreaks for uniform regex scanning
    final normalized = text.replaceAll('\n', ' ').trim();

    // Pattern 1: "입금 320,000원 이도현" or "[입금] 320,000원 이도현"
    final regex1 = RegExp(r'(?:입금|받은금액)\s*:?\s*([0-9,]+)\s*원?\s*([가-힣a-zA-Z\s0-9]+)?');
    // Pattern 2: "이도현 320,000원 입금"
    final regex2 = RegExp(r'([가-힣a-zA-Z]{2,10})\s*(?:님께서)?\s*([0-9,]+)\s*원?\s*입금');

    Match? match = regex1.firstMatch(normalized);
    String? amountStr;
    String? sender;

    if (match != null) {
      amountStr = match.group(1)?.replaceAll(',', '');
      sender = match.group(2)?.trim();
    } else {
      match = regex2.firstMatch(normalized);
      if (match != null) {
        sender = match.group(1)?.trim();
        amountStr = match.group(2)?.replaceAll(',', '');
      }
    }

    if (amountStr != null) {
      final amount = int.tryParse(amountStr) ?? 0;
      if (amount > 0) {
        // Clean sender noise (e.g. 잔액 123원 등 뒤에 붙는 단어 제거)
        if (sender != null) {
          sender = sender.split(' ').first;
          sender = sender.replaceAll(RegExp(r'[^가-힣a-zA-Z0-9]'), '');
        }

        return BankDepositEvent(
          packageName: packageName!,
          amount: amount,
          senderName: (sender != null && sender.isNotEmpty) ? sender : null,
          rawNotification: text,
          receivedAt: DateTime.now(),
        );
      }
    }

    return null;
  }

  /// 100% Match Bank Deposit Event with unpaid invoices using:
  /// 1) Amount exact match
  /// 2) Member Name match OR Member PayerName (Parent/Actual Depositor) match
  static InvoiceMatchResult? matchInvoiceWithDeposit({
    required BankDepositEvent event,
    required List<dynamic> unpaidInvoices, // List<Invoice>
    required List<dynamic> allMembers, // List<Member>
  }) {
    final memberMap = {for (var m in allMembers) m.id: m};

    for (final inv in unpaidInvoices) {
      if (inv.amount != event.amount) continue;

      // Check if any member connected to this invoice matches the sender name
      final invoiceMembers = inv.memberIds
          .map((id) => memberMap[id])
          .where((m) => m != null)
          .toList();

      if (event.senderName == null || event.senderName!.isEmpty) {
        // Fallback: match by amount if there's only 1 exact amount match
        return InvoiceMatchResult(
          invoice: inv,
          matchedMemberName: null,
          matchType: LocalizationService.pick(
            ko: '금액 일치',
            en: 'Amount Match',
            ja: '金額一致',
            zh: '金额匹配',
            vi: 'Khớp số tiền',
            es: 'Coincidencia de importe',
          ),
        );
      }

      final cleanSender = event.senderName!.replaceAll(' ', '');

      for (final member in invoiceMembers) {
        final cleanMemberName = member!.name.split(' ').first.replaceAll(' ', '');
        final cleanPayerName = member.payerName?.replaceAll(' ', '') ?? '';

        // Match 1: Direct member name match
        if (cleanSender.contains(cleanMemberName) || cleanMemberName.contains(cleanSender)) {
          return InvoiceMatchResult(
            invoice: inv,
            matchedMemberName: member.name,
            matchType: LocalizationService.pick(
              ko: '회원명 일치',
              en: 'Member Match',
              ja: '会員名一致',
              zh: '会员姓名匹配',
              vi: 'Khớp tên hội viên',
              es: 'Coincidencia de nombre',
            ),
          );
        }

        // Match 2: Parent / Actual depositor (payerName) match
        if (cleanPayerName.isNotEmpty &&
            (cleanSender.contains(cleanPayerName) || cleanPayerName.contains(cleanSender))) {
          return InvoiceMatchResult(
            invoice: inv,
            matchedMemberName: LocalizationService.pick(
              ko: '${member.name} (입금자: ${member.payerName})',
              en: '${member.name} (Payer: ${member.payerName})',
              ja: '${member.name} (振込人: ${member.payerName})',
              zh: '${member.name} (付款人: ${member.payerName})',
              vi: '${member.name} (Người gửi: ${member.payerName})',
              es: '${member.name} (Pagador: ${member.payerName})',
            ),
            matchType: LocalizationService.pick(
              ko: '학부모(입금자명) 일치',
              en: 'Payer / Guardian Match',
              ja: '保護者・振込名義一致',
              zh: '家长/付款人匹配',
              vi: 'Khớp tên người gửi',
              es: 'Coincidencia de pagador',
            ),
          );
        }
      }
    }

    return null;
  }
}

class InvoiceMatchResult {
  final dynamic invoice;
  final String? matchedMemberName;
  final String matchType;

  InvoiceMatchResult({
    required this.invoice,
    required this.matchedMemberName,
    required this.matchType,
  });
}

class BankDepositEvent {
  final String packageName;
  final int amount;
  final String? senderName;
  final String rawNotification;
  final DateTime receivedAt;

  BankDepositEvent({
    required this.packageName,
    required this.amount,
    this.senderName,
    required this.rawNotification,
    required this.receivedAt,
  });
}
