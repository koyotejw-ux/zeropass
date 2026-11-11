import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:zeropass/models/expense_item.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/notification_log.dart';
import 'package:zeropass/models/pass_record.dart';
import 'package:zeropass/models/schedule_item.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/models/vendor.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/screens/member_directory_screen.dart';
import 'package:zeropass/screens/onboarding_screen.dart';
import 'package:zeropass/screens/pass_dashboard_screen.dart';
import 'package:zeropass/screens/pro_store_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/screens/studio_setup_wizard_screen.dart';
import 'package:zeropass/screens/tablet_kiosk_screen.dart';
import 'package:zeropass/services/data_vault_service.dart';
import 'package:zeropass/services/database_service.dart';
import 'package:zeropass/services/kakao_share_service.dart';
import 'package:zeropass/services/localization_service.dart';
import 'package:zeropass/services/region_workflow_service.dart';
import 'package:zeropass/services/sequential_dispatch_service.dart';
import 'package:zeropass/services/sms_template_service.dart';
import 'package:zeropass/services/starter_preset_service.dart';
import 'package:zeropass/widgets/region_language_picker.dart';
import 'package:zeropass/widgets/schedule_calendar_modal.dart';
import 'package:zeropass/widgets/smart_notification_center_modal.dart';
import 'package:zeropass/widgets/tax_guide_modal.dart';

class _FixedLanguageNotifier extends LanguageNotifier {
  final AppLanguage _lang;
  _FixedLanguageNotifier(this._lang);
  @override
  AppLanguage build() => _lang;
}

class _FixedCurrencyNotifier extends CurrencyNotifier {
  final AppCurrency _cur;
  _FixedCurrencyNotifier(this._cur);
  @override
  AppCurrency build() => _cur;
}

class _MockStudioNotifier extends StudioProfileNotifier {
  final StudioProfile _profile;
  _MockStudioNotifier(this._profile);
  @override
  Future<StudioProfile> build() async => _profile;
}

class _MockMembersNotifier extends MembersNotifier {
  final List<Member> _members;
  _MockMembersNotifier(this._members);
  @override
  Future<List<Member>> build() async => _members;

  @override
  Future<void> reload() async {}
}

class _MockPassRecordsNotifier extends PassRecordsNotifier {
  @override
  Future<List<PassRecord>> build() async => [];

  @override
  Future<void> checkInMember({
    required Member member,
    AttendanceStatus status = AttendanceStatus.attended,
    bool triggerAd = true,
  }) async {}

  @override
  Future<void> reload() async {}
}

class _MockInvoicesNotifier extends InvoicesNotifier {
  final List<Invoice> _invoices;
  _MockInvoicesNotifier(this._invoices);
  @override
  Future<List<Invoice>> build() async => _invoices;
}

class _MockExpensesNotifier extends ExpensesNotifier {
  @override
  Future<List<ExpenseItem>> build() async => [];
}

class _MockVendorsNotifier extends VendorsNotifier {
  @override
  Future<List<Vendor>> build() async => [];
}

class _MockSchedulesNotifier extends SchedulesNotifier {
  @override
  Future<List<ScheduleItem>> build() async => [];
}

class _MockNotificationLogsNotifier extends NotificationLogsNotifier {
  @override
  Future<List<NotificationLog>> build() async => [];
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        return Directory.systemTemp.path;
      },
    );
    await initializeDateFormatting('ko_KR', null);
    SharedPreferences.setMockInitialValues({});
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  tearDown(() async {
    await LocalizationService.setLanguage(AppLanguage.korean, persist: false);
    await LocalizationService.setCurrency(AppCurrency.krw, persist: false);
  });

  group('1. Multi-Language & Country Currency Core Workflow Tests', () {
    test('All 6 languages switch cleanly with non-empty localized keys and regional currencies', () async {
      final expectedDefaults = {
        AppLanguage.korean: AppCurrency.krw,
        AppLanguage.english: AppCurrency.usd,
        AppLanguage.japanese: AppCurrency.jpy,
        AppLanguage.chinese: AppCurrency.cny,
        AppLanguage.vietnamese: AppCurrency.vnd,
        AppLanguage.spanish: AppCurrency.eur,
      };

      for (final lang in AppLanguage.values) {
        await LocalizationService.setLanguage(lang, persist: false);
        final cur = AppCurrency.defaultForLanguage(lang);
        expect(cur, expectedDefaults[lang]);
        await LocalizationService.setCurrency(cur, persist: false);

        // Localized studio profile should never leak Korean strings when non-Korean
        final profile = StudioProfile.defaultProfile();
        expect(profile.studioName.isNotEmpty, isTrue);
        expect(profile.bankName.isNotEmpty, isTrue);

        if (lang != AppLanguage.korean) {
          final hasHangulStudio = RegExp(r'[가-힣]').hasMatch(profile.studioName);
          final hasHangulRole = RegExp(r'[가-힣]').hasMatch(profile.roleTitle);
          final hasHangulFee = RegExp(r'[가-힣]').hasMatch(profile.feeTitle);
          expect(hasHangulStudio, isFalse, reason: '${lang.code} studioName leaked Hangul: ${profile.studioName}');
          expect(hasHangulRole, isFalse, reason: '${lang.code} roleTitle leaked Hangul: ${profile.roleTitle}');
          expect(hasHangulFee, isFalse, reason: '${lang.code} feeTitle leaked Hangul: ${profile.feeTitle}');
        }

        // Core nav labels must resolve cleanly without falling back to raw key
        for (final key in ['tab_pass', 'tab_billing', 'tab_tax_expense', 'tab_members', 'tab_pro', 'tab_settings']) {
          final val = LocalizationService.tr(key);
          expect(val, isNot(equals(key)), reason: 'Key $key missing for ${lang.code}');
          expect(val.trim().isNotEmpty, isTrue);
        }

        // Currency formatting checks
        final formatted = LocalizationService.formatAmount(150);
        if (cur == AppCurrency.usd) {
          expect(formatted, contains(r'$150'));
          expect(formatted.contains('원'), isFalse);
        } else if (cur == AppCurrency.jpy) {
          expect(formatted, contains('150'));
          expect(formatted.contains('원'), isFalse);
        } else if (cur == AppCurrency.vnd) {
          expect(formatted, contains('₫'));
          expect(formatted.contains('원'), isFalse);
        }
      }
    });

    test('RegionWorkflowService gates Toss links and adjusts withholding rates by country currency', () {
      expect(RegionWorkflowService.supportsTossTransfer(AppCurrency.krw), isTrue);
      expect(RegionWorkflowService.supportsTossTransfer(AppCurrency.usd), isFalse);
      expect(RegionWorkflowService.supportsTossTransfer(AppCurrency.jpy), isFalse);
      expect(RegionWorkflowService.supportsTossTransfer(AppCurrency.eur), isFalse);
      expect(RegionWorkflowService.supportsTossTransfer(AppCurrency.vnd), isFalse);

      expect(RegionWorkflowService.defaultWithholdingRate(AppCurrency.krw), closeTo(0.033, 0.0001));
      expect(RegionWorkflowService.defaultWithholdingRate(AppCurrency.jpy), closeTo(0.1021, 0.0001));
      expect(RegionWorkflowService.defaultWithholdingRate(AppCurrency.usd), 0.0);
      expect(RegionWorkflowService.defaultWithholdingRate(AppCurrency.eur), 0.0);

      expect(RegionWorkflowService.quickIncrementAmounts(AppCurrency.usd).first, lessThan(500));
      expect(RegionWorkflowService.quickIncrementAmounts(AppCurrency.krw).first, greaterThanOrEqualTo(10000));
    });

    test('SMS, Kakao/Share & Sequential Dispatch exclude KRW-only "원" and Toss links outside Korea', () async {
      final pairs = [
        (AppLanguage.english, AppCurrency.usd, r'$'),
        (AppLanguage.japanese, AppCurrency.jpy, '¥'),
        (AppLanguage.chinese, AppCurrency.cny, '¥'),
        (AppLanguage.vietnamese, AppCurrency.vnd, '₫'),
        (AppLanguage.spanish, AppCurrency.eur, '€'),
      ];

      for (final (lang, cur, symbol) in pairs) {
        await LocalizationService.setLanguage(lang, persist: false);
        await LocalizationService.setCurrency(cur, persist: false);

        final studio = StudioProfile.defaultProfile().copyWith(
          cardPaymentEnabled: true,
          cardPaymentUrl: 'https://checkout.example.com/pay?amt={amount}&title={title}',
        );
        final member = Member(
          id: 'm_${lang.code}',
          name: 'Alex Morgan',
          phone: '+1 555 010 9999',
          groupName: 'Piano',
          billingType: BillingType.sessionBased,
          defaultFee: cur.defaultFeeBase,
          totalSessions: 10,
          remainingSessions: 2,
          registeredAt: DateTime(2026, 5, 1),
        );
        final invoice = Invoice(
          id: 'inv_${lang.code}',
          memberIds: [member.id],
          recipientPhone: member.phone,
          title: 'Monthly Tuition',
          amount: cur.defaultFeeBase,
          dueDate: DateTime(2026, 6, 15),
          status: PaymentStatus.unpaid,
        );

        final smsInvoice = SmsTemplateService.generateInvoiceMessage(
          studio: studio,
          members: [member],
          invoice: invoice,
        );
        expect(smsInvoice.contains('원'), isFalse, reason: '${lang.code} SMS leaked 원');
        expect(smsInvoice.contains('supertoss://'), isFalse, reason: '${lang.code} SMS leaked supertoss://');
        expect(smsInvoice.contains(symbol), isTrue, reason: '${lang.code} SMS missing $symbol: $smsInvoice');
        expect(smsInvoice.contains('checkout.example.com'), isTrue);

        final shareInvoice = KakaoShareService.generateInvoiceKakaoMessage(
          studio: studio,
          members: [member],
          invoice: invoice,
        );
        expect(shareInvoice.contains('원'), isFalse);
        expect(shareInvoice.contains('supertoss://'), isFalse);

        final smsReceipt = SmsTemplateService.generatePaymentReceiptMessage(
          studio: studio,
          member: member,
          amount: cur.defaultFeeBase,
          paymentMethod: 'ONLINE_CARD',
        );
        expect(smsReceipt.contains('원'), isFalse);
        expect(smsReceipt.contains(symbol), isTrue);

        final seqTemplate = SequentialDispatchService.getDefaultTemplate(DispatchTemplateType.billing);
        final seqRendered = SequentialDispatchService.renderMessage(
          template: seqTemplate,
          studio: studio,
          member: member,
          invoice: invoice,
        );
        expect(seqRendered.contains('원'), isFalse);
        expect(seqRendered.contains('supertoss://'), isFalse);
        expect(seqRendered.contains('Alex'), isTrue);
      }
    });

    test('StarterPresetService and DataVaultService CSV export adapt cleanly to US English (USD)', () async {
      await LocalizationService.setLanguage(AppLanguage.english, persist: false);
      await LocalizationService.setCurrency(AppCurrency.usd, persist: false);

      await DatabaseService.instance.clearAllData();
      await StarterPresetService.applyPreset(IndustryPreset.fitness);

      final members = await DatabaseService.instance.getMembers();
      expect(members, isNotEmpty);
      expect(RegExp(r'[가-힣]').hasMatch(members.first.name), isFalse);

      final csvFile = await DataVaultService.exportSimplifiedBookkeepingCsv();
      final csvText = await csvFile.readAsString();
      expect(csvText, contains('Tax Bookkeeping Ledger (USD)'));
      expect(csvText, contains('Revenue (USD)'));
      expect(csvText, isNot(contains('국세청 표준')));
    });
  });

  group('2. Global UI Screens & Modals Widget Verification (All Languages & Kiosk Modes)', () {
    testWidgets('TabletKioskScreen supports both 4-Digit PIN & Name Lookup in English (USD)', (tester) async {
      await LocalizationService.setLanguage(AppLanguage.english, persist: false);
      await LocalizationService.setCurrency(AppCurrency.usd, persist: false);

      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final studio = StudioProfile.defaultProfile();
      final members = [
        Member(
          id: 'us_1',
          name: 'Olivia Carter',
          phone: '5550104321',
          groupName: 'Piano',
          billingType: BillingType.sessionBased,
          defaultFee: 150,
          totalSessions: 10,
          remainingSessions: 6,
          registeredAt: DateTime(2026, 5, 1),
        ),
      ];

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            languageProvider.overrideWith(() => _FixedLanguageNotifier(AppLanguage.english)),
            currencyProvider.overrideWith(() => _FixedCurrencyNotifier(AppCurrency.usd)),
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
            membersProvider.overrideWith(() => _MockMembersNotifier(members)),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier()),
          ],
          child: const MaterialApp(
            home: TabletKioskScreen(isTestMode: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Both modes present in English
      expect(find.text('4-Digit PIN'), findsOneWidget);
      expect(find.text('Name Lookup'), findsOneWidget);

      // Switch to Name Lookup & find Olivia Carter
      await tester.tap(find.text('Name Lookup'));
      await tester.pumpAndSettle();
      expect(find.text('Olivia Carter'), findsOneWidget);

      await tester.tap(find.text('Check In').first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Olivia Carter'), findsAtLeastNWidgets(1));
      expect(find.text('Check-in Completed Successfully!'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 9));
    });

    testWidgets('Core screens & modals render with zero overflow and localized UI in English & Japanese', (tester) async {
      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final (lang, cur) in [
        (AppLanguage.english, AppCurrency.usd),
        (AppLanguage.japanese, AppCurrency.jpy),
      ]) {
        await LocalizationService.setLanguage(lang, persist: false);
        await LocalizationService.setCurrency(cur, persist: false);

        final studio = StudioProfile.defaultProfile();
        final sampleMember = Member(
          id: 'g1_${lang.code}',
          name: lang == AppLanguage.english ? 'Emma Brooks' : '田中 陽菜',
          phone: lang == AppLanguage.english ? '5550101234' : '09012345678',
          groupName: 'Class A',
          billingType: BillingType.monthlyRecurring,
          defaultFee: cur.defaultFeeBase,
          totalSessions: 0,
          remainingSessions: 0,
          registeredAt: DateTime(2026, 5, 1),
        );
        final sampleInvoice = Invoice(
          id: 'inv_g1',
          memberIds: [sampleMember.id],
          recipientPhone: sampleMember.phone,
          title: 'Monthly Fee',
          amount: cur.defaultFeeBase,
          dueDate: DateTime(2026, 6, 15),
          status: PaymentStatus.unpaid,
        );

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              languageProvider.overrideWith(() => _FixedLanguageNotifier(lang)),
              currencyProvider.overrideWith(() => _FixedCurrencyNotifier(cur)),
              studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
              membersProvider.overrideWith(() => _MockMembersNotifier([sampleMember])),
              invoicesProvider.overrideWith(() => _MockInvoicesNotifier([sampleInvoice])),
              passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier()),
            ],
            child: const MaterialApp(
              home: Scaffold(body: PassDashboardScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(LocalizationService.tr('tab_pass')), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              languageProvider.overrideWith(() => _FixedLanguageNotifier(lang)),
              currencyProvider.overrideWith(() => _FixedCurrencyNotifier(cur)),
              studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
              membersProvider.overrideWith(() => _MockMembersNotifier([sampleMember])),
              invoicesProvider.overrideWith(() => _MockInvoicesNotifier([sampleInvoice])),
              expensesProvider.overrideWith(() => _MockExpensesNotifier()),
              vendorsProvider.overrideWith(() => _MockVendorsNotifier()),
            ],
            child: const MaterialApp(
              home: Scaffold(body: BillingLedgerScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(LocalizationService.tr('billing_title')), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              languageProvider.overrideWith(() => _FixedLanguageNotifier(lang)),
              currencyProvider.overrideWith(() => _FixedCurrencyNotifier(cur)),
              studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
              membersProvider.overrideWith(() => _MockMembersNotifier([sampleMember])),
              invoicesProvider.overrideWith(() => _MockInvoicesNotifier([sampleInvoice])),
            ],
            child: const MaterialApp(
              home: Scaffold(body: MemberDirectoryScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(LocalizationService.tr('tab_members')), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              languageProvider.overrideWith(() => _FixedLanguageNotifier(lang)),
              currencyProvider.overrideWith(() => _FixedCurrencyNotifier(cur)),
              studioProfileProvider.overrideWith(() => _MockStudioNotifier(studio)),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SettingsVaultScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(LocalizationService.tr('tab_settings')), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              languageProvider.overrideWith(() => _FixedLanguageNotifier(lang)),
              currencyProvider.overrideWith(() => _FixedCurrencyNotifier(cur)),
            ],
            child: const MaterialApp(
              home: Scaffold(
                body: SizedBox(height: 850, child: TaxGuideModal()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining(cur == AppCurrency.usd ? 'IRS' : '確定申告'), findsAtLeastNWidgets(1));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('OnboardingScreen, StudioSetupWizardScreen, ProStoreScreen, Calendar & Notification Center render cleanly in English (USD)', (tester) async {
      await LocalizationService.setLanguage(AppLanguage.english, persist: false);
      await LocalizationService.setCurrency(AppCurrency.usd, persist: false);

      tester.view.physicalSize = const Size(430, 920);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // 1. Onboarding with RegionLanguageChip
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            languageProvider.overrideWith(() => _FixedLanguageNotifier(AppLanguage.english)),
            currencyProvider.overrideWith(() => _FixedCurrencyNotifier(AppCurrency.usd)),
          ],
          child: MaterialApp(
            home: OnboardingScreen(onFinish: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RegionLanguageChip), findsWidgets);
      expect(tester.takeException(), isNull);

      // 2. StudioSetupWizardScreen
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            languageProvider.overrideWith(() => _FixedLanguageNotifier(AppLanguage.english)),
            currencyProvider.overrideWith(() => _FixedCurrencyNotifier(AppCurrency.usd)),
          ],
          child: MaterialApp(
            home: StudioSetupWizardScreen(onFinish: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(RegionLanguageChip), findsWidgets);
      expect(tester.takeException(), isNull);

      // 3. ProStoreScreen
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            languageProvider.overrideWith(() => _FixedLanguageNotifier(AppLanguage.english)),
            currencyProvider.overrideWith(() => _FixedCurrencyNotifier(AppCurrency.usd)),
          ],
          child: const MaterialApp(
            home: ProStoreScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(LocalizationService.proStoreTitle), findsOneWidget);
      expect(tester.takeException(), isNull);

      // 4. ScheduleCalendarModal & SmartNotificationCenterModal
      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            languageProvider.overrideWith(() => _FixedLanguageNotifier(AppLanguage.english)),
            currencyProvider.overrideWith(() => _FixedCurrencyNotifier(AppCurrency.usd)),
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(StudioProfile.defaultProfile())),
            membersProvider.overrideWith(() => _MockMembersNotifier([])),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier([])),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier()),
            schedulesProvider.overrideWith(() => _MockSchedulesNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: ScheduleCalendarModal()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Attendance & Schedule Calendar'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(
        ProviderScope(
          key: UniqueKey(),
          overrides: [
            languageProvider.overrideWith(() => _FixedLanguageNotifier(AppLanguage.english)),
            currencyProvider.overrideWith(() => _FixedCurrencyNotifier(AppCurrency.usd)),
            studioProfileProvider.overrideWith(() => _MockStudioNotifier(StudioProfile.defaultProfile())),
            membersProvider.overrideWith(() => _MockMembersNotifier([])),
            invoicesProvider.overrideWith(() => _MockInvoicesNotifier([])),
            passRecordsProvider.overrideWith(() => _MockPassRecordsNotifier()),
            notificationLogsProvider.overrideWith(() => _MockNotificationLogsNotifier()),
          ],
          child: const MaterialApp(
            home: Scaffold(body: SmartNotificationCenterModal()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Smart Notification Center'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
