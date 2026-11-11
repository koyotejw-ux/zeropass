import 'localization_service.dart';

/// Country- and language-aware workflow helper for studio terminology,
/// regional payment channels, tax rules, categories, and starter message templates.
class RegionWorkflowService {
  RegionWorkflowService._();

  /// Whether Korea-only `supertoss://` deep-link is valid for [currency].
  static bool supportsTossTransfer(AppCurrency currency) =>
      currency == AppCurrency.krw;

  /// Country-standard contractor withholding tax rate (default when applicable).
  static double defaultWithholdingRate(AppCurrency currency) {
    switch (currency) {
      case AppCurrency.krw:
        return 0.033; // 3.3% 프리랜서/강사 사업소득 원천징수
      case AppCurrency.jpy:
        return 0.1021; // 10.21% 源泉徴収税率
      case AppCurrency.vnd:
        return 0.10; // 10% Thuế TNCN vãng lai
      case AppCurrency.usd:
      case AppCurrency.cny:
      case AppCurrency.eur:
      case AppCurrency.gbp:
      case AppCurrency.sgd:
      case AppCurrency.aud:
      case AppCurrency.cad:
        return 0.0; // Independent contractor gross payout (1099 / self-assessment)
    }
  }

  /// Localized payment method display label preserving KR parity.
  static String paymentMethodLabel(
    String method,
    AppLanguage lang, {
    AppCurrency? currency,
  }) {
    final code = lang.code;
    switch (method.toUpperCase()) {
      case 'TRANSFER':
        return const {
              'ko': '계좌이체',
              'en': 'Bank Transfer / ACH',
              'ja': '銀行振込',
              'zh': '银行转账',
              'vi': 'Chuyển khoản ngân hàng',
              'es': 'Transferencia bancaria',
            }[code] ??
            'Bank Transfer';
      case 'CARD':
        return const {
              'ko': '신용카드(현장)',
              'en': 'Card (In-Person POS)',
              'ja': 'クレジットカード(店頭)',
              'zh': '银行卡(现场刷卡)',
              'vi': 'Thẻ (Quẹt tại quầy)',
              'es': 'Tarjeta (TPV presencial)',
            }[code] ??
            'Card (In-Person)';
      case 'ONLINE_CARD':
        return const {
              'ko': '비대면 카드결제(온라인)',
              'en': 'Online Card Payment Link',
              'ja': 'オンラインカード決済',
              'zh': '远程在线信用卡支付',
              'vi': 'Thanh toán thẻ trực tuyến',
              'es': 'Pago online con tarjeta',
            }[code] ??
            'Online Card Payment';
      case 'CASH':
        return const {
              'ko': '현금 수납',
              'en': 'Cash',
              'ja': '現金払い',
              'zh': '现金支付',
              'vi': 'Tiền mặt',
              'es': 'Efectivo',
            }[code] ??
            'Cash';
      default:
        return const {
              'ko': '기타 결제',
              'en': 'Other Payment',
              'ja': 'その他の決済',
              'zh': '其他收款方式',
              'vi': 'Hình thức khác',
              'es': 'Otro método',
            }[code] ??
            'Other';
    }
  }

  /// Localized tax evidence label while keeping internal canonical Korean keys compatible.
  static String taxEvidenceLabel(String koEvidence, AppLanguage lang) {
    final keyMap = {
      '세금계산서': 'tax_ev_invoice',
      '신용카드': 'tax_ev_card',
      '현금영수증': 'tax_ev_cash_receipt',
      '원천징수(3.3%)': 'tax_ev_withholding',
      '간이영수증': 'tax_ev_simple',
      '미수취': 'tax_ev_none',
    };
    final key = keyMap[koEvidence];
    if (key == null) return koEvidence;
    if (lang == AppLanguage.korean) return koEvidence;
    // Direct lookup without mutating global state
    const table = {
      'tax_ev_invoice': {
        'en': 'Tax Invoice / Bill',
        'ja': '適格請求書(インボイス)',
        'zh': '增值税发票',
        'vi': 'Hóa đơn GTGT',
        'es': 'Factura fiscal',
      },
      'tax_ev_card': {
        'en': 'Card Receipt',
        'ja': 'カード明細',
        'zh': '刷卡凭条',
        'vi': 'Biên lai thẻ',
        'es': 'Recibo de tarjeta',
      },
      'tax_ev_cash_receipt': {
        'en': 'E-Cash Receipt',
        'ja': '電子領収書',
        'zh': '电子收据',
        'vi': 'Biên lai điện tử',
        'es': 'Recibo electrónico',
      },
      'tax_ev_withholding': {
        'en': 'Tax Withholding',
        'ja': '源泉徴収',
        'zh': '代扣代缴',
        'vi': 'Khấu trừ tại nguồn',
        'es': 'Retención fiscal',
      },
      'tax_ev_simple': {
        'en': 'Simple Receipt',
        'ja': '簡易領収書',
        'zh': '普通收据',
        'vi': 'Phiếu thu',
        'es': 'Recibo simple',
      },
      'tax_ev_none': {
        'en': 'No Receipt',
        'ja': '領収書なし',
        'zh': '无凭证',
        'vi': 'Không chứng từ',
        'es': 'Sin comprobante',
      },
    };
    return table[key]?[lang.code] ?? table[key]?['en'] ?? koEvidence;
  }

  /// Currency-scaled quick increment presets for billing & expense forms.
  static List<int> quickIncrementAmounts(AppCurrency currency, {bool expense = false}) {
    switch (currency) {
      case AppCurrency.krw:
        return expense
            ? const [10000, 50000, 100000, 500000, 1000000]
            : const [10000, 50000, 100000, 300000];
      case AppCurrency.jpy:
        return expense
            ? const [1000, 5000, 10000, 50000, 100000]
            : const [1000, 5000, 10000, 30000];
      case AppCurrency.vnd:
        return expense
            ? const [100000, 500000, 1000000, 5000000, 10000000]
            : const [100000, 500000, 1000000, 3000000];
      case AppCurrency.cny:
        return expense
            ? const [100, 500, 1000, 5000, 10000]
            : const [100, 300, 500, 1000];
      case AppCurrency.usd:
      case AppCurrency.eur:
      case AppCurrency.gbp:
      case AppCurrency.sgd:
      case AppCurrency.aud:
      case AppCurrency.cad:
        return expense
            ? const [10, 50, 100, 500, 1000]
            : const [10, 50, 100, 200];
    }
  }

  /// Standard sibling fixed discount preset per currency.
  static int fixedDiscountPreset(AppCurrency currency) {
    switch (currency) {
      case AppCurrency.krw:
        return 20000;
      case AppCurrency.jpy:
        return 2000;
      case AppCurrency.vnd:
        return 200000;
      case AppCurrency.cny:
        return 100;
      case AppCurrency.usd:
      case AppCurrency.eur:
      case AppCurrency.gbp:
      case AppCurrency.sgd:
      case AppCurrency.aud:
      case AppCurrency.cad:
        return 20;
    }
  }

  /// Country-aware withholding description string.
  static String withholdingDescription(AppLanguage lang, AppCurrency currency) {
    final rate = defaultWithholdingRate(currency);
    final pct = (rate * 100).toStringAsFixed(rate == 0.1021 ? 2 : (rate == 0.033 ? 1 : 0));
    if (rate <= 0) {
      switch (lang) {
        case AppLanguage.korean:
          return '세전 전액 정산 (원천징수 미적용 / 해외 기준)';
        case AppLanguage.english:
          return 'Gross contractor payout (0% withheld — 1099 / self-reported)';
        case AppLanguage.japanese:
          return '総額支払い（源泉徴収なし）';
        case AppLanguage.chinese:
          return '税前全额结算（不预扣税款）';
        case AppLanguage.vietnamese:
          return 'Thanh toán tổng (0% khấu trừ tại nguồn)';
        case AppLanguage.spanish:
          return 'Pago bruto al colaborador (sin retención automática)';
      }
    }
    switch (lang) {
      case AppLanguage.korean:
        return '$pct% 사업소득 원천징수';
      case AppLanguage.english:
        return '$pct% statutory tax withholding (${currency.code})';
      case AppLanguage.japanese:
        return '$pct% 源泉徴収税控除後 (${currency.code})';
      case AppLanguage.chinese:
        return '扣除 $pct% 法定预扣税 (${currency.code})';
      case AppLanguage.vietnamese:
        return 'Khấu trừ $pct% thuế TNCN (${currency.code})';
      case AppLanguage.spanish:
        return 'Retención fiscal del $pct% (${currency.code})';
    }
  }

  /// Localized industry category label while keeping canonical ID for DB storage.
  static String industryCategoryLabel(String canonicalCategory, AppLanguage lang) {
    if (lang == AppLanguage.korean) return canonicalCategory;
    const map = {
      '음악 / 피아노': {
        'en': 'Music / Piano',
        'ja': '音楽 / ピアノ',
        'zh': '音乐 / 钢琴',
        'vi': 'Âm nhạc / Piano',
        'es': 'Música / Piano',
      },
      '입시 / 보습학원': {
        'en': 'Tutoring / Academy',
        'ja': '学習塾 / 受験指導',
        'zh': '学科辅导 / 培训班',
        'vi': 'Gia sư / Trung tâm học',
        'es': 'Academia / Clases',
      },
      '피트니스 / PT': {
        'en': 'Fitness / Personal Training',
        'ja': 'フィットネス / パーソナルジム',
        'zh': '健身 / 私教工作室',
        'vi': 'Thể hình / PT',
        'es': 'Fitness / Entrenador',
      },
      '필라테스 / 요가': {
        'en': 'Pilates / Yoga',
        'ja': 'ピラティス / ヨガ',
        'zh': '普拉提 / 瑜伽',
        'vi': 'Pilates / Yoga',
        'es': 'Pilates / Yoga',
      },
      '무용 / 댄스': {
        'en': 'Dance Studio',
        'ja': 'ダンス / バレエ教室',
        'zh': '舞蹈工作室',
        'vi': 'Nhảy / Múa',
        'es': 'Academia de baile',
      },
      '태권도 / 무술': {
        'en': 'Martial Arts / Taekwondo',
        'ja': '武道 / 空手 / テコンドー',
        'zh': '跆拳道 / 武术馆',
        'vi': 'Võ thuật / Taekwondo',
        'es': 'Artes marciales / Taekwondo',
      },
      '미술 / 도예공방': {
        'en': 'Art / Ceramics Workshop',
        'ja': '美術 / 陶芸アトリエ',
        'zh': '美术 / 陶艺工坊',
        'vi': 'Mỹ thuật / Xưởng gốm',
        'es': 'Arte / Taller de cerámica',
      },
      '수영 / 스포츠': {
        'en': 'Swimming / Sports',
        'ja': '水泳 / スポーツクラブ',
        'zh': '游泳 / 体育运动',
        'vi': 'Bơi lội / Thể thao',
        'es': 'Natación / Deportes',
      },
      '어학 / 코딩': {
        'en': 'Language / Coding',
        'ja': '語学 / プログラミング',
        'zh': '语言 / 编程教育',
        'vi': 'Ngoại ngữ / Lập trình',
        'es': 'Idiomas / Programación',
      },
      '스터디룸 / 공간대여': {
        'en': 'Study Lounge / Space Rental',
        'ja': '自習室 / レンタルスペース',
        'zh': '自习室 / 空间租赁',
        'vi': 'Phòng học / Thuê không gian',
        'es': 'Sala de estudio / Alquiler',
      },
      '기타 / 맞춤업종': {
        'en': 'Other / Custom Business',
        'ja': 'その他 / カスタム業種',
        'zh': '其他 / 自定义行业',
        'vi': 'Khác / Tùy chỉnh',
        'es': 'Otro / Personalizado',
      },
    };
    return map[canonicalCategory]?[lang.code] ??
        map[canonicalCategory]?['en'] ??
        canonicalCategory;
  }

  /// Localized display label for built-in Korean terminology options.
  static String termOptionLabel(String koTerm, AppLanguage lang) {
    if (lang == AppLanguage.korean) return koTerm;
    const map = {
      '회원': {'en': 'Member', 'ja': '会員', 'zh': '会员', 'vi': 'Hội viên', 'es': 'Miembro'},
      '수강생': {'en': 'Student', 'ja': '受講生', 'zh': '学员', 'vi': 'Học viên', 'es': 'Alumno'},
      '원생': {'en': 'Enrollee', 'ja': '生徒', 'zh': '学生', 'vi': 'Học sinh', 'es': 'Estudiante'},
      '학생': {'en': 'Student', 'ja': '生徒', 'zh': '学生', 'vi': 'Học sinh', 'es': 'Estudiante'},
      '원아': {'en': 'Child', 'ja': '園児', 'zh': '幼儿', 'vi': 'Bé', 'es': 'Alumno'},
      '고객': {'en': 'Client', 'ja': 'お客様', 'zh': '客户', 'vi': 'Khách hàng', 'es': 'Cliente'},
      '이용자': {'en': 'User', 'ja': '利用者', 'zh': '用户', 'vi': 'Người dùng', 'es': 'Usuario'},
      '수련생': {'en': 'Trainee', 'ja': '道場生', 'zh': '学员', 'vi': 'Võ sinh', 'es': 'Practicante'},
      '수강료': {'en': 'Tuition', 'ja': '月謝', 'zh': '学费', 'vi': 'Học phí', 'es': 'Matrícula'},
      '회비': {'en': 'Membership Fee', 'ja': '会費', 'zh': '会费', 'vi': 'Hội phí', 'es': 'Cuota'},
      '이용료': {'en': 'Usage Fee', 'ja': '利用料', 'zh': '使用费', 'vi': 'Phí sử dụng', 'es': 'Tarifa'},
      '레슨비': {'en': 'Lesson Fee', 'ja': 'レッスン料', 'zh': '课时费', 'vi': 'Phí tập', 'es': 'Cuota de clase'},
      '원비': {'en': 'Tuition Fee', 'ja': '授業料', 'zh': '学费', 'vi': 'Học phí', 'es': 'Mensualidad'},
      '교육비': {'en': 'Training Fee', 'ja': '指導料', 'zh': '培训费', 'vi': 'Phí đào tạo', 'es': 'Cuota de curso'},
      '대표': {'en': 'Director', 'ja': '代表', 'zh': '主理人', 'vi': 'Giám đốc', 'es': 'Director'},
      '원장': {'en': 'Principal', 'ja': '院長', 'zh': '校长', 'vi': 'Hiệu trưởng', 'es': 'Director'},
      '실장': {'en': 'Manager', 'ja': 'マネージャー', 'zh': '店长', 'vi': 'Quản lý', 'es': 'Gerente'},
      '선생님': {'en': 'Teacher', 'ja': '先生', 'zh': '老师', 'vi': 'Giáo viên', 'es': 'Profesor'},
      '코치': {'en': 'Coach', 'ja': 'コーチ', 'zh': '教练', 'vi': 'Huấn luyện viên', 'es': 'Entrenador'},
      '강사': {'en': 'Instructor', 'ja': '講師', 'zh': '讲师', 'vi': 'Giảng viên', 'es': 'Instructor'},
      '관장': {'en': 'Master', 'ja': '館長', 'zh': '馆长', 'vi': 'Võ sư trưởng', 'es': 'Maestro'},
      '관리자': {'en': 'Admin', 'ja': '管理者', 'zh': '管理员', 'vi': 'Quản trị viên', 'es': 'Administrador'},
      '스튜디오': {'en': 'Studio', 'ja': 'スタジオ', 'zh': '工作室', 'vi': 'Studio', 'es': 'Estudio'},
      '학원': {'en': 'Academy', 'ja': '教室', 'zh': '学院', 'vi': 'Trung tâm', 'es': 'Academia'},
      '센터': {'en': 'Center', 'ja': 'センター', 'zh': '中心', 'vi': 'Trung tâm', 'es': 'Centro'},
      '공방': {'en': 'Workshop', 'ja': 'アトリエ', 'zh': '工坊', 'vi': 'Xưởng', 'es': 'Taller'},
      '매장': {'en': 'Shop', 'ja': '店舗', 'zh': '门店', 'vi': 'Cửa hàng', 'es': 'Local'},
      '체육관': {'en': 'Gym', 'ja': '道場・ジム', 'zh': '武馆', 'vi': 'Phòng tập', 'es': 'Gimnasio'},
      '연습실': {'en': 'Practice Room', 'ja': '練習室', 'zh': '练习室', 'vi': 'Phòng tập', 'es': 'Sala de ensayo'},
    };
    return map[koTerm]?[lang.code] ?? map[koTerm]?['en'] ?? koTerm;
  }

  /// Localizes studio role/member/fee/place words when custom override isn't set.
  static String localizedRoleTitle(String canonicalCategory, String koDefault, AppLanguage lang) {
    if (lang == AppLanguage.korean) return koDefault;
    return termOptionLabel(koDefault, lang);
  }

  static String localizedMemberWord(String koDefault, AppLanguage lang) {
    if (lang == AppLanguage.korean) return koDefault;
    return termOptionLabel(koDefault, lang);
  }

  static String localizedFeeWord(String koDefault, AppLanguage lang) {
    if (lang == AppLanguage.korean) return koDefault;
    return termOptionLabel(koDefault, lang);
  }

  static String localizedPlaceTitle(String koDefault, AppLanguage lang) {
    if (lang == AppLanguage.korean) return koDefault;
    return termOptionLabel(koDefault, lang);
  }

  /// Localized studio default profile metadata by language/country.
  static Map<String, String> defaultStudioMetadata(AppLanguage lang, AppCurrency currency) {
    switch (lang) {
      case AppLanguage.korean:
        return {
          'studioName': '마인드핏 아카데미 & 스튜디오',
          'instructorName': '김서연',
          'bankName': '토스뱅크',
          'accountNumber': '1000-2026-8899',
          'accountHolder': '김서연',
        };
      case AppLanguage.english:
        return {
          'studioName': 'MindFit Studio & Academy',
          'instructorName': 'Sarah Kim',
          'bankName': currency == AppCurrency.gbp ? 'HSBC UK' : 'Chase / Zelle',
          'accountNumber': currency == AppCurrency.gbp ? '40-12-34 88990011' : 'pay@mindfitstudio.com',
          'accountHolder': 'MindFit Studio LLC',
        };
      case AppLanguage.japanese:
        return {
          'studioName': 'マインドフィット スタジオ＆教室',
          'instructorName': '佐藤 美咲',
          'bankName': '三菱UFJ銀行',
          'accountNumber': '普通 1234567',
          'accountHolder': 'サトウ ミサキ',
        };
      case AppLanguage.chinese:
        return {
          'studioName': '悦动未来工作室与学院',
          'instructorName': '李明',
          'bankName': '招商银行',
          'accountNumber': '6225 8801 2026 8899',
          'accountHolder': '李明',
        };
      case AppLanguage.vietnamese:
        return {
          'studioName': 'Học viện & Studio MindFit',
          'instructorName': 'Nguyễn Minh Anh',
          'bankName': 'Vietcombank',
          'accountNumber': '1020 2026 8899',
          'accountHolder': 'NGUYEN MINH ANH',
        };
      case AppLanguage.spanish:
        return {
          'studioName': 'Academia y Estudio MindFit',
          'instructorName': 'Carlos García',
          'bankName': 'Banco Santander',
          'accountNumber': 'ES91 0049 1500 0512 3456 7892',
          'accountHolder': 'MindFit Estudio SL',
        };
    }
  }

  /// Localized default invoice template. Preserves KRW Toss UX and adapts non-KRW globally.
  static String defaultInvoiceTemplate(AppLanguage lang, AppCurrency currency) {
    final isKr = lang == AppLanguage.korean;
    if (isKr) {
      return '''[#{상호명}] #{청구제목}
  
안녕하세요, #{상호명}입니다.
#{회원명} #{고객호칭}님의 #{비용호칭} 내역 안내드립니다.

────────────────
[청구 내역]
• 수납 금액 : #{금액}
• 납부 기한 : #{납부기한}까지
• 입금 계좌 : #{계좌정보}
────────────────

${supportsTossTransfer(currency) ? '[간편 입금 안내]\n• 복사용 계좌 : #{계좌복사용}\n(계좌번호를 복사 후 토스나 은행 앱을 여시면 바로 송금됩니다)' : '[해외/현지 결제 안내]\n• 결제 수단 : #{결제수단안내}'}

소중한 #{고객호칭}님과 함께할 수 있어 늘 감사드리며,
입금 확인 즉시 등록·갱신됩니다.
감사합니다.''';
    }

    switch (lang) {
      case AppLanguage.english:
        return '''[#{상호명}] #{청구제목}

Hello from #{상호명}.
Here is the #{비용호칭} billing statement for #{회원명}.

────────────────
[Invoice Summary]
• Amount Due: #{금액}
• Due Date: #{납부기한}
• Pay To: #{계좌정보}
• Accepted Channels: #{결제수단안내}
• Pay by Card: #{카드결제링크}
────────────────

Thank you for choosing #{상호명}. Your pass will be updated right upon payment confirmation.''';
      case AppLanguage.japanese:
        return '''[#{상호명}] #{청구제목}のご案内

いつもお世話になっております。#{상호명}です。
#{회원명} 様の#{비용호칭}をご案内いたします。

────────────────
[ご請求内容]
• ご請求金額 : #{금액}
• お支払期限 : #{납부期限}
• お振込先 : #{계좌정보}
• 対応決済手段 : #{결제수단안내}
• カード決済リンク : #{카드결제링크}
────────────────

ご入金を確認次第、利用回数を即時更新いたします。
よろしくお願いいたします。'''.replaceAll('#{납부期限}', '#{납부기한}');
      case AppLanguage.chinese:
        return '''[#{상호명}] #{청구제목}

您好，这里是 #{상호명}。
现向 #{회원명} 发送本次#{비용호칭}账单明细：

────────────────
[账单详情]
• 应收金额 : #{금액}
• 截止日期 : #{납부기한}
• 收款账户 : #{계좌정보}
• 支持方式 : #{결제수단안내}
• 在线刷卡支付 : #{카드결제링크}
────────────────

感谢您的支持，确认收款后将立即为您更新课时与会员状态。''';
      case AppLanguage.vietnamese:
        return '''[#{상호명}] Thông báo #{청구제목}

Xin chào từ #{상호명}.
Chúng tôi gửi chi tiết #{비용호칭} của #{회원명}:

────────────────
[Chi tiết thanh toán]
• Số tiền: #{금액}
• Hạn thanh toán: #{납부기한}
• Tài khoản nhận: #{계좌정보}
• Kênh hỗ trợ: #{결제수단안내}
• Thanh toán thẻ: #{카드결제링크}
────────────────

Cảm ơn bạn đã đồng hành cùng #{상호명}. Hệ thống sẽ gia hạn ngay khi xác nhận thanh toán.''';
      case AppLanguage.spanish:
        return '''[#{상호명}] #{청구제목}

Hola de parte de #{상호명}.
Te enviamos el detalle de #{비용호칭} para #{회원명}:

────────────────
[Detalle de cobro]
• Importe: #{금액}
• Fecha límite: #{납부기한}
• Cuenta / Pago: #{계좌정보}
• Métodos aceptados: #{결제수단안내}
• Pagar con tarjeta: #{카드결제링크}
────────────────

Gracias por confiar en nosotros. Actualizaremos tu pase en cuanto confirmemos el pago.''';
      case AppLanguage.korean:
        return '';
    }
  }

  static String defaultAttendanceTemplate(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.korean:
        return '''[#{상호명}] 출석 안심 알림

안녕하세요, #{상호명}입니다.
#{회원명} #{고객호칭}님이 #{장소호칭}에 안전하게 도착하여
출석 확인(체크인)을 완료하였습니다.

• 출석 일시 : #{출석시간}
#{잔여회차}

오늘도 즐겁고 유익한 시간이 되도록 정성껏 함께하겠습니다.
감사합니다.''';
      case AppLanguage.english:
        return '''[#{상호명}] Check-in Confirmation

Hello from #{상호명}.
#{회원명} has arrived safely and checked in at our #{장소호칭}.

• Time: #{출석시간}
#{잔여회차}

Have a wonderful session today!''';
      case AppLanguage.japanese:
        return '''[#{상호명}] 出席・入室のお知らせ

こんにちは、#{상호명}です。
#{회원명} 様が#{장소호칭}に到着し、チェックインが完了しました。

• チェックイン日時 : #{출석시간}
#{잔여회차}

本日もよろしくお願いいたします。''';
      case AppLanguage.chinese:
        return '''[#{상호명}] 到校签到提醒

您好，这里是 #{상호명}。
#{회원명} 已安全抵达并完成签到打卡。

• 签到时间 : #{출석시간}
#{잔여회차}

祝今天学习/训练愉快！''';
      case AppLanguage.vietnamese:
        return '''[#{상호명}] Thông báo đã điểm danh

Xin chào từ #{상호명}.
#{회원명} đã đến an toàn và hoàn tất điểm danh.

• Thời gian: #{출석시간}
#{잔여회차}

Chúc một buổi học tập/tập luyện hiệu quả!''';
      case AppLanguage.spanish:
        return '''[#{상호명}] Confirmación de asistencia

Hola de parte de #{상호명}.
#{회원명} ha llegado y completado su check-in correctamente.

• Hora: #{출석시간}
#{잔여회차}

¡Que disfrutes la sesión de hoy!''';
    }
  }

  static String defaultDepartureTemplate(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.korean:
        return '''[#{상호명}] 하원·퇴실 완료 알림

안녕하세요, #{상호명}입니다.
#{회원명} #{고객호칭}님이 금일 일정을 마치고
안전하게 귀가(퇴실)하였습니다.

오늘 하루도 수고 많으셨습니다. 감사합니다.''';
      case AppLanguage.english:
        return '''[#{상호명}] Check-out Notice

Hello from #{상호명}.
#{회원명} has finished today's session and safely checked out.

Thank you and see you next time!''';
      case AppLanguage.japanese:
        return '''[#{상호명}] 退室完了のお知らせ

こんにちは、#{상호명}です。
#{회원명} 様が本日のプログラムを終え、無事に退室されました。

本日もお疲れ様でした。''';
      case AppLanguage.chinese:
        return '''[#{상호명}] 离校签退提醒

您好，这里是 #{상호명}。
#{회원명} 已完成今日课程并安全离校。感谢您的配合！''';
      case AppLanguage.vietnamese:
        return '''[#{상호명}] Thông báo tan học / ra về

Xin chào từ #{상호명}.
#{회원명} đã hoàn thành buổi học hôm nay và ra về an toàn. Cảm ơn bạn!''';
      case AppLanguage.spanish:
        return '''[#{상호명}] Aviso de salida

Hola de parte de #{상호명}.
#{회원명} ha finalizado la sesión de hoy y ha salido sin novedades. ¡Gracias!''';
    }
  }

  /// Replaces any legacy Korean `#{금액}원` or `{금액}원` pattern in stored templates
  /// so non-KRW formatted amounts (`$150.00`, `¥15,000`) never get an unwanted `원` suffix.
  static String stripDuplicateWonSuffix(String template, AppCurrency currency) {
    if (currency == AppCurrency.krw) {
      // Because Currency format now produces '₩160,000' or we may preserve '160,000원' depending on caller,
      // callers pass pure formattedAmount cleanly without hardcoded '원'.
      return template.replaceAll('#{금액}원', '#{금액}').replaceAll('{금액}원', '{금액}');
    }
    return template.replaceAll('#{금액}원', '#{금액}').replaceAll('{금액}원', '{금액}');
  }

  /// Translates known built-in default group/template/invoice names when user switched language.
  static String localizeBuiltInLabel(String label, AppLanguage lang) {
    if (lang == AppLanguage.korean) return label;
    const known = {
      // Groups
      '중등수학': {'en': 'Middle Math', 'ja': '中学数学', 'zh': '初中数学', 'vi': 'Toán THCS', 'es': 'Matemáticas'},
      '고등수학': {'en': 'High School Math', 'ja': '高校数学', 'zh': '高中数学', 'vi': 'Toán THPT', 'es': 'Mates Avanzado'},
      '국어논술': {'en': 'Essay & Writing', 'ja': '国語・小論文', 'zh': '阅读写作', 'vi': 'Ngữ văn', 'es': 'Redacción'},
      '영문법': {'en': 'Grammar Class', 'ja': '英文法', 'zh': '英语语法', 'vi': 'Ngữ pháp', 'es': 'Gramática'},
      '정규반': {'en': 'Regular Class', 'ja': '通常クラス', 'zh': '常规班', 'vi': 'Lớp thường', 'es': 'Clase regular'},
      '그룹 1': {'en': 'Group A', 'ja': 'グループA', 'zh': 'A组', 'vi': 'Nhóm A', 'es': 'Grupo A'},
      '개인 PT': {'en': '1:1 PT', 'ja': 'パーソナルPT', 'zh': '私教1对1', 'vi': 'PT 1:1', 'es': 'PT 1:1'},
      '다이어트반': {'en': 'Fat Loss', 'ja': 'ダイエット', 'zh': '减脂塑形', 'vi': 'Giảm cân', 'es': 'Tonificación'},
      '바디프로필반': {'en': 'Physique Prep', 'ja': 'ボディメイク', 'zh': '形体精雕', 'vi': 'Hình thể', 'es': 'Definición'},
      '그룹 PT': {'en': 'Group PT', 'ja': 'グループPT', 'zh': '小团体私教', 'vi': 'Nhóm PT', 'es': 'PT Grupal'},
      '기구 필라테스': {'en': 'Reformer Pilates', 'ja': 'マシンピラティス', 'zh': '器械普拉提', 'vi': 'Pilates Máy', 'es': 'Pilates Máquinas'},
      '매트 요가': {'en': 'Mat Yoga', 'ja': 'マットヨガ', 'zh': '垫上瑜伽', 'vi': 'Yoga Thảm', 'es': 'Yoga Suelo'},
      '체형교정': {'en': 'Posture Care', 'ja': '姿勢矯正', 'zh': '体态矫正', 'vi': 'Chỉnh dáng', 'es': 'Corrección postural'},
      '댄스/방송댄스': {'en': 'Dance Class', 'ja': 'ダンスクラス', 'zh': '流行舞蹈', 'vi': 'Lớp nhảy', 'es': 'Baile moderno'},
      '취미 피아노': {'en': 'Hobby Piano', 'ja': '趣味ピアノ', 'zh': '兴趣钢琴', 'vi': 'Piano cơ bản', 'es': 'Piano Hobby'},
      '전공 입시반': {'en': 'Audition Prep', 'ja': '音大受験', 'zh': '艺考强化', 'vi': 'Luyện thi', 'es': 'Conservatorio'},
      '수채화 취미': {'en': 'Watercolor Art', 'ja': '水彩画クラス', 'zh': '水彩画', 'vi': 'Màu nước', 'es': 'Acuarela'},
      '원데이 공방': {'en': 'One-Day Workshop', 'ja': '1日体験教室', 'zh': '一日体验课', 'vi': 'Workshop 1 ngày', 'es': 'Taller 1 día'},
      '유치부': {'en': 'Kids', 'ja': '幼児クラス', 'zh': '幼儿班', 'vi': 'Thiếu nhi', 'es': 'Infantil'},
      '초등부': {'en': 'Junior', 'ja': '小学生クラス', 'zh': '少儿班', 'vi': 'Thiếu niên', 'es': 'Juvenil'},
      '시범단': {'en': 'Demo Team', 'ja': '演武チーム', 'zh': '示范团', 'vi': 'Đội tuyển', 'es': 'Equipo exhibición'},
      '성인부': {'en': 'Adult', 'ja': '大人クラス', 'zh': '成人班', 'vi': 'Người lớn', 'es': 'Adultos'},
      '회화 정규반': {'en': 'Speaking Regular', 'ja': '会話クラス', 'zh': '口语常规班', 'vi': 'Giao tiếp', 'es': 'Conversación'},
      '코딩 실습반': {'en': 'Coding Lab', 'ja': 'プログラミング', 'zh': '编程实践班', 'vi': 'Thực hành Code', 'es': 'Taller Código'},
      '자격증 대비': {'en': 'Exam Prep', 'ja': '資格対策', 'zh': '考证冲刺', 'vi': 'Luyện thi chứng chỉ', 'es': 'Certificación'},
      '1인 고정석': {'en': 'Dedicated Desk', 'ja': '固定席', 'zh': '固定专座', 'vi': 'Chỗ cố định', 'es': 'Puesto fijo'},
      '자유석(시간권)': {'en': 'Flex Pass (Hours)', 'ja': '時間パス', 'zh': '自由小时卡', 'vi': 'Gói theo giờ', 'es': 'Pase por horas'},
      '그룹 스터디룸': {'en': 'Meeting Room', 'ja': '貸切ルーム', 'zh': '研讨室', 'vi': 'Phòng nhóm', 'es': 'Sala grupal'},
      '일반': {'en': 'General', 'ja': '一般', 'zh': '常规', 'vi': 'Chung', 'es': 'General'},
      '일반반': {'en': 'General Class', 'ja': '一般クラス', 'zh': '常规班', 'vi': 'Lớp chung', 'es': 'Clase general'},
      // Expense categories
      '교재비': {'en': 'Materials / Books', 'ja': '教材費', 'zh': '教材费', 'vi': 'Tài liệu', 'es': 'Materiales'},
      '임대료': {'en': 'Rent / Lease', 'ja': '家賃・賃料', 'zh': '房租租金', 'vi': 'Tiền thuê', 'es': 'Alquiler'},
      '강사료': {'en': 'Instructor Payroll', 'ja': '講師報酬', 'zh': '讲师课时费', 'vi': 'Lương GV', 'es': 'Honorarios'},
      '소모품비': {'en': 'Supplies', 'ja': '消耗品費', 'zh': '耗材费', 'vi': 'Vật tư', 'es': 'Suministros'},
      '시설관리': {'en': 'Facility Maint.', 'ja': '設備管理費', 'zh': '设施维护', 'vi': 'Bảo trì', 'es': 'Mantenimiento'},
      '공과금': {'en': 'Utilities', 'ja': '水道光熱費', 'zh': '水电网费', 'vi': 'Điện nước', 'es': 'Servicios'},
      '기타': {'en': 'Other', 'ja': 'その他', 'zh': '其他', 'vi': 'Khác', 'es': 'Otros'},
      // Vendor categories
      '교재/교구': {'en': 'Books & Gear', 'ja': '教材・教具', 'zh': '教材教具', 'vi': 'Sách & Giáo cụ', 'es': 'Libros y equipo'},
      '시설/기구': {'en': 'Equipment', 'ja': '設備・器具', 'zh': '设备器材', 'vi': 'Thiết bị', 'es': 'Equipamiento'},
      '임대/관리비': {'en': 'Rent & HOA', 'ja': '賃料・管理費', 'zh': '房租物业', 'vi': 'Thuê & Quản lý', 'es': 'Alquiler y gestión'},
      '강사/코치료': {'en': 'Instructors', 'ja': '講師・コーチ', 'zh': '讲师教练', 'vi': 'Giảng viên', 'es': 'Profesores'},
      '소모품/비품': {'en': 'Office Supplies', 'ja': '備品・消耗品', 'zh': '办公耗材', 'vi': 'Vật tư tiêu hao', 'es': 'Consumibles'},
      // Expense payment methods
      '계좌이체': {'en': 'Bank Transfer', 'ja': '銀行振込', 'zh': '银行转账', 'vi': 'Chuyển khoản', 'es': 'Transferencia'},
      '신용카드': {'en': 'Card', 'ja': 'カード払い', 'zh': '信用卡/银行卡', 'vi': 'Thẻ', 'es': 'Tarjeta'},
      '현금': {'en': 'Cash', 'ja': '現金', 'zh': '现金', 'vi': 'Tiền mặt', 'es': 'Efectivo'},
      '간편결제': {'en': 'Mobile / QR Pay', 'ja': '電子決済', 'zh': '移动/扫码支付', 'vi': 'Ví điện tử', 'es': 'Pago móvil'},
      // Tax evidence fallback
      '원천징수(3.3%)': {'en': 'Withholding Tax', 'ja': '源泉徴収税', 'zh': '代扣个税', 'vi': 'Khấu trừ thuế', 'es': 'Retención fiscal'},
    };
    return known[label]?[lang.code] ?? known[label]?['en'] ?? label;
  }
}
