import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeropass/services/localization_service.dart';
import 'package:zeropass/providers/app_providers.dart';

void main() {
  setUpAll(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await Future.wait([
      initializeDateFormatting('ko_KR', null),
      initializeDateFormatting('en_US', null),
      initializeDateFormatting('ja_JP', null),
      initializeDateFormatting('zh_CN', null),
      initializeDateFormatting('vi_VN', null),
      initializeDateFormatting('es_ES', null),
    ]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocalizationService.initialize();
    await LocalizationService.setLanguage(AppLanguage.korean, persist: false);
    await LocalizationService.setCurrency(AppCurrency.krw, persist: false);
  });

  group('Global Localization & Country Currency Policy Tests', () {
    test('1. AppLanguage covers all 6 key global regions with correct metadata', () {
      expect(AppLanguage.values.length, 6);
      expect(AppLanguage.fromCode('ko'), AppLanguage.korean);
      expect(AppLanguage.fromCode('en'), AppLanguage.english);
      expect(AppLanguage.fromCode('ja'), AppLanguage.japanese);
      expect(AppLanguage.fromCode('zh'), AppLanguage.chinese);
      expect(AppLanguage.fromCode('vi'), AppLanguage.vietnamese);
      expect(AppLanguage.fromCode('es'), AppLanguage.spanish);
      expect(AppLanguage.fromCode('unknown'), AppLanguage.korean); // fallback

      expect(AppLanguage.korean.flag, '🇰🇷');
      expect(AppLanguage.english.flag, '🇺🇸');
      expect(AppLanguage.japanese.flag, '🇯🇵');
      expect(AppLanguage.chinese.flag, '🇨🇳');
      expect(AppLanguage.vietnamese.flag, '🇻🇳');
      expect(AppLanguage.spanish.flag, '🇪🇸');
    });

    test('2. AppCurrency supports 10 global financial currencies with tax policies', () {
      expect(AppCurrency.values.length, 10);

      // Check decimal places and formatting
      expect(AppCurrency.krw.decimalPlaces, 0);
      expect(AppCurrency.krw.format(160000), '₩160,000');
      expect(AppCurrency.krw.taxPolicy, contains('국세청'));

      expect(AppCurrency.usd.decimalPlaces, 2);
      expect(AppCurrency.usd.format(150), r'$150.00');
      expect(AppCurrency.usd.taxPolicy, contains('IRS'));

      expect(AppCurrency.jpy.decimalPlaces, 0);
      expect(AppCurrency.jpy.format(15000), '¥15,000');
      expect(AppCurrency.jpy.taxPolicy, contains('国税庁'));

      expect(AppCurrency.cny.decimalPlaces, 2);
      expect(AppCurrency.cny.format(880), '¥880.00');
      expect(AppCurrency.cny.taxPolicy, contains('国家税务总局'));

      expect(AppCurrency.vnd.decimalPlaces, 0);
      expect(AppCurrency.vnd.format(2500000), '2,500,000 ₫');
      expect(AppCurrency.vnd.taxPolicy, contains('Tổng cục Thuế'));

      expect(AppCurrency.eur.decimalPlaces, 2);
      expect(AppCurrency.eur.format(120), '€120.00');
      expect(AppCurrency.eur.taxPolicy, contains('EU VAT'));

      expect(AppCurrency.gbp.decimalPlaces, 2);
      expect(AppCurrency.gbp.format(110), '£110.00');
      expect(AppCurrency.gbp.taxPolicy, contains('HMRC'));

      expect(AppCurrency.sgd.decimalPlaces, 2);
      expect(AppCurrency.sgd.format(180), r'S$180.00');
      expect(AppCurrency.sgd.taxPolicy, contains('IRAS'));

      expect(AppCurrency.aud.decimalPlaces, 2);
      expect(AppCurrency.aud.format(175), r'A$175.00');
      expect(AppCurrency.aud.taxPolicy, contains('ATO'));

      expect(AppCurrency.cad.decimalPlaces, 2);
      expect(AppCurrency.cad.format(165), r'C$165.00');
      expect(AppCurrency.cad.taxPolicy, contains('CRA'));
    });

    test('3. defaultForLanguage maps each language to its primary domestic currency', () {
      expect(AppCurrency.defaultForLanguage(AppLanguage.korean), AppCurrency.krw);
      expect(AppCurrency.defaultForLanguage(AppLanguage.english), AppCurrency.usd);
      expect(AppCurrency.defaultForLanguage(AppLanguage.japanese), AppCurrency.jpy);
      expect(AppCurrency.defaultForLanguage(AppLanguage.chinese), AppCurrency.cny);
      expect(AppCurrency.defaultForLanguage(AppLanguage.vietnamese), AppCurrency.vnd);
      expect(AppCurrency.defaultForLanguage(AppLanguage.spanish), AppCurrency.eur);
    });

    test('4. LocalizationService translates all core tabs across all 6 languages', () {
      final tabs = ['tab_pass', 'tab_billing', 'tab_tax_expense', 'tab_members', 'tab_settings'];

      for (final lang in AppLanguage.values) {
        LocalizationService.setLanguage(lang, persist: false);
        for (final tab in tabs) {
          final translated = LocalizationService.tr(tab);
          expect(translated.isNotEmpty, isTrue);
          expect(translated, isNot(tab)); // Must not return raw key
        }
      }
    });

    test('5. LocalizationService formats header date and calendar dates per locale', () {
      final sampleDate = DateTime(2026, 11, 9); // Monday

      LocalizationService.setLanguage(AppLanguage.korean, persist: false);
      expect(LocalizationService.formatHeaderDate(sampleDate), contains('11월 9일'));
      expect(LocalizationService.formatDate(sampleDate), '2026.11.09');

      LocalizationService.setLanguage(AppLanguage.english, persist: false);
      expect(LocalizationService.formatHeaderDate(sampleDate), contains('Nov 9'));
      expect(LocalizationService.formatDate(sampleDate), 'Nov 9, 2026');

      LocalizationService.setLanguage(AppLanguage.japanese, persist: false);
      expect(LocalizationService.formatHeaderDate(sampleDate), contains('11月9日'));
      expect(LocalizationService.formatDate(sampleDate), '2026.11.09');

      LocalizationService.setLanguage(AppLanguage.chinese, persist: false);
      expect(LocalizationService.formatHeaderDate(sampleDate), contains('11月9日'));
      expect(LocalizationService.formatDate(sampleDate), '2026.11.09');

      LocalizationService.setLanguage(AppLanguage.vietnamese, persist: false);
      expect(LocalizationService.formatHeaderDate(sampleDate), contains('09/11'));
      expect(LocalizationService.formatDate(sampleDate), '09/11/2026');

      LocalizationService.setLanguage(AppLanguage.spanish, persist: false);
      expect(LocalizationService.formatHeaderDate(sampleDate), contains('9 nov'));
      expect(LocalizationService.formatDate(sampleDate), '09/11/2026');
    });

    testWidgets('6. Riverpod LanguageNotifier and CurrencyNotifier reactively update state and persist', (tester) async {
      final container = ProviderScope(
        child: Consumer(
          builder: (context, ref, child) {
            final lang = ref.watch(languageProvider);
            final cur = ref.watch(currencyProvider);
            return Directionality(
              textDirection: TextDirection.ltr,
              child: Column(
                children: [
                  Text('LANG:${lang.code}'),
                  Text('CUR:${cur.code}'),
                ],
              ),
            );
          },
        ),
      );

      await tester.pumpWidget(container);
      expect(find.text('LANG:ko'), findsOneWidget);
      expect(find.text('CUR:KRW'), findsOneWidget);

      final element = tester.element(find.byType(Column));
      final containerRef = ProviderScope.containerOf(element);

      // Switch language to Japanese with autoUpdateCurrency
      await containerRef.read(languageProvider.notifier).setLanguage(
        AppLanguage.japanese,
        autoUpdateCurrency: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('LANG:ja'), findsOneWidget);
      expect(find.text('CUR:JPY'), findsOneWidget);

      // Switch language to English with autoUpdateCurrency
      await containerRef.read(languageProvider.notifier).setLanguage(
        AppLanguage.english,
        autoUpdateCurrency: true,
      );
      await tester.pumpAndSettle();

      expect(find.text('LANG:en'), findsOneWidget);
      expect(find.text('CUR:USD'), findsOneWidget);
    });
  });
}
