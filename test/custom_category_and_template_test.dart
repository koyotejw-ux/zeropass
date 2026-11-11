import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeropass/models/custom_category_template.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/providers/app_providers.dart';
import 'package:zeropass/screens/settings_vault_screen.dart';
import 'package:zeropass/services/custom_category_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('CustomCategoryState Model & Industry Presets Tests', () {
    test('Correctly supplies industry-specific defaults for all 6 business categories', () {
      final academy = CustomCategoryState.getDefaultsForIndustry('입시 / 보습학원');
      expect(academy.groupCategories.any((g) => g.contains('내신')), isTrue);
      expect(academy.memberTemplates.any((t) => t.label.contains('내신')), isTrue);
      expect(academy.invoiceTemplates.any((t) => t.title.contains('수강료')), isTrue);

      final fitness = CustomCategoryState.getDefaultsForIndustry('피트니스 / PT');
      expect(fitness.groupCategories.any((g) => g.contains('PT')), isTrue);
      expect(fitness.memberTemplates.any((t) => t.label.contains('PT')), isTrue);
      expect(fitness.invoiceTemplates.any((t) => t.title.contains('PT')), isTrue);

      final pilates = CustomCategoryState.getDefaultsForIndustry('필라테스 / 요가');
      expect(pilates.groupCategories.any((g) => g.contains('필라테스')), isTrue);
      expect(pilates.invoiceTemplates.any((t) => t.title.contains('기구필라테스')), isTrue);

      final taekwondo = CustomCategoryState.getDefaultsForIndustry('태권도 / 무술');
      expect(taekwondo.groupCategories.any((g) => g.contains('품새') || g.contains('수련')), isTrue);
      expect(taekwondo.invoiceTemplates.any((t) => t.title.contains('심사비')), isTrue);

      final artMusic = CustomCategoryState.getDefaultsForIndustry('음악 / 피아노');
      expect(artMusic.groupCategories.any((g) => g.contains('피아노') || g.contains('도예')), isTrue);
      expect(artMusic.invoiceTemplates.any((t) => t.title.contains('소성비') || t.title.contains('수강료')), isTrue);

      final general = CustomCategoryState.getDefaultsForIndustry('기타 / 맞춤업종');
      expect(general.groupCategories.isNotEmpty, isTrue);
      expect(general.memberTemplates.isNotEmpty, isTrue);
      expect(general.invoiceTemplates.isNotEmpty, isTrue);
    });

    test('Serialization and deserialization of CustomCategoryState preserves all fields', () {
      const state = CustomCategoryState(
        groupCategories: ['월수금 집중반', '주말 토요반'],
        memberTemplates: [
          MemberCategoryTemplate(
            id: 'tpl_1',
            label: '주말 특별반',
            groupName: '주말 토요반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 220000,
            defaultSessions: 0,
          ),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(
            id: 'inv_1',
            title: '특별 교재비',
            defaultAmount: 45000,
            category: '교재',
          ),
        ],
      );

      final map = state.toMap();
      final revived = CustomCategoryState.fromMap(map);

      expect(revived.groupCategories, equals(['월수금 집중반', '주말 토요반']));
      expect(revived.memberTemplates.first.label, equals('주말 특별반'));
      expect(revived.memberTemplates.first.defaultFee, equals(220000));
      expect(revived.invoiceTemplates.first.title, equals('특별 교재비'));
      expect(revived.invoiceTemplates.first.defaultAmount, equals(45000));
      expect(revived.invoiceTemplates.first.category, equals('교재'));
    });
  });

  group('CustomCategoryService CRUD and Persistence Tests', () {
    test('loadCategories initializes with defaults and persists', () async {
      final service = CustomCategoryService.instance;
      final loaded = await service.loadCategories(industryCategory: '피트니스 / PT');

      expect(loaded.groupCategories.any((g) => g.contains('PT')), isTrue);
      expect(loaded.invoiceTemplates.any((t) => t.title.contains('PT')), isTrue);

      // Verify it's actually in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('zeropass_custom_group_categories'), isNotNull);
      expect(prefs.getString('zeropass_custom_member_templates'), isNotNull);
      expect(prefs.getString('zeropass_custom_invoice_templates'), isNotNull);
    });

    test('addGroupCategory and removeGroupCategory work seamlessly', () async {
      final service = CustomCategoryService.instance;
      await service.resetToIndustry('입시 / 보습학원');

      final afterAdd = await service.addGroupCategory('수능 파이널 실전반');
      expect(afterAdd.groupCategories.contains('수능 파이널 실전반'), isTrue);

      // Cannot add duplicate
      final afterDup = await service.addGroupCategory('수능 파이널 실전반');
      expect(afterDup.groupCategories.where((g) => g == '수능 파이널 실전반').length, equals(1));

      // Remove
      final afterRemove = await service.removeGroupCategory('수능 파이널 실전반');
      expect(afterRemove.groupCategories.contains('수능 파이널 실전반'), isFalse);
    });

    test('saveMemberTemplate and removeMemberTemplate work seamlessly', () async {
      final service = CustomCategoryService.instance;
      await service.resetToIndustry('피트니스 / PT');

      const newTpl = MemberCategoryTemplate(
        id: 'custom_pt_50',
        label: 'VIP 50회권 (300만)',
        groupName: '1:1 VIP PT',
        billingType: BillingType.sessionBased,
        defaultFee: 3000000,
        defaultSessions: 50,
      );

      final updated = await service.saveMemberTemplate(newTpl);
      expect(updated.memberTemplates.any((t) => t.id == 'custom_pt_50'), isTrue);
      expect(updated.groupCategories.contains('1:1 VIP PT'), isTrue);

      final removed = await service.removeMemberTemplate('custom_pt_50');
      expect(removed.memberTemplates.any((t) => t.id == 'custom_pt_50'), isFalse);
    });

    test('saveInvoiceTemplate and removeInvoiceTemplate work seamlessly', () async {
      final service = CustomCategoryService.instance;
      await service.resetToIndustry('필라테스 / 요가');

      const newInvTpl = InvoiceItemTemplate(
        id: 'inv_grip_socks',
        title: '프리미엄 필라테스 토삭스',
        defaultAmount: 18000,
        category: '용품',
      );

      final updated = await service.saveInvoiceTemplate(newInvTpl);
      expect(updated.invoiceTemplates.any((t) => t.id == 'inv_grip_socks'), isTrue);

      final removed = await service.removeInvoiceTemplate('inv_grip_socks');
      expect(removed.invoiceTemplates.any((t) => t.id == 'inv_grip_socks'), isFalse);
    });

    test('renameGroupCategory and CustomMessageTemplate full CRUD work seamlessly', () async {
      final service = CustomCategoryService.instance;
      final loaded = await service.resetToIndustry('피트니스 / PT');
      expect(loaded.messageTemplates.isNotEmpty, isTrue);

      // Rename group and check member template propagation
      await service.saveMemberTemplate(const MemberCategoryTemplate(
        id: 'pt_grp_tpl',
        label: 'PT 테스트',
        groupName: '1:1 개인 PT',
        billingType: BillingType.sessionBased,
        defaultFee: 700000,
        defaultSessions: 10,
      ));
      final renamed = await service.renameGroupCategory('1:1 개인 PT', '1:1 프리미엄 PT');
      expect(renamed.groupCategories.contains('1:1 프리미엄 PT'), isTrue);
      expect(renamed.groupCategories.contains('1:1 개인 PT'), isFalse);
      expect(
        renamed.memberTemplates.firstWhere((t) => t.id == 'pt_grp_tpl').groupName,
        equals('1:1 프리미엄 PT'),
      );

      // Create custom message template
      const msgTpl = CustomMessageTemplate(
        id: 'msg_custom_holiday',
        title: '추석 연휴 휴무 안내',
        body: '[#{상호명}] #{회원명} #{고객호칭}님, 연휴 휴무 안내드립니다.',
        categoryTag: '공지',
      );
      final afterCreateMsg = await service.saveMessageTemplate(msgTpl);
      expect(afterCreateMsg.messageTemplates.any((m) => m.id == 'msg_custom_holiday'), isTrue);

      // Update custom message template
      final updatedMsg = msgTpl.copyWith(title: '설날 연휴 휴무 안내', body: '변경된 본문');
      final afterEditMsg = await service.saveMessageTemplate(updatedMsg);
      final foundMsg = afterEditMsg.messageTemplates.firstWhere((m) => m.id == 'msg_custom_holiday');
      expect(foundMsg.title, equals('설날 연휴 휴무 안내'));
      expect(foundMsg.body, equals('변경된 본문'));

      // Delete custom message template
      final afterDeleteMsg = await service.removeMessageTemplate('msg_custom_holiday');
      expect(afterDeleteMsg.messageTemplates.any((m) => m.id == 'msg_custom_holiday'), isFalse);
    });
  });

  group('UI Integration & Settings Rendering Tests', () {
    testWidgets('SettingsVaultScreen renders Custom Category section with all 4 management actions', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final container = ProviderContainer(
        overrides: [
          studioProfileProvider.overrideWith(() => _MockStudioProfileNotifier()),
          customCategoryProvider.overrideWith(() => _MockCustomCategoryNotifier()),
        ],
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SettingsVaultScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Dismiss coach mark if shown
      if (find.text('안심하고 사용할게요').evaluate().isNotEmpty) {
        await tester.tap(find.text('안심하고 사용할게요'));
        await tester.pumpAndSettle();
      }

      // Scroll to custom category representative tile
      await tester.scrollUntilVisible(
        find.text('업종별 카테고리 & 청구 템플릿'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      // Verify custom category representative tile is present
      expect(find.text('업종별 카테고리 & 청구 템플릿'), findsOneWidget);

      // Tap representative tile to open detail bottom sheet
      await tester.tap(find.text('업종별 카테고리 & 청구 템플릿'));
      await tester.pumpAndSettle();

      // Verify all 4 feature tiles are present inside the bottom sheet
      expect(find.text('수업 / 반 그룹 카테고리 관리'), findsOneWidget);
      expect(find.text('학생 등록 간편 템플릿 관리'), findsOneWidget);
      expect(find.text('청구 항목 및 금액 템플릿 관리'), findsOneWidget);
      expect(find.text('원터치 업종별 프리셋 불러오기'), findsOneWidget);

      // Cleanup
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    });

    test('CustomCategoryNotifier adds and removes items and updates state', () async {
      final container = ProviderContainer(
        overrides: [
          studioProfileProvider.overrideWith(() => _MockStudioProfileNotifier()),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(customCategoryProvider.notifier);
      await container.read(customCategoryProvider.future);

      await notifier.addGroupCategory('수학 올림피아드반');
      var state = container.read(customCategoryProvider).value!;
      expect(state.groupCategories.contains('수학 올림피아드반'), isTrue);

      await notifier.removeGroupCategory('수학 올림피아드반');
      state = container.read(customCategoryProvider).value!;
      expect(state.groupCategories.contains('수학 올림피아드반'), isFalse);

      await notifier.resetToIndustry('태권도 / 무술');
      state = container.read(customCategoryProvider).value!;
      expect(state.groupCategories.any((g) => g.contains('품새') || g.contains('수련')), isTrue);

      await notifier.saveMessageTemplate(const CustomMessageTemplate(
        id: 'tkd_custom_1',
        title: '심사 준비물 안내',
        body: '도복과 띠를 지참해 주세요.',
        categoryTag: '준비물',
      ));
      state = container.read(customCategoryProvider).value!;
      expect(state.messageTemplates.any((m) => m.id == 'tkd_custom_1'), isTrue);

      await notifier.removeMessageTemplate('tkd_custom_1');
      state = container.read(customCategoryProvider).value!;
      expect(state.messageTemplates.any((m) => m.id == 'tkd_custom_1'), isFalse);
    });

    testWidgets('SettingsVaultScreen exposes Edit & Create & Delete for member/invoice/custom SMS templates', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            studioProfileProvider.overrideWith(() => _MockStudioProfileNotifier()),
          ],
          child: const MaterialApp(
            home: SettingsVaultScreen(enableAutoCoachMark: false),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Open SMS templates & custom formats sheet
      await tester.scrollUntilVisible(
        find.text('문자 알림 및 청구 서식 관리'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.text('문자 알림 및 청구 서식 관리'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('문자 알림 및 청구 서식 관리'));
      await tester.pumpAndSettle();

      expect(find.text('나만의 맞춤 문자 · 공지 서식'), findsOneWidget);
      expect(find.text('새 맞춤 문자 서식 만들기'), findsOneWidget);
      expect(find.byIcon(Icons.edit_outlined), findsWidgets);
      expect(find.byIcon(Icons.delete_outline), findsWidgets);
    });
  });
}

class _MockStudioProfileNotifier extends StudioProfileNotifier {
  @override
  Future<StudioProfile> build() async {
    return const StudioProfile(
      studioName: '테스트 스튜디오',
      instructorName: '김대표',
      bankName: '토스뱅크',
      accountNumber: '1000-0000-1111',
      accountHolder: '김대표',
      category: '피트니스 / PT',
      autoBankDetectEnabled: true,
      invoiceTemplate: '기본 서식',
      attendanceTemplate: '출석 서식',
      departureTemplate: '하원 서식',
    );
  }
}

class _MockCustomCategoryNotifier extends CustomCategoryNotifier {
  @override
  Future<CustomCategoryState> build() async {
    return const CustomCategoryState(
      groupCategories: ['1:1 개인 PT', '2:1 듀엣 PT', '체형교정 재활반'],
      memberTemplates: [
        MemberCategoryTemplate(
          id: 'test_tpl_1',
          label: '1:1 PT 10회 (75만)',
          groupName: '1:1 개인 PT',
          billingType: BillingType.sessionBased,
          defaultFee: 750000,
          defaultSessions: 10,
        ),
      ],
      invoiceTemplates: [
        InvoiceItemTemplate(
          id: 'test_inv_1',
          title: '1:1 PT 10회 재등록',
          defaultAmount: 750000,
          category: 'PT수납',
        ),
      ],
    );
  }
}
