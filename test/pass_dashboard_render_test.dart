import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/pass_dashboard_screen.dart';
import 'package:zeropass/services/localization_service.dart';

class MockMembersNotifier extends MembersNotifier {
  @override
  Future<List<Member>> build() async {
    return [
      Member(
        id: 'mem_1',
        name: '최준혁',
        phone: '01044901188',
        groupName: '유품자 2품',
        billingType: BillingType.monthlyRecurring,
        defaultFee: 190000,
        totalSessions: 1,
        remainingSessions: 1,
        registeredAt: DateTime.now(),
      ),
    ];
  }
}

class MockPassRecordsNotifier extends PassRecordsNotifier {
  @override
  Future<List<PassRecord>> build() async {
    return [];
  }
}

class MockStudioProfileNotifier extends StudioProfileNotifier {
  @override
  Future<StudioProfile> build() async {
    return StudioProfile.defaultProfile();
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  testWidgets('PassDashboardScreen renders properly with mock providers', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          membersProvider.overrideWith(() => MockMembersNotifier()),
          passRecordsProvider.overrideWith(() => MockPassRecordsNotifier()),
          studioProfileProvider.overrideWith(() => MockStudioProfileNotifier()),
        ],
        child: const MaterialApp(
          home: PassDashboardScreen(),
        ),
      ),
    );

    // Pump frames until loaded
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify Title
    expect(find.text(LocalizationService.tr('tab_pass')), findsOneWidget);
    // Verify member name rendered
    expect(find.text('최준혁'), findsOneWidget);
    // Verify essential kiosk icon button (Minimalist line icon in AppBar)
    expect(find.byTooltip('무인 키오스크 모드'), findsOneWidget);
    expect(find.byIcon(Icons.tablet_android_outlined), findsWidgets);
  });
}
