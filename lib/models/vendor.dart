import 'dart:convert';

/// 거래처 (Vendor/Supplier/Partner) 데이터 모델
/// 학원 교재 총판, 피트니스 기구 납품처, 인쇄소, 공방 재료상, 프리랜서 강사 등
class Vendor {
  final String id;
  final String name; // 거래처 상호/이름 (예: '(주)에듀프라임 교재총판', '몬스터피트니스 기구', '김코치')
  final String category; // 분류 (교재/교구, 시설/기구, 소모품/비품, 강사/코치료, 임대/관리비, 기타)
  final String? bankName; // 입금 은행
  final String? accountNumber; // 입금 계좌번호
  final String? accountHolder; // 예금주
  final String? phone; // 연락처
  final String? memo; // 메모 (예: 담당자 직통, 납품 주기 등)
  final DateTime createdAt;

  const Vendor({
    required this.id,
    required this.name,
    required this.category,
    this.bankName,
    this.accountNumber,
    this.accountHolder,
    this.phone,
    this.memo,
    required this.createdAt,
  });

  Vendor copyWith({
    String? id,
    String? name,
    String? category,
    String? bankName,
    String? accountNumber,
    String? accountHolder,
    String? phone,
    String? memo,
    DateTime? createdAt,
  }) {
    return Vendor(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      bankName: bankName ?? this.bankName,
      accountNumber: accountNumber ?? this.accountNumber,
      accountHolder: accountHolder ?? this.accountHolder,
      phone: phone ?? this.phone,
      memo: memo ?? this.memo,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountHolder': accountHolder,
      'phone': phone,
      'memo': memo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Vendor.fromMap(Map<String, dynamic> map) {
    return Vendor(
      id: map['id'] as String? ?? 'vnd_${DateTime.now().millisecondsSinceEpoch}',
      name: map['name'] as String? ?? '거래처',
      category: map['category'] as String? ?? '기타',
      bankName: map['bankName'] as String?,
      accountNumber: map['accountNumber'] as String?,
      accountHolder: map['accountHolder'] as String?,
      phone: map['phone'] as String?,
      memo: map['memo'] as String?,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());
  factory Vendor.fromJson(String source) =>
      Vendor.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
