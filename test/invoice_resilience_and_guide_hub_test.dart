import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/screens/pro_store_screen.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';

class MockMembersNotifier extends MembersNotifier {
  @override
  Future<List<Member>> build() async => [];
}

class MockInvoicesNotifier extends InvoicesNotifier {
  @override
  Future<List<Invoice>> build() async => [];
}

class MockStudioProfileNotifier extends StudioProfileNotifier {
  final StudioProfile mockProfile;
  MockStudioProfileNotifier(this.mockProfile);

  @override
  Future<StudioProfile> build() async {
    return mockProfile;
  }
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  group('Billing & Quick Invoice Resilience Tests', () {
    test('Direct member creation generates valid Member with single-line primaryName', () {
      final directMember = Member(
        id: 'mem_direct_test',
        name: '박서준 (신규 상담)',
        phone: '010-9876-5432',
        groupName: '일반',
        billingType: BillingType.monthlyRecurring,
        defaultFee: 250000,
        totalSessions: 0,
        remainingSessions: 0,
        registeredAt: DateTime.now(),
      );

      expect(directMember.primaryName, equals('박서준'));
      expect(directMember.secondaryTag, equals('신규 상담'));
      expect(directMember.phone, equals('010-9876-5432'));
      expect(directMember.defaultFee, equals(250000));
    });

    test('Invoice model handles direct member ID without requiring pre-existing member in store', () {
      final invoice = Invoice(
        id: 'inv_direct_1',
        memberIds: ['mem_direct_test'],
        recipientPhone: '01098765432',
        title: '박서준 11월 수강료 안내',
        amount: 250000,
        dueDate: DateTime.now().add(const Duration(days: 7)),
        status: PaymentStatus.unpaid,
      );

      expect(invoice.memberIds, contains('mem_direct_test'));
      expect(invoice.amount, equals(250000));
      expect(invoice.status, equals(PaymentStatus.unpaid));
      expect(invoice.recipientPhone, equals('01098765432'));
    });
  });

  group('Settings & Vault Screen UI Architecture Tests', () {
    testWidgets('SettingsVaultScreen renders Studio Profile and Security Vault prior to Guide Center', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final profile = StudioProfile.defaultProfile().copyWith(
        studioName: '마스터 아카데미',
        category: '학원/교습소',
        instructorName: '김원장',
        bankName: '국민은행',
        accountNumber: '123-456-789012',
        accountHolder: '김원장',
        autoBankDetectEnabled: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier(profile)),
          ],
          child: const MaterialApp(
            home: SettingsVaultScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();
      if (find.text('안심하고 사용할게요').evaluate().isNotEmpty) {
        await tester.tap(find.text('안심하고 사용할게요'));
        await tester.pumpAndSettle();
      }

      // Check top title (synchronized with bottom nav label '운영·설정')
      expect(find.text('운영·설정'), findsOneWidget);

      // 1. Studio Profile Card is rendered
      expect(find.text('마스터 아카데미'), findsWidgets);
      expect(find.textContaining('김원장'), findsWidgets);
      await tester.scrollUntilVisible(
        find.textContaining('프로필'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('프로필'), findsWidgets);

      // 2. Local Data Vault is rendered
      await tester.scrollUntilVisible(
        find.textContaining('로컬 데이터 보안 금고'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('로컬 데이터 보안 금고'), findsOneWidget);

      // Tap Data Vault tile to open bottom sheet
      await tester.tap(find.textContaining('로컬 데이터 보안 금고'));
      await tester.pumpAndSettle();
      expect(find.textContaining('로컬 백업 파일 생성'), findsOneWidget);

      // Close bottom sheet
      Navigator.pop(tester.element(find.textContaining('로컬 백업 파일 생성')));
      await tester.pumpAndSettle();

      // Scroll to Bank Push Security
      await tester.scrollUntilVisible(
        find.textContaining('금융 푸시 필터 보안 설정'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('금융 푸시 필터 보안 설정'), findsOneWidget);

      // Scroll down to reveal Guide Center tile if needed
      await tester.scrollUntilVisible(
        find.textContaining('원장님 실전 가이드 센터'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // 6. Consolidated Guide Center representative tile is rendered
      expect(find.textContaining('원장님 실전 가이드 센터'), findsOneWidget);

      // Verify tapping opens the consolidated guide bottom sheet
      await tester.tap(find.textContaining('원장님 실전 가이드 센터'));
      await tester.pumpAndSettle();

      // Inside bottom sheet modal:
      expect(find.text('스텝바이스텝 4단계 실전 연습 가이드'), findsOneWidget);
      expect(find.text('초간단 3단계 핵심 이용 가이드'), findsOneWidget);
      expect(find.text('원클릭 업종 프리셋 전환'), findsOneWidget);
      expect(find.text('매장 셋업 위저드 다시 실행'), findsOneWidget);
      expect(find.text('자주 묻는 질문 (FAQ)'), findsOneWidget);

      // Verify that redundant PRO Store section was removed from Settings
      Navigator.pop(tester.element(find.text('스텝바이스텝 4단계 실전 연습 가이드')));
      await tester.pumpAndSettle();
      expect(find.textContaining('체크앤페이 PRO 멤버십'), findsNothing);
    });
  });

  group('ProStoreScreen & Visual Hierarchy Tests', () {
    testWidgets('ProStoreScreen renders 3 subscription plans with high readability and unified styling', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        const MaterialApp(
          home: ProStoreScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('프로샵'), findsOneWidget);
      expect(find.text('구독 복원'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('올인원 VIP 패키지 구독 (추천)'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('올인원 VIP 패키지 구독 (추천)'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('태블릿 키오스크 단독 구독'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('태블릿 키오스크 단독 구독'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('광고 제거 단독 구독'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('광고 제거 단독 구독'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('정기 구독 안내 및 해지 방법'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      expect(find.text('정기 구독 안내 및 해지 방법'), findsOneWidget);
    });

    testWidgets('BillingLedgerScreen renders empty state OutlinedButton avoiding conflict with FAB', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            membersProvider.overrideWith(() => MockMembersNotifier()),
            invoicesProvider.overrideWith(() => MockInvoicesNotifier()),
            studioProfileProvider.overrideWith(() => MockStudioProfileNotifier(StudioProfile.defaultProfile())),
          ],
          child: const MaterialApp(
            home: BillingLedgerScreen(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Check that empty state center button is an OutlinedButton, NOT ElevatedButton
      final outlinedBtnFinder = find.widgetWithText(OutlinedButton, '첫 청구서 작성하기');
      expect(outlinedBtnFinder, findsOneWidget);

      // Check that FAB is FloatingActionButton.extended with '새 청구서 작성'
      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      expect(find.text('새 청구서 작성'), findsOneWidget);
    });
  });
}
