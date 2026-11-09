import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AppLanguage {
  korean('ko', '한국어'),
  english('en', 'English'),
  japanese('ja', '日本語'),
  spanish('es', 'Español');

  final String code;
  final String label;
  const AppLanguage(this.code, this.label);

  static AppLanguage fromCode(String code) {
    return AppLanguage.values.firstWhere(
      (lang) => lang.code == code,
      orElse: () => AppLanguage.korean,
    );
  }

  String get flag {
    switch (this) {
      case AppLanguage.korean:
        return '🇰🇷';
      case AppLanguage.english:
        return '🇺🇸';
      case AppLanguage.japanese:
        return '🇯🇵';
      case AppLanguage.spanish:
        return '🇪🇸';
    }
  }

  String get englishLabel {
    switch (this) {
      case AppLanguage.korean:
        return 'Korean';
      case AppLanguage.english:
        return 'English';
      case AppLanguage.japanese:
        return 'Japanese';
      case AppLanguage.spanish:
        return 'Spanish';
    }
  }

  static const List<Locale> supportedLocales = [
    Locale('ko'),
    Locale('en'),
    Locale('ja'),
    Locale('es'),
  ];
}

enum AppCurrency {
  krw('KRW', '₩', '원', 0, '₩#,###'),
  usd('USD', '\$', 'USD', 2, '\$#,##0.00'),
  jpy('JPY', '¥', '円', 0, '¥#,###'),
  eur('EUR', '€', 'EUR', 2, '€#,##0.00'),
  gbp('GBP', '£', 'GBP', 2, '£#,##0.00');

  final String code;
  final String symbol;
  final String unitName;
  final int decimalPlaces;
  final String formatPattern;

  const AppCurrency(
    this.code,
    this.symbol,
    this.unitName,
    this.decimalPlaces,
    this.formatPattern,
  );

  static AppCurrency fromCode(String code) {
    return AppCurrency.values.firstWhere(
      (c) => c.code == code,
      orElse: () => AppCurrency.krw,
    );
  }

  String get flag {
    switch (this) {
      case AppCurrency.krw:
        return '🇰🇷';
      case AppCurrency.usd:
        return '🇺🇸';
      case AppCurrency.jpy:
        return '🇯🇵';
      case AppCurrency.eur:
        return '🇪🇺';
      case AppCurrency.gbp:
        return '🇬🇧';
    }
  }

  String get displayName {
    switch (this) {
      case AppCurrency.krw:
        return '대한민국 원 (KRW)';
      case AppCurrency.usd:
        return '미국 달러 (USD)';
      case AppCurrency.jpy:
        return '일본 엔 (JPY)';
      case AppCurrency.eur:
        return '유럽 유로 (EUR)';
      case AppCurrency.gbp:
        return '영국 파운드 (GBP)';
    }
  }

  List<String> get paymentChannels {
    switch (this) {
      case AppCurrency.krw:
        return ['무통장 계좌입금', '국내 신용카드', '카카오페이 / 토스 / 제로페이', '지역화폐 / 바우처', '현금'];
      case AppCurrency.usd:
        return ['Credit Card / Stripe', 'Apple Pay', 'Google Pay', 'Zelle / Wire', 'Cash'];
      case AppCurrency.jpy:
        return ['銀行振込', 'クレジットカード', 'PayPay / LINE Pay', '交通系IC / 電子マネー', '現金'];
      case AppCurrency.eur:
        return ['SEPA Bank Transfer', 'Credit Card', 'Apple Pay / Google Pay', 'Cash'];
      case AppCurrency.gbp:
        return ['Faster Payments / BACS', 'Credit Card', 'Apple Pay / Google Pay', 'Cash'];
    }
  }

  static AppCurrency defaultForLanguage(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.korean:
        return AppCurrency.krw;
      case AppLanguage.japanese:
        return AppCurrency.jpy;
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
      return '$symbol$str';
    } else {
      final parts = amount.toStringAsFixed(decimalPlaces).split('.');
      final intPart = parts[0].replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
            (m) => '${m[1]},',
          );
      return '$symbol$intPart.${parts[1]}';
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

  static String formatDate(DateTime date) {
    return DateFormat('yyyy.MM.dd').format(date);
  }

  // --- Translation Dictionary (KO, EN, JA, ES) ---
  static const Map<String, Map<String, String>> _strings = {
    // App Bar & Nav
    'app_name': {
      'ko': '체크앤페이',
      'en': 'Check & Pay',
      'ja': 'チェック＆ペイ',
      'es': 'Check & Pay',
    },
    'tab_pass': {
      'ko': '출결 체크',
      'en': 'Check-In',
      'ja': '出席チェック',
      'es': 'Asistencia',
    },
    'tab_billing': {
      'ko': '청구·수납',
      'en': 'Billing',
      'ja': '請求・収納',
      'es': 'Facturación',
    },
    'tab_tax_expense': {
      'ko': '지출·세무',
      'en': 'Tax & Cost',
      'ja': '支出・税務',
      'es': 'Gastos·Imp.',
    },
    'tab_members': {
      'ko': '회원 명부',
      'en': 'Members',
      'ja': '会員名簿',
      'es': 'Miembros',
    },
    'tab_pro': {
      'ko': 'PRO 샵',
      'en': 'PRO Store',
      'ja': 'PROショップ',
      'es': 'Tienda PRO',
    },
    'tab_settings': {
      'ko': '운영·설정',
      'en': 'Settings',
      'ja': '運営・設定',
      'es': 'Ajustes',
    },

    // Senior / Elderly Easy Mode
    'senior_mode': {
      'ko': '시니어 큰글씨 모드',
      'en': 'Senior Easy Mode',
      'ja': 'シニア簡単モード',
      'es': 'Modo Senior',
    },
    'senior_mode_desc': {
      'ko': '노안 및 스마트폰 조작이 어려운 원장님을 위한 1.4배 큰글씨 & 고대비 간편 화면',
      'en': '1.4x larger text & high contrast easy view for elderly business owners',
      'ja': '文字が大きく見やすいシニア向け高コントラスト簡単画面',
      'es': 'Texto 1.4x más grande y alto contraste para adultos mayores',
    },
    'senior_attendance': {
      'ko': '큰글씨 간편 출석',
      'en': 'Senior Easy Attendance',
      'ja': '大きな文字で出席チェック',
      'es': 'Asistencia Fácil',
    },
    'senior_billing': {
      'ko': '회비(수강료) 문자',
      'en': 'Tuition Fee SMS',
      'ja': '月謝案内メッセージ',
      'es': 'SMS de Mensualidad',
    },
    'senior_call': {
      'ko': '원생·학부모 전화',
      'en': 'Call Student / Parent',
      'ja': '保護者・生徒へ電話',
      'es': 'Llamar Estudiante/Tutor',
    },
    'senior_guide': {
      'ko': '쉬운 사용설명서',
      'en': 'Easy User Guide',
      'ja': 'わかりやすい説明書',
      'es': 'Guía Fácil',
    },

    // Pass Dashboard
    'onetouch_checkin': {
      'ko': '원터치 출결 체크',
      'en': 'One-Touch Check-in',
      'ja': 'ワンタッチ出席チェック',
      'es': 'Pase de Asistencia',
    },
    'all_groups': {
      'ko': '전체 그룹',
      'en': 'All Groups',
      'ja': '全グループ',
      'es': 'Todos los Grupos',
    },
    'checked_in': {
      'ko': '출석 완료',
      'en': 'Checked In',
      'ja': '出席済み',
      'es': 'Presente',
    },
    'check_in_btn': {
      'ko': '체크인',
      'en': 'Check-In',
      'ja': 'チェックイン',
      'es': 'Marcar',
    },
    'checkin_alert_sent': {
      'ko': '출석 알림',
      'en': 'Check-in Notice',
      'ja': '出席通知',
      'es': 'Aviso Llegada',
    },
    'checkout_alert_sent': {
      'ko': '하원 알림',
      'en': 'Checkout Notice',
      'ja': '退席通知',
      'es': 'Aviso Salida',
    },
    'kiosk_mode_btn': {
      'ko': '자율출결 키오스크 모드',
      'en': 'Self Kiosk Mode',
      'ja': 'セルフキオスクモード',
      'es': 'Modo Quiosco',
    },
    'batch_checkin_all': {
      'ko': '남은 회원 일괄 출석 완료',
      'en': 'Batch Check-In Remaining',
      'ja': '残りの会員を一括出席',
      'es': 'Marcar Asistencia Masiva',
    },

    // Billing Ledger
    'billing_title': {
      'ko': '청구 · 수납 관리',
      'en': 'Billing & Payment Ledger',
      'ja': '請求・収納管理',
      'es': 'Control de Pagos y Cobros',
    },
    'unpaid_tab': {
      'ko': '미납 / 청구 대상',
      'en': 'Unpaid / Invoices',
      'ja': '未納・請求対象',
      'es': 'Pendientes / Facturas',
    },
    'paid_tab': {
      'ko': '수납 완료 내역',
      'en': 'Paid History',
      'ja': '収納完了履歴',
      'es': 'Historial Pagados',
    },
    'total_unpaid': {
      'ko': '수납 대기 총액',
      'en': 'Total Pending Amount',
      'ja': '収納待ち総額',
      'es': 'Total Pendiente',
    },
    'total_paid': {
      'ko': '총 수납 완료액',
      'en': 'Total Collected',
      'ja': '収納完了総額',
      'es': 'Total Recaudado',
    },
    'create_invoice': {
      'ko': '새 청구서 작성',
      'en': 'New Invoice',
      'ja': '新規請求書作成',
      'es': 'Nueva Factura',
    },
    'send_invoice_msg': {
      'ko': '청구문자',
      'en': 'Send Invoice',
      'ja': '請求送信',
      'es': 'Enviar Cobro',
    },
    'remind_1sec': {
      'ko': '1초 리마인드',
      'en': 'Quick Remind',
      'ja': '1秒リマインド',
      'es': 'Recordatorio',
    },
    'mark_paid': {
      'ko': '수납확인 완료 처리',
      'en': 'Mark as Paid',
      'ja': '収納完了処理',
      'es': 'Registrar Pago',
    },

    // Member Directory
    'member_dir_title': {
      'ko': '회원 명부 관리',
      'en': 'Member Directory',
      'ja': '会員名簿管理',
      'es': 'Directorio de Miembros',
    },
    'search_member_hint': {
      'ko': '이름, 연락처, 그룹명으로 검색',
      'en': 'Search by name, phone, or group',
      'ja': '名前、連絡先、グループで検索',
      'es': 'Buscar por nombre, teléfono o grupo',
    },
    'add_member_btn': {
      'ko': '신규 회원 등록',
      'en': 'Add Member',
      'ja': '新規会員登録',
      'es': 'Nuevo Miembro',
    },
    'sessions_left': {
      'ko': '회 남음',
      'en': 'left',
      'ja': '回残り',
      'es': 'restantes',
    },
    'monthly_pass': {
      'ko': '정기권',
      'en': 'Monthly Pass',
      'ja': '定期券',
      'es': 'Pase Mensual',
    },

    // Settings
    'settings_title': {
      'ko': '설정 · 보안 금고',
      'en': 'Settings & Security Vault',
      'ja': '設定・セキュリティ金庫',
      'es': 'Ajustes y Seguridad',
    },
    'global_center_title': {
      'ko': '글로벌 언어 및 통화 단위 설정',
      'en': 'Global Language & Currency',
      'ja': '言語・通貨単位設定',
      'es': 'Idioma y Moneda',
    },
    'global_center_subtitle': {
      'ko': '전 세계 190개국 해외 교민 학원, 한인 스튜디오, 글로벌 현지 사업장을 위한 다국어 & 다통화 결제 지원 센터입니다.',
      'en': 'Multi-language and currency support for studios worldwide.',
      'ja': 'グローバルなスタジオのための多言語・多通貨決済センターです。',
      'es': 'Soporte multilingüe y multidivisa para estudios en todo el mundo.',
    },
    'auto_suggest_currency': {
      'ko': '언어 선택 시 대표 통화 자동 연동',
      'en': 'Auto-link default currency when language changes',
      'ja': '言語選択時に代表通貨を自動連動',
      'es': 'Vincular moneda predeterminada al cambiar idioma',
    },
    'live_preview_card': {
      'ko': '실시간 앱 표기 미리보기',
      'en': 'Live App Display Preview',
      'ja': 'リアルタイム表示プレビュー',
      'es': 'Vista Previa en Vivo',
    },
    'btn_confirm': {
      'ko': '설정 완료',
      'en': 'Done',
      'ja': '完了',
      'es': 'Listo',
    },
    'language_selector': {
      'ko': '다국어 언어 설정 (Language)',
      'en': 'Language Setting',
      'ja': '言語設定 (Language)',
      'es': 'Idioma (Language)',
    },
    'currency_selector': {
      'ko': '통화 및 결제 단위 (Currency)',
      'en': 'Currency & Payment Unit',
      'ja': '通貨・決済単位 (Currency)',
      'es': 'Moneda y Pagos (Currency)',
    },
    'backup_title': {
      'ko': '100% 안심 로컬 데이터 백업 & 내보내기',
      'en': 'Local Data Backup & Export',
      'ja': 'ローカルデータバックアップ＆出力',
      'es': 'Copia de Seguridad y Exportación',
    },
    'pro_membership_title': {
      'ko': '체크앤페이 PRO 멤버십 & 프리미엄 기능',
      'en': 'Check & Pay PRO Membership',
      'ja': 'チェック＆ペイ PROメンバーシップ',
      'es': 'Membresía PRO Check & Pay',
    },

    // Kiosk
    'kiosk_prompt': {
      'ko': '전화번호 뒷자리 4자리를 입력해주세요',
      'en': 'Please enter the last 4 digits of your phone',
      'ja': '電話番号の下4桁を入力してください',
      'es': 'Ingrese los últimos 4 dígitos de su teléfono',
    },
    'kiosk_exit_prompt': {
      'ko': '키오스크 종료 (관리자)',
      'en': 'Exit Kiosk (Admin)',
      'ja': 'キオスク終了 (管理者)',
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
