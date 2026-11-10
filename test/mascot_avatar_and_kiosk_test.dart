import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/tablet_kiosk_screen.dart';
import 'package:zeropass/widgets/mascot_avatar.dart';
import 'package:zeropass/widgets/member_name_badge.dart';

class MockEmptyMembersNotifier extends MembersNotifier {
  @override
  Future<List<Member>> build() async => [];
}

class MockStudioProfileNotifier extends StudioProfileNotifier {
  @override
  Future<StudioProfile> build() async => StudioProfile.defaultProfile();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });
  group('ZeroPassMascotAvatar Widget Tests', () {
    testWidgets('Renders 3D transparent mascot inside ClipOval when photoPath is null', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZeroPassMascotAvatar(
              size: 52,
              isLightMode: true,
            ),
          ),
        ),
      );

      expect(find.byType(ZeroPassMascotAvatar), findsOneWidget);
      expect(find.byType(ClipOval), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('Renders badge overlay when provided', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ZeroPassMascotAvatar(
              size: 80,
              badge: Icon(Icons.check_circle, key: Key('test_badge')),
            ),
          ),
        ),
      );

      expect(find.byKey(const Key('test_badge')), findsOneWidget);
    });

    testWidgets('Renders properly without overflow on ultra-narrow 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(
              child: ZeroPassMascotAvatar(size: 60),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    });

    test('MascotExpression correctly maps attendance rates to expressions and asset paths', () {
      expect(MascotExpression.fromAttendanceRate(100), MascotExpression.laughing);
      expect(MascotExpression.fromAttendanceRate(75), MascotExpression.laughing);
      expect(MascotExpression.fromAttendanceRate(70), MascotExpression.laughing);
      expect(MascotExpression.fromAttendanceRate(69), MascotExpression.smile);
      expect(MascotExpression.fromAttendanceRate(50), MascotExpression.smile);
      expect(MascotExpression.fromAttendanceRate(35), MascotExpression.smile);
      expect(MascotExpression.fromAttendanceRate(34), MascotExpression.crying);
      expect(MascotExpression.fromAttendanceRate(10), MascotExpression.crying);
      expect(MascotExpression.fromAttendanceRate(0), MascotExpression.crying);
      expect(MascotExpression.fromAttendanceRate(null), MascotExpression.smile);

      expect(MascotExpression.laughing.assetPath, 'assets/icons/mascot_profile_laughing.png');
      expect(MascotExpression.smile.assetPath, 'assets/icons/mascot_profile.png');
      expect(MascotExpression.crying.assetPath, 'assets/icons/mascot_profile_crying.png');

      expect(MascotExpression.laughing.emoji, '😄');
      expect(MascotExpression.smile.emoji, '🙂');
      expect(MascotExpression.crying.emoji, '😢');
    });

    testWidgets('ZeroPassMascotAvatar dynamically reacts to attendanceRate', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZeroPassMascotAvatar(size: 60, attendanceRate: 90),
                ZeroPassMascotAvatar(size: 60, attendanceRate: 50),
                ZeroPassMascotAvatar(size: 60, attendanceRate: 15),
              ],
            ),
          ),
        ),
      );

      expect(find.byType(ZeroPassMascotAvatar), findsNWidgets(3));
      expect(find.byType(ClipOval), findsNWidgets(3));
      expect(tester.takeException(), isNull);
    });
  });

  group('TabletKioskScreen Celebration Overflow Resilience Tests (Test Mode)', () {
    testWidgets('Kiosk check-in celebration screen renders with ZERO overflow on Galaxy Z Fold 4 outer screen (340dp width)', (tester) async {
      tester.view.physicalSize = const Size(340, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => MockEmptyMembersNotifier()),
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier()),
          ],
          child: const MaterialApp(
            home: TabletKioskScreen(isTestMode: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify "관리자 테스트 모드" banner and tap "체험 PIN 1234" to trigger celebration screen
      expect(find.text('관리자 테스트 모드'), findsOneWidget);
      final demoChip = find.text('1234');
      expect(demoChip, findsOneWidget);
      await tester.tap(demoChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify celebration screen elements are visible
      expect(find.text('김패시 학생'), findsOneWidget);
      expect(find.text('10회권 (잔여 9회)'), findsOneWidget);
      expect(find.byType(ZeroPassMascotAvatar), findsWidgets);

      // Verify absolute zero overflow
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Kiosk check-in celebration screen renders with ZERO overflow on ultra-narrow 320dp width', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => MockEmptyMembersNotifier()),
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier()),
          ],
          child: const MaterialApp(
            home: TabletKioskScreen(isTestMode: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final demoChip = find.text('1234');
      await tester.tap(demoChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('김패시 학생'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Kiosk check-in celebration screen renders with ZERO overflow in short landscape (700x340)', (tester) async {
      tester.view.physicalSize = const Size(700, 340);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => MockEmptyMembersNotifier()),
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier()),
          ],
          child: const MaterialApp(
            home: TabletKioskScreen(isTestMode: true),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final demoChip = find.text('1234');
      await tester.tap(demoChip);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('김패시 학생'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('TabletKioskScreen Mode Separation & Empty State Tests', () {
    testWidgets('Student mode with NO members renders empty state and HIDES test chips', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => MockEmptyMembersNotifier()),
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier()),
          ],
          child: const MaterialApp(
            home: TabletKioskScreen(isTestMode: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Empty state guidance should be visible
      expect(find.text('학생 데이터 없음'), findsOneWidget);
      expect(find.text('등록된 학생 데이터가 없어\n키오스크 모드를 실행할 수 없습니다'), findsOneWidget);
      expect(find.text('샘플 학생 5명 바로 등록하기'), findsOneWidget);
      expect(find.text('기능 테스트 모드로 체험하기'), findsOneWidget);

      // Demo PIN '1234' chip should NOT be visible
      expect(find.text('1234'), findsNothing);
      expect(find.text('관리자 테스트 모드'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('Switching from empty state to test mode reveals test chips and 1234', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => MockEmptyMembersNotifier()),
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier()),
          ],
          child: const MaterialApp(
            home: TabletKioskScreen(isTestMode: false),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap "기능 테스트 모드로 체험하기"
      await tester.tap(find.text('기능 테스트 모드로 체험하기'));
      await tester.pumpAndSettle();

      // Now keypad and test mode banner with 1234 chip should appear
      expect(find.text('관리자 테스트 모드'), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('Member Name & Secondary Tag Separation Tests (Two-line Prevention)', () {
    test('Member.primaryName and secondaryTag parse correctly across various formats', () {
      final now = DateTime.now();

      final m1 = Member(
        id: '1',
        name: '강지훈 (바디프로필 PT)',
        phone: '01011112222',
        groupName: 'PT 화목반',
        billingType: BillingType.sessionBased,
        defaultFee: 800000,
        totalSessions: 10,
        remainingSessions: 2,
        registeredAt: now,
      );
      expect(m1.primaryName, '강지훈');
      expect(m1.secondaryTag, '바디프로필 PT');
      expect(m1.initial, '강');

      final m2 = Member(
        id: '2',
        name: '이도현(중2 수학반)',
        phone: '01033334444',
        groupName: '수학반',
        billingType: BillingType.monthlyRecurring,
        defaultFee: 300000,
        totalSessions: 0,
        remainingSessions: 0,
        registeredAt: now,
      );
      expect(m2.primaryName, '이도현');
      expect(m2.secondaryTag, '중2 수학반');
      expect(m2.initial, '이');

      final m3 = Member(
        id: '3',
        name: '최예원 [도예 주말반]',
        phone: '01055556666',
        groupName: '도예반',
        billingType: BillingType.sessionBased,
        defaultFee: 200000,
        totalSessions: 4,
        remainingSessions: 4,
        registeredAt: now,
      );
      expect(m3.primaryName, '최예원');
      expect(m3.secondaryTag, '도예 주말반');

      final m4 = Member(
        id: '4',
        name: '정하율',
        phone: '01077778888',
        groupName: '음악반',
        billingType: BillingType.monthlyRecurring,
        defaultFee: 150000,
        totalSessions: 0,
        remainingSessions: 0,
        registeredAt: now,
      );
      expect(m4.primaryName, '정하율');
      expect(m4.secondaryTag, isNull);
    });

    testWidgets('MemberNameBadge renders pure single-line name and secondary tag without 2-line break', (tester) async {
      final member = Member(
        id: '1',
        name: '강지훈 (바디프로필 PT)',
        phone: '01011112222',
        groupName: 'PT 화목반',
        billingType: BillingType.sessionBased,
        defaultFee: 800000,
        totalSessions: 10,
        remainingSessions: 2,
        registeredAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 200, // constrained width
              child: MemberNameBadge(
                member: member,
                showGroupName: true,
              ),
            ),
          ),
        ),
      );

      expect(find.text('강지훈'), findsOneWidget);
      expect(find.text('바디프로필 PT'), findsOneWidget);
      expect(find.text('PT 화목반'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
