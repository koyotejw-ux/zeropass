import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/widgets/digital_pass_card_dialog.dart';
import 'package:zeropass/widgets/attendance_notify_dialog.dart';
import 'package:zeropass/screens/pass_dashboard_screen.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/screens/member_directory_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';

class MockMembersNotifier extends MembersNotifier {
  @override
  Future<List<Member>> build() async {
    return [
      Member(
        id: 'mem_test_101',
        name: '홍길동',
        phone: '010-1234-5678',
        groupName: '초등 심화반',
        billingType: BillingType.sessionBased,
        defaultFee: 150000,
        totalSessions: 10,
        remainingSessions: 7,
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
    return StudioProfile.defaultProfile().copyWith(
      studioName: '플레이펭귄 아카데미',
      category: '유아·초등 창의미술',
      instructorName: '김대표',
    );
  }
}

class MockInvoicesNotifier extends InvoicesNotifier {
  @override
  Future<List<Invoice>> build() async {
    return [];
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  group('Digital Pass & QR Modal Widget Tests', () {
    final sampleMember = Member(
      id: 'mem_test_101',
      name: '홍길동',
      phone: '010-1234-5678',
      groupName: '초등 심화반',
      billingType: BillingType.sessionBased,
      defaultFee: 150000,
      totalSessions: 10,
      remainingSessions: 7,
      registeredAt: DateTime.now(),
    );

    final sampleStudio = StudioProfile.defaultProfile().copyWith(
      studioName: '플레이펭귄 아카데미',
      category: '유아·초등 창의미술',
      instructorName: '김대표',
    );

    testWidgets('DigitalPassCardDialog renders vector QR matrix, mascot emblem, and actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: DigitalPassCardDialog(
              member: sampleMember,
              studio: sampleStudio,
              latestRecord: PassRecord(
                id: 'rec_1',
                memberId: sampleMember.id,
                timestamp: DateTime.now(),
                status: AttendanceStatus.attended,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Header Studio Name & Pass Badge
      expect(find.text('플레이펭귄 아카데미'), findsOneWidget);
      expect(find.text('PASS'), findsOneWidget);

      // Member Info
      expect(find.text('초등 심화반'), findsOneWidget);
      expect(find.text('홍길동'), findsOneWidget);
      expect(find.text('출석 완료'), findsOneWidget);

      // Vector QR CustomPaint exists
      expect(find.byType(CustomPaint), findsWidgets);

      // QR Instruction & Phone Tail
      expect(find.text('키오스크 스캐너 또는 카메라에 비춰주세요'), findsOneWidget);
      expect(find.textContaining('5678'), findsOneWidget);

      // Sessions in RichText
      expect(find.byWidgetPredicate((w) => w is RichText && w.text.toPlainText().contains('7 / 10회')), findsOneWidget);

      // Action Buttons
      expect(find.text('카톡 / 문자 공유'), findsOneWidget);
      expect(find.byTooltip('출결패스 복사'), findsOneWidget);
    });

    testWidgets('AttendanceNotifyDialog renders refined styling and buttons', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AttendanceNotifyDialog(
              member: sampleMember,
              studio: sampleStudio,
              type: AttendanceNotifyType.checkIn,
              time: DateTime.now(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('안심 등원 알림장 발송'), findsOneWidget);
      expect(find.text('카톡 0원 전송'), findsOneWidget);
      expect(find.text('문자(SMS) 전송'), findsOneWidget);
    });
  });

  group('Universal Screen Header: Senior Mode Far-Right Rule Tests', () {
    testWidgets('PassDashboardScreen AppBar has senior icon at far right of actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

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
      await tester.pump(const Duration(milliseconds: 500));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, isNotNull);
      expect(appBar.actions!.isNotEmpty, isTrue);

      // Last action must be the Senior icon padding/button
      final lastAction = appBar.actions!.last;
      expect(lastAction, isA<Padding>());
      final paddingWidget = lastAction as Padding;
      expect(paddingWidget.child, isA<IconButton>());
      final iconButton = paddingWidget.child as IconButton;
      expect(iconButton.tooltip, '큰글씨 모드');
    });

    testWidgets('BillingLedgerScreen AppBar has senior icon at far right of actions & uses SliverPersistentHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => MockMembersNotifier()),
            invoicesProvider.overrideWith(() => MockInvoicesNotifier()),
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier()),
          ],
          child: const MaterialApp(
            home: BillingLedgerScreen(enableAutoCoachMark: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, isNotNull);
      final lastAction = appBar.actions!.last;
      expect(lastAction, isA<Padding>());
      final iconButton = (lastAction as Padding).child as IconButton;
      expect(iconButton.tooltip, '큰글씨 모드');

      // Uses CustomScrollView and pinned SliverPersistentHeader
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SliverPersistentHeader), findsOneWidget);
    });

    testWidgets('MemberDirectoryScreen AppBar has senior icon at far right of actions & uses SliverPersistentHeader', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => MockMembersNotifier()),
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier()),
          ],
          child: const MaterialApp(
            home: MemberDirectoryScreen(enableAutoCoachMark: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, isNotNull);
      final lastAction = appBar.actions!.last;
      expect(lastAction, isA<Padding>());
      final iconButton = (lastAction as Padding).child as IconButton;
      expect(iconButton.tooltip, '큰글씨 모드');

      // Uses CustomScrollView and pinned SliverPersistentHeader
      expect(find.byType(CustomScrollView), findsOneWidget);
      expect(find.byType(SliverPersistentHeader), findsOneWidget);
    });

    testWidgets('SettingsVaultScreen AppBar has senior icon at far right of actions', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier()),
          ],
          child: const MaterialApp(
            home: SettingsVaultScreen(enableAutoCoachMark: false),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));

      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.actions, isNotNull);
      final lastAction = appBar.actions!.last;
      expect(lastAction, isA<Padding>());
      final iconButton = (lastAction as Padding).child as IconButton;
      expect(iconButton.tooltip, '큰글씨 모드');
    });
  });
}
