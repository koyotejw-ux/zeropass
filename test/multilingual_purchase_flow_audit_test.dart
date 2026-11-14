import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/pro_store_screen.dart';
import 'package:zeropass/services/localization_service.dart';
import 'package:zeropass/services/monetization_service.dart';

class _FixedLanguageNotifier extends LanguageNotifier {
  final AppLanguage _lang;
  _FixedLanguageNotifier(this._lang);
  @override
  AppLanguage build() => _lang;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await MonetizationService.instance.debugResetAll();
  });

  tearDown(() async {
    await MonetizationService.instance.debugResetAll();
  });

  final languages = [
    (AppLanguage.korean, 'ko', '한국어'),
    (AppLanguage.english, 'en', 'English'),
    (AppLanguage.japanese, 'ja', '日本語'),
    (AppLanguage.chinese, 'zh', '中文'),
    (AppLanguage.vietnamese, 'vi', 'Tiếng Việt'),
    (AppLanguage.spanish, 'es', 'Español'),
  ];

  group('Multilingual In-App Purchase Flow & Store UI Audit', () {
    for (final (lang, code, langLabel) in languages) {
      testWidgets('ProStoreScreen renders cleanly in $langLabel ($code) and handles purchase flow events', (tester) async {
        final errors = <String>[];
        final originalOnError = FlutterError.onError;
        FlutterError.onError = (details) {
          debugPrint('OVERFLOW CATCH: $details');
          errors.add(details.toString());
          originalOnError?.call(details);
        };
        addTearDown(() => FlutterError.onError = originalOnError);

        tester.view.physicalSize = const Size(1080, 2400);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        await LocalizationService.setLanguage(lang);
        final bm = MonetizationService.instance;

        await tester.pumpWidget(
          ProviderScope(
            key: UniqueKey(),
            overrides: [
              languageProvider.overrideWith(() => _FixedLanguageNotifier(lang)),
            ],
            child: const MaterialApp(
              home: ProStoreScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1. Verify Pro Store title & header in current language
        expect(errors, isEmpty, reason: 'No overflow or exception on $langLabel initial render: $errors');

        // 2. Test Pending Purchase Event localization
        await bm.processPurchaseUpdatesForTest([
          PurchaseDetails(
            productID: MonetizationService.productSubAllInOneMonthly,
            verificationData: PurchaseVerificationData(
              localVerificationData: 'test',
              serverVerificationData: 'test',
              source: 'test',
            ),
            transactionDate: null,
            status: PurchaseStatus.pending,
          ),
        ]);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(bm.getProductState(MonetizationService.productSubAllInOneMonthly), ProductPurchaseState.pending);
        expect(bm.lastStoreNotice, isNotNull);
        expect(bm.lastStoreNotice, isNotEmpty);
        expect(errors, isEmpty, reason: 'Pending notice renders cleanly in $langLabel');

        // 3. Test Purchase Success Event localization & Benefit Activation
        await bm.processPurchaseUpdatesForTest([
          PurchaseDetails(
            productID: MonetizationService.productSubAllInOneMonthly,
            verificationData: PurchaseVerificationData(
              localVerificationData: 'test',
              serverVerificationData: 'test',
              source: 'test',
            ),
            transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
            status: PurchaseStatus.purchased,
          ),
        ]);
        await tester.pumpAndSettle();

        expect(bm.isUnlimitedVip, isTrue);
        expect(bm.isAdsRemoved, isTrue);
        expect(bm.isKioskProUnlocked, isTrue);
        expect(bm.getProductState(MonetizationService.productSubAllInOneMonthly), ProductPurchaseState.active);
        expect(bm.lastStoreNotice, isNotNull);
        expect(tester.takeException(), isNull, reason: 'Purchased state renders cleanly in $langLabel');

        // 4. Test Restore Event in current language
        final restoreResult = await bm.restorePurchases(
          settleDuration: Duration.zero,
          platformRestoreOverride: () async {
            await bm.processPurchaseUpdatesForTest([
              PurchaseDetails(
                productID: MonetizationService.productSubAllInOneMonthly,
                verificationData: PurchaseVerificationData(
                  localVerificationData: 'test',
                  serverVerificationData: 'test',
                  source: 'test',
                ),
                transactionDate: DateTime.now().millisecondsSinceEpoch.toString(),
                status: PurchaseStatus.restored,
              ),
            ]);
          },
        );
        await tester.pumpAndSettle();

        expect(restoreResult.hadError, isFalse);
        expect(restoreResult.restoredCount, 1);
        expect(restoreResult.message, isNotEmpty);
        expect(tester.takeException(), isNull, reason: 'Restore flow renders cleanly in $langLabel');

        // 5. Test Cancellation Notice in current language
        await bm.processPurchaseUpdatesForTest([
          PurchaseDetails(
            productID: MonetizationService.productSubKioskMonthly,
            verificationData: PurchaseVerificationData(
              localVerificationData: 'test',
              serverVerificationData: 'test',
              source: 'test',
            ),
            transactionDate: null,
            status: PurchaseStatus.canceled,
          ),
        ]);
        await tester.pumpAndSettle();

        expect(bm.lastStoreEventType, StoreEventType.canceled);
        expect(bm.lastStoreNotice, isNotNull);
        expect(tester.takeException(), isNull, reason: 'Canceled notice renders cleanly in $langLabel');
      });
    }
  });
}
