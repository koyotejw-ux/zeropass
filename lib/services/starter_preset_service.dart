import 'package:uuid/uuid.dart';
import '../models/member.dart';
import '../models/invoice.dart';
import 'custom_category_service.dart';
import 'database_service.dart';

enum IndustryPreset {
  academy('학원 · 공부방 · 교습소', '입시 / 보습학원', '멘토스 수학학원', '김멘토', 350000),
  fitness('피트니스 · PT · 헬스', '피트니스 / PT', '에이스 1:1 바디 PT샵', '강철민', 750000),
  pilates('필라테스 · 요가 · 댄스', '필라테스 / 요가', '루나 기구 필라테스', '이지은', 550000),
  taekwondo('태권도 · 체육관 · 무예', '태권도 / 무술', '호랑이 국가대표 태권도장', '박도진', 180000),
  artMusic('음악 · 피아노 · 미술공방', '음악 / 피아노', '클래식 피아노 음악학원', '최유진', 240000);

  final String label;
  final String category;
  final String sampleStudioName;
  final String sampleInstructorName;
  final int defaultFee;

  const IndustryPreset(
    this.label,
    this.category,
    this.sampleStudioName,
    this.sampleInstructorName,
    this.defaultFee,
  );
}

class StarterPresetService {
  StarterPresetService._();

  /// Applies the chosen industry preset to DB:
  /// Updates StudioProfile and generates 5 realistic mock members suited for that industry.
  static Future<void> applyPreset(IndustryPreset preset) async {
    final db = await DatabaseService.instance.database;
    final now = DateTime.now();

    // 1. Update Studio Profile
    await db.update(
      'studio_profile',
      {
        'studioName': preset.sampleStudioName,
        'instructorName': preset.sampleInstructorName,
        'category': preset.category,
      },
      where: 'id = ?',
      whereArgs: [1],
    );

    // 1-1. Update Custom Categories and Invoice Templates for this industry
    await CustomCategoryService.instance.resetToIndustry(preset.category);

    // 2. Clear old members & seed industry-specific members
    await db.delete('pass_records');
    await db.delete('invoices');
    await db.delete('members');

    final members = _generateIndustryMembers(preset, now);
    for (final m in members) {
      await db.insert('members', m.toMap());
    }

    // 3. Seed sample invoice for the first member
    if (members.isNotEmpty) {
      final sampleInvoice = Invoice(
        id: const Uuid().v4(),
        memberIds: [members[0].id],
        recipientPhone: members[0].phone,
        title: '${now.month}월 ${preset.label.split(' ')[0]} 수납 안내',
        amount: members[0].defaultFee,
        dueDate: now.add(const Duration(days: 5)),
        status: PaymentStatus.unpaid,
      );
      await db.insert('invoices', sampleInvoice.toMap());
    }
  }

  static List<Member> _generateIndustryMembers(IndustryPreset preset, DateTime now) {
    switch (preset) {
      case IndustryPreset.academy:
        return [
          Member(
            id: 'mem_acad_1',
            name: '김서연 (중3 심화)',
            phone: '01012341101',
            groupName: '중3 특목대비반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 380000,
            totalSessions: 0,
            remainingSessions: 0,
            memo: '매주 화·목 19:00 수학 심화, 오답노트 필수',
            payerName: '김진호(부)',
            registeredAt: now.subtract(const Duration(days: 40)),
          ),
          Member(
            id: 'mem_acad_2',
            name: '박민재 (고1 내신)',
            phone: '01023451102',
            groupName: '고1 1등급 집중반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 420000,
            totalSessions: 0,
            remainingSessions: 0,
            memo: '영어 단어 테스트 미통과 시 30분 보충',
            payerName: '이미영(모)',
            registeredAt: now.subtract(const Duration(days: 30)),
          ),
          Member(
            id: 'mem_acad_3',
            name: '이지우 (초6 연산)',
            phone: '01034561103',
            groupName: '초등 창의수학',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 250000,
            totalSessions: 0,
            remainingSessions: 0,
            memo: '학원 차량 2호차 이용 (월·수·금 15:30)',
            payerName: '이성훈(부)',
            registeredAt: now.subtract(const Duration(days: 15)),
          ),
        ];

      case IndustryPreset.fitness:
        return [
          Member(
            id: 'mem_fit_1',
            name: '이도현 (바디프로필)',
            phone: '01055219012',
            groupName: '1:1 VIP PT',
            billingType: BillingType.sessionBased,
            defaultFee: 800000,
            totalSessions: 20,
            remainingSessions: 3, // 만료 임박
            memo: 'D-30 식단 점검 및 하체 벌크업 집중',
            registeredAt: now.subtract(const Duration(days: 60)),
          ),
          Member(
            id: 'mem_fit_2',
            name: '정수아 (체형교정)',
            phone: '01077894451',
            groupName: '재활&체형케어',
            billingType: BillingType.sessionBased,
            defaultFee: 650000,
            totalSessions: 10,
            remainingSessions: 8,
            memo: '경추 디스크 주의, 가벼운 스트레칭 위주 진행',
            registeredAt: now.subtract(const Duration(days: 10)),
          ),
          Member(
            id: 'mem_fit_3',
            name: '강태우 (헬스 연간)',
            phone: '01088903342',
            groupName: '헬스 프리패스',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 120000,
            totalSessions: 0,
            remainingSessions: 0,
            memo: '락커룸 45호 배정 완료',
            registeredAt: now.subtract(const Duration(days: 80)),
          ),
        ];

      case IndustryPreset.pilates:
        return [
          Member(
            id: 'mem_pil_1',
            name: '박민지 (리포머 1:1)',
            phone: '01033418872',
            groupName: '기구 필라테스',
            billingType: BillingType.sessionBased,
            defaultFee: 700000,
            totalSessions: 10,
            remainingSessions: 2, // 만료 임박
            memo: '라운드숄더 집중 케어',
            registeredAt: now.subtract(const Duration(days: 45)),
          ),
          Member(
            id: 'mem_pil_2',
            name: '윤하은 (오전 4:1 그룹)',
            phone: '01099234412',
            groupName: '그룹 리포머&체어',
            billingType: BillingType.sessionBased,
            defaultFee: 280000,
            totalSessions: 8,
            remainingSessions: 6,
            memo: '화·목 오전 10시 정원제 수업',
            registeredAt: now.subtract(const Duration(days: 20)),
          ),
        ];

      case IndustryPreset.taekwondo:
        return [
          Member(
            id: 'mem_tkd_1',
            name: '최준혁 (유품자 2품)',
            phone: '01044901188',
            groupName: '초등 2부 (15:30)',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 190000,
            totalSessions: 0,
            remainingSessions: 0,
            memo: '겨루기 선수단 희망, 보호대 착용 확인',
            payerName: '최동욱(부)',
            registeredAt: now.subtract(const Duration(days: 90)),
          ),
          Member(
            id: 'mem_tkd_2',
            name: '한예린 (초록띠)',
            phone: '01066772233',
            groupName: '유치부 (14:00)',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 180000,
            totalSessions: 0,
            remainingSessions: 0,
            memo: '도복 사이즈 120호 지급 완료',
            payerName: '송유진(모)',
            registeredAt: now.subtract(const Duration(days: 30)),
          ),
        ];

      case IndustryPreset.artMusic:
        return [
          Member(
            id: 'mem_mus_1',
            name: '이지안 (체르니 30)',
            phone: '01011223344',
            groupName: '피아노 주3회반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 240000,
            totalSessions: 0,
            remainingSessions: 0,
            memo: '콩쿠르 대비 모차르트 소나타 연습 중',
            payerName: '이현우(부)',
            registeredAt: now.subtract(const Duration(days: 50)),
          ),
          Member(
            id: 'mem_mus_2',
            name: '서우진 (도예 정규)',
            phone: '01077665544',
            groupName: '도예 물레 주말반',
            billingType: BillingType.sessionBased,
            defaultFee: 320000,
            totalSessions: 4,
            remainingSessions: 3,
            memo: '가마 소성 일정 안내 요망',
            registeredAt: now.subtract(const Duration(days: 12)),
          ),
        ];
    }
  }
}
