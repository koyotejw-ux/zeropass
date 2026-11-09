import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../models/custom_category_template.dart';
import '../models/vendor.dart';
import '../models/expense_item.dart';
import '../providers/app_providers.dart';
import '../services/bank_notification_filter.dart';
import '../services/coach_mark_service.dart';
import '../services/localization_service.dart';
import '../services/sms_template_service.dart';
import '../services/kakao_share_service.dart';
import '../services/data_vault_service.dart';
import '../services/monetization_service.dart';
import '../services/sequential_dispatch_service.dart';
import '../widgets/sequential_dispatch_modal.dart';
import '../widgets/receipt_notify_dialog.dart';
import '../widgets/tax_guide_modal.dart';

import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coach_mark_dialog.dart';
import '../widgets/design_system.dart';
import '../widgets/native_inline_ad_card.dart';
import '../widgets/responsive_dialog_actions.dart';

enum LedgerScreenMode {
  all, // Default: 3-tab view (for backward compatibility & widget tests)
  billingOnly, // Tab 1 (청구·수납): Focused exclusively on tuition invoicing & collection
  expenseTaxOnly, // Tab 2 (지출·세무): Focused exclusively on expenses, 3.3% payroll, vendors & tax ledger
}

class BillingLedgerScreen extends ConsumerStatefulWidget {
  final LedgerScreenMode mode;
  final int initialTab;
  final bool enableAutoCoachMark;

  const BillingLedgerScreen({
    super.key,
    this.mode = LedgerScreenMode.all,
    this.initialTab = 0,
    this.enableAutoCoachMark = true,
  });

  @override
  ConsumerState<BillingLedgerScreen> createState() => _BillingLedgerScreenState();
}

class _BillingLedgerScreenState extends ConsumerState<BillingLedgerScreen> {
  int _selectedTab = 0; // 0: 미납 / 청구 대상, 1: 수납 완료 내역, 2: 지출 / 매입 장부
  String _selectedExpenseCategory = 'all';
  String _selectedExpensePayFilter = 'all';
  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    _selectedTab = widget.mode == LedgerScreenMode.expenseTaxOnly
        ? 2
        : (widget.mode == LedgerScreenMode.billingOnly && widget.initialTab == 2
            ? 0
            : widget.initialTab);
    if (widget.enableAutoCoachMark) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CoachMarkDialog.showIfFirstTime(
          context: context,
          coachKey: CoachMarkService.keyBillingTab,
          title: '수강료 청구 및 수납 장부',
          message: '매월 나가는 수강료 청구 문자를 0원으로 보내고 입금 내역을 관리할 수 있는 장부예요.\n\n우측 하단 [+]를 누르면 동일 연락처의 형제자매까지 자동 합산하여 청구서를 작성할 수 있어요!',
          tip: '수납이 확인되면 [수납 완료] 버튼을 눌러 계좌이체/카드/현금 결제 수단별로 깔끔하게 장부에 기록하세요.',
          buttonText: '장부 둘러보기',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    ref.watch(currencyProvider);
    final invoicesAsync = ref.watch(invoicesProvider);
    final membersAsync = ref.watch(membersProvider);
    final studioAsync = ref.watch(studioProfileProvider);
    final expensesAsync = ref.watch(expensesProvider);
    final vendorsAsync = ref.watch(vendorsProvider);
    final isSeniorMode = ref.watch(seniorModeProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    final String appBarTitle = widget.mode == LedgerScreenMode.expenseTaxOnly
        ? LocalizationService.tr('tab_tax_expense')
        : widget.mode == LedgerScreenMode.billingOnly
            ? LocalizationService.tr('tab_billing')
            : LocalizationService.tr('billing_title');

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(appBarTitle),
        ),
        actions: [
          // 1. 간편장부 엑셀 내보내기 & 세무 가이드 (심플 라인 아이콘)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.table_view_outlined, size: 21, color: Color(0xFF3F3F46)),
              tooltip: '간편장부 엑셀 & 세무',
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () => _showBookkeepingExportSheet(context),
            ),
          ),
          // 2. 세무 장부 모드 시 세무 일정 가이드 퀵 아이콘
          if (widget.mode == LedgerScreenMode.expenseTaxOnly)
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                icon: const Icon(Icons.menu_book_outlined, size: 21, color: Color(0xFF3F3F46)),
                tooltip: '소상공인 세무 가이드',
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                visualDensity: VisualDensity.compact,
                onPressed: () => TaxGuideModal.show(context),
              ),
            ),
          // 3. 거래처 수첩 or 실시간 입금 감지 (심플 라인 아이콘)
          if (_selectedTab == 2 || widget.mode == LedgerScreenMode.expenseTaxOnly)
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                icon: const Icon(Icons.business_center_outlined, size: 21, color: Color(0xFF4F46E5)),
                tooltip: '거래처 수첩',
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final vendors = vendorsAsync.value ?? [];
                  _openVendorManagementSheet(context, vendors);
                },
              ),
            )
          else
            SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                icon: const Icon(Icons.notifications_active_outlined, size: 21, color: Color(0xFF059669)),
                tooltip: '실시간 입금 감지',
                splashRadius: 20,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  final members = membersAsync.value ?? [];
                  final unpaid = (invoicesAsync.value ?? []).where((i) => i.status == PaymentStatus.unpaid).toList();
                  _showBankNotificationSimulator(context, members, unpaid);
                },
              ),
            ),
          // 4. 시니어 큰글씨 모드 퀵 토글 (공통 규격: 가장 우측 배치)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: Icon(
                Icons.format_size_rounded,
                size: 21,
                color: isSeniorMode ? AppTheme.trustBlue : const Color(0xFF3F3F46),
              ),
              tooltip: '큰글씨 모드',
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(seniorModeProvider.notifier).toggle(),
            ),
          ),
        ],
      ),
      body: invoicesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('청구 내역 오류: $err')),
        data: (invoices) {
          return membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('회원 로딩 오류: $err')),
            data: (members) {
              final studio = studioAsync.value ?? StudioProfile.defaultProfile();
              final memberMap = {for (var m in members) m.id: m};

              final unpaidInvoices = invoices.where((i) => i.status == PaymentStatus.unpaid).toList();
              final paidInvoices = invoices.where((i) => i.status == PaymentStatus.paid).toList();

              final totalUnpaidAmount = unpaidInvoices.fold<int>(0, (sum, i) => sum + i.amount);
              final totalPaidAmount = paidInvoices.fold<int>(0, (sum, i) => sum + i.amount);

              final expenses = expensesAsync.value ?? [];
              final vendors = vendorsAsync.value ?? [];
              final paidExpenses = expenses.where((e) => e.isPaid).toList();
              final unpaidExpenses = expenses.where((e) => !e.isPaid).toList();
              final totalExpenseAmount = expenses.fold<int>(0, (sum, e) => sum + e.amount);
              final netProfit = totalPaidAmount - totalExpenseAmount;

              // 회차 만료 임박 회원 (1회 이하)
              final expiringMembers = members
                  .where((m) => m.billingType == BillingType.sessionBased && m.remainingSessions <= 1)
                  .toList();

              final currentList = _selectedTab == 0 ? unpaidInvoices : paidInvoices;

              final Color cardBorderColor = _selectedTab == 0
                  ? const Color(0xFFF59E0B).withAlpha((255 * 0.25).round())
                  : _selectedTab == 1
                      ? const Color(0xFF10B981).withAlpha((255 * 0.25).round())
                      : const Color(0xFFF43F5E).withAlpha((255 * 0.25).round());

              final IconData heroIcon = _selectedTab == 0
                  ? Icons.pending_actions_rounded
                  : _selectedTab == 1
                      ? Icons.check_circle_rounded
                      : Icons.shopping_bag_outlined;

              final Color heroIconColor = _selectedTab == 0
                  ? const Color(0xFFFBBF24)
                  : _selectedTab == 1
                      ? const Color(0xFF34D399)
                      : const Color(0xFFFB7185);

              final String heroTitle = _selectedTab == 0
                  ? LocalizationService.tr('hero_unpaid_title')
                  : _selectedTab == 1
                      ? LocalizationService.tr('hero_paid_title')
                      : LocalizationService.tr('hero_expense_title');

              final int heroAmount = _selectedTab == 0
                  ? totalUnpaidAmount
                  : _selectedTab == 1
                      ? totalPaidAmount
                      : totalExpenseAmount;

              final Color badgeBgColor = _selectedTab == 0
                  ? const Color(0xFFD97706).withAlpha((255 * 0.22).round())
                  : _selectedTab == 1
                      ? const Color(0xFF059669).withAlpha((255 * 0.22).round())
                      : const Color(0xFFE11D48).withAlpha((255 * 0.22).round());

              final Color badgeBorderColor = _selectedTab == 0
                  ? const Color(0xFFF59E0B)
                  : _selectedTab == 1
                      ? const Color(0xFF10B981)
                      : const Color(0xFFF43F5E);

              final IconData badgeIcon = _selectedTab == 0
                  ? Icons.error_outline_rounded
                  : _selectedTab == 1
                      ? Icons.verified_rounded
                      : Icons.account_balance_wallet_outlined;

              final Color badgeTextColor = _selectedTab == 0
                  ? const Color(0xFFFDE68A)
                  : _selectedTab == 1
                      ? const Color(0xFFA7F3D0)
                      : const Color(0xFFFECDD3);

              final String badgeText = _selectedTab == 0
                  ? '${unpaidInvoices.length}건 미납 대기'
                  : _selectedTab == 1
                      ? '${paidInvoices.length}건 완납'
                      : '${expenses.length}건 지출 (${paidExpenses.length}건 완납 / ${unpaidExpenses.length}건 대기)';

              final String infoBarLeftText = _selectedTab == 0
                  ? '전체 ${invoices.length}건 중 ${paidInvoices.length}건 수납'
                  : '당월 순이익: ${netProfit >= 0 ? '+' : ''}${LocalizationService.formatAmount(netProfit)} (${netProfit >= 0 ? '흑자' : '적자'})';

              final String infoBarRightText = _selectedTab == 0
                  ? '완납: ${LocalizationService.formatAmount(totalPaidAmount)}'
                  : _selectedTab == 1
                      ? '지출: ${LocalizationService.formatAmount(totalExpenseAmount)}'
                      : '수납: ${LocalizationService.formatAmount(totalPaidAmount)}';

              final Color infoBarRightColor = _selectedTab == 0
                  ? const Color(0xFF34D399)
                  : _selectedTab == 1
                      ? const Color(0xFFFB7185)
                      : const Color(0xFF34D399);

              return CustomScrollView(
                slivers: [
                  // 1. Amount Metric Overview Card & Notice Banners (Scrollable with body)
                  SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: isLandscape ? 4 : 8,
                          ),
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: isLandscape ? 12 : 18,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha((255 * 0.25).round()),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                              border: Border.all(
                                color: cardBorderColor,
                                width: 1.2,
                              ),
                            ),
                            child: isLandscape
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: FittedBox(
                                          fit: BoxFit.scaleDown,
                                          alignment: Alignment.centerLeft,
                                          child: Row(
                                            children: [
                                              Icon(
                                                heroIcon,
                                                color: heroIconColor,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '$heroTitle: ',
                                                style: const TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              Text(
                                                LocalizationService.formatAmount(heroAmount),
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 22,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: -0.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                        decoration: BoxDecoration(
                                          color: badgeBgColor,
                                          borderRadius: BorderRadius.circular(20),
                                          border: Border.all(
                                            color: badgeBorderColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              badgeIcon,
                                              size: 13,
                                              color: badgeTextColor,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              badgeText,
                                              style: TextStyle(
                                                color: badgeTextColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  )
                                : Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Header Row: Category Icon & Title + Status Badge (with responsive wrap)
                                      Wrap(
                                        alignment: WrapAlignment.spaceBetween,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(6),
                                                decoration: BoxDecoration(
                                                  color: heroIconColor.withAlpha((255 * 0.18).round()),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  heroIcon,
                                                  color: heroIconColor,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                heroTitle,
                                                style: const TextStyle(
                                                  color: Color(0xFF94A3B8),
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                                            decoration: BoxDecoration(
                                              color: badgeBgColor,
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: badgeBorderColor,
                                                width: 1,
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  badgeIcon,
                                                  size: 13,
                                                  color: badgeTextColor,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  badgeText,
                                                  style: TextStyle(
                                                    color: badgeTextColor,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Hero Amount Typography
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          LocalizationService.formatAmount(heroAmount),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 32,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: -1.0,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 14),

                                      // Secondary Info Bar
                                      Container(
                                        width: double.infinity,
                                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha((255 * 0.05).round()),
                                          borderRadius: BorderRadius.circular(12),
                                          border: Border.all(color: Colors.white.withAlpha((255 * 0.08).round())),
                                        ),
                                        child: Wrap(
                                          alignment: WrapAlignment.spaceBetween,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          spacing: 10,
                                          runSpacing: 4,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  Icons.pie_chart_outline_rounded,
                                                  size: 14,
                                                  color: Colors.white.withAlpha((255 * 0.6).round()),
                                                ),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    infoBarLeftText,
                                                    softWrap: true,
                                                    style: TextStyle(
                                                      color: Colors.white.withAlpha((255 * 0.75).round()),
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            Text(
                                              infoBarRightText,
                                              style: TextStyle(
                                                color: infoBarRightColor,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),

                        // Expiring Sessions Warning Strip (with one-tap warning SMS)
                        if (_selectedTab == 0 && expiringMembers.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ZeroNoticeBanner(
                              variant: ZeroBannerVariant.care,
                              icon: Icons.warning_amber_rounded,
                              title: '${LocalizationService.tr("expiring_banner_title")} (${expiringMembers.length})',
                              subtitle: expiringMembers.map((m) => m.name.split(' ').first).join(', '),
                              actionLabel: LocalizationService.tr('expiring_banner_btn'),
                              onAction: () => _sendExpiryAlert(context, studio, expiringMembers.first),
                            ),
                          ),

                        // 미납자 전체 순차 릴레이 독촉 발송 배너
                        if (_selectedTab == 0 && unpaidInvoices.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: ZeroNoticeBanner(
                              variant: ZeroBannerVariant.info,
                              icon: Icons.mark_chat_unread_outlined,
                              title: LocalizationService.tr('unpaid_members_waiting').replaceAll('{count}', unpaidInvoices.length.toString()),
                              trailing: InkWell(
                                onTap: () {
                                  final unpaidMemberIds = unpaidInvoices.expand((i) => i.memberIds).toSet();
                                  final unpaidMembersList = members.where((m) => unpaidMemberIds.contains(m.id)).toList();
                                  SequentialDispatchModal.show(
                                    context: context,
                                    allMembers: unpaidMembersList,
                                    studio: studio,
                                    invoices: unpaidInvoices,
                                    initialTemplateType: DispatchTemplateType.billing,
                                  );
                                },
                                borderRadius: BorderRadius.circular(8),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primaryBlue,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.forward_to_inbox_rounded, size: 13, color: Colors.white),
                                      const SizedBox(width: 4),
                                      Text(
                                        LocalizationService.tr('batch_dispatch_btn'),
                                        style: TextStyle(
                                          fontFamily: 'Pretendard',
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
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

                  // 2. Sticky Pinned Sub-tabs / Hub Header
                  SliverPersistentHeader(
                    pinned: true,
                    delegate: _BillingTabHeaderDelegate(
                      height: (widget.mode == LedgerScreenMode.expenseTaxOnly) ? 56.0 : 52.0,
                      child: (widget.mode == LedgerScreenMode.expenseTaxOnly)
                          ? Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _buildQuickTaxActionTile(
                                      icon: Icons.business_center_outlined,
                                      label: '${LocalizationService.tr("vendors_label")} (${vendors.length})',
                                      color: const Color(0xFF4F46E5),
                                      onTap: () => _openVendorManagementSheet(context, vendors),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildQuickTaxActionTile(
                                      icon: Icons.table_view_outlined,
                                      label: LocalizationService.tr('simple_bookkeeping_excel'),
                                      color: const Color(0xFF059669),
                                      onTap: () => _showBookkeepingExportSheet(context),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildQuickTaxActionTile(
                                      icon: Icons.menu_book_outlined,
                                      label: LocalizationService.tr('tax_guide_1min'),
                                      color: AppTheme.primaryBlue,
                                      onTap: () => TaxGuideModal.show(context),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppTheme.chipBackground,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                padding: const EdgeInsets.all(3),
                                child: Row(
                                  children: [
                                    _buildTabButton('${LocalizationService.tr("unpaid_tab_short")} (${unpaidInvoices.length})', 0),
                                    _buildTabButton('${LocalizationService.tr("paid_tab_short")} (${paidInvoices.length})', 1),
                                    if (widget.mode == LedgerScreenMode.all)
                                      _buildTabButton('${LocalizationService.tr("expense_tab_short")} (${expenses.length})', 2),
                                  ],
                                ),
                              ),
                            ),
                    ),
                  ),

                  // 3. Invoice or Expense Slivers
                  if (_selectedTab == 2)
                    ..._buildExpenseSlivers(context, expenses, vendors, studio)
                  else if (currentList.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.receipt_long_outlined, size: 52, color: AppTheme.textTertiary),
                              const SizedBox(height: 14),
                              Text(
                                _selectedTab == 0 ? LocalizationService.tr('empty_unpaid_title') : LocalizationService.tr('empty_paid_title'),
                                style: const TextStyle(
                                  fontFamily: 'Pretendard',
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                '우측 하단 [+] 또는 아래 버튼을 눌러\n첫 청구서를 간편하게 발행해보세요.',
                                textAlign: TextAlign.center,
                                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final members = membersAsync.value ?? [];
                                  final studio = studioAsync.value ?? StudioProfile.defaultProfile();
                                  _openQuickInvoiceSheet(context, members, studio);
                                },
                                icon: const Icon(Icons.add, size: 18, color: AppTheme.primaryBlue),
                                label: const Text('첫 청구서 작성하기', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700, fontSize: 14)),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppTheme.primaryBlue,
                                  side: const BorderSide(color: AppTheme.primaryBlue, width: 1.2),
                                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.05),
                                  padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            if (index == currentList.length) {
                              return const NativeInlineAdCard(placementTag: 'billing_list');
                            }
                            final invoice = currentList[index];
                            final invoiceMembers = invoice.memberIds
                                .map((id) => memberMap[id])
                                .whereType<Member>()
                                .toList();

                            return _buildInvoiceCard(context, invoice, invoiceMembers, studio);
                          },
                          childCount: currentList.length + 1,
                        ),
                      ),
                    ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: (_selectedTab == 2 || widget.mode == LedgerScreenMode.expenseTaxOnly)
          ? FloatingActionButton.extended(
              heroTag: 'fab_expense_${widget.mode.name}',
              onPressed: () {
                final curVendors = vendorsAsync.value ?? [];
                _openAddExpenseSheet(context, curVendors);
              },
              backgroundColor: const Color(0xFFE11D48),
              elevation: 3,
              icon: const Icon(Icons.add_shopping_cart_rounded, color: Colors.white, size: 20),
              label: Text(
                LocalizationService.tr('new_expense_btn'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Colors.white, letterSpacing: -0.2),
              ),
            )
          : FloatingActionButton.extended(
              heroTag: 'fab_billing_${widget.mode.name}',
              onPressed: () {
                final members = membersAsync.value ?? [];
                final studio = studioAsync.value ?? StudioProfile.defaultProfile();
                _openQuickInvoiceSheet(context, members, studio);
              },
              backgroundColor: AppTheme.fabPrimary,
              elevation: 3,
              icon: const Icon(Icons.edit_note, color: Colors.white, size: 21),
              label: Text(
                LocalizationService.tr('create_invoice'),
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Colors.white, letterSpacing: -0.2),
              ),
            ),
    );
  }

  Widget _buildQuickTaxActionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.borderSubtle, width: 0.9),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 5),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int tabIndex) {
    final isSelected = _selectedTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tabIndex),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isSelected ? AppTheme.cardShadow : null,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

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

  Widget _buildInvoiceCard(
    BuildContext context,
    Invoice invoice,
    List<Member> invoiceMembers,
    StudioProfile studio,
  ) {
    final isSeniorMode = ref.watch(seniorModeProvider);
    final isPaid = invoice.status == PaymentStatus.paid;
    final memberNames = invoiceMembers.map((m) => m.name).join(', ');
    final dateLabel = isPaid ? LocalizationService.tr('paid_date_label') : LocalizationService.tr('due_date_label');
    final dateValue = isPaid && invoice.paidAt != null
        ? LocalizationService.formatDate(invoice.paidAt!)
        : LocalizationService.formatDate(invoice.dueDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isPaid ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isPaid ? AppTheme.borderSubtle : const Color(0xFFE2E8F0),
          width: 0.9,
        ),
        boxShadow: isPaid ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Meta Row: Tier-2 Semantic Status Badge (Left) <-> Tier-4 Date Caption (Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    isPaid
                        ? ZeroBadge.success(LocalizationService.tr('paid_status'), size: ZeroBadgeSize.medium)
                        : ZeroBadge.danger(LocalizationService.tr('unpaid_status'), size: ZeroBadgeSize.medium),
                    if (!isPaid && studio.cardPaymentEnabled && studio.cardPaymentUrl.trim().isNotEmpty)
                      ZeroBadge(
                        label: LocalizationService.tr('card_link_integrated'),
                        variant: ZeroBadgeVariant.neutral,
                        size: ZeroBadgeSize.small,
                        icon: Icons.link_rounded,
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '$dateLabel $dateValue',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textTertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Mobile-First Vertical Focal Stack: Tier-1 Amount -> Tier-2 Title -> Tier-3 Member & Phone (Zero Truncation!)
          Text(
            LocalizationService.formatAmount(invoice.amount),
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w900,
              color: isPaid ? AppTheme.softMint : AppTheme.textPrimary,
              letterSpacing: -0.7,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            invoice.title,
            softWrap: true,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          // Sub-info: member badges & phone pill cluster (clean structured badges!)
          Wrap(
            spacing: 6,
            runSpacing: 5,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (invoiceMembers.isNotEmpty)
                for (final m in invoiceMembers)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                    ),
                    child: Text(
                      m.name,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF334155),
                      ),
                    ),
                  )
              else if (memberNames.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                  ),
                  child: Text(
                    memberNames,
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF334155),
                    ),
                  ),
                ),
              if (invoice.recipientPhone.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7.5, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFFDBEAFE), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.phone_iphone_rounded, size: 12.5, color: Color(0xFF2563EB)),
                      const SizedBox(width: 3.5),
                      Text(
                        _formatPhone(invoice.recipientPhone),
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1D4ED8),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Action Hierarchy: 1 Solid Primary CTA + Secondary 2-Column Row (Zero Cramming!)
          if (!isPaid) ...[
            // Tier 1 Primary Action: 수납확인 완료 처리 (Full-width solid Royal Blue CTA, minHeight 52)
            ZeroButton.primary(
              label: LocalizationService.tr('mark_paid'),
              icon: Icons.check_circle_outline_rounded,
              fullWidth: true,
              size: ZeroButtonSize.large,
              onPressed: () => _showPaymentConfirmDialog(context, invoice, invoiceMembers, studio),
            ),
            const SizedBox(height: 8),

            // Tier 2: 2 Clean Equal Utility Buttons (1 Column Full-Width in Senior Mode)
            if (isSeniorMode) ...[
              ZeroButton(
                label: LocalizationService.tr('kakao_invoice_btn'),
                icon: Icons.chat_bubble_outline_rounded,
                variant: ZeroButtonVariant.neutral,
                size: ZeroButtonSize.large,
                fullWidth: true,
                onPressed: () async {
                  final kakaoMsg = KakaoShareService.generateInvoiceKakaoMessage(
                    studio: studio,
                    members: invoiceMembers,
                    invoice: invoice,
                  );
                  await KakaoShareService.shareMessage(
                    text: kakaoMsg,
                    subject: '[${studio.studioName}] 수강료 청구 안내',
                  );
                },
              ),
              const SizedBox(height: 8),
              ZeroButton(
                label: LocalizationService.tr('sms_invoice_btn'),
                icon: Icons.sms_outlined,
                variant: ZeroButtonVariant.neutral,
                size: ZeroButtonSize.large,
                fullWidth: true,
                onPressed: () => _sendSmsInvoice(context, studio, invoiceMembers, invoice),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: ZeroButton(
                      label: LocalizationService.tr('kakao_invoice_btn'),
                      icon: Icons.chat_bubble_outline_rounded,
                      variant: ZeroButtonVariant.neutral,
                      size: ZeroButtonSize.medium,
                      fullWidth: true,
                      onPressed: () async {
                        final kakaoMsg = KakaoShareService.generateInvoiceKakaoMessage(
                          studio: studio,
                          members: invoiceMembers,
                          invoice: invoice,
                        );
                        await KakaoShareService.shareMessage(
                          text: kakaoMsg,
                          subject: '[${studio.studioName}] 수강료 청구 안내',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ZeroButton(
                      label: LocalizationService.tr('sms_invoice_btn'),
                      icon: Icons.sms_outlined,
                      variant: ZeroButtonVariant.neutral,
                      size: ZeroButtonSize.medium,
                      fullWidth: true,
                      onPressed: () => _sendSmsInvoice(context, studio, invoiceMembers, invoice),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 8),

            // Tier 3: Full-width Tint Reminder CTA
            ZeroButton(
              label: LocalizationService.tr('remind_1sec'),
              icon: Icons.notifications_none_rounded,
              variant: ZeroButtonVariant.tint,
              size: isSeniorMode ? ZeroButtonSize.large : ZeroButtonSize.medium,
              fullWidth: true,
              onPressed: () {
                final reminderMsg = SmsTemplateService.generateUnpaidReminderMessage(
                  studio: studio,
                  members: invoiceMembers,
                  invoice: invoice,
                );
                SmsTemplateService.launchNativeSms(
                  recipientPhone: invoice.recipientPhone,
                  body: reminderMsg,
                );
              },
            ),
          ] else ...[
            // Paid Invoice Utilities (1 Column Full-Width in Senior Mode)
            if (isSeniorMode) ...[
              ZeroButton.secondary(
                label: LocalizationService.tr('receipt_notice_btn'),
                icon: Icons.receipt_long_rounded,
                size: ZeroButtonSize.large,
                fullWidth: true,
                onPressed: () async {
                  if (invoiceMembers.isEmpty) return;
                  ReceiptNotifyDialog.show(
                    context: context,
                    member: invoiceMembers.first,
                    invoice: invoice,
                    studio: studio,
                  );
                },
              ),
              const SizedBox(height: 8),
              ZeroButton.secondary(
                label: LocalizationService.tr('receipt_sms_btn'),
                icon: Icons.sms_outlined,
                size: ZeroButtonSize.large,
                fullWidth: true,
                onPressed: () => _sendReceiptSms(context, studio, invoiceMembers, invoice),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: ZeroButton.secondary(
                      label: LocalizationService.tr('receipt_notice_btn'),
                      icon: Icons.receipt_long_rounded,
                      size: ZeroButtonSize.medium,
                      fullWidth: true,
                      onPressed: () async {
                        if (invoiceMembers.isEmpty) return;
                        ReceiptNotifyDialog.show(
                          context: context,
                          member: invoiceMembers.first,
                          invoice: invoice,
                          studio: studio,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ZeroButton.secondary(
                      label: LocalizationService.tr('receipt_sms_btn'),
                      icon: Icons.sms_outlined,
                      size: ZeroButtonSize.medium,
                      fullWidth: true,
                      onPressed: () => _sendReceiptSms(context, studio, invoiceMembers, invoice),
                    ),
                  ),
                ],
              ),
          ],
        ],
      ),
    );
  }

  void _sendSmsInvoice(
    BuildContext context,
    StudioProfile studio,
    List<Member> members,
    Invoice invoice,
  ) {
    final defaultMessage = SmsTemplateService.generateInvoiceMessage(
      studio: studio,
      members: members,
      invoice: invoice,
    );

    final textController = TextEditingController(text: defaultMessage);

    AppBottomSheet.show(
      context: context,
      builder: (ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '청구서 전송 방법 선택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '수신: ${invoice.recipientPhone} (토스 1초 무료 송금 링크 자동 포함)',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),

              // 1. 카카오톡 0원 직접 전송 버튼 (최우선 추천)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final kakaoMsg = KakaoShareService.generateInvoiceKakaoMessage(
                      studio: studio,
                      members: members,
                      invoice: invoice,
                    );
                    final ok = await KakaoShareService.shareMessage(
                      text: kakaoMsg,
                      subject: '[${studio.studioName}] 수강료 청구 안내',
                    );
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('카카오톡 공유가 실행되었습니다. (복사 완료)'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF191919), size: 17),
                  label: const Text(
                    '카카오톡 0원 전송 (토스 간편송금 포함)',
                    style: TextStyle(color: Color(0xFF191919), fontWeight: FontWeight.w800, fontSize: 14.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: const Color(0xFF191919),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              AppTextField(
                controller: textController,
                label: '문자 본문 내용 (수정 가능)',
                maxLines: 6,
              ),
              const SizedBox(height: 14),
              ResponsiveDialogActions(
                breakpoint: 320,
                secondary: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(LocalizationService.tr('btn_cancel')),
                ),
                primary: ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final success = await SmsTemplateService.launchNativeSms(
                      recipientPhone: invoice.recipientPhone,
                      body: textController.text.trim(),
                    );
                    if (!success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('문자 앱을 실행할 수 없습니다. 번호를 확인해주세요.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
                  label: const Text('기본 문자 앱으로 전송'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _sendReceiptSms(
    BuildContext context,
    StudioProfile studio,
    List<Member> members,
    Invoice invoice,
  ) async {
    if (members.isEmpty) return;
    final msg = SmsTemplateService.generatePaymentReceiptMessage(
      studio: studio,
      member: members.first,
      amount: invoice.amount,
      paymentMethod: invoice.paymentMethod ?? 'TRANSFER',
      remainingSessions: members.first.billingType == BillingType.sessionBased ? members.first.remainingSessions : null,
    );
    await SmsTemplateService.launchNativeSms(recipientPhone: invoice.recipientPhone, body: msg);
  }

  void _sendExpiryAlert(BuildContext context, StudioProfile studio, Member member) async {
    final msg = SmsTemplateService.generateExpiryWarningMessage(studio: studio, member: member);
    await SmsTemplateService.launchNativeSms(recipientPhone: member.phone, body: msg);
  }

  void _showPaymentConfirmDialog(
    BuildContext context,
    Invoice invoice,
    List<Member> invoiceMembers,
    StudioProfile studio,
  ) {
    AppBottomSheet.show(
      context: context,
      builder: (ctx) {
        return Material(
          color: Colors.transparent,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryBlue, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '수납 완료 처리',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${invoice.title} (${LocalizationService.formatAmount(invoice.amount)})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                      splashRadius: 18,
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.account_balance, color: AppTheme.primaryBlue),
                  ),
                  title: '계좌 입금 확인',
                  subtitle: '은행 통장으로 실시간 무통장 입금 완료',
                  onTap: () => _confirmPayment(ctx, invoice, 'TRANSFER', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFECFDF5),
                    child: Icon(Icons.credit_card, color: AppTheme.softMint),
                  ),
                  title: '오프라인 카드 단말기 (현장 결제)',
                  subtitle: '매장/학원 현장 신용·체크카드 결제',
                  onTap: () => _confirmPayment(ctx, invoice, 'OFFLINE_CARD', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.link_rounded, color: AppTheme.primaryBlue),
                  ),
                  title: '비대면 신용카드 결제 (원격 결제 링크)',
                  subtitle: '토스페이먼츠/페이앱/결제선생 원격 링크 승인 확인',
                  onTap: () => _confirmPayment(ctx, invoice, 'ONLINE_CARD', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.qr_code_scanner, color: Color(0xFFD97706)),
                  ),
                  title: '간편결제 (카카오페이 / 토스 / 제로페이 QR)',
                  subtitle: '매장 비치 QR 코드 또는 송금 링크 결제',
                  onTap: () => _confirmPayment(ctx, invoice, 'EASY_PAY', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3E8FF),
                    child: Icon(Icons.card_giftcard, color: Color(0xFF9333EA)),
                  ),
                  title: '지역화폐 · 교육/스포츠 바우처',
                  subtitle: '지역사랑상품권, 평생교육바우처, 스포츠강좌이용권',
                  onTap: () => _confirmPayment(ctx, invoice, 'VOUCHER', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFFBEB),
                    child: Icon(Icons.payments_outlined, color: AppTheme.warning),
                  ),
                  title: '현금 수납',
                  subtitle: '현장 현금 수령 및 간이 영수',
                  onTap: () => _confirmPayment(ctx, invoice, 'CASH', invoiceMembers, studio),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPaymentMethodTile({
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFF8FAFC),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          leading: leading,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          trailing: const Icon(Icons.arrow_forward_ios, size: 13, color: AppTheme.textSecondary),
          onTap: onTap,
        ),
      ),
    );
  }

  void _confirmPayment(
    BuildContext sheetContext,
    Invoice invoice,
    String method,
    List<Member> invoiceMembers,
    StudioProfile studio,
  ) async {
    Navigator.pop(sheetContext);
    await ref.read(invoicesProvider.notifier).markAsPaid(
          invoiceId: invoice.id,
          paymentMethod: method,
        );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${invoice.title} 수납 처리가 완료되었습니다.'),
          action: SnackBarAction(
            label: '영수증 알림',
            textColor: const Color(0xFFFEE500),
            onPressed: () {
              if (invoiceMembers.isNotEmpty) {
                ReceiptNotifyDialog.show(
                  context: context,
                  member: invoiceMembers.first,
                  invoice: invoice.copyWith(status: PaymentStatus.paid, paymentMethod: method, paidAt: DateTime.now()),
                  studio: studio,
                );
              }
            },
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ==========================================
  // 체크인 페이: 지출/매입 장부 및 거래처 관리 UI
  // ==========================================

  List<Widget> _buildExpenseSlivers(
    BuildContext context,
    List<ExpenseItem> expenses,
    List<Vendor> vendors,
    StudioProfile studio,
  ) {
    final payFilters = [
      (id: 'all', label: LocalizationService.tr('filter_all')),
      (id: 'paid', label: LocalizationService.tr('filter_paid')),
      (id: 'unpaid', label: LocalizationService.tr('filter_unpaid')),
    ];
    final categoryFilters = [
      (id: 'all', label: LocalizationService.tr('filter_all')),
      (id: '교재비', label: '교재비'),
      (id: '임대료', label: '임대료'),
      (id: '강사료', label: '강사료'),
      (id: '소모품비', label: '소모품비'),
      (id: '시설관리', label: '시설관리'),
      (id: '공과금', label: '공과금'),
      (id: '기타', label: '기타'),
    ];

    var filtered = List<ExpenseItem>.from(expenses);
    if (_selectedExpensePayFilter == 'paid') {
      filtered = filtered.where((e) => e.isPaid).toList();
    } else if (_selectedExpensePayFilter == 'unpaid') {
      filtered = filtered.where((e) => !e.isPaid).toList();
    }
    if (_selectedExpenseCategory != 'all') {
      filtered = filtered.where((e) => e.category == _selectedExpenseCategory).toList();
    }
    filtered.sort((a, b) => b.date.compareTo(a.date));

    return [
      // 1. Filter strip (결제상태 & 카테고리)
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // 결제 상태 필터
                ...payFilters.map((p) {
                  final isSel = _selectedExpensePayFilter == p.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        p.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : AppTheme.textSecondary,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: AppTheme.primaryDark,
                      backgroundColor: const Color(0xFFF4F4F5),
                      checkmarkColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isSel ? AppTheme.primaryDark : Colors.transparent),
                      ),
                      onSelected: (val) {
                        if (val) setState(() => _selectedExpensePayFilter = p.id);
                      },
                    ),
                  );
                }),
                const SizedBox(width: 6),
                Container(height: 18, width: 1, color: AppTheme.borderSubtle),
                const SizedBox(width: 8),
                // 카테고리 필터
                ...categoryFilters.map((c) {
                  final isSel = _selectedExpenseCategory == c.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip(
                      label: Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? AppTheme.primaryBlue : AppTheme.textSecondary,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: const Color(0xFFEFF6FF),
                      backgroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: isSel ? AppTheme.primaryBlue : AppTheme.borderSubtle),
                      ),
                      onSelected: (val) {
                        setState(() => _selectedExpenseCategory = val ? c.id : 'all');
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),

      // 2. List or Empty state
      if (filtered.isEmpty)
        SliverFillRemaining(
          hasScrollBody: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet_outlined, size: 52, color: Color(0xFFCBD5E1)),
                  const SizedBox(height: 14),
                  const Text(
                    '기록된 지출/매입 내역이 없습니다',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '학원·스튜디오 운영에 지출된 교재비, 임대료, 강사료를 기록하고\n실시간 손익과 순이익을 한눈에 관리하세요.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => _openAddExpenseSheet(context, vendors),
                    icon: const Icon(Icons.add, size: 18, color: AppTheme.primaryBlue),
                    label: const Text(
                      '첫 지출 등록하기',
                      style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.primaryBlue,
                      side: const BorderSide(color: AppTheme.primaryBlue, width: 1.2),
                      backgroundColor: const Color(0xFFEFF6FF),
                      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 90),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (ctx, idx) {
                if (idx == filtered.length) {
                  return const NativeInlineAdCard(placementTag: 'expense_list');
                }
                final exp = filtered[idx];
                return _buildExpenseCard(context, exp, vendors, studio);
              },
              childCount: filtered.length + 1,
            ),
          ),
        ),
    ];
  }

  Widget _buildExpenseCard(
    BuildContext context,
    ExpenseItem expense,
    List<Vendor> vendors,
    StudioProfile studio,
  ) {
    final isSeniorMode = ref.watch(seniorModeProvider);
    final vendor = vendors.where((v) => v.id == expense.vendorId || v.name == expense.vendorName).firstOrNull;
    final dateStr = DateFormat('yyyy.MM.dd').format(expense.date);
    final isInstructor = expense.category == '강사료' || vendor?.category == '강사/코치료';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: expense.isPaid ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: expense.isPaid ? null : AppTheme.cardShadow,
        border: Border.all(
          color: expense.isPaid ? AppTheme.borderSubtle : const Color(0xFFFECACA),
          width: expense.isPaid ? 0.9 : 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Header: Tier-3 Category & Metadata (Left) <-> Tier-2 Semantic Status Pill (Right)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ZeroBadge.neutral(expense.category, size: ZeroBadgeSize.small),
                    Text(
                      '$dateStr · ${expense.taxEvidence}',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              expense.isPaid
                  ? ZeroBadge.success(
                      LocalizationService.tr('filter_paid'),
                      icon: Icons.check_circle_outline,
                      size: ZeroBadgeSize.medium,
                      onTap: () async {
                        await ref.read(expensesProvider.notifier).togglePaymentStatus(expense.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LocalizationService.tr('status_changed_unpaid')),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    )
                  : ZeroBadge.danger(
                      LocalizationService.tr('unpaid_expense_status'),
                      icon: Icons.pending_actions_outlined,
                      size: ZeroBadgeSize.medium,
                      onTap: () async {
                        await ref.read(expensesProvider.notifier).togglePaymentStatus(expense.id);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LocalizationService.tr('status_changed_paid')),
                              behavior: SnackBarBehavior.floating,
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        }
                      },
                    ),
            ],
          ),
          const SizedBox(height: 10),

          // 2. Mobile-First Vertical Focal Stack: Tier-1 Amount -> Tier-2 Expense Title -> Tier-3 Vendor & Bank Account (Zero Truncation!)
          Text(
            '- ${LocalizationService.formatAmount(expense.amount)}',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: expense.isPaid ? AppTheme.textPrimary : AppTheme.danger,
              letterSpacing: -0.7,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            expense.title,
            softWrap: true,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
              letterSpacing: -0.3,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),

          // 3. Inset Grouped Metadata Container (Vendor, Account, Memo, Withholding Tax)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Vendor & Account Row
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.storefront_outlined, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            expense.vendorName,
                            softWrap: true,
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ),
                      ],
                    ),
                    if (vendor?.bankName != null && vendor?.accountNumber != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFCBD5E1), width: 0.6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.account_balance_outlined, size: 12, color: Color(0xFF475569)),
                            const SizedBox(width: 3.5),
                            Text(
                              '${vendor!.bankName} ${vendor.accountNumber}',
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                            const SizedBox(width: 5),
                            InkWell(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: '${vendor.bankName} ${vendor.accountNumber} ${vendor.accountHolder ?? ''}'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${vendor.bankName} 계좌번호가 복사되었습니다.'), behavior: SnackBarBehavior.floating),
                                );
                              },
                              child: const Icon(Icons.copy_rounded, size: 12, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                if (expense.memo != null && expense.memo!.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(Icons.description_outlined, size: 13, color: AppTheme.textTertiary),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          expense.memo!,
                          softWrap: true,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.3),
                        ),
                      ),
                    ],
                  ),
                ],
                if (expense.isWithholdingApplied) ...[
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => _showStaffSettlementModal(context, expense, vendor, studio),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFDBEAFE), width: 0.8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calculate_outlined, size: 13.5, color: AppTheme.primaryBlue),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              '원천징수 3.3% (-${LocalizationService.formatAmount(expense.withholdingTax)}) · 실수령 ${LocalizationService.formatAmount(expense.actualPayoutAmount)}',
                              softWrap: true,
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue, height: 1.25),
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.arrow_forward_ios_rounded, size: 9, color: AppTheme.primaryBlue),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 12),

          // 4. Action Row (1 Column Full-Width in Senior Mode)
          if (isInstructor || expense.isWithholdingApplied) ...[
            if (isSeniorMode) ...[
              ZeroButton(
                label: LocalizationService.tr('share_order_payment'),
                icon: Icons.chat_bubble_outline_rounded,
                variant: ZeroButtonVariant.neutral,
                size: ZeroButtonSize.large,
                fullWidth: true,
                onPressed: () async {
                  final kakaoMsg = KakaoShareService.generateVendorOrderKakaoMessage(
                    studio: studio,
                    vendorName: expense.vendorName,
                    title: expense.title,
                    amount: expense.amount,
                    bankInfo: vendor != null && vendor.accountNumber != null
                        ? '${vendor.bankName} ${vendor.accountNumber} (${vendor.accountHolder ?? ''})'
                        : null,
                    memo: expense.memo,
                  );
                  await KakaoShareService.shareMessage(
                    text: kakaoMsg,
                    subject: '[${studio.studioName}] 발주 및 입금 확인',
                  );
                },
              ),
              const SizedBox(height: 8),
              ZeroButton(
                label: LocalizationService.tr('instructor_settlement_btn'),
                icon: Icons.badge_outlined,
                variant: ZeroButtonVariant.neutral,
                size: ZeroButtonSize.large,
                fullWidth: true,
                onPressed: () => _showStaffSettlementModal(context, expense, vendor, studio),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: ZeroButton(
                      label: LocalizationService.tr('share_order_payment'),
                      icon: Icons.chat_bubble_outline_rounded,
                      variant: ZeroButtonVariant.neutral,
                      size: ZeroButtonSize.medium,
                      fullWidth: true,
                      onPressed: () async {
                        final kakaoMsg = KakaoShareService.generateVendorOrderKakaoMessage(
                          studio: studio,
                          vendorName: expense.vendorName,
                          title: expense.title,
                          amount: expense.amount,
                          bankInfo: vendor != null && vendor.accountNumber != null
                              ? '${vendor.bankName} ${vendor.accountNumber} (${vendor.accountHolder ?? ''})'
                              : null,
                          memo: expense.memo,
                        );
                        await KakaoShareService.shareMessage(
                          text: kakaoMsg,
                          subject: '[${studio.studioName}] 발주 및 입금 확인',
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ZeroButton(
                      label: LocalizationService.tr('instructor_settlement_btn'),
                      icon: Icons.badge_outlined,
                      variant: ZeroButtonVariant.neutral,
                      size: ZeroButtonSize.medium,
                      fullWidth: true,
                      onPressed: () => _showStaffSettlementModal(context, expense, vendor, studio),
                    ),
                  ),
                ],
              ),
          ] else ...[
            ZeroButton(
              label: LocalizationService.tr('share_order_payment'),
              icon: Icons.chat_bubble_outline_rounded,
              variant: ZeroButtonVariant.neutral,
              size: isSeniorMode ? ZeroButtonSize.large : ZeroButtonSize.medium,
              fullWidth: true,
              onPressed: () async {
                final kakaoMsg = KakaoShareService.generateVendorOrderKakaoMessage(
                  studio: studio,
                  vendorName: expense.vendorName,
                  title: expense.title,
                  amount: expense.amount,
                  bankInfo: vendor != null && vendor.accountNumber != null
                      ? '${vendor.bankName} ${vendor.accountNumber} (${vendor.accountHolder ?? ''})'
                      : null,
                  memo: expense.memo,
                );
                await KakaoShareService.shareMessage(
                  text: kakaoMsg,
                  subject: '[${studio.studioName}] 발주 및 입금 확인',
                );
              },
            ),
          ],
          const SizedBox(height: 8),

          // 5. Tier-4 Utility Actions (Standardized ZeroButtons for Edit & Delete)
          if (isSeniorMode) ...[
            ZeroButton(
              label: LocalizationService.tr('edit_expense_btn'),
              icon: Icons.edit_outlined,
              variant: ZeroButtonVariant.neutral,
              size: ZeroButtonSize.medium,
              fullWidth: true,
              onPressed: () => _openAddExpenseSheet(context, vendors, expense),
            ),
            const SizedBox(height: 8),
            ZeroButton(
              label: LocalizationService.tr('delete_expense_btn'),
              icon: Icons.delete_outline_rounded,
              variant: ZeroButtonVariant.neutral,
              size: ZeroButtonSize.medium,
              fullWidth: true,
              onPressed: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    title: const Text('지출 내역 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    content: Text('\'${expense.title}\' 지출 내역을 장부에서 삭제하시겠습니까?'),
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
                              onPressed: () => Navigator.pop(dCtx, false),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: ZeroButton.danger(
                              label: LocalizationService.tr('btn_delete'),
                              size: ZeroButtonSize.medium,
                              fullWidth: true,
                              onPressed: () => Navigator.pop(dCtx, true),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
                if (confirm == true) {
                  await ref.read(expensesProvider.notifier).deleteExpense(expense.id);
                }
              },
            ),
          ] else
            Row(
              children: [
                Expanded(
                  child: ZeroButton(
                    label: LocalizationService.tr('btn_edit'),
                    icon: Icons.edit_outlined,
                    variant: ZeroButtonVariant.neutral,
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () => _openAddExpenseSheet(context, vendors, expense),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ZeroButton(
                    label: LocalizationService.tr('btn_delete'),
                    icon: Icons.delete_outline_rounded,
                    variant: ZeroButtonVariant.neutral,
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (dCtx) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        title: const Text('지출 내역 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        content: Text('\'${expense.title}\' 지출 내역을 장부에서 삭제하시겠습니까?'),
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
                                  onPressed: () => Navigator.pop(dCtx, false),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ZeroButton.danger(
                                  label: LocalizationService.tr('btn_delete'),
                                  size: ZeroButtonSize.medium,
                                  fullWidth: true,
                                  onPressed: () => Navigator.pop(dCtx, true),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(expensesProvider.notifier).deleteExpense(expense.id);
                    }
                  },
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  void _openAddExpenseSheet(
    BuildContext context,
    List<Vendor> vendors, [
    ExpenseItem? editExpense,
  ]) {
    final titleCtrl = TextEditingController(text: editExpense?.title ?? '');
    final amountCtrl = TextEditingController(text: editExpense != null ? editExpense.amount.toString() : '');
    final memoCtrl = TextEditingController(text: editExpense?.memo ?? '');
    String selectedCategory = editExpense?.category ?? '교재비';
    String selectedMethod = editExpense?.paymentMethod ?? '계좌이체';
    bool isPaid = editExpense?.isPaid ?? true;
    final DateTime selectedDate = editExpense?.date ?? DateTime.now();
    bool isWithholdingApplied = editExpense?.isWithholdingApplied ?? (selectedCategory == '강사료');
    String selectedEvidence = editExpense?.taxEvidence ?? (isWithholdingApplied ? '원천징수(3.3%)' : '세금계산서');
    Vendor? selectedVendor = editExpense?.vendorId != null
        ? vendors.where((v) => v.id == editExpense!.vendorId).firstOrNull
        : (vendors.isNotEmpty ? vendors.first : null);
    String directVendorName = editExpense?.vendorName ?? (selectedVendor?.name ?? '');

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.92,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      editExpense == null ? '새 지출/매입 등록' : '지출 내역 수정',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetCtx)),
                  ],
                ),
                const SizedBox(height: 12),

                // 거래처 선택 드롭다운 또는 직접 입력
                const Text('거래처 (납품처/수취인)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                if (vendors.isNotEmpty) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderSubtle),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<Vendor>(
                        isExpanded: true,
                        value: selectedVendor,
                        hint: const Text('거래처를 선택하세요'),
                        items: vendors.map((v) {
                          return DropdownMenuItem<Vendor>(
                            value: v,
                            child: Text('${v.name} (${v.category})', style: const TextStyle(fontSize: 14)),
                          );
                        }).toList(),
                        onChanged: (newV) {
                          if (newV != null) {
                            setSheetState(() {
                              selectedVendor = newV;
                              directVendorName = newV.name;
                              if (newV.category.contains('교재')) selectedCategory = '교재비';
                              if (newV.category.contains('임대')) selectedCategory = '임대료';
                              if (newV.category.contains('강사')) selectedCategory = '강사료';
                              if (newV.category.contains('소모품')) selectedCategory = '소모품비';
                            });
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
                AppTextField(
                  controller: TextEditingController(text: directVendorName)
                    ..selection = TextSelection.collapsed(offset: directVendorName.length),
                  label: '거래처 상호 직접 입력',
                  hint: '예: (주)영재교육, 우리건물 관리단, 홍길동 코치',
                  prefixIcon: Icons.storefront_outlined,
                  onChanged: (val) => directVendorName = val,
                ),
                const SizedBox(height: 12),

                // 지출 품목명
                AppTextField(
                  controller: titleCtrl,
                  label: '지출 항목 / 품목명',
                  hint: '예: 5월 수학 워크북 30부, 스튜디오 월세, 소독 비품',
                  prefixIcon: Icons.shopping_bag_outlined,
                ),
                const SizedBox(height: 12),

                // 지출 금액
                AppTextField(
                  controller: amountCtrl,
                  label: '지출 금액 (원)',
                  hint: '100000',
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.payments_outlined,
                ),
                const SizedBox(height: 8),

                // 빠른 금액 가산 버튼
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [10000, 50000, 100000, 500000, 1000000].map((amt) {
                    return OutlinedButton(
                      onPressed: () {
                        final cur = int.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
                        amountCtrl.text = (cur + amt).toString();
                        setSheetState(() {});
                      },
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      child: Text('+${amt ~/ 10000}만원', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 분류 카테고리 선택
                const Text('지출 분류', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['교재비', '임대료', '강사료', '소모품비', '시설관리', '공과금', '기타'].map((cat) {
                    final isSel = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
                      selected: isSel,
                      selectedColor: const Color(0xFFE11D48),
                      backgroundColor: Colors.white,
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 결제 수단
                const Text('결제 수단', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['계좌이체', '신용카드', '현금', '간편결제'].map((m) {
                    final isSel = selectedMethod == m;
                    return ChoiceChip(
                      label: Text(m, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
                      selected: isSel,
                      selectedColor: AppTheme.primaryBlue,
                      backgroundColor: Colors.white,
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedMethod = m);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 3.3% 프리랜서 강사료 원천징수 계산기
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('3.3% 프리랜서 원천징수 적용', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: const Text('사업소득세 3% + 지방소득세 0.3% 자동 공제 계산', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  value: isWithholdingApplied,
                  activeThumbColor: const Color(0xFF6366F1),
                  onChanged: (val) {
                    setSheetState(() {
                      isWithholdingApplied = val;
                      if (val) selectedEvidence = '원천징수(3.3%)';
                    });
                  },
                ),
                Builder(
                  builder: (_) {
                    final curAmount = int.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
                    final calcTax = isWithholdingApplied ? ((curAmount * 0.033).round()) : 0;
                    final actualPayout = curAmount - calcTax;

                    if (isWithholdingApplied && curAmount > 0) {
                      return Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFC7D2FE)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('원천징수 세액 (3.3%)', style: TextStyle(fontSize: 12.5, color: Color(0xFF4338CA), fontWeight: FontWeight.w600)),
                                Text('- ${LocalizationService.formatAmount(calcTax)}', style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('실제 이체할 실수령액', style: TextStyle(fontSize: 13.5, color: Color(0xFF1E1B4B), fontWeight: FontWeight.w800)),
                                Text(LocalizationService.formatAmount(actualPayout), style: const TextStyle(fontSize: 15, color: Color(0xFF4338CA), fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),

                // 세무 적격증빙 유형 (간편장부 연동)
                const Text('세무 적격증빙 유형 (국세청 간편장부)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ExpenseItem.taxEvidenceTypes.map((ev) {
                    final isSel = selectedEvidence == ev;
                    return ChoiceChip(
                      label: Text(ev, style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
                      selected: isSel,
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: Colors.white,
                      onSelected: (val) {
                        if (val) setSheetState(() => selectedEvidence = ev);
                      },
                    );
                  }).toList(),
                ),
                Builder(
                  builder: (_) {
                    final curAmount = int.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
                    if (selectedEvidence == '간이영수증' && curAmount > 30000) {
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '3만원 초과 간이영수증은 세법상 증빙불비 가산세(2%) 대상이 될 수 있습니다.',
                                style: TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
                const SizedBox(height: 14),

                // 완납 여부 스위치
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('지급 완료 (완납)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  subtitle: Text(isPaid ? '대금 이체 완료' : '미지급 / 외상 대기 상태', style: const TextStyle(fontSize: 12)),
                  value: isPaid,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) => setSheetState(() => isPaid = val),
                ),
                const SizedBox(height: 8),

                // 메모
                AppTextField(
                  controller: memoCtrl,
                  label: '비고 / 메모 (선택)',
                  hint: '예: 5월 10일 정산 예정, 택배 수령 완료',
                  prefixIcon: Icons.notes_outlined,
                ),
                const SizedBox(height: 20),

                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () async {
                      final title = titleCtrl.text.trim();
                      final amount = int.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
                      final vName = directVendorName.trim().isEmpty ? '일반 거래처' : directVendorName.trim();

                      if (title.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('지출 품목명을 입력해주세요.')));
                        return;
                      }
                      if (amount <= 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('금액을 올바르게 입력해주세요.')));
                        return;
                      }

                      final withTax = isWithholdingApplied ? ((amount * 0.033).round()) : 0;
                      final item = ExpenseItem(
                        id: editExpense?.id ?? 'exp_${DateTime.now().millisecondsSinceEpoch}',
                        vendorId: selectedVendor?.id,
                        vendorName: vName,
                        title: title,
                        amount: amount,
                        date: selectedDate,
                        category: selectedCategory,
                        paymentMethod: selectedMethod,
                        isPaid: isPaid,
                        memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
                        createdAt: editExpense?.createdAt ?? DateTime.now(),
                        taxEvidence: selectedEvidence,
                        isWithholdingApplied: isWithholdingApplied,
                        withholdingTax: withTax,
                      );

                      if (editExpense == null) {
                        await ref.read(expensesProvider.notifier).addExpense(item);
                      } else {
                        await ref.read(expensesProvider.notifier).updateExpense(item);
                      }

                      if (sheetCtx.mounted) Navigator.pop(sheetCtx);

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${item.title} (${_currencyFormat.format(amount)}원) 지출이 저장되었습니다.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE11D48),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      editExpense == null ? '지출 내역 등록 완료' : '수정 내용 저장',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _openVendorManagementSheet(BuildContext context, List<Vendor> vendors) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.85,
      builder: (sheetCtx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Row(
                    children: [
                      Icon(Icons.business_center_outlined, color: Color(0xFF4F46E5), size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '거래처 수첩 (B2B 납품처)',
                          softWrap: true,
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetCtx)),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '교재사, 기구사, 관리사무소, 파트너 강사의 계좌 및 연락처 목록입니다.',
              style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),

            // 새 거래처 등록 버튼
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openAddEditVendorDialog(context),
                icon: const Icon(Icons.add, size: 18, color: Color(0xFF4F46E5)),
                label: const Text('새 거래처 등록하기', style: TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
                  backgroundColor: const Color(0xFFEEF2FF),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 14),

            if (vendors.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text('등록된 거래처가 없습니다.', style: TextStyle(color: AppTheme.textTertiary)),
                ),
              )
            else
              ...vendors.map((v) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
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
                          Expanded(
                            child: Row(
                              children: [
                                Text(
                                  v.name,
                                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    v.category,
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textSecondary),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () => _openAddEditVendorDialog(context, v),
                              ),
                              const SizedBox(width: 8),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 18, color: Color(0xFFEF4444)),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dCtx) => AlertDialog(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      title: const Text('거래처 삭제', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                      content: Text('\'${v.name}\' 거래처를 삭제하시겠습니까?'),
                                      actions: [
                                        TextButton(onPressed: () => Navigator.pop(dCtx, false), child: Text(LocalizationService.tr('btn_cancel'))),
                                        ElevatedButton(
                                          onPressed: () => Navigator.pop(dCtx, true),
                                          style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFEF4444)),
                                          child: Text(LocalizationService.tr('btn_delete'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                  );
                                  if (confirm == true) {
                                    await ref.read(vendorsProvider.notifier).deleteVendor(v.id);
                                  }
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                      if (v.bankName != null && v.accountNumber != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(Icons.account_balance, size: 13, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              '${v.bankName} ${v.accountNumber} (${v.accountHolder ?? ''})',
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.textPrimary, fontWeight: FontWeight.w500),
                            ),
                            IconButton(
                              icon: const Icon(Icons.copy_rounded, size: 12, color: AppTheme.primaryBlue),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: '${v.bankName} ${v.accountNumber} ${v.accountHolder ?? ''}'));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('${v.bankName} 계좌번호가 복사되었습니다.'), behavior: SnackBarBehavior.floating),
                                );
                              },
                            ),
                          ],
                        ),
                      ],
                      if (v.phone != null && v.phone!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.phone_outlined, size: 13, color: AppTheme.textSecondary),
                            const SizedBox(width: 4),
                            Text(
                              v.phone!,
                              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                            ),
                            const SizedBox(width: 6),
                            InkWell(
                              onTap: () => launchUrl(Uri.parse('tel:${v.phone}')),
                              child: const Text('통화', style: TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ],
                      if (v.memo != null && v.memo!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '메모: ${v.memo}',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textTertiary),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  void _openAddEditVendorDialog(BuildContext context, [Vendor? editVendor]) {
    final nameCtrl = TextEditingController(text: editVendor?.name ?? '');
    final bankCtrl = TextEditingController(text: editVendor?.bankName ?? '');
    final accountCtrl = TextEditingController(text: editVendor?.accountNumber ?? '');
    final holderCtrl = TextEditingController(text: editVendor?.accountHolder ?? '');
    final phoneCtrl = TextEditingController(text: editVendor?.phone ?? '');
    final memoCtrl = TextEditingController(text: editVendor?.memo ?? '');
    String selectedCategory = editVendor?.category ?? '교재/교구';

    showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            editVendor == null ? '새 거래처 등록' : '거래처 정보 수정',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: nameCtrl,
                  label: '상호 / 거래처명 (필수)',
                  hint: '예: (주)에듀프라임 교재총판',
                  prefixIcon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 10),
                const Text('거래처 분류', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: ['교재/교구', '시설/기구', '임대/관리비', '강사/코치료', '소모품/비품', '기타'].map((cat) {
                    final isSel = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(cat, style: TextStyle(fontSize: 11.5, color: isSel ? Colors.white : AppTheme.textPrimary)),
                      selected: isSel,
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: Colors.white,
                      onSelected: (val) {
                        if (val) setDlgState(() => selectedCategory = cat);
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: bankCtrl,
                  label: '입금 은행',
                  hint: '예: 국민은행, 신한은행, 카카오뱅크',
                  prefixIcon: Icons.account_balance,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: accountCtrl,
                  label: '계좌번호',
                  hint: '숫자만 또는 하이픈 포함',
                  prefixIcon: Icons.payment,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: holderCtrl,
                  label: '예금주',
                  hint: '예: 김영수 (에듀프라임)',
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: phoneCtrl,
                  label: '연락처 (선택)',
                  hint: '010-0000-0000',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: memoCtrl,
                  label: '메모 (선택)',
                  hint: '담당자명, 정기 발주일 등',
                  prefixIcon: Icons.note_outlined,
                ),
              ],
            ),
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
                    label: editVendor != null ? '수정 완료' : '등록 완료',
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('거래처 상호를 입력해주세요.')));
                  return;
                }

                final vendor = Vendor(
                  id: editVendor?.id ?? 'vnd_${DateTime.now().millisecondsSinceEpoch}',
                  name: name,
                  category: selectedCategory,
                  bankName: bankCtrl.text.trim().isEmpty ? null : bankCtrl.text.trim(),
                  accountNumber: accountCtrl.text.trim().isEmpty ? null : accountCtrl.text.trim(),
                  accountHolder: holderCtrl.text.trim().isEmpty ? null : holderCtrl.text.trim(),
                  phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
                  memo: memoCtrl.text.trim().isEmpty ? null : memoCtrl.text.trim(),
                  createdAt: editVendor?.createdAt ?? DateTime.now(),
                );

                if (editVendor == null) {
                  await ref.read(vendorsProvider.notifier).addVendor(vendor);
                } else {
                  await ref.read(vendorsProvider.notifier).updateVendor(vendor);
                }

                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  void _showBankNotificationSimulator(
    BuildContext context,
    List<Member> members,
    List<Invoice> unpaidInvoices,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        actionsAlignment: MainAxisAlignment.end,
        title: const Row(
          children: [
            Icon(Icons.sync_alt_rounded, color: AppTheme.primaryBlue, size: 22),
            SizedBox(width: 8),
            Text('은행 푸시 알림 장부 매칭', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '안드로이드 기기에 수신되는 은행 알림을 필터링하여 자동으로 장부와 대조합니다.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              if (unpaidInvoices.isEmpty)
                const Text('현재 매칭 대기 중인 미납 청구서가 없습니다.')
            else
              Column(
                children: unpaidInvoices.take(2).map((inv) {
                    final invoiceMembers = inv.memberIds.map((id) => members.where((m) => m.id == id).firstOrNull).whereType<Member>().toList();
                    final payerOrStudent = invoiceMembers.isNotEmpty && invoiceMembers.first.payerName != null
                        ? '${invoiceMembers.first.name} (학부모: ${invoiceMembers.first.payerName})'
                        : inv.title;
                    final simSenderName = invoiceMembers.isNotEmpty && invoiceMembers.first.payerName != null
                        ? invoiceMembers.first.payerName!
                        : (invoiceMembers.isNotEmpty ? invoiceMembers.first.name.split(' ').first : '입금자');

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(payerOrStudent, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text('${LocalizationService.formatAmount(inv.amount)} 입금 시뮬레이션 (입금자: $simSenderName)'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          // Simulate banking app push with sender name (payerName or student name)
                          final event = BankNotificationFilter.parseDepositNotification(
                            packageName: 'viva.republica.toss',
                            title: '토스뱅크',
                            text: '입금 ${LocalizationService.formatAmount(inv.amount)} $simSenderName',
                          );
                          if (event != null) {
                            final match = BankNotificationFilter.matchInvoiceWithDeposit(
                              event: event,
                              unpaidInvoices: unpaidInvoices,
                              allMembers: members,
                            );

                            if (match != null) {
                              ref.read(invoicesProvider.notifier).markAsPaid(invoiceId: match.invoice.id, paymentMethod: 'TRANSFER');
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('은행 알림 감지 [${match.matchType}]: ${match.matchedMemberName ?? match.invoice.title} (${LocalizationService.formatAmount(event.amount)}) 자동 입금 처리 완료!'),
                                  backgroundColor: AppTheme.softMint,
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            }
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.softMint,
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        ),
                        child: const Text('자동매칭', style: TextStyle(fontSize: 12)),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
        ],
      ),
    );
  }

  void _openQuickInvoiceSheet(
    BuildContext context,
    List<Member> allMembers,
    StudioProfile studio,
  ) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (ctx) => _QuickInvoiceModal(
        allMembers: allMembers,
        studio: studio,
        onSendSms: (createdInvoice, members) {
          _sendSmsInvoice(context, studio, members, createdInvoice);
        },
      ),
    );
  }

  void _showStaffSettlementModal(
    BuildContext context,
    ExpenseItem expense,
    Vendor? vendor,
    StudioProfile studio,
  ) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (ctx) => _StaffSettlementSheet(
        expense: expense,
        vendor: vendor,
        studio: studio,
      ),
    );
  }

  void _showBookkeepingExportSheet(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.85,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.table_view_rounded, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '간편장부 엑셀 및 세무 관리',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '국세청 표준 사업소득 간편장부 CSV 추출 및 1분 세무 가이드',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFF64748B)),
                  splashRadius: 18,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFEEF2FF),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.table_view_rounded, color: Color(0xFF4F46E5)),
                ),
                title: const Text('국세청 사업소득 간편장부 엑셀(CSV) 내보내기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: const Text('수입과 지출 통합 정렬 엑셀 호환 표준 CSV 생성 및 카톡 공유', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
                onTap: () async {
                  Navigator.pop(ctx);
                  try {
                    final file = await DataVaultService.exportSimplifiedBookkeepingCsv();
                    await DataVaultService.shareSimplifiedBookkeepingCsv(file);
                    await MonetizationService.instance.recordValueAction(taxCount: 1);
                    MonetizationService.instance.triggerSmartInterstitialAd(
                      cooldownSeconds: 90,
                      actionThreshold: 1,
                    );
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('간편장부 내보내기 오류: $e')));
                    }
                  }
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFFBEB),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706)),
                ),
                title: const Text('소상공인 간편장부 세무 신고 꿀팁 가이드', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: const Text('5월 종합소득세, 2월 사업장현황신고, 3.3% 원천세 1분 마스터', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
                onTap: () {
                  Navigator.pop(ctx);
                  TaxGuideModal.show(context);
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _QuickInvoiceModal extends ConsumerStatefulWidget {
  final List<Member> allMembers;
  final StudioProfile studio;
  final Function(Invoice, List<Member>) onSendSms;

  const _QuickInvoiceModal({
    required this.allMembers,
    required this.studio,
    required this.onSendSms,
  });

  @override
  ConsumerState<_QuickInvoiceModal> createState() => _QuickInvoiceModalState();
}

class _QuickInvoiceModalState extends ConsumerState<_QuickInvoiceModal> {
  final Set<String> _selectedMemberIds = {};
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _directNameController = TextEditingController();
  bool _isDirectInputMode = false;
  bool _autoRegisterMember = true;
  DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  final NumberFormat _currencyFormat = NumberFormat('#,###');
  bool _sendSmsRightNow = true;
  bool _applySiblingDiscount = false;
  double _siblingDiscountRate = 0.10;
  int _siblingFixedDiscount = 0;
  int _originalSiblingTotal = 0;
  int _calculatedSiblingDiscount = 0;

  @override
  void initState() {
    super.initState();
    if (widget.allMembers.isNotEmpty) {
      _selectMember(widget.allMembers.first);
    } else {
      _isDirectInputMode = true;
      final now = DateTime.now();
      final feeWord = widget.studio.feeTitle;
      _titleController.text = '${now.month}월 $feeWord 안내';
      _amountController.text = '250000';
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _phoneController.dispose();
    _directNameController.dispose();
    super.dispose();
  }

  void _recalculateSiblingTotal() {
    final selectedMembers = widget.allMembers.where((m) => _selectedMemberIds.contains(m.id)).toList();
    if (selectedMembers.isEmpty) return;

    final totalDefault = selectedMembers.fold<int>(0, (sum, m) => sum + m.defaultFee);
    final now = DateTime.now();
    final feeWord = widget.studio.feeTitle;

    _originalSiblingTotal = totalDefault > 0 ? totalDefault : 250000;
    _calculatedSiblingDiscount = 0;
    if (_applySiblingDiscount && selectedMembers.length > 1) {
      if (_siblingFixedDiscount > 0) {
        _calculatedSiblingDiscount = _siblingFixedDiscount;
      } else {
        _calculatedSiblingDiscount = (_originalSiblingTotal * _siblingDiscountRate).round();
      }
    }
    final finalAmount = (_originalSiblingTotal - _calculatedSiblingDiscount).clamp(0, 999999999);

    _amountController.text = finalAmount.toString();
    _titleController.text = selectedMembers.length > 1
        ? '${now.month}월 $feeWord (${selectedMembers.map((s) => s.primaryName).join('/')} 형제·가족 합산${_applySiblingDiscount ? ' [할인적용]' : ''})'
        : '${selectedMembers.first.primaryName} ${now.month}월 $feeWord 안내';
  }

  void _selectMember(Member m) {
    setState(() {
      _isDirectInputMode = false;
      _selectedMemberIds.clear();
      _selectedMemberIds.add(m.id);
      _phoneController.text = m.phone;
      _recalculateSiblingTotal();
    });
  }

  void _toggleMemberSelection(Member m) {
    setState(() {
      _isDirectInputMode = false;
      if (_selectedMemberIds.contains(m.id)) {
        if (_selectedMemberIds.length > 1) {
          _selectedMemberIds.remove(m.id);
        }
      } else {
        _selectedMemberIds.add(m.id);
      }
      _recalculateSiblingTotal();
    });
  }

  void _addAmount(int add) {
    final current = int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    _amountController.text = (current + add).toString();
  }

  @override
  Widget build(BuildContext context) {
    final feeWord = widget.studio.feeTitle;
    final now = DateTime.now();
    final monthEnd = DateTime(now.year, now.month + 1, 0);
    final customCatAsync = ref.watch(customCategoryProvider);
    final customCatState = customCatAsync.value ??
        CustomCategoryState.getDefaultsForIndustry(widget.studio.category);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Row(
                  children: [
                    Icon(Icons.edit_note, color: AppTheme.primaryBlue, size: 24),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '간편 청구서 작성',
                        softWrap: true,
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
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
          const SizedBox(height: 12),

          // If no members are registered, show helpful guidance + demo data load button
          if (widget.allMembers.isEmpty)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFBFDBFE)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '등록된 회원이 없어도 바로 작성 가능',
                          softWrap: true,
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  const Text(
                    '수신인 성함과 연락처를 직접 입력하시면 청구서 등록과 동시에 회원 명부에도 자동으로 등록할 수 있습니다.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF3B82F6), height: 1.4),
                  ),
                  const SizedBox(height: 10),
                  Consumer(
                    builder: (ctx, ref, _) => OutlinedButton.icon(
                      onPressed: () async {
                        final db = ref.read(databaseServiceProvider);
                        await db.restoreSampleData();
                        await ref.read(membersProvider.notifier).reload();
                        await ref.read(invoicesProvider.notifier).reload();
                        if (context.mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('체험용 샘플 회원 5명이 등록되었습니다. 다시 청구서를 작성해보세요!'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 15, color: AppTheme.primaryBlue),
                      label: const Text('체험용 샘플 회원 5명 불러오기', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF93C5FD)),
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Select Target Member or Direct Input
          Text(
            '${widget.studio.memberTitle} 선택 및 대상자 지정',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          if (widget.allMembers.isNotEmpty)
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  ...widget.allMembers.map((m) {
                    final isSelected = !_isDirectInputMode && _selectedMemberIds.contains(m.id);
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(m.primaryName),
                            if (isSelected && _selectedMemberIds.length > 1) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.check, size: 12, color: Colors.white),
                            ],
                          ],
                        ),
                        selected: isSelected,
                        onSelected: (val) {
                          if (_isDirectInputMode || _selectedMemberIds.isEmpty) {
                            _selectMember(m);
                          } else {
                            _toggleMemberSelection(m);
                          }
                        },
                        selectedColor: AppTheme.primaryDark,
                        labelStyle: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );
                  }),
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: Icon(
                        Icons.add,
                        size: 16,
                        color: _isDirectInputMode ? Colors.white : AppTheme.primaryBlue,
                      ),
                      label: const Text('직접 입력'),
                      selected: _isDirectInputMode,
                      onSelected: (val) {
                        setState(() {
                          _isDirectInputMode = true;
                          _selectedMemberIds.clear();
                          if (_directNameController.text.trim().isNotEmpty) {
                            _titleController.text = '${_directNameController.text.trim()} ${now.month}월 $feeWord 안내';
                          }
                        });
                      },
                      selectedColor: AppTheme.primaryBlue,
                      labelStyle: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _isDirectInputMode ? Colors.white : AppTheme.primaryBlue,
                      ),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ],
              ),
            ),

          // Sibling Quick-Add Suggestion Banner
          if (!_isDirectInputMode && widget.allMembers.any((other) => other.phone == _phoneController.text && !_selectedMemberIds.contains(other.id))) ...[
            const SizedBox(height: 8),
            Builder(
              builder: (ctx) {
                final unselectedSiblings = widget.allMembers.where((other) => other.phone == _phoneController.text && !_selectedMemberIds.contains(other.id)).toList();
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFBFDBFE)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.people_alt_outlined, size: 16, color: AppTheme.primaryBlue),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '동일 연락처 형제: ${unselectedSiblings.map((s) => s.primaryName).join(", ")}',
                          softWrap: true,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFF1E40AF)),
                        ),
                      ),
                      const SizedBox(width: 6),
                      InkWell(
                        onTap: () {
                          setState(() {
                            for (final s in unselectedSiblings) {
                              _selectedMemberIds.add(s.id);
                            }
                            _recalculateSiblingTotal();
                          });
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF93C5FD)),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.add_rounded, size: 13, color: AppTheme.primaryBlue),
                              SizedBox(width: 2),
                              Text('함께 묶기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],

          // Sibling Bundle & 10% Discount Card
          if (!_isDirectInputMode && _selectedMemberIds.length > 1) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFBBF7D0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.family_restroom_rounded, color: Color(0xFF16A34A), size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '형제·가족 ${_selectedMemberIds.length}명 묶음 합산 청구 모드',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            if (_selectedMemberIds.length > 1) {
                              final firstId = _selectedMemberIds.first;
                              _selectedMemberIds.clear();
                              _selectedMemberIds.add(firstId);
                              _recalculateSiblingTotal();
                            }
                          });
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('단독 청구로 전환', style: TextStyle(fontSize: 11, color: Color(0xFF64748B))),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: const Text('형제/다자녀 10% 자동 할인 적용', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    subtitle: Text(
                      _siblingFixedDiscount > 0
                          ? '${_currencyFormat.format(_siblingFixedDiscount)}원 고정 감면'
                          : '수강료 ${(_siblingDiscountRate * 100).toInt()}% 원터치 감면 계산',
                      style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                    value: _applySiblingDiscount,
                    activeThumbColor: const Color(0xFF16A34A),
                    onChanged: (val) {
                      setState(() {
                        _applySiblingDiscount = val;
                        _recalculateSiblingTotal();
                      });
                    },
                  ),
                  if (_applySiblingDiscount) ...[
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _buildDiscountChip('10% 할인 (기본)', 0.10, 0),
                        _buildDiscountChip('5% 할인', 0.05, 0),
                        _buildDiscountChip('15% 할인', 0.15, 0),
                        _buildDiscountChip('-2만원 할인', 0, 20000),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDCFCE7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('정상 합계: ${_currencyFormat.format(_originalSiblingTotal)}원', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                          Text('할인: -${LocalizationService.formatAmount(_calculatedSiblingDiscount)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFE11D48))),
                          Text('최종 청구: ${LocalizationService.formatAmount(_originalSiblingTotal - _calculatedSiblingDiscount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          // Direct Name Input & Auto-register Option
          if (_isDirectInputMode) ...[
            const SizedBox(height: 12),
            AppTextField(
              controller: _directNameController,
              label: '${widget.studio.memberTitle} 성함 / 수신인 성함',
              hint: '예: 김철수',
              prefixIcon: Icons.person_outline,
              onChanged: (val) {
                final name = val.trim();
                if (name.isNotEmpty) {
                  _titleController.text = '$name ${now.month}월 $feeWord 안내';
                }
              },
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoRegisterMember,
              onChanged: (val) => setState(() => _autoRegisterMember = val ?? true),
              title: Text(
                '${widget.studio.memberTitle} 명부에도 신규 회원으로 자동 등록하기',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ],
          const SizedBox(height: 14),

          // Custom Invoice Item Templates (Title + Amount auto-fill)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Expanded(
                child: Text(
                  '업종별 청구 템플릿 (원터치 자동 완성)',
                  softWrap: true,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showQuickAddInvoiceTemplateDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF8B5CF6)),
                      SizedBox(width: 3),
                      Text('새 서식 추가',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6))),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...customCatState.invoiceTemplates.map((template) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ActionChip(
                      avatar: const Icon(Icons.receipt_long_rounded, size: 14, color: Color(0xFF8B5CF6)),
                      label: Text('${template.title} (₩${_currencyFormat.format(template.defaultAmount)})'),
                      backgroundColor: const Color(0xFFF8FAFC),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      onPressed: () {
                        setState(() {
                          _titleController.text = template.title.replaceAll('#{월}', '${now.month}월');
                          _amountController.text = template.defaultAmount.toString();
                        });
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Title
          AppTextField(
            controller: _titleController,
            label: '청구 제목',
            hint: '예: ${now.month}월 정기 $feeWord 안내',
            prefixIcon: Icons.description_outlined,
          ),
          const SizedBox(height: 14),

          // Amount & Preset Buttons
          AppTextField(
            controller: _amountController,
            label: '청구 금액 (원)',
            hint: '300000',
            prefixIcon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
            suffix: const Padding(
              padding: EdgeInsets.only(right: 16, top: 14),
              child: Text('원', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildPresetButton('+1만', 10000),
              _buildPresetButton('+5만', 50000),
              _buildPresetButton('+10만', 100000),
              _buildPresetButton('+30만', 300000),
            ],
          ),
          const SizedBox(height: 14),

          // Due Date Selection
          const Text(
            '납부 기한 설정',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('일주일 후 (+7일)'),
                selected: _dueDate.difference(DateTime.now()).inDays <= 7 && _dueDate.difference(DateTime.now()).inDays >= 6,
                onSelected: (val) {
                  if (val) setState(() => _dueDate = DateTime.now().add(const Duration(days: 7)));
                },
              ),
              ChoiceChip(
                label: Text('${now.month}월 말일까지'),
                selected: _dueDate.day == monthEnd.day && _dueDate.month == monthEnd.month,
                onSelected: (val) {
                  if (val) setState(() => _dueDate = monthEnd);
                },
              ),
              ActionChip(
                avatar: const Icon(Icons.calendar_today_outlined, size: 14),
                label: Text(DateFormat('yyyy.MM.dd').format(_dueDate)),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _dueDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 30)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setState(() => _dueDate = picked);
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Recipient Phone
          AppTextField(
            controller: _phoneController,
            label: '수신인 연락처 (보호자 / 회원)',
            hint: '예: 010-1234-5678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),

          // Option to launch SMS editor directly
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _sendSmsRightNow,
            onChanged: (val) => setState(() => _sendSmsRightNow = val ?? true),
            title: const Text(
              '등록 완료 후 바로 청구문자 발송창 띄우기',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          const SizedBox(height: 18),

          Consumer(
            builder: (ctx, ref, _) {
              return SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final amount = int.tryParse(_amountController.text.replaceAll(',', '').trim()) ?? 0;
                    final phone = _phoneController.text.trim();
                    final title = _titleController.text.trim();

                    if (amount <= 0) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('청구 금액을 0원보다 크게 입력해주세요.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (phone.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('수신인 연락처를 입력해주세요.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }

                    if (_isDirectInputMode) {
                      final directName = _directNameController.text.trim();
                      if (directName.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('청구 대상자의 이름을 입력해주세요.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      String memberId = 'mem_${const Uuid().v4().substring(0, 8)}';
                      Member? newMember;
                      if (_autoRegisterMember) {
                        newMember = Member(
                          id: memberId,
                          name: directName,
                          phone: phone,
                          groupName: '일반',
                          billingType: BillingType.monthlyRecurring,
                          defaultFee: amount,
                          totalSessions: 0,
                          remainingSessions: 0,
                          registeredAt: DateTime.now(),
                        );
                        await ref.read(membersProvider.notifier).addMember(newMember);
                      }

                      final newInvoice = Invoice(
                        id: 'inv_${const Uuid().v4().substring(0, 8)}',
                        memberIds: [memberId],
                        recipientPhone: phone,
                        title: title.isEmpty ? '$directName ${now.month}월 $feeWord 안내' : title,
                        amount: amount,
                        dueDate: _dueDate,
                        status: PaymentStatus.unpaid,
                      );

                      await ref.read(invoicesProvider.notifier).addInvoice(newInvoice);
                      if (!context.mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${newInvoice.title} (${LocalizationService.formatAmount(amount)}) 청구서가 등록되었습니다.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      if (_sendSmsRightNow) {
                        widget.onSendSms(newInvoice, newMember != null ? [newMember] : []);
                      }
                    } else {
                      if (_selectedMemberIds.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('청구 대상 회원을 선택해주세요.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }

                      final newInvoice = Invoice(
                        id: 'inv_${const Uuid().v4().substring(0, 8)}',
                        memberIds: _selectedMemberIds.toList(),
                        recipientPhone: phone,
                        title: title.isEmpty ? '${now.month}월 $feeWord 안내' : title,
                        amount: amount,
                        dueDate: _dueDate,
                        status: PaymentStatus.unpaid,
                      );

                      await ref.read(invoicesProvider.notifier).addInvoice(newInvoice);
                      if (!context.mounted) return;
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${newInvoice.title} (${LocalizationService.formatAmount(amount)}) 청구서가 등록되었습니다.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );

                      if (_sendSmsRightNow) {
                        final members = widget.allMembers.where((m) => newInvoice.memberIds.contains(m.id)).toList();
                        widget.onSendSms(newInvoice, members);
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _sendSmsRightNow ? '청구서 등록 및 즉시 문자 발송' : '청구서 장부 등록 완료',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  void _showQuickAddInvoiceTemplateDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '100000');
    final tagCtrl = TextEditingController(text: '정기수납');

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('새 청구 서식 추가', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: titleCtrl,
                label: '청구 항목명',
                hint: '예: 교재비 / 워크북, PT 10회 재등록',
                prefixIcon: Icons.receipt_outlined,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: amountCtrl,
                label: '기본 청구 금액 (원)',
                hint: '50000',
                prefixIcon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: tagCtrl,
                label: '분류 태그 (선택)',
                hint: '예: 정기수납, 교재/재료, 레슨비',
                prefixIcon: Icons.label_outline_rounded,
              ),
            ],
          ),
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
                  label: '추가 및 적용',
                  size: ZeroButtonSize.medium,
                  fullWidth: true,
                  onPressed: () async {
              final title = titleCtrl.text.trim();
              final amount = int.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
              final tag = tagCtrl.text.trim();

              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('청구 항목명을 입력해주세요.')));
                return;
              }

              final newTemplate = InvoiceItemTemplate(
                id: 'inv_tpl_${DateTime.now().millisecondsSinceEpoch}',
                title: title,
                defaultAmount: amount,
                category: tag.isEmpty ? null : tag,
              );

              await ref.read(customCategoryProvider.notifier).saveInvoiceTemplate(newTemplate);
              setState(() {
                _titleController.text = title;
                _amountController.text = amount.toString();
              });
              if (dlgCtx.mounted) Navigator.pop(dlgCtx);
            },
                  ),
                ),
              ],
            ),
          ],
      ),
    );
  }

  Widget _buildPresetButton(String label, int amount) {
    return OutlinedButton(
      onPressed: () => setState(() => _addAmount(amount)),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
    );
  }

  Widget _buildDiscountChip(String label, double rate, int fixed) {
    final isSelected = _siblingFixedDiscount == fixed && (_siblingFixedDiscount > 0 || _siblingDiscountRate == rate);
    return InkWell(
      onTap: () {
        setState(() {
          _siblingDiscountRate = rate;
          _siblingFixedDiscount = fixed;
          _recalculateSiblingTotal();
        });
      },
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF16A34A) : Colors.white,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: isSelected ? const Color(0xFF16A34A) : const Color(0xFFCBD5E1)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : const Color(0xFF334155),
          ),
        ),
      ),
    );
  }
}

class _StaffSettlementSheet extends StatefulWidget {
  final ExpenseItem expense;
  final Vendor? vendor;
  final StudioProfile studio;

  const _StaffSettlementSheet({
    required this.expense,
    required this.vendor,
    required this.studio,
  });

  @override
  State<_StaffSettlementSheet> createState() => _StaffSettlementSheetState();
}

class _StaffSettlementSheetState extends State<_StaffSettlementSheet> {
  late final TextEditingController _messageController;
  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    final bankInfo = widget.vendor != null && widget.vendor?.accountNumber != null
        ? '${widget.vendor!.bankName} ${widget.vendor!.accountNumber} (${widget.vendor!.accountHolder ?? widget.expense.vendorName})'
        : null;

    final initialText = KakaoShareService.generateStaffSettlementKakaoMessage(
      studio: widget.studio,
      staffName: widget.expense.vendorName,
      amount: widget.expense.actualPayoutAmount,
      period: '${widget.expense.date.month}월',
      details: '${widget.expense.title} (${widget.expense.paymentMethod})',
      isWithholdingApplied: widget.expense.isWithholdingApplied,
      withholdingTax: widget.expense.withholdingTax,
      grossAmount: widget.expense.amount,
      bankAccount: bankInfo,
    );

    _messageController = TextEditingController(text: initialText);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final incomeTax = (widget.expense.amount * 0.03).round();
    final localTax = (widget.expense.amount * 0.003).round();

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2FF),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFC7D2FE)),
                  ),
                  child: const Icon(Icons.badge_outlined, color: Color(0xFF4F46E5), size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${widget.expense.vendorName} 강사료 정산서',
                            softWrap: true,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('3.3% 원천징수', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.expense.date.month}월 정산 • ${widget.expense.title}',
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Visual breakdown card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                children: [
                  _buildSummaryRow('총 지급액 (공제 전 총액)', '${_currencyFormat.format(widget.expense.amount)}원', isBold: true),
                  const Divider(height: 14, color: Color(0xFFE2E8F0)),
                  _buildSummaryRow('사업소득세 (국세 3.0%)', '-${_currencyFormat.format(incomeTax)}원', textColor: const Color(0xFFE11D48)),
                  const SizedBox(height: 4),
                  _buildSummaryRow('지방소득세 (지방세 0.3%)', '-${_currencyFormat.format(localTax)}원', textColor: const Color(0xFFE11D48)),
                  const SizedBox(height: 4),
                  _buildSummaryRow('원천징수 합계 (3.3%)', '-${_currencyFormat.format(widget.expense.withholdingTax)}원', textColor: const Color(0xFFE11D48), isBold: true),
                  const Divider(height: 14, color: Color(0xFFE2E8F0)),
                  _buildSummaryRow('차인 지급액 (실수령 입금액)', '${_currencyFormat.format(widget.expense.actualPayoutAmount)}원', textColor: const Color(0xFF4F46E5), isBold: true, fontSize: 15),
                  if (widget.vendor?.bankName != null && widget.vendor?.accountNumber != null) ...[
                    const SizedBox(height: 6),
                    _buildSummaryRow('입금 계좌', '${widget.vendor!.bankName} ${widget.vendor!.accountNumber}', textColor: AppTheme.textSecondary, fontSize: 11.5),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Editable message field
            const Text(
              '정산 명세서 메시지 본문 미리보기 (수정 가능)',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _messageController,
                maxLines: 6,
                style: const TextStyle(fontSize: 13, height: 1.45, color: Color(0xFF1E293B)),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(12),
                  border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Dispatch Buttons
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: _messageController.text));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('정산서가 클립보드에 복사되었습니다.'), behavior: SnackBarBehavior.floating),
                    );
                  },
                  icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
                  label: const Text('내용 복사', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
                if (widget.vendor?.phone != null && widget.vendor!.phone!.isNotEmpty) ...[
                  ElevatedButton.icon(
                    onPressed: () async {
                      Navigator.pop(context);
                      await SmsTemplateService.launchNativeSms(
                        recipientPhone: widget.vendor!.phone!,
                        body: _messageController.text,
                      );
                    },
                    icon: const Icon(Icons.sms_rounded, size: 15, color: Colors.white),
                    label: const Text('문자(SMS) 전송', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
                ElevatedButton.icon(
                  onPressed: () async {
                    Navigator.pop(context);
                    await KakaoShareService.shareMessage(
                      text: _messageController.text,
                      subject: '[${widget.studio.studioName}] 강사료 정산서',
                    );
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, size: 15, color: Color(0xFF1E1E1E)),
                  label: const Text('카톡 정산서 전송', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E1E1E))),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {Color? textColor, bool isBold = false, double fontSize = 12.5}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(fontSize: fontSize, color: AppTheme.textSecondary, fontWeight: isBold ? FontWeight.w700 : FontWeight.w500)),
        Text(value, style: TextStyle(fontSize: fontSize, color: textColor ?? AppTheme.textPrimary, fontWeight: isBold ? FontWeight.w800 : FontWeight.w600)),
      ],
    );
  }
}

/// Sticky Pinned Sub-tab Header Delegate for Billing & Ledger
class _BillingTabHeaderDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  const _BillingTabHeaderDelegate({
    required this.child,
    this.height = 52.0,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: height,
      child: Container(
        color: AppTheme.background,
        child: child,
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _BillingTabHeaderDelegate oldDelegate) {
    return oldDelegate.child != child || oldDelegate.height != height;
  }
}

