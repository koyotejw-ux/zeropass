import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/vendor.dart';
import 'package:zeropass/models/expense_item.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/home_navigation_screen.dart';
import 'package:zeropass/screens/pass_dashboard_screen.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/screens/member_directory_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/services/coach_mark_service.dart';
import 'package:zeropass/services/localization_service.dart';
import 'package:zeropass/theme/app_theme.dart';

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

class _MockInvoicesNotifier extends InvoicesNotifier {
  final List<Invoice> _invoices;
  _MockInvoicesNotifier([this._invoices = const []]);
  @override
  Future<List<Invoice>> build() async => _invoices;
}

class _MockVendorsNotifier extends VendorsNotifier {
  @override
  Future<List<Vendor>> build() async => [];
}

class _MockExpensesNotifier extends ExpensesNotifier {
  @override
  Future<List<ExpenseItem>> build() async => [];
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

  const languages = ['ko', 'en', 'ja', 'zh', 'vi', 'es'];

  final dummyMembers = [
    Member(
      id: 'mem_1',
      name: '홍길동 Alejandro Rodriguez',
      phone: '010-1234-5678',
      groupName: '초등 심화반 Entrenamiento intensivo',
      billingType: BillingType.monthlyRecurring,
      defaultFee: 150000,
      totalSessions: 10,
      remainingSessions: 7,
      registeredAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    Member(
      id: 'mem_2',
      name: 'Trần Thị Thu Trang',
      phone: '091-998-1234',
      groupName: 'Lớp Nhạc cuối tuần',
      billingType: BillingType.monthlyRecurring,
      defaultFee: 200000,
      totalSessions: 10,
      remainingSessions: 5,
      registeredAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
  ];

  final studio = StudioProfile.defaultProfile().copyWith(
    studioName: '플레이펭귄 아카데미 Centro de Entrenamiento Internacional',
    category: '피트니스 / PT',
    instructorName: '김대표 Director General',
  );

  final dummyInvoices = [
    Invoice(
      id: 'inv_1',
      memberIds: const ['mem_1'],
      recipientPhone: '010-1234-5678',
      title: '11월 정기 회비 Cuota mensual de membresía deportiva',
      amount: 150000,
      dueDate: DateTime.now().add(const Duration(days: 7)),
      status: PaymentStatus.unpaid,
    ),
  ];

  for (final lang in languages) {
    testWidgets('HomeNavigationScreen & NavigationBar senior mode overflow audit ($lang)', (tester) async {
      final errors = <String>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final str = details.toString();
        if (str.contains('overflow') || str.contains('RenderFlex')) {
          errors.add(details.summary.toString());
        }
        originalOnError?.call(details);
      };

      try {
        tester.view.physicalSize = const Size(360, 780); // narrow phone viewport
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
            membersProvider.overrideWith(() => _MockMembersNotifier(dummyMembers)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier([])),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier(dummyInvoices)),
            vendorsProvider.overrideWith(() => _MockVendorsNotifier()),
            expensesProvider.overrideWith(() => _MockExpensesNotifier()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(languageProvider.notifier).setLanguage(AppLanguage.fromCode(lang));
        await container.read(seniorModeProvider.notifier).setSeniorMode(true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.seniorTheme,
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.25,
                maxScaleFactor: 1.55,
                child: child!,
              ),
              home: const HomeNavigationScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(errors, isEmpty, reason: 'RenderFlex overflow in HomeNavigationScreen ($lang): $errors');
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('PassDashboardScreen senior mode overflow audit ($lang)', (tester) async {
      final errors = <String>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final str = details.toString();
        if (str.contains('overflow') || str.contains('RenderFlex')) {
          errors.add(details.summary.toString());
        }
        originalOnError?.call(details);
      };

      try {
        tester.view.physicalSize = const Size(390, 844); // standard phone size
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
            membersProvider.overrideWith(() => _MockMembersNotifier(dummyMembers)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier([])),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier(dummyInvoices)),
            vendorsProvider.overrideWith(() => _MockVendorsNotifier()),
            expensesProvider.overrideWith(() => _MockExpensesNotifier()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(languageProvider.notifier).setLanguage(AppLanguage.fromCode(lang));
        await container.read(seniorModeProvider.notifier).setSeniorMode(true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.seniorTheme,
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.25,
                maxScaleFactor: 1.55,
                child: child!,
              ),
              home: const PassDashboardScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(errors, isEmpty, reason: 'RenderFlex overflow in PassDashboardScreen ($lang): $errors');

        // Test opening Senior Attendance Sheet
        final attendanceTile = find.text(LocalizationService.tr('senior_attendance'));
        if (attendanceTile.evaluate().isNotEmpty) {
          await tester.ensureVisible(attendanceTile);
          await tester.tap(attendanceTile);
          await tester.pumpAndSettle();
          expect(errors, isEmpty, reason: 'RenderFlex overflow in Senior Attendance Sheet ($lang): $errors');
          await tester.tap(find.byIcon(Icons.close_rounded).first);
          await tester.pumpAndSettle();
        }

        // Test opening Senior Billing Sheet
        final billingTile = find.text(LocalizationService.tr('senior_billing'));
        if (billingTile.evaluate().isNotEmpty) {
          await tester.ensureVisible(billingTile);
          await tester.tap(billingTile);
          await tester.pumpAndSettle();
          expect(errors, isEmpty, reason: 'RenderFlex overflow in Senior Billing Sheet ($lang): $errors');
          await tester.tap(find.byIcon(Icons.close_rounded).first);
          await tester.pumpAndSettle();
        }

        // Test opening Senior Call Sheet
        final callTile = find.text(LocalizationService.tr('senior_call'));
        if (callTile.evaluate().isNotEmpty) {
          await tester.ensureVisible(callTile);
          await tester.tap(callTile);
          await tester.pumpAndSettle();
          expect(errors, isEmpty, reason: 'RenderFlex overflow in Senior Call Sheet ($lang): $errors');
          await tester.tap(find.byIcon(Icons.close_rounded).first);
          await tester.pumpAndSettle();
        }
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('BillingLedgerScreen senior mode overflow audit ($lang)', (tester) async {
      final errors = <String>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final str = details.toString();
        if (str.contains('overflow') || str.contains('RenderFlex')) {
          errors.add(details.summary.toString());
        }
        originalOnError?.call(details);
      };

      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
            membersProvider.overrideWith(() => _MockMembersNotifier(dummyMembers)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier([])),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier(dummyInvoices)),
            vendorsProvider.overrideWith(() => _MockVendorsNotifier()),
            expensesProvider.overrideWith(() => _MockExpensesNotifier()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(languageProvider.notifier).setLanguage(AppLanguage.fromCode(lang));
        await container.read(seniorModeProvider.notifier).setSeniorMode(true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.seniorTheme,
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.25,
                maxScaleFactor: 1.55,
                child: child!,
              ),
              home: const BillingLedgerScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(errors, isEmpty, reason: 'RenderFlex overflow in BillingLedgerScreen ($lang): $errors');
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('MemberDirectoryScreen senior mode overflow audit ($lang)', (tester) async {
      final errors = <String>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final str = details.toString();
        if (str.contains('overflow') || str.contains('RenderFlex')) {
          errors.add(details.summary.toString());
        }
        originalOnError?.call(details);
      };

      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
            membersProvider.overrideWith(() => _MockMembersNotifier(dummyMembers)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier([])),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier(dummyInvoices)),
            vendorsProvider.overrideWith(() => _MockVendorsNotifier()),
            expensesProvider.overrideWith(() => _MockExpensesNotifier()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(languageProvider.notifier).setLanguage(AppLanguage.fromCode(lang));
        await container.read(seniorModeProvider.notifier).setSeniorMode(true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.seniorTheme,
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.25,
                maxScaleFactor: 1.55,
                child: child!,
              ),
              home: const MemberDirectoryScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(errors, isEmpty, reason: 'RenderFlex overflow in MemberDirectoryScreen ($lang): $errors');
      } finally {
        FlutterError.onError = originalOnError;
      }
    });

    testWidgets('SettingsVaultScreen senior mode overflow audit ($lang)', (tester) async {
      final errors = <String>[];
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        final str = details.toString();
        if (str.contains('overflow') || str.contains('RenderFlex')) {
          errors.add(details.summary.toString());
        }
        originalOnError?.call(details);
      };

      try {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final container = ProviderContainer(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
            membersProvider.overrideWith(() => _MockMembersNotifier(dummyMembers)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier([])),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier(dummyInvoices)),
            vendorsProvider.overrideWith(() => _MockVendorsNotifier()),
            expensesProvider.overrideWith(() => _MockExpensesNotifier()),
          ],
        );
        addTearDown(container.dispose);

        await container.read(languageProvider.notifier).setLanguage(AppLanguage.fromCode(lang));
        await container.read(seniorModeProvider.notifier).setSeniorMode(true);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AppTheme.seniorTheme,
              builder: (context, child) => MediaQuery.withClampedTextScaling(
                minScaleFactor: 1.25,
                maxScaleFactor: 1.55,
                child: child!,
              ),
              home: const SettingsVaultScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(errors, isEmpty, reason: 'RenderFlex overflow in SettingsVaultScreen ($lang): $errors');
      } finally {
        FlutterError.onError = originalOnError;
      }
    });
  }
}
