import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/expense_item.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/models/vendor.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/screens/pass_dashboard_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/services/data_vault_service.dart';
import 'package:zeropass/services/database_service.dart';
import 'package:zeropass/widgets/receipt_notify_dialog.dart';
import 'package:zeropass/widgets/tax_guide_modal.dart';

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

class _MockExpensesNotifier extends ExpensesNotifier {
  final List<ExpenseItem> _expenses;
  _MockExpensesNotifier(this._expenses);
  @override
  Future<List<ExpenseItem>> build() async => _expenses;
}

class _MockVendorsNotifier extends VendorsNotifier {
  final List<Vendor> _vendors;
  _MockVendorsNotifier(this._vendors);
  @override
  Future<List<Vendor>> build() async => _vendors;
}

class _MockPassRecordsNotifier extends PassRecordsNotifier {
  final List<PassRecord> _records;
  _MockPassRecordsNotifier([this._records = const []]);
  @override
  Future<List<PassRecord>> build() async => _records;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('ko_KR', null);
  });

  final testStudioWithLogo = StudioProfile(
    studioName: '마인드핏 아카데미 & PT 스튜디오',
    instructorName: '김서연 대표원장',
    bankName: '토스뱅크',
    accountNumber: '1000-2026-8899-01',
    accountHolder: '김서연',
    category: '피트니스 / PT',
    autoBankDetectEnabled: true,
    invoiceTemplate: StudioProfile.defaultInvoiceTemplate,
    attendanceTemplate: StudioProfile.defaultAttendanceTemplate,
    departureTemplate: StudioProfile.defaultDepartureTemplate,
    cardPaymentUrl: 'https://pay.toss.im/_m/cardpay?amt={금액}&name={회원명}',
    cardPaymentEnabled: true,
    logoPath: 'test_assets/logo.png',
  );

  final testMembers = [
    Member(
      id: 'm-biz-1',
      name: '김민준',
      phone: '010-1234-5678',
      groupName: 'PT 화목 심화반',
      billingType: BillingType.monthlyRecurring,
      defaultFee: 250000,
      totalSessions: 10,
      remainingSessions: 1,
      registeredAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    Member(
      id: 'm-biz-2',
      name: '김민서',
      phone: '010-1234-5678', // Same phone as sibling
      groupName: '필라테스 주말반',
      billingType: BillingType.monthlyRecurring,
      defaultFee: 200000,
      totalSessions: 8,
      remainingSessions: 4,
      registeredAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    Member(
      id: 'm-biz-absent',
      name: '이수진',
      phone: '010-5555-7777',
      groupName: '요가 저녁반',
      billingType: BillingType.sessionBased,
      defaultFee: 180000,
      totalSessions: 10,
      remainingSessions: 8,
      registeredAt: DateTime.now().subtract(const Duration(days: 40)),
    ),
  ];

  final testInvoices = [
    Invoice(
      id: 'inv-biz-1',
      memberIds: ['m-biz-1'],
      recipientPhone: '010-1234-5678',
      title: '2026년 4월 PT 정기 수강료',
      amount: 250000,
      dueDate: DateTime(2026, 4, 25),
      status: PaymentStatus.paid,
      paymentMethod: '계좌이체',
      paidAt: DateTime(2026, 4, 24, 15, 30),
    ),
  ];

  final testExpenses = [
    ExpenseItem(
      id: 'exp-biz-1',
      vendorName: '박준혁 강사',
      title: '4월 PT 전담 강사료 정산',
      amount: 1000000,
      date: DateTime(2026, 4, 30),
      category: '강사료',
      paymentMethod: '계좌이체',
      isPaid: true,
      createdAt: DateTime(2026, 4, 30),
      taxEvidence: '원천징수(3.3%)',
      isWithholdingApplied: true,
      withholdingTax: 33000,
    ),
    ExpenseItem(
      id: 'exp-biz-2',
      vendorName: '에듀북스 총판',
      title: '피트니스 교재 및 워크북 발주',
      amount: 150000,
      date: DateTime(2026, 4, 10),
      category: '교재비',
      paymentMethod: '신용카드',
      isPaid: true,
      createdAt: DateTime(2026, 4, 10),
      taxEvidence: '신용카드',
      isWithholdingApplied: false,
      withholdingTax: 0,
    ),
  ];

  final testVendors = [
    Vendor(
      id: 'ven-biz-1',
      name: '박준혁 강사',
      category: '강사/코치료',
      bankName: '국민은행',
      accountNumber: '110-222-333444',
      accountHolder: '박준혁',
      phone: '010-7777-8888',
      createdAt: DateTime(2026, 1, 1),
    ),
  ];

  group('Priority 1: StudioProfile Logo & Branding Tests', () {
    test('StudioProfile serializes and deserializes logoPath accurately', () {
      final map = testStudioWithLogo.toMap();
      expect(map['logoPath'], 'test_assets/logo.png');

      final reconstructed = StudioProfile.fromMap(map);
      expect(reconstructed.logoPath, 'test_assets/logo.png');
      expect(reconstructed.studioName, '마인드핏 아카데미 & PT 스튜디오');
    });

    test('StudioProfile copyWith clearLogo cleanly resets logoPath to null', () {
      final cleared = testStudioWithLogo.copyWith(clearLogo: true);
      expect(cleared.logoPath, isNull);
      expect(cleared.studioName, testStudioWithLogo.studioName);
    });
  });

  group('Priority 2: ExpenseItem Tax Evidence & 3.3% Withholding Tests', () {
    test('ExpenseItem calculates actualPayoutAmount accurately with 3.3% withholding', () {
      final instructorExpense = testExpenses.first;
      expect(instructorExpense.amount, 1000000);
      expect(instructorExpense.isWithholdingApplied, isTrue);
      expect(instructorExpense.withholdingTax, 33000);
      expect(instructorExpense.actualPayoutAmount, 967000);
      expect(instructorExpense.taxEvidence, '원천징수(3.3%)');
    });

    test('ExpenseItem preserves all tax fields across Map serialization/deserialization', () {
      final exp = testExpenses.first;
      final map = exp.toMap();
      expect(map['taxEvidence'], '원천징수(3.3%)');
      expect(map['isWithholdingApplied'], 1);
      expect(map['withholdingTax'], 33000);

      final restored = ExpenseItem.fromMap(map);
      expect(restored.taxEvidence, '원천징수(3.3%)');
      expect(restored.isWithholdingApplied, isTrue);
      expect(restored.withholdingTax, 33000);
      expect(restored.actualPayoutAmount, 967000);
    });
  });

  group('Priority 2: National Tax Service Simplified Bookkeeping & Vault Tests', () {
    test('DataVaultService exportSimplifiedBookkeepingCsv creates valid CSV file with UTF-8 BOM', () async {
      final db = DatabaseService.instance;
      await db.updateStudioProfile(testStudioWithLogo);
      for (final m in testMembers) {
        await db.insertMember(m);
      }
      for (final inv in testInvoices) {
        await db.insertInvoice(inv);
      }
      for (final exp in testExpenses) {
        await db.insertExpense(exp);
      }

      final file = await DataVaultService.exportSimplifiedBookkeepingCsv();
      expect(file.existsSync(), isTrue);

      final bytes = await file.readAsBytes();
      // Check UTF-8 BOM: 0xEF, 0xBB, 0xBF
      expect(bytes[0], 0xEF);
      expect(bytes[1], 0xBB);
      expect(bytes[2], 0xBF);

      final content = await file.readAsString();
      expect(content, contains('[국세청 표준 사업소득 간편장부]'));
      expect(content, contains('수입(매출)'));
      expect(content, contains('비용(매입/경비)'));
      expect(content, contains('2026년 4월 PT 정기 수강료'));
      expect(content, contains('4월 PT 전담 강사료 정산'));
      expect(content, contains('원천징수(3.3%)'));
      expect(content, contains('[합계]'));
    });

    test('DataVaultService exportEncryptedBackup and restoreFromBackupJson covers vendors & expenses', () async {
      final backupFile = await DataVaultService.exportEncryptedBackup();
      expect(backupFile.existsSync(), isTrue);

      final jsonContent = await backupFile.readAsString();
      expect(jsonContent, contains('vendors'));
      expect(jsonContent, contains('expenses'));

      final restoreSuccess = await DataVaultService.restoreFromBackupJson(jsonContent);
      expect(restoreSuccess, isTrue);
    });
  });

  group('Priority 1, 2, 3: UI Integration Widget Tests', () {
    testWidgets('SettingsVaultScreen displays Studio Logo Header and National Tax Service Export Action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudioWithLogo)),
          ],
          child: const MaterialApp(
            home: SettingsVaultScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('마인드핏 아카데미 & PT 스튜디오'), findsWidgets);
      expect(find.text('로고 적용됨'), findsOneWidget);
      expect(find.text('로고 변경/삭제'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('국세청 사업소득 간편장부 엑셀(CSV) 내보내기'),
        300,
      );
      expect(find.text('국세청 사업소득 간편장부 엑셀(CSV) 내보내기'), findsOneWidget);
    });

    testWidgets('BillingLedgerScreen renders 3.3% Withholding and Tax Evidence badges', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudioWithLogo)),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier(testInvoices)),
            membersProvider.overrideWith(() => _MockMembersNotifier(testMembers)),
            expensesProvider.overrideWith(() => _MockExpensesNotifier(testExpenses)),
            vendorsProvider.overrideWith(() => _MockVendorsNotifier(testVendors)),
          ],
          child: const MaterialApp(
            home: BillingLedgerScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Tab 2: '지출 / 매입 (2)'
      await tester.tap(find.text('지출 / 매입 (2)'));
      await tester.pumpAndSettle();

      expect(find.text('4월 PT 전담 강사료 정산'), findsOneWidget);
      expect(find.text('원천징수(3.3%)'), findsOneWidget);
      expect(find.textContaining('원천징수 3.3%'), findsOneWidget);
      expect(find.textContaining('실수령 967,000원'), findsOneWidget);
    });

    testWidgets('ReceiptNotifyDialog renders Cash Receipt Phone Copy and HomeTax Launcher', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptNotifyDialog(
              member: testMembers.first,
              invoice: testInvoices.first,
              studio: testStudioWithLogo,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('현금영수증 발급 지원'), findsOneWidget);
      expect(find.text('번호 복사'), findsOneWidget);
      expect(find.text('홈택스 열기'), findsOneWidget);
    });

    testWidgets('PassDashboardScreen renders Golden-Time Care Banner for Absent Members', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      // Only member 1 has a today record, member 2 and absent member have no records
      final oldRecords = [
        PassRecord(
          id: 'rec-old-1',
          memberId: 'm-biz-1',
          timestamp: DateTime.now(),
          status: AttendanceStatus.attended,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudioWithLogo)),
            membersProvider.overrideWith(() => _MockMembersNotifier(testMembers)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier(oldRecords)),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier(testInvoices)),
          ],
          child: const MaterialApp(
            home: PassDashboardScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.textContaining('장기 미출석 안심 케어'), findsOneWidget);
      expect(find.text('보기'), findsOneWidget);
    });

    testWidgets('TaxGuideModal renders and displays schedules and HomeTax quick action', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TaxGuideModal(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('국세청 간편장부 & 세무 꿀팁'), findsOneWidget);
      expect(find.text('소상공인 원장님을 위한 1분 세무 마스터 가이드'), findsOneWidget);
      expect(find.text('국세청 표준 사업소득 간편장부란?'), findsOneWidget);
      expect(find.text('간편장부 작성 시 원장님 3대 혜택'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('종합소득세 확정 신고 (모든 개인사업자 필수)'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('종합소득세 확정 신고 (모든 개인사업자 필수)'), findsOneWidget);
      expect(find.text('국세청 홈택스 바로가기'), findsOneWidget);
    });

    testWidgets('PassDashboardScreen opens Golden-Time Care Sheet and displays situation presets', (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final oldRecords = [
        PassRecord(
          id: 'rec-old-1',
          memberId: 'm-biz-1',
          timestamp: DateTime.now(),
          status: AttendanceStatus.attended,
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudioWithLogo)),
            membersProvider.overrideWith(() => _MockMembersNotifier(testMembers)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier(oldRecords)),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier(testInvoices)),
          ],
          child: const MaterialApp(
            home: PassDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on Golden-Time Care Button
      final careButton = find.text('최근 7일+ 미출석 • 따뜻한 안부 톡 보내기').first;
      await tester.scrollUntilVisible(careButton, 150, scrollable: find.byType(Scrollable).first);
      await tester.tap(careButton);
      await tester.pumpAndSettle();

      // Verify Golden-Time Care Sheet elements
      expect(find.text('골든타임 안심 케어'), findsOneWidget);
      expect(find.text('상황별 안부 메시지 템플릿 선택'), findsOneWidget);
      expect(find.text('🌸 따뜻한 안부'), findsOneWidget);
      expect(find.text('🧘 복귀 & 스케줄'), findsOneWidget);
      expect(find.text('📚 학업/시험 격려'), findsOneWidget);
      expect(find.text('🏃 운동/수업 재개'), findsOneWidget);
      expect(find.text('문자(SMS) 전송'), findsOneWidget);
      expect(find.text('카카오톡 안부 톡'), findsOneWidget);
    });
  });
}

