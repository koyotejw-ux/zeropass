import 'dart:convert';

/// 지출 내역 (Expense Item) 데이터 모델
/// 체크인 페이의 매입/지출을 기록하여 [수입 - 지출 = 순이익] 및 국세청 간편장부를 원터치로 산출합니다.
class ExpenseItem {
  final String id;
  final String? vendorId; // 연결된 거래처 ID (선택)
  final String vendorName; // 거래처 상호/수취인명
  final String title; // 지출 품목/내용 (예: '5월 수학 워크북 발주', '스튜디오 월세', '트레이너 수업료')
  final int amount; // 지출 금액 (원천징수 전 총액)
  final DateTime date; // 지출/발생 일자
  final String category; // 지출 분류 (교재비, 임대료, 강사료, 소모품비, 시설관리, 공과금, 기타)
  final String paymentMethod; // 결제 수단 (계좌이체, 신용카드, 현금, 간편결제)
  final bool isPaid; // 지급 완료 여부 (true: 완납, false: 미지급/외상)
  final String? memo; // 비고/메모
  final DateTime createdAt;
  final String taxEvidence; // 세무 적격증빙 (세금계산서, 계산서, 신용카드, 현금영수증, 간이영수증, 기타)
  final bool isWithholdingApplied; // 3.3% 프리랜서 원천징수 적용 여부
  final int withholdingTax; // 원천징수 세액 (소득세 3% + 지방소득세 0.3%)

  static const List<String> taxEvidenceTypes = [
    '세금계산서',
    '계산서(면세)',
    '신용카드',
    '현금영수증(지출증빙)',
    '간이영수증',
    '원천징수(3.3%)',
    '기타/통장증빙',
  ];

  const ExpenseItem({
    required this.id,
    this.vendorId,
    required this.vendorName,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    this.paymentMethod = '계좌이체',
    this.isPaid = true,
    this.memo,
    required this.createdAt,
    this.taxEvidence = '기타/통장증빙',
    this.isWithholdingApplied = false,
    this.withholdingTax = 0,
  });

  /// 3.3% 원천징수 공제 후 실제 이체/지급해야 할 실수령액
  int get actualPayoutAmount => isWithholdingApplied ? (amount - withholdingTax) : amount;

  ExpenseItem copyWith({
    String? id,
    String? vendorId,
    String? vendorName,
    String? title,
    int? amount,
    DateTime? date,
    String? category,
    String? paymentMethod,
    bool? isPaid,
    String? memo,
    DateTime? createdAt,
    String? taxEvidence,
    bool? isWithholdingApplied,
    int? withholdingTax,
  }) {
    return ExpenseItem(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      vendorName: vendorName ?? this.vendorName,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      category: category ?? this.category,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      isPaid: isPaid ?? this.isPaid,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
      taxEvidence: taxEvidence ?? this.taxEvidence,
      isWithholdingApplied: isWithholdingApplied ?? this.isWithholdingApplied,
      withholdingTax: withholdingTax ?? this.withholdingTax,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendorId': vendorId,
      'vendorName': vendorName,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(),
      'category': category,
      'paymentMethod': paymentMethod,
      'isPaid': isPaid ? 1 : 0,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
      'taxEvidence': taxEvidence,
      'isWithholdingApplied': isWithholdingApplied ? 1 : 0,
      'withholdingTax': withholdingTax,
    };
  }

  factory ExpenseItem.fromMap(Map<String, dynamic> map) {
    return ExpenseItem(
      id: map['id'] as String? ?? 'exp_${DateTime.now().millisecondsSinceEpoch}',
      vendorId: map['vendorId'] as String?,
      vendorName: map['vendorName'] as String? ?? '일반 지출',
      title: map['title'] as String? ?? '운영 지출',
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      date: map['date'] != null
          ? DateTime.tryParse(map['date'].toString()) ?? DateTime.now()
          : DateTime.now(),
      category: map['category'] as String? ?? '기타',
      paymentMethod: map['paymentMethod'] as String? ?? '계좌이체',
      isPaid: (map['isPaid'] is int)
          ? (map['isPaid'] as int) == 1
          : (map['isPaid'] as bool? ?? true),
      memo: map['memo'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      taxEvidence: map['taxEvidence'] as String? ?? '기타/통장증빙',
      isWithholdingApplied: (map['isWithholdingApplied'] is int)
          ? (map['isWithholdingApplied'] == 1)
          : (map['isWithholdingApplied'] as bool? ?? false),
      withholdingTax: (map['withholdingTax'] as num?)?.toInt() ?? 0,
    );
  }

  String toJson() => jsonEncode(toMap());
  factory ExpenseItem.fromJson(String source) =>
      ExpenseItem.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
