import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/services/kakao_share_service.dart';
import 'package:zeropass/services/sequential_dispatch_service.dart';
import 'package:zeropass/services/sms_template_service.dart';

class _MockStudioNotifier extends StudioProfileNotifier {
  final StudioProfile _studio;
  _MockStudioNotifier(this._studio);
  @override
  Future<StudioProfile> build() async => _studio;
}

class _MockInvoicesNotifier extends InvoicesNotifier {
  final List<Invoice> _invoices;
  _MockInvoicesNotifier(this._invoices);
  @override
  Future<List<Invoice>> build() async => _invoices;
}

class _MockMembersNotifier extends MembersNotifier {
  final List<Member> _members;
  _MockMembersNotifier(this._members);
  @override
  Future<List<Member>> build() async => _members;
}

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  final testMember = Member(
    id: 'm-card-test-1',
    name: '김민준',
    phone: '010-1234-5678',
    groupName: 'A반',
    billingType: BillingType.monthlyRecurring,
    defaultFee: 150000,
    totalSessions: 10,
    remainingSessions: 8,
    registeredAt: DateTime(2026, 1, 1),
  );

  final testInvoice = Invoice(
    id: 'inv-card-test-1',
    memberIds: ['m-card-test-1'],
    recipientPhone: '010-1234-5678',
    title: '4월 정기 수강료',
    amount: 150000,
    dueDate: DateTime(2026, 4, 25),
    status: PaymentStatus.unpaid,
  );

  final studioWithCard = StudioProfile(
    studioName: '마인드핏 아카데미',
    instructorName: '김서연 원장',
    bankName: '토스뱅크',
    accountNumber: '1000-2026-8899',
    accountHolder: '김서연',
    category: '피트니스 / PT',
    autoBankDetectEnabled: true,
    invoiceTemplate: '''[#{상호명}] #{청구제목}
금액: #{금액}원
계좌: #{계좌정보}
토스: #{토스송금링크}
카드: #{카드결제링크}''',
    attendanceTemplate: StudioProfile.defaultAttendanceTemplate,
    departureTemplate: StudioProfile.defaultDepartureTemplate,
    cardPaymentUrl: 'https://pay.toss.im/_m/cardpay?amt={금액}&name={회원명}',
    cardPaymentEnabled: true,
  );

  final studioWithoutCard = studioWithCard.copyWith(
    cardPaymentEnabled: false,
    cardPaymentUrl: '',
  );

  group('1. StudioProfile Card Payment URL Model Tests', () {
    test('Serializes and deserializes cardPaymentUrl and cardPaymentEnabled correctly', () {
      final map = studioWithCard.toMap();
      expect(map['cardPaymentUrl'], 'https://pay.toss.im/_m/cardpay?amt={금액}&name={회원명}');
      expect(map['cardPaymentEnabled'], 1);

      final reconstructed = StudioProfile.fromMap(map);
      expect(reconstructed.cardPaymentUrl, studioWithCard.cardPaymentUrl);
      expect(reconstructed.cardPaymentEnabled, isTrue);
    });

    test('getFormattedCardPaymentUrl formats placeholders accurately when enabled', () {
      final url = studioWithCard.getFormattedCardPaymentUrl(
        amount: 150000,
        orderTitle: '4월 정기 수강료',
        customerName: '김민준',
      );
      expect(url, 'https://pay.toss.im/_m/cardpay?amt=150000&name=%EA%B9%80%EB%AF%BC%EC%A4%80');
    });

    test('getFormattedCardPaymentUrl returns empty string when disabled', () {
      final url = studioWithoutCard.getFormattedCardPaymentUrl(
        amount: 150000,
        orderTitle: '4월 정기 수강료',
        customerName: '김민준',
      );
      expect(url, isEmpty);
    });
  });

  group('2. SmsTemplateService & KakaoShareService Remote Card Integration Tests', () {
    test('SmsTemplateService replaces #{카드결제링크} when card payment is enabled', () {
      final msg = SmsTemplateService.generateInvoiceMessage(
        studio: studioWithCard,
        members: [testMember],
        invoice: testInvoice,
      );
      expect(msg, contains('카드: https://pay.toss.im/_m/cardpay?amt=150000'));
    });

    test('SmsTemplateService cleanly removes card payment tag when disabled', () {
      final msg = SmsTemplateService.generateInvoiceMessage(
        studio: studioWithoutCard,
        members: [testMember],
        invoice: testInvoice,
      );
      expect(msg, isNot(contains('https://pay.toss.im')));
      expect(msg, isNot(contains('#{카드결제링크}')));
    });

    test('SmsTemplateService generatePaymentReceiptMessage formats ONLINE_CARD properly', () {
      final msg = SmsTemplateService.generatePaymentReceiptMessage(
        studio: studioWithCard,
        member: testMember,
        amount: 150000,
        paymentMethod: 'ONLINE_CARD',
      );
      expect(msg, contains('비대면 신용카드(원격)'));
    });

    test('KakaoShareService generateInvoiceKakaoMessage includes card payment block when enabled', () {
      final kakao = KakaoShareService.generateInvoiceKakaoMessage(
        studio: studioWithCard,
        members: [testMember],
        invoice: testInvoice,
      );
      expect(kakao, contains('💳 [비대면 카드 결제]'));
      expect(kakao, contains('https://pay.toss.im/_m/cardpay?amt=150000'));
    });

    test('KakaoShareService generateInvoiceKakaoMessage omits card payment block when disabled', () {
      final kakao = KakaoShareService.generateInvoiceKakaoMessage(
        studio: studioWithoutCard,
        members: [testMember],
        invoice: testInvoice,
      );
      expect(kakao, isNot(contains('💳 [비대면 카드 결제]')));
    });

    test('KakaoShareService generateReceiptKakaoMessage formats ONLINE_CARD properly', () {
      final paidInvoice = testInvoice.copyWith(
        status: PaymentStatus.paid,
        paymentMethod: 'ONLINE_CARD',
        paidAt: DateTime(2026, 4, 20),
      );
      final receipt = KakaoShareService.generateReceiptKakaoMessage(
        studio: studioWithCard,
        member: testMember,
        invoice: paidInvoice,
      );
      expect(receipt, contains('비대면 신용카드(원격)'));
    });
  });

  group('3. SequentialDispatchService Remote Card Link Tests', () {
    test('renderMessage correctly replaces #{카드결제링크} in bulk dispatch', () {
      final template = '수납 안내: #{회원명} 회원님 #{금액} / 카드결제: #{카드결제링크}';
      final rendered = SequentialDispatchService.renderMessage(
        template: template,
        studio: studioWithCard,
        member: testMember,
        invoice: testInvoice,
      );
      expect(rendered, contains('카드결제: https://pay.toss.im/_m/cardpay?amt=150000'));
    });
  });

  group('4. SettingsVaultScreen & BillingLedgerScreen UI Tests', () {
    testWidgets('SettingsVaultScreen displays remote card payment section and switches state', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(studioWithCard)),
          ],
          child: const MaterialApp(
            home: SettingsVaultScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check Section Title and Badge
      expect(find.text('비대면 신용카드 결제 링크 (0원 연동)'), findsOneWidget);
      expect(find.text('가입비 0원 · 월관리비 0원'), findsOneWidget);
      expect(find.text('결제 링크 설정'), findsOneWidget);
      expect(find.text('링크 테스트'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('BillingLedgerScreen payment confirmation sheet displays remote card payment option', (tester) async {
      await tester.binding.setSurfaceSize(const Size(800, 1200));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(studioWithCard)),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier([testInvoice])),
            membersProvider.overrideWith(() => _MockMembersNotifier([testMember])),
          ],
          child: const MaterialApp(
            home: BillingLedgerScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the card link badge on the invoice card
      expect(find.text('카드링크 연동'), findsOneWidget);

      // Tap '수납확인 완료 처리' button on invoice card
      final payBtn = find.text('수납확인 완료 처리');
      expect(payBtn, findsOneWidget);
      await tester.tap(payBtn);
      await tester.pumpAndSettle();

      // Verify that '비대면 신용카드 결제 (원격 결제 링크)' choice is visible in bottom sheet
      expect(find.text('비대면 신용카드 결제 (원격 결제 링크)'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
