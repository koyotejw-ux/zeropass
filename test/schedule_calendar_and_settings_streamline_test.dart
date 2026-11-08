import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/schedule_item.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/services/schedule_service.dart';
import 'package:zeropass/widgets/schedule_calendar_modal.dart';

class _MockStudioNotifier extends StudioProfileNotifier {
  final StudioProfile _studio;
  _MockStudioNotifier(this._studio);
  @override
  Future<StudioProfile> build() async => _studio;
}

class _MockPassRecordsNotifier extends PassRecordsNotifier {
  @override
  Future<List<PassRecord>> build() async => [
        PassRecord(
          id: 'pass_rec_1',
          memberId: 'mem_1',
          status: AttendanceStatus.attended,
          timestamp: DateTime(2026, 4, 15, 14, 30),
        ),
      ];
}

class _MockInvoicesNotifier extends InvoicesNotifier {
  @override
  Future<List<Invoice>> build() async => [
        Invoice(
          id: 'inv_cal_1',
          memberIds: ['mem_1'],
          recipientPhone: '010-1111-2222',
          title: '4월 정기 수강료',
          amount: 220000,
          dueDate: DateTime(2026, 4, 25),
          status: PaymentStatus.unpaid,
        ),
      ];
}

class _MockMembersNotifier extends MembersNotifier {
  @override
  Future<List<Member>> build() async => [
        Member(
          id: 'mem_1',
          name: '최하은',
          phone: '010-1111-2222',
          groupName: '피아노 영재반',
          billingType: BillingType.monthlyRecurring,
          defaultFee: 220000,
          totalSessions: 1,
          remainingSessions: 1,
          registeredAt: DateTime(2026, 1, 1),
        ),
      ];
}

void main() {
  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('ko_KR', null);
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  final testStudio = StudioProfile(
    studioName: '모차르트 클래식 음악원',
    instructorName: '조성진 원장',
    bankName: '신한은행',
    accountNumber: '110-123-456789',
    accountHolder: '조성진',
    category: '음악 / 피아노',
    autoBankDetectEnabled: true,
    invoiceTemplate: StudioProfile.defaultInvoiceTemplate,
    attendanceTemplate: StudioProfile.defaultAttendanceTemplate,
    departureTemplate: StudioProfile.defaultDepartureTemplate,
  );

  group('ScheduleItem Model & ScheduleService Tests', () {
    test('ScheduleItem serialization and copyWith works seamlessly', () {
      final now = DateTime(2026, 4, 10, 10, 0);
      final item = ScheduleItem(
        id: 'sched_test_1',
        title: '정기 수강료 정산 마감일',
        date: now,
        category: ScheduleCategory.billingTax,
        memo: '미납자 일괄 재청구 전송',
        createdAt: now,
      );

      final map = item.toMap();
      final fromMap = ScheduleItem.fromMap(map);
      expect(fromMap.id, equals('sched_test_1'));
      expect(fromMap.title, equals('정기 수강료 정산 마감일'));
      expect(fromMap.category, equals(ScheduleCategory.billingTax));
      expect(fromMap.category.label, equals('수납/세무 일정'));

      final jsonStr = item.toJson();
      final fromJson = ScheduleItem.fromJson(jsonStr);
      expect(fromJson.title, equals(item.title));

      final updated = item.copyWith(title: '정기 정산 완료');
      expect(updated.title, equals('정기 정산 완료'));
    });

    test('ScheduleService loads defaults and performs CRUD correctly', () async {
      final defaults = await ScheduleService.loadSchedules();
      expect(defaults.isNotEmpty, isTrue);
      expect(defaults.any((s) => s.category == ScheduleCategory.billingTax), isTrue);

      final newItem = ScheduleItem(
        id: 'new_sched_item',
        title: '신규 특별 마스터 클래스',
        date: DateTime(2026, 4, 20),
        category: ScheduleCategory.specialLesson,
        memo: '초청 교수 특강',
        createdAt: DateTime.now(),
      );

      await ScheduleService.addSchedule(newItem);
      final afterAdd = await ScheduleService.loadSchedules();
      expect(afterAdd.any((s) => s.id == 'new_sched_item'), isTrue);

      await ScheduleService.deleteSchedule('new_sched_item');
      final afterDelete = await ScheduleService.loadSchedules();
      expect(afterDelete.any((s) => s.id == 'new_sched_item'), isFalse);
    });
  });

  group('ScheduleCalendarModal UI Tests', () {
    testWidgets('Renders month navigation, attendance indicators and schedule items', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudio)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier()),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier()),
            membersProvider.overrideWith(() => _MockMembersNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: ScheduleCalendarModal(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check header title
      expect(find.text('출결 & 일정 스케줄 달력'), findsOneWidget);
      expect(find.text('오늘'), findsOneWidget);

      // Verify week days are rendered
      expect(find.text('일'), findsOneWidget);
      expect(find.text('월'), findsOneWidget);
      expect(find.text('토'), findsOneWidget);

      // Verify Add schedule button is present
      expect(find.text('일정 추가'), findsOneWidget);
    });
  });

  group('SettingsVaultScreen Streamlined Architecture UI Tests', () {
    testWidgets('Renders grouped representative tiles and opens detailed bottom sheet', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(testStudio)),
            membersProvider.overrideWith(() => _MockMembersNotifier()),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier()),
          ],
          child: const MaterialApp(
            home: SettingsVaultScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      if (find.text('안심하고 사용할게요').evaluate().isNotEmpty) {
        await tester.tap(find.text('안심하고 사용할게요'));
        await tester.pumpAndSettle();
      }

      // Compact Studio Hero
      expect(find.text('모차르트 클래식 음악원'), findsOneWidget);
      expect(find.textContaining('조성진 원장'), findsWidgets);

      // Scroll to Representative Group Headers
      await tester.scrollUntilVisible(
        find.text('시설 & 브랜드 환경'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('시설 & 브랜드 환경'), findsOneWidget);

      // Scroll down to check representative tiles
      await tester.scrollUntilVisible(
        find.text('고객 & 비용 맞춤 호칭 설정'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('고객 & 비용 맞춤 호칭 설정'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('무인 출결 키오스크 기기 설정'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('무인 출결 키오스크 기기 설정'), findsOneWidget);

      // Tap kiosk settings tile to open bottom sheet
      await tester.tap(find.text('무인 출결 키오스크 기기 설정'));
      await tester.pumpAndSettle();

      // Check inside bottom sheet
      expect(find.text('앱 실행 시 키오스크 자동 실행'), findsOneWidget);
      expect(find.text('학생 출결 키오스크 실행 (실제 운영용)'), findsOneWidget);

      // Close bottom sheet
      Navigator.pop(tester.element(find.text('앱 실행 시 키오스크 자동 실행')));
      await tester.pumpAndSettle();

      // Check Legal Compliance tile
      await tester.scrollUntilVisible(
        find.textContaining('법적 고지 및 규정 준수'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('법적 고지 및 규정 준수'), findsOneWidget);
    });
  });
}
