class StudioProfile {
  final String studioName;
  final String instructorName;
  final String bankName;
  final String accountNumber;
  final String accountHolder;
  final bool autoBankDetectEnabled;

  const StudioProfile({
    required this.studioName,
    required this.instructorName,
    required this.bankName,
    required this.accountNumber,
    required this.accountHolder,
    this.autoBankDetectEnabled = true,
  });

  StudioProfile copyWith({
    String? studioName,
    String? instructorName,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    bool? autoBankDetectEnabled,
  }) {
    return StudioProfile(
      studioName: studioName ?? this.studioName,
      instructorName: instructorName ?? this.instructorName,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolder: accountHolder ?? this.accountHolder,
      autoBankDetectEnabled: autoBankDetectEnabled ?? this.autoBankDetectEnabled,
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
    );
  }

  static StudioProfile defaultProfile() {
    return const StudioProfile(
      studioName: '마인드핏 아카데미 & 스튜디오',
      instructorName: '김서연 대표/원장',
      bankName: '토스뱅크',
      accountNumber: '1000-2026-8899',
      accountHolder: '김서연',
      autoBankDetectEnabled: true,
    );
  }
}
