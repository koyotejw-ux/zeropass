import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';

/// 카카오톡 0원 직접 공유 & 시스템 공유 서비스
/// 유료 알림톡 충전 비용 없이, 대표님 스마트폰의 카카오톡 앱을 통해
/// 학부모, 거래처, 강사에게 리치 포맷 메시지를 무료로 전송합니다.
class KakaoShareService {
  static final NumberFormat _currencyFormat = NumberFormat('#,###');

  /// 1. 청구서 수납 안내 카카오톡 메시지
  static String generateInvoiceKakaoMessage({
    required StudioProfile studio,
    required List<Member> members,
    required Invoice invoice,
  }) {
    final memberNames = members.map((m) => m.name.split(' ').first).join(', ');
    final accountInfo = '${studio.bankName} ${studio.accountNumber} (${studio.accountHolder})';
    final copyAccount = '${studio.bankName} ${studio.accountNumber} ${studio.accountHolder}';
    final formattedAmount = _currencyFormat.format(invoice.amount);
    final dueDateStr = DateFormat('yyyy년 M월 d일').format(invoice.dueDate);

    final cleanAccountOnly = studio.accountNumber.replaceAll(RegExp(r'[^0-9]'), '');
    final tossLink = 'supertoss://send?bank=${Uri.encodeComponent(studio.bankName)}&account=$cleanAccountOnly&amount=${invoice.amount}';

    return '''
[📢 ${studio.studioName} 수강료 청구 안내]

안녕하세요, ${studio.studioName}입니다.
$memberNames 회원님의 수강료 안내장을 보내드립니다.

────────────────
📋 청구 항목 : ${invoice.title}
💰 납부 금액 : $formattedAmount원
📅 납부 기한 : $dueDateStr까지
────────────────

💳 [입금 계좌 안내]
• $accountInfo
• 계좌 복사용 : $copyAccount

⚡ [토스 1초 간편 송금]
$tossLink
(링크를 누르시면 금액과 계좌가 토스에 자동 채워집니다)

감사합니다. 즐겁고 유익한 수업으로 보답하겠습니다!

────────────────
⚡ 스마트 출결·수납 ZeroPass
'''.trim();
  }

  /// 2. 출석 / 등원 확인 알림
  static String generateAttendanceKakaoMessage({
    required StudioProfile studio,
    required Member member,
    required DateTime time,
  }) {
    final timeStr = DateFormat('HH시 mm분').format(time);
    final isSession = member.billingType == BillingType.sessionBased;
    final sessionText = isSession ? '• 잔여 회차 : ${member.remainingSessions}회' : '• 이용권 : 정기 패스';

    return '''
[🔔 ${studio.studioName} 출석 체크 알림]

${member.name.split(' ').first} 학생이 안전하게 출석(등원)하였습니다.

• 출석 시각 : $timeStr
$sessionText

오늘도 학생의 안전과 성장을 위해 정성을 다해 지도하겠습니다. 감사합니다!

────────────────
⚡ 스마트 출결·수납 ZeroPass
'''.trim();
  }

  /// 3. 하원 / 수업 종료 알림
  static String generateDepartureKakaoMessage({
    required StudioProfile studio,
    required Member member,
    required DateTime time,
  }) {
    final timeStr = DateFormat('HH시 mm분').format(time);

    return '''
[👋 ${studio.studioName} 하원 알림]

${member.name.split(' ').first} 학생이 수업을 마치고 안전하게 하원(퇴실)하였습니다.

• 하원 시각 : $timeStr

집까지 안전하게 귀가할 수 있도록 지도하였습니다. 편안한 하루 되세요!

────────────────
⚡ 스마트 출결·수납 ZeroPass
'''.trim();
  }

  /// 4. 수납 확인 완료 영수증
  static String generateReceiptKakaoMessage({
    required StudioProfile studio,
    required Member member,
    required Invoice invoice,
  }) {
    final formattedAmount = _currencyFormat.format(invoice.amount);
    final paidDate = DateFormat('yyyy년 M월 d일 HH:mm').format(invoice.paidAt ?? DateTime.now());

    return '''
[🧾 ${studio.studioName} 수납 확인 영수증]

안녕하세요, ${studio.studioName}입니다.
${member.name.split(' ').first} 회원님의 수강료 입금이 정상 확인되었습니다.

────────────────
• 수납 항목 : ${invoice.title}
• 수납 금액 : $formattedAmount원
• 결제 수단 : ${invoice.paymentMethod ?? '계좌이체'}
• 확인 일시 : $paidDate
────────────────

항상 저희 ${studio.studioName}을 믿고 맡겨주셔서 진심으로 감사드립니다!

────────────────
⚡ 스마트 출결·수납 ZeroPass
'''.trim();
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
    final formattedAmount = _currencyFormat.format(amount);
    final nowStr = DateFormat('yyyy년 M월 d일').format(DateTime.now());

    return '''
[📦 ${studio.studioName} 발주 및 입금 확인 안내]

안녕하세요, $vendorName 담당자님.
${studio.studioName}(대표: ${studio.instructorName})에서 대금 이체 및 발주 내역을 전달드립니다.

────────────────
• 발주/정산 내용 : $title
• 송금 금액 : $formattedAmount원
• 이체 일자 : $nowStr
${bankInfo != null && bankInfo.isNotEmpty ? '• 수신 계좌 : $bankInfo\n' : ''}${memo != null && memo.isNotEmpty ? '• 요청 메모 : $memo\n' : ''}────────────────

내용 확인 부탁드리며, 이상이 있으시면 편하게 회신 주시기 바랍니다. 감사합니다!

────────────────
⚡ 사업장 경영 관리 ZeroPass
'''.trim();
  }

  /// 6. 프리랜서 강사/코치 월별 수당 정산서
  static String generateStaffSettlementKakaoMessage({
    required StudioProfile studio,
    required String staffName,
    required int amount,
    required String period,
    String? details,
  }) {
    final formattedAmount = _currencyFormat.format(amount);

    return '''
[💼 ${studio.studioName} $period 강사료/수당 정산 명세서]

안녕하세요, $staffName 강사님.
$period 수업 활동에 대한 정산 내역서를 전달드립니다.

────────────────
• 수령인 : $staffName 선생님
• 정산 대상 기간 : $period
• 실수령 지급액 : $formattedAmount원
${details != null && details.isNotEmpty ? '• 정산 산출 근거 :\n$details\n' : ''}────────────────

늘 열정으로 지도해주셔서 감사드리며, 문의사항은 편하게 말씀해주세요!

────────────────
⚡ 스마트 강사 정산 볼트 ZeroPass
'''.trim();
  }

  /// 7. 동료 원장님 앱 추천 및 초대장
  static String generateAppInviteKakaoMessage({
    required StudioProfile studio,
  }) {
    return '''
[🎁 원장님·대표님을 위한 100% 무료 출결·수납·간편장부 앱 추천]

안녕하세요! ${studio.studioName}에서 매우 유용하게 쓰고 있는 '제로패스'를 소개해 드립니다.

• 문자비 0원! 부모님 안심 출결 알림 & 전용 키오스크
• 은행 입금 푸시 알림 100% 자동 매칭 (미납 완벽 해결)
• 토스 1초 무료 송금 딥링크로 결제 수수료 0원
• 학원/헬스/필라테스/태권도/공방 맞춤형 간편 지출 장부

원장님 학원이나 매장 태블릿/스마트폰에 설치해 지금 바로 무료로 사용해보세요!
👉 구글 플레이스토어에서 '제로패스' 검색
'''.trim();
  }

  /// 카카오톡 직접 공유 또는 시스템 공유 호출 (비용 0원)
  static Future<bool> shareMessage({
    required String text,
    String? subject,
  }) async {
    // 1. 편리한 붙여넣기를 위해 클립보드에 우선 복사
    try {
      await Clipboard.setData(ClipboardData(text: text));
    } catch (_) {}

    // 2. 카카오톡 스킴 URL 시도
    final encoded = Uri.encodeComponent(text);
    final kakaoUri = Uri.parse('kakaotalk://msg/send?text=$encoded');

    try {
      if (await canLaunchUrl(kakaoUri)) {
        final launched = await launchUrl(kakaoUri);
        if (launched) return true;
      }
    } catch (_) {}

    // 3. Share.share로 폴백 (안드로이드/iOS 공유창에서 카카오톡이 최상단 노출)
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
