import 'dart:convert';
import 'member.dart';

class Invoice {
  final String id; // UUID
  final List<String> memberIds; // Supports siblings/bundle billing
  final String recipientPhone;
  final String title; // e.g., "3월 수강 패스 안내", "PT 10회 재등록 안내"
  final int amount;
  final DateTime dueDate;
  final PaymentStatus status;
  final String? paymentMethod; // "TRANSFER", "OFFLINE_CARD", "CASH"
  final DateTime? paidAt;
  final String? externalOrderId; // Prepared for future PG expansion

  const Invoice({
    required this.id,
    required this.memberIds,
    required this.recipientPhone,
    required this.title,
    required this.amount,
    required this.dueDate,
    required this.status,
    this.paymentMethod,
    this.paidAt,
    this.externalOrderId,
  });

  Invoice copyWith({
    String? id,
    List<String>? memberIds,
    String? recipientPhone,
    String? title,
    int? amount,
    DateTime? dueDate,
    PaymentStatus? status,
    String? paymentMethod,
    DateTime? paidAt,
    String? externalOrderId,
  }) {
    return Invoice(
      id: id ?? this.id,
      memberIds: memberIds ?? this.memberIds,
      recipientPhone: recipientPhone ?? this.recipientPhone,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      dueDate: dueDate ?? this.dueDate,
      status: status ?? this.status,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paidAt: paidAt ?? this.paidAt,
      externalOrderId: externalOrderId ?? this.externalOrderId,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'memberIds': jsonEncode(memberIds),
      'recipientPhone': recipientPhone,
      'title': title,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'status': status.name,
      'paymentMethod': paymentMethod,
      'paidAt': paidAt?.toIso8601String(),
      'externalOrderId': externalOrderId,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    List<String> ids = [];
    final rawIds = map['memberIds'];
    if (rawIds is String) {
      try {
        final decoded = jsonDecode(rawIds);
        if (decoded is List) {
          ids = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {
        ids = [rawIds];
      }
    } else if (rawIds is List) {
      ids = rawIds.map((e) => e.toString()).toList();
    }

    return Invoice(
      id: map['id'] as String,
      memberIds: ids,
      recipientPhone: map['recipientPhone'] as String,
      title: map['title'] as String,
      amount: map['amount'] as int,
      dueDate: DateTime.parse(map['dueDate'] as String),
      status: PaymentStatus.values.byName(map['status'] as String),
      paymentMethod: map['paymentMethod'] as String?,
      paidAt: map['paidAt'] != null ? DateTime.parse(map['paidAt'] as String) : null,
      externalOrderId: map['externalOrderId'] as String?,
    );
  }
}
