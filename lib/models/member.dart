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
  });

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
    );
  }
}
