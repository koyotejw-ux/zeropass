import '../services/localization_service.dart';
import '../services/region_workflow_service.dart';

class StudioProfile {
  final String studioName;
  final String instructorName;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final String category;
  final bool autoBankDetectEnabled;
  final String invoiceTemplate;
  final String attendanceTemplate;
  final String departureTemplate;
  final String cardPaymentUrl;
  final bool cardPaymentEnabled;
  final String? logoPath;
  final String? customMemberTerm;
  final String? customFeeTerm;
  final String? customRoleTerm;
  final String? customPlaceTerm;

  static const List<String> businessCategories = [
    '음악 / 피아노',
    '입시 / 보습학원',
    '피트니스 / PT',
    '필라테스 / 요가',
    '무용 / 댄스',
    '태권도 / 무술',
    '미술 / 도예공방',
    '수영 / 스포츠',
    '어학 / 코딩',
    '스터디룸 / 공간대여',
    '기타 / 맞춤업종',
  ];

  static const List<String> memberTermOptions = [
    '회원',
    '수강생',
    '원생',
    '학생',
    '원아',
    '고객',
    '이용자',
  ];

  static const List<String> feeTermOptions = [
    '수강료',
    '회비',
    '이용료',
    '레슨비',
    '원비',
    '교육비',
  ];

  static const List<String> roleTermOptions = [
    '대표',
    '원장',
    '실장',
    '선생님',
    '코치',
    '강사',
    '관장',
    '관리자',
  ];

  static const List<String> placeTermOptions = [
    '스튜디오',
    '학원',
    '센터',
    '공방',
    '매장',
    '체육관',
    '연습실',
  ];

  const StudioProfile({
    required this.studioName,
    required this.instructorName,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    this.category = '음악 / 피아노',
    this.autoBankDetectEnabled = true,
    required this.invoiceTemplate,
    required this.attendanceTemplate,
    required this.departureTemplate,
    this.cardPaymentUrl = '',
    this.cardPaymentEnabled = false,
    this.logoPath,
    this.customMemberTerm,
    this.customFeeTerm,
    this.customRoleTerm,
    this.customPlaceTerm,
  });

  /// 비대면 카드결제 링크 생성 (금액/회원명 치환 지원)
  String getFormattedCardPaymentUrl({int? amount, String? orderTitle, String? customerName}) {
    if (!cardPaymentEnabled || cardPaymentUrl.trim().isEmpty) return '';
    String url = cardPaymentUrl.trim();
    if (amount != null) {
      url = url.replaceAll('{금액}', amount.toString()).replaceAll('{amount}', amount.toString());
    }
    if (orderTitle != null) {
      url = url.replaceAll('{상품명}', Uri.encodeComponent(orderTitle)).replaceAll('{title}', Uri.encodeComponent(orderTitle));
    }
    if (customerName != null) {
      url = url.replaceAll('{회원명}', Uri.encodeComponent(customerName)).replaceAll('{name}', Uri.encodeComponent(customerName));
    }
    return url;
  }

  /// 운영자 직함 호칭 (커스텀 설정 우선, 미설정 시 업종 및 언어별 기본값)
  String get roleTitle {
    if (customRoleTerm != null && customRoleTerm!.trim().isNotEmpty) {
      return customRoleTerm!.trim();
    }
    String koDefault = '대표';
    if (category.contains('피트니스') || category.contains('PT') || category.contains('스포츠') || category.contains('수영')) {
      koDefault = '코치';
    } else if (category.contains('공방') || category.contains('도예') || category.contains('미술')) {
      koDefault = '대표';
    } else if (category.contains('필라테스') || category.contains('요가') || category.contains('무용') || category.contains('댄스')) {
      koDefault = '실장';
    } else if (category.contains('학원') || category.contains('입시') || category.contains('어학') || category.contains('코딩')) {
      koDefault = '원장';
    }
    return RegionWorkflowService.localizedRoleTitle(
      category,
      koDefault,
      LocalizationService.currentLanguage,
    );
  }

  /// 고객/회원 호칭 (커스텀 설정 우선, 미설정 시 업종 및 언어별 스마트 기본값)
  String get memberTitle {
    if (customMemberTerm != null && customMemberTerm!.trim().isNotEmpty) {
      return customMemberTerm!.trim();
    }
    final lang = LocalizationService.currentLanguage;
    if (lang != AppLanguage.korean) return memberWord;
    if (category.contains('학원') || category.contains('입시') || category.contains('어학') || category.contains('태권도')) {
      return '학생 / 수강생';
    } else if (category.contains('피트니스') || category.contains('PT') || category.contains('필라테스') || category.contains('요가')) {
      return '회원';
    } else if (category.contains('공방') || category.contains('공간대여')) {
      return '이용 고객 / 회원';
    }
    return '회원 / 수강생';
  }

  /// 단일 단어 고객 호칭 (예: '회원', '수강생', '원생', '학생', '원아', '고객', '이용자')
  String get memberWord {
    if (customMemberTerm != null && customMemberTerm!.trim().isNotEmpty) {
      return customMemberTerm!.trim();
    }
    String koDefault = '회원';
    if (category.contains('학원') || category.contains('입시') || category.contains('어학') || category.contains('태권도')) {
      koDefault = '수강생';
    } else if (category.contains('피트니스') || category.contains('PT') || category.contains('필라테스') || category.contains('요가')) {
      koDefault = '회원';
    } else if (category.contains('공방') || category.contains('공간대여')) {
      koDefault = '고객';
    }
    return RegionWorkflowService.localizedMemberWord(
      koDefault,
      LocalizationService.currentLanguage,
    );
  }

  /// 수강료/이용료/회비 호칭 (커스텀 설정 우선, 미설정 시 업종 및 언어별 스마트 기본값)
  String get feeTitle {
    if (customFeeTerm != null && customFeeTerm!.trim().isNotEmpty) {
      return customFeeTerm!.trim();
    }
    final lang = LocalizationService.currentLanguage;
    if (lang != AppLanguage.korean) return feeWord;
    if (category.contains('학원') || category.contains('음악') || category.contains('어학')) {
      return '수강료';
    } else if (category.contains('피트니스') || category.contains('PT') || category.contains('필라테스')) {
      return '회비 / 레슨비';
    } else if (category.contains('공방') || category.contains('공간대여')) {
      return '이용료 / 재료비';
    }
    return '수납 / 회비';
  }

  /// 단일 단어 비용 호칭 (예: '수강료', '회비', '이용료', '레슨비', '원비', '교육비')
  String get feeWord {
    if (customFeeTerm != null && customFeeTerm!.trim().isNotEmpty) {
      return customFeeTerm!.trim();
    }
    String koDefault = '회비';
    if (category.contains('학원') || category.contains('음악') || category.contains('어학')) {
      koDefault = '수강료';
    } else if (category.contains('피트니스') || category.contains('PT') || category.contains('필라테스')) {
      koDefault = '회비';
    } else if (category.contains('공방') || category.contains('공간대여')) {
      koDefault = '이용료';
    }
    return RegionWorkflowService.localizedFeeWord(
      koDefault,
      LocalizationService.currentLanguage,
    );
  }

  /// 사업장 성격 호칭 (커스텀 설정 우선, 미설정 시 업종 및 언어별 기본값)
  String get placeTitle {
    if (customPlaceTerm != null && customPlaceTerm!.trim().isNotEmpty) {
      return customPlaceTerm!.trim();
    }
    String koDefault = '매장';
    if (category.contains('학원') || category.contains('입시') || category.contains('어학')) {
      koDefault = '학원';
    } else if (category.contains('피트니스') || category.contains('PT') || category.contains('스포츠')) {
      koDefault = '센터';
    } else if (category.contains('필라테스') || category.contains('요가') || category.contains('댄스')) {
      koDefault = '스튜디오';
    } else if (category.contains('공방') || category.contains('도예')) {
      koDefault = '공방';
    }
    return RegionWorkflowService.localizedPlaceTitle(
      koDefault,
      LocalizationService.currentLanguage,
    );
  }

  String get localizedCategoryLabel =>
      LocalizationService.industryCategoryLabel(category);

  int get defaultMonthlyFee => LocalizationService.currentCurrency.defaultFeeBase;

  String get localizedDefaultInvoiceTemplate => RegionWorkflowService.defaultInvoiceTemplate(
        LocalizationService.currentLanguage,
        LocalizationService.currentCurrency,
      );

  String get localizedDefaultAttendanceTemplate => RegionWorkflowService.defaultAttendanceTemplate(
        LocalizationService.currentLanguage,
      );

  String get localizedDefaultDepartureTemplate => RegionWorkflowService.defaultDepartureTemplate(
        LocalizationService.currentLanguage,
      );

  StudioProfile copyWith({
    String? studioName,
    String? instructorName,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? category,
    bool? autoBankDetectEnabled,
    String? invoiceTemplate,
    String? attendanceTemplate,
    String? departureTemplate,
    String? cardPaymentUrl,
    bool? cardPaymentEnabled,
    String? logoPath,
    bool clearLogo = false,
    String? customMemberTerm,
    String? customFeeTerm,
    String? customRoleTerm,
    String? customPlaceTerm,
    bool clearCustomTerms = false,
  }) {
    return StudioProfile(
      studioName: studioName ?? this.studioName,
      instructorName: instructorName ?? this.instructorName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolder: accountHolder ?? this.accountHolder,
      category: category ?? this.category,
      autoBankDetectEnabled: autoBankDetectEnabled ?? this.autoBankDetectEnabled,
      invoiceTemplate: invoiceTemplate ?? this.invoiceTemplate,
      attendanceTemplate: attendanceTemplate ?? this.attendanceTemplate,
      departureTemplate: departureTemplate ?? this.departureTemplate,
      cardPaymentUrl: cardPaymentUrl ?? this.cardPaymentUrl,
      cardPaymentEnabled: cardPaymentEnabled ?? this.cardPaymentEnabled,
      logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
      customMemberTerm: clearCustomTerms ? null : (customMemberTerm ?? this.customMemberTerm),
      customFeeTerm: clearCustomTerms ? null : (customFeeTerm ?? this.customFeeTerm),
      customRoleTerm: clearCustomTerms ? null : (customRoleTerm ?? this.customRoleTerm),
      customPlaceTerm: clearCustomTerms ? null : (customPlaceTerm ?? this.customPlaceTerm),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studioName': studioName,
      'instructorName': instructorName,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolder': accountHolder,
      'category': category,
      'autoBankDetectEnabled': autoBankDetectEnabled ? 1 : 0,
      'invoiceTemplate': invoiceTemplate,
      'attendanceTemplate': attendanceTemplate,
      'departureTemplate': departureTemplate,
      'cardPaymentUrl': cardPaymentUrl,
      'cardPaymentEnabled': cardPaymentEnabled ? 1 : 0,
      'logoPath': logoPath,
      'customMemberTerm': customMemberTerm,
      'customFeeTerm': customFeeTerm,
      'customRoleTerm': customRoleTerm,
      'customPlaceTerm': customPlaceTerm,
    };
  }

  factory StudioProfile.fromMap(Map<String, dynamic> map) {
    return StudioProfile(
      studioName: map['studioName'] as String? ?? '체크앤페이 스튜디오',
      instructorName: map['instructorName'] as String? ?? '담당자',
      bankName: map['bankName'] as String? ?? '토스뱅크',
      accountNumber: map['accountNumber'] as String? ?? '1000-1234-5678',
      accountHolder: map['accountHolder'] as String? ?? '홍길동',
      category: map['category'] as String? ?? '음악 / 피아노',
      autoBankDetectEnabled: (map['autoBankDetectEnabled'] is int)
          ? (map['autoBankDetectEnabled'] == 1)
          : (map['autoBankDetectEnabled'] as bool? ?? true),
      invoiceTemplate: map['invoiceTemplate'] as String? ?? defaultInvoiceTemplate,
      attendanceTemplate: map['attendanceTemplate'] as String? ?? defaultAttendanceTemplate,
      departureTemplate: map['departureTemplate'] as String? ?? defaultDepartureTemplate,
      cardPaymentUrl: map['cardPaymentUrl'] as String? ?? '',
      cardPaymentEnabled: (map['cardPaymentEnabled'] is int)
          ? (map['cardPaymentEnabled'] == 1)
          : (map['cardPaymentEnabled'] as bool? ?? false),
      logoPath: map['logoPath'] as String?,
      customMemberTerm: map['customMemberTerm'] as String?,
      customFeeTerm: map['customFeeTerm'] as String?,
      customRoleTerm: map['customRoleTerm'] as String?,
      customPlaceTerm: map['customPlaceTerm'] as String?,
    );
  }

  static const String defaultInvoiceTemplate = '''[#{상호명}] #{청구제목}
  
안녕하세요, #{상호명}입니다.
#{회원명} #{고객호칭}님의 #{비용호칭} 내역 안내드립니다.

────────────────
[청구 내역]
• 수납 금액 : #{금액}원
• 납부 기한 : #{납부기한}까지
• 입금 계좌 : #{계좌정보}
────────────────

[간편 입금 안내]
• 복사용 계좌 : #{계좌복사용}
(계좌번호를 복사 후 토스나 은행 앱을 여시면 바로 송금됩니다)

소중한 #{고객호칭}님과 함께할 수 있어 늘 감사드리며,
입금 확인 즉시 등록·갱신됩니다.
감사합니다.''';

  static const String defaultAttendanceTemplate = '''[#{상호명}] 출석 안심 알림

안녕하세요, #{상호명}입니다.
#{회원명} #{고객호칭}님이 #{장소호칭}에 안전하게 도착하여
출석 확인(체크인)을 완료하였습니다.

• 출석 일시 : #{출석시간}
#{잔여회차}

오늘도 즐겁고 유익한 시간이 되도록 정성껏 함께하겠습니다.
감사합니다.''';

  static const String defaultDepartureTemplate = '''[#{상호명}] 하원·퇴실 완료 알림

안녕하세요, #{상호명}입니다.
#{회원명} #{고객호칭}님이 금일 일정을 마치고
안전하게 귀가(퇴실)하였습니다.

오늘 하루도 수고 많으셨습니다. 감사합니다.''';

  static StudioProfile defaultProfile() {
    final lang = LocalizationService.currentLanguage;
    final currency = LocalizationService.currentCurrency;
    if (lang == AppLanguage.korean && currency == AppCurrency.krw) {
      return const StudioProfile(
        studioName: '마인드핏 아카데미 & 스튜디오',
        instructorName: '김서연',
        bankName: '토스뱅크',
        accountNumber: '1000-2026-8899',
        accountHolder: '김서연',
        category: '피트니스 / PT',
        autoBankDetectEnabled: true,
        invoiceTemplate: defaultInvoiceTemplate,
        attendanceTemplate: defaultAttendanceTemplate,
        departureTemplate: defaultDepartureTemplate,
      );
    }
    final meta = RegionWorkflowService.defaultStudioMetadata(lang, currency);
    return StudioProfile(
      studioName: meta['studioName']!,
      instructorName: meta['instructorName']!,
      bankName: meta['bankName']!,
      accountNumber: meta['accountNumber']!,
      accountHolder: meta['accountHolder']!,
      category: '피트니스 / PT',
      autoBankDetectEnabled: currency == AppCurrency.krw,
      invoiceTemplate: RegionWorkflowService.defaultInvoiceTemplate(lang, currency),
      attendanceTemplate: RegionWorkflowService.defaultAttendanceTemplate(lang),
      departureTemplate: RegionWorkflowService.defaultDepartureTemplate(lang),
    );
  }
}
