import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/schedule_item.dart';

class ScheduleService {
  static const String _keySchedules = 'custom_studio_schedules_v1';

  static List<ScheduleItem> getInitialPresets() {
    final now = DateTime.now();
    return [
      ScheduleItem(
        id: 'preset_tax_10',
        title: '원천세 및 4대보험 납부일',
        date: DateTime(now.year, now.month, 10),
        category: ScheduleCategory.billingTax,
        memo: '국세청 홈택스 원천징수이행상황신고 및 납부 마감',
        createdAt: now,
      ),
      ScheduleItem(
        id: 'preset_billing_25',
        title: '이달의 정기 수강료 정산 마감',
        date: DateTime(now.year, now.month, 25),
        category: ScheduleCategory.billingTax,
        memo: '익월 원비 청구서 발송 및 미납금 현황 확인',
        createdAt: now,
      ),
      ScheduleItem(
        id: 'preset_level_test',
        title: '정기 학습 성취도 평가 / 실력 점검',
        date: DateTime(now.year, now.month, 18),
        category: ScheduleCategory.examOrTest,
        memo: '학부모 안심 성적 리포트 발송 예정',
        createdAt: now,
      ),
      ScheduleItem(
        id: 'preset_workshop',
        title: '스튜디오 방역 및 시설 정기 점검',
        date: DateTime(now.year, now.month, 28),
        category: ScheduleCategory.academy,
        memo: '무인 키오스크 기기 상태 및 소독 점검',
        createdAt: now,
      ),
    ];
  }

  static Future<List<ScheduleItem>> loadSchedules() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_keySchedules);
    if (jsonStr == null || jsonStr.isEmpty) {
      final presets = getInitialPresets();
      await saveSchedules(presets);
      return presets;
    }
    try {
      final list = json.decode(jsonStr) as List<dynamic>;
      return list.map((e) => ScheduleItem.fromMap(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return getInitialPresets();
    }
  }

  static Future<void> saveSchedules(List<ScheduleItem> schedules) async {
    final prefs = await SharedPreferences.getInstance();
    final list = schedules.map((e) => e.toMap()).toList();
    await prefs.setString(_keySchedules, json.encode(list));
  }

  static Future<void> addSchedule(ScheduleItem item) async {
    final current = await loadSchedules();
    current.add(item);
    await saveSchedules(current);
  }

  static Future<void> deleteSchedule(String id) async {
    final current = await loadSchedules();
    current.removeWhere((e) => e.id == id);
    await saveSchedules(current);
  }

  static Future<void> updateSchedule(ScheduleItem item) async {
    final current = await loadSchedules();
    final idx = current.indexWhere((e) => e.id == item.id);
    if (idx != -1) {
      current[idx] = item;
      await saveSchedules(current);
    }
  }

  static Future<void> clearSchedules() async {
    await saveSchedules([]);
  }
}

