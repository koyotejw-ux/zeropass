import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/notification_log.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/kakao_share_service.dart';
import '../services/sequential_dispatch_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'app_text_field.dart';
import 'sequential_dispatch_modal.dart';

class SmartNotificationCenterModal extends ConsumerStatefulWidget {
  const SmartNotificationCenterModal({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.94,
      builder: (_) => const SmartNotificationCenterModal(),
    );
  }

  @override
  ConsumerState<SmartNotificationCenterModal> createState() => _SmartNotificationCenterModalState();
}

class _SmartNotificationCenterModalState extends ConsumerState<SmartNotificationCenterModal> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  NotificationType? _selectedTypeFilter;

  // Template Controllers
  late TextEditingController _attendanceTplController;
  late TextEditingController _departureTplController;
  late TextEditingController _invoiceTplController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);

    final studio = ref.read(studioProfileProvider).value ?? StudioProfile.defaultProfile();
    _attendanceTplController = TextEditingController(text: studio.attendanceTemplate);
    _departureTplController = TextEditingController(text: studio.departureTemplate);
    _invoiceTplController = TextEditingController(text: studio.invoiceTemplate);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _attendanceTplController.dispose();
    _departureTplController.dispose();
    _invoiceTplController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final studio = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();
    final members = ref.watch(membersProvider).value ?? [];
    final invoices = ref.watch(invoicesProvider).value ?? [];
    final passRecords = ref.watch(passRecordsProvider).value ?? [];
    final logs = ref.watch(notificationLogsProvider).value ?? [];

    // 1. Calculate unsent today's attendance alerts
    final now = DateTime.now();
    final todayCheckIns = passRecords.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();

    final todayNotifiedMemberIds = logs
        .where((l) =>
            l.type == NotificationType.attendance &&
            l.sentAt.year == now.year &&
            l.sentAt.month == now.month &&
            l.sentAt.day == now.day)
        .map((l) => l.memberId)
        .whereType<String>()
        .toSet();

    final memberMap = {for (final m in members) m.id: m};
    final unsentAttendanceMembers = todayCheckIns
        .map((r) => memberMap[r.memberId])
        .whereType<Member>()
        .where((m) => !todayNotifiedMemberIds.contains(m.id))
        .toSet()
        .toList();

    // 2. Unpaid Invoices
    final unpaidInvoices = invoices.where((i) => i.status == PaymentStatus.unpaid).toList();

    // 3. Expiring Members (<= 1 session)
    final expiringMembers = members
        .where((m) => m.billingType == BillingType.sessionBased && m.remainingSessions <= 1)
        .toList();

    return Column(
      children: [
        // Modal Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_rounded, color: AppTheme.primaryBlue, size: 22),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '스마트 안심 알림 센터',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '등·하원 안심 알림 & 수납 독촉 릴레이 허브',
                            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Tabs
        TabBar(
          controller: _tabController,
          labelColor: AppTheme.primaryBlue,
          unselectedLabelColor: AppTheme.textSecondary,
          labelStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
          indicatorColor: AppTheme.primaryBlue,
          indicatorWeight: 3,
          tabs: [
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('실시간 브리핑'),
                    if (unsentAttendanceMembers.isNotEmpty || unpaidInvoices.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${unsentAttendanceMembers.length + unpaidInvoices.length}',
                          style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('발송 이력 (${logs.length})'),
              ),
            ),
            const Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('알림 템플릿'),
              ),
            ),
          ],
        ),

        // Tab Content
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // TAB 1: Smart Briefing
              _buildSmartBriefingTab(
                context: context,
                studio: studio,
                members: members,
                invoices: invoices,
                unsentAttendanceMembers: unsentAttendanceMembers,
                unpaidInvoices: unpaidInvoices,
                expiringMembers: expiringMembers,
              ),

              // TAB 2: Notification Logs
              _buildLogsTab(logs: logs),

              // TAB 3: Template Quick Settings
              _buildTemplatesTab(studio: studio),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================
  // TAB 1: SMART BRIEFING
  // ==========================================
  Widget _buildSmartBriefingTab({
    required BuildContext context,
    required StudioProfile studio,
    required List<Member> members,
    required List<Invoice> invoices,
    required List<Member> unsentAttendanceMembers,
    required List<Invoice> unpaidInvoices,
    required List<Member> expiringMembers,
  }) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // 1. Unsent Attendance Queue Card
        _buildQueueCard(
          title: '오늘 등원 안심 알림 대기',
          count: unsentAttendanceMembers.length,
          countColor: unsentAttendanceMembers.isEmpty ? AppTheme.softMint : const Color(0xFF3182F6),
          icon: Icons.login_rounded,
          iconBgColor: const Color(0xFFEFF6FF),
          iconColor: AppTheme.primaryBlue,
          subtitle: unsentAttendanceMembers.isEmpty
              ? '오늘 출석한 모든 원생의 보호자에게 알림장이 정상 발송되었습니다.'
              : '오늘 출석 체크 완료 원생 중 아직 보호자 알림장이 발송되지 않았습니다.',
          actionLabel: '등원 알림 순차 발송 🚀',
          actionColor: AppTheme.primaryBlue,
          isActionEnabled: unsentAttendanceMembers.isNotEmpty,
          onAction: () {
            SequentialDispatchModal.show(
              context: context,
              allMembers: unsentAttendanceMembers,
              studio: studio,
              invoices: invoices,
              initialTemplateType: DispatchTemplateType.notice,
            );
          },
        ),

        const SizedBox(height: 14),

        // 2. Unpaid Billing Queue Card
        _buildQueueCard(
          title: '미납 수강료 수납 독촉 대기',
          count: unpaidInvoices.length,
          countColor: unpaidInvoices.isEmpty ? AppTheme.softMint : const Color(0xFFEF4444),
          icon: Icons.mark_chat_unread_outlined,
          iconBgColor: const Color(0xFFFEF2F2),
          iconColor: const Color(0xFFEF4444),
          subtitle: unpaidInvoices.isEmpty
              ? '대기 중인 미납 청구서가 없습니다. 수납률 100%!'
              : '납부 기한이 도래했거나 미납 상태인 청구서가 대기 중입니다.',
          actionLabel: '미납 순차 독촉 발송 ⚡',
          actionColor: const Color(0xFFEF4444),
          isActionEnabled: unpaidInvoices.isNotEmpty,
          onAction: () {
            final unpaidMemberIds = unpaidInvoices.expand((i) => i.memberIds).toSet();
            final targetMembers = members.where((m) => unpaidMemberIds.contains(m.id)).toList();
            SequentialDispatchModal.show(
              context: context,
              allMembers: targetMembers,
              studio: studio,
              invoices: unpaidInvoices,
              initialTemplateType: DispatchTemplateType.billing,
            );
          },
        ),

        const SizedBox(height: 14),

        // 3. Expiring Sessions Queue Card
        _buildQueueCard(
          title: '수강권 만료 임박 (잔여 1회 이하)',
          count: expiringMembers.length,
          countColor: expiringMembers.isEmpty ? AppTheme.softMint : const Color(0xFFF59E0B),
          icon: Icons.hourglass_bottom_rounded,
          iconBgColor: const Color(0xFFFFFBEB),
          iconColor: const Color(0xFFF59E0B),
          subtitle: expiringMembers.isEmpty
              ? '만료 임박 회원이 없습니다.'
              : '수업이 1회 이하로 남아 연속 지도를 위해 재등록 안내가 필요합니다.',
          actionLabel: '재등록 안내 순차 발송 💌',
          actionColor: const Color(0xFFD97706),
          isActionEnabled: expiringMembers.isNotEmpty,
          onAction: () {
            SequentialDispatchModal.show(
              context: context,
              allMembers: expiringMembers,
              studio: studio,
              invoices: invoices,
              initialTemplateType: DispatchTemplateType.sessionExpiry,
            );
          },
        ),
      ],
    );
  }

  Widget _buildQueueCard({
    required String title,
    required int count,
    required Color countColor,
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String subtitle,
    required String actionLabel,
    required Color actionColor,
    required bool isActionEnabled,
    required VoidCallback onAction,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: iconBgColor, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: countColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count건',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: countColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(subtitle, style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4)),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isActionEnabled ? onAction : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: actionColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(actionLabel, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 2: NOTIFICATION LOGS
  // ==========================================
  Widget _buildLogsTab({required List<NotificationLog> logs}) {
    final filteredLogs = _selectedTypeFilter == null
        ? logs
        : logs.where((l) => l.type == _selectedTypeFilter).toList();

    return Column(
      children: [
        // Filter Chips Row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _buildTypeFilterChip('전체 보기 (${logs.length})', null),
              _buildTypeFilterChip('등원 알림', NotificationType.attendance),
              _buildTypeFilterChip('하원 알림', NotificationType.departure),
              _buildTypeFilterChip('수납 영수증', NotificationType.receipt),
              _buildTypeFilterChip('수강료 청구', NotificationType.billing),
              _buildTypeFilterChip('미납 리마인드', NotificationType.reminder),
              _buildTypeFilterChip('만료 안내', NotificationType.sessionExpiry),
            ],
          ),
        ),

        // Logs List
        Expanded(
          child: filteredLogs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_toggle_off_rounded, size: 48, color: Colors.grey.shade300),
                      const SizedBox(height: 12),
                      const Text(
                        '아직 발송된 알림 내역이 없습니다.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: filteredLogs.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (ctx, idx) {
                    final log = filteredLogs[idx];
                    return _buildLogCard(log);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildTypeFilterChip(String label, NotificationType? type) {
    final isSel = _selectedTypeFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSel ? FontWeight.w800 : FontWeight.w500,
            color: isSel ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        selected: isSel,
        selectedColor: AppTheme.primaryBlue,
        backgroundColor: Colors.white,
        onSelected: (val) {
          if (val) setState(() => _selectedTypeFilter = type);
        },
      ),
    );
  }

  Widget _buildLogCard(NotificationLog log) {
    final timeStr = DateFormat('M월 d일 a h:mm', 'ko_KR').format(log.sentAt);
    final isKakao = log.channel == 'KAKAO';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderSubtle),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: isKakao ? const Color(0xFFFEE500) : AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      isKakao ? '카톡 0원' : '문자(SMS)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isKakao ? const Color(0xFF191919) : AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      log.typeLabel,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF475569)),
                    ),
                  ),
                ],
              ),
              Text(timeStr, style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '수신: ${log.memberName} (${log.recipientPhone})',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              log.message,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, height: 1.4, color: Color(0xFF334155)),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                if (isKakao) {
                  KakaoShareService.shareMessage(text: log.message);
                } else {
                  SmsTemplateService.launchNativeSms(recipientPhone: log.recipientPhone, body: log.message);
                }
              },
              icon: Icon(isKakao ? Icons.chat_bubble_rounded : Icons.sms_outlined, size: 14),
              label: const Text('동일 내용 재발송', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================
  // TAB 3: QUICK TEMPLATES
  // ==========================================
  Widget _buildTemplatesTab({required StudioProfile studio}) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        const Text(
          '알림장 문구 즉시 수정',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
        ),
        const SizedBox(height: 4),
        const Text(
          '사용 가능한 자동 치환 변수: #{상호명}, #{회원명}, #{출석시간}, #{잔여회차}, #{금액}, #{토스송금링크}, #{카드결제링크}',
          style: TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
        ),
        const SizedBox(height: 16),

        // Attendance Template
        AppTextField(
          controller: _attendanceTplController,
          label: '안심 등원 알림 템플릿',
          maxLines: 4,
        ),
        const SizedBox(height: 14),

        // Departure Template
        AppTextField(
          controller: _departureTplController,
          label: '안심 하원 알림 템플릿',
          maxLines: 4,
        ),
        const SizedBox(height: 14),

        // Invoice Template
        AppTextField(
          controller: _invoiceTplController,
          label: '수강료 청구/독촉 알림 템플릿',
          maxLines: 5,
        ),
        const SizedBox(height: 20),

        ElevatedButton.icon(
          onPressed: () async {
            final updated = studio.copyWith(
              attendanceTemplate: _attendanceTplController.text.trim(),
              departureTemplate: _departureTplController.text.trim(),
              invoiceTemplate: _invoiceTplController.text.trim(),
            );
            await ref.read(studioProfileProvider.notifier).updateProfile(updated);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('알림장 템플릿이 성공적으로 저장되었습니다.')),
              );
            }
          },
          icon: const Icon(Icons.save_rounded, size: 18),
          label: const Text('알림 템플릿 변경사항 저장하기', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ],
    );
  }
}
