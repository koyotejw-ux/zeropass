import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/models/vendor.dart';
import 'package:zeropass/models/expense_item.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/services/kakao_share_service.dart';

class MockMembersNotifier extends MembersNotifier {
  @override
  Future<List<Member>> build() async => [
        Member(
          id: 'mem_test_1',
          name: '김태리 (중등 영어)',
          phone: '010-1234-5678',
          groupName: '중등영어',
          billingType: BillingType.monthlyRecurring,
          defaultFee: 200000,
          totalSessions: 0,
          remainingSessions: 0,
          registeredAt: DateTime(2026, 1, 1),
        ),
      ];
}

class MockInvoicesNotifier extends InvoicesNotifier {
  @override
  Future<List<Invoice>> build() async => [
        Invoice(
          id: 'inv_test_1',
          memberIds: ['mem_test_1'],
          recipientPhone: '010-1234-5678',
          title: '5월 수강료',
          amount: 200000,
          dueDate: DateTime(2026, 5, 25),
          status: PaymentStatus.unpaid,
        ),
        Invoice(
          id: 'inv_test_2',
          memberIds: ['mem_test_1'],
          recipientPhone: '010-1234-5678',
          title: '4월 수강료',
          amount: 200000,
          dueDate: DateTime(2026, 4, 25),
          status: PaymentStatus.paid,
          paymentMethod: 'TRANSFER',
          paidAt: DateTime(2026, 4, 24),
        ),
      ];
}

class MockVendorsNotifier extends VendorsNotifier {
  @override
  Future<List<Vendor>> build() async => [
        Vendor(
          id: 'vnd_mock_1',
          name: '(주)알파교재',
          category: '교재/교구',
          bankName: '국민은행',
          accountNumber: '123-456-7890',
          accountHolder: '알파교재',
          phone: '010-9999-8888',
          memo: '정기 워크북 발주처',
          createdAt: DateTime(2026, 1, 1),
        ),
        Vendor(
          id: 'vnd_mock_2',
          name: '박코치',
          category: '강사/코치료',
          bankName: '카카오뱅크',
          accountNumber: '3333-00-1111',
          accountHolder: '박코치',
          phone: '010-7777-6666',
          createdAt: DateTime(2026, 1, 1),
        ),
      ];
}

class MockExpensesNotifier extends ExpensesNotifier {
  @override
  Future<List<ExpenseItem>> build() async => [
        ExpenseItem(
          id: 'exp_mock_1',
          vendorId: 'vnd_mock_1',
          vendorName: '(주)알파교재',
          title: '5월 워크북 20부',
          amount: 150000,
          date: DateTime(2026, 5, 10),
          category: '교재비',
          paymentMethod: '계좌이체',
          isPaid: true,
          createdAt: DateTime(2026, 5, 10),
        ),
        ExpenseItem(
          id: 'exp_mock_2',
          vendorId: 'vnd_mock_2',
          vendorName: '박코치',
          title: '4월 수업 정산',
          amount: 300000,
          date: DateTime(2026, 5, 15),
          category: '강사료',
          paymentMethod: '계좌이체',
          isPaid: false,
          createdAt: DateTime(2026, 5, 15),
        ),
      ];
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
    SharedPreferences.setMockInitialValues({});
  });

  group('Vendor and ExpenseItem Models Tests', () {
    test('Vendor serialization, deserialization, and copyWith', () {
      final vendor = Vendor(
        id: 'vnd_test_1',
        name: '태권도 매트 총판',
        category: '시설/기구',
        bankName: '신한은행',
        accountNumber: '110-123-456789',
        accountHolder: '홍길동',
        phone: '010-1234-5678',
        memo: '안전 매트 교체 건',
        createdAt: DateTime(2026, 3, 1),
      );

      final map = vendor.toMap();
      final revived = Vendor.fromMap(map);

      expect(revived.id, equals('vnd_test_1'));
      expect(revived.name, equals('태권도 매트 총판'));
      expect(revived.category, equals('시설/기구'));
      expect(revived.bankName, equals('신한은행'));
      expect(revived.accountNumber, equals('110-123-456789'));
      expect(revived.accountHolder, equals('홍길동'));
      expect(revived.phone, equals('010-1234-5678'));
      expect(revived.memo, equals('안전 매트 교체 건'));

      final updated = vendor.copyWith(name: '프리미엄 매트 총판');
      expect(updated.name, equals('프리미엄 매트 총판'));
      expect(updated.id, equals('vnd_test_1'));
    });

    test('ExpenseItem serialization, deserialization, and togglePaymentStatus', () {
      final expense = ExpenseItem(
        id: 'exp_test_1',
        vendorId: 'vnd_test_1',
        vendorName: '태권도 매트 총판',
        title: '친환경 코트 매트 10장',
        amount: 450000,
        date: DateTime(2026, 5, 2),
        category: '시설관리',
        paymentMethod: '계좌이체',
        isPaid: false,
        memo: '설치 완료 후 송금 예정',
        createdAt: DateTime(2026, 5, 2),
      );

      final map = expense.toMap();
      final revived = ExpenseItem.fromMap(map);

      expect(revived.id, equals('exp_test_1'));
      expect(revived.vendorName, equals('태권도 매트 총판'));
      expect(revived.title, equals('친환경 코트 매트 10장'));
      expect(revived.amount, equals(450000));
      expect(revived.category, equals('시설관리'));
      expect(revived.isPaid, isFalse);

      final toggled = expense.copyWith(isPaid: true);
      expect(toggled.isPaid, isTrue);
    });
  });

  group('KakaoShareService Format & Message Generation Tests', () {
    final studio = StudioProfile.defaultProfile().copyWith(
      studioName: '위너스 아카데미',
      instructorName: '이원장',
      bankName: '국민은행',
      accountNumber: '987-654-3210',
      accountHolder: '위너스',
    );

    final member = Member(
      id: 'mem_1',
      name: '이민호 (피아노)',
      phone: '010-5555-4444',
      groupName: '피아노',
      billingType: BillingType.monthlyRecurring,
      defaultFee: 180000,
      totalSessions: 0,
      remainingSessions: 0,
      registeredAt: DateTime(2026, 1, 1),
    );

    final invoice = Invoice(
      id: 'inv_1',
      memberIds: ['mem_1'],
      recipientPhone: '010-5555-4444',
      title: '5월 정기 수강료',
      amount: 180000,
      dueDate: DateTime(2026, 5, 25),
      status: PaymentStatus.unpaid,
    );

    test('generateInvoiceKakaoMessage contains studio name, toss link, and formatted amount', () {
      final msg = KakaoShareService.generateInvoiceKakaoMessage(
        studio: studio,
        members: [member],
        invoice: invoice,
      );

      expect(msg.contains('위너스 아카데미'), isTrue);
      expect(msg.contains('180,000원'), isTrue);
      expect(msg.contains('이민호'), isTrue);
      expect(msg.contains('supertoss://send'), isTrue);
      expect(msg.contains('국민은행 987-654-3210'), isTrue);
    });

    test('generateAttendanceKakaoMessage contains check-in time and status', () {
      final msg = KakaoShareService.generateAttendanceKakaoMessage(
        studio: studio,
        member: member,
        time: DateTime(2026, 5, 5, 14, 30),
      );

      expect(msg.contains('이민호 ${studio.memberWord}님이 안전하게 출석'), isTrue);
      expect(msg.contains('14시 30분'), isTrue);
      expect(msg.contains('체크앤페이'), isTrue);
    });

    test('generateDepartureKakaoMessage contains departure time and safe return note', () {
      final msg = KakaoShareService.generateDepartureKakaoMessage(
        studio: studio,
        member: member,
        time: DateTime(2026, 5, 5, 16, 0),
      );

      expect(msg.contains('이민호 ${studio.memberWord}님이 일정을 마치고'), isTrue);
      expect(msg.contains('16시 00분'), isTrue);
    });

    test('generateReceiptKakaoMessage contains paid amount and confirmation', () {
      final paidInvoice = invoice.copyWith(
        status: PaymentStatus.paid,
        paymentMethod: 'TRANSFER',
        paidAt: DateTime(2026, 5, 20, 10, 15),
      );

      final msg = KakaoShareService.generateReceiptKakaoMessage(
        studio: studio,
        member: member,
        invoice: paidInvoice,
      );

      expect(msg.contains('수납 확인 영수증'), isTrue);
      expect(msg.contains('180,000원'), isTrue);
      expect(msg.contains('계좌이체') || msg.contains('TRANSFER'), isTrue);
    });

    test('generateVendorOrderKakaoMessage contains B2B vendor and order details', () {
      final msg = KakaoShareService.generateVendorOrderKakaoMessage(
        studio: studio,
        vendorName: '(주)에듀프라임',
        title: '수학 워크북 30부 발주',
        amount: 250000,
        bankInfo: '국민은행 123-456-7890 (에듀프라임)',
        memo: '빠른 택배 발송 요청',
      );

      expect(msg.contains('(주)에듀프라임'), isTrue);
      expect(msg.contains('수학 워크북 30부 발주'), isTrue);
      expect(msg.contains('250,000원'), isTrue);
      expect(msg.contains('빠른 택배 발송 요청'), isTrue);
    });

    test('generateStaffSettlementKakaoMessage contains instructor settlement statement', () {
      final msg = KakaoShareService.generateStaffSettlementKakaoMessage(
        studio: studio,
        staffName: '박코치',
        amount: 800000,
        period: '5월',
        details: '주말 1:1 레슨 10회 (인센티브 포함)',
      );

      expect(msg.contains('박코치'), isTrue);
      expect(msg.contains('5월 강사료/수당 정산 명세서'), isTrue);
      expect(msg.contains('800,000원'), isTrue);
      expect(msg.contains('주말 1:1 레슨 10회'), isTrue);
    });

    test('generateAppInviteKakaoMessage generates viral referral invitation', () {
      final msg = KakaoShareService.generateAppInviteKakaoMessage(studio: studio);
      expect(msg.contains('체크앤페이'), isTrue);
      expect(msg.contains('100% 무료'), isTrue);
      expect(msg.contains('구글 플레이스토어'), isTrue);
    });
  });

  group('BillingLedgerScreen 3-Tab & Expense Ledger UI Tests', () {
    testWidgets('Renders all 3 tabs: 미납/청구, 수납 완료, 지출/매입', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => MockMembersNotifier()),
            invoicesProvider.overrideWith(() => MockInvoicesNotifier()),
            vendorsProvider.overrideWith(() => MockVendorsNotifier()),
            expensesProvider.overrideWith(() => MockExpensesNotifier()),
          ],
          child: const MaterialApp(
            home: BillingLedgerScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Dismiss first-time coach mark if shown
      if (find.text('장부 둘러보기').evaluate().isNotEmpty) {
        await tester.tap(find.text('장부 둘러보기'));
        await tester.pumpAndSettle();
      }

      // Check the 3 segmented tabs exist
      expect(find.textContaining('미납 / 청구'), findsOneWidget);
      expect(find.textContaining('수납 완료'), findsOneWidget);
      expect(find.textContaining('지출 / 매입'), findsOneWidget);

      // Tab 0 is initially selected: Shows "새 청구서 작성" FAB and Unpaid invoice
      expect(find.text('새 청구서 작성'), findsOneWidget);
      expect(find.text('5월 수강료'), findsOneWidget);
      expect(find.text('카톡 청구서'), findsOneWidget);

      // Switch to Tab 2: "지출 / 매입"
      await tester.tap(find.textContaining('지출 / 매입'));
      await tester.pumpAndSettle();

      // In Tab 2:
      // FAB changes dynamically to "새 지출 등록"
      expect(find.text('새 지출 등록'), findsOneWidget);

      // AppBar shows "거래처 수첩" action icon (pure line icon header)
      expect(find.byTooltip('거래처 수첩'), findsOneWidget);
      expect(find.byIcon(Icons.business_center_outlined), findsOneWidget);

      // Expenses are listed:
      expect(find.text('5월 워크북 20부'), findsOneWidget);
      expect(find.text('4월 수업 정산'), findsOneWidget);

      // B2B Actions exist
      expect(find.text('카톡 발주/입금서'), findsWidgets);
      expect(find.text('강사 정산서'), findsOneWidget);
    });
  });
}
