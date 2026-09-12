import 'package:flutter_test/flutter_test.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/services/bank_notification_filter.dart';
import 'package:zeropass/services/sms_template_service.dart';

void main() {
  group('ZeroPass Security & Compliance Tests', () {
    test('Strictly accepts verified banking package names only', () {
      expect(BankNotificationFilter.isVerifiedBankingApp('viva.republica.toss'), isTrue);
      expect(BankNotificationFilter.isVerifiedBankingApp('com.kakaobank.channel'), isTrue);
      expect(BankNotificationFilter.isVerifiedBankingApp('com.kbstar.kbbank'), isTrue);
      expect(BankNotificationFilter.isVerifiedBankingApp('com.shinhan.sbanking'), isTrue);
    });

    test('Strictly drops non-banking apps and personal messengers', () {
      // Must drop KakaoTalk, SMS, Instagram, Telegram etc.
      expect(BankNotificationFilter.isVerifiedBankingApp('com.kakao.talk'), isFalse);
      expect(BankNotificationFilter.isVerifiedBankingApp('com.samsung.android.messaging'), isFalse);
      expect(BankNotificationFilter.isVerifiedBankingApp('org.telegram.messenger'), isFalse);
      expect(BankNotificationFilter.isVerifiedBankingApp(null), isFalse);
      expect(BankNotificationFilter.isVerifiedBankingApp(''), isFalse);
    });

    test('Parses legitimate bank deposit notification correctly', () {
      final event = BankNotificationFilter.parseDepositNotification(
        packageName: 'viva.republica.toss',
        title: '토스 입금',
        text: '입금 320,000원 이도현',
      );

      expect(event, isNotNull);
      expect(event!.amount, 320000);
      expect(event.senderName, '이도현');
    });

    test('Instantly drops non-bank notifications in parser', () {
      final event = BankNotificationFilter.parseDepositNotification(
        packageName: 'com.kakao.talk',
        title: '채팅방',
        text: '입금 320,000원 보냈어',
      );

      expect(event, isNull);
    });

    test('Accurately matches bank deposit with parent (payerName)', () {
      final member = Member(
        id: 'mem_student',
        name: '김하늘 (학생)',
        payerName: '이영희', // 어머니 성함
        phone: '01012345678',
        groupName: '수학반',
        billingType: BillingType.monthlyRecurring,
        defaultFee: 300000,
        totalSessions: 0,
        remainingSessions: 0,
        registeredAt: DateTime(2026, 1, 1),
      );

      final invoice = Invoice(
        id: 'inv_target',
        memberIds: [member.id],
        recipientPhone: member.phone,
        title: '9월 수강료',
        amount: 300000,
        dueDate: DateTime(2026, 9, 20),
        status: PaymentStatus.unpaid,
      );

      final depositEvent = BankDepositEvent(
        packageName: 'viva.republica.toss',
        amount: 300000,
        senderName: '이영희',
        rawNotification: '입금 300,000원 이영희',
        receivedAt: DateTime.now(),
      );

      final matchResult = BankNotificationFilter.matchInvoiceWithDeposit(
        event: depositEvent,
        unpaidInvoices: [invoice],
        allMembers: [member],
      );

      expect(matchResult, isNotNull);
      expect(matchResult!.matchType, '학부모(입금자명) 일치');
      expect(matchResult.invoice.id, 'inv_target');
    });
  });

  group('SMS Template Placeholder Substitution Tests', () {
    test('Correctly formats billing template for single member with toss link and copy account', () {
      final studio = StudioProfile.defaultProfile();
      final member = Member(
        id: 'mem_test',
        name: '홍길동',
        phone: '01012345678',
        groupName: 'PT반',
        billingType: BillingType.sessionBased,
        defaultFee: 500000,
        totalSessions: 10,
        remainingSessions: 2,
        registeredAt: DateTime(2026, 3, 1),
      );
      final invoice = Invoice(
        id: 'inv_test',
        memberIds: [member.id],
        recipientPhone: member.phone,
        title: 'PT 10회 수강료',
        amount: 500000,
        dueDate: DateTime(2026, 3, 15),
        status: PaymentStatus.unpaid,
      );

      final message = SmsTemplateService.generateInvoiceMessage(
        studio: studio,
        members: [member],
        invoice: invoice,
      );

      expect(message.contains(studio.studioName), isTrue);
      expect(message.contains('홍길동'), isTrue);
      expect(message.contains('500,000원'), isTrue);
      expect(message.contains(studio.accountNumber), isTrue);
      expect(message.contains('복사용 계좌'), isTrue);
    });

    test('Correctly formats 1-second unpaid reminder message', () {
      final studio = StudioProfile.defaultProfile();
      final member = Member(
        id: 'mem_test',
        name: '박서준',
        phone: '01055556666',
        groupName: '보컬레슨',
        billingType: BillingType.monthlyRecurring,
        defaultFee: 200000,
        totalSessions: 0,
        remainingSessions: 0,
        registeredAt: DateTime(2026, 3, 1),
      );
      final invoice = Invoice(
        id: 'inv_test_remind',
        memberIds: [member.id],
        recipientPhone: member.phone,
        title: '3월 보컬 수강료',
        amount: 200000,
        dueDate: DateTime(2026, 3, 10),
        status: PaymentStatus.unpaid,
      );

      final reminder = SmsTemplateService.generateUnpaidReminderMessage(
        studio: studio,
        members: [member],
        invoice: invoice,
      );

      expect(reminder.contains('리마인드'), isTrue);
      expect(reminder.contains('박서준'), isTrue);
      expect(reminder.contains('200,000원'), isTrue);
      expect(reminder.contains('복사용 계좌'), isTrue);
    });
  });
}
