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
  static bool get isDomestic => _currentLanguage == AppLanguage.korean;

  /// 국가/언어별 맞춤형 금융 기관 / 은행 프리셋 목록
  static List<String> getBankPresets() {
    switch (_currentLanguage) {
      case AppLanguage.korean:
        return ['토스뱅크', '카카오뱅크', '국민은행', '신한은행', '우리은행', '하나은행', '농협은행', '기업은행', '새마을금고', '우체국', '기타'];
      case AppLanguage.english:
        return ['Chase', 'Bank of America', 'Wells Fargo', 'Citibank', 'Capital One', 'PayPal', 'Wise', 'Wire Transfer', 'Other'];
      case AppLanguage.japanese:
        return ['三菱UFJ銀行', '三井住友銀行', 'みずほ銀行', 'ゆうちょ銀行', 'りそな銀行', 'PayPay銀行', '楽天銀行', 'その他'];
      case AppLanguage.chinese:
        return ['中国工商银行', '中国建设银行', '中国农业银行', '中国银行', '招商银行', '交通银行', '微信支付', '支付宝', '其他'];
      case AppLanguage.vietnamese:
        return ['Vietcombank', 'Techcombank', 'BIDV', 'VietinBank', 'MB Bank', 'ACB', 'MoMo / ZaloPay', 'Khác'];
      case AppLanguage.spanish:
        return ['Banco Santander', 'BBVA', 'CaixaBank', 'Banco Sabadell', 'Bankinter', 'Revolut', 'SEPA Transfer', 'Otro'];
    }
  }

  /// 메신저/공유 버튼 라벨 (국내: 카카오톡 알림톡/공유, 글로벌: 메신저/시스템 공유)
  static String get shareMessengerLabel {
    switch (_currentLanguage) {
      case AppLanguage.korean:
        return '카카오톡 전송';
      case AppLanguage.english:
        return 'Share via Messenger';
      case AppLanguage.japanese:
        return 'メッセージ共有';
      case AppLanguage.chinese:
        return '分享至社交软件';
      case AppLanguage.vietnamese:
        return 'Chia sẻ qua tin nhắn';
      case AppLanguage.spanish:
        return 'Compartir mensaje';
    }
  }

  /// 국세청 / 세무 리포트 타이틀
  static String get taxReportTitle {
    switch (_currentLanguage) {
      case AppLanguage.korean:
        return '국세청 사업소득 간편장부 엑셀(CSV) 내보내기';
      case AppLanguage.english:
        return 'IRS Schedule C / Business Ledger Export (CSV)';
      case AppLanguage.japanese:
        return '青色申告決算・帳簿データ出力 (CSV)';
      case AppLanguage.chinese:
        return '企业简易收支明细记账导出 (CSV)';
      case AppLanguage.vietnamese:
        return 'Xuất sổ sách thu chi kinh doanh (CSV)';
      case AppLanguage.spanish:
        return 'Exportar libro de ingresos y gastos (CSV)';
    }
  }

  /// 프로샵 타이틀
  static String get proStoreTitle => isDomestic ? '체크앤페이 PRO 샵' : 'Check-in Pay PRO Shop';

  /// 구독 복원 라벨
  static String get proStoreRestore => isDomestic ? '구독 복원' : 'Restore Purchases';

  /// 타사 출결 ERP 비교 라벨
  static String get proStoreComparisonOld =>
      isDomestic ? '타사 출결 키오스크·ERP (월 49,000원)' : 'Traditional Attendance ERP (\$39.99/mo)';

  /// 체크앤페이 VIP 절감 라벨
  static String get proStoreComparisonNew =>
      isDomestic ? '체크앤페이 VIP 월 5,900원 (88% 절감)' : 'Check-in Pay VIP \$4.99/mo (88% Off)';

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
    'senior_board_title': {
      'ko': '시니어 간편 3대 업무 보드',
      'en': 'Senior Easy Operation Board',
      'ja': 'シニア簡単3大業務ボード',
      'zh': '长辈极简三大业务看板',
      'vi': 'Bảng nghiệp vụ chữ lớn',
      'es': 'Tablero de Operaciones Senior',
    },
    'guide_label': {
      'ko': '설명서',
      'en': 'Guide',
      'ja': '説明書',
      'zh': '使用说明',
      'vi': 'Hướng dẫn',
      'es': 'Guía',
    },
    'senior_attendance': {
      'ko': '간편 출석',
      'en': 'Easy Attendance',
      'ja': '簡単出席',
      'zh': '便捷考勤',
      'vi': 'Điểm danh nhanh',
      'es': 'Asistencia Fácil',
    },
    'senior_attendance_sub': {
      'ko': '오늘 출석 체크 및 안심 알림',
      'en': 'Daily check-in & parent notices',
      'ja': '本日の出席確認と安心通知',
      'zh': '今日考勤签到与平安通知',
      'vi': 'Điểm danh hôm nay & báo phụ huynh',
      'es': 'Pase de asistencia y notificación',
    },
    'senior_billing': {
      'ko': '회비 문자',
      'en': 'Tuition SMS',
      'ja': '月謝案内SMS',
      'zh': '学费短信',
      'vi': 'Tin nhắn học phí',
      'es': 'SMS de Mensualidad',
    },
    'senior_billing_sub': {
      'ko': '수강료 청구 및 입금 안내',
      'en': 'Fee invoice & bank payment info',
      'ja': '会費請求とお振込のご案内',
      'zh': '学费账单与收款账户通知',
      'vi': 'Thu học phí & thông tin chuyển khoản',
      'es': 'Factura y datos de transferencia',
    },
    'senior_call': {
      'ko': '바로 통화',
      'en': 'Direct Call',
      'ja': '直接通話',
      'zh': '一键拨号',
      'vi': 'Gọi trực tiếp',
      'es': 'Llamada Directa',
    },
    'senior_call_sub': {
      'ko': '원생 및 학부모 안심 통화',
      'en': 'Direct call to student / parent',
      'ja': '生徒・保護者へ安心直接通話',
      'zh': '一键拨打学员及家长电话',
      'vi': 'Gọi trực tiếp học viên / phụ huynh',
      'es': 'Llamada directa al estudiante/tutor',
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
    'waiting_checkin': {
      'ko': '출결 대기',
      'en': 'Waiting',
      'ja': '出席待機',
      'zh': '等待签到',
      'vi': 'Chờ điểm danh',
      'es': 'Por Marcar',
    },
    'expiring_soon': {
      'ko': '만료 임박',
      'en': 'Expiring Soon',
      'ja': '満了間近',
      'zh': '即将到期',
      'vi': 'Sắp hết hạn',
      'es': 'Por Vencer',
    },
    'attendance_rate': {
      'ko': '출석률',
      'en': 'Attendance',
      'ja': '出席率',
      'zh': '出勤率',
      'vi': 'Tỷ lệ đến lớp',
      'es': 'Asistencia',
    },
    'mascot_mood_great': {
      'ko': '출석 대만족!',
      'en': 'Great Attendance!',
      'ja': '出席率最高！',
      'zh': '出勤极佳！',
      'vi': 'Điểm danh xuất sắc!',
      'es': '¡Excelente Asistencia!',
    },
    'mascot_mood_steady': {
      'ko': '순항 중',
      'en': 'On Track',
      'ja': '順調',
      'zh': '平稳推进',
      'vi': 'Tiến độ ổn định',
      'es': 'En Camino',
    },
    'mascot_mood_needs_boost': {
      'ko': '출석 분발 필요',
      'en': 'Needs Boost',
      'ja': '出席強化が必要',
      'zh': '需要提升出勤',
      'vi': 'Cần cải thiện điểm danh',
      'es': 'Necesita Impulso',
    },
    'golden_time_care': {
      'ko': '장기 미출석 안심 케어',
      'en': 'Absence Care',
      'ja': '長期未出席安心ケア',
      'zh': '长期缺勤关怀',
      'vi': 'Chăm sóc vắng học dài hạn',
      'es': 'Atención por Inasistencia',
    },
    'view_details': {
      'ko': '자세히 보기',
      'en': 'View Details',
      'ja': '詳細を見る',
      'zh': '查看详情',
      'vi': 'Xem chi tiết',
      'es': 'Ver Detalles',
    },
    'no_matching_members': {
      'ko': '해당 조건의 회원이 없습니다',
      'en': 'No matching members found',
      'ja': '該当する会員はいません',
      'zh': '未找到符合条件的学员',
      'vi': 'Không có hội viên phù hợp',
      'es': 'No se encontraron miembros',
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

    // Billing Ledger & Invoices
    'billing_title': {
      'ko': '청구 · 수납 관리',
      'en': 'Billing & Payment Ledger',
      'ja': '請求・収納管理',
      'zh': '账单与收款管理',
      'vi': 'Quản lý Thu phí & Công nợ',
      'es': 'Control de Pagos y Cobros',
    },
    'hero_unpaid_title': {
      'ko': '수납 대기 (미납 총액)',
      'en': 'Total Pending Amount',
      'ja': '収納待ち総額',
      'zh': '待收款总额',
      'vi': 'Tổng tiền chờ thu',
      'es': 'Total Pendiente',
    },
    'hero_paid_title': {
      'ko': '이번 달 총 수납액',
      'en': 'Total Collected This Month',
      'ja': '今月の収納総額',
      'zh': '本月收款总额',
      'vi': 'Tổng thu tháng này',
      'es': 'Total Cobrado este Mes',
    },
    'hero_expense_title': {
      'ko': '이번 달 총 지출액',
      'en': 'Total Expense This Month',
      'ja': '今月の支出総額',
      'zh': '本月支出总额',
      'vi': 'Tổng chi tháng này',
      'es': 'Total Gastos este Mes',
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
    'unpaid_tab_short': {
      'ko': '미납 / 청구',
      'en': 'Unpaid',
      'ja': '未納・請求',
      'zh': '待付款',
      'vi': 'Chưa thu',
      'es': 'Pendientes',
    },
    'paid_tab_short': {
      'ko': '수납 완료',
      'en': 'Paid',
      'ja': '収納完了',
      'zh': '已收款',
      'vi': 'Đã thu',
      'es': 'Pagados',
    },
    'expense_tab_short': {
      'ko': '지출 / 매입',
      'en': 'Expenses',
      'ja': '支出・仕入',
      'zh': '支出采购',
      'vi': 'Chi phí',
      'es': 'Gastos',
    },
    'paid_status': {
      'ko': '수납 완료',
      'en': 'Paid',
      'ja': '収納完了',
      'zh': '已收款',
      'vi': 'Đã thu',
      'es': 'Pagado',
    },
    'unpaid_status': {
      'ko': '미납',
      'en': 'Unpaid',
      'ja': '未納',
      'zh': '未付款',
      'vi': 'Chưa thu',
      'es': 'Pendiente',
    },
    'paid_date_label': {
      'ko': '수납일',
      'en': 'Paid Date',
      'ja': '収納日',
      'zh': '收款日期',
      'vi': 'Ngày thu',
      'es': 'Fecha de pago',
    },
    'due_date_label': {
      'ko': '납부기한',
      'en': 'Due Date',
      'ja': '支払期限',
      'zh': '缴费截止',
      'vi': 'Hạn nộp',
      'es': 'Vencimiento',
    },
    'card_link_integrated': {
      'ko': '카드링크 연동',
      'en': 'Card Link',
      'ja': 'カード決済リンク',
      'zh': '信用卡链接',
      'vi': 'Liên kết thẻ',
      'es': 'Enlace de tarjeta',
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
    'kakao_invoice_btn': {
      'ko': '카톡 청구서',
      'en': 'Share Invoice',
      'ja': '共有請求書',
      'zh': '分享账单',
      'vi': 'Chia sẻ hóa đơn',
      'es': 'Compartir Factura',
    },
    'sms_invoice_btn': {
      'ko': '문자 청구서',
      'en': 'SMS Invoice',
      'ja': 'SMS請求',
      'zh': '短信账单',
      'vi': 'Tin nhắn hóa đơn',
      'es': 'Factura por SMS',
    },
    'remind_1sec': {
      'ko': '1초 입금 안내 리마인드 문자',
      'en': 'Quick Remind SMS',
      'ja': '1秒リマインドSMS',
      'zh': '1秒快速提醒短信',
      'vi': 'SMS nhắc nhở 1 chạm',
      'es': 'Recordatorio SMS',
    },
    'mark_paid': {
      'ko': '수납확인 완료 처리',
      'en': 'Mark as Paid',
      'ja': '収納完了処理',
      'zh': '确认已收款',
      'vi': 'Xác nhận đã thu',
      'es': 'Registrar Pago',
    },
    'receipt_notice_btn': {
      'ko': '영수증 알림 (0원)',
      'en': 'Receipt Notice',
      'ja': '領収書通知',
      'zh': '收据通知',
      'vi': 'Thông báo biên lai',
      'es': 'Aviso de Recibo',
    },
    'receipt_sms_btn': {
      'ko': '영수증 문자 전송',
      'en': 'Send Receipt SMS',
      'ja': '領収書SMS送信',
      'zh': '发送收据短信',
      'vi': 'Gửi SMS biên lai',
      'es': 'Enviar Recibo SMS',
    },
    'batch_dispatch_btn': {
      'ko': '미납 순차 발송',
      'en': 'Batch Remind',
      'ja': '順次督促送信',
      'zh': '批量催缴',
      'vi': 'Gửi nhắc nhở loạt',
      'es': 'Recordatorio Masivo',
    },
    'expiring_banner_title': {
      'ko': '회차 만료 임박',
      'en': 'Pass Expiring Soon',
      'ja': '利用期限満了間近',
      'zh': '次卡即将到期',
      'vi': 'Sắp hết buổi',
      'es': 'Pase por Vencer',
    },
    'expiring_banner_btn': {
      'ko': '만료 안내문자',
      'en': 'Expiry Notice',
      'ja': '満了案内SMS',
      'zh': '到期提醒',
      'vi': 'Báo hết hạn',
      'es': 'Aviso Vencimiento',
    },
    'unpaid_members_waiting': {
      'ko': '미납 회원 {count}명 대기 중',
      'en': '{count} Unpaid Members Waiting',
      'ja': '未納会員 {count}名 待機中',
      'zh': '{count}位未缴费学员待催缴',
      'vi': '{count} hội viên chưa thanh toán',
      'es': '{count} Miembros con Deuda Pendiente',
    },
    'vendors_label': {
      'ko': '거래처·강사',
      'en': 'Vendors & Staff',
      'ja': '取引先・講師',
      'zh': '往来单位·讲师',
      'vi': 'Đối tác & Giảng viên',
      'es': 'Proveedores y Personal',
    },
    'simple_bookkeeping_excel': {
      'ko': '간편장부 엑셀',
      'en': 'Ledger Excel',
      'ja': '簡易帳簿Excel',
      'zh': '简易记账Excel',
      'vi': 'Sổ kế toán Excel',
      'es': 'Excel de Contabilidad',
    },
    'tax_guide_1min': {
      'ko': '1분 세무 가이드',
      'en': '1-Min Tax Guide',
      'ja': '1分税務ガイド',
      'zh': '1分钟税务指南',
      'vi': 'Hướng dẫn thuế 1 phút',
      'es': 'Guía Fiscal de 1 Min',
    },
    'new_expense_btn': {
      'ko': '새 지출 등록',
      'en': 'New Expense',
      'ja': '新規支出登録',
      'zh': '新增支出登记',
      'vi': 'Ghi nhận chi phí',
      'es': 'Nuevo Gasto',
    },
    'unpaid_expense_status': {
      'ko': '미지급 대기',
      'en': 'Unpaid Pending',
      'ja': '未払待機',
      'zh': '待付款',
      'vi': 'Chờ thanh toán',
      'es': 'Pendiente de Pago',
    },
    'share_order_payment': {
      'ko': '카톡 발주/입금서',
      'en': 'Share Order/Receipt',
      'ja': '発注・入金書共有',
      'zh': '分享采购及打款单',
      'vi': 'Chia sẻ phiếu chi',
      'es': 'Compartir Pedido/Recibo',
    },
    'instructor_settlement_btn': {
      'ko': '강사 정산서',
      'en': 'Instructor Pay Statement',
      'ja': '講師精算書',
      'zh': '讲师结算单',
      'vi': 'Bảng lương giảng viên',
      'es': 'Liquidación de Profesor',
    },
    'edit_expense_btn': {
      'ko': '지출 항목 수정',
      'en': 'Edit Expense',
      'ja': '支出項目編集',
      'zh': '修改支出明细',
      'vi': 'Chỉnh sửa chi phí',
      'es': 'Editar Gasto',
    },
    'delete_expense_btn': {
      'ko': '지출 항목 삭제',
      'en': 'Delete Expense',
      'ja': '支出項目削除',
      'zh': '删除支出明细',
      'vi': 'Xóa chi phí',
      'es': 'Eliminar Gasto',
    },
    'btn_edit': {
      'ko': '수정',
      'en': 'Edit',
      'ja': '編集',
      'zh': '编辑',
      'vi': 'Sửa',
      'es': 'Editar',
    },
    'btn_delete': {
      'ko': '삭제',
      'en': 'Delete',
      'ja': '削除',
      'zh': '删除',
      'vi': 'Xóa',
      'es': 'Eliminar',
    },
    'btn_cancel': {
      'ko': '취소',
      'en': 'Cancel',
      'ja': 'キャンセル',
      'zh': '取消',
      'vi': 'Hủy',
      'es': 'Cancelar',
    },
    'empty_expense_title': {
      'ko': '기록된 지출/매입 내역이 없습니다',
      'en': 'No recorded expenses yet',
      'ja': '記録された支出明細がありません',
      'zh': '暂无已记录的支出/采购明细',
      'vi': 'Chưa có khoản chi nào được ghi nhận',
      'es': 'No hay gastos registrados aún',
    },
    'empty_expense_sub': {
      'ko': '운영에 지출된 비용과 강사료를 기록하고 실시간 손익과 순이익을 한눈에 관리하세요.',
      'en': 'Record studio operating costs & staff pay to track net profit in real time.',
      'ja': '運営経費や講師報酬を記録し、リアルタイムで損益と純利益を管理しましょう。',
      'zh': '记录经营成本与讲师课酬，实时掌握收支利润。',
      'vi': 'Ghi lại chi phí vận hành và thù lao giảng viên để theo dõi lợi nhuận thực.',
      'es': 'Registre los costos operativos y honorarios para controlar la ganancia neta en tiempo real.',
    },
    'filter_all': {
      'ko': '전체',
      'en': 'All',
      'ja': 'すべて',
      'zh': '全部',
      'vi': 'Tất cả',
      'es': 'Todos',
    },
    'filter_unpaid': {
      'ko': '미지급',
      'en': 'Unpaid',
      'ja': '未払い',
      'zh': '未支付',
      'vi': 'Chưa trả',
      'es': 'No Pagado',
    },
    'filter_paid': {
      'ko': '완납',
      'en': 'Paid',
      'ja': '支払済',
      'zh': '已支付',
      'vi': 'Đã trả',
      'es': 'Pagado',
    },
    'status_changed_unpaid': {
      'ko': '미지급 상태로 변경되었습니다.',
      'en': 'Changed to unpaid status.',
      'ja': '未払い状態に変更されました。',
      'zh': '已变更为未支付状态。',
      'vi': 'Đã đổi sang trạng thái chưa thanh toán.',
      'es': 'Cambiado a estado no pagado.',
    },
    'status_changed_paid': {
      'ko': '지급 완료(완납) 처리되었습니다.',
      'en': 'Marked as completed / paid.',
      'ja': '支払完了(完納)処理されました。',
      'zh': '已确认支付完毕。',
      'vi': 'Đã xác nhận thanh toán hoàn tất.',
      'es': 'Marcado como pagado.',
    },
    'empty_unpaid_title': {
      'ko': '미납된 청구서가 없습니다',
      'en': 'No unpaid invoices',
      'ja': '未納の請求書はありません',
      'zh': '暂无未缴费账单',
      'vi': 'Không có hóa đơn chưa thanh toán',
      'es': 'No hay facturas pendientes',
    },
    'empty_paid_title': {
      'ko': '수납 완료 내역이 없습니다',
      'en': 'No paid history',
      'ja': '収納完了履歴はありません',
      'zh': '暂无已收款明细',
      'vi': 'Chưa có lịch sử đã thu',
      'es': 'No hay historial de pagos',
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
    'total_members_count': {
      'ko': '등록 회원 총 {count}명',
      'en': 'Total Members: {count}',
      'ja': '登録会員 計 {count}名',
      'zh': '学员总数: {count}人',
      'vi': 'Tổng số hội viên: {count}',
      'es': 'Total de Miembros: {count}',
    },
    'sequential_dispatch_btn': {
      'ko': '순차 릴레이 발송',
      'en': 'Relay Dispatch',
      'ja': 'リレー一括送信',
      'zh': '顺序群发通知',
      'vi': 'Gửi chuyển tiếp loạt',
      'es': 'Envío Secuencial',
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
    'settings_group_studio': {
      'ko': '스튜디오 및 기본 정보',
      'en': 'Studio & Basic Info',
      'ja': 'スタジオ・基本情報',
      'zh': '机构与基础资料',
      'vi': 'Thông tin cơ sở & cơ bản',
      'es': 'Información del Estudio',
    },
    'settings_group_attendance': {
      'ko': '출결 & 무인 키오스크 운영',
      'en': 'Attendance & Self Kiosk',
      'ja': '出席・無人キオスク運営',
      'zh': '考勤与自助考勤机管理',
      'vi': 'Điểm danh & Kiosk tự động',
      'es': 'Asistencia y Quiosco',
    },
    'settings_group_security': {
      'ko': '데이터 보안 & 백업',
      'en': 'Data Security & Backup',
      'ja': 'データセキュリティ・バックアップ',
      'zh': '数据安全与备份',
      'vi': 'Bảo mật dữ liệu & Sao lưu',
      'es': 'Seguridad y Respaldo',
    },
    'settings_group_customer': {
      'ko': '고객센터 & 프리미엄',
      'en': 'Support & Premium',
      'ja': 'サポート・プレミアム',
      'zh': '客服中心与高级特权',
      'vi': 'Hỗ trợ & Gói cao cấp',
      'es': 'Soporte y Premium',
    },
    'tile_custom_terms': {
      'ko': '고객 & 비용 맞춤 호칭 설정',
      'en': 'Custom Member & Fee Terms',
      'ja': '顧客・費用カスタム呼称設定',
      'zh': '学员与费用自定义称呼设置',
      'vi': 'Tùy chỉnh danh xưng học viên & học phí',
      'es': 'Términos de Miembro y Tarifa',
    },
    'tile_custom_category': {
      'ko': '업종별 카테고리 & 청구 템플릿',
      'en': 'Category & Invoice Templates',
      'ja': '業種別カテゴリー・請求テンプレート',
      'zh': '行业分类与收费模板',
      'vi': 'Danh mục theo ngành & Mẫu thu phí',
      'es': 'Categorías y Plantillas de Cobro',
    },
    'tile_kiosk_settings': {
      'ko': '무인 출결 키오스크 기기 설정',
      'en': 'Self Kiosk Device Settings',
      'ja': '無人出席キオスク端末設定',
      'zh': '自助平板考勤机设备设置',
      'vi': 'Cài đặt thiết bị Kiosk điểm danh',
      'es': 'Ajustes de Dispositivo Quiosco',
    },
    'tile_notification_hub': {
      'ko': '스마트 안심 알림 센터 & 감사 로그',
      'en': 'Smart Notification Hub & Audit Logs',
      'ja': 'スマート安心通知センター＆監査ログ',
      'zh': '智能通知中心与操作审计日志',
      'vi': 'Trung tâm thông báo & Nhật ký kiểm toán',
      'es': 'Centro de Notificaciones y Registros',
    },
    'tile_sms_format': {
      'ko': '문자 알림 및 청구 서식 관리',
      'en': 'SMS Notice & Invoice Templates',
      'ja': 'SMS通知・請求書式管理',
      'zh': '短信通知与账单格式管理',
      'vi': 'Quản lý tin nhắn & mẫu hóa đơn',
      'es': 'Plantillas de SMS y Facturas',
    },
    'tile_card_link': {
      'ko': '비대면 신용카드 결제 링크',
      'en': 'Remote Card Payment Link',
      'ja': '非対面クレジットカード決済リンク',
      'zh': '线上远程信用卡支付链接',
      'vi': 'Liên kết thanh toán thẻ từ xa',
      'es': 'Enlace de Pago Remoto con Tarjeta',
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
