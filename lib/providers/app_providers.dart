import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/invoice.dart';
import '../models/studio_profile.dart';
import '../services/database_service.dart';

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
      id: 'pass_${DateTime.now().millisecondsSinceEpoch}',
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
