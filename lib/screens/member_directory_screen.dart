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
import '../services/localization_service.dart';
import '../services/monetization_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coach_mark_dialog.dart';
import '../widgets/design_system.dart';
import '../widgets/member_name_badge.dart';
import '../widgets/native_inline_ad_card.dart';
import '../widgets/sequential_dispatch_modal.dart';

String _formatPhone(String raw) {
  final clean = raw.replaceAll(RegExp(r'\D'), '');
  if (clean.length == 11) {
    return '${clean.substring(0, 3)}-${clean.substring(3, 7)}-${clean.substring(7)}';
  } else if (clean.length == 10) {
    if (clean.startsWith('02')) {
      return '${clean.substring(0, 2)}-${clean.substring(2, 6)}-${clean.substring(6)}';
    }
    return '${clean.substring(0, 3)}-${clean.substring(3, 6)}-${clean.substring(6)}';
  }
  return raw;
}

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
          title: LocalizationService.tr('tab_members'),
          message: LocalizationService.pick(
            ko: '등록된 회원들의 남은 회차와 수업 그룹, 출결 이력을 한눈에 볼 수 있는 공간이에요.\n\n새로운 학생이나 회원이 등록하면 언제든 우측 하단 [+ 회원 등록]으로 10초 만에 추가하세요!',
            en: 'View remaining sessions, classes, and attendance history for all members.\n\nTap the bottom-right button to register a new member anytime!',
            ja: '登録会員の残回数・クラス・出席履歴を一覧で確認できます。\n\n右下の追加ボタンから10秒で新規登録できます！',
            zh: '在这里可一站查看会员剩余课时、班级及考勤记录。\n\n点击右下角按钮即可10秒快速添加新会员！',
            vi: 'Xem số buổi còn lại, nhóm lớp và lịch sử điểm danh.\n\nNhấn nút góc dưới bên phải để thêm học viên mới!',
            es: 'Consulta sesiones restantes, grupos e historial de asistencia.\n\nPulsa el botón inferior derecho para registrar nuevos miembros.',
          ),
          tip: LocalizationService.pick(
            ko: '회원 카드를 터치하면 출결 타임라인 확인, 회차 충전(+10회), 청구서 즉시 발송이 가능해요.',
            en: 'Tap any member card for timeline history, +10 top-ups, and instant invoicing.',
            ja: '会員カードをタップすると出席履歴や回数追加、請求書送信が行えます。',
            zh: '点击会员卡片即可查看考勤时间轴、快速充次或立即开单。',
            vi: 'Chạm thẻ học viên để xem lịch sử, nạp thêm buổi và gửi hóa đơn.',
            es: 'Toca cualquier tarjeta para ver el historial, recargar sesiones o facturar.',
          ),
          buttonText: LocalizationService.tr('common_confirm'),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    ref.watch(currencyProvider);
    final membersAsync = ref.watch(membersProvider);
    final studio = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();
    final isSeniorMode = ref.watch(seniorModeProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(LocalizationService.tr('tab_members')),
        ),
        actions: [
          // 1. 순차 릴레이 단체발송 마법사 (심플 라인 아이콘)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.mark_chat_unread_outlined, size: 21, color: AppTheme.textPrimary),
              tooltip: LocalizationService.tr('sequential_dispatch_btn'),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                final members = membersAsync.value ?? [];
                if (members.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(LocalizationService.tr('kiosk_empty_title'))),
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
          ),
          // 2. 회원 명부 엑셀(CSV) 내보내기 (심플 라인 아이콘)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.file_download_outlined, size: 21, color: AppTheme.textPrimary),
              tooltip: LocalizationService.pick(
                ko: '명부 엑셀 내보내기',
                en: 'Export Roster CSV',
                ja: '名簿CSV出力',
                zh: '导出会员名单 CSV',
                vi: 'Xuất danh sách CSV',
                es: 'Exportar listado CSV',
              ),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                final members = membersAsync.value ?? [];
                if (members.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(LocalizationService.tr('kiosk_empty_title'))),
                  );
                  return;
                }
                try {
                  final file = await DataVaultService.exportMembersCsv();
                  await DataVaultService.shareMembersCsv(file);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('CSV Export Error: $e')),
                    );
                  }
                }
              },
            ),
          ),
          // 3. 시니어 큰글씨 모드 퀵 토글 (공통 규격: 가장 우측 배치)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: Icon(
                Icons.format_size_rounded,
                size: 21,
                color: isSeniorMode ? AppTheme.trustBlue : const Color(0xFF3F3F46),
              ),
              tooltip: LocalizationService.tr('senior_easy_mode'),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(seniorModeProvider.notifier).toggle(),
            ),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
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
                        Text(
                          LocalizationService.tr('kiosk_name_empty'),
                          style: const TextStyle(
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
        backgroundColor: AppTheme.fabPrimary,
        elevation: 3,
        icon: const Icon(Icons.person_add_alt_1_rounded, color: Colors.white, size: 21),
        label: Text(
          LocalizationService.tr('add_member_btn'),
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Colors.white, letterSpacing: -0.2),
        ),
      ),
    );
  }

  Widget _buildMemberTile(BuildContext context, Member member, StudioProfile studio) {
    final isSeniorMode = ref.watch(seniorModeProvider);
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
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tier 1: Avatar + Member Name (UNCONSTRAINED FULL WIDTH) + Chevron
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
                  const Icon(Icons.chevron_right_rounded, size: 20, color: Color(0xFF94A3B8)),
                ],
              ),

              const SizedBox(height: 8),

              // Tier 2: Grouped Badges Cluster (배치는 배치끼리 깔끔하게 묶음)
              Wrap(
                spacing: 6,
                runSpacing: 5,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                    ),
                    child: Text(
                      [
                        if (member.secondaryTag != null && member.secondaryTag!.isNotEmpty) member.secondaryTag!,
                        if (member.groupName.isNotEmpty) LocalizationService.localizeBuiltInLabel(member.groupName),
                        if ((member.secondaryTag == null || member.secondaryTag!.isEmpty) && member.groupName.isEmpty)
                          LocalizationService.localizeBuiltInLabel('일반'),
                      ].join(' · '),
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        height: 1.25,
                      ),
                    ),
                  ),
                  isSession
                      ? (isExpiring
                          ? ZeroBadge.danger('${member.remainingSessions}/${member.totalSessions}', size: ZeroBadgeSize.small)
                          : ZeroBadge.primary('${member.remainingSessions}/${member.totalSessions}', size: ZeroBadgeSize.small))
                      : ZeroBadge.neutral(LocalizationService.tr('monthly_pass'), size: ZeroBadgeSize.small),
                ],
              ),

              const SizedBox(height: 7),

              // Tier 3: Contact & Meta Row (1-Column Stack in Senior Mode)
              if (isSeniorMode)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.phone_iphone_rounded, size: 14, color: Color(0xFF64748B)),
                        const SizedBox(width: 4),
                        Text(
                          _formatPhone(member.phone),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ],
                    ),
                    if (member.payerName != null && member.payerName!.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        LocalizationService.pick(
                          ko: '입금자(보호자): ${member.payerName}',
                          en: 'Payer / Guardian: ${member.payerName}',
                          ja: '振込名義 / 保護者: ${member.payerName}',
                          zh: '付款人 / 家长: ${member.payerName}',
                          vi: 'Người nộp / Phụ huynh: ${member.payerName}',
                          es: 'Pagador / Tutor: ${member.payerName}',
                        ),
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ],
                )
              else
                Row(
                  children: [
                    const Icon(Icons.phone_iphone_rounded, size: 13, color: Color(0xFF64748B)),
                    const SizedBox(width: 4),
                    Text(
                      _formatPhone(member.phone),
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    if (member.payerName != null && member.payerName!.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '· ${member.payerName}',
                          softWrap: true,
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ],
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

  void _openAddMemberDialog(BuildContext context, {Member? editMember}) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (ctx) => _AddMemberModal(editMember: editMember),
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
    final isSeniorMode = ref.watch(seniorModeProvider);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                          const SizedBox(height: 5),
                          // Badges Cluster (배치는 배치끼리 깔끔하게 묶음)
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                                ),
                                child: Text(
                                  member.groupName.isNotEmpty
                                      ? LocalizationService.localizeBuiltInLabel(member.groupName)
                                      : LocalizationService.localizeBuiltInLabel('일반'),
                                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF334155)),
                                ),
                              ),
                              if (member.secondaryTag != null && member.secondaryTag!.isNotEmpty)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFEFF6FF),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: const Color(0xFFDBEAFE), width: 0.8),
                                  ),
                                  child: Text(
                                    member.secondaryTag!,
                                    style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                                  ),
                                ),
                              if (member.billingType == BillingType.sessionBased)
                                ZeroBadge.primary('${member.remainingSessions}/${member.totalSessions}', size: ZeroBadgeSize.small)
                              else
                                ZeroBadge.neutral(LocalizationService.tr('monthly_pass'), size: ZeroBadgeSize.small),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Contact Row (전화번호는 따로 독립 분리)
                          Row(
                            children: [
                              const Icon(Icons.phone_iphone_rounded, size: 13, color: Color(0xFF64748B)),
                              const SizedBox(width: 4),
                              Text(
                                _formatPhone(member.phone),
                                style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), fontWeight: FontWeight.w600),
                              ),
                              if (member.payerName != null && member.payerName!.isNotEmpty) ...[
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '· ${member.payerName}',
                                    softWrap: true,
                                    style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.primaryBlue),
                    tooltip: LocalizationService.tr('common_edit'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      AppBottomSheet.show(
                        context: context,
                        maxHeightRatio: 0.90,
                        builder: (ctx) => _AddMemberModal(editMember: member),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20, color: AppTheme.danger),
                    tooltip: LocalizationService.tr('common_delete'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _confirmDeleteMember(context, ref, member),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Shortcut Action Buttons (1 Column Full-Width in Senior Mode)
          if (isSeniorMode) ...[
            if (member.billingType == BillingType.sessionBased) ...[
              ZeroButton.primary(
                label: LocalizationService.pick(
                  ko: '+10회 충전',
                  en: '+10 Top Up',
                  ja: '+10回追加',
                  zh: '+10次续充',
                  vi: '+10 buổi',
                  es: '+10 Sesiones',
                ),
                icon: Icons.add,
                fullWidth: true,
                size: ZeroButtonSize.large,
                onPressed: () {
                  ref.read(membersProvider.notifier).addSessions(member.id, 10);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${member.primaryName} +10'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
            ZeroButton.secondary(
              label: LocalizationService.pick(
                ko: '청구서 즉시 발송',
                en: 'Send Invoice Now',
                ja: '請求書を今すぐ送信',
                zh: '立即开单发送',
                vi: 'Gửi hóa đơn ngay',
                es: 'Enviar factura ahora',
              ),
              icon: Icons.send_outlined,
              fullWidth: true,
              size: ZeroButtonSize.large,
              onPressed: () async {
                final bm = MonetizationService.instance;
                final curInvCount = ref.read(invoicesProvider).value?.length ?? 0;
                if (!await bm.ensureCreateAllowed(
                  context,
                  itemLabel: LocalizationService.tr('tab_billing'),
                  currentCount: curInvCount,
                  limit: bm.maxInvoiceLimit,
                )) {
                  return;
                }
                // Create invoice on the fly
                final invoice = Invoice(
                  id: 'inv_${const Uuid().v4().substring(0, 8)}',
                  memberIds: [member.id],
                  recipientPhone: member.phone,
                  title: '${member.primaryName} · ${studio.feeWord}',
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
          ] else
            Row(
              children: [
                if (member.billingType == BillingType.sessionBased)
                  Expanded(
                    child: ZeroButton.primary(
                      label: LocalizationService.pick(
                        ko: '+10회 충전',
                        en: '+10 Top Up',
                        ja: '+10回追加',
                        zh: '+10次续充',
                        vi: '+10 buổi',
                        es: '+10 Sesiones',
                      ),
                      icon: Icons.add,
                      fullWidth: true,
                      size: ZeroButtonSize.large,
                      onPressed: () {
                        ref.read(membersProvider.notifier).addSessions(member.id, 10);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${member.primaryName} +10'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                    ),
                  ),
                if (member.billingType == BillingType.sessionBased) const SizedBox(width: 8),
                Expanded(
                  child: ZeroButton.secondary(
                    label: LocalizationService.pick(
                      ko: '청구서 즉시 발송',
                      en: 'Send Invoice Now',
                      ja: '請求書を今すぐ送信',
                      zh: '立即开单发送',
                      vi: 'Gửi hóa đơn ngay',
                      es: 'Enviar factura ahora',
                    ),
                    icon: Icons.send_outlined,
                    fullWidth: true,
                    size: ZeroButtonSize.large,
                    onPressed: () async {
                      // Create invoice on the fly
                      final bm = MonetizationService.instance;
                      final curInvCount = ref.read(invoicesProvider).value?.length ?? 0;
                      if (!await bm.ensureCreateAllowed(
                        context,
                        itemLabel: LocalizationService.tr('tab_billing'),
                        currentCount: curInvCount,
                        limit: bm.maxInvoiceLimit,
                      )) {
                        return;
                      }
                      final invoice = Invoice(
                        id: 'inv_${const Uuid().v4().substring(0, 8)}',
                        memberIds: [member.id],
                        recipientPhone: member.phone,
                        title: '${member.primaryName} · ${studio.feeWord}',
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
                  TabBar(
                    labelColor: AppTheme.primaryBlue,
                    unselectedLabelColor: AppTheme.textSecondary,
                    indicatorColor: AppTheme.primaryBlue,
                    indicatorWeight: 2.5,
                    indicatorSize: TabBarIndicatorSize.tab,
                    dividerColor: Colors.transparent,
                    labelStyle: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    tabs: [
                      Tab(
                        text: LocalizationService.pick(
                          ko: '출석 기록 타임라인',
                          en: 'Attendance History',
                          ja: '出席履歴タイムライン',
                          zh: '考勤签到记录',
                          vi: 'Lịch sử điểm danh',
                          es: 'Historial de asistencia',
                        ),
                      ),
                      Tab(
                        text: LocalizationService.pick(
                          ko: '수납 내역 로그',
                          en: 'Billing & Payment Log',
                          ja: '請求・入金履歴',
                          zh: '收费与付款记录',
                          vi: 'Lịch sử hóa đơn & thu phí',
                          es: 'Registro de cobros',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Attendance List
                        memberPasses.isEmpty
                            ? Center(child: Text(LocalizationService.tr('kiosk_name_empty')))
                            : ListView.builder(
                                itemCount: memberPasses.length,
                                itemBuilder: (ctx, i) {
                                  final p = memberPasses[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFECFDF5),
                                            shape: BoxShape.circle,
                                            border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                                          ),
                                          child: const Icon(Icons.check_rounded, color: AppTheme.softMint, size: 14),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                DateFormat('yyyy.MM.dd HH:mm').format(p.timestamp),
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                p.status == AttendanceStatus.attended
                                                    ? LocalizationService.tr('checked_in')
                                                    : LocalizationService.pick(ko: '지각/보강', en: 'Late / Make-up', ja: '遅刻・振替', zh: '迟到/补课', vi: 'Muộn / Học bù', es: 'Tarde / Recuperación'),
                                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (p.sessionDeduction != null && p.sessionDeduction! > 0)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFEE2E2),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              '-1',
                                              style: TextStyle(fontSize: 11.5, color: Color(0xFFDC2626), fontWeight: FontWeight.w700),
                                            ),
                                          ),
                                        const SizedBox(width: 4),
                                        IconButton(
                                          icon: const Icon(Icons.undo_rounded, size: 17, color: AppTheme.textSecondary),
                                          tooltip: LocalizationService.tr('common_cancel'),
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                                          onPressed: () async {
                                            final confirm = await showDialog<bool>(
                                              context: context,
                                              builder: (dlgCtx) => AlertDialog(
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                                title: Text(
                                                  LocalizationService.pick(
                                                    ko: '출석 기록 취소',
                                                    en: 'Undo Check-in Record',
                                                    ja: '出席記録を取り消す',
                                                    zh: '撤销签到记录',
                                                    vi: 'Hủy bản ghi điểm danh',
                                                    es: 'Anular asistencia',
                                                  ),
                                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                                                ),
                                                content: Text(
                                                  '${DateFormat('MM.dd HH:mm').format(p.timestamp)} — ${LocalizationService.tr('common_confirm')}?',
                                                  style: const TextStyle(fontSize: 13.5, height: 1.45),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(dlgCtx, false),
                                                    child: Text(LocalizationService.tr('btn_cancel')),
                                                  ),
                                                  ElevatedButton(
                                                    onPressed: () => Navigator.pop(dlgCtx, true),
                                                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                                    child: Text(LocalizationService.tr('common_confirm'), style: const TextStyle(color: Colors.white)),
                                                  ),
                                                ],
                                              ),
                                            );
                                            if (confirm == true) {
                                              await ref.read(passRecordsProvider.notifier).cancelCheckIn(
                                                    record: p,
                                                    member: member,
                                                  );
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text(LocalizationService.tr('common_confirm')),
                                                    behavior: SnackBarBehavior.floating,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),

                        // Invoices List
                        memberInvoices.isEmpty
                            ? Center(child: Text(LocalizationService.tr('kiosk_name_empty')))
                            : ListView.builder(
                                itemCount: memberInvoices.length,
                                itemBuilder: (ctx, i) {
                                  final inv = memberInvoices[i];
                                  final isPaid = inv.status == PaymentStatus.paid;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFF8FAFC),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(7),
                                          decoration: BoxDecoration(
                                            color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFEF2F2),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            isPaid ? Icons.check_circle_outline_rounded : Icons.pending_actions_rounded,
                                            color: isPaid ? AppTheme.softMint : const Color(0xFFEF4444),
                                            size: 14,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                inv.title,
                                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                '${LocalizationService.formatAmount(inv.amount)} · ${LocalizationService.formatDate(inv.dueDate)}',
                                                style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                              ),
                                            ],
                                          ),
                                        ),
                                        isPaid
                                            ? ZeroBadge.success(LocalizationService.tr('paid_status'), size: ZeroBadgeSize.small)
                                            : ZeroBadge.danger(LocalizationService.tr('unpaid_status'), size: ZeroBadgeSize.small),
                                      ],
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

  Future<void> _confirmDeleteMember(BuildContext context, WidgetRef ref, Member member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppTheme.danger, size: 22),
            const SizedBox(width: 8),
            Text(LocalizationService.tr('common_delete'), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: Text(
          LocalizationService.pick(
            ko: '\'${member.name}\' 회원을 명부에서 삭제하시겠습니까?\n\n해당 회원의 출석 기록도 함께 삭제되며 되돌릴 수 없습니다.',
            en: 'Delete "${member.name}" from the directory?\n\nAttendance records for this member will also be removed permanently.',
            ja: '「${member.name}」様を削除しますか？\n\nこの会員の出席履歴もあわせて削除されます。',
            zh: '确定要删除会员「${member.name}」吗？\n\n该会员的考勤历史也将一并删除且无法恢复。',
            vi: 'Xóa "${member.name}" khỏi danh sách?\n\nLịch sử điểm danh của học viên này cũng sẽ bị xóa.',
            es: '¿Eliminar a "${member.name}"?\n\nSu historial de asistencia también se borrará.',
          ),
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(LocalizationService.tr('btn_cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text(LocalizationService.tr('common_delete'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await ref.read(membersProvider.notifier).deleteMember(member.id);
      await ref.read(passRecordsProvider.notifier).reload();
      if (context.mounted) {
        Navigator.pop(context); // Close detail modal
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${member.name} · ${LocalizationService.tr('common_delete')}'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _updatePhoto(BuildContext context, WidgetRef ref, Member member) async {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.50,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.account_circle_rounded, color: AppTheme.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          member.name,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryBlue),
              title: Text(
                LocalizationService.pick(
                  ko: '카메라로 직접 촬영',
                  en: 'Take Photo with Camera',
                  ja: 'カメラで撮影',
                  zh: '拍照上传',
                  vi: 'Chụp ảnh bằng camera',
                  es: 'Tomar foto con cámara',
                ),
              ),
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
              title: Text(
                LocalizationService.pick(
                  ko: '갤러리에서 사진 선택',
                  en: 'Choose from Gallery',
                  ja: 'アルバムから選択',
                  zh: '从相册选择',
                  vi: 'Chọn từ thư viện',
                  es: 'Elegir de la galería',
                ),
              ),
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
                title: Text(LocalizationService.tr('common_delete'), style: const TextStyle(color: AppTheme.danger)),
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
  final Member? editMember;
  const _AddMemberModal({this.editMember});

  @override
  ConsumerState<_AddMemberModal> createState() => _AddMemberModalState();
}

class _AddMemberModalState extends ConsumerState<_AddMemberModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _payerNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _groupController;
  late final TextEditingController _feeController;
  late final TextEditingController _sessionsController;
  late final TextEditingController _remainingSessionsController;
  late final TextEditingController _memoController;

  late BillingType _billingType;
  String? _photoPath;

  bool get _isEdit => widget.editMember != null;

  @override
  void initState() {
    super.initState();
    final m = widget.editMember;
    _nameController = TextEditingController(text: m?.name ?? '');
    _payerNameController = TextEditingController(text: m?.payerName ?? '');
    _phoneController = TextEditingController(text: m?.phone ?? '');
    _groupController = TextEditingController(
      text: m?.groupName ?? LocalizationService.localizeBuiltInLabel('정규반'),
    );
    _feeController = TextEditingController(
      text: (m?.defaultFee ?? LocalizationService.currentCurrency.defaultFeeBase).toString(),
    );
    _sessionsController = TextEditingController(text: (m != null && m.totalSessions > 0 ? m.totalSessions : 10).toString());
    _remainingSessionsController = TextEditingController(text: (m?.remainingSessions ?? 10).toString());
    _memoController = TextEditingController(text: m?.memo ?? '');
    _billingType = m?.billingType ?? BillingType.sessionBased;
    _photoPath = m?.photoPath;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _payerNameController.dispose();
    _phoneController.dispose();
    _groupController.dispose();
    _feeController.dispose();
    _sessionsController.dispose();
    _remainingSessionsController.dispose();
    _memoController.dispose();
    super.dispose();
  }

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
          SnackBar(content: Text('Photo error: $e')),
        );
      }
    }
  }

  void _showPhotoOptions() {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.50,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.add_a_photo_rounded, color: AppTheme.primaryBlue, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          LocalizationService.pick(
                            ko: '회원 사진 등록',
                            en: 'Add Member Photo',
                            ja: '会員写真の登録',
                            zh: '上传会员照片',
                            vi: 'Thêm ảnh hội viên',
                            es: 'Añadir foto del miembro',
                          ),
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.4,
                          ),
                          softWrap: true,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 10),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined, color: AppTheme.primaryBlue),
              title: Text(
                LocalizationService.pick(
                  ko: '카메라로 직접 촬영',
                  en: 'Take Photo with Camera',
                  ja: 'カメラで撮影',
                  zh: '拍照上传',
                  vi: 'Chụp ảnh bằng camera',
                  es: 'Tomar foto con cámara',
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, color: AppTheme.softMint),
              title: Text(
                LocalizationService.pick(
                  ko: '갤러리에서 사진 선택',
                  en: 'Choose from Gallery',
                  ja: 'アルバムから選択',
                  zh: '从相册选择',
                  vi: 'Chọn từ thư viện',
                  es: 'Elegir de la galería',
                ),
              ),
              onTap: () {
                Navigator.pop(ctx);
                _pickPhoto(ImageSource.gallery);
              },
            ),
            if (_photoPath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: AppTheme.danger),
                title: Text(LocalizationService.tr('common_delete'), style: const TextStyle(color: AppTheme.danger)),
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
    final customCatAsync = ref.watch(customCategoryProvider);
    final customCatState = customCatAsync.value ??
        CustomCategoryState.getDefaultsForIndustry('입시 / 보습학원');

    return Form(
      key: _formKey,
      child: StickyBottomSheetLayout(
        header: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _isEdit ? LocalizationService.tr('common_edit') : LocalizationService.tr('add_member_btn'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),
        bodyPadding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [

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
                              : Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.add_a_photo_rounded, size: 28, color: AppTheme.primaryBlue),
                                    const SizedBox(height: 2),
                                    Text(
                                      LocalizationService.tr('common_add'),
                                      style: const TextStyle(
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
              Center(
                child: Text(
                  LocalizationService.pick(
                    ko: '등록된 사진은 키오스크 출석 체크 시 전면에 표시됩니다',
                    en: 'Registered photo appears on the kiosk check-in screen',
                    ja: '登録した写真はキオスクの出席完了画面に表示されます',
                    zh: '上传的头像将在考勤终端签到成功时显示',
                    vi: 'Ảnh sẽ hiển thị trên màn hình điểm danh Kiosk',
                    es: 'La foto aparecerá en la pantalla del quiosco',
                  ),
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(height: 16),

              // Name
              AppTextField(
                controller: _nameController,
                label: LocalizationService.pick(
                  ko: '회원/학생 이름',
                  en: 'Member / Student Name',
                  ja: '会員・生徒名',
                  zh: '会员/学员姓名',
                  vi: 'Họ tên học viên / hội viên',
                  es: 'Nombre del miembro / alumno',
                ),
                hint: LocalizationService.tr('kiosk_demo_member_name'),
                prefixIcon: Icons.badge_outlined,
                validator: (v) => (v == null || v.trim().isEmpty) ? LocalizationService.tr('wiz_err_required') : null,
              ),
              const SizedBox(height: 12),

              // Payer Name (Parent / Actual Depositor)
              AppTextField(
                controller: _payerNameController,
                label: LocalizationService.pick(
                  ko: '입금자 성함 (학부모 / 보호자명)',
                  en: 'Payer / Guardian Name (Optional)',
                  ja: '振込名義 / 保護者名（任意）',
                  zh: '付款人 / 家长姓名（选填）',
                  vi: 'Tên người nộp tiền / Phụ huynh',
                  es: 'Nombre del pagador / tutor (Opcional)',
                ),
                hint: LocalizationService.pick(
                  ko: '학생명과 다를 경우 입력 (예: 이영희)',
                  en: 'If different from member name',
                  ja: '会員名と異なる場合に入力',
                  zh: '如与学员姓名不同可在此填写',
                  vi: 'Nhập nếu khác tên học viên',
                  es: 'Si es distinto al nombre del miembro',
                ),
                prefixIcon: Icons.family_restroom_outlined,
              ),
              const SizedBox(height: 12),

              // Phone
              AppTextField(
                controller: _phoneController,
                label: LocalizationService.pick(
                  ko: '연락처 (안심 알림·청구 문자용)',
                  en: 'Phone Number (For Alerts & Invoices)',
                  ja: '電話番号（通知・請求SMS用）',
                  zh: '联系电话（用于考勤通知与账单）',
                  vi: 'Số điện thoại (Thông báo & Hóa đơn)',
                  es: 'Teléfono (Para avisos y facturas)',
                ),
                hint: LocalizationService.isDomestic ? '예: 010-1234-5678' : '+1 555-010-1234',
                prefixIcon: Icons.phone_outlined,
                keyboardType: TextInputType.phone,
                validator: (v) => (v == null || v.trim().length < 6) ? LocalizationService.tr('wiz_err_required') : null,
              ),
              const SizedBox(height: 14),

              // Multi-Industry Quick Selection Templates
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LocalizationService.pick(
                      ko: '업종별 간편 템플릿 (원터치 자동 입력)',
                      en: 'Quick Plan Templates',
                      ja: '簡単テンプレート（ワンタップ入力）',
                      zh: '快捷课程套餐模板（一键填入）',
                      vi: 'Mẫu gói nhanh (Chạm để điền)',
                      es: 'Plantillas rápidas de tarifa',
                    ),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                  ),
                  Text('${customCatState.memberTemplates.length}',
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
                    final displayPrice = LocalizationService.isDomestic && LocalizationService.currentCurrency == AppCurrency.krw
                        ? (template.label.contains('만') ? template.label : '${template.label} (${template.defaultFee ~/ 10000}만)')
                        : '${LocalizationService.localizeBuiltInLabel(template.groupName)} (${LocalizationService.formatAmount(template.defaultFee)})';
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
                        label: Text(displayPrice),
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
                label: LocalizationService.pick(
                  ko: '수업 / 클래스 그룹',
                  en: 'Class / Group Name',
                  ja: 'クラス / グループ',
                  zh: '课程班级 / 分组',
                  vi: 'Lớp / Nhóm',
                  es: 'Clase / Grupo',
                ),
                hint: LocalizationService.localizeBuiltInLabel('정규반'),
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
                          label: Text(LocalizationService.localizeBuiltInLabel(group)),
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
                      label: Text(
                        LocalizationService.pick(
                          ko: '새 그룹 추가',
                          en: 'Add Group',
                          ja: 'グループ追加',
                          zh: '新增分组',
                          vi: 'Thêm nhóm',
                          es: 'Nuevo grupo',
                        ),
                        style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: AppTheme.primaryBlue),
                      ),
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
              Text(
                '${LocalizationService.tr('billing_type_session')} / ${LocalizationService.tr('billing_type_monthly')}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              SegmentedButton<BillingType>(
                segments: [
                  ButtonSegment(
                    value: BillingType.sessionBased,
                    label: Text(LocalizationService.tr('billing_type_session')),
                  ),
                  ButtonSegment(
                    value: BillingType.monthlyRecurring,
                    label: Text(LocalizationService.tr('billing_type_monthly')),
                  ),
                ],
                selected: {_billingType},
                onSelectionChanged: (val) {
                  setState(() => _billingType = val.first);
                },
              ),
              const SizedBox(height: 14),

              // Default Fee & Sessions
              LayoutBuilder(
                builder: (context, constraints) {
                  final isSenior = ref.watch(seniorModeProvider);
                  final isCompact = constraints.maxWidth < 320;
                  final feeLabel = '${LocalizationService.tr('sms_default_order_title')} (${LocalizationService.currentCurrency.symbol})';
                  final totalSessLabel = LocalizationService.trParams('common_sessions_unit', {'n': '10'});
                  if ((isSenior || isCompact) && _billingType == BillingType.sessionBased) {
                    return Column(
                      children: [
                        AppTextField(
                          controller: _feeController,
                          label: feeLabel,
                          hint: '${LocalizationService.currentCurrency.defaultFeeBase}',
                          prefixIcon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: _sessionsController,
                          label: totalSessLabel,
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
                          label: feeLabel,
                          hint: '${LocalizationService.currentCurrency.defaultFeeBase}',
                          prefixIcon: Icons.payments_outlined,
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      if (_billingType == BillingType.sessionBased) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: AppTextField(
                            controller: _sessionsController,
                            label: totalSessLabel,
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
              // Remaining sessions field when editing session-based member
              if (_isEdit && _billingType == BillingType.sessionBased) ...[
                const SizedBox(height: 12),
                AppTextField(
                  controller: _remainingSessionsController,
                  label: LocalizationService.tr('kiosk_success_pass_label'),
                  hint: '0',
                  prefixIcon: Icons.timelapse_outlined,
                  keyboardType: TextInputType.number,
                ),
              ],
              const SizedBox(height: 14),

              // Memo
              AppTextField(
                controller: _memoController,
                label: LocalizationService.pick(
                  ko: '운영자 메모 (비공개 로컬 보관)',
                  en: 'Private Staff Notes (Stored Locally)',
                  ja: 'スタッフメモ（端末内保存）',
                  zh: '老师内部备注（仅存本地）',
                  vi: 'Ghi chú nội bộ (Lưu trên máy)',
                  es: 'Notas internas (Solo en dispositivo)',
                ),
                hint: '...',
                prefixIcon: Icons.note_alt_outlined,
              ),
            ],
          ),
        footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        footer: SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () async {
              if (_formKey.currentState!.validate()) {
                final fee = int.tryParse(_feeController.text.replaceAll(',', '')) ?? 0;
                final totalSessions = int.tryParse(_sessionsController.text) ?? 10;
                final remainingSessions = _isEdit
                    ? (int.tryParse(_remainingSessionsController.text) ?? totalSessions)
                    : totalSessions;

                if (_isEdit) {
                  if (!await MonetizationService.instance.ensureEditAllowed(
                    context,
                    itemLabel: LocalizationService.tr('common_edit'),
                  )) {
                    return;
                  }
                  final updatedMember = widget.editMember!.copyWith(
                    name: _nameController.text.trim(),
                    phone: _phoneController.text.trim(),
                    groupName: _groupController.text.trim(),
                    billingType: _billingType,
                    defaultFee: fee,
                    totalSessions: _billingType == BillingType.sessionBased ? totalSessions : 0,
                    remainingSessions: _billingType == BillingType.sessionBased ? remainingSessions : 0,
                    memo: _memoController.text.trim(),
                    payerName: _payerNameController.text.trim().isNotEmpty ? _payerNameController.text.trim() : '',
                    photoPath: _photoPath,
                  );
                  await ref.read(membersProvider.notifier).updateMember(updatedMember);
                  await MonetizationService.instance.recordEditUsage();
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${updatedMember.name} · ${LocalizationService.tr('common_save')}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  final bm = MonetizationService.instance;
                  final currentMemberCount = ref.read(membersProvider).value?.length ?? 0;
                  if (!await bm.ensureCreateAllowed(
                    context,
                    itemLabel: LocalizationService.tr('tab_members'),
                    currentCount: currentMemberCount,
                    limit: bm.maxMemberLimit,
                  )) {
                    return;
                  }
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

                  await ref.read(membersProvider.notifier).addMember(newMember);
                  MonetizationService.instance.triggerSmartInterstitialAd(
                    cooldownSeconds: 75,
                    actionThreshold: 2,
                  );
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${newMember.name} · ${LocalizationService.tr('common_save')}'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: Text(
              _isEdit ? LocalizationService.tr('common_save') : LocalizationService.tr('add_member_btn'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
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
        title: Text(
          LocalizationService.pick(
            ko: '새 수업/그룹 등록',
            en: 'Create New Group',
            ja: '新しいグループを追加',
            zh: '创建新班级分组',
            vi: 'Thêm nhóm mới',
            es: 'Crear nuevo grupo',
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: AppTextField(
          controller: groupInputCtrl,
          label: LocalizationService.tr('wiz_label_category'),
          hint: LocalizationService.localizeBuiltInLabel('정규반'),
          prefixIcon: Icons.group_add_outlined,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: ZeroButton(
                  label: LocalizationService.tr('btn_cancel'),
                  variant: ZeroButtonVariant.neutral,
                  size: ZeroButtonSize.medium,
                  fullWidth: true,
                  onPressed: () => Navigator.pop(dlgCtx),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ZeroButton.primary(
                  label: LocalizationService.tr('common_add'),
                  size: ZeroButtonSize.medium,
                  fullWidth: true,
                  onPressed: () async {
                    final name = groupInputCtrl.text.trim();
                    if (name.isNotEmpty) {
                      await ref.read(customCategoryProvider.notifier).addGroupCategory(name);
                      setState(() => _groupController.text = name);
                      if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                    }
                  },
                ),
              ),
            ],
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
                      hintText: LocalizationService.pick(
                        ko: '이름, 초성(ㄱㄷㅎ), 연락처, 그룹명 검색',
                        en: 'Search name, phone, or group',
                        ja: '名前・電話番号・グループで検索',
                        zh: '搜索姓名、电话或班级分组',
                        vi: 'Tìm tên, SĐT hoặc nhóm',
                        es: 'Buscar nombre, teléfono o grupo',
                      ),
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
                      label: grp == '전체'
                          ? LocalizationService.tr('common_all')
                          : LocalizationService.localizeBuiltInLabel(grp),
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
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          LocalizationService.tr('total_members_count').replaceAll('{count}', totalCount.toString()),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerRight,
                        child: InkWell(
                          onTap: onSequentialDispatch,
                          borderRadius: BorderRadius.circular(8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.send_rounded, size: 11.5, color: Color(0xFF475569)),
                                const SizedBox(width: 4),
                                Text(
                                  LocalizationService.tr('sequential_dispatch_btn'),
                                  style: const TextStyle(
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

