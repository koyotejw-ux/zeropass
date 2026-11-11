import '../services/localization_service.dart';

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
        return LocalizationService.pick(
          ko: '등원 안심 알림',
          en: 'Check-In Alert',
          ja: '出席安心通知',
          zh: '到店签到通知',
          vi: 'Thông báo đến lớp',
          es: 'Aviso de llegada',
        );
      case NotificationType.departure:
        return LocalizationService.pick(
          ko: '하원 귀가 알림',
          en: 'Check-Out Alert',
          ja: '帰宅安心通知',
          zh: '离店安心通知',
          vi: 'Thông báo ra về',
          es: 'Aviso de salida',
        );
      case NotificationType.billing:
        return LocalizationService.pick(
          ko: '수강료 청구',
          en: 'Tuition Invoice',
          ja: '授業料請求',
          zh: '账单缴费通知',
          vi: 'Hóa đơn học phí',
          es: 'Factura de cuota',
        );
      case NotificationType.reminder:
        return LocalizationService.pick(
          ko: '미납 리마인드',
          en: 'Overdue Reminder',
          ja: '未納リマインド',
          zh: '欠费催缴提醒',
          vi: 'Nhắc thanh toán',
          es: 'Recordatorio de pago',
        );
      case NotificationType.receipt:
        return LocalizationService.pick(
          ko: '수납 영수증',
          en: 'Payment Receipt',
          ja: '領収証',
          zh: '收款电子收据',
          vi: 'Biên nhận thanh toán',
          es: 'Recibo de pago',
        );
      case NotificationType.sessionExpiry:
        return LocalizationService.pick(
          ko: '수강권 재등록 안내',
          en: 'Pass Renewal',
          ja: '回数券更新案内',
          zh: '续课到期提醒',
          vi: 'Nhắc gia hạn gói',
          es: 'Aviso de renovación',
        );
      case NotificationType.notice:
        return LocalizationService.pick(
          ko: '공지 및 휴원 안내',
          en: 'General Notice',
          ja: 'お知らせ・休講案内',
          zh: '公告与停课通知',
          vi: 'Thông báo chung',
          es: 'Aviso general',
        );
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
      memberName: map['memberName'] as String? ??
          LocalizationService.pick(
            ko: '회원',
            en: 'Member',
            ja: '会員',
            zh: '会员',
            vi: 'Hội viên',
            es: 'Miembro',
          ),
      recipientPhone: map['recipientPhone'] as String? ?? '',
      channel: map['channel'] as String? ?? 'SMS',
      message: map['message'] as String? ?? '',
      sentAt: DateTime.tryParse(map['sentAt'] as String? ?? '') ?? DateTime.now(),
      isSuccess: (map['isSuccess'] is int) ? (map['isSuccess'] == 1) : (map['isSuccess'] as bool? ?? true),
    );
  }
}

