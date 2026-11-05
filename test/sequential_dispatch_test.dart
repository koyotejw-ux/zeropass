import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/services/sequential_dispatch_service.dart';
import 'package:zeropass/widgets/sequential_dispatch_modal.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('ko_KR', null);
    SharedPreferences.setMockInitialValues({});
  });

  final studio = StudioProfile.defaultProfile().copyWith(
    studioName: '센트럴 음악학원',
    instructorName: '김대표',
    bankName: '우리은행',
    accountNumber: '1002-123-456789',
    accountHolder: '센트럴음악',
  );

  final memberA = Member(
    id: 'mem_a',
    name: '이지원 (체르니 30)',
    phone: '010-1111-2222',
    groupName: '피아노 정규반',
    billingType: BillingType.monthlyRecurring,
    defaultFee: 190000,
    totalSessions: 0,
    remainingSessions: 0,
    registeredAt: DateTime(2026, 1, 1),
  );

  final memberB = Member(
    id: 'mem_b',
    name: '최민준 (바이올린)',
    phone: '010-3333-4444',
    groupName: '바이올린 주말반',
    billingType: BillingType.sessionBased,
    defaultFee: 250000,
    totalSessions: 10,
    remainingSessions: 1, // 만료 임박
    registeredAt: DateTime(2026, 2, 1),
  );

  final invoiceA = Invoice(
    id: 'inv_a',
    memberIds: ['mem_a'],
    recipientPhone: '010-1111-2222',
    title: '5월 피아노 수강료',
    amount: 190000,
    dueDate: DateTime(2026, 5, 25),
    status: PaymentStatus.unpaid,
  );

  group('SequentialDispatchService Unit Tests', () {
    test('Correctly renders and substitutes all dynamic placeholders in templates', () {
      const template = '''
[#{상호명}] #{회원명} 회원님 (#{그룹명})
청구 금액: #{금액}
납부 기한: #{납부기한}
계좌: #{계좌정보}
토스: #{토스송금링크}
회차: #{잔여회차}
''';

      final rendered = SequentialDispatchService.renderMessage(
        template: template,
        studio: studio,
        member: memberA,
        invoice: invoiceA,
      );

      expect(rendered.contains('센트럴 음악학원'), isTrue);
      expect(rendered.contains('이지원'), isTrue);
      expect(rendered.contains('피아노 정규반'), isTrue);
      expect(rendered.contains('190,000원'), isTrue);
      expect(rendered.contains('2026년 5월 25일'), isTrue);
      expect(rendered.contains('우리은행 1002-123-456789 (센트럴음악)'), isTrue);
      expect(rendered.contains('supertoss://send'), isTrue);
      expect(rendered.contains('정기 패스'), isTrue);
    });

    test('Session-based member properly renders remaining sessions', () {
      final rendered = SequentialDispatchService.renderMessage(
        template: '잔여: #{잔여회차}, 원명: #{상호명}, 학생: #{회원명}',
        studio: studio,
        member: memberB,
      );

      expect(rendered.contains('잔여: 1회'), isTrue);
      expect(rendered.contains('원명: 센트럴 음악학원'), isTrue);
      expect(rendered.contains('학생: 최민준'), isTrue);
    });

    test('buildDispatchItems creates queue matching members and linked invoices', () {
      final items = SequentialDispatchService.buildDispatchItems(
        members: [memberA, memberB],
        studio: studio,
        template: SequentialDispatchService.getDefaultTemplate(DispatchTemplateType.billing),
        invoices: [invoiceA],
      );

      expect(items.length, equals(2));
      expect(items[0].member.id, equals('mem_a'));
      expect(items[0].invoice?.id, equals('inv_a'));
      expect(items[0].recipientPhone, equals('010-1111-2222'));
      expect(items[0].isSent, isFalse);
      expect(items[0].message.contains('190,000원'), isTrue);

      expect(items[1].member.id, equals('mem_b'));
      expect(items[1].invoice, isNull);
      expect(items[1].recipientPhone, equals('010-3333-4444'));
      expect(items[1].message.contains('250,000원'), isTrue);
    });
  });

  group('SequentialDispatchModal Widget Interactive Wizard Tests', () {
    testWidgets('Full Interactive Flow: Config -> Dispatching -> Completion', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher'),
        (MethodCall call) async => true,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('plugins.flutter.io/url_launcher_android'),
        (MethodCall call) async => true,
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('dev.fluttercommunity.plus/share/share'),
        (MethodCall call) async => 'dev.fluttercommunity.plus/share/success',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.zeropass.app/sms_launcher'),
        (MethodCall call) async => true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  SequentialDispatchModal.show(
                    context: ctx,
                    allMembers: [memberA, memberB],
                    studio: studio,
                    invoices: [invoiceA],
                    onShareKakao: (t, s) async => true,
                    onSendSms: (p, b) async => true,
                  );
                },
                child: const Text('마법사 열기'),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Open Modal
      await tester.tap(find.text('마법사 열기'));
      await tester.pumpAndSettle();

      // Verify Config Phase UI
      expect(find.text('스마트 순차 단체발송'), findsOneWidget);
      expect(find.textContaining('전체 회원 (2명)'), findsOneWidget);
      expect(find.textContaining('그룹별 선택'), findsOneWidget);
      expect(find.textContaining('미납 회원만'), findsOneWidget);
      expect(find.textContaining('만료 임박'), findsOneWidget);

      // Verify Target Filter: Tap "전체 회원 (2명)"
      await tester.tap(find.textContaining('전체 회원 (2명)'));
      await tester.pumpAndSettle();

      // Check Start Button
      expect(find.textContaining('총 2명 순차 릴레이 발송 시작'), findsOneWidget);

      // Tap Start Dispatch
      await tester.tap(find.textContaining('총 2명 순차 릴레이 발송 시작'));
      await tester.pumpAndSettle();

      // Verify Dispatch Phase UI (1 of 2)
      expect(find.textContaining('1 / 2명'), findsOneWidget);
      expect(find.text('순차 릴레이 발송 중'), findsOneWidget);
      expect(find.textContaining('이지원 (체르니 30)'), findsOneWidget);
      expect(find.text('카톡 0원 전송 후 다음'), findsOneWidget);
      expect(find.text('문자 전송 후 다음'), findsOneWidget);
      expect(find.text('이 회원 건너뛰기'), findsOneWidget);

      // Dispatch 1st via Kakao
      await tester.tap(find.text('카톡 0원 전송 후 다음'));
      await tester.pumpAndSettle();

      // Now at 2 of 2
      expect(find.textContaining('2 / 2명'), findsOneWidget);
      expect(find.textContaining('최민준 (바이올린)'), findsOneWidget);

      // Dispatch 2nd via SMS
      await tester.tap(find.text('문자 전송 후 다음'));
      await tester.pumpAndSettle();

      // Verify Completion Phase UI
      expect(find.text('순차 릴레이 발송 완료!'), findsOneWidget);
      expect(find.textContaining('카카오톡 (0원) 발송'), findsOneWidget);
      expect(find.textContaining('기본 문자(SMS) 발송'), findsOneWidget);
      expect(find.text('확인 및 닫기'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('확인 및 닫기'));
      await tester.pumpAndSettle();

      expect(find.text('순차 릴레이 발송 완료!'), findsNothing);
    });
  });
}
