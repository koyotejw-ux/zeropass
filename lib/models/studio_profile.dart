class StudioProfile {
  final String studioName;
  final String instructorName;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final bool autoBankDetectEnabled;
  final String invoiceTemplate;
  final String attendanceTemplate;
  final String departureTemplate;

  const StudioProfile({
    required this.studioName,
    required this.instructorName,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
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
#{회원명} 회원님의 #{청구제목}이 발행되었습니다.

• 수납 금액: #{금액}원
• 입금 계좌: #{계좌정보}
• 납부 기한: #{납부기한}까지

[간편 입금 안내]
• 계좌 복사하기: #{계좌복사용}
• 토스 바로 송금: #{토스송금링크}

기한 내 입금 부탁드리며 확인 즉시 출결 패스가 안전하게 갱신됩니다. 감사합니다.''';

  static const String defaultAttendanceTemplate = '''[#{상호명}] 출석 확인
안녕하세요.
#{회원명} 회원님이 오늘 #{출석시간}에 정상 출석(등원)하였습니다.
#{잔여회차}
오늘도 알차고 즐거운 수업이 되도록 정성을 다하겠습니다.''';

  static const String defaultDepartureTemplate = '''[#{상호명}] 하원 완료
안녕하세요.
#{회원명} 회원님이 오늘 수업을 마치고 안전하게 귀가(하원)하였습니다.
가정에서 많은 칭찬 부탁드립니다. 감사합니다.''';

  static StudioProfile defaultProfile() {
    return const StudioProfile(
      studioName: '마인드핏 아카데미 & 스튜디오',
      instructorName: '김서연 대표/원장',
      bankName: '토스뱅크',
      accountNumber: '1000-2026-8899',
      accountHolder: '김서연',
      autoBankDetectEnabled: true,
      invoiceTemplate: defaultInvoiceTemplate,
      attendanceTemplate: defaultAttendanceTemplate,
      departureTemplate: defaultDepartureTemplate,
    );
  }
}
