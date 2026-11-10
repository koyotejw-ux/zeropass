import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/notification_log.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/services/database_service.dart';
import 'package:zeropass/widgets/attendance_notify_dialog.dart';
import 'package:zeropass/widgets/receipt_notify_dialog.dart';
import 'package:zeropass/widgets/smart_notification_center_modal.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    DatabaseService.testDatabasePath = inMemoryDatabasePath;
    await DatabaseService.instance.resetForTesting();
    await DatabaseService.instance.database;
  });

  tearDownAll(() async {
    await DatabaseService.instance.resetForTesting();
    DatabaseService.testDatabasePath = null;
  });

  final testMember = Member(
    id: 'mem_notif_1',
    name: '강하늘 (피아노 초급)',
    phone: '010-9876-5432',
    groupName: '피아노초급',
    billingType: BillingType.sessionBased,
    defaultFee: 180000,
    totalSessions: 10,
    remainingSessions: 1, // 만료 임박
    registeredAt: DateTime(2026, 3, 1),
  );

  final testStudio = StudioProfile(
    studioName: '하늘 음악학원',
    instructorName: '하늘원장',
    bankName: '국민은행',
    accountNumber: '123-456-7890',
    accountHolder: '하늘원장',
    category: '음악 / 피아노',
    autoBankDetectEnabled: true,
    invoiceTemplate: StudioProfile.defaultInvoiceTemplate,
    attendanceTemplate: StudioProfile.defaultAttendanceTemplate,
    departureTemplate: StudioProfile.defaultDepartureTemplate,
  );

  final testInvoice = Invoice(
    id: 'inv_notif_1',
    memberIds: ['mem_notif_1'],
    recipientPhone: '010-9876-5432',
    title: '5월 수강료',
    amount: 180000,
    dueDate: DateTime(2026, 5, 20),
    status: PaymentStatus.unpaid,
  );

  group('NotificationLog Model & Type Tests', () {
    test('NotificationLog serialization, deserialization and type labels', () {
      final log = NotificationLog(
        id: 'notif_test_1',
        type: NotificationType.attendance,
        memberId: 'mem_1',
        memberName: '홍길동',
        recipientPhone: '010-1111-2222',
        channel: 'KAKAO',
        message: '홍길동 학생이 안전하게 출석하였습니다.',
        sentAt: DateTime(2026, 5, 5, 14, 30),
        isSuccess: true,
      );

      expect(log.typeLabel, equals('등원 안심 알림'));
      final map = log.toMap();
      expect(map['channel'], equals('KAKAO'));
      expect(map['type'], equals('attendance'));

      final fromMap = NotificationLog.fromMap(map);
      expect(fromMap.id, equals('notif_test_1'));
      expect(fromMap.memberName, equals('홍길동'));
      expect(fromMap.type, equals(NotificationType.attendance));
      expect(fromMap.isSuccess, isTrue);

      // Other type labels
      final now = DateTime(2026, 1, 1);
      expect(NotificationLog(id: '2', type: NotificationType.departure, memberName: '', recipientPhone: '', channel: '', message: '', sentAt: now).typeLabel, equals('하원 귀가 알림'));
      expect(NotificationLog(id: '3', type: NotificationType.receipt, memberName: '', recipientPhone: '', channel: '', message: '', sentAt: now).typeLabel, equals('수납 영수증'));
      expect(NotificationLog(id: '4', type: NotificationType.sessionExpiry, memberName: '', recipientPhone: '', channel: '', message: '', sentAt: now).typeLabel, equals('수강권 재등록 안내'));
    });
  });

  group('DatabaseService Notification Logs CRUD Tests', () {
    test('insertNotificationLog, getNotificationLogs, and deleteNotificationLog', () async {
      final db = DatabaseService.instance;
      final logA = NotificationLog(
        id: 'log_crud_1',
        type: NotificationType.attendance,
        memberId: 'mem_crud_a',
        memberName: '이수현',
        recipientPhone: '010-2222-3333',
        channel: 'SMS',
        message: '등원 확인 메시지',
        sentAt: DateTime.now(),
      );

      final logB = NotificationLog(
        id: 'log_crud_2',
        type: NotificationType.receipt,
        memberId: 'mem_crud_b',
        memberName: '박지민',
        recipientPhone: '010-4444-5555',
        channel: 'KAKAO',
        message: '수납 영수증 메시지',
        sentAt: DateTime.now(),
      );

      await db.insertNotificationLog(logA);
      await db.insertNotificationLog(logB);

      final allLogs = await db.getNotificationLogs();
      expect(allLogs.any((l) => l.id == 'log_crud_1'), isTrue);
      expect(allLogs.any((l) => l.id == 'log_crud_2'), isTrue);

      final memberALogs = await db.getNotificationLogs(memberId: 'mem_crud_a');
      expect(memberALogs.length, equals(1));
      expect(memberALogs.first.memberName, equals('이수현'));

      final receiptLogs = await db.getNotificationLogs(type: NotificationType.receipt);
      expect(receiptLogs.any((l) => l.id == 'log_crud_2'), isTrue);

      await db.deleteNotificationLog('log_crud_1');
      final afterDelete = await db.getNotificationLogs(memberId: 'mem_crud_a');
      expect(afterDelete.isEmpty, isTrue);
    });
  });

  group('AttendanceNotifyDialog Widget Tests', () {
    testWidgets('Renders CheckIn Dialog, edits text, and sends via Kakao and SMS', (tester) async {
      bool kakaoSent = false;
      bool smsSent = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AttendanceNotifyDialog.show(
                    context: ctx,
                    member: testMember,
                    studio: testStudio,
                    type: AttendanceNotifyType.checkIn,
                    onShareKakao: (txt, subj) async {
                      kakaoSent = true;
                      return true;
                    },
                    onSendSms: (phone, body) async {
                      smsSent = true;
                      return true;
                    },
                  );
                },
                child: const Text('등원 다이얼로그 열기'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('등원 다이얼로그 열기'));
      await tester.pumpAndSettle();

      expect(find.text('안심 등원 알림장 발송'), findsOneWidget);
      expect(find.textContaining('강하늘 (피아노 초급)'), findsOneWidget);
      expect(find.text('카톡 0원 전송'), findsOneWidget);
      expect(find.text('문자(SMS) 전송'), findsOneWidget);

      // Tap Kakao send
      await tester.tap(find.text('카톡 0원 전송'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(kakaoSent, isTrue);
      expect(smsSent, isFalse);
      await tester.pump(const Duration(seconds: 5));
    });

    testWidgets('Renders CheckOut Dialog and sends via SMS', (tester) async {
      bool smsSent = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  AttendanceNotifyDialog.show(
                    context: ctx,
                    member: testMember,
                    studio: testStudio,
                    type: AttendanceNotifyType.checkOut,
                    onSendSms: (phone, body) async {
                      smsSent = true;
                      return true;
                    },
                  );
                },
                child: const Text('하원 다이얼로그 열기'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('하원 다이얼로그 열기'));
      await tester.pumpAndSettle();

      expect(find.text('안심 하원 알림장 발송'), findsOneWidget);

      await tester.tap(find.text('문자(SMS) 전송'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(smsSent, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('ReceiptNotifyDialog Widget Tests', () {
    testWidgets('Renders Receipt Dialog and sends via Kakao', (tester) async {
      bool kakaoSent = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  ReceiptNotifyDialog.show(
                    context: ctx,
                    member: testMember,
                    invoice: testInvoice,
                    studio: testStudio,
                    onShareKakao: (txt, subj) async {
                      kakaoSent = true;
                      return true;
                    },
                  );
                },
                child: const Text('영수증 다이얼로그 열기'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('영수증 다이얼로그 열기'));
      await tester.pumpAndSettle();

      expect(find.text('수납 완료 영수증 알림장'), findsOneWidget);
      expect(find.textContaining('180,000원'), findsNWidgets(2));

      await tester.tap(find.text('카톡 영수증 0원 전송'));
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
      await tester.pumpAndSettle();
      expect(kakaoSent, isTrue);
      await tester.pump(const Duration(seconds: 5));
    });
  });

  group('SmartNotificationCenterModal Tests', () {
    testWidgets('Renders 3 Tabs (Smart Briefing, Log History, Templates)', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => _MockMembersNotifier([testMember])),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier([testInvoice])),
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudio)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier([
                  PassRecord(
                    id: 'rec_today_1',
                    memberId: testMember.id,
                    timestamp: DateTime.now(),
                    status: AttendanceStatus.attended,
                  ),
                ])),
            notificationLogsProvider.overrideWith(() => _MockNotificationLogsNotifier([])),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => ElevatedButton(
                  onPressed: () => SmartNotificationCenterModal.show(ctx),
                  child: const Text('알림 센터 열기'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('알림 센터 열기'));
      await tester.pumpAndSettle();

      // Check Header & Tab 1
      expect(find.text('스마트 안심 알림 센터'), findsOneWidget);
      expect(find.text('실시간 브리핑'), findsOneWidget);
      expect(find.text('오늘 등원 안심 알림 대기'), findsOneWidget);
      expect(find.text('미납 수강료 수납 독촉 대기'), findsOneWidget);
      expect(find.text('수강권 만료 임박 (잔여 2회 이하)'), findsOneWidget);

      // Switch to Tab 2: Logs
      await tester.tap(find.textContaining('발송 이력'));
      await tester.pumpAndSettle();
      expect(find.textContaining('전체 보기'), findsOneWidget);
      expect(find.text('아직 발송된 알림 내역이 없습니다.'), findsOneWidget);

      // Switch to Tab 3: Templates
      await tester.tap(find.text('알림 템플릿'));
      await tester.pumpAndSettle();
      expect(find.text('알림장 문구 즉시 수정'), findsOneWidget);
      expect(find.text('안심 등원 알림 템플릿'), findsOneWidget);
      expect(find.text('안심 하원 알림 템플릿'), findsOneWidget);
      expect(find.text('알림 템플릿 변경사항 저장하기'), findsOneWidget);
    });
  });
}

class _MockMembersNotifier extends MembersNotifier {
  final List<Member> _members;
  _MockMembersNotifier(this._members);
  @override
  Future<List<Member>> build() async => _members;
}

class _MockInvoicesNotifier extends InvoicesNotifier {
  final List<Invoice> _invoices;
  _MockInvoicesNotifier(this._invoices);
  @override
  Future<List<Invoice>> build() async => _invoices;
}

class _MockStudioNotifier extends StudioProfileNotifier {
  final StudioProfile _studio;
  _MockStudioNotifier(this._studio);
  @override
  Future<StudioProfile> build() async => _studio;
}

class _MockPassRecordsNotifier extends PassRecordsNotifier {
  final List<PassRecord> _records;
  _MockPassRecordsNotifier(this._records);
  @override
  Future<List<PassRecord>> build() async => _records;
}

class _MockNotificationLogsNotifier extends NotificationLogsNotifier {
  final List<NotificationLog> _logs;
  _MockNotificationLogsNotifier(this._logs);
  @override
  Future<List<NotificationLog>> build() async => _logs;
}
