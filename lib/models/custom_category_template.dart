import 'dart:convert';
import 'member.dart';

/// 업종별 학생/원생 등록 간편 템플릿
class MemberCategoryTemplate {
  final String id;
  final String label; // 칩 표시명 (예: '중등 수학 정규반', '1:1 기구필라 10회')
  final String groupName; // 그룹명 (예: '중등수학', '기구필라테스')
  final BillingType billingType; // 회차형 vs 월정기
  final int defaultFee; // 기본 수강료
  final int defaultSessions; // 기본 회차 (회차형일 때)

  const MemberCategoryTemplate({
    required this.id,
    required this.label,
    required this.groupName,
    required this.billingType,
    required this.defaultFee,
    this.defaultSessions = 0,
  });

  MemberCategoryTemplate copyWith({
    String? id,
    String? label,
    String? groupName,
    BillingType? billingType,
    int? defaultFee,
    int? defaultSessions,
  }) {
    return MemberCategoryTemplate(
      id: id ?? this.id,
      label: label ?? this.label,
      groupName: groupName ?? this.groupName,
      billingType: billingType ?? this.billingType,
      defaultFee: defaultFee ?? this.defaultFee,
      defaultSessions: defaultSessions ?? this.defaultSessions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'label': label,
      'groupName': groupName,
      'billingType': billingType.name,
      'defaultFee': defaultFee,
      'defaultSessions': defaultSessions,
    };
  }

  factory MemberCategoryTemplate.fromMap(Map<String, dynamic> map) {
    return MemberCategoryTemplate(
      id: map['id'] as String? ?? 'tpl_${DateTime.now().millisecondsSinceEpoch}',
      label: map['label'] as String? ?? '일반 수강',
      groupName: map['groupName'] as String? ?? '일반',
      billingType: map['billingType'] == 'sessionBased'
          ? BillingType.sessionBased
          : BillingType.monthlyRecurring,
      defaultFee: (map['defaultFee'] as num?)?.toInt() ?? 200000,
      defaultSessions: (map['defaultSessions'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory MemberCategoryTemplate.fromJson(String source) =>
      MemberCategoryTemplate.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// 업종별 청구서 항목 및 금액 템플릿
class InvoiceItemTemplate {
  final String id;
  final String title; // 청구 제목 (예: '정규 수강료 안내', 'PT 10회 재등록', '교재비')
  final int defaultAmount; // 기본 청구 금액
  final String? category; // 분류 태그 (예: '정기수납', '재등록', '교재/재료')

  const InvoiceItemTemplate({
    required this.id,
    required this.title,
    required this.defaultAmount,
    this.category,
  });

  InvoiceItemTemplate copyWith({
    String? id,
    String? title,
    int? defaultAmount,
    String? category,
  }) {
    return InvoiceItemTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      defaultAmount: defaultAmount ?? this.defaultAmount,
      category: category ?? this.category,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'defaultAmount': defaultAmount,
      'category': category,
    };
  }

  factory InvoiceItemTemplate.fromMap(Map<String, dynamic> map) {
    return InvoiceItemTemplate(
      id: map['id'] as String? ?? 'inv_tpl_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? '수강료 안내',
      defaultAmount: (map['defaultAmount'] as num?)?.toInt() ?? 100000,
      category: map['category'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory InvoiceItemTemplate.fromJson(String source) =>
      InvoiceItemTemplate.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// 전체 업종별 맞춤 카테고리 상태 모델
class CustomCategoryState {
  final List<String> groupCategories;
  final List<MemberCategoryTemplate> memberTemplates;
  final List<InvoiceItemTemplate> invoiceTemplates;

  const CustomCategoryState({
    required this.groupCategories,
    required this.memberTemplates,
    required this.invoiceTemplates,
  });

  CustomCategoryState copyWith({
    List<String>? groupCategories,
    List<MemberCategoryTemplate>? memberTemplates,
    List<InvoiceItemTemplate>? invoiceTemplates,
  }) {
    return CustomCategoryState(
      groupCategories: groupCategories ?? this.groupCategories,
      memberTemplates: memberTemplates ?? this.memberTemplates,
      invoiceTemplates: invoiceTemplates ?? this.invoiceTemplates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupCategories': groupCategories,
      'memberTemplates': memberTemplates.map((e) => e.toMap()).toList(),
      'invoiceTemplates': invoiceTemplates.map((e) => e.toMap()).toList(),
    };
  }

  factory CustomCategoryState.fromMap(Map<String, dynamic> map) {
    final rawGroups = map['groupCategories'] as List<dynamic>? ?? [];
    final rawMembers = map['memberTemplates'] as List<dynamic>? ?? [];
    final rawInvoices = map['invoiceTemplates'] as List<dynamic>? ?? [];

    return CustomCategoryState(
      groupCategories: rawGroups.map((e) => e.toString()).toList(),
      memberTemplates: rawMembers
          .map((e) => MemberCategoryTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      invoiceTemplates: rawInvoices
          .map((e) => InvoiceItemTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  /// 각 업종별 최적화된 초기 프리셋 생성기
  static CustomCategoryState getDefaultsForIndustry(String category) {
    if (category.contains('학원') ||
        category.contains('입시') ||
        category.contains('보습') ||
        category.contains('어학') ||
        category.contains('코딩')) {
      return const CustomCategoryState(
        groupCategories: [
          '초등 영재반',
          '중등 내신대비반',
          '고등 수능1등급반',
          '수학 1:1 클리닉',
          '주말 단과특강',
        ],
        memberTemplates: [
          MemberCategoryTemplate(
            id: 'tpl_acad_1',
            label: '중등 내신반 (35만/월)',
            groupName: '중등 내신대비반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 350000,
            defaultSessions: 0,
          ),
          MemberCategoryTemplate(
            id: 'tpl_acad_2',
            label: '고등 수능반 (42만/월)',
            groupName: '고등 수능1등급반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 420000,
            defaultSessions: 0,
          ),
          MemberCategoryTemplate(
            id: 'tpl_acad_3',
            label: '1:1 클리닉 8회 (32만)',
            groupName: '수학 1:1 클리닉',
            billingType: BillingType.sessionBased,
            defaultFee: 320000,
            defaultSessions: 8,
          ),
          MemberCategoryTemplate(
            id: 'tpl_acad_4',
            label: '초등 영재반 (28만/월)',
            groupName: '초등 영재반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 280000,
            defaultSessions: 0,
          ),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(
            id: 'inv_tpl_acad_1',
            title: '정규 수강료 안내',
            defaultAmount: 350000,
            category: '정기수납',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_acad_2',
            title: '학기 교재비 / 워크북',
            defaultAmount: 35000,
            category: '교재/재료',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_acad_3',
            title: '방학 집중특강 수강료',
            defaultAmount: 250000,
            category: '특강',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_acad_4',
            title: '전국 모의고사 응시료',
            defaultAmount: 20000,
            category: '시험/평가',
          ),
        ],
      );
    } else if (category.contains('피트니스') ||
        category.contains('PT') ||
        category.contains('스포츠') ||
        category.contains('수영') ||
        category.contains('헬스')) {
      return const CustomCategoryState(
        groupCategories: [
          '1:1 개인 PT',
          '2:1 듀엣 PT',
          '바디프로필 집중반',
          '체형교정 재활반',
          '일반 헬스이용권',
        ],
        memberTemplates: [
          MemberCategoryTemplate(
            id: 'tpl_fit_1',
            label: '1:1 PT 10회 (75만)',
            groupName: '1:1 개인 PT',
            billingType: BillingType.sessionBased,
            defaultFee: 750000,
            defaultSessions: 10,
          ),
          MemberCategoryTemplate(
            id: 'tpl_fit_2',
            label: '1:1 PT 30회 (210만)',
            groupName: '1:1 개인 PT',
            billingType: BillingType.sessionBased,
            defaultFee: 2100000,
            defaultSessions: 30,
          ),
          MemberCategoryTemplate(
            id: 'tpl_fit_3',
            label: '2:1 듀엣 10회 (50만)',
            groupName: '2:1 듀엣 PT',
            billingType: BillingType.sessionBased,
            defaultFee: 500000,
            defaultSessions: 10,
          ),
          MemberCategoryTemplate(
            id: 'tpl_fit_4',
            label: '헬스 3개월 정기권 (24만)',
            groupName: '일반 헬스이용권',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 240000,
            defaultSessions: 0,
          ),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(
            id: 'inv_tpl_fit_1',
            title: '1:1 PT 10회 재등록',
            defaultAmount: 750000,
            category: 'PT수납',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_fit_2',
            title: '1:1 PT 20회 패키지',
            defaultAmount: 1400000,
            category: '패키지',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_fit_3',
            title: '개인 락커 & 운동복 이용료',
            defaultAmount: 30000,
            category: '부대시설',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_fit_4',
            title: '1일 체험 레슨권',
            defaultAmount: 30000,
            category: '체험',
          ),
        ],
      );
    } else if (category.contains('필라테스') ||
        category.contains('요가') ||
        category.contains('무용') ||
        category.contains('댄스')) {
      return const CustomCategoryState(
        groupCategories: [
          '개인 기구필라테스',
          '4:1 소그룹 리포머',
          '체형교정 요가',
          '주말 댄스/안무반',
          '산전산후 케어반',
        ],
        memberTemplates: [
          MemberCategoryTemplate(
            id: 'tpl_pil_1',
            label: '개인 기구 10회 (70만)',
            groupName: '개인 기구필라테스',
            billingType: BillingType.sessionBased,
            defaultFee: 700000,
            defaultSessions: 10,
          ),
          MemberCategoryTemplate(
            id: 'tpl_pil_2',
            label: '소그룹 20회권 (45만)',
            groupName: '4:1 소그룹 리포머',
            billingType: BillingType.sessionBased,
            defaultFee: 450000,
            defaultSessions: 20,
          ),
          MemberCategoryTemplate(
            id: 'tpl_pil_3',
            label: '체형요가 주3회 (18만/월)',
            groupName: '체형교정 요가',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 180000,
            defaultSessions: 0,
          ),
          MemberCategoryTemplate(
            id: 'tpl_pil_4',
            label: '댄스 안무 정규반 (16만/월)',
            groupName: '주말 댄스/안무반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 160000,
            defaultSessions: 0,
          ),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(
            id: 'inv_tpl_pil_1',
            title: '기구필라테스 10회 레슨비',
            defaultAmount: 700000,
            category: '레슨비',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_pil_2',
            title: '소그룹 리포머 20회 재등록',
            defaultAmount: 450000,
            category: '회수권',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_pil_3',
            title: '미끄럼방지 토삭스 / 소도구',
            defaultAmount: 25000,
            category: '용품',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_pil_4',
            title: '체형분석 & 1회 체험권',
            defaultAmount: 35000,
            category: '체험',
          ),
        ],
      );
    } else if (category.contains('태권도') ||
        category.contains('무술') ||
        category.contains('주짓수') ||
        category.contains('검도') ||
        category.contains('복싱')) {
      return const CustomCategoryState(
        groupCategories: [
          '유치부 꿈나무반',
          '초등 정규수련반',
          '중고등 품새반',
          '시범단 / 선수반',
          '성인 실전호신술',
        ],
        memberTemplates: [
          MemberCategoryTemplate(
            id: 'tpl_tkd_1',
            label: '초등 주5회 정규 (18만/월)',
            groupName: '초등 정규수련반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 180000,
            defaultSessions: 0,
          ),
          MemberCategoryTemplate(
            id: 'tpl_tkd_2',
            label: '유치부 안심돌봄 (17만/월)',
            groupName: '유치부 꿈나무반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 170000,
            defaultSessions: 0,
          ),
          MemberCategoryTemplate(
            id: 'tpl_tkd_3',
            label: '중고등 품새반 (19만/월)',
            groupName: '중고등 품새반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 190000,
            defaultSessions: 0,
          ),
          MemberCategoryTemplate(
            id: 'tpl_tkd_4',
            label: '시범단 특별훈련 (12만/월)',
            groupName: '시범단 / 선수반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 120000,
            defaultSessions: 0,
          ),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(
            id: 'inv_tpl_tkd_1',
            title: '정규 수련 교육비',
            defaultAmount: 180000,
            category: '교육비',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_tkd_2',
            title: '정기 승품·승단 심사비',
            defaultAmount: 60000,
            category: '심사비',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_tkd_3',
            title: '전용 도복 및 보호장구',
            defaultAmount: 70000,
            category: '용품비',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_tkd_4',
            title: '방학 특별캠프 참가비',
            defaultAmount: 50000,
            category: '행사/캠프',
          ),
        ],
      );
    } else if (category.contains('음악') ||
        category.contains('피아노') ||
        category.contains('바이올린') ||
        category.contains('보컬') ||
        category.contains('미술') ||
        category.contains('도예') ||
        category.contains('공방')) {
      return const CustomCategoryState(
        groupCategories: [
          '피아노 기초/바이엘',
          '체르니/클래식 전공반',
          '도예 정규물레반',
          '미술 창의조형반',
          '원데이 힐링클래스',
        ],
        memberTemplates: [
          MemberCategoryTemplate(
            id: 'tpl_art_1',
            label: '피아노 주3회 (20만/월)',
            groupName: '피아노 기초/바이엘',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 200000,
            defaultSessions: 0,
          ),
          MemberCategoryTemplate(
            id: 'tpl_art_2',
            label: '도예 정규 4회권 (24만)',
            groupName: '도예 정규물레반',
            billingType: BillingType.sessionBased,
            defaultFee: 240000,
            defaultSessions: 4,
          ),
          MemberCategoryTemplate(
            id: 'tpl_art_3',
            label: '미술 창의반 (18만/월)',
            groupName: '미술 창의조형반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 180000,
            defaultSessions: 0,
          ),
          MemberCategoryTemplate(
            id: 'tpl_art_4',
            label: '원데이 클래스 (7만/1회)',
            groupName: '원데이 힐링클래스',
            billingType: BillingType.sessionBased,
            defaultFee: 70000,
            defaultSessions: 1,
          ),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(
            id: 'inv_tpl_art_1',
            title: '정규 수강료 안내',
            defaultAmount: 200000,
            category: '수강료',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_art_2',
            title: '도예 점토/가마 소성비',
            defaultAmount: 40000,
            category: '재료/소성',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_art_3',
            title: '정기 연주회/콩쿠르 참가비',
            defaultAmount: 80000,
            category: '행사',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_art_4',
            title: '교재 및 악보집 구입비',
            defaultAmount: 25000,
            category: '교재',
          ),
        ],
      );
    } else {
      // 기타 / 맞춤업종 (범용)
      return const CustomCategoryState(
        groupCategories: [
          '일반 정규반',
          '맞춤 1:1 레슨',
          '주말 특별반',
          '자유 이용권',
        ],
        memberTemplates: [
          MemberCategoryTemplate(
            id: 'tpl_gen_1',
            label: '정규 월회비 (20만/월)',
            groupName: '일반 정규반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 200000,
            defaultSessions: 0,
          ),
          MemberCategoryTemplate(
            id: 'tpl_gen_2',
            label: '10회 이용권 (50만/10회)',
            groupName: '맞춤 1:1 레슨',
            billingType: BillingType.sessionBased,
            defaultFee: 500000,
            defaultSessions: 10,
          ),
          MemberCategoryTemplate(
            id: 'tpl_gen_3',
            label: '주말 특별반 (15만/월)',
            groupName: '주말 특별반',
            billingType: BillingType.monthlyRecurring,
            defaultFee: 150000,
            defaultSessions: 0,
          ),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(
            id: 'inv_tpl_gen_1',
            title: '정기 이용료 / 회비',
            defaultAmount: 200000,
            category: '회비',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_gen_2',
            title: '10회 이용권 재등록',
            defaultAmount: 500000,
            category: '이용권',
          ),
          InvoiceItemTemplate(
            id: 'inv_tpl_gen_3',
            title: '소모품 및 재료비',
            defaultAmount: 30000,
            category: '부대비용',
          ),
        ],
      );
    }
  }
}
