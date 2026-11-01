import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/member.dart';
import '../models/invoice.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/chosung_search_service.dart';
import '../services/coach_mark_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coach_mark_dialog.dart';
import '../widgets/digital_pass_card_dialog.dart';

class MemberDirectoryScreen extends ConsumerStatefulWidget {
  const MemberDirectoryScreen({super.key});

  @override
  ConsumerState<MemberDirectoryScreen> createState() => _MemberDirectoryScreenState();
}

class _MemberDirectoryScreenState extends ConsumerState<MemberDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CoachMarkDialog.showIfFirstTime(
        context: context,
        coachKey: CoachMarkService.keyMemberTab,
        title: '수강생(회원) 명부 관리',
        message: '등록된 회원들의 남은 회차와 수업 그룹, 출결 이력을 한눈에 볼 수 있는 공간이에요.\n\n새로운 학생이나 회원이 등록하면 언제든 우측 하단 [+ 회원 등록]으로 10초 만에 추가하세요!',
        tip: '회원 카드를 터치하면 출결 타임라인 확인, 회차 충전(+10회), 청구서 즉시 발송이 가능해요.',
        buttonText: '회원 명부 둘러보기',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final studio = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('회원 명부 관리'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '회원 등록 & 이용 팁',
            onPressed: () {
              showDialog(
                context: context,
                builder: (c) => AlertDialog(
                  title: const Text('회원 관리 및 데이터 안내'),
                  content: const SingleChildScrollView(
                    child: Text(
                      '1. 우측 하단의 [+ 신규 회원 등록] 버튼으로 실제 운영하시는 학생/회원 정보를 바로 추가할 수 있습니다.\n'
                      '2. 회차권(예: 10회권)과 월 정기권(매월 자동) 중 매장 운영 방식에 맞춰 선택할 수 있습니다.\n'
                      '3. 연습용 샘플 데이터는 [설정·보안] 탭에서 언제든지 깨끗하게 비우거나 다시 채울 수 있습니다.',
                      style: TextStyle(height: 1.5, fontSize: 13),
                    ),
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(c), child: const Text('확인')),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('회원 로딩 오류: $err')),
        data: (members) {
          final filtered = members.where((m) {
            if (_searchQuery.isEmpty) return true;
            return ChosungSearchService.matchesAny(
              [m.name, m.phone, m.groupName, m.payerName, m.memo],
              _searchQuery,
            );
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
                      hintText: '이름, 초성(ㄱㄷㅎ), 연락처, 그룹명 검색',
                      hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue, size: 21),
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
                          return _buildMemberTile(context, member, studio);
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_member',
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

  Widget _buildMemberTile(BuildContext context, Member member, StudioProfile studio) {
    final initials = member.name.isNotEmpty ? member.name.substring(0, 1) : '?';
    final isSession = member.billingType == BillingType.sessionBased;
    final isExpiring = isSession && member.remainingSessions <= 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () => _openMemberDetailSheet(context, member),
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Section: Avatar + Name, Group, and Digital Pass Card Button
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.chipBackground,
                      border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                    ),
                    child: ClipOval(
                      child: member.photoPath != null &&
                              member.photoPath!.isNotEmpty &&
                              File(member.photoPath!).existsSync()
                          ? Image.file(
                              File(member.photoPath!),
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                            )
                          : Center(
                              child: Text(
                                initials,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.primaryDark,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: AppTheme.chipBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            member.groupName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      DigitalPassCardDialog.show(
                        context: context,
                        member: member,
                        studio: studio,
                      );
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.badge_outlined, size: 13, color: AppTheme.primaryBlue),
                          SizedBox(width: 4),
                          Text(
                            '패스',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // 2. Bottom Section: Phone, Registration date, and Pass Type badge
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.phone_iphone_outlined, size: 14, color: AppTheme.textSecondary),
                          const SizedBox(width: 4),
                          Text(
                            member.phone,
                            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      Text(
                        '•  등록 ${DateFormat("yy.MM.dd").format(member.registeredAt)}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textTertiary),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
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
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openMemberDetailSheet(BuildContext context, Member member) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.88,
      builder: (ctx) => _MemberDetailModal(memberId: member.id),
    );
  }

  void _openAddMemberDialog(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
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

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => _updatePhoto(context, ref, member),
                      child: Stack(
                        children: [
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppTheme.chipBackground,
                              border: Border.all(color: AppTheme.borderSubtle, width: 1.2),
                            ),
                            child: ClipOval(
                              child: member.photoPath != null &&
                                      member.photoPath!.isNotEmpty &&
                                      File(member.photoPath!).existsSync()
                                  ? Image.file(
                                      File(member.photoPath!),
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                    )
                                  : Center(
                                      child: Text(
                                        member.name.isNotEmpty ? member.name.substring(0, 1) : '?',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.primaryDark,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(3),
                              decoration: const BoxDecoration(
                                color: AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.camera_alt, size: 10, color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${member.groupName} • ${member.phone}${member.payerName != null && member.payerName!.isNotEmpty ? ' (입금자: ${member.payerName})' : ''}',
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
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
                    label: const FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('+10회 충전'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text('청구서 즉시 발송'),
                  ),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
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

  Future<void> _updatePhoto(BuildContext context, WidgetRef ref, Member member) async {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            Text('${member.name} 사진 관리', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryBlue),
              title: const Text('카메라로 직접 촬영'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.camera, imageQuality: 85, maxWidth: 800);
                if (picked != null) {
                  final appDir = await getApplicationDocumentsDirectory();
                  final fileName = 'member_${member.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');
                  await ref.read(membersProvider.notifier).updateMember(member.copyWith(photoPath: savedImage.path));
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.softMint),
              title: const Text('갤러리에서 사진 선택'),
              onTap: () async {
                Navigator.pop(ctx);
                final picker = ImagePicker();
                final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
                if (picked != null) {
                  final appDir = await getApplicationDocumentsDirectory();
                  final fileName = 'member_${member.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
                  final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');
                  await ref.read(membersProvider.notifier).updateMember(member.copyWith(photoPath: savedImage.path));
                }
              },
            ),
            if (member.photoPath != null && member.photoPath!.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: const Text('등록된 사진 삭제', style: TextStyle(color: AppTheme.danger)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await ref.read(membersProvider.notifier).updateMember(member.copyWith(photoPath: ''));
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
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
  final _payerNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _groupController = TextEditingController(text: '일반 클래스');
  final _feeController = TextEditingController(text: '300000');
  final _sessionsController = TextEditingController(text: '10');
  final _memoController = TextEditingController();

  BillingType _billingType = BillingType.sessionBased;
  String? _photoPath;

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85, maxWidth: 800);
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'member_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');

      setState(() {
        _photoPath = savedImage.path;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('사진 등록 실패: $e')),
        );
      }
    }
  }

  void _showPhotoOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
            const SizedBox(height: 16),
            const Text('회원 사진 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryBlue),
              title: const Text('카메라로 직접 촬영'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.softMint),
              title: const Text('갤러리에서 사진 선택'),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: const Text('등록된 사진 삭제', style: TextStyle(color: AppTheme.danger)),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photoPath = null);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
              const SizedBox(height: 14),

              // Member Photo Picker Avatar
              Center(
                child: GestureDetector(
                  onTap: _showPhotoOptions,
                  child: Stack(
                    children: [
                      Container(
                        width: 82,
                        height: 82,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFF1F5F9),
                          border: Border.all(color: AppTheme.borderSubtle, width: 1.5),
                        ),
                        child: ClipOval(
                          child: _photoPath != null && File(_photoPath!).existsSync()
                              ? Image.file(
                                  File(_photoPath!),
                                  width: 82,
                                  height: 82,
                                  fit: BoxFit.cover,
                                )
                              : const Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.add_a_photo_rounded, size: 28, color: AppTheme.primaryBlue),
                                    SizedBox(height: 2),
                                    Text(
                                      '사진 등록',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryBlue,
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            color: AppTheme.primaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            _photoPath != null ? Icons.edit : Icons.add,
                            size: 14,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              const Center(
                child: Text(
                  '등록된 사진은 키오스크 출석 체크 시 전면에 표시됩니다',
                  style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              AppTextField(
                controller: _nameController,
                label: '회원/학생 이름',
                hint: '예: 김하늘',
                prefixIcon: Icons.badge_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? '이름을 입력하세요' : null,
              ),
              const SizedBox(height: 12),

              // Payer Name (Parent / Actual Depositor for 100% Bank Auto Matching)
              AppTextField(
                controller: _payerNameController,
                label: '입금자 성함 (학부모 / 보호자명)',
                hint: '학생명과 다를 경우 입력 (예: 이영희)',
                prefixIcon: Icons.family_restroom_outlined,
                helperText: '은행 푸시 알림 수신 시 100% 자동 매칭됩니다',
              ),
              const SizedBox(height: 12),

              // Phone
              AppTextField(
                controller: _phoneController,
                label: '연락처 (안심 알림·청구 문자용)',
                hint: '예: 010-1234-5678',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 10) ? '유효한 번호를 입력하세요' : null,
              ),
              const SizedBox(height: 14),

              // Multi-Industry Quick Selection Chips
              const Text('업종별 간편 템플릿', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildIndustryChip('보습·입시', '중등수학 정규반', BillingType.monthlyRecurring, 350000, 0),
                    _buildIndustryChip('음악·피아노', '피아노 클래식반', BillingType.monthlyRecurring, 180000, 0),
                    _buildIndustryChip('미술·도예공방', '도예 정규반', BillingType.sessionBased, 240000, 4),
                    _buildIndustryChip('PT·필라테스', '1:1 기구필라테스', BillingType.sessionBased, 700000, 10),
                    _buildIndustryChip('태권도·체육관', '유소년 태권도', BillingType.monthlyRecurring, 160000, 0),
                    _buildIndustryChip('댄스·보컬레슨', '보컬 1:1 레슨', BillingType.sessionBased, 320000, 4),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Group
              AppTextField(
                controller: _groupController,
                label: '수업 / 클래스 그룹',
                hint: '예: 중등수학, 기구필라테스, 도예반',
                prefixIcon: Icons.group_outlined,
              ),
              const SizedBox(height: 14),

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
              const SizedBox(height: 14),

              // Default Fee & Sessions
              Row(
                children: [
                  Expanded(
                    child: AppTextField(
                      controller: _feeController,
                      label: '수강료 (원)',
                      hint: '300000',
                      prefixIcon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  if (_billingType == BillingType.sessionBased) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppTextField(
                        controller: _sessionsController,
                        label: '총 등록 회차',
                        hint: '10',
                        prefixIcon: Icons.confirmation_number_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              // Memo
              AppTextField(
                controller: _memoController,
                label: '운영자 메모 (비공개 로컬 보관)',
                hint: '회원 특이사항, 목표 등',
                prefixIcon: Icons.note_alt_outlined,
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
                        payerName: _payerNameController.text.trim().isNotEmpty ? _payerNameController.text.trim() : null,
                        registeredAt: DateTime.now(),
                        photoPath: _photoPath,
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

  Widget _buildIndustryChip(String label, String group, BillingType type, int fee, int sessions) {
    final isSelected = _groupController.text == group;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (val) {
          setState(() {
            _groupController.text = group;
            _billingType = type;
            _feeController.text = fee.toString();
            if (type == BillingType.sessionBased) {
              _sessionsController.text = sessions.toString();
            }
          });
        },
        selectedColor: AppTheme.primaryDark,
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? Colors.white : AppTheme.textPrimary,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
