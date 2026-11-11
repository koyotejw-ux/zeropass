import 'dart:convert';
import '../services/localization_service.dart';

enum ScheduleCategory {
  academy('학원/스튜디오 일정', 0xFF2563EB),
  holiday('휴원/휴무일', 0xFFEF4444),
  examOrTest('평가/모의고사/심사', 0xFF8B5CF6),
  billingTax('수납/세무 일정', 0xFF059669),
  specialLesson('특강/이벤트', 0xFFF59E0B),
  custom('기타 메모', 0xFF64748B);

  final String label;
  final int colorValue;

  const ScheduleCategory(this.label, this.colorValue);

  String get localizedLabel {
    switch (this) {
      case ScheduleCategory.academy:
        return LocalizationService.pick(
          ko: label,
          en: 'Studio Schedule',
          ja: 'スタジオ予定',
          zh: '机构日程',
          vi: 'Lịch cơ sở',
          es: 'Horario del centro',
        );
      case ScheduleCategory.holiday:
        return LocalizationService.pick(
          ko: label,
          en: 'Holiday / Closed',
          ja: '休講・休業日',
          zh: '休假/停课日',
          vi: 'Nghỉ lễ / Đóng cửa',
          es: 'Festivo / Cerrado',
        );
      case ScheduleCategory.examOrTest:
        return LocalizationService.pick(
          ko: label,
          en: 'Exam / Evaluation',
          ja: 'テスト・審査',
          zh: '考核/测验',
          vi: 'Kiểm tra / Đánh giá',
          es: 'Examen / Evaluación',
        );
      case ScheduleCategory.billingTax:
        return LocalizationService.pick(
          ko: label,
          en: 'Billing / Tax Schedule',
          ja: '集金・税務予定',
          zh: '收款/税务日程',
          vi: 'Lịch thu phí / Thuế',
          es: 'Cobros / Impuestos',
        );
      case ScheduleCategory.specialLesson:
        return LocalizationService.pick(
          ko: label,
          en: 'Workshop / Event',
          ja: '特別講座・イベント',
          zh: '特训/活动',
          vi: 'Chuyên đề / Sự kiện',
          es: 'Taller / Evento',
        );
      case ScheduleCategory.custom:
        return LocalizationService.pick(
          ko: label,
          en: 'Other Memo',
          ja: 'その他メモ',
          zh: '其他备注',
          vi: 'Ghi chú khác',
          es: 'Otras notas',
        );
    }
  }
}

class ScheduleItem {
  final String id;
  final String title;
  final DateTime date;
  final ScheduleCategory category;
  final String? memo;
  final bool isAllDay;
  final DateTime createdAt;

  const ScheduleItem({
    required this.id,
    required this.title,
    required this.date,
    this.category = ScheduleCategory.academy,
    this.memo,
    this.isAllDay = true,
    required this.createdAt,
  });

  ScheduleItem copyWith({
    String? id,
    String? title,
    DateTime? date,
    ScheduleCategory? category,
    String? memo,
    bool? isAllDay,
    DateTime? createdAt,
  }) {
    return ScheduleItem(
      id: id ?? this.id,
      title: title ?? this.title,
      date: date ?? this.date,
      category: category ?? this.category,
      memo: memo ?? this.memo,
      isAllDay: isAllDay ?? this.isAllDay,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': date.toIso8601String(),
      'category': category.name,
      'memo': memo,
      'isAllDay': isAllDay,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory ScheduleItem.fromMap(Map<String, dynamic> map) {
    return ScheduleItem(
      id: map['id'] as String,
      title: map['title'] as String,
      date: DateTime.parse(map['date'] as String),
      category: ScheduleCategory.values.firstWhere(
        (c) => c.name == map['category'],
        orElse: () => ScheduleCategory.academy,
      ),
      memo: map['memo'] as String?,
      isAllDay: map['isAllDay'] as bool? ?? true,
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : DateTime.now(),
    );
  }

  String toJson() => json.encode(toMap());

  factory ScheduleItem.fromJson(String source) =>
      ScheduleItem.fromMap(json.decode(source) as Map<String, dynamic>);
}

