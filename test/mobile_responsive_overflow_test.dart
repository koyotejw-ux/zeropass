import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/notification_log.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/screens/pass_dashboard_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/widgets/attendance_notify_dialog.dart';
import 'package:zeropass/widgets/receipt_notify_dialog.dart';
import 'package:zeropass/widgets/smart_notification_center_modal.dart';

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

class _MockPassRecordsNotifier extends PassRecordsNotifier {
  @override
  Future<List<PassRecord>> build() async => [];
}

class _MockNotificationLogsNotifier extends NotificationLogsNotifier {
  final List<NotificationLog> _logs;
  _MockNotificationLogsNotifier(this._logs);
  @override
  Future<List<NotificationLog>> build() async => _logs;
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('ko_KR', null);
  });

  final testStudio = StudioProfile(
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
  );

  final testMembers = [
    Member(
      id: 'm-overflow-1',
      name: '김민준학생',
      phone: '010-1234-5678',
      groupName: 'PT 화목 심화반',
      billingType: BillingType.monthlyRecurring,
      defaultFee: 250000,
      totalSessions: 10,
      remainingSessions: 1,
      registeredAt: DateTime(2026, 1, 1),
    ),
    Member(
      id: 'm-overflow-2',
      name: '이서연수강생',
      phone: '010-9876-5432',
      groupName: '필라테스 주말반',
      billingType: BillingType.sessionBased,
      defaultFee: 180000,
      totalSessions: 8,
      remainingSessions: 0,
      registeredAt: DateTime(2026, 2, 1),
    ),
  ];

  final testInvoices = [
    Invoice(
      id: 'inv-overflow-1',
      memberIds: ['m-overflow-1'],
      recipientPhone: '010-1234-5678',
      title: '2026년 4월 정기 수강료 및 교재비 합산 청구',
      amount: 250000,
      dueDate: DateTime(2026, 4, 25),
      status: PaymentStatus.unpaid,
    ),
  ];

  final testLogs = [
    NotificationLog(
      id: 'log-overflow-1',
      type: NotificationType.attendance,
      memberId: 'm-overflow-1',
      memberName: '김민준학생',
      recipientPhone: '010-1234-5678',
      channel: 'KAKAO',
      message: '[마인드핏 아카데미 & PT 스튜디오] 김민준 학생 출석 확인 완료되었습니다.',
      sentAt: DateTime.now(),
      isSuccess: true,
    ),
  ];

  const narrowMobileSizes = [
    Size(320, 600), // Ultra-compact 320px
    Size(360, 720), // Standard 360px
    Size(390, 844), // iPhone 390px
  ];

  group('Mobile-First Zero-Overflow Resilience Tests', () {
    testWidgets('BillingLedgerScreen renders with 0 overflow on 320px & 360px mobile viewports', (tester) async {
      for (final size in narrowMobileSizes) {
        await tester.binding.setSurfaceSize(size);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudio)),
              invoicesProvider.overrideWith(() => _MockInvoicesNotifier(testInvoices)),
              membersProvider.overrideWith(() => _MockMembersNotifier(testMembers)),
            ],
            child: const MaterialApp(
              home: BillingLedgerScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify elements rendered without RenderFlex overflow
        expect(find.text('카드링크 연동'), findsOneWidget);
        expect(find.text('2026년 4월 정기 수강료 및 교재비 합산 청구'), findsOneWidget);
        expect(find.text('카톡 청구'), findsOneWidget);
        expect(find.text('문자 청구'), findsOneWidget);
        expect(find.text('1초 리마인드'), findsOneWidget);
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('SettingsVaultScreen renders with 0 overflow on 320px & 360px mobile viewports', (tester) async {
      for (final size in narrowMobileSizes) {
        await tester.binding.setSurfaceSize(size);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudio)),
            ],
            child: const MaterialApp(
              home: SettingsVaultScreen(),
            ),
          ),
        );

        await tester.pumpAndSettle();

        expect(find.text('설정 · 보안 금고'), findsOneWidget);
        expect(find.text('상호 / 브랜드명'), findsOneWidget);
        expect(find.text('김서연 대표원장'), findsOneWidget);

        // Cleanly reset widget tree for next viewport size
        await tester.pumpWidget(const SizedBox());
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('PassDashboardScreen renders with 0 overflow on 320px & 360px mobile viewports', (tester) async {
      for (final size in narrowMobileSizes) {
        await tester.binding.setSurfaceSize(size);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudio)),
              membersProvider.overrideWith(() => _MockMembersNotifier(testMembers)),
              passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier()),
              invoicesProvider.overrideWith(() => _MockInvoicesNotifier(testInvoices)),
            ],
            child: const MaterialApp(
              home: PassDashboardScreen(),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        expect(find.text('김민준학생'), findsOneWidget);
        expect(find.text('체크인'), findsNWidgets(2));
      }
      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('SmartNotificationCenterModal renders with 0 overflow on 320px viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudio)),
            membersProvider.overrideWith(() => _MockMembersNotifier(testMembers)),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier(testInvoices)),
            notificationLogsProvider.overrideWith(() => _MockNotificationLogsNotifier(testLogs)),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: SmartNotificationCenterModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('스마트 안심 알림 센터'), findsOneWidget);
      expect(find.text('등·하원 안심 알림 & 수납 독촉 릴레이 허브'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('ReceiptNotifyDialog renders with 0 overflow on 320px viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ReceiptNotifyDialog(
              member: testMembers.first,
              invoice: testInvoices.first,
              studio: testStudio,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('수납 완료 영수증 알림장'), findsOneWidget);
      expect(find.text('카톡 영수증 0원 전송'), findsOneWidget);
      expect(find.text('문자(SMS) 전송'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });

    testWidgets('AttendanceNotifyDialog renders with 0 overflow on 320px viewport', (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 600));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceNotifyDialog(
              member: testMembers.first,
              studio: testStudio,
              type: AttendanceNotifyType.checkIn,
              time: DateTime(2026, 4, 15, 14, 30),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('안심 등원 알림장 발송'), findsOneWidget);
      expect(find.text('카톡 0원 전송'), findsOneWidget);
      expect(find.text('문자(SMS) 전송'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    });
  });
}
