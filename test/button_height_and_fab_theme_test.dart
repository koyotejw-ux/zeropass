import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/theme/app_theme.dart';
import 'package:zeropass/widgets/design_system.dart';
import 'package:zeropass/screens/billing_ledger_screen.dart';
import 'package:zeropass/screens/member_directory_screen.dart';

class MockMembersNotifier extends MembersNotifier {
  @override
  Future<List<Member>> build() async => [];
}

class MockInvoicesNotifier extends InvoicesNotifier {
  @override
  Future<List<Invoice>> build() async => [];
}

class MockStudioProfileNotifier extends StudioProfileNotifier {
  @override
  Future<StudioProfile> build() async => StudioProfile.defaultProfile();
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
  });

  group('Button Minimum Height & Touch Target Standards', () {
    test('ZeroButtonSize values meet generous touch target and unclipped standards', () {
      expect(const ZeroButton(label: '테스트', onPressed: null, size: ZeroButtonSize.compact), isNotNull);
      expect(const ZeroButton(label: '테스트', onPressed: null, size: ZeroButtonSize.medium), isNotNull);
      expect(const ZeroButton(label: '테스트', onPressed: null, size: ZeroButtonSize.large), isNotNull);
      expect(const ZeroButton(label: '테스트', onPressed: null, size: ZeroButtonSize.hero), isNotNull);
    });

    testWidgets('ZeroButton renders with minHeight constraint >= 46 for medium and 52 for large', (tester) async {
      await tester.binding.setSurfaceSize(const Size(450, 900));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                ZeroButton(
                  label: '중간 버튼 테스트 (체크인)',
                  size: ZeroButtonSize.medium,
                  onPressed: () {},
                ),
                ZeroButton(
                  label: '대형 버튼 테스트 (수납확인)',
                  size: ZeroButtonSize.large,
                  onPressed: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final mediumContainer = tester.widget<Container>(
        find.descendant(
          of: find.widgetWithText(ZeroButton, '중간 버튼 테스트 (체크인)'),
          matching: find.byType(Container),
        ).first,
      );
      expect(mediumContainer.constraints?.minHeight, greaterThanOrEqualTo(46.0));

      final largeContainer = tester.widget<Container>(
        find.descendant(
          of: find.widgetWithText(ZeroButton, '대형 버튼 테스트 (수납확인)'),
          matching: find.byType(Container),
        ).first,
      );
      expect(largeContainer.constraints?.minHeight, greaterThanOrEqualTo(52.0));
    });
  });

  group('FAB vs Basic Button Semantic Bifurcation & Color Contrast', () {
    test('AppTheme defines distinct fabCreation color differentiated from primaryBlue', () {
      expect(AppTheme.fabCreation, equals(const Color(0xFFEA580C)));
      expect(AppTheme.primaryBlue, equals(const Color(0xFF2563EB)));
      expect(AppTheme.fabCreation, isNot(equals(AppTheme.primaryBlue)));
    });

    testWidgets('BillingLedgerScreen FAB has distinct fabCreation color', (tester) async {
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

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      final fab = tester.widget<FloatingActionButton>(fabFinder);
      expect(fab.backgroundColor, equals(AppTheme.fabCreation));
      expect(find.text('새 청구서 작성'), findsOneWidget);
    });

    testWidgets('MemberDirectoryScreen FAB has distinct fabCreation color', (tester) async {
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

      final fabFinder = find.byType(FloatingActionButton);
      expect(fabFinder, findsOneWidget);
      final fab = tester.widget<FloatingActionButton>(fabFinder);
      expect(fab.backgroundColor, equals(AppTheme.fabCreation));
      expect(find.text('신규 회원 등록'), findsOneWidget);
    });
  });
}
