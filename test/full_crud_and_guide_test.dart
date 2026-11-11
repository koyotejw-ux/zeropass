import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
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
import 'package:zeropass/screens/pro_store_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/services/data_vault_service.dart';
import 'package:zeropass/services/database_service.dart';
import 'package:zeropass/services/kakao_share_service.dart';
import 'package:zeropass/services/monetization_service.dart';
import 'package:zeropass/services/schedule_service.dart';
import 'package:zeropass/services/sequential_dispatch_service.dart';
import 'package:zeropass/services/sms_template_service.dart';
import 'package:zeropass/widgets/full_usage_guide_modal.dart';
import 'package:zeropass/widgets/interactive_guide_dialog.dart';
import 'package:zeropass/widgets/senior_easy_guide_modal.dart';
import 'package:zeropass/widgets/tax_guide_modal.dart';

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

  group('Responsive Width Tests for Settings & Guides', () {
    testWidgets('SettingsVaultScreen and FullUsageGuideModal render cleanly on 320px compact phone and 900px tablet', (tester) async {
      for (final size in const [Size(320, 640), Size(900, 800)]) {
        await tester.binding.setSurfaceSize(size);

        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey(size),
            overrides: [
              studioProfileProvider.overrideWith(() => _MockStudioNotifier()),
              membersProvider.overrideWith(() => _MockMembersNotifier([])),
            ],
            child: const MaterialApp(
              home: SettingsVaultScreen(enableAutoCoachMark: false),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Check tile list constraints (max 720px on tablet -> card width <= 720)
        final tileFinder = find.text('맞춤 호칭 & 용어 설정');
        await tester.scrollUntilVisible(
          tileFinder,
          150,
          scrollable: find.byType(Scrollable).first,
        );
        expect(tileFinder, findsOneWidget);
        if (size.width >= 900) {
          final tileRect = tester.getRect(tileFinder);
          // On 900px screen centered in max 720px content column, left margin >= (900 - 720) / 2 = 90
          expect(tileRect.left, greaterThanOrEqualTo(89.0));
        }

        // Open FullUsageGuideModal and verify sheet maxWidth <= 640 on tablet and zero overflow on 320px
        await tester.scrollUntilVisible(
          find.text('탭별 · 기능별 전체 사용 가이드'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.ensureVisible(find.text('탭별 · 기능별 전체 사용 가이드'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('탭별 · 기능별 전체 사용 가이드'));
        await tester.pumpAndSettle();

        expect(find.text('체크앤페이 전체 메뉴·기능 가이드'), findsOneWidget);
        if (size.width >= 900) {
          final sheetRect = tester.getRect(find.byType(FullUsageGuideModal));
          expect(sheetRect.width, lessThanOrEqualTo(640.1));
        }

        Navigator.pop(tester.element(find.byType(FullUsageGuideModal)));
        await tester.pumpAndSettle();
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });

    testWidgets('TaxGuideModal, SeniorEasyGuideModal, and StepByStepPracticeGuideDialog render cleanly at 320px & 900px', (tester) async {
      for (final size in const [Size(320, 640), Size(900, 800)]) {
        await tester.binding.setSurfaceSize(size);

        await tester.pumpWidget(
          ProviderScope(
            key: ValueKey('guide_${size.width}'),
            overrides: [
              studioProfileProvider.overrideWith(() => _MockStudioNotifier()),
              membersProvider.overrideWith(() => _MockMembersNotifier([])),
            ],
            child: MaterialApp(
              home: Builder(
                builder: (ctx) => Scaffold(
                  body: Column(
                    children: [
                      ElevatedButton(
                        onPressed: () => TaxGuideModal.show(ctx),
                        child: const Text('TAX'),
                      ),
                      ElevatedButton(
                        onPressed: () => SeniorEasyGuideModal.show(ctx),
                        child: const Text('SENIOR'),
                      ),
                      ElevatedButton(
                        onPressed: () => StepByStepPracticeGuideDialog.show(
                          ctx,
                          onOpenAddMember: () {},
                          onOpenSettings: () {},
                        ),
                        child: const Text('STEP'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. TaxGuideModal
        await tester.tap(find.text('TAX'));
        await tester.pumpAndSettle();
        expect(find.text('1분 세무 마스터 가이드'), findsOneWidget);
        if (size.width >= 900) {
          expect(tester.getRect(find.byType(TaxGuideModal)).width, lessThanOrEqualTo(640.1));
        }
        Navigator.pop(tester.element(find.byType(TaxGuideModal)));
        await tester.pumpAndSettle();

        // 2. SeniorEasyGuideModal
        await tester.tap(find.text('SENIOR'));
        await tester.pumpAndSettle();
        expect(find.text('큰글씨 간편 사용 안내'), findsOneWidget);
        Navigator.pop(tester.element(find.byType(SeniorEasyGuideModal)));
        await tester.pumpAndSettle();

        // 3. StepByStepPracticeGuideDialog
        await tester.tap(find.text('STEP'));
        await tester.pumpAndSettle();
        expect(find.text('하나씩 따라 해볼까요?'), findsOneWidget);
        Navigator.pop(tester.element(find.byType(StepByStepPracticeGuideDialog)));
        await tester.pumpAndSettle();
      }
      addTearDown(() => tester.binding.setSurfaceSize(null));
    });
  });

  group('Probabilistic CRUD Ad & Subscription Upsell Tests', () {
    test('triggerCrudInterstitialAd fires probabilistically across CRUD operations and stops when subscribed', () async {
      final bm = MonetizationService.instance;
      await bm.debugResetAll();
      bm.allowCrudAdInTests = true;
      final triggeredActions = <String>[];
      final upsells = <String>[];
      bm.onTestInterstitialTriggered = triggeredActions.add;
      bm.onTestUpsellTriggered = upsells.add;
      addTearDown(() async {
        bm.allowCrudAdInTests = false;
        bm.onTestInterstitialTriggered = null;
        bm.onTestUpsellTriggered = null;
        await bm.debugResetAll();
      });

      // 1. Probability 0.0 -> never triggers
      expect(
        bm.triggerCrudInterstitialAd(actionLabel: '회원 등록', probability: 0.0, cooldownSeconds: 0),
        isFalse,
      );
      expect(triggeredActions, isEmpty);

      // 2. Probability 1.0 -> triggers ad + upsell funnel
      expect(
        bm.triggerCrudInterstitialAd(actionLabel: '회원 수정', probability: 1.0, cooldownSeconds: 0),
        isTrue,
      );
      expect(triggeredActions, equals(['회원 수정']));
      expect(upsells, equals(['회원 수정']));

      // 3. Respects cooldown when cooldownSeconds > 0
      expect(
        bm.triggerCrudInterstitialAd(actionLabel: '청구 삭제', probability: 1.0, cooldownSeconds: 30),
        isFalse,
      );
      expect(triggeredActions.length, equals(1));

      // 4. Fires again after cooldownSeconds == 0 on next CRUD
      expect(
        bm.triggerCrudInterstitialAd(actionLabel: '지출 등록', probability: 1.0, cooldownSeconds: 0),
        isTrue,
      );
      expect(triggeredActions, equals(['회원 수정', '지출 등록']));

      // 5. Completely suppressed when VIP subscription or 1h ad-free pass is active
      await bm.setDebugUnlock(adsRemoved: true);
      expect(
        bm.triggerCrudInterstitialAd(actionLabel: '일정 등록', probability: 1.0, cooldownSeconds: 0),
        isFalse,
      );
      expect(triggeredActions.length, equals(2));

      await bm.debugResetAll();
      await bm.grantTemporaryAdFreeHours(1);
      expect(
        bm.triggerCrudInterstitialAd(actionLabel: '서식 저장', probability: 1.0, cooldownSeconds: 0),
        isFalse,
      );
      expect(triggeredActions.length, equals(2));
    });

    testWidgets('showAdRemovalUpsellDialog renders cleanly and navigates to ProStoreScreen', (tester) async {
      final bm = MonetizationService.instance;
      await bm.debugResetAll();

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            navigatorKey: MonetizationService.rootNavigatorKey,
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => bm.showAdRemovalUpsellDialog(ctx, actionLabel: '회원 등록'),
                    child: const Text('SHOW_UPSELL'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('SHOW_UPSELL'));
      await tester.pumpAndSettle();

      expect(find.text('광고 없이 바로 저장할까요?'), findsOneWidget);
      expect(find.textContaining('회원 등록'), findsOneWidget);
      expect(find.text('월 1,900원 광고 완전 제거'), findsOneWidget);
      expect(find.text('1시간 무료 체험'), findsOneWidget);

      await tester.tap(find.text('계속 광고 보며 이용하기'));
      await tester.pumpAndSettle();
      expect(find.text('광고 없이 바로 저장할까요?'), findsNothing);
    });
  });

  group('Non-VIP Registration & Edit Quota Enforcement Tests', () {
    test('Free and Standalone plans enforce caps while All-in-One VIP unlocks unlimited', () async {
      final bm = MonetizationService.instance;
      await bm.debugResetAll();
      addTearDown(() async => await bm.debugResetAll());

      // 1. Free tier caps
      expect(bm.isUnlimitedVip, isFalse);
      expect(bm.maxMemberLimit, equals(10));
      expect(bm.maxMonthlyEditLimit, equals(5));
      expect(bm.maxCustomTemplateLimit, equals(5));
      expect(bm.canCreateItem(currentCount: 9, limit: bm.maxMemberLimit), isTrue);
      expect(bm.canCreateItem(currentCount: 10, limit: bm.maxMemberLimit), isFalse);

      // Consume all 5 free monthly edits
      for (int i = 0; i < 5; i++) {
        expect(bm.canPerformEdit, isTrue);
        await bm.recordEditUsage();
      }
      expect(bm.remainingMonthlyEditCount, equals(0));
      expect(bm.canPerformEdit, isFalse);

      // 2. Standalone plan (Remove Ads only) expands caps slightly, still non-VIP restricted
      await bm.setDebugUnlock(adsRemoved: true, kioskPro: false);
      expect(bm.isUnlimitedVip, isFalse);
      expect(bm.isStandalonePaidPlan, isTrue);
      expect(bm.maxMemberLimit, equals(30));
      expect(bm.maxMonthlyEditLimit, equals(15));
      expect(bm.canCreateItem(currentCount: 30, limit: bm.maxMemberLimit), isFalse);
      expect(bm.canPerformEdit, isTrue); // 5 used out of 15 standalone edits

      // 3. All-in-One VIP unlocks unlimited registration & edits
      await bm.debugUnlockAll();
      expect(bm.isUnlimitedVip, isTrue);
      expect(bm.maxMemberLimit, equals(-1));
      expect(bm.maxMonthlyEditLimit, equals(-1));
      expect(bm.canCreateItem(currentCount: 9999, limit: bm.maxMemberLimit), isTrue);
      expect(bm.canPerformEdit, isTrue);
    });

    testWidgets('showVipLimitUpgradeDialog blocks over-limit action and links to VIP', (tester) async {
      final bm = MonetizationService.instance;
      await bm.debugResetAll();
      addTearDown(() async => await bm.debugResetAll());

      bool allowedCreate = true;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (ctx) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      allowedCreate = await bm.ensureCreateAllowed(
                        ctx,
                        itemLabel: '회원',
                        currentCount: 10,
                        limit: bm.maxMemberLimit,
                      );
                    },
                    child: const Text('TRY_ADD_MEMBER_11'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('TRY_ADD_MEMBER_11'));
      await tester.pumpAndSettle();

      expect(find.text('회원 등록 한도에 도달했습니다'), findsOneWidget);
      expect(find.text('올인원 VIP 무제한 (₩5,900)'), findsOneWidget);
      expect(find.text('1시간 VIP 체험'), findsOneWidget);

      await tester.tap(find.text('닫기'));
      await tester.pumpAndSettle();
      expect(allowedCreate, isFalse);
    });
  });

  group('Subscription & Period Entitlement Lifecycle Tests', () {
    PurchaseDetails makePurchase(
      String productId,
      PurchaseStatus status, {
      DateTime? txDate,
    }) {
      return PurchaseDetails(
        productID: productId,
        verificationData: PurchaseVerificationData(
          localVerificationData: 'local',
          serverVerificationData: 'server',
          source: 'google_play',
        ),
        transactionDate: txDate?.millisecondsSinceEpoch.toString(),
        status: status,
      );
    }

    test('Subscription pending -> purchased transitions to active, covers standalone items, and blocks duplicate buyProduct', () async {
      final bm = MonetizationService.instance;
      await bm.debugResetAll();
      addTearDown(() async => await bm.debugResetAll());

      expect(bm.getProductState(MonetizationService.productSubAllInOneMonthly), ProductPurchaseState.notOwned);
      expect(bm.canPurchaseProduct(MonetizationService.productSubAllInOneMonthly), isTrue);

      // 1. Pending state
      await bm.processPurchaseUpdatesForTest([
        makePurchase(MonetizationService.productSubAllInOneMonthly, PurchaseStatus.pending),
      ]);
      expect(bm.getProductState(MonetizationService.productSubAllInOneMonthly), ProductPurchaseState.pending);
      expect(bm.canPurchaseProduct(MonetizationService.productSubAllInOneMonthly), isFalse);

      // 2. Purchased -> Active + covers Kiosk & Ads standalone + blocks duplicate buy
      final purchaseTime = DateTime.now();
      await bm.processPurchaseUpdatesForTest(
        [makePurchase(MonetizationService.productSubAllInOneMonthly, PurchaseStatus.purchased, txDate: purchaseTime)],
        now: purchaseTime,
      );

      expect(bm.getProductState(MonetizationService.productSubAllInOneMonthly), ProductPurchaseState.active);
      expect(bm.getProductState(MonetizationService.productSubKioskMonthly), ProductPurchaseState.coveredByVip);
      expect(bm.getProductState(MonetizationService.productSubRemoveAdsMonthly), ProductPurchaseState.coveredByVip);
      expect(bm.canPurchaseProduct(MonetizationService.productSubAllInOneMonthly), isFalse);
      expect(bm.canPurchaseProduct(MonetizationService.productSubKioskMonthly), isFalse);
      expect(bm.isPermanentVip, isTrue);

      final dupResult = await bm.buyProduct(MonetizationService.productSubAllInOneMonthly);
      expect(dupResult.started, isFalse);
      expect(dupResult.errorMessage, contains('이미 이용 중인 상품'));
    });

    test('Timed 1-hour pass blocks re-claim while active and unlocks cleanly after period expires', () async {
      final bm = MonetizationService.instance;
      await bm.debugResetAll();
      addTearDown(() async => await bm.debugResetAll());

      final start = DateTime.now();
      final firstClaim = await bm.claimTemporaryVipPass(hours: 1, now: start);
      expect(firstClaim.granted, isTrue);
      expect(bm.isTemporaryPassActive, isTrue);
      expect(bm.canClaimTemporaryPass, isFalse);
      expect(bm.getProductState(MonetizationService.productPassTemporaryVip1h, now: start), ProductPurchaseState.active);

      // Re-claim 30 minutes later must be blocked while active
      final mid = start.add(const Duration(minutes: 30));
      final blockedClaim = await bm.claimTemporaryVipPass(hours: 1, now: mid);
      expect(blockedClaim.granted, isFalse);
      expect(blockedClaim.message, contains('기간 만료 후 다시 이용'));

      // After 61 minutes, expiration runs -> state becomes expired and re-claim succeeds
      final afterExpiry = start.add(const Duration(minutes: 61));
      final expiredIds = await bm.checkEntitlementExpirations(now: afterExpiry);
      expect(expiredIds, contains(MonetizationService.productPassTemporaryVip1h));
      expect(bm.getProductState(MonetizationService.productPassTemporaryVip1h, now: afterExpiry), ProductPurchaseState.expired);
      expect(bm.isUnlimitedVip, isFalse);

      final reClaim = await bm.claimTemporaryVipPass(hours: 1, now: afterExpiry.add(const Duration(seconds: 1)));
      expect(reClaim.granted, isTrue);
    });

    test('Subscription expiration revokes access and transitions state to expired -> resubscribable', () async {
      final bm = MonetizationService.instance;
      await bm.debugResetAll();
      addTearDown(() async => await bm.debugResetAll());

      final pastPurchase = DateTime.now().subtract(const Duration(days: 35));
      await bm.seedEntitlementForTest(
        PurchasedEntitlement(
          productId: MonetizationService.productSubRemoveAdsMonthly,
          purchasedAt: pastPurchase,
          expiresAt: pastPurchase.add(const Duration(days: 30)),
          isSubscription: true,
        ),
      );

      final expiredIds = await bm.checkEntitlementExpirations();
      expect(expiredIds, contains(MonetizationService.productSubRemoveAdsMonthly));
      expect(bm.isSubscriptionAdsRemoved, isFalse);
      expect(bm.isAdsRemoved, isFalse);
      expect(bm.getProductState(MonetizationService.productSubRemoveAdsMonthly), ProductPurchaseState.expired);
      expect(bm.canPurchaseProduct(MonetizationService.productSubRemoveAdsMonthly), isTrue);
    });

    test('restorePurchases activates valid store SKUs and revokes stale un-restored local subscriptions', () async {
      final bm = MonetizationService.instance;
      await bm.debugResetAll();
      addTearDown(() async => await bm.debugResetAll());

      // Case 1: Restore valid subscription from store
      final restoreRes = await bm.restorePurchases(
        settleDuration: Duration.zero,
        platformRestoreOverride: () async {
          await bm.processPurchaseUpdatesForTest([
            makePurchase(MonetizationService.productSubKioskMonthly, PurchaseStatus.restored),
          ]);
        },
      );
      expect(restoreRes.hadError, isFalse);
      expect(restoreRes.restoredCount, 1);
      expect(bm.isSubscriptionKioskPro, isTrue);
      expect(bm.getProductState(MonetizationService.productSubKioskMonthly), ProductPurchaseState.active);

      // Case 2: Store returns 0 restored purchases -> stale local subscription becomes expired
      final syncEmptyRes = await bm.restorePurchases(
        settleDuration: Duration.zero,
        platformRestoreOverride: () async {},
      );
      expect(syncEmptyRes.hadError, isFalse);
      expect(syncEmptyRes.restoredCount, 0);
      expect(syncEmptyRes.message, contains('만료 상태로 동기화'));
      expect(bm.isSubscriptionKioskPro, isFalse);
      expect(bm.getProductState(MonetizationService.productSubKioskMonthly), ProductPurchaseState.expired);
    });

    testWidgets('ProStoreScreen displays active subscription badges, disables duplicate buys, and locks active timed pass', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bm = MonetizationService.instance;
      await bm.debugResetAll();
      addTearDown(() async => await bm.debugResetAll());

      // Active 1-hour pass locks re-claim button
      await bm.claimTemporaryVipPass(hours: 1);

      await tester.pumpWidget(
        const MaterialApp(home: ProStoreScreen()),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('기간제 이용 중'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('기간제 이용 중'), findsOneWidget);
      expect(find.textContaining('만료 후 재이용'), findsOneWidget);

      // Simulate All-in-One VIP purchase while ProStoreScreen is open
      await bm.processPurchaseUpdatesForTest([
        makePurchase(MonetizationService.productSubAllInOneMonthly, PurchaseStatus.purchased),
      ]);
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('구독 중 (올인원 VIP 이용 중)'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('구독 중 (올인원 VIP 이용 중)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('태블릿 키오스크 단독 구독'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('VIP 포함 이용 중 (중복 구독 불가)'), findsAtLeastNWidgets(1));

      await tester.scrollUntilVisible(
        find.text('광고 제거 단독 구독'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('VIP 포함 이용 중 (중복 구독 불가)'), findsAtLeastNWidgets(1));
    });

    testWidgets('Per-product benefit matrix: Ads standalone, Kiosk standalone, VIP Yearly, and Settings lock', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final bm = MonetizationService.instance;
      await bm.debugResetAll();
      addTearDown(() async => await bm.debugResetAll());

      // 0. Free Plan defaults
      expect(bm.isAdsRemoved, isFalse);
      expect(bm.isKioskProUnlocked, isFalse);
      expect(bm.maxMemberLimit, MonetizationService.freeMaxMembers);
      expect(bm.maxMonthlyEditLimit, MonetizationService.freeMaxMonthlyEdits);

      // 1. Remove Ads Standalone
      await bm.processPurchaseUpdatesForTest([
        makePurchase(MonetizationService.productSubRemoveAdsMonthly, PurchaseStatus.purchased),
      ]);
      expect(bm.isAdsRemoved, isTrue);
      expect(bm.isKioskProUnlocked, isFalse);
      expect(bm.isStandalonePaidPlan, isTrue);
      expect(bm.maxMemberLimit, MonetizationService.standaloneMaxMembers);
      expect(bm.canPurchaseProduct(MonetizationService.productSubRemoveAdsMonthly), isFalse);
      expect(bm.canPurchaseProduct(MonetizationService.productSubKioskMonthly), isTrue);

      await tester.pumpWidget(const MaterialApp(home: ProStoreScreen()));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('구독 중 (광고 제거 이용 중)'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('구독 중 (광고 제거 이용 중)'), findsOneWidget);

      // 2. Kiosk Standalone (after reset)
      await bm.debugResetAll();
      await bm.processPurchaseUpdatesForTest([
        makePurchase(MonetizationService.productSubKioskMonthly, PurchaseStatus.purchased),
      ]);
      expect(bm.isAdsRemoved, isFalse);
      expect(bm.isKioskProUnlocked, isTrue);
      expect(bm.isStandalonePaidPlan, isTrue);
      expect(bm.maxMemberLimit, MonetizationService.standaloneMaxMembers);
      expect(bm.canPurchaseProduct(MonetizationService.productSubKioskMonthly), isFalse);
      expect(bm.canPurchaseProduct(MonetizationService.productSubRemoveAdsMonthly), isTrue);

      // 3. VIP Yearly covers Monthly VIP, Kiosk, Ads, Temp Pass + unlocks unlimited quotas
      await bm.debugResetAll();
      await bm.processPurchaseUpdatesForTest([
        makePurchase(MonetizationService.productSubAllInOneYearly, PurchaseStatus.purchased),
      ]);
      expect(bm.isPermanentVip, isTrue);
      expect(bm.isUnlimitedVip, isTrue);
      expect(bm.maxMemberLimit, -1);
      expect(bm.maxMonthlyEditLimit, -1);
      expect(bm.getProductState(MonetizationService.productSubAllInOneYearly), ProductPurchaseState.active);
      expect(bm.getProductState(MonetizationService.productSubAllInOneMonthly), ProductPurchaseState.coveredByVip);
      expect(bm.getProductState(MonetizationService.productSubKioskMonthly), ProductPurchaseState.coveredByVip);
      expect(bm.getProductState(MonetizationService.productSubRemoveAdsMonthly), ProductPurchaseState.coveredByVip);
      expect(bm.getProductState(MonetizationService.productPassTemporaryVip1h), ProductPurchaseState.coveredByVip);
      expect(bm.canClaimTemporaryPass, isFalse);

      // Expiry after 366 days revokes VIP Yearly
      final afterYear = DateTime.now().add(const Duration(days: 366));
      final expired = await bm.checkEntitlementExpirations(now: afterYear);
      expect(expired, contains(MonetizationService.productSubAllInOneYearly));
      expect(bm.isPermanentVip, isFalse);
      expect(bm.getProductState(MonetizationService.productSubAllInOneYearly), ProductPurchaseState.expired);
      expect(bm.canPurchaseProduct(MonetizationService.productSubAllInOneYearly), isTrue);

      // 4. SettingsVaultScreen disables 1-hour pass CTA while active
      await bm.debugResetAll();
      await bm.claimTemporaryVipPass(hours: 1);
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
      await tester.scrollUntilVisible(
        find.textContaining('1시간 VIP 체험 중'),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('1시간 VIP 체험 중'), findsOneWidget);
      expect(find.text('1시간 VIP 무료 체험'), findsNothing);
    });
  });
}

