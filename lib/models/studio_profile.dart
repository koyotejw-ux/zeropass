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

  /// 업종별 대표자 직함 (원장 / 대표 / 코치 / 강사)
  String get roleTitle {
    if (category.contains('피트니스') || category.contains('PT') || category.contains('스포츠') || category.contains('수영')) {
      return '대표 / 트레이너';
    } else if (category.contains('공방') || category.contains('도예') || category.contains('미술')) {
      return '대표 / 작가';
    } else if (category.contains('필라테스') || category.contains('요가') || category.contains('무용') || category.contains('댄스')) {
      return '원장 / 강사';
    } else if (category.contains('학원') || category.contains('입시') || category.contains('어학') || category.contains('코딩')) {
      return '원장';
    }
    return '대표 / 원장';
  }

  /// 고객/회원 호칭 (학생 / 회원 / 수강생)
  String get memberTitle {
    if (category.contains('학원') || category.contains('입시') || category.contains('어학') || category.contains('태권도')) {
      return '학생 / 수강생';
    } else if (category.contains('피트니스') || category.contains('PT') || category.contains('필라테스') || category.contains('요가')) {
      return '회원';
    } else if (category.contains('공방') || category.contains('공간대여')) {
      return '이용 고객 / 회원';
    }
    return '회원 / 수강생';
  }

  /// 수강료/이용료/회비 호칭
  String get feeTitle {
    if (category.contains('학원') || category.contains('음악') || category.contains('어학')) {
      return '수강료';
    } else if (category.contains('피트니스') || category.contains('PT') || category.contains('필라테스')) {
      return '회비 / 레슨비';
    } else if (category.contains('공방') || category.contains('공간대여')) {
      return '이용료 / 재료비';
    }
    return '수납 / 회비';
  }

  /// 사업장 성격 (스튜디오 / 센터 / 학원 / 공방 / 매장)
  String get placeTitle {
    if (category.contains('학원') || category.contains('입시') || category.contains('어학')) {
      return '학원 / 교습소';
    } else if (category.contains('피트니스') || category.contains('PT') || category.contains('스포츠')) {
      return '센터 / 피트니스샵';
    } else if (category.contains('필라테스') || category.contains('요가') || category.contains('댄스')) {
      return '스튜디오';
    } else if (category.contains('공방') || category.contains('도예')) {
      return '공방 / 작업실';
    }
    return '사업장 / 매장';
  }

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
    };
  }

  factory StudioProfile.fromMap(Map<String, dynamic> map) {
    return StudioProfile(
      studioName: map['studioName'] as String? ?? '체크앤페이 스튜디오',
      instructorName: map['instructorName'] as String? ?? '김원장',
      bankName: map['bankName'] as String? ?? '토스뱅크',
      accountNumber: map['accountNumber'] as String? ?? '1000-1234-5678',
      accountHolder: map['accountHolder'] as String? ?? '김원장',
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
    );
  }

  static const String defaultInvoiceTemplate = '''[#{상호명}] #{청구제목}
  
안녕하세요, #{상호명}입니다.
#{회원명} 회원님의 수납 내역 안내드립니다.

────────────────
[청구 내역]
• 수납 금액 : #{금액}원
• 납부 기한 : #{납부기한}까지
• 입금 계좌 : #{계좌정보}
────────────────

[간편 입금 안내]
• 복사용 계좌 : #{계좌복사용}
(계좌번호를 복사 후 토스나 은행 앱을 여시면 바로 송금됩니다)

소중한 회원님과 함께할 수 있어 늘 감사드리며,
입금 확인 즉시 등록·갱신됩니다.
감사합니다.''';

  static const String defaultAttendanceTemplate = '''[#{상호명}] 출석 안심 알림

안녕하세요, #{상호명}입니다.
#{회원명} 회원님이 학원/센터에 안전하게 도착하여
출석 확인(체크인)을 완료하였습니다.

• 출석 일시 : #{출석시간}
#{잔여회차}

오늘도 즐겁고 유익한 시간이 되도록 정성껏 지도하겠습니다.
감사합니다.''';

  static const String defaultDepartureTemplate = '''[#{상호명}] 하원 완료 알림

안녕하세요, #{상호명}입니다.
#{회원명} 회원님이 금일 모든 수업 일정을 마치고
안전하게 귀가(하원)하였습니다.

오늘 하루도 정말 수고 많았습니다.
가정에서도 따뜻한 격려와 칭찬 부탁드립니다.
감사합니다.''';

  static StudioProfile defaultProfile() {
    return const StudioProfile(
      studioName: '마인드핏 아카데미 & 스튜디오',
      instructorName: '김서연 대표/원장',
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
}
