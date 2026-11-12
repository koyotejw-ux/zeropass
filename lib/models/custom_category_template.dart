import 'dart:convert';
import '../services/localization_service.dart';
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
    final fallbackLabel = LocalizationService.pick(
      ko: '일반 수강',
      en: 'Standard Plan',
      ja: '一般コース',
      zh: '常规课程',
      vi: 'Gói tiêu chuẩn',
      es: 'Plan Estándar',
    );
    final fallbackGroup = LocalizationService.pick(
      ko: '일반',
      en: 'General',
      ja: '一般',
      zh: '常规',
      vi: 'Chung',
      es: 'General',
    );
    final fallbackFee = LocalizationService.currentCurrency == AppCurrency.krw
        ? 200000
        : CustomCategoryState.scaleAmount(200000);
    return MemberCategoryTemplate(
      id: map['id'] as String? ?? 'tpl_${DateTime.now().millisecondsSinceEpoch}',
      label: map['label'] as String? ?? fallbackLabel,
      groupName: map['groupName'] as String? ?? fallbackGroup,
      billingType: map['billingType'] == 'sessionBased'
          ? BillingType.sessionBased
          : BillingType.monthlyRecurring,
      defaultFee: (map['defaultFee'] as num?)?.toInt() ?? fallbackFee,
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
    final fallbackTitle = LocalizationService.pick(
      ko: '수강료 안내',
      en: 'Tuition Invoice',
      ja: '受講料のご案内',
      zh: '课程费用账单',
      vi: 'Thông báo học phí',
      es: 'Aviso de Cuota',
    );
    final fallbackAmt = LocalizationService.currentCurrency == AppCurrency.krw
        ? 100000
        : CustomCategoryState.scaleAmount(100000);
    return InvoiceItemTemplate(
      id: map['id'] as String? ?? 'inv_tpl_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? fallbackTitle,
      defaultAmount: (map['defaultAmount'] as num?)?.toInt() ?? fallbackAmt,
      category: map['category'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory InvoiceItemTemplate.fromJson(String source) =>
      InvoiceItemTemplate.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// 업종별 사용자 정의 문자 / 공지 / 일괄 발송 서식 템플릿
class CustomMessageTemplate {
  final String id;
  final String title; // 서식 이름 (예: '방학 특강 안내', '1:1 피티 재등록 혜택')
  final String body; // 치환 태그를 포함한 본문
  final String? categoryTag; // 분류 태그 (예: '특강/이벤트', '공지사항', '재등록')

  const CustomMessageTemplate({
    required this.id,
    required this.title,
    required this.body,
    this.categoryTag,
  });

  CustomMessageTemplate copyWith({
    String? id,
    String? title,
    String? body,
    String? categoryTag,
  }) {
    return CustomMessageTemplate(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      categoryTag: categoryTag ?? this.categoryTag,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'categoryTag': categoryTag,
    };
  }

  factory CustomMessageTemplate.fromMap(Map<String, dynamic> map) {
    final fallbackTitle = LocalizationService.pick(
      ko: '맞춤 안내 문구',
      en: 'Custom Notice',
      ja: 'カスタム案内',
      zh: '自定义通知模板',
      vi: 'Mẫu thông báo tùy chỉnh',
      es: 'Aviso Personalizado',
    );
    return CustomMessageTemplate(
      id: map['id'] as String? ?? 'msg_tpl_${DateTime.now().millisecondsSinceEpoch}',
      title: map['title'] as String? ?? fallbackTitle,
      body: map['body'] as String? ?? '',
      categoryTag: map['categoryTag'] as String?,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory CustomMessageTemplate.fromJson(String source) =>
      CustomMessageTemplate.fromMap(jsonDecode(source) as Map<String, dynamic>);
}

/// 전체 업종별 맞춤 카테고리 상태 모델
class CustomCategoryState {
  final List<String> groupCategories;
  final List<MemberCategoryTemplate> memberTemplates;
  final List<InvoiceItemTemplate> invoiceTemplates;
  final List<CustomMessageTemplate> messageTemplates;

  const CustomCategoryState({
    required this.groupCategories,
    required this.memberTemplates,
    required this.invoiceTemplates,
    this.messageTemplates = const [],
  });

  CustomCategoryState copyWith({
    List<String>? groupCategories,
    List<MemberCategoryTemplate>? memberTemplates,
    List<InvoiceItemTemplate>? invoiceTemplates,
    List<CustomMessageTemplate>? messageTemplates,
  }) {
    return CustomCategoryState(
      groupCategories: groupCategories ?? this.groupCategories,
      memberTemplates: memberTemplates ?? this.memberTemplates,
      invoiceTemplates: invoiceTemplates ?? this.invoiceTemplates,
      messageTemplates: messageTemplates ?? this.messageTemplates,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'groupCategories': groupCategories,
      'memberTemplates': memberTemplates.map((e) => e.toMap()).toList(),
      'invoiceTemplates': invoiceTemplates.map((e) => e.toMap()).toList(),
      'messageTemplates': messageTemplates.map((e) => e.toMap()).toList(),
    };
  }

  factory CustomCategoryState.fromMap(Map<String, dynamic> map) {
    final rawGroups = map['groupCategories'] as List<dynamic>? ?? [];
    final rawMembers = map['memberTemplates'] as List<dynamic>? ?? [];
    final rawInvoices = map['invoiceTemplates'] as List<dynamic>? ?? [];
    final rawMessages = map['messageTemplates'] as List<dynamic>? ?? [];

    return CustomCategoryState(
      groupCategories: rawGroups.map((e) => e.toString()).toList(),
      memberTemplates: rawMembers
          .map((e) => MemberCategoryTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      invoiceTemplates: rawInvoices
          .map((e) => InvoiceItemTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
      messageTemplates: rawMessages
          .map((e) => CustomMessageTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList(),
    );
  }

  /// Scales a KRW reference amount proportionally to [currency] using clean round steps.
  static int scaleAmount(int krwAmount, [AppCurrency? currency]) {
    final cur = currency ?? LocalizationService.currentCurrency;
    if (cur == AppCurrency.krw) return krwAmount;
    final raw = (krwAmount / AppCurrency.krw.defaultFeeBase) * cur.defaultFeeBase;
    final int step;
    switch (cur) {
      case AppCurrency.krw:
        return krwAmount;
      case AppCurrency.jpy:
        step = 500;
        break;
      case AppCurrency.vnd:
        step = 50000;
        break;
      case AppCurrency.usd:
      case AppCurrency.cny:
      case AppCurrency.eur:
      case AppCurrency.gbp:
      case AppCurrency.sgd:
      case AppCurrency.aud:
      case AppCurrency.cad:
        step = 5;
        break;
    }
    final rounded = ((raw / step).round() * step);
    return rounded < step ? step : rounded;
  }

  static bool _matchesAny(String source, List<String> keywords) {
    final lower = source.toLowerCase();
    return keywords.any((k) => lower.contains(k.toLowerCase()));
  }

  static bool _isFitness(String category) => _matchesAny(category, [
        '피트니스',
        'pt',
        '스포츠',
        '수영',
        '헬스',
        'fitness',
        'gym',
        'swim',
        'スポーツ',
        'フィットネス',
        'ジム',
        '水泳',
        '健身',
        '体育',
        '游泳',
        'thể hình',
        'bơi',
        'gimnasio',
        'entrenamiento',
        'natación',
      ]);

  static bool _isPilates(String category) => _matchesAny(category, [
        '필라테스',
        '요가',
        '무용',
        '댄스',
        'pilates',
        'yoga',
        'dance',
        'ピラティス',
        'ヨガ',
        'ダンス',
        '普拉提',
        '瑜伽',
        '舞蹈',
        'múa',
        'nhảy',
        'danza',
        'baile',
      ]);

  static bool _isAcademy(String category) => _matchesAny(category, [
        '학원',
        '입시',
        '보습',
        '어학',
        '코딩',
        'academy',
        'tutor',
        'coding',
        'language',
        '学習塾',
        '塾',
        '語学',
        'プログラミング',
        '培训',
        '补习',
        '语言',
        '编程',
        'trung tâm',
        'gia sư',
        'ngoại ngữ',
        'lập trình',
        'academia',
        'idiomas',
        'programación',
      ]);

  static bool _isMartialArts(String category) => _matchesAny(category, [
        '태권도',
        '무술',
        '주짓수',
        '검도',
        '복싱',
        'taekwondo',
        'martial',
        'jiu-jitsu',
        'boxing',
        '武道',
        '空手',
        'テコンドー',
        'ボクシング',
        '跆拳道',
        '武术',
        '拳击',
        'võ',
        'artes marciales',
        'boxeo',
      ]);

  static bool _isMusicArt(String category) => _matchesAny(category, [
        '음악',
        '피아노',
        '바이올린',
        '보컬',
        '미술',
        '도예',
        '공방',
        'music',
        'piano',
        'violin',
        'art',
        'pottery',
        'ceramic',
        'workshop',
        '音楽',
        'ピアノ',
        '美術',
        '陶芸',
        'アトリエ',
        '音乐',
        '钢琴',
        '美术',
        '陶艺',
        'âm nhạc',
        'nhạc',
        'mỹ thuật',
        'gốm',
        'música',
        'arte',
        'cerámica',
        'taller',
      ]);

  /// 업종별 기본 사용자 정의 문자·공지 서식 생성
  static List<CustomMessageTemplate> getDefaultMessageTemplatesForIndustry(String category) {
    final lang = LocalizationService.currentLanguage;
    final supportsToss = LocalizationService.supportsTossTransfer;
    if (lang == AppLanguage.korean && supportsToss) {
      if (_isFitness(category) || _isPilates(category)) {
        return const [
          CustomMessageTemplate(
            id: 'msg_tpl_fit_renew',
            title: '회차 재등록 혜택 안내',
            categoryTag: '재등록',
            body: '[#{상호명}] #{회원명} #{고객호칭}님, 현재 #{잔여회차}가 얼마 남지 않았습니다.\n연속적인 운동 루틴 유지를 위해 이번 주 내 재등록 시 우선 스케줄 예약을 도와드릴게요!\n문의: #{담당자} #{직함}',
          ),
          CustomMessageTemplate(
            id: 'msg_tpl_fit_notice',
            title: '센터 운영시간 / 휴무 공지',
            categoryTag: '공지사항',
            body: '[#{상호명}] #{회원명} #{고객호칭}님 안녕하세요.\n이번 주 #{장소호칭} 운영 일정 안내드립니다. 예약 변경은 편하신 시간에 답장 주세요!\n감사합니다. (#{담당자} #{직함})',
          ),
        ];
      }
      return const [
        CustomMessageTemplate(
          id: 'msg_tpl_gen_notice',
          title: '일정 변경 / 휴강 공지',
          categoryTag: '공지사항',
          body: '[#{상호명}] 안녕하세요, #{회원명} #{고객호칭}님.\n#{장소호칭} 일정 변경 및 보강 안내드립니다. 확인 후 문의사항 있으시면 연락 부탁드립니다.\n감사합니다. (#{담당자} #{직함})',
        ),
        CustomMessageTemplate(
          id: 'msg_tpl_gen_special',
          title: '특강 · 프로그램 · 이벤트 안내',
          categoryTag: '안내',
          body: '[#{상호명}] #{회원명} #{고객호칭}님께 특별 프로그램 소식을 전해드립니다!\n참여를 원하시면 #{비용호칭}(#{금액}원) 입금 또는 아래 링크로 편하게 신청해 주세요.\n#{토스송금링크}\n#{카드결제링크}',
        ),
      ];
    }

    final paymentLinks = supportsToss ? '#{토스송금링크}\n#{카드결제링크}' : '#{카드결제링크}';
    if (_isFitness(category) || _isPilates(category)) {
      return [
        CustomMessageTemplate(
          id: 'msg_tpl_fit_renew',
          title: LocalizationService.pick(
            ko: '회차 재등록 혜택 안내',
            en: 'Pass Renewal Benefit Notice',
            ja: '回数券更新のご案内',
            zh: '续课优惠提醒',
            vi: 'Ưu đãi gia hạn gói buổi',
            es: 'Aviso de Renovación de Bono',
          ),
          categoryTag: LocalizationService.pick(
            ko: '재등록',
            en: 'Renewal',
            ja: '更新',
            zh: '续费',
            vi: 'Gia hạn',
            es: 'Renovación',
          ),
          body: LocalizationService.pick(
            ko: '[#{상호명}] #{회원명} #{고객호칭}님, 현재 #{잔여회차}가 얼마 남지 않았습니다.\n연속적인 운동 루틴 유지를 위해 이번 주 내 재등록 시 우선 스케줄 예약을 도와드릴게요!\n문의: #{담당자} #{직함}',
            en: '[#{상호명}] Hi #{회원명}, you only have #{잔여회차} remaining.\nRenew this week to keep priority booking for your preferred workout slots!\nContact: #{담당자} (#{직함})',
            ja: '[#{상호명}] #{회원명}様、現在の残り回数は【#{잔여회차}】となっております。\n今週中の更新で優先スケジュール予約をご案内いたします。\n担当: #{담당자}（#{직함}）',
            zh: '[#{상호명}] 您好 #{회원명}，您当前仅剩【#{잔여회차}】。\n本周内续费可优先锁定理想时段，欢迎随时联系预约！\n联系人: #{담당자}（#{직함}）',
            vi: '[#{상호명}] Xin chào #{회원명}, bạn chỉ còn #{잔여회차}.\nGia hạn trong tuần này để được ưu tiên giữ lịch tập phù hợp nhất nhé!\nLiên hệ: #{담당자} (#{직함})',
            es: '[#{상호명}] Hola #{회원명}, te quedan pocas sesiones (#{잔여회차}).\n¡Renueva esta semana para mantener prioridad en tu horario favorito!\nContacto: #{담당자} (#{직함})',
          ),
        ),
        CustomMessageTemplate(
          id: 'msg_tpl_fit_notice',
          title: LocalizationService.pick(
            ko: '센터 운영시간 / 휴무 공지',
            en: 'Hours & Holiday Notice',
            ja: '営業時間・休館のお知らせ',
            zh: '营业时间与休馆公告',
            vi: 'Thông báo giờ mở cửa / nghỉ lễ',
            es: 'Horario y Días Festivos',
          ),
          categoryTag: LocalizationService.pick(
            ko: '공지사항',
            en: 'Notice',
            ja: 'お知らせ',
            zh: '公告',
            vi: 'Thông báo',
            es: 'Aviso',
          ),
          body: LocalizationService.pick(
            ko: '[#{상호명}] #{회원명} #{고객호칭}님 안녕하세요.\n이번 주 #{장소호칭} 운영 일정 안내드립니다. 예약 변경은 편하신 시간에 답장 주세요!\n감사합니다. (#{담당자} #{직함})',
            en: '[#{상호명}] Hello #{회원명},\nHere is this week\'s schedule for #{장소호칭}. Reply anytime if you need to reschedule!\nBest, #{담당자} (#{직함})',
            ja: '[#{상호명}] #{회원명}様、いつもありがとうございます。\n今週の#{장소호칭}の営業予定をお知らせいたします。ご予約変更はお気軽にご返信ください。\n#{담당자}（#{직함}）',
            zh: '[#{상호명}] 您好 #{회원명}：\n为您同步本周#{장소호칭}的营业安排，如需调整预约请随时回复。\n#{담당자}（#{직함}）',
            vi: '[#{상호명}] Xin chào #{회원명},\nXin gửi lịch hoạt động tuần này của #{장소호칭}. Vui lòng phản hồi nếu cần đổi lịch nhé!\n#{담당자} (#{직함})',
            es: '[#{상호명}] Hola #{회원명},\nTe compartimos el horario de esta semana en #{장소호칭}. Responde cuando necesites reprogramar.\n#{담당자} (#{직함})',
          ),
        ),
      ];
    }

    return [
      CustomMessageTemplate(
        id: 'msg_tpl_gen_notice',
        title: LocalizationService.pick(
          ko: '일정 변경 / 휴강 공지',
          en: 'Schedule Change / Closure Notice',
          ja: '日程変更・休講のお知らせ',
          zh: '调课 / 停课公告',
          vi: 'Thông báo đổi lịch / nghỉ buổi',
          es: 'Cambio de Horario / Aviso',
        ),
        categoryTag: LocalizationService.pick(
          ko: '공지사항',
          en: 'Notice',
          ja: 'お知らせ',
          zh: '公告',
          vi: 'Thông báo',
          es: 'Aviso',
        ),
        body: LocalizationService.pick(
          ko: '[#{상호명}] 안녕하세요, #{회원명} #{고객호칭}님.\n#{장소호칭} 일정 변경 및 보강 안내드립니다. 확인 후 문의사항 있으시면 연락 부탁드립니다.\n감사합니다. (#{담당자} #{직함})',
          en: '[#{상호명}] Hello #{회원명},\nWe have an update regarding #{장소호칭} class schedule and make-up sessions. Please reach out with any questions.\nThank you! (#{담당자}, #{직함})',
          ja: '[#{상호명}] #{회원명}様、いつもありがとうございます。\n#{장소호칭}の日程変更および振替授業のご案内です。ご不明点がございましたらご連絡ください。\n#{담당자}（#{직함}）',
          zh: '[#{상호명}] 您好 #{회원명}：\n现向您发送#{장소호칭}课程调整与补课安排通知，如有疑问欢迎联系。\n谢谢！（#{담당자} #{직함}）',
          vi: '[#{상호명}] Xin chào #{회원명},\nXin gửi thông báo thay đổi lịch và lịch học bù tại #{장소호칭}. Vui lòng liên hệ nếu cần hỗ trợ.\nTrân trọng! (#{담당자}, #{직함})',
          es: '[#{상호명}] Hola #{회원명},\nTe informamos sobre cambios de horario y sesiones de recuperación en #{장소호칭}. Contáctanos ante cualquier duda.\nGracias. (#{담당자}, #{직함})',
        ),
      ),
      CustomMessageTemplate(
        id: 'msg_tpl_gen_special',
        title: LocalizationService.pick(
          ko: '특강 · 프로그램 · 이벤트 안내',
          en: 'Special Workshop / Event Notice',
          ja: '特別講座・イベントのご案内',
          zh: '专题课程 / 活动通知',
          vi: 'Thông báo khóa chuyên đề & sự kiện',
          es: 'Taller Especial / Evento',
        ),
        categoryTag: LocalizationService.pick(
          ko: '안내',
          en: 'Event',
          ja: '案内',
          zh: '活动',
          vi: 'Sự kiện',
          es: 'Evento',
        ),
        body: LocalizationService.pick(
          ko: '[#{상호명}] #{회원명} #{고객호칭}님께 특별 프로그램 소식을 전해드립니다!\n참여를 원하시면 #{비용호칭}(#{금액}) 입금 또는 아래 링크로 편하게 신청해 주세요.\n$paymentLinks',
          en: '[#{상호명}] Hello #{회원명}, check out our upcoming special program!\nTo reserve your spot, pay #{비용호칭} (#{금액}) using the link below.\n$paymentLinks',
          ja: '[#{상호명}] #{회원명}様へ特別講座・イベントのご案内です！\nご参加希望の方は#{비용호칭}（#{금액}）のお支払い、または下記リンクよりお申し込みください。\n$paymentLinks',
          zh: '[#{상호명}] 您好 #{회원명}，诚邀您参加我们的特别课程活动！\n如需报名，请支付#{비용호칭}（#{금액}）或通过下方链接快速申请：\n$paymentLinks',
          vi: '[#{상호명}] Xin chào #{회원명}, mời bạn tham gia chương trình đặc biệt sắp tới!\nĐể giữ chỗ, vui lòng thanh toán #{비용호칭} (#{금액}) qua liên kết dưới đây:\n$paymentLinks',
          es: '[#{상호명}] Hola #{회원명}, ¡te invitamos a nuestro programa especial!\nPara reservar tu plaza, abona #{비용호칭} (#{금액}) mediante el enlace:\n$paymentLinks',
        ),
      ),
    ];
  }

  /// 각 업종별 최적화된 초기 프리셋 생성기
  static CustomCategoryState getDefaultsForIndustry(String category) {
    final lang = LocalizationService.currentLanguage;
    final cur = LocalizationService.currentCurrency;
    if (lang == AppLanguage.korean && cur == AppCurrency.krw) {
      if (_isAcademy(category)) {
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
      } else if (_isFitness(category)) {
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
      } else if (_isPilates(category)) {
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
      } else if (_isMartialArts(category)) {
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
      } else if (_isMusicArt(category)) {
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

    // Global multi-language / multi-currency localized presets
    int s(int krw) => scaleAmount(krw, cur);
    String fmt(int krw) => cur.format(s(krw));
    final moSuffix = LocalizationService.pick(
      ko: '/월',
      en: '/mo',
      ja: '/月',
      zh: '/月',
      vi: '/tháng',
      es: '/mes',
    );

    if (_isAcademy(category)) {
      final g1 = LocalizationService.pick(ko: '초등 영재반', en: 'Elementary Honors', ja: '小学生コース', zh: '小学培优班', vi: 'Lớp Tiểu học', es: 'Primaria Avanzado');
      final g2 = LocalizationService.pick(ko: '중등 내신대비반', en: 'Middle School Core', ja: '中学生定期テスト', zh: '初中同步班', vi: 'Lớp THCS', es: 'Secundaria Base');
      final g3 = LocalizationService.pick(ko: '고등 수능1등급반', en: 'High School Exam Prep', ja: '高校入試対策', zh: '高中冲刺班', vi: 'Luyện thi THPT', es: 'Preparación Universitaria');
      final g4 = LocalizationService.pick(ko: '수학 1:1 클리닉', en: '1:1 Math Clinic', ja: '1:1 数学クリニック', zh: '1对1数学辅导', vi: 'Gia sư Toán 1:1', es: 'Tutoría 1:1 Mates');
      final g5 = LocalizationService.pick(ko: '주말 단과특강', en: 'Weekend Intensive', ja: '週末特別講座', zh: '周末专题班', vi: 'Chuyên đề cuối tuần', es: 'Intensivo Fin de Semana');
      return CustomCategoryState(
        groupCategories: [g1, g2, g3, g4, g5],
        memberTemplates: [
          MemberCategoryTemplate(id: 'tpl_acad_1', label: '$g2 (${fmt(350000)}$moSuffix)', groupName: g2, billingType: BillingType.monthlyRecurring, defaultFee: s(350000), defaultSessions: 0),
          MemberCategoryTemplate(id: 'tpl_acad_2', label: '$g3 (${fmt(420000)}$moSuffix)', groupName: g3, billingType: BillingType.monthlyRecurring, defaultFee: s(420000), defaultSessions: 0),
          MemberCategoryTemplate(id: 'tpl_acad_3', label: '$g4 8x (${fmt(320000)})', groupName: g4, billingType: BillingType.sessionBased, defaultFee: s(320000), defaultSessions: 8),
          MemberCategoryTemplate(id: 'tpl_acad_4', label: '$g1 (${fmt(280000)}$moSuffix)', groupName: g1, billingType: BillingType.monthlyRecurring, defaultFee: s(280000), defaultSessions: 0),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(id: 'inv_tpl_acad_1', title: LocalizationService.pick(ko: '정규 수강료 안내', en: 'Monthly Tuition', ja: '月額受講料', zh: '常规月度学费', vi: 'Học phí định kỳ', es: 'Cuota Mensual'), defaultAmount: s(350000), category: LocalizationService.pick(ko: '정기수납', en: 'Tuition', ja: '授業料', zh: '学费', vi: 'Học phí', es: 'Cuota')),
          InvoiceItemTemplate(id: 'inv_tpl_acad_2', title: LocalizationService.pick(ko: '학기 교재비 / 워크북', en: 'Textbooks & Workbook', ja: '教材・ワークブック費', zh: '学期教材与练习册', vi: 'Giáo trình & bài tập', es: 'Libros y Cuaderno'), defaultAmount: s(35000), category: LocalizationService.pick(ko: '교재/재료', en: 'Books', ja: '教材', zh: '教材', vi: 'Giáo trình', es: 'Material')),
          InvoiceItemTemplate(id: 'inv_tpl_acad_3', title: LocalizationService.pick(ko: '방학 집중특강 수강료', en: 'Break Intensive Course', ja: '季節講習受講料', zh: '假期集训班学费', vi: 'Khóa tăng cường kỳ nghỉ', es: 'Curso Intensivo'), defaultAmount: s(250000), category: LocalizationService.pick(ko: '특강', en: 'Workshop', ja: '講習', zh: '特训', vi: 'Chuyên đề', es: 'Taller')),
          InvoiceItemTemplate(id: 'inv_tpl_acad_4', title: LocalizationService.pick(ko: '전국 모의고사 응시료', en: 'Mock Exam Fee', ja: '模試受験料', zh: '模拟考报名费', vi: 'Lệ phí thi thử', es: 'Examen Simulacro'), defaultAmount: s(20000), category: LocalizationService.pick(ko: '시험/평가', en: 'Exam', ja: '試験', zh: '考试', vi: 'Thi', es: 'Examen')),
        ],
      );
    } else if (_isFitness(category)) {
      final g1 = LocalizationService.pick(ko: '1:1 개인 PT', en: '1:1 Personal Training', ja: '1:1 パーソナルPT', zh: '1对1私教课', vi: 'PT Cá nhân 1:1', es: 'Entrenamiento 1:1');
      final g2 = LocalizationService.pick(ko: '2:1 듀엣 PT', en: '2:1 Duet PT', ja: '2:1 ペアPT', zh: '2对1双人私教', vi: 'PT Đôi 2:1', es: 'Entrenamiento Dúo 2:1');
      final g3 = LocalizationService.pick(ko: '바디프로필 집중반', en: 'Body Transformation', ja: 'ボディメイク集中', zh: '减脂塑形集训', vi: 'Siết cân hình thể', es: 'Transformación Física');
      final g4 = LocalizationService.pick(ko: '체형교정 재활반', en: 'Posture & Rehab', ja: '姿勢改善・リハビリ', zh: '体态康复纠正', vi: 'Phục hồi tư thế', es: 'Postura y Rehab');
      final g5 = LocalizationService.pick(ko: '일반 헬스이용권', en: 'Gym Membership', ja: 'ジム一般会員', zh: '常规健身月卡', vi: 'Thẻ tập Gym', es: 'Membresía Gimnasio');
      return CustomCategoryState(
        groupCategories: [g1, g2, g3, g4, g5],
        memberTemplates: [
          MemberCategoryTemplate(id: 'tpl_fit_1', label: '1:1 PT 10x (${fmt(750000)})', groupName: g1, billingType: BillingType.sessionBased, defaultFee: s(750000), defaultSessions: 10),
          MemberCategoryTemplate(id: 'tpl_fit_2', label: '1:1 PT 30x (${fmt(2100000)})', groupName: g1, billingType: BillingType.sessionBased, defaultFee: s(2100000), defaultSessions: 30),
          MemberCategoryTemplate(id: 'tpl_fit_3', label: '2:1 PT 10x (${fmt(500000)})', groupName: g2, billingType: BillingType.sessionBased, defaultFee: s(500000), defaultSessions: 10),
          MemberCategoryTemplate(id: 'tpl_fit_4', label: '$g5 (${fmt(240000)}$moSuffix)', groupName: g5, billingType: BillingType.monthlyRecurring, defaultFee: s(240000), defaultSessions: 0),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(id: 'inv_tpl_fit_1', title: LocalizationService.pick(ko: '1:1 PT 10회 재등록', en: '1:1 PT 10-Session Renewal', ja: '1:1 PT 10回更新', zh: '1对1私教10节续课', vi: 'Gia hạn gói PT 10 buổi', es: 'Bono 10 Sesiones PT'), defaultAmount: s(750000), category: 'PT'),
          InvoiceItemTemplate(id: 'inv_tpl_fit_2', title: LocalizationService.pick(ko: '1:1 PT 20회 패키지', en: '1:1 PT 20-Session Pack', ja: '1:1 PT 20回パック', zh: '1对1私教20节套餐', vi: 'Gói PT 20 buổi', es: 'Pack 20 Sesiones PT'), defaultAmount: s(1400000), category: LocalizationService.pick(ko: '패키지', en: 'Package', ja: 'パック', zh: '套餐', vi: 'Gói', es: 'Pack')),
          InvoiceItemTemplate(id: 'inv_tpl_fit_3', title: LocalizationService.pick(ko: '개인 락커 & 운동복 이용료', en: 'Locker & Towel Rental', ja: 'ロッカー・ウェア利用料', zh: '储物柜及运动服租借', vi: 'Thuê tủ đồ & khăn tập', es: 'Taquilla y Ropa'), defaultAmount: s(30000), category: LocalizationService.pick(ko: '부대시설', en: 'Add-on', ja: 'オプション', zh: '附加费', vi: 'Tiện ích', es: 'Extra')),
          InvoiceItemTemplate(id: 'inv_tpl_fit_4', title: LocalizationService.pick(ko: '1일 체험 레슨권', en: '1-Day Trial Pass', ja: '1日体験レッスン', zh: '单日体验课', vi: 'Vé tập thử 1 ngày', es: 'Pase Prueba 1 Día'), defaultAmount: s(30000), category: LocalizationService.pick(ko: '체험', en: 'Trial', ja: '体験', zh: '体验', vi: 'Thử', es: 'Prueba')),
        ],
      );
    } else if (_isPilates(category)) {
      final g1 = LocalizationService.pick(ko: '개인 기구필라테스', en: 'Private Reformer Pilates', ja: 'プライベートマシンピラティス', zh: '私教器械普拉提', vi: 'Pilates Máy 1:1', es: 'Pilates Reformer 1:1');
      final g2 = LocalizationService.pick(ko: '4:1 소그룹 리포머', en: 'Small Group Reformer', ja: '4:1 少人数リフォーマー', zh: '4对1小团器械课', vi: 'Nhóm nhỏ Reformer', es: 'Reformer Grupo Reducido');
      final g3 = LocalizationService.pick(ko: '체형교정 요가', en: 'Alignment Yoga', ja: '姿勢改善ヨガ', zh: '体态塑形瑜伽', vi: 'Yoga Chỉnh dáng', es: 'Yoga Postural');
      final g4 = LocalizationService.pick(ko: '주말 댄스/안무반', en: 'Weekend Choreography', ja: '週末ダンスクラス', zh: '周末舞蹈编舞班', vi: 'Lớp Nhảy cuối tuần', es: 'Coreografía Fin de Semana');
      final g5 = LocalizationService.pick(ko: '산전산후 케어반', en: 'Prenatal & Postnatal', ja: 'マタニティ・産後ケア', zh: '产前产后康复班', vi: 'Chăm sóc Mẹ bầu', es: 'Pre y Postparto');
      return CustomCategoryState(
        groupCategories: [g1, g2, g3, g4, g5],
        memberTemplates: [
          MemberCategoryTemplate(id: 'tpl_pil_1', label: '$g1 10x (${fmt(700000)})', groupName: g1, billingType: BillingType.sessionBased, defaultFee: s(700000), defaultSessions: 10),
          MemberCategoryTemplate(id: 'tpl_pil_2', label: '$g2 20x (${fmt(450000)})', groupName: g2, billingType: BillingType.sessionBased, defaultFee: s(450000), defaultSessions: 20),
          MemberCategoryTemplate(id: 'tpl_pil_3', label: '$g3 (${fmt(180000)}$moSuffix)', groupName: g3, billingType: BillingType.monthlyRecurring, defaultFee: s(180000), defaultSessions: 0),
          MemberCategoryTemplate(id: 'tpl_pil_4', label: '$g4 (${fmt(160000)}$moSuffix)', groupName: g4, billingType: BillingType.monthlyRecurring, defaultFee: s(160000), defaultSessions: 0),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(id: 'inv_tpl_pil_1', title: LocalizationService.pick(ko: '기구필라테스 10회 레슨비', en: 'Reformer Pilates 10-Pack', ja: 'マシンピラティス10回券', zh: '器械普拉提10次卡', vi: 'Gói Pilates 10 buổi', es: 'Bono 10 Clases Pilates'), defaultAmount: s(700000), category: LocalizationService.pick(ko: '레슨비', en: 'Lessons', ja: 'レッスン', zh: '课时费', vi: 'Học phí', es: 'Clases')),
          InvoiceItemTemplate(id: 'inv_tpl_pil_2', title: LocalizationService.pick(ko: '소그룹 리포머 20회 재등록', en: 'Group Reformer 20-Pack', ja: '少人数リフォーマー20回更新', zh: '小团课20次卡续费', vi: 'Gia hạn nhóm 20 buổi', es: 'Renovación Grupo 20x'), defaultAmount: s(450000), category: LocalizationService.pick(ko: '회수권', en: 'Pass', ja: '回数券', zh: '次卡', vi: 'Gói buổi', es: 'Bono')),
          InvoiceItemTemplate(id: 'inv_tpl_pil_3', title: LocalizationService.pick(ko: '미끄럼방지 토삭스 / 소도구', en: 'Grip Socks & Props', ja: '滑り止めソックス・小物', zh: '防滑袜与小器材', vi: 'Tất chống trượt & dụng cụ', es: 'Calcetines Grip'), defaultAmount: s(25000), category: LocalizationService.pick(ko: '용품', en: 'Gear', ja: '用品', zh: '用品', vi: 'Phụ kiện', es: 'Equipo')),
          InvoiceItemTemplate(id: 'inv_tpl_pil_4', title: LocalizationService.pick(ko: '체형분석 & 1회 체험권', en: 'Posture Check & Trial', ja: '姿勢診断・1回体験', zh: '体态评估与单次体验', vi: 'Đánh giá & tập thử 1 buổi', es: 'Evaluación y Prueba'), defaultAmount: s(35000), category: LocalizationService.pick(ko: '체험', en: 'Trial', ja: '体験', zh: '体验', vi: 'Thử', es: 'Prueba')),
        ],
      );
    } else if (_isMartialArts(category)) {
      final g1 = LocalizationService.pick(ko: '유치부 꿈나무반', en: 'Little Tigers (Ages 4-6)', ja: '幼児クラス', zh: '幼儿启蒙班', vi: 'Lớp Mầm non', es: 'Infantil (4-6 años)');
      final g2 = LocalizationService.pick(ko: '초등 정규수련반', en: 'Youth Regular Class', ja: '小学生レギュラー', zh: '少儿常规班', vi: 'Lớp Thiếu nhi', es: 'Juvenil Regular');
      final g3 = LocalizationService.pick(ko: '중고등 품새반', en: 'Teens Poomsae & Sparring', ja: '中高生型・組手', zh: '青少年品势班', vi: 'Lớp Quyền & Đối kháng', es: 'Poomsae y Combate');
      final g4 = LocalizationService.pick(ko: '시범단 / 선수반', en: 'Demo & Competition Team', ja: '演武団・選手コース', zh: '示范团 / 选手班', vi: 'Đội tuyển / Biểu diễn', es: 'Equipo Competición');
      final g5 = LocalizationService.pick(ko: '성인 실전호신술', en: 'Adult Self-Defense', ja: '成人護身術', zh: '成人防身术', vi: 'Tự vệ Người lớn', es: 'Defensa Personal Adultos');
      return CustomCategoryState(
        groupCategories: [g1, g2, g3, g4, g5],
        memberTemplates: [
          MemberCategoryTemplate(id: 'tpl_tkd_1', label: '$g2 (${fmt(180000)}$moSuffix)', groupName: g2, billingType: BillingType.monthlyRecurring, defaultFee: s(180000), defaultSessions: 0),
          MemberCategoryTemplate(id: 'tpl_tkd_2', label: '$g1 (${fmt(170000)}$moSuffix)', groupName: g1, billingType: BillingType.monthlyRecurring, defaultFee: s(170000), defaultSessions: 0),
          MemberCategoryTemplate(id: 'tpl_tkd_3', label: '$g3 (${fmt(190000)}$moSuffix)', groupName: g3, billingType: BillingType.monthlyRecurring, defaultFee: s(190000), defaultSessions: 0),
          MemberCategoryTemplate(id: 'tpl_tkd_4', label: '$g4 (${fmt(120000)}$moSuffix)', groupName: g4, billingType: BillingType.monthlyRecurring, defaultFee: s(120000), defaultSessions: 0),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(id: 'inv_tpl_tkd_1', title: LocalizationService.pick(ko: '정규 수련 교육비', en: 'Monthly Training Fee', ja: '月謝（レギュラー）', zh: '常规训练学费', vi: 'Học phí võ thuật', es: 'Mensualidad Clases'), defaultAmount: s(180000), category: LocalizationService.pick(ko: '교육비', en: 'Tuition', ja: '月謝', zh: '学费', vi: 'Học phí', es: 'Cuota')),
          InvoiceItemTemplate(id: 'inv_tpl_tkd_2', title: LocalizationService.pick(ko: '정기 승품·승단 심사비', en: 'Belt Promotion Test Fee', ja: '昇級・昇段審査料', zh: '考级 / 升段评审费', vi: 'Lệ phí thi lên đai', es: 'Examen de Cinturón'), defaultAmount: s(60000), category: LocalizationService.pick(ko: '심사비', en: 'Grading', ja: '審査料', zh: '考级', vi: 'Thi đai', es: 'Examen')),
          InvoiceItemTemplate(id: 'inv_tpl_tkd_3', title: LocalizationService.pick(ko: '전용 도복 및 보호장구', en: 'Uniform & Sparring Gear', ja: '道着・防具セット', zh: '道服与护具费用', vi: 'Võ phục & bảo hộ', es: 'Dobok y Protecciones'), defaultAmount: s(70000), category: LocalizationService.pick(ko: '용품비', en: 'Uniform', ja: '道着', zh: '装备', vi: 'Dụng cụ', es: 'Equipo')),
          InvoiceItemTemplate(id: 'inv_tpl_tkd_4', title: LocalizationService.pick(ko: '방학 특별캠프 참가비', en: 'Seasonal Camp Fee', ja: '合宿・特別キャンプ費', zh: '假期特训营报名费', vi: 'Phí trại hè võ thuật', es: 'Campamento Especial'), defaultAmount: s(50000), category: LocalizationService.pick(ko: '행사/캠프', en: 'Camp', ja: 'イベント', zh: '活动', vi: 'Sự kiện', es: 'Campamento')),
        ],
      );
    } else if (_isMusicArt(category)) {
      final g1 = LocalizationService.pick(ko: '피아노 기초/바이엘', en: 'Piano Foundations', ja: 'ピアノ基礎・バイエル', zh: '钢琴基础班', vi: 'Piano Cơ bản', es: 'Piano Iniciación');
      final g2 = LocalizationService.pick(ko: '체르니/클래식 전공반', en: 'Classical Repertoire', ja: 'クラシック専門コース', zh: '古典钢琴提高班', vi: 'Piano Cổ điển', es: 'Repertorio Clásico');
      final g3 = LocalizationService.pick(ko: '도예 정규물레반', en: 'Wheel Pottery Studio', ja: '陶芸ろくろコース', zh: '拉坯陶艺常规班', vi: 'Lớp Gốm bàn xoay', es: 'Torno y Cerámica');
      final g4 = LocalizationService.pick(ko: '미술 창의조형반', en: 'Creative Fine Arts', ja: '絵画・造形クラス', zh: '少儿创意美术班', vi: 'Mỹ thuật Sáng tạo', es: 'Artes Plásticas');
      final g5 = LocalizationService.pick(ko: '원데이 힐링클래스', en: '1-Day Creative Workshop', ja: '1日体験ワークショップ', zh: '单日治愈体验课', vi: 'Workshop 1 ngày', es: 'Taller de 1 Día');
      return CustomCategoryState(
        groupCategories: [g1, g2, g3, g4, g5],
        memberTemplates: [
          MemberCategoryTemplate(id: 'tpl_art_1', label: '$g1 (${fmt(200000)}$moSuffix)', groupName: g1, billingType: BillingType.monthlyRecurring, defaultFee: s(200000), defaultSessions: 0),
          MemberCategoryTemplate(id: 'tpl_art_2', label: '$g3 4x (${fmt(240000)})', groupName: g3, billingType: BillingType.sessionBased, defaultFee: s(240000), defaultSessions: 4),
          MemberCategoryTemplate(id: 'tpl_art_3', label: '$g4 (${fmt(180000)}$moSuffix)', groupName: g4, billingType: BillingType.monthlyRecurring, defaultFee: s(180000), defaultSessions: 0),
          MemberCategoryTemplate(id: 'tpl_art_4', label: '$g5 1x (${fmt(70000)})', groupName: g5, billingType: BillingType.sessionBased, defaultFee: s(70000), defaultSessions: 1),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(id: 'inv_tpl_art_1', title: LocalizationService.pick(ko: '정규 수강료 안내', en: 'Monthly Studio Tuition', ja: '月額レッスン料', zh: '常规课程学费', vi: 'Học phí hàng tháng', es: 'Cuota Mensual'), defaultAmount: s(200000), category: LocalizationService.pick(ko: '수강료', en: 'Tuition', ja: 'レッスン料', zh: '学费', vi: 'Học phí', es: 'Cuota')),
          InvoiceItemTemplate(id: 'inv_tpl_art_2', title: LocalizationService.pick(ko: '도예 점토/가마 소성비', en: 'Clay & Kiln Firing Fee', ja: '粘土・窯焼成料', zh: '陶泥与窑烧材料费', vi: 'Đất sét & phí nung gốm', es: 'Arcilla y Horno'), defaultAmount: s(40000), category: LocalizationService.pick(ko: '재료/소성', en: 'Materials', ja: '材料費', zh: '材料费', vi: 'Vật liệu', es: 'Material')),
          InvoiceItemTemplate(id: 'inv_tpl_art_3', title: LocalizationService.pick(ko: '정기 연주회/콩쿠르 참가비', en: 'Recital / Competition Fee', ja: '発表会・コンクール参加費', zh: '音乐会 / 比赛报名费', vi: 'Phí biểu diễn / hội thi', es: 'Recital / Concurso'), defaultAmount: s(80000), category: LocalizationService.pick(ko: '행사', en: 'Event', ja: '行事', zh: '活动', vi: 'Sự kiện', es: 'Evento')),
          InvoiceItemTemplate(id: 'inv_tpl_art_4', title: LocalizationService.pick(ko: '교재 및 악보집 구입비', en: 'Sheet Music & Art Kit', ja: '楽譜・教材購入費', zh: '教材与乐谱费', vi: 'Giáo trình & bản nhạc', es: 'Partituras y Kit'), defaultAmount: s(25000), category: LocalizationService.pick(ko: '교재', en: 'Books', ja: '教材', zh: '教材', vi: 'Sách', es: 'Libros')),
        ],
      );
    } else {
      final g1 = LocalizationService.pick(ko: '일반 정규반', en: 'Standard Regular', ja: '一般レギュラー', zh: '常规课程班', vi: 'Lớp Tiêu chuẩn', es: 'Grupo Regular');
      final g2 = LocalizationService.pick(ko: '맞춤 1:1 레슨', en: 'Custom 1:1 Session', ja: '個別 1:1 レッスン', zh: '1对1定制课', vi: 'Học 1:1 Tùy chỉnh', es: 'Sesión 1:1');
      final g3 = LocalizationService.pick(ko: '주말 특별반', en: 'Weekend Special', ja: '週末特別クラス', zh: '周末特色班', vi: 'Lớp Cuối tuần', es: 'Especial Fin de Semana');
      final g4 = LocalizationService.pick(ko: '자유 이용권', en: 'Open Access Pass', ja: 'フリーパス', zh: '自由畅享卡', vi: 'Thẻ Tự do', es: 'Acceso Libre');
      return CustomCategoryState(
        groupCategories: [g1, g2, g3, g4],
        memberTemplates: [
          MemberCategoryTemplate(id: 'tpl_gen_1', label: '$g1 (${fmt(200000)}$moSuffix)', groupName: g1, billingType: BillingType.monthlyRecurring, defaultFee: s(200000), defaultSessions: 0),
          MemberCategoryTemplate(id: 'tpl_gen_2', label: '$g2 10x (${fmt(500000)})', groupName: g2, billingType: BillingType.sessionBased, defaultFee: s(500000), defaultSessions: 10),
          MemberCategoryTemplate(id: 'tpl_gen_3', label: '$g3 (${fmt(150000)}$moSuffix)', groupName: g3, billingType: BillingType.monthlyRecurring, defaultFee: s(150000), defaultSessions: 0),
        ],
        invoiceTemplates: [
          InvoiceItemTemplate(id: 'inv_tpl_gen_1', title: LocalizationService.pick(ko: '정기 이용료 / 회비', en: 'Monthly Membership Fee', ja: '定期利用料・月会費', zh: '月度会费 / 服务费', vi: 'Phí thành viên định kỳ', es: 'Cuota Mensual'), defaultAmount: s(200000), category: LocalizationService.pick(ko: '회비', en: 'Fee', ja: '会費', zh: '会费', vi: 'Học phí', es: 'Cuota')),
          InvoiceItemTemplate(id: 'inv_tpl_gen_2', title: LocalizationService.pick(ko: '10회 이용권 재등록', en: '10-Session Pass Renewal', ja: '10回利用券の更新', zh: '10次卡续费', vi: 'Gia hạn gói 10 buổi', es: 'Bono 10 Sesiones'), defaultAmount: s(500000), category: LocalizationService.pick(ko: '이용권', en: 'Pass', ja: '利用券', zh: '次卡', vi: 'Gói buổi', es: 'Bono')),
          InvoiceItemTemplate(id: 'inv_tpl_gen_3', title: LocalizationService.pick(ko: '소모품 및 재료비', en: 'Supplies & Materials', ja: '消耗品・材料費', zh: '耗材与材料费', vi: 'Vật tư & dụng cụ', es: 'Materiales'), defaultAmount: s(30000), category: LocalizationService.pick(ko: '부대비용', en: 'Supplies', ja: '備品', zh: '杂费', vi: 'Phụ phí', es: 'Extras')),
        ],
      );
    }
  }
}
