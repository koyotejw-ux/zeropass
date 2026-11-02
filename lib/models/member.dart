enum BillingType { monthlyRecurring, sessionBased }

enum AttendanceStatus { attended, absent, late }

enum PaymentStatus { unpaid, paid, cancelled }

class Member {
  final String id; // UUID
  final String name;
  final String phone; // Normalized 11 digits (01012345678)
  final String groupName; // e.g., "중등수학", "PT 화목반", "도예 주말반"
  final BillingType billingType;
  final int defaultFee;
  final int totalSessions; // For session-based (e.g. 10)
  final int remainingSessions; // For session-based
  final String? memo;
  final String? payerName; // Optional parent/actual depositor name for 100% bank push matching
  final DateTime registeredAt;
  final String? photoPath; // Local file path or asset URI for member profile photo

  const Member({
    required this.id,
    required this.name,
    required this.phone,
    required this.groupName,
    required this.billingType,
    required this.defaultFee,
    required this.totalSessions,
    required this.remainingSessions,
    this.memo,
    this.payerName,
    required this.registeredAt,
    this.photoPath,
  });

  /// 회원의 순수 이름만 추출 (부차적인 괄호, 코스 표기 등을 제외하여 1줄 표시 보장)
  /// 예: '강지훈 (바디프로필 PT)' -> '강지훈'
  /// 예: '이도현(중2 수학반)' -> '이도현'
  /// 예: '박민지 [1:1 필라테스]' -> '박민지'
  /// 예: '정하율' -> '정하율'
  String get primaryName {
    final trimmed = name.trim();
    // 1. 괄호 표기 매칭 ( ) [ ] < > { }
    final bracketMatch = RegExp(r'^(.*?)\s*[\(\[\<\{](.+?)[\)\]\>\}]').firstMatch(trimmed);
    if (bracketMatch != null && bracketMatch.group(1)!.trim().isNotEmpty) {
      return bracketMatch.group(1)!.trim();
    }
    // 2. 구분 기호 표기 매칭 (- / · |)
    final delimiterMatch = RegExp(r'^(.*?)\s*[-–—/·|]\s*(.+)$').firstMatch(trimmed);
    if (delimiterMatch != null && delimiterMatch.group(1)!.trim().isNotEmpty) {
      return delimiterMatch.group(1)!.trim();
    }
    return trimmed;
  }

  /// 이름 뒤에 붙어있던 부차적 부가 태그/과정명/비고 정보 분리
  /// 예: '강지훈 (바디프로필 PT)' -> '바디프로필 PT'
  /// 예: '이도현(중2 수학반)' -> '중2 수학반'
  String? get secondaryTag {
    final trimmed = name.trim();
    final bracketMatch = RegExp(r'^(.*?)\s*[\(\[\<\{](.+?)[\)\]\>\}]').firstMatch(trimmed);
    if (bracketMatch != null && bracketMatch.group(2)!.trim().isNotEmpty) {
      return bracketMatch.group(2)!.trim();
    }
    final delimiterMatch = RegExp(r'^(.*?)\s*[-–—/·|]\s*(.+)$').firstMatch(trimmed);
    if (delimiterMatch != null && delimiterMatch.group(2)!.trim().isNotEmpty) {
      return delimiterMatch.group(2)!.trim();
    }
    return null;
  }

  /// 1글자 이니셜 (아바타용)
  String get initial {
    final p = primaryName;
    return p.isNotEmpty ? p.substring(0, 1) : '?';
  }

  Member copyWith({
    String? id,
    String? name,
    String? phone,
    String? groupName,
    BillingType? billingType,
    int? defaultFee,
    int? totalSessions,
    int? remainingSessions,
    String? memo,
    String? payerName,
    DateTime? registeredAt,
    String? photoPath,
  }) {
    return Member(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      groupName: groupName ?? this.groupName,
      billingType: billingType ?? this.billingType,
      defaultFee: defaultFee ?? this.defaultFee,
      totalSessions: totalSessions ?? this.totalSessions,
      remainingSessions: remainingSessions ?? this.remainingSessions,
      memo: memo ?? this.memo,
      payerName: payerName ?? this.payerName,
      registeredAt: registeredAt ?? this.registeredAt,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'groupName': groupName,
      'billingType': billingType.name,
      'defaultFee': defaultFee,
      'totalSessions': totalSessions,
      'remainingSessions': remainingSessions,
      'memo': memo,
      'payerName': payerName,
      'registeredAt': registeredAt.toIso8601String(),
      'photoPath': photoPath,
    };
  }

  factory Member.fromMap(Map<String, dynamic> map) {
    return Member(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String,
      groupName: map['groupName'] as String,
      billingType: BillingType.values.byName(map['billingType'] as String),
      defaultFee: map['defaultFee'] as int,
      totalSessions: map['totalSessions'] as int,
      remainingSessions: map['remainingSessions'] as int,
      memo: map['memo'] as String?,
      payerName: map['payerName'] as String?,
      registeredAt: DateTime.parse(map['registeredAt'] as String),
      photoPath: map['photoPath'] as String?,
    );
  }
}
