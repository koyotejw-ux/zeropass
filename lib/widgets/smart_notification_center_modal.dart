import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/notification_log.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/kakao_share_service.dart';
import '../services/localization_service.dart';
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

    // 3. Expiring Members (<= 2 sessions)
    final expiringMembers = members
        .where((m) => m.billingType == BillingType.sessionBased && m.remainingSessions <= 2)
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
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.pick(
                              ko: '스마트 안심 알림 센터',
                              en: 'Smart Notification Center',
                              ja: 'スマート安心通知センター',
                              zh: '智能安心通知中心',
                              vi: 'Trung tâm Thông báo Thông minh',
                              es: 'Centro de Avisos Inteligente',
                            ),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
                            softWrap: true,
                          ),
                          Text(
                            LocalizationService.pick(
                              ko: '등·하원 안심 알림 & 수납 독촉 릴레이 허브',
                              en: 'Attendance alerts & overdue payment relay hub',
                              ja: '出席安心通知・未納フォローリレーハブ',
                              zh: '考勤安心通知与缴费催收中枢',
                              vi: 'Trung tâm báo điểm danh & nhắc thu phí',
                              es: 'Avisos de asistencia y recordatorios de cobro',
                            ),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            softWrap: true,
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
                    Text(
                      LocalizationService.pick(
                        ko: '실시간 브리핑',
                        en: 'Live Briefing',
                        ja: '状況ブリーフィング',
                        zh: '实时简报',
                        vi: 'Tổng quan',
                        es: 'Resumen',
                      ),
                    ),
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
                child: Text(
                  LocalizationService.pick(
                    ko: '발송 이력 (${logs.length})',
                    en: 'Sent Logs (${logs.length})',
                    ja: '送信履歴 (${logs.length})',
                    zh: '发送记录 (${logs.length})',
                    vi: 'Lịch sử gửi (${logs.length})',
                    es: 'Historial (${logs.length})',
                  ),
                ),
              ),
            ),
            Tab(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  LocalizationService.pick(
                    ko: '알림 템플릿',
                    en: 'Templates',
                    ja: '通知テンプレート',
                    zh: '通知模板',
                    vi: 'Mẫu tin nhắn',
                    es: 'Plantillas',
                  ),
                ),
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
          title: LocalizationService.pick(
            ko: '오늘 등원 안심 알림 대기',
            en: 'Pending Today Check-In Notices',
            ja: '本日の出席通知（未送信）',
            zh: '今日待发到店安心通知',
            vi: 'Thông báo điểm danh hôm nay chờ gửi',
            es: 'Avisos de asistencia pendientes hoy',
          ),
          count: unsentAttendanceMembers.length,
          countColor: unsentAttendanceMembers.isEmpty ? AppTheme.softMint : const Color(0xFF3182F6),
          icon: Icons.login_rounded,
          iconBgColor: const Color(0xFFEFF6FF),
          iconColor: AppTheme.primaryBlue,
          subtitle: unsentAttendanceMembers.isEmpty
              ? LocalizationService.pick(
                  ko: '오늘 출석한 모든 원생의 보호자에게 알림장이 정상 발송되었습니다.',
                  en: 'All checked-in members today have received their attendance notice.',
                  ja: '本日チェックインした全会員への出席通知を送信済みです。',
                  zh: '今日已签到的全部会员均已发送安心通知。',
                  vi: 'Tất cả hội viên điểm danh hôm nay đều đã nhận được thông báo.',
                  es: 'Todos los alumnos registrados hoy ya recibieron su aviso.',
                )
              : LocalizationService.pick(
                  ko: '오늘 출석 체크 완료 원생 중 아직 보호자 알림장이 발송되지 않았습니다.',
                  en: 'Some members checked in today have not been sent an arrival notification yet.',
                  ja: '本日チェックイン済みのうち、まだ通知が未送信の会員がいます。',
                  zh: '部分今日已签到的会员尚未发送到达安心通知。',
                  vi: 'Một số hội viên điểm danh hôm nay chưa được gửi thông báo.',
                  es: 'Hay registros de llegada de hoy sin aviso enviado.',
                ),
          actionLabel: LocalizationService.pick(
            ko: '등원 알림 순차 발송 🚀',
            en: 'Send Check-In Alerts 🚀',
            ja: '出席通知を順次送信 🚀',
            zh: '逐一发送签到通知 🚀',
            vi: 'Gửi lần lượt thông báo đến 🚀',
            es: 'Enviar avisos de llegada 🚀',
          ),
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
          title: LocalizationService.pick(
            ko: '미납 수강료 수납 독촉 대기',
            en: 'Pending Overdue Reminders',
            ja: '未納授業料フォロー待ち',
            zh: '待催缴未付账单',
            vi: 'Hóa đơn chờ nhắc thanh toán',
            es: 'Recordatorios de pago pendientes',
          ),
          count: unpaidInvoices.length,
          countColor: unpaidInvoices.isEmpty ? AppTheme.softMint : const Color(0xFFEF4444),
          icon: Icons.mark_chat_unread_outlined,
          iconBgColor: const Color(0xFFFEF2F2),
          iconColor: const Color(0xFFEF4444),
          subtitle: unpaidInvoices.isEmpty
              ? LocalizationService.pick(
                  ko: '대기 중인 미납 청구서가 없습니다. 수납률 100%!',
                  en: 'No unpaid invoices pending. 100% collected!',
                  ja: '未納の請求書はありません。回収率100%です！',
                  zh: '当前没有待催缴的未付账单，收款率100%！',
                  vi: 'Không có hóa đơn quá hạn nào. Đã thu 100%!',
                  es: 'Sin facturas pendientes. ¡100% cobrado!',
                )
              : LocalizationService.pick(
                  ko: '납부 기한이 도래했거나 미납 상태인 청구서가 대기 중입니다.',
                  en: 'There are unpaid or due invoices awaiting reminder dispatch.',
                  ja: '支払期限が到来または未納の請求書があります。',
                  zh: '有已到期或未结清的账单等待发送提醒。',
                  vi: 'Có hóa đơn đến hạn hoặc chưa thanh toán đang chờ nhắc phí.',
                  es: 'Hay facturas vencidas o pendientes listas para recordar.',
                ),
          actionLabel: LocalizationService.pick(
            ko: '미납 순차 독촉 발송 ⚡',
            en: 'Send Overdue Reminders ⚡',
            ja: '未納案内を順次送信 ⚡',
            zh: '逐一发送催缴提醒 ⚡',
            vi: 'Gửi nhắc phí lần lượt ⚡',
            es: 'Enviar recordatorios ⚡',
          ),
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
          title: LocalizationService.pick(
            ko: '수강권 만료 임박 (잔여 2회 이하)',
            en: 'Low Session Passes (≤2 left)',
            ja: '回数券の有効期限迫る（残2回以下）',
            zh: '次卡即将到期（剩余≤2次）',
            vi: 'Gói sắp hết buổi (≤2 buổi)',
            es: 'Bonos por agotar (≤2 sesiones)',
          ),
          count: expiringMembers.length,
          countColor: expiringMembers.isEmpty ? AppTheme.softMint : const Color(0xFFF59E0B),
          icon: Icons.hourglass_bottom_rounded,
          iconBgColor: const Color(0xFFFFFBEB),
          iconColor: const Color(0xFFF59E0B),
          subtitle: expiringMembers.isEmpty
              ? LocalizationService.pick(
                  ko: '만료 임박 회원이 없습니다.',
                  en: 'No members with low remaining sessions.',
                  ja: '残り回数が少ない会員はいません。',
                  zh: '暂无即将到期或余课不足的会员。',
                  vi: 'Không có hội viên nào sắp hết buổi.',
                  es: 'No hay alumnos con pocas sesiones restantes.',
                )
              : LocalizationService.pick(
                  ko: '수업이 2회 이하로 남아 연속 지도를 위해 재등록 안내가 필요합니다.',
                  en: 'These members have 2 or fewer sessions left and need renewal outreach.',
                  ja: '残回数が2回以下のため、継続受講に向けた更新案内が必要です。',
                  zh: '剩余课时不足2次，建议及时发送续费提醒。',
                  vi: 'Các hội viên còn từ 2 buổi trở xuống và cần nhắc gia hạn.',
                  es: 'Alumnos con 2 sesiones o menos que requieren aviso de renovación.',
                ),
          actionLabel: LocalizationService.pick(
            ko: '재등록 안내 순차 발송 💌',
            en: 'Send Renewal Notices 💌',
            ja: '更新案内を順次送信 💌',
            zh: '逐一发送续费提醒 💌',
            vi: 'Gửi nhắc gia hạn lần lượt 💌',
            es: 'Enviar avisos de renovación 💌',
          ),
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
                  LocalizationService.pick(
                    ko: '$count건',
                    en: '$count',
                    ja: '$count件',
                    zh: '$count 条',
                    vi: '$count',
                    es: '$count',
                  ),
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
              _buildTypeFilterChip(
                LocalizationService.pick(
                  ko: '전체 보기 (${logs.length})',
                  en: 'All (${logs.length})',
                  ja: 'すべて (${logs.length})',
                  zh: '全部 (${logs.length})',
                  vi: 'Tất cả (${logs.length})',
                  es: 'Todos (${logs.length})',
                ),
                null,
              ),
              _buildTypeFilterChip(
                LocalizationService.pick(ko: '등원 알림', en: 'Check-In', ja: '出席通知', zh: '到店通知', vi: 'Điểm danh', es: 'Llegada'),
                NotificationType.attendance,
              ),
              _buildTypeFilterChip(
                LocalizationService.pick(ko: '하원 알림', en: 'Check-Out', ja: '帰宅通知', zh: '离店通知', vi: 'Ra về', es: 'Salida'),
                NotificationType.departure,
              ),
              _buildTypeFilterChip(
                LocalizationService.pick(ko: '수납 영수증', en: 'Receipt', ja: '領収証', zh: '电子收据', vi: 'Biên nhận', es: 'Recibo'),
                NotificationType.receipt,
              ),
              _buildTypeFilterChip(
                LocalizationService.pick(ko: '수강료 청구', en: 'Billing', ja: '請求書', zh: '账单通知', vi: 'Hóa đơn', es: 'Facturación'),
                NotificationType.billing,
              ),
              _buildTypeFilterChip(
                LocalizationService.pick(ko: '미납 리마인드', en: 'Reminder', ja: '未納催促', zh: '催缴提醒', vi: 'Nhắc phí', es: 'Recordatorio'),
                NotificationType.reminder,
              ),
              _buildTypeFilterChip(
                LocalizationService.pick(ko: '만료 안내', en: 'Renewal', ja: '更新案内', zh: '到期续费', vi: 'Gia hạn', es: 'Renovación'),
                NotificationType.sessionExpiry,
              ),
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
                      Text(
                        LocalizationService.pick(
                          ko: '아직 발송된 알림 내역이 없습니다.',
                          en: 'No notification logs yet.',
                          ja: 'まだ送信された通知履歴がありません。',
                          zh: '暂无已发送的通知记录。',
                          vi: 'Chưa có lịch sử gửi thông báo nào.',
                          es: 'Aún no hay notificaciones enviadas.',
                        ),
                        style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
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
    final timeStr = LocalizationService.currentLanguage == AppLanguage.korean
        ? DateFormat('M월 d일 a h:mm', 'ko_KR').format(log.sentAt)
        : '${LocalizationService.formatDate(log.sentAt)} ${DateFormat('HH:mm').format(log.sentAt)}';
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
                      isKakao
                          ? LocalizationService.pick(ko: '카톡 0원', en: 'Shared', ja: 'アプリ共有', zh: '分享发送', vi: 'Đã chia sẻ', es: 'Compartido')
                          : LocalizationService.pick(ko: '문자(SMS)', en: 'SMS', ja: 'SMS', zh: '短信(SMS)', vi: 'SMS', es: 'SMS'),
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
            LocalizationService.pick(
              ko: '수신: ${log.memberName} (${log.recipientPhone})',
              en: 'To: ${log.memberName} (${log.recipientPhone})',
              ja: '宛先: ${log.memberName} (${log.recipientPhone})',
              zh: '收件人: ${log.memberName} (${log.recipientPhone})',
              vi: 'Người nhận: ${log.memberName} (${log.recipientPhone})',
              es: 'Para: ${log.memberName} (${log.recipientPhone})',
            ),
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
              softWrap: true,
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
              label: Text(
                LocalizationService.pick(
                  ko: '동일 내용 재발송',
                  en: 'Resend Message',
                  ja: '同じ内容で再送信',
                  zh: '重新发送相同内容',
                  vi: 'Gửi lại nội dung này',
                  es: 'Reenviar mensaje',
                ),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
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
    final supportsToss = LocalizationService.supportsTossTransfer;
    return StickyBottomSheetLayout(
      scrollBody: false,
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          Text(
            LocalizationService.pick(
              ko: '알림장 문구 즉시 수정',
              en: 'Quick Edit Alert Templates',
              ja: '通知テンプレートのクイック編集',
              zh: '快捷编辑通知文案模板',
              vi: 'Chỉnh sửa nhanh mẫu thông báo',
              es: 'Editar Plantillas Rápidas',
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            LocalizationService.pick(
              ko: '사용 가능한 자동 치환 변수: #{상호명}, #{회원명}, #{출석시간}, #{잔여회차}, #{금액}${supportsToss ? ', #{토스송금링크}' : ''}, #{카드결제링크}',
              en: 'Available variables: #{상호명}, #{회원명}, #{출석시간}, #{잔여회차}, #{금액}${supportsToss ? ', #{토스송금링크}' : ''}, #{카드결제링크}',
              ja: '使用可能な差し込み変数: #{상호명}, #{회원명}, #{출석시간}, #{잔여회차}, #{금액}${supportsToss ? ', #{토스송금링크}' : ''}, #{카드결제링크}',
              zh: '可用自动替换变量: #{상호명}, #{회원명}, #{출석시간}, #{잔여회차}, #{금액}${supportsToss ? ', #{토스송금링크}' : ''}, #{카드결제링크}',
              vi: 'Biến tự động: #{상호명}, #{회원명}, #{출석시간}, #{잔여회차}, #{금액}${supportsToss ? ', #{토스송금링크}' : ''}, #{카드결제링크}',
              es: 'Variables disponibles: #{상호명}, #{회원명}, #{출석시간}, #{잔여회차}, #{금액}${supportsToss ? ', #{토스송금링크}' : ''}, #{카드결제링크}',
            ),
            style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 16),

          // Attendance Template
          AppTextField(
            controller: _attendanceTplController,
            label: LocalizationService.pick(
              ko: '안심 등원 알림 템플릿',
              en: 'Check-In Notification Template',
              ja: '安心出席通知テンプレート',
              zh: '到店安心通知模板',
              vi: 'Mẫu thông báo điểm danh đến',
              es: 'Plantilla de aviso de llegada',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 14),

          // Departure Template
          AppTextField(
            controller: _departureTplController,
            label: LocalizationService.pick(
              ko: '안심 하원 알림 템플릿',
              en: 'Check-Out Notification Template',
              ja: '安心帰宅通知テンプレート',
              zh: '离店安心通知模板',
              vi: 'Mẫu thông báo ra về an toàn',
              es: 'Plantilla de aviso de salida',
            ),
            maxLines: 4,
          ),
          const SizedBox(height: 14),

          // Invoice Template
          AppTextField(
            controller: _invoiceTplController,
            label: LocalizationService.pick(
              ko: '수강료 청구/독촉 알림 템플릿',
              en: 'Billing / Overdue Reminder Template',
              ja: '請求・未納リマインダーテンプレート',
              zh: '账单与催缴提醒模板',
              vi: 'Mẫu hóa đơn & nhắc thanh toán',
              es: 'Plantilla de cobro y recordatorio',
            ),
            maxLines: 5,
          ),
          const SizedBox(height: 12),
        ],
      ),
      footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () async {
            final updated = studio.copyWith(
              attendanceTemplate: _attendanceTplController.text.trim(),
              departureTemplate: _departureTplController.text.trim(),
              invoiceTemplate: _invoiceTplController.text.trim(),
            );
            await ref.read(studioProfileProvider.notifier).updateProfile(updated);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    LocalizationService.pick(
                      ko: '알림장 템플릿이 성공적으로 저장되었습니다.',
                      en: 'Notification templates saved.',
                      ja: '通知テンプレートを保存しました。',
                      zh: '通知文案模板保存成功。',
                      vi: 'Đã lưu mẫu thông báo thành công.',
                      es: 'Plantillas guardadas correctamente.',
                    ),
                  ),
                ),
              );
            }
          },
          icon: const Icon(Icons.save_rounded, size: 18),
          label: Text(
            LocalizationService.pick(
              ko: '알림 템플릿 변경사항 저장하기',
              en: 'Save Alert Templates',
              ja: '通知テンプレートを保存する',
              zh: '保存通知模板修改',
              vi: 'Lưu thay đổi mẫu thông báo',
              es: 'Guardar cambios',
            ),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
    );
  }
}
