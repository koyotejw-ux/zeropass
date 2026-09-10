/// ZeroPass Bank Notification Filter Service
/// Legal & Compliance Safeguard:
/// Strictly filters incoming notifications by verified banking app package names.
/// Immediately drops and ignores all non-financial notifications (KakaoTalk, personal SMS, etc.)
/// without reading or logging content.
class BankNotificationFilter {
  // Verified South Korean Bank & Fintech Package Names
  static const Set<String> verifiedBankPackages = {
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
  };

  /// Evaluates whether an incoming notification origin is legitimate.
  /// If [packageName] is not in [verifiedBankPackages], it is immediately rejected.
  static bool isVerifiedBankingApp(String? packageName) {
    if (packageName == null || packageName.isEmpty) {
      return false;
    }
    return verifiedBankPackages.contains(packageName.trim().toLowerCase());
  }

  /// Parses financial deposit notification content.
  /// Strictly requires verified origin before any processing.
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

    // 2. Simple deposit regex matcher (e.g. "[입금] 320,000원 이도현" or "입금 880,000원 (강지훈)")
    final depositRegex = RegExp(r'입금\s*([0-9,]+)\s*원?\s*([가-힣a-zA-Z\s]+)?');
    final match = depositRegex.firstMatch(text);

    if (match != null) {
      final amountStr = match.group(1)?.replaceAll(',', '');
      final amount = int.tryParse(amountStr ?? '0') ?? 0;
      final sender = match.group(2)?.trim();

      if (amount > 0) {
        return BankDepositEvent(
          packageName: packageName!,
          amount: amount,
          senderName: sender,
          rawNotification: text,
          receivedAt: DateTime.now(),
        );
      }
    }

    return null;
  }
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
