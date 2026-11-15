import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/home_navigation_screen.dart';
import 'package:zeropass/services/coach_mark_service.dart';
import 'package:zeropass/services/monetization_service.dart';
import 'package:zeropass/theme/app_theme.dart';

class _MockStudioNotifier extends StudioProfileNotifier {
  @override
  Future<StudioProfile> build() async => StudioProfile.defaultProfile();
}

class _MockMembersNotifier extends MembersNotifier {
  @override
  Future<List<Member>> build() async => [
        Member(
          id: 'm1',
          name: '김회원',
          phone: '010-1234-5678',
          groupName: '기본반',
          registeredAt: DateTime.now(),
          billingType: BillingType.monthlyRecurring,
          defaultFee: 150000,
          totalSessions: 0,
          remainingSessions: 0,
        ),
      ];
}

class _MockInvoicesNotifier extends InvoicesNotifier {
  @override
  Future<List<Invoice>> build() async => [
        Invoice(
          id: 'inv1',
          memberIds: ['m1'],
          recipientPhone: '010-1234-5678',
          title: '11월 수강료',
          amount: 150000,
          dueDate: DateTime.now(),
          status: PaymentStatus.unpaid,
        ),
      ];
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
      CoachMarkService.keyBillingTab: true,
      CoachMarkService.keyCheckIn: true,
      CoachMarkService.keyMemberTab: true,
      CoachMarkService.keySettingsTab: true,
      'is_ads_removed': true,
    });
  });

  testWidgets('Toggle Senior Mode in Billing Tab should not throw GlobalKey ink renderer error', (tester) async {
    final container = ProviderContainer(
      overrides: [
        studioProfileProvider.overrideWith(() => _MockStudioNotifier()),
        membersProvider.overrideWith(() => _MockMembersNotifier()),
        invoicesProvider.overrideWith(() => _MockInvoicesNotifier()),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) {
            final isSeniorMode = ref.watch(seniorModeProvider);
            return MaterialApp(
              theme: isSeniorMode ? AppTheme.seniorTheme : AppTheme.lightTheme,
              home: const HomeNavigationScreen(),
            );
          },
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));

    // 1. Switch to Billing tab (index 1)
    await tester.tap(find.byIcon(Icons.receipt_long_outlined));
    await tester.pump(const Duration(milliseconds: 500));

    // 2. Tap senior mode toggle (Icons.format_size_rounded)
    final formatIconFinder = find.byIcon(Icons.format_size_rounded);
    expect(formatIconFinder, findsOneWidget);

    await tester.tap(formatIconFinder);
    await tester.pump(const Duration(milliseconds: 500));

    // Verify senior mode is ON
    expect(container.read(seniorModeProvider), true);

    // 3. Tap senior mode toggle again to turn OFF
    await tester.tap(formatIconFinder);
    await tester.pump(const Duration(milliseconds: 500));

    // Verify senior mode is OFF
    expect(container.read(seniorModeProvider), false);

    // 4. Toggle back and forth 3 times
    for (int i = 0; i < 3; i++) {
      await tester.tap(formatIconFinder);
      await tester.pump(const Duration(milliseconds: 500));
    }
  });
}
