import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/pass_dashboard_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/services/coach_mark_service.dart';
import 'package:zeropass/theme/app_theme.dart';
import 'package:zeropass/widgets/senior_easy_guide_modal.dart';

class _MockStudioNotifier extends StudioProfileNotifier {
  final StudioProfile _studio;
  _MockStudioNotifier(this._studio);
  @override
  Future<StudioProfile> build() async => _studio;
}

class _MockMembersNotifier extends MembersNotifier {
  final List<Member> _members;
  _MockMembersNotifier(this._members);
  @override
  Future<List<Member>> build() async => _members;
}

class _MockPassRecordsNotifier extends PassRecordsNotifier {
  final List<PassRecord> _records;
  _MockPassRecordsNotifier([this._records = const []]);
  @override
  Future<List<PassRecord>> build() async => _records;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    await initializeDateFormatting('ko_KR', null);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      CoachMarkService.keyCheckIn: true,
      CoachMarkService.keyBillingTab: true,
      CoachMarkService.keyMemberTab: true,
      CoachMarkService.keySettingsTab: true,
      CoachMarkService.keySendInvoice: true,
      'onboarding_completed': true,
      'setup_wizard_completed': true,
    });
  });

  group('Senior Mode - Unit & Theme Tests', () {
    test('SeniorModeNotifier toggles and persists state', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(seniorModeProvider), false);

      await container.read(seniorModeProvider.notifier).toggle();
      expect(container.read(seniorModeProvider), true);

      await container.read(seniorModeProvider.notifier).setSeniorMode(false);
      expect(container.read(seniorModeProvider), false);

      await container.read(seniorModeProvider.notifier).setSeniorMode(true);
      expect(container.read(seniorModeProvider), true);
    });

    test('AppTheme.seniorTheme enforces WCAG high contrast and large text typography', () {
      final theme = AppTheme.seniorTheme;

      // Pure black text for high contrast (> 7:1)
      expect(theme.colorScheme.onSurface, const Color(0xFF000000));
      expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFFFF));
      expect(theme.primaryColor, AppTheme.seniorPrimaryBlue);

      // Large typography
      expect(theme.textTheme.headlineMedium?.fontSize, 23);
      expect(theme.textTheme.bodyLarge?.fontSize, 18);
      expect(theme.textTheme.bodyMedium?.fontSize, 16);

      // Elevated button high touch target (>= 54px height)
      final btnStyle = theme.elevatedButtonTheme.style;
      expect(btnStyle?.minimumSize?.resolve({}), const Size(64, 54));
    });
  });

  group('SeniorEasyGuideModal - Widget Tests', () {
    testWidgets('renders all 4 essential steps with friendly descriptions', (tester) async {
      tester.view.physicalSize = const Size(412, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.seniorTheme,
          home: const Scaffold(
            body: SeniorEasyGuideModal(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('어르신 원장님 큰글씨 사용 안내'), findsOneWidget);
      expect(find.text('돋보기 없이도 3초 만에 끝내는 쉬운 사용법'), findsOneWidget);
      expect(find.text('오늘 온 학생 출석 찍기'), findsOneWidget);
      expect(find.text('이번 달 수강료(회비) 문자 보내기'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('학생이나 학부모님께 바로 전화 걸기'), 100);
      expect(find.text('학생이나 학부모님께 바로 전화 걸기'), findsOneWidget);

      await tester.scrollUntilVisible(find.text('글씨 크기 및 원래 모드로 돌아가기'), 100);
      expect(find.text('글씨 크기 및 원래 모드로 돌아가기'), findsOneWidget);
      expect(find.text('확인했습니다 (닫기)'), findsOneWidget);
    });
  });

  group('Senior Mode - Screen Integration Tests', () {
    testWidgets('PassDashboardScreen renders Senior Easy Board when senior mode is ON', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final dummyMembers = [
        Member(
          id: 'mem_1',
          name: '김서연',
          phone: '01011112222',
          groupName: '피아노 기초반',
          billingType: BillingType.monthlyRecurring,
          defaultFee: 150000,
          totalSessions: 0,
          remainingSessions: 0,
          payerName: '김민수',
          registeredAt: DateTime.now().subtract(const Duration(days: 30)),
        ),
        Member(
          id: 'mem_2',
          name: '이지훈',
          phone: '01033334444',
          groupName: '체르니 30',
          billingType: BillingType.monthlyRecurring,
          defaultFee: 180000,
          totalSessions: 0,
          remainingSessions: 0,
          registeredAt: DateTime.now().subtract(const Duration(days: 20)),
        ),
      ];

      final studio = StudioProfile.defaultProfile().copyWith(
        studioName: '선율 피아노 교습소',
        category: '음악 / 피아노',
        instructorName: '이선율',
      );

      final container = ProviderContainer(
        overrides: [
          studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
          membersProvider.overrideWith(() => _MockMembersNotifier(dummyMembers)),
          passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier([])),
        ],
      );
      addTearDown(container.dispose);

      // Turn senior mode ON
      await container.read(seniorModeProvider.notifier).setSeniorMode(true);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.seniorTheme,
            home: const PassDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check senior toggle in AppBar
      expect(find.byTooltip('큰글씨 모드'), findsOneWidget);

      // Check Senior 3 Core Action Board
      expect(find.text('시니어 간편 3대 업무 보드'), findsOneWidget);
      expect(find.text('간편 출석'), findsOneWidget);
      expect(find.text('회비 문자'), findsOneWidget);
      expect(find.text('바로 통화'), findsOneWidget);

      // Tap '간편 출석' action tile
      await tester.tap(find.text('간편 출석'));
      await tester.pumpAndSettle();

      // Modal sheet opens with large text
      expect(find.text('큰글씨 간편 출석 체크'), findsOneWidget);
      expect(find.text('김서연'), findsAtLeastNWidgets(1));
      expect(find.text('이지훈'), findsAtLeastNWidgets(1));
      expect(find.text('출석 확인'), findsNWidgets(2));

      // Close modal
      await tester.tap(find.byIcon(Icons.close_rounded).first);
      await tester.pumpAndSettle();
    });

    testWidgets('SettingsVaultScreen renders Senior Mode Card with toggle and guide button', (tester) async {
      tester.view.physicalSize = const Size(412, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final studio = StudioProfile.defaultProfile().copyWith(
        studioName: '선율 피아노 교습소',
      );

      final container = ProviderContainer(
        overrides: [
          studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
          membersProvider.overrideWith(() => _MockMembersNotifier([])),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: const SettingsVaultScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check Senior Mode Section in Settings (Scroll down to find section)
      await tester.scrollUntilVisible(find.text('시니어 큰글씨 모드'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('시니어 큰글씨 모드'), findsOneWidget);
      expect(find.text('큰글씨 사용 가이드 보기'), findsOneWidget);

      // Tap guide button
      await tester.tap(find.text('큰글씨 사용 가이드 보기'));
      await tester.pumpAndSettle();

      expect(find.text('어르신 원장님 큰글씨 사용 안내'), findsOneWidget);
    });
  });
}
