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
import '../models/custom_category_template.dart';
import '../providers/app_providers.dart';
import '../services/chosung_search_service.dart';
import '../services/coach_mark_service.dart';
import '../services/data_vault_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coach_mark_dialog.dart';
import '../widgets/design_system.dart';
import '../widgets/member_name_badge.dart';
import '../widgets/native_inline_ad_card.dart';
import '../widgets/sequential_dispatch_modal.dart';

class MemberDirectoryScreen extends ConsumerStatefulWidget {
  final bool enableAutoCoachMark;

  const MemberDirectoryScreen({
    super.key,
    this.enableAutoCoachMark = true,
  });

  @override
  ConsumerState<MemberDirectoryScreen> createState() => _MemberDirectoryScreenState();
}

class _MemberDirectoryScreenState extends ConsumerState<MemberDirectoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedGroupFilter = '전체';

  @override
  void initState() {
    super.initState();
    if (widget.enableAutoCoachMark) {
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
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final studio = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();
    final isSeniorMode = ref.watch(seniorModeProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('회원 명부 관리'),
        ),
        actions: [
          // 1. 순차 릴레이 단체발송 마법사 (심플 라인 아이콘)
          IconButton(
            icon: const Icon(Icons.mark_chat_unread_outlined, size: 22, color: AppTheme.textPrimary),
            tooltip: '순차 릴레이 발송',
            splashRadius: 20,
            onPressed: () {
              final members = membersAsync.value ?? [];
              if (members.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('등록된 회원이 없습니다.')),
                );
                return;
              }
              final invoices = ref.read(invoicesProvider).value ?? [];
              SequentialDispatchModal.show(
                context: context,
                allMembers: members,
                studio: studio,
                invoices: invoices,
              );
            },
          ),
          // 2. 회원 명부 엑셀(CSV) 내보내기 (심플 라인 아이콘)
          IconButton(
            icon: const Icon(Icons.file_download_outlined, size: 22, color: AppTheme.textPrimary),
            tooltip: '명부 엑셀 내보내기',
            splashRadius: 20,
            onPressed: () async {
              final members = membersAsync.value ?? [];
              if (members.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('내보낼 등록 회원이 없습니다.')),
                );
                return;
              }
              try {
                final file = await DataVaultService.exportMembersCsv();
                await DataVaultService.shareMembersCsv(file);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('CSV 내보내기 오류: $e')),
                  );
                }
              }
            },
          ),
          // 3. 시니어 큰글씨 모드 퀵 토글 (공통 규격: 가장 우측 배치)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: Icon(
                Icons.format_size_rounded,
                size: 22,
                color: isSeniorMode ? AppTheme.trustBlue : const Color(0xFF3F3F46),
              ),
              tooltip: '큰글씨 모드',
              splashRadius: 20,
              onPressed: () => ref.read(seniorModeProvider.notifier).toggle(),
            ),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('회원 로딩 오류: $err')),
        data: (members) {
          final allGroups = ['전체', ...members.map((m) => m.groupName).where((g) => g.trim().isNotEmpty).toSet()];
          final filtered = members.where((m) {
            if (_selectedGroupFilter != '전체' && m.groupName != _selectedGroupFilter) {
              return false;
            }
            if (_searchQuery.isEmpty) return true;
            return ChosungSearchService.matchesAny(
              [m.name, m.phone, m.groupName, m.payerName, m.memo],
              _searchQuery,
            );
          }).toList();

          return CustomScrollView(
            slivers: [
              // 1. Pinned Sticky Search and Group Filter Header
              SliverPersistentHeader(
                pinned: true,
                delegate: _StickyMemberSearchAndFilterDelegate(
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                  onSearchClear: () {
                    _searchController.clear();
                    setState(() => _searchQuery = '');
                  },
                  allGroups: allGroups,
                  selectedGroupFilter: _selectedGroupFilter,
                  onGroupSelected: (grp) => setState(() => _selectedGroupFilter = grp),
                  totalCount: filtered.length,
                  onSequentialDispatch: () {
                    final invoices = ref.read(invoicesProvider).value ?? [];
                    SequentialDispatchModal.show(
                      context: context,
                      allMembers: filtered,
                      studio: studio,
                      invoices: invoices,
                    );
                  },
                ),
              ),

              // 2. Member List or Empty State
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.person_search_outlined, size: 48, color: AppTheme.textTertiary),
                        const SizedBox(height: 12),
                        const Text(
                          '검색 결과와 일치하는 회원이 없습니다',
                          style: TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 90),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        if (index == filtered.length) {
                          return const NativeInlineAdCard(placementTag: 'member_list');
                        }
                        final member = filtered[index];
                        return _buildMemberTile(context, member, studio);
                      },
                      childCount: filtered.length + 1,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_member',
        onPressed: () => _openAddMemberDialog(context),
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.person_add_alt_1, color: Colors.white),
        label: const Text(
          '신규 회원 등록',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, Member member, StudioProfile studio) {
    final isSession = member.billingType == BillingType.sessionBased;
    final isExpiring = isSession && member.remainingSessions <= 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isExpiring ? const Color(0xFFFECACA) : const Color(0xFFE2E8F0),
          width: isExpiring ? 1.2 : 0.8,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: InkWell(
        onTap: () => _openMemberDetailSheet(context, member),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Meta Row: Course & Group (Left) <-> Remaining Sessions / Pass Badge (Right)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        [
                          if (member.secondaryTag != null && member.secondaryTag!.isNotEmpty) member.secondaryTag!,
                          if (member.groupName.isNotEmpty) member.groupName,
                          if ((member.secondaryTag == null || member.secondaryTag!.isEmpty) && member.groupName.isEmpty) '일반 회원',
                        ].join(' · '),
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF475569),
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  isSession
                      ? (isExpiring
                          ? ZeroBadge.danger('${member.remainingSessions}/${member.totalSessions}회', size: ZeroBadgeSize.medium)
                          : ZeroBadge.primary('${member.remainingSessions}/${member.totalSessions}회', size: ZeroBadgeSize.medium))
                      : ZeroBadge.neutral('정기권', size: ZeroBadgeSize.medium),
                ],
              ),

              const SizedBox(height: 9),

              // 2. Member Name (UNCONSTRAINED FULL WIDTH) & Phone & Chevron
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ZeroAvatar(
                    name: member.name,
                    size: ZeroAvatarSize.medium,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      member.primaryName,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 16.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    member.phone,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
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
                                        member.initial,
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
                          MemberNameBadge(
                            member: member,
                            nameStyle: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
                            ),
                            showGroupName: false,
                          ),
                          const SizedBox(height: 2),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.chipBackground,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  member.groupName,
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.phone_outlined, size: 12, color: AppTheme.textSecondary),
                                  const SizedBox(width: 3),
                                  Text(
                                    member.phone,
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                              if (member.payerName != null && member.payerName!.isNotEmpty)
                                Text(
                                  '(입금자: ${member.payerName})',
                                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textTertiary),
                                ),
                            ],
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

          // Shortcut Action Buttons (Standardized ZeroButtons)
          Row(
            children: [
              if (member.billingType == BillingType.sessionBased)
                Expanded(
                  child: ZeroButton.primary(
                    label: '+10회 충전',
                    icon: Icons.add,
                    fullWidth: true,
                    size: ZeroButtonSize.large,
                    onPressed: () {
                      ref.read(membersProvider.notifier).addSessions(member.id, 10);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${member.primaryName} 잔여 회차 10회가 추가되었습니다.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                  ),
                ),
              if (member.billingType == BillingType.sessionBased) const SizedBox(width: 8),
              Expanded(
                child: ZeroButton.secondary(
                  label: '청구서 즉시 발송',
                  icon: Icons.send_outlined,
                  fullWidth: true,
                  size: ZeroButtonSize.large,
                  onPressed: () async {
                    // Create invoice on the fly
                    final invoice = Invoice(
                      id: 'inv_${const Uuid().v4().substring(0, 8)}',
                      memberIds: [member.id],
                      recipientPhone: member.phone,
                      title: '${member.primaryName} 수강 패스 재등록 안내',
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
        child: SingleChildScrollView(
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
        child: SingleChildScrollView(
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final customCatAsync = ref.watch(customCategoryProvider);
    final customCatState = customCatAsync.value ??
        CustomCategoryState.getDefaultsForIndustry('입시 / 보습학원');

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

              // Multi-Industry Quick Selection Templates
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('업종별 간편 템플릿 (원터치 자동 입력)',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                  Text('${customCatState.memberTemplates.length}개 서식',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                ],
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: customCatState.memberTemplates.map((template) {
                    final isSelected = _groupController.text == template.groupName &&
                        _billingType == template.billingType;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: Icon(
                          template.billingType == BillingType.sessionBased
                              ? Icons.confirmation_number_outlined
                              : Icons.calendar_month_outlined,
                          size: 14,
                          color: isSelected ? Colors.white : AppTheme.primaryBlue,
                        ),
                        label: Text(
                          template.label.contains('만')
                              ? template.label
                              : '${template.label} (${template.defaultFee ~/ 10000}만)',
                        ),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryDark,
                        labelStyle: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (val) {
                          setState(() {
                            _groupController.text = template.groupName;
                            _billingType = template.billingType;
                            _feeController.text = template.defaultFee.toString();
                            if (template.billingType == BillingType.sessionBased) {
                              _sessionsController.text = template.defaultSessions.toString();
                            }
                          });
                        },
                      ),
                    );
                  }).toList(),
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
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...customCatState.groupCategories.map((group) {
                      final isSelected = _groupController.text == group;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(group),
                          selected: isSelected,
                          selectedColor: AppTheme.primaryDark,
                          labelStyle: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : AppTheme.textPrimary,
                          ),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          onSelected: (val) {
                            if (val) setState(() => _groupController.text = group);
                          },
                        ),
                      );
                    }),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 14, color: AppTheme.primaryBlue),
                      label: const Text('새 그룹 추가',
                          style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      backgroundColor: const Color(0xFFEFF6FF),
                      side: const BorderSide(color: Color(0xFFBFDBFE)),
                      onPressed: () => _showQuickAddGroupDialog(context),
                    ),
                  ],
                ),
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

              // Default Fee & Sessions (Responsive side-by-side or stacked)
              LayoutBuilder(
                builder: (context, constraints) {
                  final isCompact = constraints.maxWidth < 320;
                  if (isCompact && _billingType == BillingType.sessionBased) {
                    return Column(
                      children: [
                        AppTextField(
                          controller: _feeController,
                          label: '수강료 (원)',
                          hint: '300000',
                          prefixIcon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _sessionsController,
                          label: '총 등록 회차',
                          hint: '10',
                          prefixIcon: Icons.confirmation_number_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ],
                    );
                  }
                  return Row(
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
                  );
                },
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

  void _showQuickAddGroupDialog(BuildContext context) {
    final groupInputCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('새 수업/그룹 등록', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: AppTextField(
          controller: groupInputCtrl,
          label: '그룹 이름',
          hint: '예: 고등 내신반, 1:1 기구필라',
          prefixIcon: Icons.group_add_outlined,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dlgCtx), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              final name = groupInputCtrl.text.trim();
              if (name.isNotEmpty) {
                await ref.read(customCategoryProvider.notifier).addGroupCategory(name);
                setState(() => _groupController.text = name);
                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
            child: const Text('추가 및 선택', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}

/// Sticky Pinned Header Delegate for Member Search and Group Filter Chips
class _StickyMemberSearchAndFilterDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final List<String> allGroups;
  final String selectedGroupFilter;
  final ValueChanged<String> onGroupSelected;
  final int totalCount;
  final VoidCallback onSequentialDispatch;

  const _StickyMemberSearchAndFilterDelegate({
    required this.searchController,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.allGroups,
    required this.selectedGroupFilter,
    required this.onGroupSelected,
    required this.totalCount,
    required this.onSequentialDispatch,
  });

  bool get hasGroups => allGroups.length > 1;
  double get extent => hasGroups ? 122.0 : 86.0;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: extent,
      child: Container(
        color: AppTheme.background,
        child: Column(
          children: [
            // Search Input Bar (height 52)
            SizedBox(
              height: 52,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 4),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderSubtle, width: 0.9),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: TextField(
                    controller: searchController,
                    onChanged: onSearchChanged,
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: '이름, 초성(ㄱㄷㅎ), 연락처, 그룹명 검색',
                      hintStyle: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                      prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue, size: 19),
                      suffixIcon: searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 16),
                              onPressed: onSearchClear,
                            )
                          : null,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                    ),
                  ),
                ),
              ),
            ),

            // Group Filter Chips (height 36 if present)
            if (hasGroups)
              SizedBox(
                height: 36,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  itemCount: allGroups.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 6),
                  itemBuilder: (context, idx) {
                    final grp = allGroups[idx];
                    final isSelected = selectedGroupFilter == grp;
                    return ZeroFilterChip(
                      label: grp,
                      isSelected: isSelected,
                      onTap: () => onGroupSelected(grp),
                    );
                  },
                ),
              ),

            // Total count badge & Quick batch action (height 34)
            SizedBox(
              height: 34,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      '등록 회원 총 $totalCount명',
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    InkWell(
                      onTap: onSequentialDispatch,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.send_rounded, size: 11.5, color: Color(0xFF475569)),
                            SizedBox(width: 4),
                            Text(
                              '순차 릴레이 발송',
                              style: TextStyle(
                                fontFamily: 'Pretendard',
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF334155),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickyMemberSearchAndFilterDelegate oldDelegate) {
    return oldDelegate.searchQuery != searchQuery ||
        oldDelegate.selectedGroupFilter != selectedGroupFilter ||
        oldDelegate.allGroups.length != allGroups.length ||
        oldDelegate.totalCount != totalCount;
  }
}

