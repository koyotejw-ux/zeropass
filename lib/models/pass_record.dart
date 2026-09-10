import 'member.dart';

class PassRecord {
  final String id;
  final String memberId;
  final DateTime timestamp;
  final AttendanceStatus status;
  final int? sessionDeduction; // Usually 1 for session-based

  const PassRecord({
    required this.id,
    required this.memberId,
    required this.timestamp,
    required this.status,
    this.sessionDeduction,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberId': memberId,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'sessionDeduction': sessionDeduction,
    };
  }

  factory PassRecord.fromMap(Map<String, dynamic> map) {
    return PassRecord(
      id: map['id'] as String,
      memberId: map['memberId'] as String,
      timestamp: DateTime.parse(map['timestamp'] as String),
      status: AttendanceStatus.values.byName(map['status'] as String),
      sessionDeduction: map['sessionDeduction'] as int?,
    );
  }
}
