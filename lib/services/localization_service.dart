import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  korean('ko', '한국어', 'Korean', '🇰🇷'),
  english('en', 'English', 'English', '🇺🇸'),
  japanese('ja', '日本語', 'Japanese', '🇯🇵'),
  chinese('zh', '简体中文', 'Chinese', '🇨🇳'),
  vietnamese('vi', 'Tiếng Việt', 'Vietnamese', '🇻🇳'),
  spanish('es', 'Español', 'Spanish', '🇪🇸');

  final String code;
  final String label;
  final String englishLabel;
  final String flag;
  const AppLanguage(this.code, this.label, this.englishLabel, this.flag);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.korean,
    );
  }

  static const List<Locale> supportedLocales = [
    Locale('ko'),
    Locale('en'),
    Locale('ja'),
    Locale('zh'),
    Locale('vi'),
    Locale('es'),
  ];
}

enum AppCurrency {
  krw(
    'KRW',
    '₩',
    '원',
    0,
    '₩#,###',
    '🇰🇷',
    '대한민국 원 (KRW)',
    160000,
    true,
  ),
  usd(
    'USD',
    r'$',
    'USD',
    2,
    r'$#,##0.00',
    '🇺🇸',
    '미국 달러 (USD)',
    150.00,
    true,
  ),
  jpy(
    'JPY',
    '¥',
    '円',
    0,
    '¥#,###',
    '🇯🇵',
    '일본 엔 (JPY)',
    15000,
    true,
  ),
  cny(
    'CNY',
    '¥',
    '元',
    2,
    '¥#,##0.00',
    '🇨🇳',
    '중국 위안 (CNY)',
    880.00,
    true,
  ),
  vnd(
    'VND',
    '₫',
    'VND',
    0,
    '#,### ₫',
    '🇻🇳',
    '베트남 동 (VND)',
    2500000,
    false,
  ),
  eur(
    'EUR',
    '€',
    'EUR',
    2,
    '€#,##0.00',
    '🇪🇺',
    '유럽 유로 (EUR)',
    120.00,
    true,
  ),
  gbp(
    'GBP',
    '£',
    'GBP',
    2,
    '£#,##0.00',
    '🇬🇧',
    '영국 파운드 (GBP)',
    110.00,
    true,
  ),
  sgd(
    'SGD',
    r'S$',
    'SGD',
    2,
    r'S$#,##0.00',
    '🇸🇬',
    '싱가포르 달러 (SGD)',
    180.00,
    true,
  ),
  aud(
    'AUD',
    r'A$',
    'AUD',
    2,
    r'A$#,##0.00',
    '🇦🇺',
    '호주 달러 (AUD)',
    175.00,
    true,
  ),
  cad(
    'CAD',
    r'C$',
    'CAD',
    2,
    r'C$#,##0.00',
    '🇨🇦',
    '캐나다 달러 (CAD)',
    165.00,
    true,
  );

  final String code;
  final String symbol;
  final String unitName;
  final int decimalPlaces;
  final String formatPattern;
  final String flag;
  final String displayName;
  final num sampleAmount;
  final bool isPrefixSymbol;

  const AppCurrency(
    this.code,
    this.symbol,
    this.unitName,
    this.decimalPlaces,
    this.formatPattern,
    this.flag,
    this.displayName,
    this.sampleAmount,
    this.isPrefixSymbol,
  );

  static AppCurrency fromCode(String code) {
    return AppCurrency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => AppCurrency.krw,
    );
  }

  List<String> get paymentChannels {
    switch (this) {
      case AppCurrency.krw:
        return ['무통장 계좌입금', '국내 신용카드', '카카오페이 / 토스 / 제로페이', '지역화폐 / 바우처', '현금'];
      case AppCurrency.usd:
        return ['Credit Card / Stripe', 'Apple Pay / Google Pay', 'Zelle / Venmo', 'ACH / Wire Transfer', 'Cash'];
      case AppCurrency.jpy:
        return ['銀行振込', 'クレジットカード', 'PayPay / LINE Pay', '交通系IC / 電子マネー', '現金'];
      case AppCurrency.cny:
        return ['微信支付 (WeChat Pay)', '支付宝 (Alipay)', '中国银联 (UnionPay)', '银行转账', '现金'];
      case AppCurrency.vnd:
        return ['Chuyển khoản VietQR', 'MoMo / ZaloPay / VNPay', 'Thẻ nội địa & Quốc tế', 'Tiền mặt'];
      case AppCurrency.eur:
        return ['SEPA Bank Transfer', 'Credit Card (Visa/Mastercard)', 'Apple Pay / Google Pay', 'Cash'];
      case AppCurrency.gbp:
        return ['Faster Payments / BACS', 'Debit / Credit Card', 'Apple Pay / Google Pay', 'Cash'];
      case AppCurrency.sgd:
        return ['PayNow / FAST Transfer', 'GrabPay / NETS', 'Credit Card', 'Cash'];
      case AppCurrency.aud:
        return ['PayID / Osko Transfer', 'Credit Card / EFTPOS', 'Apple Pay / Google Pay', 'Cash'];
      case AppCurrency.cad:
        return ['Interac e-Transfer', 'Credit Card', 'Apple Pay / Google Pay', 'Cash'];
    }
  }

  String get taxPolicy {
    switch (this) {
      case AppCurrency.krw:
        return '국세청 간편장부 / 부가세·종합소득세 매입매출 전표';
      case AppCurrency.usd:
        return 'IRS Form 1099-K / Schedule C (Small Business Profit/Loss)';
      case AppCurrency.jpy:
        return '国税庁 青色申告決算書 / 適格請求書等保存方式 (インボイス制度)';
      case AppCurrency.cny:
        return '国家税务总局 全电发票(数电票) / 小规模纳税人简易记账';
      case AppCurrency.vnd:
        return 'Tổng cục Thuế Hóa đơn điện tử (e-Invoice) / Hộ kinh doanh cá thể';
      case AppCurrency.eur:
        return 'EU VAT Directive / Reverse Charge Mechanism / SAF-T Report';
      case AppCurrency.gbp:
        return 'HMRC Making Tax Digital (MTD) / Self Assessment & VAT Return';
      case AppCurrency.sgd:
        return 'IRAS Goods and Services Tax (GST) & Corporate Tax Form C-S';
      case AppCurrency.aud:
        return 'ATO Business Activity Statement (BAS) / Goods & Services Tax (GST)';
      case AppCurrency.cad:
        return 'CRA GST/HST Return / Small Business T2125 Statement';
    }
  }

  static AppCurrency defaultForLanguage(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.korean:
        return AppCurrency.krw;
      case AppLanguage.japanese:
        return AppCurrency.jpy;
      case AppLanguage.chinese:
        return AppCurrency.cny;
      case AppLanguage.vietnamese:
        return AppCurrency.vnd;
      case AppLanguage.spanish:
        return AppCurrency.eur;
      case AppLanguage.english:
        return AppCurrency.usd;
    }
  }

  String format(num amount) {
    if (decimalPlaces == 0) {
      final intVal = amount.round();
      final str = intVal.toString().replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
      return isPrefixSymbol ? '$symbol$str' : '$str $symbol';
    } else {
      final parts = amount.toStringAsFixed(decimalPlaces).split('.');
      final intPart = parts[0].replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
      final formatted = '$intPart.${parts[1]}';
      return isPrefixSymbol ? '$symbol$formatted' : '$formatted $symbol';
    }
  }
}

class LocalizationService {
  static const String keySelectedLanguage = 'selected_language';
  static const String keySelectedCurrency = 'selected_currency';

  static AppLanguage _currentLanguage = AppLanguage.korean;
  static AppCurrency _currentCurrency = AppCurrency.krw;

  static AppLanguage get currentLanguage => _currentLanguage;
  static AppCurrency get currentCurrency => _currentCurrency;

  static Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final langCode = prefs.getString(keySelectedLanguage);
      if (langCode != null && langCode.isNotEmpty) {
        _currentLanguage = AppLanguage.fromCode(langCode);
      }
      final curCode = prefs.getString(keySelectedCurrency);
      if (curCode != null && curCode.isNotEmpty) {
        _currentCurrency = AppCurrency.fromCode(curCode);
      }
    } catch (_) {}
  }

  static Future<void> setLanguage(AppLanguage lang, {bool persist = true}) async {
    _currentLanguage = lang;
    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keySelectedLanguage, lang.code);
      } catch (_) {}
    }
  }

  static Future<void> setCurrency(AppCurrency cur, {bool persist = true}) async {
    _currentCurrency = cur;
    if (persist) {
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(keySelectedCurrency, cur.code);
      } catch (_) {}
    }
  }

  static String formatHeaderDate(DateTime date) {
    switch (_currentLanguage) {
      case AppLanguage.korean:
        return DateFormat('M월 d일 (E)', 'ko_KR').format(date);
      case AppLanguage.english:
        return DateFormat('EEE, MMM d', 'en_US').format(date);
      case AppLanguage.japanese:
        return DateFormat('M月d日 (E)', 'ja_JP').format(date);
      case AppLanguage.chinese:
        return DateFormat('M月d日 (E)', 'zh_CN').format(date);
      case AppLanguage.vietnamese:
        return DateFormat('E, dd/MM', 'vi_VN').format(date);
      case AppLanguage.spanish:
        return DateFormat('EEE, d MMM', 'es_ES').format(date);
    }
  }

  static String formatDate(DateTime date) {
    switch (_currentLanguage) {
      case AppLanguage.korean:
      case AppLanguage.japanese:
      case AppLanguage.chinese:
        return DateFormat('yyyy.MM.dd').format(date);
      case AppLanguage.english:
        return DateFormat('MMM d, yyyy', 'en_US').format(date);
      case AppLanguage.vietnamese:
      case AppLanguage.spanish:
        return DateFormat('dd/MM/yyyy').format(date);
    }
  }

  // --- Comprehensive 6-Language Translation Dictionary ---
  static const Map<String, Map<String, String>> _strings = {
    // App Bar & Nav
    'app_name': {
      'ko': '체크앤페이',
      'en': 'Check & Pay',
      'ja': 'チェック＆ペイ',
      'zh': '签到收款',
      'vi': 'Check & Pay',
      'es': 'Check & Pay',
    },
    'tab_pass': {
      'ko': '출결 체크',
      'en': 'Check-In',
      'ja': '出席チェック',
      'zh': '考勤签到',
      'vi': 'Điểm danh',
      'es': 'Asistencia',
    },
    'tab_billing': {
      'ko': '청구·수납',
      'en': 'Billing',
      'ja': '請求・収納',
      'zh': '账单账务',
      'vi': 'Thanh toán',
      'es': 'Facturación',
    },
    'tab_tax_expense': {
      'ko': '지출·세무',
      'en': 'Tax & Cost',
      'ja': '支出・税務',
      'zh': '支出税务',
      'vi': 'Thuế & Chi phí',
      'es': 'Gastos·Imp.',
    },
    'tab_members': {
      'ko': '회원 명부',
      'en': 'Members',
      'ja': '会員名簿',
      'zh': '学员名册',
      'vi': 'Hội viên',
      'es': 'Miembros',
    },
    'tab_pro': {
      'ko': 'PRO 샵',
      'en': 'PRO Store',
      'ja': 'PROショップ',
      'zh': 'PRO商城',
      'vi': 'Cửa hàng PRO',
      'es': 'Tienda PRO',
    },
    'tab_settings': {
      'ko': '운영·설정',
      'en': 'Settings',
      'ja': '運営・設定',
      'zh': '运营设置',
      'vi': 'Cài đặt',
      'es': 'Ajustes',
    },

    // Senior / Elderly Easy Mode
    'senior_mode': {
      'ko': '시니어 큰글씨 모드',
      'en': 'Senior Easy Mode',
      'ja': 'シニア簡単モード',
      'zh': '长辈大字模式',
      'vi': 'Chế độ chữ lớn',
      'es': 'Modo Senior',
    },
    'senior_mode_desc': {
      'ko': '노안 및 스마트폰 조작이 어려운 원장님을 위한 1.4배 큰글씨 & 고대비 간편 화면',
      'en': '1.4x larger text & high contrast easy view for elderly business owners',
      'ja': '文字が大きく見やすいシニア向け高コントラスト簡単画面',
      'zh': '为老龄馆长提供1.4倍超大字体与高对比度的极简界面',
      'vi': 'Phông chữ lớn hơn 1.4 lần và độ tương phản cao dễ đọc',
      'es': 'Texto 1.4x más grande y alto contraste para adultos mayores',
    },
    'senior_attendance': {
      'ko': '큰글씨 간편 출석',
      'en': 'Senior Easy Attendance',
      'ja': '大きな文字で出席チェック',
      'zh': '大字便捷考勤',
      'vi': 'Điểm danh chữ lớn',
      'es': 'Asistencia Fácil',
    },
    'senior_billing': {
      'ko': '회비(수강료) 문자',
      'en': 'Tuition Fee SMS',
      'ja': '月謝案内メッセージ',
      'zh': '学费通知短信',
      'vi': 'Tin nhắn học phí',
      'es': 'SMS de Mensualidad',
    },
    'senior_call': {
      'ko': '원생·학부모 전화',
      'en': 'Call Student / Parent',
      'ja': '保護者・生徒へ電話',
      'zh': '拨打学员/家长电话',
      'vi': 'Gọi học viên/phụ huynh',
      'es': 'Llamar Estudiante/Tutor',
    },
    'senior_guide': {
      'ko': '쉬운 사용설명서',
      'en': 'Easy User Guide',
      'ja': 'わかりやすい説明書',
      'zh': '简易使用手册',
      'vi': 'Hướng dẫn dễ hiểu',
      'es': 'Guía Fácil',
    },

    // Pass Dashboard
    'onetouch_checkin': {
      'ko': '원터치 출결 체크',
      'en': 'One-Touch Check-in',
      'ja': 'ワンタッチ出席チェック',
      'zh': '一键考勤签到',
      'vi': 'Điểm danh 1 chạm',
      'es': 'Pase de Asistencia',
    },
    'all_groups': {
      'ko': '전체 그룹',
      'en': 'All Groups',
      'ja': '全グループ',
      'zh': '所有组别',
      'vi': 'Tất cả nhóm',
      'es': 'Todos los Grupos',
    },
    'checked_in': {
      'ko': '출석 완료',
      'en': 'Checked In',
      'ja': '出席済み',
      'zh': '已签到',
      'vi': 'Đã điểm danh',
      'es': 'Presente',
    },
    'check_in_btn': {
      'ko': '체크인',
      'en': 'Check-In',
      'ja': 'チェックイン',
      'zh': '签到',
      'vi': 'Vào lớp',
      'es': 'Marcar',
    },
    'check_out_btn': {
      'ko': '체크아웃',
      'en': 'Check-Out',
      'ja': 'チェックアウト',
      'zh': '签退',
      'vi': 'Ra về',
      'es': 'Salida',
    },
    'checkin_alert_sent': {
      'ko': '출석 알림',
      'en': 'Check-in Notice',
      'ja': '出席通知',
      'zh': '签到通知',
      'vi': 'Báo đến',
      'es': 'Aviso Llegada',
    },
    'checkout_alert_sent': {
      'ko': '하원 알림',
      'en': 'Checkout Notice',
      'ja': '退席通知',
      'zh': '签退通知',
      'vi': 'Báo về',
      'es': 'Aviso Salida',
    },
    'kiosk_mode_btn': {
      'ko': '자율출결 키오스크 모드',
      'en': 'Self Kiosk Mode',
      'ja': 'セルフキオスクモード',
      'zh': '自助平板考勤机',
      'vi': 'Chế độ Kiosk tự phục vụ',
      'es': 'Modo Quiosco',
    },
    'batch_checkin_all': {
      'ko': '남은 회원 일괄 출석 완료',
      'en': 'Batch Check-In Remaining',
      'ja': '残りの会員を一括出席',
      'zh': '批量签到剩余学员',
      'vi': 'Điểm danh tất cả còn lại',
      'es': 'Marcar Asistencia Masiva',
    },

    // Billing Ledger
    'billing_title': {
      'ko': '청구 · 수납 관리',
      'en': 'Billing & Payment Ledger',
      'ja': '請求・収納管理',
      'zh': '账单与收款管理',
      'vi': 'Quản lý Thu phí & Công nợ',
      'es': 'Control de Pagos y Cobros',
    },
    'unpaid_tab': {
      'ko': '미납 / 청구 대상',
      'en': 'Unpaid / Invoices',
      'ja': '未納・請求対象',
      'zh': '未付款/待收账单',
      'vi': 'Chưa thanh toán / Hóa đơn',
      'es': 'Pendientes / Facturas',
    },
    'paid_tab': {
      'ko': '수납 완료 내역',
      'en': 'Paid History',
      'ja': '収納完了履歴',
      'zh': '已收款明细',
      'vi': 'Lịch sử đã thu',
      'es': 'Historial Pagados',
    },
    'total_unpaid': {
      'ko': '수납 대기 총액',
      'en': 'Total Pending Amount',
      'ja': '収納待ち総額',
      'zh': '待收总金额',
      'vi': 'Tổng tiền chờ thu',
      'es': 'Total Pendiente',
    },
    'total_paid': {
      'ko': '총 수납 완료액',
      'en': 'Total Collected',
      'ja': '収納完了総額',
      'zh': '已收总金额',
      'vi': 'Tổng đã thu',
      'es': 'Total Recaudado',
    },
    'create_invoice': {
      'ko': '새 청구서 작성',
      'en': 'New Invoice',
      'ja': '新規請求書作成',
      'zh': '创建新账单',
      'vi': 'Tạo hóa đơn mới',
      'es': 'Nueva Factura',
    },
    'send_invoice_msg': {
      'ko': '청구문자',
      'en': 'Send Invoice',
      'ja': '請求送信',
      'zh': '发送催缴短信',
      'vi': 'Gửi tin thu phí',
      'es': 'Enviar Cobro',
    },
    'remind_1sec': {
      'ko': '1초 리마인드',
      'en': 'Quick Remind',
      'ja': '1秒リマインド',
      'zh': '1秒快速提醒',
      'vi': 'Nhắc nhở 1 chạm',
      'es': 'Recordatorio',
    },
    'mark_paid': {
      'ko': '수납확인 완료 처리',
      'en': 'Mark as Paid',
      'ja': '収納完了処理',
      'zh': '确认已收款',
      'vi': 'Xác nhận đã thu',
      'es': 'Registrar Pago',
    },

    // Member Directory
    'member_dir_title': {
      'ko': '회원 명부 관리',
      'en': 'Member Directory',
      'ja': '会員名簿管理',
      'zh': '学员档案名册',
      'vi': 'Danh bạ hội viên',
      'es': 'Directorio de Miembros',
    },
    'search_member_hint': {
      'ko': '이름, 연락처, 그룹명으로 검색',
      'en': 'Search by name, phone, or group',
      'ja': '名前、連絡先、グループで検索',
      'zh': '按姓名、手机号或组别搜索',
      'vi': 'Tìm theo tên, điện thoại, nhóm',
      'es': 'Buscar por nombre, teléfono o grupo',
    },
    'add_member_btn': {
      'ko': '신규 회원 등록',
      'en': 'Add Member',
      'ja': '新規会員登録',
      'zh': '新增学员',
      'vi': 'Thêm học viên mới',
      'es': 'Nuevo Miembro',
    },
    'sessions_left': {
      'ko': '회 남음',
      'en': 'left',
      'ja': '回残り',
      'zh': '次剩余',
      'vi': 'buổi còn lại',
      'es': 'restantes',
    },
    'monthly_pass': {
      'ko': '정기권',
      'en': 'Monthly Pass',
      'ja': '定期券',
      'zh': '月度通卡',
      'vi': 'Thẻ định kỳ',
      'es': 'Pase Mensual',
    },

    // Settings
    'settings_title': {
      'ko': '설정 · 보안 금고',
      'en': 'Settings & Security Vault',
      'ja': '設定・セキュリティ金庫',
      'zh': '运营设置与数据保险箱',
      'vi': 'Cài đặt & Két bảo mật',
      'es': 'Ajustes y Seguridad',
    },
    'global_center_title': {
      'ko': '글로벌 언어 및 통화 단위 설정',
      'en': 'Global Language & Currency',
      'ja': '言語・通貨単位設定',
      'zh': '全球语言与法定货币设置',
      'vi': 'Cài đặt Ngôn ngữ & Tiền tệ',
      'es': 'Idioma y Moneda',
    },
    'global_center_subtitle': {
      'ko': '전 세계 190개국 해외 교민 학원, 한인 스튜디오, 글로벌 현지 사업장을 위한 다국어 & 다통화 결제 지원 센터입니다.',
      'en': 'Multi-language and currency support for studios and business owners worldwide.',
      'ja': 'グローバルなスタジオと事業者のための多言語・多通貨決済センターです。',
      'zh': '为全球各类培训机构、私教馆与工作室提供多语言及多币种计费支持。',
      'vi': 'Hỗ trợ đa ngôn ngữ và tiền tệ cho các trung tâm và phòng tập trên toàn thế giới.',
      'es': 'Soporte multilingüe y multidivisa para estudios y negocios en todo el mundo.',
    },
    'auto_suggest_currency': {
      'ko': '언어 선택 시 대표 통화 자동 연동',
      'en': 'Auto-link default currency when language changes',
      'ja': '言語選択時に代表通貨を自動連動',
      'zh': '选择语言时自动关联对应国家主货币',
      'vi': 'Tự động liên kết tiền tệ mặc định theo ngôn ngữ',
      'es': 'Vincular moneda predeterminada al cambiar idioma',
    },
    'live_preview_card': {
      'ko': '실시간 앱 표기 미리보기',
      'en': 'Live App Display Preview',
      'ja': 'リアルタイム表示プレビュー',
      'zh': '实时显示预览',
      'vi': 'Xem trước hiển thị trực tiếp',
      'es': 'Vista Previa en Vivo',
    },
    'btn_confirm': {
      'ko': '설정 완료',
      'en': 'Done',
      'ja': '完了',
      'zh': '完成设置',
      'vi': 'Hoàn tất',
      'es': 'Listo',
    },
    'language_selector': {
      'ko': '다국어 언어 설정 (Language)',
      'en': 'Language Setting (Language)',
      'ja': '言語設定 (Language)',
      'zh': '语言设置 (Language)',
      'vi': 'Cài đặt ngôn ngữ (Language)',
      'es': 'Idioma (Language)',
    },
    'currency_selector': {
      'ko': '통화 및 결제 단위 (Currency)',
      'en': 'Currency & Payment Unit (Currency)',
      'ja': '通貨・決済単位 (Currency)',
      'zh': '货币与计费单位 (Currency)',
      'vi': 'Tiền tệ & Đơn vị thu phí (Currency)',
      'es': 'Moneda y Pagos (Currency)',
    },
    'sample_fee_label': {
      'ko': '예시 청구 금액',
      'en': 'Sample Fee Amount',
      'ja': '請求金額サンプル',
      'zh': '示例费用金额',
      'vi': 'Số tiền mẫu',
      'es': 'Monto de Muestra',
    },
    'sample_date_label': {
      'ko': '표기 일자',
      'en': 'Date Format',
      'ja': '日付表示',
      'zh': '日期格式',
      'vi': 'Định dạng ngày',
      'es': 'Formato de Fecha',
    },
    'tax_accounting_label': {
      'ko': '세무·회계 기준',
      'en': 'Tax & Accounting Policy',
      'ja': '税務・会計基準',
      'zh': '税务记账标准',
      'vi': 'Chính sách thuế & kế toán',
      'es': 'Normativa Fiscal y Contable',
    },
    'backup_title': {
      'ko': '100% 안심 로컬 데이터 백업 & 내보내기',
      'en': 'Local Data Backup & Export',
      'ja': 'ローカルデータバックアップ＆出力',
      'zh': '本地数据安全备份与导出',
      'vi': 'Sao lưu dữ liệu cục bộ an toàn',
      'es': 'Copia de Seguridad y Exportación',
    },
    'pro_membership_title': {
      'ko': '체크앤페이 PRO 멤버십 & 프리미엄 기능',
      'en': 'Check & Pay PRO Membership',
      'ja': 'チェック＆ペイ PROメンバーシップ',
      'zh': '签到收款 PRO 会员特权',
      'vi': 'Gói thành viên PRO Check & Pay',
      'es': 'Membresía PRO Check & Pay',
    },

    // Kiosk
    'kiosk_prompt': {
      'ko': '전화번호 뒷자리 4자리를 입력해주세요',
      'en': 'Please enter the last 4 digits of your phone',
      'ja': '電話番号の下4桁を入力してください',
      'zh': '请输入手机号后4位',
      'vi': 'Vui lòng nhập 4 số cuối số điện thoại',
      'es': 'Ingrese los últimos 4 dígitos de su teléfono',
    },
    'kiosk_exit_prompt': {
      'ko': '키오스크 종료 (관리자)',
      'en': 'Exit Kiosk (Admin)',
      'ja': 'キオスク終了 (管理者)',
      'zh': '退出考勤机模式 (管理员)',
      'vi': 'Thoát Kiosk (Quản trị)',
      'es': 'Salir de Quiosco (Admin)',
    },
  };

  /// Translate key with fallback
  static String tr(String key) {
    final langCode = _currentLanguage.code;
    final dict = _strings[key];
    if (dict != null) {
      return dict[langCode] ?? dict['en'] ?? dict['ko'] ?? key;
    }
    return key;
  }

  /// Format money using active currency
  static String formatAmount(num amount) {
    return _currentCurrency.format(amount);
  }
}
