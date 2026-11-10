import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/invoice.dart';
import '../models/studio_profile.dart';
import '../models/custom_category_template.dart';
import '../models/vendor.dart';
import '../models/expense_item.dart';
import '../models/notification_log.dart';
import '../models/schedule_item.dart';
import '../services/custom_category_service.dart';
import '../services/database_service.dart';
import 'dart:ui';
import '../services/schedule_service.dart';
import '../services/localization_service.dart';

// Database Instance Provider
final databaseServiceProvider = Provider<DatabaseService>((ref) {
  return DatabaseService.instance;
});

// Members AsyncNotifier
class MembersNotifier extends AsyncNotifier<List<Member>> {
  @override
  Future<List<Member>> build() async {
    final db = ref.read(databaseServiceProvider);
    return await db.getMembers();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      return await db.getMembers();
    });
  }

  Future<void> addMember(Member member) async {
    final db = ref.read(databaseServiceProvider);
    await db.insertMember(member);
    await reload();
  }

  Future<void> updateMember(Member member) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateMember(member);
    await reload();
  }

  Future<void> deleteMember(String id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteMember(id);
    await reload();
  }

  Future<void> addSessions(String memberId, int sessionsToAdd) async {
    final currentList = state.value ?? [];
    final idx = currentList.indexWhere((m) => m.id == memberId);
    if (idx != -1) {
      final m = currentList[idx];
      final updated = m.copyWith(
        totalSessions: m.totalSessions + sessionsToAdd,
        remainingSessions: m.remainingSessions + sessionsToAdd,
      );
      await updateMember(updated);
    }
  }
}

final membersProvider = AsyncNotifierProvider<MembersNotifier, List<Member>>(() {
  return MembersNotifier();
});

// Pass Records AsyncNotifier
class PassRecordsNotifier extends AsyncNotifier<List<PassRecord>> {
  @override
  Future<List<PassRecord>> build() async {
    final db = ref.read(databaseServiceProvider);
    return await db.getPassRecords();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      return await db.getPassRecords();
    });
  }

  Future<void> checkInMember({
    required Member member,
    AttendanceStatus status = AttendanceStatus.attended,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final record = PassRecord(
      id: 'pass_${DateTime.now().microsecondsSinceEpoch}_${member.id}',
      memberId: member.id,
      timestamp: DateTime.now(),
      status: status,
      sessionDeduction: member.billingType == BillingType.sessionBased ? 1 : 0,
    );

    await db.insertPassRecord(record);

    // If session-based, decrement remaining sessions
    if (member.billingType == BillingType.sessionBased && member.remainingSessions > 0) {
      final updatedMember = member.copyWith(
        remainingSessions: member.remainingSessions - 1,
      );
      await ref.read(membersProvider.notifier).updateMember(updatedMember);
    }

    await reload();
  }

  Future<void> cancelCheckIn({
    required PassRecord record,
    Member? member,
  }) async {
    final db = ref.read(databaseServiceProvider);
    await db.deletePassRecord(record.id);

    // Restore deducted session if applicable
    final deduction = record.sessionDeduction ?? 0;
    if (member != null && member.billingType == BillingType.sessionBased && deduction > 0) {
      final restored = member.copyWith(
        remainingSessions: member.remainingSessions + deduction,
      );
      await ref.read(membersProvider.notifier).updateMember(restored);
    }

    await reload();
  }

  Future<void> batchCheckInAll(List<Member> members) async {
    for (final m in members) {
      await checkInMember(member: m, status: AttendanceStatus.attended);
    }
  }
}

final passRecordsProvider = AsyncNotifierProvider<PassRecordsNotifier, List<PassRecord>>(() {
  return PassRecordsNotifier();
});

// Invoices AsyncNotifier
class InvoicesNotifier extends AsyncNotifier<List<Invoice>> {
  @override
  Future<List<Invoice>> build() async {
    final db = ref.read(databaseServiceProvider);
    return await db.getInvoices();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      return await db.getInvoices();
    });
  }

  Future<void> addInvoice(Invoice invoice) async {
    final db = ref.read(databaseServiceProvider);
    await db.insertInvoice(invoice);
    await reload();
  }

  Future<void> updateInvoice(Invoice invoice) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateInvoice(invoice);
    await reload();
  }

  Future<void> deleteInvoice(String invoiceId) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteInvoice(invoiceId);
    await reload();
  }

  Future<void> markAsPaid({
    required String invoiceId,
    required String paymentMethod,
  }) async {
    final currentInvoices = state.value ?? [];
    final idx = currentInvoices.indexWhere((inv) => inv.id == invoiceId);
    if (idx != -1) {
      final updated = currentInvoices[idx].copyWith(
        status: PaymentStatus.paid,
        paymentMethod: paymentMethod,
        paidAt: DateTime.now(),
      );
      final db = ref.read(databaseServiceProvider);
      await db.updateInvoice(updated);
      await reload();
    }
  }

  Future<void> markAsUnpaid(String invoiceId) async {
    final currentInvoices = state.value ?? [];
    final idx = currentInvoices.indexWhere((inv) => inv.id == invoiceId);
    if (idx != -1) {
      final current = currentInvoices[idx];
      final updated = Invoice(
        id: current.id,
        memberIds: current.memberIds,
        recipientPhone: current.recipientPhone,
        title: current.title,
        amount: current.amount,
        dueDate: current.dueDate,
        status: PaymentStatus.unpaid,
        paymentMethod: null,
        paidAt: null,
        externalOrderId: current.externalOrderId,
      );
      final db = ref.read(databaseServiceProvider);
      await db.updateInvoice(updated);
      await reload();
    }
  }
}

final invoicesProvider = AsyncNotifierProvider<InvoicesNotifier, List<Invoice>>(() {
  return InvoicesNotifier();
});

// Studio Profile AsyncNotifier
class StudioProfileNotifier extends AsyncNotifier<StudioProfile> {
  @override
  Future<StudioProfile> build() async {
    final db = ref.read(databaseServiceProvider);
    return await db.getStudioProfile();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      return await db.getStudioProfile();
    });
  }

  Future<void> updateProfile(StudioProfile profile) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateStudioProfile(profile);
    state = AsyncValue.data(profile);
  }

  Future<void> toggleBankDetect(bool enabled) async {
    final current = state.value;
    if (current != null) {
      final updated = current.copyWith(autoBankDetectEnabled: enabled);
      await updateProfile(updated);
    }
  }
}

final studioProfileProvider = AsyncNotifierProvider<StudioProfileNotifier, StudioProfile>(() {
  return StudioProfileNotifier();
});

// Custom Category Service Provider
final customCategoryServiceProvider = Provider<CustomCategoryService>((ref) {
  return CustomCategoryService.instance;
});

// Custom Category State AsyncNotifier
class CustomCategoryNotifier extends AsyncNotifier<CustomCategoryState> {
  @override
  Future<CustomCategoryState> build() async {
    final studioProfile = await ref.watch(studioProfileProvider.future).catchError((_) => StudioProfile.defaultProfile());
    final service = ref.read(customCategoryServiceProvider);
    return await service.loadCategories(industryCategory: studioProfile.category);
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final studioProfile = await ref.read(studioProfileProvider.future).catchError((_) => StudioProfile.defaultProfile());
      final service = ref.read(customCategoryServiceProvider);
      return await service.loadCategories(industryCategory: studioProfile.category);
    });
  }

  Future<void> addGroupCategory(String group) async {
    final service = ref.read(customCategoryServiceProvider);
    final updated = await service.addGroupCategory(group);
    state = AsyncValue.data(updated);
  }

  Future<void> removeGroupCategory(String group) async {
    final service = ref.read(customCategoryServiceProvider);
    final updated = await service.removeGroupCategory(group);
    state = AsyncValue.data(updated);
  }

  Future<void> saveMemberTemplate(MemberCategoryTemplate template) async {
    final service = ref.read(customCategoryServiceProvider);
    final updated = await service.saveMemberTemplate(template);
    state = AsyncValue.data(updated);
  }

  Future<void> removeMemberTemplate(String id) async {
    final service = ref.read(customCategoryServiceProvider);
    final updated = await service.removeMemberTemplate(id);
    state = AsyncValue.data(updated);
  }

  Future<void> saveInvoiceTemplate(InvoiceItemTemplate template) async {
    final service = ref.read(customCategoryServiceProvider);
    final updated = await service.saveInvoiceTemplate(template);
    state = AsyncValue.data(updated);
  }

  Future<void> removeInvoiceTemplate(String id) async {
    final service = ref.read(customCategoryServiceProvider);
    final updated = await service.removeInvoiceTemplate(id);
    state = AsyncValue.data(updated);
  }

  Future<void> resetToIndustry(String industryCategory) async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final service = ref.read(customCategoryServiceProvider);
      return await service.resetToIndustry(industryCategory);
    });
  }
}

final customCategoryProvider = AsyncNotifierProvider<CustomCategoryNotifier, CustomCategoryState>(() {
  return CustomCategoryNotifier();
});

// Vendors AsyncNotifier (체크인 페이 거래처)
class VendorsNotifier extends AsyncNotifier<List<Vendor>> {
  @override
  Future<List<Vendor>> build() async {
    final db = ref.read(databaseServiceProvider);
    return await db.getVendors();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      return await db.getVendors();
    });
  }

  Future<void> addVendor(Vendor vendor) async {
    final db = ref.read(databaseServiceProvider);
    await db.insertVendor(vendor);
    await reload();
  }

  Future<void> updateVendor(Vendor vendor) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateVendor(vendor);
    await reload();
  }

  Future<void> deleteVendor(String id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteVendor(id);
    await reload();
  }
}

final vendorsProvider = AsyncNotifierProvider<VendorsNotifier, List<Vendor>>(() {
  return VendorsNotifier();
});

// Expenses AsyncNotifier (체크인 페이 지출/매입)
class ExpensesNotifier extends AsyncNotifier<List<ExpenseItem>> {
  @override
  Future<List<ExpenseItem>> build() async {
    final db = ref.read(databaseServiceProvider);
    return await db.getExpenses();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      return await db.getExpenses();
    });
  }

  Future<void> addExpense(ExpenseItem expense) async {
    final db = ref.read(databaseServiceProvider);
    await db.insertExpense(expense);
    await reload();
  }

  Future<void> updateExpense(ExpenseItem expense) async {
    final db = ref.read(databaseServiceProvider);
    await db.updateExpense(expense);
    await reload();
  }

  Future<void> deleteExpense(String id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteExpense(id);
    await reload();
  }

  Future<void> togglePaymentStatus(String id) async {
    final currentList = state.value ?? [];
    final idx = currentList.indexWhere((e) => e.id == id);
    if (idx != -1) {
      final target = currentList[idx];
      final updated = target.copyWith(isPaid: !target.isPaid);
      await updateExpense(updated);
    }
  }
}

final expensesProvider = AsyncNotifierProvider<ExpensesNotifier, List<ExpenseItem>>(() {
  return ExpensesNotifier();
});

// Notification Logs AsyncNotifier
class NotificationLogsNotifier extends AsyncNotifier<List<NotificationLog>> {
  @override
  Future<List<NotificationLog>> build() async {
    final db = ref.read(databaseServiceProvider);
    return await db.getNotificationLogs();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final db = ref.read(databaseServiceProvider);
      return await db.getNotificationLogs();
    });
  }

  Future<void> logNotification({
    required NotificationType type,
    String? memberId,
    required String memberName,
    required String recipientPhone,
    required String channel,
    required String message,
    bool isSuccess = true,
  }) async {
    final db = ref.read(databaseServiceProvider);
    final log = NotificationLog(
      id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${memberId ?? "bulk"}',
      type: type,
      memberId: memberId,
      memberName: memberName,
      recipientPhone: recipientPhone,
      channel: channel,
      message: message,
      sentAt: DateTime.now(),
      isSuccess: isSuccess,
    );
    await db.insertNotificationLog(log);
    await reload();
  }

  Future<void> deleteLog(String id) async {
    final db = ref.read(databaseServiceProvider);
    await db.deleteNotificationLog(id);
    await reload();
  }

  Future<void> clearAll() async {
    final db = ref.read(databaseServiceProvider);
    await db.clearAllNotificationLogs();
    await reload();
  }
}

final notificationLogsProvider =
    AsyncNotifierProvider<NotificationLogsNotifier, List<NotificationLog>>(() {
  return NotificationLogsNotifier();
});

// Senior / Elderly Easy Mode Notifier
class SeniorModeNotifier extends Notifier<bool> {
  static const String keySeniorMode = 'senior_easy_mode_enabled';

  @override
  bool build() {
    _loadFromPrefs();
    return false;
  }

  Future<void> _loadFromPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    state = prefs.getBool(keySeniorMode) ?? false;
  }

  Future<void> toggle() async {
    final prefs = await SharedPreferences.getInstance();
    final next = !state;
    await prefs.setBool(keySeniorMode, next);
    state = next;
  }

  Future<void> setSeniorMode(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(keySeniorMode, enabled);
    state = enabled;
  }
}

final seniorModeProvider = NotifierProvider<SeniorModeNotifier, bool>(() {
  return SeniorModeNotifier();
});

// Studio & Academy Schedules Provider
class SchedulesNotifier extends AsyncNotifier<List<ScheduleItem>> {
  @override
  Future<List<ScheduleItem>> build() async {
    return await ScheduleService.loadSchedules();
  }

  Future<void> reload() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async => await ScheduleService.loadSchedules());
  }

  Future<void> addSchedule(ScheduleItem item) async {
    await ScheduleService.addSchedule(item);
    await reload();
  }

  Future<void> deleteSchedule(String id) async {
    await ScheduleService.deleteSchedule(id);
    await reload();
  }

  Future<void> updateSchedule(ScheduleItem item) async {
    await ScheduleService.updateSchedule(item);
    await reload();
  }
}

final schedulesProvider =
    AsyncNotifierProvider<SchedulesNotifier, List<ScheduleItem>>(() {
  return SchedulesNotifier();
});





// Global Language Notifier
class LanguageNotifier extends Notifier<AppLanguage> {
  @override
  AppLanguage build() {
    _load();
    return LocalizationService.currentLanguage;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(LocalizationService.keySelectedLanguage);
    if (code != null && code.isNotEmpty) {
      final lang = AppLanguage.fromCode(code);
      await LocalizationService.setLanguage(lang, persist: false);
      state = lang;
    }
  }

  Future<void> setLanguage(AppLanguage lang, {bool autoUpdateCurrency = false}) async {
    await LocalizationService.setLanguage(lang, persist: true);
    state = lang;
    if (autoUpdateCurrency) {
      final cur = AppCurrency.defaultForLanguage(lang);
      await ref.read(currencyProvider.notifier).setCurrency(cur);
    }
  }
}

final languageProvider = NotifierProvider<LanguageNotifier, AppLanguage>(() {
  return LanguageNotifier();
});

// Global Currency Policy Notifier
class CurrencyNotifier extends Notifier<AppCurrency> {
  @override
  AppCurrency build() {
    _load();
    return LocalizationService.currentCurrency;
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(LocalizationService.keySelectedCurrency);
    if (code != null && code.isNotEmpty) {
      final cur = AppCurrency.fromCode(code);
      await LocalizationService.setCurrency(cur, persist: false);
      state = cur;
    }
  }

  Future<void> setCurrency(AppCurrency cur) async {
    await LocalizationService.setCurrency(cur, persist: true);
    state = cur;
  }
}

final currencyProvider = NotifierProvider<CurrencyNotifier, AppCurrency>(() {
  return CurrencyNotifier();
});

// Active Locale Provider
final localeProvider = Provider<Locale>((ref) {
  final lang = ref.watch(languageProvider);
  return Locale(lang.code);
});
