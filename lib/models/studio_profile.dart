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
  });

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
    };
  }

  factory StudioProfile.fromMap(Map<String, dynamic> map) {
    return StudioProfile(
      studioName: map['studioName'] as String? ?? '제로패스 스튜디오',
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
    );
  }

  static const String defaultInvoiceTemplate = '''[#{상호명}] 수강료 청구 안내

안녕하세요, #{상호명}입니다.
#{회원명} 회원님의 #{청구제목} 안내드립니다.

────────────────
[청구 내역]
• 수납 금액 : #{금액}원
• 납부 기한 : #{납부기한}까지
• 입금 계좌 : #{계좌정보}
────────────────

[간편 입금 안내]
• 계좌 복사 : #{계좌복사용}
• 토스 송금 : #{토스송금링크}

소중한 회원님과 함께할 수 있어 늘 감사드리며,
입금 확인 즉시 수업 패스가 안전하게 등록·갱신됩니다.
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
