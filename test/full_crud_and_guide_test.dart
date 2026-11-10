import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/notification_log.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/schedule_item.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/services/data_vault_service.dart';
import 'package:zeropass/services/database_service.dart';
import 'package:zeropass/services/kakao_share_service.dart';
import 'package:zeropass/services/monetization_service.dart';
import 'package:zeropass/services/schedule_service.dart';
import 'package:zeropass/services/sequential_dispatch_service.dart';
import 'package:zeropass/services/sms_template_service.dart';

class _MockMembersNotifier extends MembersNotifier {
  final List<Member> _items;
  _MockMembersNotifier(this._items);
  @override
  Future<List<Member>> build() async => _items;
}

class _MockStudioNotifier extends StudioProfileNotifier {
  @override
  Future<StudioProfile> build() async => StudioProfile.defaultProfile();
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async => Directory.systemTemp.path,
    );
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

  group('End-to-End CRUD Tests across all menus', () {
    test('Member CRUD: create, read, update, and delete cascades pass records', () async {
      final db = DatabaseService.instance;
      await db.clearAllData();

      final member = Member(
        id: 'mem_crud_1',
        name: '김철수',
        phone: '010-1111-2222',
        groupName: '피아노 초급',
        billingType: BillingType.sessionBased,
        defaultFee: 200000,
        totalSessions: 10,
        remainingSessions: 10,
        registeredAt: DateTime.now(),
      );
      await db.insertMember(member);

      final pass = PassRecord(
        id: 'pass_crud_1',
        memberId: member.id,
        timestamp: DateTime.now(),
        status: AttendanceStatus.attended,
        sessionDeduction: 1,
      );
      await db.insertPassRecord(pass);

      final updated = member.copyWith(
        name: '김철수(수정)',
        groupName: '피아노 중급',
        remainingSessions: 9,
      );
      await db.updateMember(updated);

      final loadedMembers = await db.getMembers();
      expect(loadedMembers.length, 1);
      expect(loadedMembers.first.name, '김철수(수정)');
      expect(loadedMembers.first.groupName, '피아노 중급');
      expect(loadedMembers.first.remainingSessions, 9);

      await db.deleteMember(member.id);
      expect((await db.getMembers()), isEmpty);
      expect((await db.getPassRecords()), isEmpty);
    });

    test('PassRecord deletePassRecord restores workflow cleanly', () async {
      final db = DatabaseService.instance;
      await db.clearAllData();

      final pass = PassRecord(
        id: 'pass_del_1',
        memberId: 'mem_x',
        timestamp: DateTime.now(),
        status: AttendanceStatus.attended,
        sessionDeduction: 1,
      );
      await db.insertPassRecord(pass);
      expect((await db.getPassRecords()).length, 1);

      await db.deletePassRecord('pass_del_1');
      expect((await db.getPassRecords()), isEmpty);
    });

    test('Invoice CRUD: create, edit, mark paid, revert unpaid, and delete', () async {
      final db = DatabaseService.instance;
      await db.clearAllData();

      final inv = Invoice(
        id: 'inv_crud_1',
        memberIds: ['mem_1'],
        recipientPhone: '010-3333-4444',
        title: '11월 수강료',
        amount: 250000,
        dueDate: DateTime(2026, 11, 25),
        status: PaymentStatus.unpaid,
      );
      await db.insertInvoice(inv);

      final edited = inv.copyWith(title: '11월 수강료(할인)', amount: 220000);
      await db.updateInvoice(edited);

      final loaded = (await db.getInvoices()).first;
      expect(loaded.title, '11월 수강료(할인)');
      expect(loaded.amount, 220000);

      await db.deleteInvoice(inv.id);
      expect((await db.getInvoices()), isEmpty);
    });

    test('Backup & Restore includes notification logs and schedules + Real usage reset', () async {
      final db = DatabaseService.instance;
      await db.clearAllData();
      await ScheduleService.clearSchedules();

      await db.insertNotificationLog(
        NotificationLog(
          id: 'n_bak_1',
          type: NotificationType.attendance,
          memberId: 'm1',
          memberName: '테스트학생',
          recipientPhone: '010-0000-1111',
          channel: 'SMS',
          message: '등원 완료',
          sentAt: DateTime.now(),
        ),
      );
      await ScheduleService.addSchedule(
        ScheduleItem(
          id: 'sch_bak_1',
          title: '발표회',
          date: DateTime(2026, 12, 20),
          createdAt: DateTime.now(),
        ),
      );

      final backupFile = await DataVaultService.exportEncryptedBackup();
      final jsonStr = await backupFile.readAsString();
      expect(jsonStr.contains('n_bak_1'), isTrue);
      expect(jsonStr.contains('sch_bak_1'), isTrue);

      // Clear everything for real usage
      await db.clearAllData();
      await ScheduleService.clearSchedules();
      await MonetizationService.instance.resetMetricsForRealUsage();

      expect((await db.getNotificationLogs()), isEmpty);
      expect((await ScheduleService.loadSchedules()), isEmpty);
      expect(MonetizationService.instance.cumulativeCheckInCount, 0);
      expect(MonetizationService.instance.cumulativeSavedSmsCount, 0);

      // Restore from JSON
      final restored = await DataVaultService.restoreFromBackupJson(jsonStr);
      expect(restored, isTrue);
      expect((await db.getNotificationLogs()).any((l) => l.id == 'n_bak_1'), isTrue);
      expect((await ScheduleService.loadSchedules()).any((s) => s.id == 'sch_bak_1'), isTrue);
    });
  });

  group('SettingsVaultScreen FullUsageGuideModal Tests', () {
    testWidgets('Opens FullUsageGuideModal from SettingsVaultScreen and switches tab guides', (tester) async {
      tester.view.physicalSize = const Size(1080, 2200);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => _MockMembersNotifier([])),
            studioProfileProvider.overrideWith(() => _MockStudioNotifier()),
          ],
          child: const MaterialApp(
            home: SettingsVaultScreen(enableAutoCoachMark: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final guideTile = find.text('탭별 · 기능별 전체 사용 가이드');
      await tester.scrollUntilVisible(guideTile, 200, scrollable: find.byType(Scrollable).first);
      expect(guideTile, findsOneWidget);

      await tester.tap(guideTile);
      await tester.pumpAndSettle();

      expect(find.text('체크앤페이 전체 메뉴·기능 가이드'), findsOneWidget);
      expect(find.text('1. 1초 원터치 출석 체크 & 취소'), findsOneWidget);

      // Switch to 청구·수납 guide
      await tester.tap(find.text('청구·수납'));
      await tester.pumpAndSettle();
      expect(find.text('2. 청구서 수정 · 삭제 · 완납 처리 · 수납 취소'), findsOneWidget);

      // Switch to 회원 명부 guide
      await tester.tap(find.text('회원 명부'));
      await tester.pumpAndSettle();
      expect(find.text('2. 회원 정보 수정 · 삭제 · 회차 충전 · 이력 관리'), findsOneWidget);
    });
  });

  group('Custom Terminology & Role Personalization Tests', () {
    test('Custom role, place, member, and fee terms propagate to DB, SMS, Kakao, and Sequential Dispatch', () async {
      final db = DatabaseService.instance;
      final customProfile = StudioProfile.defaultProfile().copyWith(
        studioName: '루나 필라테스',
        instructorName: '박지현',
        customRoleTerm: '실장',
        customPlaceTerm: '스튜디오',
        customMemberTerm: '회원',
        customFeeTerm: '레슨비',
        attendanceTemplate: '[#{상호명}] #{회원명} #{고객호칭}님 #{장소호칭} 출석 (#{직함}: #{담당자})',
      );

      await db.updateStudioProfile(customProfile);
      final loaded = await db.getStudioProfile();
      expect(loaded.roleTitle, equals('실장'));
      expect(loaded.placeTitle, equals('스튜디오'));
      expect(loaded.memberWord, equals('회원'));
      expect(loaded.feeWord, equals('레슨비'));

      final member = Member(
        id: 'm_custom_1',
        name: '김수진',
        phone: '010-1234-5678',
        groupName: '기구 필라테스',
        billingType: BillingType.sessionBased,
        defaultFee: 450000,
        totalSessions: 10,
        remainingSessions: 9,
        registeredAt: DateTime.now(),
      );

      final smsMsg = SmsTemplateService.generateAttendanceMessage(
        studio: loaded,
        member: member,
        time: DateTime(2026, 11, 11, 14, 30),
      );
      expect(smsMsg, contains('[루나 필라테스] 김수진 회원님 스튜디오 출석 (실장: 박지현)'));

      final kakaoVendorMsg = KakaoShareService.generateVendorOrderKakaoMessage(
        studio: loaded,
        vendorName: '필라기구몰',
        title: '리포머 스프링 교체',
        amount: 120000,
      );
      expect(kakaoVendorMsg, contains('루나 필라테스(실장: 박지현)'));

      final kakaoAttMsg = KakaoShareService.generateAttendanceKakaoMessage(
        studio: loaded,
        member: member,
        time: DateTime(2026, 11, 11, 14, 30),
      );
      expect(kakaoAttMsg, contains('김수진 회원님이'));
      expect(kakaoAttMsg.contains('학생'), isFalse);

      final dispatchMsg = SequentialDispatchService.renderMessage(
        template: '#{상호명} #{직함} #{담당자} / #{고객호칭} #{비용호칭} #{장소호칭}',
        studio: loaded,
        member: member,
      );
      expect(dispatchMsg, equals('루나 필라테스 실장 박지현 / 회원 레슨비 스튜디오'));
    });
  });
}

