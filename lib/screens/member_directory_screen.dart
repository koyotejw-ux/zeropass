import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/member.dart';
import '../models/invoice.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';

class MemberDirectoryScreen extends ConsumerStatefulWidget {
  const MemberDirectoryScreen({super.key});

  @override
  ConsumerState<MemberDirectoryScreen> createState() => _MemberDirectoryScreenState();
}

class _MemberDirectoryScreenState extends ConsumerState<MemberDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('회원 명부 관리'),
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('회원 로딩 오류: $err')),
        data: (members) {
          final filtered = members.where((m) {
            if (_searchQuery.isEmpty) return true;
            final q = _searchQuery.toLowerCase();
            return m.name.toLowerCase().contains(q) ||
                m.phone.contains(q) ||
                m.groupName.toLowerCase().contains(q);
          }).toList();

          return Column(
            children: [
              // Search Input Bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: '이름, 연락처, 그룹명으로 검색',
                      hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),

              // Total count badge
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      '등록 회원 총 ${filtered.length}명',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Member List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_search_outlined, size: 48, color: AppTheme.textTertiary),
                            const SizedBox(height: 12),
                            const Text(
                              '검색 결과와 일치하는 회원이 없습니다',
                              style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(18, 6, 18, 90),
                        itemCount: filtered.length,
                        itemBuilder: (context, index) {
                          final member = filtered[index];
                          return _buildMemberTile(context, member);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openAddMemberDialog(context),
        backgroundColor: AppTheme.primaryDark,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text(
          '신규 회원 등록',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, Member member) {
    final initials = member.name.isNotEmpty ? member.name.substring(0, 1) : '?';
    final isSession = member.billingType == BillingType.sessionBased;
    final isExpiring = isSession && member.remainingSessions <= 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        onTap: () => _openMemberDetailSheet(context, member),
        leading: CircleAvatar(
          radius: 22,
          backgroundColor: AppTheme.chipBackground,
          child: Text(
            initials,
            style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                member.name,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.chipBackground,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                member.groupName,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            '${member.phone} • 등록: ${DateFormat('yyyy.MM.dd').format(member.registeredAt)}',
            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: isSession
                ? (isExpiring
                    ? AppTheme.danger.withAlpha((255 * 0.12).round())
                    : AppTheme.primaryBlue.withAlpha((255 * 0.1).round()))
                : AppTheme.softMint.withAlpha((255 * 0.12).round()),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            isSession ? '${member.remainingSessions}/${member.totalSessions}회' : '정기권',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSession ? (isExpiring ? AppTheme.danger : AppTheme.primaryBlue) : AppTheme.softMint,
            ),
          ),
        ),
      ),
    );
  }

  void _openMemberDetailSheet(BuildContext context, Member member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _MemberDetailModal(memberId: member.id),
    );
  }

  void _openAddMemberDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const _AddMemberModal(),
    );
  }
}

class _MemberDetailModal extends ConsumerWidget {
  final String memberId;
  const _MemberDetailModal({required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(membersProvider).value ?? [];
    final passRecords = ref.watch(passRecordsProvider).value ?? [];
    final invoices = ref.watch(invoicesProvider).value ?? [];
    final studio = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();

    final memberIndex = members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) return const SizedBox();
    final member = members[memberIndex];

    final memberPasses = passRecords.where((p) => p.memberId == member.id).toList();
    final memberInvoices = invoices.where((i) => i.memberIds.contains(member.id)).toList();
    final currency = NumberFormat('#,###');

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    member.name,
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${member.groupName} • ${member.phone}',
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Shortcut Action Buttons
          Row(
            children: [
              if (member.billingType == BillingType.sessionBased)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(membersProvider.notifier).addSessions(member.id, 10);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${member.name} 잔여 회차 10회가 추가되었습니다.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.add, size: 16, color: Colors.white),
                    label: const Text('+10회 충전'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              if (member.billingType == BillingType.sessionBased) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    // Create invoice on the fly
                    final invoice = Invoice(
                      id: 'inv_${const Uuid().v4().substring(0, 8)}',
                      memberIds: [member.id],
                      recipientPhone: member.phone,
                      title: '${member.name.split(' ').first} 수강 패스 재등록 안내',
                      amount: member.defaultFee,
                      dueDate: DateTime.now().add(const Duration(days: 5)),
                      status: PaymentStatus.unpaid,
                    );
                    await ref.read(invoicesProvider.notifier).addInvoice(invoice);
                    final message = SmsTemplateService.generateInvoiceMessage(
                      studio: studio,
                      members: [member],
                      invoice: invoice,
                    );
                    await SmsTemplateService.launchNativeSms(
                      recipientPhone: member.phone,
                      body: message,
                    );
                  },
                  icon: const Icon(Icons.send_outlined, size: 16),
                  label: const Text('청구서 즉시 발송'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Timeline Tabs: Pass Attendance vs Payment History
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  const TabBar(
                    labelColor: AppTheme.primaryBlue,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primaryBlue,
                    tabs: [
                      Tab(text: '출석 기록 타임라인'),
                      Tab(text: '수납 내역 로그'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Attendance List
                        memberPasses.isEmpty
                            ? const Center(child: Text('출석 기록이 없습니다.'))
                            : ListView.builder(
                                itemCount: memberPasses.length,
                                itemBuilder: (ctx, i) {
                                  final p = memberPasses[i];
                                  return ListTile(
                                    leading: const Icon(Icons.check_circle, color: AppTheme.softMint),
                                    title: Text(DateFormat('yyyy.MM.dd HH:mm').format(p.timestamp)),
                                    subtitle: Text(p.status == AttendanceStatus.attended ? '출석 완료' : '지각/보강'),
                                    trailing: p.sessionDeduction != null && p.sessionDeduction! > 0
                                        ? const Text('-1회 차감', style: TextStyle(color: AppTheme.danger, fontWeight: FontWeight.bold))
                                        : null,
                                  );
                                },
                              ),

                        // Invoices List
                        memberInvoices.isEmpty
                            ? const Center(child: Text('청구 내역이 없습니다.'))
                            : ListView.builder(
                                itemCount: memberInvoices.length,
                                itemBuilder: (ctx, i) {
                                  final inv = memberInvoices[i];
                                  return ListTile(
                                    leading: Icon(
                                      inv.status == PaymentStatus.paid ? Icons.done_all : Icons.pending_outlined,
                                      color: inv.status == PaymentStatus.paid ? AppTheme.softMint : AppTheme.warning,
                                    ),
                                    title: Text(inv.title),
                                    subtitle: Text('기한: ${DateFormat('yyyy.MM.dd').format(inv.dueDate)}'),
                                    trailing: Text(
                                      '${currency.format(inv.amount)}원',
                                      style: const TextStyle(fontWeight: FontWeight.w700),
                                    ),
                                  );
                                },
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddMemberModal extends ConsumerStatefulWidget {
  const _AddMemberModal();

  @override
  ConsumerState<_AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends ConsumerState<_AddMemberModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _groupController = TextEditingController(text: '일반 클래스');
  final _feeController = TextEditingController(text: '300000');
  final _sessionsController = TextEditingController(text: '10');
  final _memoController = TextEditingController();

  BillingType _billingType = BillingType.sessionBased;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '신규 회원 등록',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Name
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: '회원 이름 (예: 김하늘)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
              ),
              const SizedBox(height: 10),

              // Phone
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: '연락처 (01012345678)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().length < 10) ? '유효한 번호를 입력하세요' : null,
              ),
              const SizedBox(height: 10),

              // Group
              TextFormField(
                controller: _groupController,
                decoration: InputDecoration(
                  labelText: '그룹/반 명 (예: 중등수학, 기구필라테스, PT반)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),

              // Billing Type Segmented
              const Text('패스 수강 유형', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              SegmentedButton<BillingType>(
                segments: const [
                  ButtonSegment(
                    value: BillingType.sessionBased,
                    label: Text('회차 차감형 (PT/레슨)'),
                  ),
                  ButtonSegment(
                    value: BillingType.monthlyRecurring,
                    label: Text('정기 결제형 (학원/월정액)'),
                  ),
                ],
                selected: {_billingType},
                onSelectionChanged: (val) {
                  setState(() => _billingType = val.first);
                },
              ),
              const SizedBox(height: 12),

              // Default Fee & Sessions
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _feeController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: '수강료 (원)',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  if (_billingType == BillingType.sessionBased) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextFormField(
                        controller: _sessionsController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: '총 등록 회차',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),

              // Memo
              TextFormField(
                controller: _memoController,
                decoration: InputDecoration(
                  labelText: '운영자 메모 (비공개 로컬 보관)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),

              // Submit
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_formKey.currentState!.validate()) {
                      final fee = int.tryParse(_feeController.text.replaceAll(',', '')) ?? 0;
                      final totalSessions = int.tryParse(_sessionsController.text) ?? 10;

                      final newMember = Member(
                        id: 'mem_${const Uuid().v4().substring(0, 8)}',
                        name: _nameController.text.trim(),
                        phone: _phoneController.text.trim(),
                        groupName: _groupController.text.trim(),
                        billingType: _billingType,
                        defaultFee: fee,
                        totalSessions: _billingType == BillingType.sessionBased ? totalSessions : 0,
                        remainingSessions: _billingType == BillingType.sessionBased ? totalSessions : 0,
                        memo: _memoController.text.trim(),
                        registeredAt: DateTime.now(),
                      );

                      ref.read(membersProvider.notifier).addMember(newMember);
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${newMember.name} 회원이 등록되었습니다.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('회원 등록 완료', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
