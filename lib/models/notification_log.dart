enum NotificationType {
  attendance, // 등원 / 출석 확인
  departure, // 하원 / 귀가 안심
  billing, // 수강료 청구
  reminder, // 미납 리마인드
  receipt, // 수납 완료 영수증
  sessionExpiry, // 수강권 만료 / 재등록 안내
  notice, // 일반 공지 / 휴원 안내
}

class NotificationLog {
  final String id;
  final NotificationType type;
  final String? memberId;
  final String memberName;
  final String recipientPhone;
  final String channel; // 'KAKAO' or 'SMS'
  final String message;
  final DateTime sentAt;
  final bool isSuccess;

  const NotificationLog({
    required this.id,
    required this.type,
    this.memberId,
    required this.memberName,
    required this.recipientPhone,
    required this.channel,
    required this.message,
    required this.sentAt,
    this.isSuccess = true,
  });

  String get typeLabel {
    switch (type) {
      case NotificationType.attendance:
        return '등원 안심 알림';
      case NotificationType.departure:
        return '하원 귀가 알림';
      case NotificationType.billing:
        return '수강료 청구';
      case NotificationType.reminder:
        return '미납 리마인드';
      case NotificationType.receipt:
        return '수납 영수증';
      case NotificationType.sessionExpiry:
        return '수강권 재등록 안내';
      case NotificationType.notice:
        return '공지 및 휴원 안내';
    }
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'type': type.name,
      'memberId': memberId,
      'memberName': memberName,
      'recipientPhone': recipientPhone,
      'channel': channel,
      'message': message,
      'sentAt': sentAt.toIso8601String(),
      'isSuccess': isSuccess ? 1 : 0,
    };
  }

  factory NotificationLog.fromMap(Map<String, dynamic> map) {
    return NotificationLog(
      id: map['id'] as String,
      type: NotificationType.values.firstWhere(
        (t) => t.name == map['type'],
        orElse: () => NotificationType.notice,
      ),
      memberId: map['memberId'] as String?,
      memberName: map['memberName'] as String? ?? '회원',
      recipientPhone: map['recipientPhone'] as String? ?? '',
      channel: map['channel'] as String? ?? 'SMS',
      message: map['message'] as String? ?? '',
      sentAt: DateTime.tryParse(map['sentAt'] as String? ?? '') ?? DateTime.now(),
      isSuccess: (map['isSuccess'] is int) ? (map['isSuccess'] == 1) : (map['isSuccess'] as bool? ?? true),
    );
  }
}

