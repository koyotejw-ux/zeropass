import 'package:flutter_test/flutter_test.dart';
import 'package:zeropass/models/member.dart';
import 'package:zeropass/models/invoice.dart';
import 'package:zeropass/models/studio_profile.dart';
import 'package:zeropass/services/kakao_share_service.dart';
import 'package:zeropass/services/sms_template_service.dart';
import 'package:zeropass/services/starter_preset_service.dart';
import 'package:zeropass/services/localization_service.dart';

void main() {
  group('StudioProfile Terminology Customization Tests', () {
    test('Default profile falls back to category or standard terms', () {
      final defaultProfile = StudioProfile.defaultProfile();
      expect(defaultProfile.customMemberTerm, isNull);
      expect(defaultProfile.customFeeTerm, isNull);
      // For general category
      expect(defaultProfile.memberWord, isNotEmpty);
      expect(defaultProfile.feeWord, isNotEmpty);
      expect(defaultProfile.memberTitle, isNotEmpty);
      expect(defaultProfile.feeTitle, isNotEmpty);
    });

    test('Custom terminology overrides defaults across all getters', () {
      final profile = StudioProfile.defaultProfile().copyWith(
        customMemberTerm: '수련생',
        customFeeTerm: '도장비',
      );

      expect(profile.customMemberTerm, '수련생');
      expect(profile.customFeeTerm, '도장비');
      expect(profile.memberWord, '수련생');
      expect(profile.feeWord, '도장비');
      expect(profile.memberTitle, '수련생');
      expect(profile.feeTitle, '도장비');
    });

    test('StudioProfile serialization preserves customMemberTerm and customFeeTerm', () {
      final profile = StudioProfile.defaultProfile().copyWith(
        studioName: '마스터 태권도장',
        customMemberTerm: '수련생',
        customFeeTerm: '수련비',
      );

      final map = profile.toMap();
      expect(map['customMemberTerm'], '수련생');
      expect(map['customFeeTerm'], '수련비');

      final revived = StudioProfile.fromMap(map);
      expect(revived.customMemberTerm, '수련생');
      expect(revived.customFeeTerm, '수련비');
      expect(revived.memberWord, '수련생');
      expect(revived.feeWord, '수련비');
    });

    test('IndustryPreset provides specialized memberTerm and feeTerm', () {
      expect(IndustryPreset.academy.memberTerm, '원생');
      expect(IndustryPreset.academy.feeTerm, '수강료');

      expect(IndustryPreset.fitness.memberTerm, '회원');
      expect(IndustryPreset.fitness.feeTerm, '회비');

      expect(IndustryPreset.taekwondo.memberTerm, '수련생');
      expect(IndustryPreset.taekwondo.feeTerm, '교육비');

      expect(IndustryPreset.artMusic.memberTerm, '수강생');
      expect(IndustryPreset.artMusic.feeTerm, '수강료');
    });
  });

  group('Kakao & SMS Template Custom Terminology Injection Tests', () {
    final customStudio = StudioProfile.defaultProfile().copyWith(
      studioName: '용인대 호랑이 태권도',
      customMemberTerm: '수련생',
      customFeeTerm: '승품비',
      bankName: '우리은행',
      accountNumber: '1002-123-456789',
      accountHolder: '용인대호랑이',
      invoiceTemplate: '[#{상호명}] #{회원명} #{고객호칭}님의 #{비용호칭} #{청구제목} 안내\n수납 금액: #{금액}원',
    );

    final member = Member(
      id: 'm1',
      name: '강호동',
      phone: '010-9999-1111',
      groupName: '품새반',
      billingType: BillingType.monthlyRecurring,
      defaultFee: 160000,
      totalSessions: 0,
      remainingSessions: 0,
      registeredAt: DateTime(2026, 1, 1),
    );

    final invoice = Invoice(
      id: 'inv_term_1',
      memberIds: ['m1'],
      recipientPhone: '010-9999-1111',
      title: '6월 정기 청구',
      amount: 160000,
      dueDate: DateTime(2026, 6, 25),
      status: PaymentStatus.unpaid,
    );

    test('KakaoShareService injects custom feeWord and memberWord into invoice and notices', () {
      final invoiceMsg = KakaoShareService.generateInvoiceKakaoMessage(
        studio: customStudio,
        members: [member],
        invoice: invoice,
      );
      expect(invoiceMsg.contains('승품비 청구 안내'), isTrue);
      expect(invoiceMsg.contains('강호동 수련생님의 승품비 안내장'), isTrue);

      final paidInvoice = invoice.copyWith(
        status: PaymentStatus.paid,
        paymentMethod: 'TRANSFER',
        paidAt: DateTime.now(),
      );
      final receiptMsg = KakaoShareService.generateReceiptKakaoMessage(
        studio: customStudio,
        member: member,
        invoice: paidInvoice,
      );
      expect(receiptMsg.contains('승품비 입금이 정상 확인'), isTrue);
    });

    test('SmsTemplateService substitutes custom #{고객호칭} and #{비용호칭}', () {
      final rendered = SmsTemplateService.generateInvoiceMessage(
        studio: customStudio,
        members: [member],
        invoice: invoice,
      );

      expect(rendered, contains('[용인대 호랑이 태권도]'));
      expect(rendered, contains('강호동 수련생님의 승품비 6월 정기 청구 안내'));
      expect(rendered, contains('수납 금액: 160,000원'));
    });
  });

  group('Header and Bottom Navigation Title Parity', () {
    test('LocalizationService has exact 1:1 matching keys for all 5 tabs', () {
      expect(LocalizationService.tr('tab_pass'), '출결 체크');
      expect(LocalizationService.tr('tab_billing'), '청구·수납');
      expect(LocalizationService.tr('tab_tax_expense'), '지출·세무');
      expect(LocalizationService.tr('tab_members'), '회원 명부');
      expect(LocalizationService.tr('tab_settings'), '운영·설정');
    });
  });
}
