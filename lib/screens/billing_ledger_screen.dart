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
          title: LocalizationService.pick(
            ko: '수강료 청구 및 수납 장부',
            en: 'Tuition Billing & Payment Ledger',
            ja: '受講料請求・入金台帳',
            zh: '学费账单与收款台账',
            vi: 'Sổ thu học phí & công nợ',
            es: 'Cobros y Libro de Pagos',
          ),
          message: LocalizationService.pick(
            ko: '매월 나가는 수강료 청구 문자를 0원으로 보내고 입금 내역을 관리할 수 있는 장부예요.\n\n우측 하단 [+]를 누르면 동일 연락처의 형제자매까지 자동 합산하여 청구서를 작성할 수 있어요!',
            en: 'Send monthly fee invoices via SMS/chat for \$0 and track all payments cleanly.\n\nTap [+] at the bottom right to bundle family members sharing the same contact!',
            ja: '毎月の請求連絡を0円で送信し、入金履歴をすっきり管理できます。\n\n右下の[+]ボタンから同じ連絡先の家族まとめて請求書を作成できます！',
            zh: '每月零成本发送收费通知，并清晰管理每笔收款记录。\n\n点击右下角[+]可为同一联系人的家庭成员合并生成账单！',
            vi: 'Gửi hóa đơn học phí hàng tháng với 0đ và theo dõi thanh toán gọn gàng.\n\nNhấn [+] ở góc dưới để gộp hóa đơn cho các thành viên chung số liên hệ!',
            es: 'Envía avisos de cobro mensuales gratis por SMS/chat y registra cada pago.\n\nPulsa [+] abajo a la derecha para agrupar cobros de una misma familia!',
          ),
          tip: LocalizationService.pick(
            ko: '수납이 확인되면 [수납 완료] 버튼을 눌러 계좌이체/카드/현금 결제 수단별로 깔끔하게 장부에 기록하세요.',
            en: 'Once paid, tap [Mark Paid] to record by Bank Transfer, Card, Cash, or Digital Wallet.',
            ja: '入金を確認したら[入金完了]を押し、振込・カード・現金などの決済方法別に記録してください。',
            zh: '确认收款后点击[确认收款]，按转账/刷卡/现金方式分类入账。',
            vi: 'Sau khi nhận tiền, nhấn [Xác nhận thu] để lưu theo chuyển khoản, thẻ hoặc tiền mặt.',
            es: 'Cuando cobres, pulsa [Confirmar pago] para registrarlo por transferencia, tarjeta o efectivo.',
          ),
          buttonText: LocalizationService.pick(
            ko: '장부 둘러보기',
            en: 'Explore Ledger',
            ja: '台帳を見る',
            zh: '查看台账',
            vi: 'Xem sổ thu',
            es: 'Explorar libro',
          ),
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
              tooltip: LocalizationService.pick(
                ko: '간편장부 엑셀 & 세무',
                en: 'CSV Ledger & Tax Export',
                ja: '簡易帳簿CSV & 税務',
                zh: '简易账簿CSV与税务',
                vi: 'Xuất CSV & Thuế',
                es: 'Libro CSV e Impuestos',
              ),
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
                tooltip: LocalizationService.pick(
                  ko: '소상공인 세무 가이드',
                  en: 'Small Business Tax Guide',
                  ja: '個人事業主の税務ガイド',
                  zh: '小微商户税务指南',
                  vi: 'Hướng dẫn thuế hộ KD',
                  es: 'Guía Fiscal Pyme',
                ),
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
                tooltip: LocalizationService.pick(
                  ko: '거래처 수첩',
                  en: 'Vendors & Payroll Book',
                  ja: '取引先・講師帳',
                  zh: '供应商与讲师簿',
                  vi: 'Sổ đối tác & GV',
                  es: 'Proveedores y Equipo',
                ),
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
                tooltip: LocalizationService.pick(
                  ko: '실시간 입금 감지',
                  en: 'Auto Deposit Match',
                  ja: '自動入金照合',
                  zh: '自动对账检测',
                  vi: 'Đối soát tự động',
                  es: 'Detección de Pagos',
                ),
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
              tooltip: LocalizationService.pick(
                ko: '큰글씨 모드',
                en: 'Large Text Mode',
                ja: '大きな文字モード',
                zh: '大字模式',
                vi: 'Chế độ chữ lớn',
                es: 'Modo Texto Grande',
              ),
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
        error: (err, _) => Center(child: Text('${LocalizationService.tr('common_error')}: $err')),
        data: (invoices) {
          return membersAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('${LocalizationService.tr('common_error')}: $err')),
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

              // 회차 만료 임박 회원 (2회 이하)
              final expiringMembers = members
                  .where((m) => m.billingType == BillingType.sessionBased && m.remainingSessions <= 2)
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
                  ? LocalizationService.pick(
                      ko: '${unpaidInvoices.length}건 미납 대기',
                      en: '${unpaidInvoices.length} unpaid',
                      ja: '${unpaidInvoices.length}件 未入金',
                      zh: '${unpaidInvoices.length}笔待收款',
                      vi: '${unpaidInvoices.length} chưa thu',
                      es: '${unpaidInvoices.length} pendientes',
                    )
                  : _selectedTab == 1
                      ? LocalizationService.pick(
                          ko: '${paidInvoices.length}건 완납',
                          en: '${paidInvoices.length} paid',
                          ja: '${paidInvoices.length}件 入金済',
                          zh: '${paidInvoices.length}笔已收',
                          vi: '${paidInvoices.length} đã thu',
                          es: '${paidInvoices.length} cobrados',
                        )
                      : LocalizationService.pick(
                          ko: '${expenses.length}건 지출 (${paidExpenses.length}건 완납 / ${unpaidExpenses.length}건 대기)',
                          en: '${expenses.length} expenses (${paidExpenses.length} paid / ${unpaidExpenses.length} due)',
                          ja: '${expenses.length}件 支出 (${paidExpenses.length}済 / ${unpaidExpenses.length}未払)',
                          zh: '${expenses.length}笔支出 (${paidExpenses.length}已付 / ${unpaidExpenses.length}待付)',
                          vi: '${expenses.length} khoản chi (${paidExpenses.length} xong / ${unpaidExpenses.length} chờ)',
                          es: '${expenses.length} gastos (${paidExpenses.length} pagados / ${unpaidExpenses.length} pend.)',
                        );

              final String infoBarLeftText = _selectedTab == 0
                  ? LocalizationService.pick(
                      ko: '전체 ${invoices.length}건 중 ${paidInvoices.length}건 수납',
                      en: '${paidInvoices.length} of ${invoices.length} invoices collected',
                      ja: '全${invoices.length}件中 ${paidInvoices.length}件入金済',
                      zh: '共${invoices.length}笔账单，已收${paidInvoices.length}笔',
                      vi: 'Đã thu ${paidInvoices.length}/${invoices.length} hóa đơn',
                      es: '${paidInvoices.length} de ${invoices.length} cobros completados',
                    )
                  : LocalizationService.pick(
                      ko: '당월 순이익: ${netProfit >= 0 ? '+' : ''}${LocalizationService.formatAmount(netProfit)} (${netProfit >= 0 ? '흑자' : '적자'})',
                      en: 'Monthly Net: ${netProfit >= 0 ? '+' : ''}${LocalizationService.formatAmount(netProfit)} (${netProfit >= 0 ? 'Surplus' : 'Deficit'})',
                      ja: '今月純利益: ${netProfit >= 0 ? '+' : ''}${LocalizationService.formatAmount(netProfit)} (${netProfit >= 0 ? '黒字' : '赤字'})',
                      zh: '本月净利润: ${netProfit >= 0 ? '+' : ''}${LocalizationService.formatAmount(netProfit)} (${netProfit >= 0 ? '盈余' : '亏损'})',
                      vi: 'Lợi nhuận ròng: ${netProfit >= 0 ? '+' : ''}${LocalizationService.formatAmount(netProfit)} (${netProfit >= 0 ? 'Lãi' : 'Lỗ'})',
                      es: 'Balance Neto: ${netProfit >= 0 ? '+' : ''}${LocalizationService.formatAmount(netProfit)} (${netProfit >= 0 ? 'Superávit' : 'Déficit'})',
                    );

              final String infoBarRightText = _selectedTab == 0
                  ? '${LocalizationService.pick(ko: '완납', en: 'Paid', ja: '入金済', zh: '已收', vi: 'Đã thu', es: 'Cobrado')}: ${LocalizationService.formatAmount(totalPaidAmount)}'
                  : _selectedTab == 1
                      ? '${LocalizationService.pick(ko: '지출', en: 'Expense', ja: '支出', zh: '支出', vi: 'Chi', es: 'Gasto')}: ${LocalizationService.formatAmount(totalExpenseAmount)}'
                      : '${LocalizationService.pick(ko: '수납', en: 'Revenue', ja: '収入', zh: '收入', vi: 'Thu', es: 'Ingresos')}: ${LocalizationService.formatAmount(totalPaidAmount)}';

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
                                          FittedBox(
                                            fit: BoxFit.scaleDown,
                                            alignment: Alignment.centerLeft,
                                            child: Row(
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
                              Text(
                                LocalizationService.pick(
                                  ko: '우측 하단 [+] 또는 아래 버튼을 눌러\n첫 청구서를 간편하게 발행해보세요.',
                                  en: 'Tap [+] below or the button to\ncreate your first invoice easily.',
                                  ja: '右下の[+]または下のボタンから\n最初の請求書を作成できます。',
                                  zh: '点击右下角[+]或下方按钮\n轻松开具第一张账单。',
                                  vi: 'Nhấn [+] hoặc nút bên dưới để\ntạo hóa đơn đầu tiên.',
                                  es: 'Pulsa [+] o el botón de abajo para\ncrear tu primer cobro fácilmente.',
                                ),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                              ),
                              const SizedBox(height: 18),
                              OutlinedButton.icon(
                                onPressed: () {
                                  final members = membersAsync.value ?? [];
                                  final studio = studioAsync.value ?? StudioProfile.defaultProfile();
                                  _openQuickInvoiceSheet(context, members, studio);
                                },
                                icon: const Icon(Icons.add, size: 18, color: AppTheme.primaryBlue),
                                label: Text(
                                  LocalizationService.pick(
                                    ko: '첫 청구서 작성하기',
                                    en: 'Create First Invoice',
                                    ja: '最初の請求書を作成',
                                    zh: '创建首张账单',
                                    vi: 'Tạo hóa đơn đầu tiên',
                                    es: 'Crear Primer Cobro',
                                  ),
                                  style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700, fontSize: 14),
                                ),
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
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                  Text(
                    '$dateLabel $dateValue',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  SizedBox(
                    width: 28,
                    height: 28,
                    child: PopupMenuButton<String>(
                      padding: EdgeInsets.zero,
                      icon: const Icon(Icons.more_vert_rounded, size: 18, color: AppTheme.textSecondary),
                      tooltip: LocalizationService.pick(
                        ko: '청구서 관리',
                        en: 'Manage Invoice',
                        ja: '請求書管理',
                        zh: '管理账单',
                        vi: 'Quản lý hóa đơn',
                        es: 'Gestionar cobro',
                      ),
                      onSelected: (value) {
                        if (value == 'edit') {
                          _showEditInvoiceDialog(context, invoice);
                        } else if (value == 'unpaid') {
                          _confirmRevertInvoiceToUnpaid(context, invoice);
                        } else if (value == 'delete') {
                          _confirmDeleteInvoice(context, invoice);
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primaryBlue),
                              const SizedBox(width: 8),
                              Text(LocalizationService.pick(
                                ko: '청구서 수정',
                                en: 'Edit Invoice',
                                ja: '請求書を編集',
                                zh: '编辑账单',
                                vi: 'Sửa hóa đơn',
                                es: 'Editar cobro',
                              )),
                            ],
                          ),
                        ),
                        if (isPaid)
                          PopupMenuItem(
                            value: 'unpaid',
                            child: Row(
                              children: [
                                const Icon(Icons.undo_rounded, size: 18, color: Color(0xFFD97706)),
                                const SizedBox(width: 8),
                                Text(LocalizationService.pick(
                                  ko: '수납 취소 (미납 전환)',
                                  en: 'Revert to Unpaid',
                                  ja: '未入金に戻す',
                                  zh: '撤销收款 (转为待付)',
                                  vi: 'Hoàn tác về chưa thu',
                                  es: 'Marcar como pendiente',
                                )),
                              ],
                            ),
                          ),
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              const Icon(Icons.delete_outline_rounded, size: 18, color: AppTheme.danger),
                              const SizedBox(width: 8),
                              Text(
                                LocalizationService.pick(
                                  ko: '청구서 삭제',
                                  en: 'Delete Invoice',
                                  ja: '請求書を削除',
                                  zh: '删除账单',
                                  vi: 'Xóa hóa đơn',
                                  es: 'Eliminar cobro',
                                ),
                                style: const TextStyle(color: AppTheme.danger),
                              ),
                            ],
                          ),
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
                    subject: '[${studio.studioName}] ${studio.feeTitle}',
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
                          subject: '[${studio.studioName}] ${studio.feeTitle}',
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

  Future<void> _showEditInvoiceDialog(BuildContext context, Invoice invoice) async {
    final titleCtrl = TextEditingController(text: invoice.title);
    final amountCtrl = TextEditingController(text: invoice.amount.toString());
    final phoneCtrl = TextEditingController(text: invoice.recipientPhone);
    DateTime dueDate = invoice.dueDate;

    final itemNoun = LocalizationService.pick(
      ko: '청구서',
      en: 'Invoice',
      ja: '請求書',
      zh: '账单',
      vi: 'Hóa đơn',
      es: 'Cobro',
    );
    await showDialog(
      context: context,
      builder: (dlgCtx) => StatefulBuilder(
        builder: (ctx, setDlgState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          title: Text(
            LocalizationService.pick(
              ko: '청구서 정보 수정',
              en: 'Edit Invoice',
              ja: '請求書の編集',
              zh: '编辑账单信息',
              vi: 'Sửa hóa đơn',
              es: 'Editar cobro',
            ),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: titleCtrl,
                  label: LocalizationService.pick(
                    ko: '청구 항목명',
                    en: 'Invoice Title',
                    ja: '請求項目名',
                    zh: '账单名称',
                    vi: 'Tên khoản thu',
                    es: 'Concepto del cobro',
                  ),
                  prefixIcon: Icons.receipt_long_outlined,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: amountCtrl,
                  label: '${LocalizationService.pick(ko: '청구 금액', en: 'Amount', ja: '請求金額', zh: '账单金额', vi: 'Số tiền', es: 'Importe')} (${LocalizationService.currentCurrency.symbol})',
                  prefixIcon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: phoneCtrl,
                  label: LocalizationService.pick(
                    ko: '수신 연락처',
                    en: 'Recipient Phone',
                    ja: '受信先電話番号',
                    zh: '接收手机号',
                    vi: 'Số điện thoại nhận',
                    es: 'Teléfono destinatario',
                  ),
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: dlgCtx,
                      initialDate: dueDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2035),
                    );
                    if (picked != null) {
                      setDlgState(() => dueDate = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: LocalizationService.pick(
                        ko: '납부 기한',
                        en: 'Due Date',
                        ja: 'お支払い期限',
                        zh: '截止日期',
                        vi: 'Hạn thanh toán',
                        es: 'Fecha límite',
                      ),
                      prefixIcon: const Icon(Icons.event_outlined),
                      border: const OutlineInputBorder(),
                    ),
                    child: Text(DateFormat('yyyy.MM.dd').format(dueDate)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dlgCtx),
              child: Text(LocalizationService.tr('btn_cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                final amount = int.tryParse(amountCtrl.text.replaceAll(',', '').trim());
                if (title.isEmpty || amount == null || amount <= 0) return;

                if (!await MonetizationService.instance.ensureEditAllowed(dlgCtx, itemLabel: itemNoun)) {
                  return;
                }
                final updated = invoice.copyWith(
                  title: title,
                  amount: amount,
                  recipientPhone: phoneCtrl.text.trim(),
                  dueDate: dueDate,
                );
                await ref.read(invoicesProvider.notifier).updateInvoice(updated);
                await MonetizationService.instance.recordEditUsage();
                if (dlgCtx.mounted) Navigator.pop(dlgCtx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.pick(
                        ko: '청구서 정보가 수정되었습니다.',
                        en: 'Invoice updated.',
                        ja: '請求書情報を更新しました。',
                        zh: '账单信息已更新。',
                        vi: 'Đã cập nhật hóa đơn.',
                        es: 'Cobro actualizado.',
                      )),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: Text(LocalizationService.tr('btn_save'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRevertInvoiceToUnpaid(BuildContext context, Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          LocalizationService.pick(
            ko: '수납 취소 (미납 전환)',
            en: 'Revert to Unpaid',
            ja: '入金取消（未入金へ戻す）',
            zh: '撤销收款（转为待付）',
            vi: 'Hoàn tác về chưa thu',
            es: 'Marcar como pendiente',
          ),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: Text(
          LocalizationService.pick(
            ko: '\'${invoice.title}\' 건의 수납 완료 처리를 취소하고 미납 상태로 되돌리시겠습니까?',
            en: 'Revert \'${invoice.title}\' back to unpaid status?',
            ja: '「${invoice.title}」の入金を取消し、未入金状態に戻しますか？',
            zh: '确定将「${invoice.title}」撤回为待收款状态吗？',
            vi: 'Chuyển \'${invoice.title}\' về trạng thái chưa thanh toán?',
            es: '¿Marcar \'${invoice.title}\' nuevamente como pendiente?',
          ),
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(LocalizationService.tr('btn_close'), style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFD97706)),
            child: Text(
              LocalizationService.pick(
                ko: '미납으로 되돌리기',
                en: 'Mark Unpaid',
                ja: '未入金に戻す',
                zh: '转为待收',
                vi: 'Chuyển chưa thu',
                es: 'Marcar pendiente',
              ),
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(invoicesProvider.notifier).markAsUnpaid(invoice.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.pick(
              ko: '해당 청구서가 미납 상태로 전환되었습니다.',
              en: 'Invoice reverted to unpaid.',
              ja: '未入金状態に戻りました。',
              zh: '账单已转为待收状态。',
              vi: 'Hóa đơn đã chuyển về chưa thanh toán.',
              es: 'El cobro pasó a pendiente.',
            )),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _confirmDeleteInvoice(BuildContext context, Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.delete_outline_rounded, color: AppTheme.danger, size: 22),
            const SizedBox(width: 8),
            Text(
              LocalizationService.pick(
                ko: '청구서 삭제',
                en: 'Delete Invoice',
                ja: '請求書削除',
                zh: '删除账单',
                vi: 'Xóa hóa đơn',
                es: 'Eliminar cobro',
              ),
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
          ],
        ),
        content: Text(
          LocalizationService.pick(
            ko: '\'${invoice.title}\' 청구서를 삭제하시겠습니까?\n삭제된 청구 내역은 복구할 수 없습니다.',
            en: 'Delete \'${invoice.title}\'?\nThis action cannot be undone.',
            ja: '「${invoice.title}」を削除しますか？\n削除した履歴は復元できません。',
            zh: '确定删除「${invoice.title}」吗？\n删除后无法恢复。',
            vi: 'Xóa hóa đơn \'${invoice.title}\'?\nKhông thể hoàn tác sau khi xóa.',
            es: '¿Eliminar \'${invoice.title}\'?\nNo se puede deshacer.',
          ),
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgCtx, false),
            child: Text(LocalizationService.tr('btn_cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dlgCtx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text(LocalizationService.tr('btn_delete'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(invoicesProvider.notifier).deleteInvoice(invoice.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(LocalizationService.pick(
              ko: '청구서가 삭제되었습니다.',
              en: 'Invoice deleted.',
              ja: '請求書を削除しました。',
              zh: '账单已删除。',
              vi: 'Đã xóa hóa đơn.',
              es: 'Cobro eliminado.',
            )),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
        return StickyBottomSheetLayout(
          bodyPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      LocalizationService.pick(
                        ko: '청구서 전송 방법 선택',
                        en: 'Choose Invoice Delivery Method',
                        ja: '請求書の送信方法を選択',
                        zh: '选择账单发送方式',
                        vi: 'Chọn cách gửi hóa đơn',
                        es: 'Elegir método de envío',
                      ),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                LocalizationService.supportsTossTransfer
                    ? LocalizationService.pick(
                        ko: '수신: ${invoice.recipientPhone} (토스 1초 무료 송금 링크 자동 포함)',
                        en: 'To: ${invoice.recipientPhone} (${LocalizationService.currentCurrency.paymentChannels})',
                        ja: '宛先: ${invoice.recipientPhone} (${LocalizationService.currentCurrency.paymentChannels})',
                        zh: '收件人: ${invoice.recipientPhone} (${LocalizationService.currentCurrency.paymentChannels})',
                        vi: 'Đến: ${invoice.recipientPhone} (${LocalizationService.currentCurrency.paymentChannels})',
                        es: 'Para: ${invoice.recipientPhone} (${LocalizationService.currentCurrency.paymentChannels})',
                      )
                    : '${LocalizationService.pick(ko: '수신', en: 'To', ja: '宛先', zh: '收件人', vi: 'Đến', es: 'Para')}: ${invoice.recipientPhone} (${LocalizationService.currentCurrency.paymentChannels})',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 14),

              // Share / Messenger Direct Send
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
                      subject: '[${studio.studioName}] ${studio.feeTitle}',
                    );
                    if (ok && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(LocalizationService.pick(
                            ko: '카카오톡 공유가 실행되었습니다. (복사 완료)',
                            en: 'Opened share sheet & copied invoice text.',
                            ja: '共有を開き、請求内容をコピーしました。',
                            zh: '已打开分享并复制账单文本。',
                            vi: 'Đã mở chia sẻ & sao chép nội dung.',
                            es: 'Compartir abierto y texto copiado.',
                          )),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF191919), size: 17),
                  label: Text(
                    LocalizationService.supportsTossTransfer
                        ? LocalizationService.pick(
                            ko: '카카오톡 0원 전송 (토스 간편송금 포함)',
                            en: 'Share via Messenger (Free)',
                            ja: 'メッセージアプリで無料送信',
                            zh: '免费聊天软件转发',
                            vi: 'Gửi qua Messenger miễn phí',
                            es: 'Enviar por Chat (Gratis)',
                          )
                        : LocalizationService.pick(
                            ko: '카카오톡 / 메신저로 바로 공유',
                            en: 'Share via WhatsApp / Messenger',
                            ja: 'LINE / メッセージで送信',
                            zh: '微信 / 聊天应用转发',
                            vi: 'Chia sẻ qua Zalo / WhatsApp',
                            es: 'Compartir por WhatsApp / Chat',
                          ),
                    style: const TextStyle(color: Color(0xFF191919), fontWeight: FontWeight.w800, fontSize: 14.5),
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
                label: LocalizationService.pick(
                  ko: '문자 본문 내용 (수정 가능)',
                  en: 'Message Body (Editable)',
                  ja: 'メッセージ本文（編集可能）',
                  zh: '短信正文内容（可编辑）',
                  vi: 'Nội dung tin nhắn (Có thể sửa)',
                  es: 'Texto del mensaje (Editable)',
                ),
                maxLines: 6,
              ),
            ],
          ),
          footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
          footer: ResponsiveDialogActions(
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
                    SnackBar(
                      content: Text(LocalizationService.pick(
                        ko: '문자 앱을 실행할 수 없습니다. 번호를 확인해주세요.',
                        en: 'Could not open SMS app. Please check phone number.',
                        ja: 'SMSアプリを開けません。電話番号を確認してください。',
                        zh: '无法打开短信应用，请检查手机号。',
                        vi: 'Không mở được ứng dụng SMS. Kiểm tra lại số.',
                        es: 'No se pudo abrir la app de SMS. Revisa el número.',
                      )),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 16),
              label: Text(LocalizationService.pick(
                ko: '기본 문자 앱으로 전송',
                en: 'Send via SMS App',
                ja: 'SMSアプリで送信',
                zh: '通过默认短信发送',
                vi: 'Gửi qua ứng dụng SMS',
                es: 'Enviar por App de SMS',
              )),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
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
                          Text(
                            LocalizationService.pick(
                              ko: '수납 완료 처리',
                              en: 'Record Payment',
                              ja: '入金完了処理',
                              zh: '确认收款处理',
                              vi: 'Xác nhận thanh toán',
                              es: 'Registrar Pago',
                            ),
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${invoice.title} (${LocalizationService.formatAmount(invoice.amount)})',
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
                  title: LocalizationService.pick(
                    ko: '계좌 입금 확인',
                    en: 'Bank Transfer / ACH / Wire',
                    ja: '銀行振込確認',
                    zh: '银行转账确认',
                    vi: 'Chuyển khoản ngân hàng',
                    es: 'Transferencia Bancaria',
                  ),
                  subtitle: LocalizationService.pick(
                    ko: '은행 통장으로 실시간 무통장 입금 완료',
                    en: 'Direct deposit to studio bank account',
                    ja: '指定口座への振込入金を確認',
                    zh: '银行账户直连转入完成',
                    vi: 'Đã nhận chuyển khoản vào tài khoản',
                    es: 'Ingreso confirmado en cuenta bancaria',
                  ),
                  onTap: () => _confirmPayment(ctx, invoice, 'TRANSFER', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFECFDF5),
                    child: Icon(Icons.credit_card, color: AppTheme.softMint),
                  ),
                  title: LocalizationService.pick(
                    ko: '오프라인 카드 단말기 (현장 결제)',
                    en: 'Card Terminal (In-Person POS)',
                    ja: '店頭カード決済 (POS端末)',
                    zh: '现场刷卡 / POS 终端',
                    vi: 'Máy quẹt thẻ POS tại quầy',
                    es: 'Tarjeta en TPV Presencial',
                  ),
                  subtitle: LocalizationService.pick(
                    ko: '매장/학원 현장 신용·체크카드 결제',
                    en: 'Debit / Credit card swipe or tap on-site',
                    ja: '現地でのクレジットカード・タッチ決済',
                    zh: '店内借记卡/信用卡现场支付',
                    vi: 'Thanh toán thẻ tín dụng/ghi nợ trực tiếp',
                    es: 'Pago presencial con tarjeta de débito/crédito',
                  ),
                  onTap: () => _confirmPayment(ctx, invoice, 'OFFLINE_CARD', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.link_rounded, color: AppTheme.primaryBlue),
                  ),
                  title: LocalizationService.pick(
                    ko: '비대면 신용카드 결제 (원격 결제 링크)',
                    en: 'Remote Card Payment Link',
                    ja: 'オンラインカード決済リンク',
                    zh: '远程在线信用卡支付链接',
                    vi: 'Liên kết thẻ thanh toán từ xa',
                    es: 'Enlace de Pago con Tarjeta Online',
                  ),
                  subtitle: LocalizationService.supportsTossTransfer
                      ? LocalizationService.pick(
                          ko: '토스페이먼츠/페이앱/결제선생 원격 링크 승인 확인',
                          en: 'Card checkout link verified remotely',
                          ja: 'オンラインカード決済の承認確認',
                          zh: '远程支付链接核销确认',
                          vi: 'Xác nhận liên kết thanh toán từ xa',
                          es: 'Enlace de pago online aprobado',
                        )
                      : LocalizationService.currentCurrency.paymentChannelsSummary,
                  onTap: () => _confirmPayment(ctx, invoice, 'ONLINE_CARD', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFEF3C7),
                    child: Icon(Icons.qr_code_scanner, color: Color(0xFFD97706)),
                  ),
                  title: LocalizationService.supportsTossTransfer
                      ? LocalizationService.pick(
                          ko: '간편결제 (카카오페이 / 토스 / 제로페이 QR)',
                          en: 'Digital Wallet / QR Pay',
                          ja: 'QR / 電子マネー決済 (PayPay等)',
                          zh: '扫码快捷支付 (微信/支付宝)',
                          vi: 'Ví điện tử / QR Pay',
                          es: 'Pago Digital / QR (Bizum/PayPal)',
                        )
                      : LocalizationService.pick(
                          ko: '간편결제 / 모바일 QR 결제',
                          en: 'Digital Wallet / QR Pay (${LocalizationService.currentCurrency.code})',
                          ja: 'QR / 電子マネー決済 (PayPay・楽天ペイ等)',
                          zh: '移动扫码支付 (微信/支付宝/FPS)',
                          vi: 'Ví điện tử / VietQR (MoMo/ZaloPay)',
                          es: 'Billetera Digital / QR (Bizum/PayPal)',
                        ),
                  subtitle: LocalizationService.pick(
                    ko: '매장 비치 QR 코드 또는 송금 링크 결제',
                    en: 'Front-desk QR scan or mobile P2P wallet transfer',
                    ja: '店頭QRコード・モバイル送金決済',
                    zh: '前台二维码收款或手机钱包转账',
                    vi: 'Quét mã QR tại quầy hoặc chuyển qua ví',
                    es: 'Escaneo QR o transferencia P2P móvil',
                  ),
                  onTap: () => _confirmPayment(ctx, invoice, 'EASY_PAY', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3E8FF),
                    child: Icon(Icons.card_giftcard, color: Color(0xFF9333EA)),
                  ),
                  title: LocalizationService.supportsTossTransfer
                      ? LocalizationService.pick(
                          ko: '지역화폐 · 교육/스포츠 바우처',
                          en: 'Voucher / Subsidy / Corporate Benefit',
                          ja: '自治体クーポン・福利厚生券',
                          zh: '教育补贴 / 消费券 / 机构代金券',
                          vi: 'Phiếu ưu đãi / Học bổng / Trợ cấp',
                          es: 'Bono Educativo / Cupón / Subvención',
                        )
                      : LocalizationService.pick(
                          ko: '바우처 / 복지 포인트 / 상품권',
                          en: 'Voucher / Gift Card / Corporate Credit',
                          ja: 'ギフト券・福利厚生・補助金クーポン',
                          zh: '代金券 / 企业福利 / 教育补贴',
                          vi: 'Voucher / Thẻ quà tặng / Trợ cấp',
                          es: 'Bono / Tarjeta Regalo / Subvención',
                        ),
                  subtitle: LocalizationService.supportsTossTransfer
                      ? LocalizationService.pick(
                          ko: '지역사랑상품권, 평생교육바우처, 스포츠강좌이용권',
                          en: 'Education vouchers, employer wellness cards, or gift credits',
                          ja: '地域商品券・教育助成クーポン・福利厚生カード等',
                          zh: '消费补贴券、教育补助或礼品卡核销',
                          vi: 'Thẻ quà tặng, trợ cấp học tập hoặc ưu đãi hội viên',
                          es: 'Bonos culturales, deportivos o tarjetas regalo',
                        )
                      : LocalizationService.pick(
                          ko: '기업 복지 카드, 기프트 카드, 수강 바우처 결제',
                          en: 'HSA/FSA, wellness subsidies, gift cards, or vouchers',
                          ja: '福利厚生・自治体助成クーポン・ギフトカード等',
                          zh: '企业福利、礼品卡或补贴券抵扣',
                          vi: 'Thẻ quà tặng, phiếu ưu đãi hoặc gói tài trợ',
                          es: 'Bonos de empresa, cheques regalo o subvenciones',
                        ),
                  onTap: () => _confirmPayment(ctx, invoice, 'VOUCHER', invoiceMembers, studio),
                ),
                _buildPaymentMethodTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFFBEB),
                    child: Icon(Icons.payments_outlined, color: AppTheme.warning),
                  ),
                  title: LocalizationService.pick(
                    ko: '현금 수납',
                    en: 'Cash Payment',
                    ja: '現金払い',
                    zh: '现金收款',
                    vi: 'Tiền mặt',
                    es: 'Efectivo',
                  ),
                  subtitle: LocalizationService.pick(
                    ko: '현장 현금 수령 및 간이 영수',
                    en: 'Cash collected at front desk',
                    ja: '窓口での現金受取・領収書発行',
                    zh: '前台现金收取及收据登记',
                    vi: 'Thu tiền mặt tại quầy',
                    es: 'Cobro en efectivo en recepción',
                  ),
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
      MonetizationService.instance.triggerSmartInterstitialAd(
        cooldownSeconds: 75,
        actionThreshold: 2,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.pick(
            ko: '${invoice.title} 수납 처리가 완료되었습니다.',
            en: 'Payment recorded for ${invoice.title}.',
            ja: '「${invoice.title}」の入金処理が完了しました。',
            zh: '${invoice.title} 已完成收款确认。',
            vi: 'Đã ghi nhận thanh toán cho ${invoice.title}.',
            es: 'Pago registrado para ${invoice.title}.',
          )),
          action: SnackBarAction(
            label: LocalizationService.pick(
              ko: '영수증 알림',
              en: 'Send Receipt',
              ja: '領収通知',
              zh: '发送收据',
              vi: 'Gửi biên lai',
              es: 'Enviar recibo',
            ),
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
      (id: '교재비', label: LocalizationService.localizeBuiltInLabel('교재비')),
      (id: '임대료', label: LocalizationService.localizeBuiltInLabel('임대료')),
      (id: '강사료', label: LocalizationService.localizeBuiltInLabel('강사료')),
      (id: '소모품비', label: LocalizationService.localizeBuiltInLabel('소모품비')),
      (id: '시설관리', label: LocalizationService.localizeBuiltInLabel('시설관리')),
      (id: '공과금', label: LocalizationService.localizeBuiltInLabel('공과금')),
      (id: '기타', label: LocalizationService.localizeBuiltInLabel('기타')),
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
                  Text(
                    LocalizationService.pick(
                      ko: '기록된 지출/매입 내역이 없습니다',
                      en: 'No expenses or payouts recorded yet',
                      ja: '支出・支払履歴がまだありません',
                      zh: '暂无支出或采购记录',
                      vi: 'Chưa có khoản chi nào được ghi nhận',
                      es: 'Aún no hay gastos registrados',
                    ),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LocalizationService.pick(
                      ko: '학원·스튜디오 운영에 지출된 교재비, 임대료, 강사료를 기록하고\n실시간 손익과 순이익을 한눈에 관리하세요.',
                      en: 'Log rent, materials, supplies, and instructor payouts\nto track real-time profit & tax readiness.',
                      ja: '教材費・家賃・講師報酬などを記録して\nリアルタイムの収支と純利益を管理できます。',
                      zh: '记录教材费、房租和讲师薪酬，\n随时掌握实时盈亏与净利润。',
                      vi: 'Ghi chép tài liệu, tiền thuê, lương giảng viên\nđể theo dõi lãi lỗ và thuế theo thời gian thực.',
                      es: 'Registra alquileres, materiales y honorarios\npara controlar tu margen neto al instante.',
                    ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 18),
                  OutlinedButton.icon(
                    onPressed: () => _openAddExpenseSheet(context, vendors),
                    icon: const Icon(Icons.add, size: 18, color: AppTheme.primaryBlue),
                    label: Text(
                      LocalizationService.pick(
                        ko: '첫 지출 등록하기',
                        en: 'Record First Expense',
                        ja: '最初の支出を登録',
                        zh: '录入第一笔支出',
                        vi: 'Ghi khoản chi đầu tiên',
                        es: 'Registrar Primer Gasto',
                      ),
                      style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700, fontSize: 14),
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
                    ZeroBadge.neutral(
                      LocalizationService.localizeBuiltInLabel(expense.category),
                      size: ZeroBadgeSize.small,
                    ),
                    Text(
                      '$dateStr · ${LocalizationService.taxEvidenceLabel(expense.taxEvidence)}',
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
                                  SnackBar(
                                    content: Text(LocalizationService.pick(
                                      ko: '${vendor.bankName} 계좌번호가 복사되었습니다.',
                                      en: 'Copied ${vendor.bankName} account details.',
                                      ja: '${vendor.bankName} の口座情報をコピーしました。',
                                      zh: '已复制 ${vendor.bankName} 账户信息。',
                                      vi: 'Đã sao chép tài khoản ${vendor.bankName}.',
                                      es: 'Cuenta de ${vendor.bankName} copiada.',
                                    )),
                                    behavior: SnackBarBehavior.floating,
                                  ),
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
                              LocalizationService.supportsTossTransfer &&
                                      LocalizationService.currentLanguage == AppLanguage.korean
                                  ? '원천징수 3.3% (-${LocalizationService.formatAmount(expense.withholdingTax)}) · 실수령 ${LocalizationService.formatAmount(expense.actualPayoutAmount)}'
                                  : '${LocalizationService.withholdingDescription} (-${LocalizationService.formatAmount(expense.withholdingTax)}) · ${LocalizationService.pick(ko: '실수령', en: 'Net', ja: '手取り', zh: '实发', vi: 'Thực nhận', es: 'Neto')} ${LocalizationService.formatAmount(expense.actualPayoutAmount)}',
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
                    subject: LocalizationService.pick(
                      ko: '[${studio.studioName}] 발주 및 입금 확인',
                      en: '[${studio.studioName}] Order & Payment Notice',
                      ja: '[${studio.studioName}] 発注・振込確認',
                      zh: '[${studio.studioName}] 采购与付款确认',
                      vi: '[${studio.studioName}] Xác nhận đặt hàng & thanh toán',
                      es: '[${studio.studioName}] Pedido y Confirmación de Pago',
                    ),
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
                          subject: LocalizationService.pick(
                      ko: '[${studio.studioName}] 발주 및 입금 확인',
                      en: '[${studio.studioName}] Order & Payment Notice',
                      ja: '[${studio.studioName}] 発注・振込確認',
                      zh: '[${studio.studioName}] 采购与付款确认',
                      vi: '[${studio.studioName}] Xác nhận đặt hàng & thanh toán',
                      es: '[${studio.studioName}] Pedido y Confirmación de Pago',
                    ),
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
                  subject: LocalizationService.pick(
                    ko: '[${studio.studioName}] 발주 및 입금 확인',
                    en: '[${studio.studioName}] Order & Payment Notice',
                    ja: '[${studio.studioName}] 発注・振込確認',
                    zh: '[${studio.studioName}] 采购与付款确认',
                    vi: '[${studio.studioName}] Xác nhận đặt hàng & thanh toán',
                    es: '[${studio.studioName}] Pedido y Confirmación de Pago',
                  ),
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
                    title: Text(
                      LocalizationService.pick(
                        ko: '지출 내역 삭제',
                        en: 'Delete Expense',
                        ja: '支出履歴の削除',
                        zh: '删除支出记录',
                        vi: 'Xóa khoản chi',
                        es: 'Eliminar Gasto',
                      ),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    content: Text(LocalizationService.pick(
                      ko: '\'${expense.title}\' 지출 내역을 장부에서 삭제하시겠습니까?',
                      en: 'Delete \'${expense.title}\' from your ledger?',
                      ja: '「${expense.title}」の支出記録を削除しますか？',
                      zh: '确定从账本中删除「${expense.title}」吗？',
                      vi: 'Xóa khoản chi \'${expense.title}\' khỏi sổ?',
                      es: '¿Eliminar \'${expense.title}\' del libro?',
                    )),
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
                        title: Text(
                          LocalizationService.pick(
                            ko: '지출 내역 삭제',
                            en: 'Delete Expense',
                            ja: '支出履歴の削除',
                            zh: '删除支出记录',
                            vi: 'Xóa khoản chi',
                            es: 'Eliminar Gasto',
                          ),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        content: Text(LocalizationService.pick(
                          ko: '\'${expense.title}\' 지출 내역을 장부에서 삭제하시겠습니까?',
                          en: 'Delete \'${expense.title}\' from your ledger?',
                          ja: '「${expense.title}」の支出記録を削除しますか？',
                          zh: '确定从账本中删除「${expense.title}」吗？',
                          vi: 'Xóa khoản chi \'${expense.title}\' khỏi sổ?',
                          es: '¿Eliminar \'${expense.title}\' del libro?',
                        )),
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
    final double activeWhRate = LocalizationService.defaultWithholdingRate;
    bool isWithholdingApplied = editExpense?.isWithholdingApplied ??
        (selectedCategory == '강사료' && activeWhRate > 0);
    String selectedEvidence = editExpense?.taxEvidence ??
        (isWithholdingApplied ? '원천징수(3.3%)' : '세금계산서');
    Vendor? selectedVendor = editExpense?.vendorId != null
        ? vendors.where((v) => v.id == editExpense!.vendorId).firstOrNull
        : (vendors.isNotEmpty ? vendors.first : null);
    String directVendorName = editExpense?.vendorName ?? (selectedVendor?.name ?? '');

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.92,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return StickyBottomSheetLayout(
            header: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 12, 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    editExpense == null
                        ? LocalizationService.pick(
                            ko: '새 지출/매입 등록',
                            en: 'Add Expense / Payout',
                            ja: '新しい支出を登録',
                            zh: '录入新支出/采购',
                            vi: 'Thêm khoản chi mới',
                            es: 'Registrar Nuevo Gasto',
                          )
                        : LocalizationService.pick(
                            ko: '지출 내역 수정',
                            en: 'Edit Expense',
                            ja: '支出履歴を編集',
                            zh: '编辑支出记录',
                            vi: 'Sửa khoản chi',
                            es: 'Editar Gasto',
                          ),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetCtx)),
                ],
              ),
            ),
            bodyPadding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 거래처 선택 드롭다운 또는 직접 입력
                Text(
                  LocalizationService.pick(
                    ko: '거래처 (납품처/수취인)',
                    en: 'Vendor / Payee',
                    ja: '取引先・支払先',
                    zh: '供应商 / 收款方',
                    vi: 'Đối tác / Người nhận',
                    es: 'Proveedor / Destinatario',
                  ),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
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
                        hint: Text(LocalizationService.pick(
                          ko: '거래처를 선택하세요',
                          en: 'Select vendor / contractor',
                          ja: '取引先を選択',
                          zh: '选择供应商或讲师',
                          vi: 'Chọn đối tác',
                          es: 'Seleccionar proveedor',
                        )),
                        items: vendors.map((v) {
                          return DropdownMenuItem<Vendor>(
                            value: v,
                            child: Text('${v.name} (${LocalizationService.localizeBuiltInLabel(v.category)})', style: const TextStyle(fontSize: 14)),
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
                  label: LocalizationService.pick(
                    ko: '거래처 상호 직접 입력',
                    en: 'Vendor / Payee Name',
                    ja: '支払先名を入力',
                    zh: '直接输入收款方名称',
                    vi: 'Tên đối tác / người nhận',
                    es: 'Nombre del proveedor / destinatario',
                  ),
                  hint: LocalizationService.pick(
                    ko: '예: (주)영재교육, 우리건물 관리단, 홍길동 코치',
                    en: 'e.g., Book Supplier, Landlord, Coach Alex',
                    ja: '例: 〇〇出版社、管理会社、田中コーチ',
                    zh: '例: 教材出版社、物业管理处、王教练',
                    vi: 'VD: Nhà sách, Chủ nhà, HLV Minh',
                    es: 'Ej: Editorial, Arrendador, Entrenador',
                  ),
                  prefixIcon: Icons.storefront_outlined,
                  onChanged: (val) => directVendorName = val,
                ),
                const SizedBox(height: 12),

                // 지출 품목명
                AppTextField(
                  controller: titleCtrl,
                  label: LocalizationService.pick(
                    ko: '지출 항목 / 품목명',
                    en: 'Expense Title / Item',
                    ja: '支出項目・品目名',
                    zh: '支出项目 / 物品名称',
                    vi: 'Tên khoản chi / Mục',
                    es: 'Concepto del gasto',
                  ),
                  hint: LocalizationService.pick(
                    ko: '예: 5월 수학 워크북 30부, 스튜디오 월세, 소독 비품',
                    en: 'e.g., Workbooks, Monthly Studio Rent, Supplies',
                    ja: '例: 教材30冊、スタジオ家賃、備品',
                    zh: '例: 教材采购、场地月租、办公耗材',
                    vi: 'VD: Sách bài tập, Tiền thuê phòng, Vật tư',
                    es: 'Ej: Libros, Alquiler del local, Suministros',
                  ),
                  prefixIcon: Icons.shopping_bag_outlined,
                ),
                const SizedBox(height: 12),

                // 지출 금액
                AppTextField(
                  controller: amountCtrl,
                  label: '${LocalizationService.pick(ko: '지출 금액', en: 'Expense Amount', ja: '支出金額', zh: '支出金额', vi: 'Số tiền chi', es: 'Importe del gasto')} (${LocalizationService.currentCurrency.symbol})',
                  hint: LocalizationService.quickIncrementAmounts(expense: true).first.toString(),
                  keyboardType: TextInputType.number,
                  prefixIcon: Icons.payments_outlined,
                ),
                const SizedBox(height: 8),

                // 빠른 금액 가산 버튼
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: LocalizationService.quickIncrementAmounts(expense: true).map((amt) {
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
                      child: Text('+${LocalizationService.formatAmount(amt)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 14),

                // 분류 카테고리 선택
                Text(
                  LocalizationService.pick(
                    ko: '지출 분류',
                    en: 'Expense Category',
                    ja: '支出カテゴリ',
                    zh: '支出分类',
                    vi: 'Danh mục chi',
                    es: 'Categoría',
                  ),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['교재비', '임대료', '강사료', '소모품비', '시설관리', '공과금', '기타'].map((cat) {
                    final isSel = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(LocalizationService.localizeBuiltInLabel(cat), style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
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
                Text(
                  LocalizationService.pick(
                    ko: '결제 수단',
                    en: 'Payment Method',
                    ja: '支払方法',
                    zh: '付款方式',
                    vi: 'Phương thức thanh toán',
                    es: 'Método de pago',
                  ),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ['계좌이체', '신용카드', '현금', '간편결제'].map((m) {
                    final isSel = selectedMethod == m;
                    return ChoiceChip(
                      label: Text(LocalizationService.localizeBuiltInLabel(m), style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
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

                // 국가별 원천징수 계산기
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                        ? '3.3% 프리랜서 원천징수 적용'
                        : LocalizationService.withholdingDescription,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                        ? '사업소득세 3% + 지방소득세 0.3% 자동 공제 계산'
                        : LocalizationService.currentCurrency.taxPolicy,
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
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
                    final calcTax = isWithholdingApplied ? ((curAmount * activeWhRate).round()) : 0;
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
                                Text(
                                  LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                                      ? '원천징수 세액 (3.3%)'
                                      : LocalizationService.pick(
                                          ko: '원천징수 세액 (${(activeWhRate * 100).toStringAsFixed(1)}%)',
                                          en: 'Withheld Tax (${(activeWhRate * 100).toStringAsFixed(1)}%)',
                                          ja: '源泉徴収税額 (${(activeWhRate * 100).toStringAsFixed(2)}%)',
                                          zh: '预扣税额 (${(activeWhRate * 100).toStringAsFixed(1)}%)',
                                          vi: 'Thuế khấu trừ (${(activeWhRate * 100).toStringAsFixed(1)}%)',
                                          es: 'Retención fiscal (${(activeWhRate * 100).toStringAsFixed(1)}%)',
                                        ),
                                  style: const TextStyle(fontSize: 12.5, color: Color(0xFF4338CA), fontWeight: FontWeight.w600),
                                ),
                                Text('- ${LocalizationService.formatAmount(calcTax)}', style: const TextStyle(fontSize: 13, color: Color(0xFFDC2626), fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  LocalizationService.pick(
                                    ko: '실제 이체할 실수령액',
                                    en: 'Net Payout to Contractor',
                                    ja: '差引手取り支払額',
                                    zh: '实际应付净额',
                                    vi: 'Số tiền thực trả',
                                    es: 'Importe neto a transferir',
                                  ),
                                  style: const TextStyle(fontSize: 13.5, color: Color(0xFF1E1B4B), fontWeight: FontWeight.w800),
                                ),
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

                // 세무 적격증빙 유형
                Text(
                  LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                      ? '세무 적격증빙 유형 (국세청 간편장부)'
                      : LocalizationService.pick(
                          ko: '세무 적격증빙 유형',
                          en: 'Tax Evidence / Receipt Type (${LocalizationService.currentCurrency.code})',
                          ja: '税務証憑の種類 (${LocalizationService.currentCurrency.code})',
                          zh: '税务凭证类型 (${LocalizationService.currentCurrency.code})',
                          vi: 'Loại chứng từ thuế (${LocalizationService.currentCurrency.code})',
                          es: 'Tipo de comprobante fiscal (${LocalizationService.currentCurrency.code})',
                        ),
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: ExpenseItem.taxEvidenceTypes.map((ev) {
                    final isSel = selectedEvidence == ev;
                    return ChoiceChip(
                      label: Text(LocalizationService.taxEvidenceLabel(ev), style: TextStyle(fontSize: 11.5, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
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
                    if (LocalizationService.supportsTossTransfer && selectedEvidence == '간이영수증' && curAmount > 30000) {
                      return Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFFBEB),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 14, color: Color(0xFFD97706)),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                LocalizationService.pick(
                                  ko: '3만원 초과 간이영수증은 세법상 증빙불비 가산세(2%) 대상이 될 수 있습니다.',
                                  en: 'Korean tax alert: Paper receipts over ₩30,000 may incur a 2% penalty.',
                                  ja: '韓国税法注意: 3万ウォン超の簡易領収書は加算税(2%)の対象になる場合があります。',
                                  zh: '韩国税法提示: 超过3万韩元的普通收据可能产生2%附加税。',
                                  vi: 'Lưu ý thuế Hàn: Hóa đơn thường trên 30,000₩ có thể bị phạt 2%.',
                                  es: 'Alerta fiscal Corea: Recibos simples > ₩30,000 pueden tener recargo del 2%.',
                                ),
                                style: const TextStyle(fontSize: 11, color: Color(0xFFB45309), fontWeight: FontWeight.w600),
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
                  title: Text(
                    LocalizationService.pick(
                      ko: '지급 완료 (완납)',
                      en: 'Marked as Paid',
                      ja: '支払完了',
                      zh: '已付款 (结清)',
                      vi: 'Đã thanh toán',
                      es: 'Pagado',
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    isPaid
                        ? LocalizationService.pick(
                            ko: '대금 이체 완료',
                            en: 'Payment sent / settled',
                            ja: '送金・精算完了',
                            zh: '款项已付清',
                            vi: 'Đã chuyển tiền',
                            es: 'Pago realizado',
                          )
                        : LocalizationService.pick(
                            ko: '미지급 / 외상 대기 상태',
                            en: 'Unpaid / Accounts payable',
                            ja: '未払い・買掛待ち',
                            zh: '待付款 / 应付账款',
                            vi: 'Chưa thanh toán / Công nợ',
                            es: 'Pendiente de pago',
                          ),
                    style: const TextStyle(fontSize: 12),
                  ),
                  value: isPaid,
                  activeThumbColor: const Color(0xFF10B981),
                  onChanged: (val) => setSheetState(() => isPaid = val),
                ),
                const SizedBox(height: 8),

                // 메모
                AppTextField(
                  controller: memoCtrl,
                  label: LocalizationService.pick(
                    ko: '비고 / 메모 (선택)',
                    en: 'Notes / Memo (Optional)',
                    ja: '備考・メモ（任意）',
                    zh: '备注 / 备忘（可选）',
                    vi: 'Ghi chú (Tùy chọn)',
                    es: 'Notas / Memo (Opcional)',
                  ),
                  hint: LocalizationService.pick(
                    ko: '예: 5월 10일 정산 예정, 택배 수령 완료',
                    en: 'e.g., Invoice #1024, Scheduled transfer',
                    ja: '例: 月末締め払い、納品完了',
                    zh: '例: 发票号#1024，已收货验收',
                    vi: 'VD: Thanh toán cuối tháng, Đã nhận hàng',
                    es: 'Ej: Factura #1024, Entrega confirmada',
                  ),
                  prefixIcon: Icons.notes_outlined,
                ),
              ],
            ),
            footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            footer: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final amount = int.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
                  final vName = directVendorName.trim().isEmpty
                      ? LocalizationService.pick(
                          ko: '일반 거래처',
                          en: 'General Vendor',
                          ja: '一般取引先',
                          zh: '一般供应商',
                          vi: 'Đối tác chung',
                          es: 'Proveedor General',
                        )
                      : directVendorName.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LocalizationService.pick(
                      ko: '지출 품목명을 입력해주세요.',
                      en: 'Please enter an expense title.',
                      ja: '支出項目名を入力してください。',
                      zh: '请输入支出项目名称。',
                      vi: 'Vui lòng nhập tên khoản chi.',
                      es: 'Ingresa el concepto del gasto.',
                    ))));
                    return;
                  }
                  if (amount <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LocalizationService.pick(
                      ko: '금액을 올바르게 입력해주세요.',
                      en: 'Please enter a valid amount.',
                      ja: '金額を正しく入力してください。',
                      zh: '请输入有效金额。',
                      vi: 'Vui lòng nhập số tiền hợp lệ.',
                      es: 'Ingresa un importe válido.',
                    ))));
                    return;
                  }

                  final withTax = isWithholdingApplied ? ((amount * activeWhRate).round()) : 0;
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

                  final bm = MonetizationService.instance;
                  final expLabel = LocalizationService.pick(
                    ko: '지출·매입',
                    en: 'Expense',
                    ja: '支出',
                    zh: '支出记录',
                    vi: 'Khoản chi',
                    es: 'Gasto',
                  );
                  if (editExpense == null) {
                    final curExp = ref.read(expensesProvider).value?.length ?? 0;
                    if (!await bm.ensureCreateAllowed(
                      sheetCtx,
                      itemLabel: expLabel,
                      currentCount: curExp,
                      limit: bm.maxExpenseLimit,
                    )) {
                      return;
                    }
                    await ref.read(expensesProvider.notifier).addExpense(item);
                    bm.triggerSmartInterstitialAd(
                      cooldownSeconds: 75,
                      actionThreshold: 2,
                    );
                  } else {
                    if (!await bm.ensureEditAllowed(sheetCtx, itemLabel: expLabel)) {
                      return;
                    }
                    await ref.read(expensesProvider.notifier).updateExpense(item);
                    await bm.recordEditUsage();
                  }

                  if (sheetCtx.mounted) Navigator.pop(sheetCtx);

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.pick(
                          ko: '${item.title} (${LocalizationService.formatAmount(amount)}) 지출이 저장되었습니다.',
                          en: 'Saved expense: ${item.title} (${LocalizationService.formatAmount(amount)})',
                          ja: '${item.title} (${LocalizationService.formatAmount(amount)}) を保存しました。',
                          zh: '已保存支出: ${item.title} (${LocalizationService.formatAmount(amount)})',
                          vi: 'Đã lưu khoản chi: ${item.title} (${LocalizationService.formatAmount(amount)})',
                          es: 'Gasto guardado: ${item.title} (${LocalizationService.formatAmount(amount)})',
                        )),
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
                  editExpense == null
                      ? LocalizationService.pick(
                          ko: '지출 내역 등록 완료',
                          en: 'Save Expense',
                          ja: '支出を登録する',
                          zh: '保存支出记录',
                          vi: 'Lưu khoản chi',
                          es: 'Guardar Gasto',
                        )
                      : LocalizationService.pick(
                          ko: '수정 내용 저장',
                          en: 'Update Expense',
                          ja: '変更を保存',
                          zh: '保存修改',
                          vi: 'Cập nhật khoản chi',
                          es: 'Guardar Cambios',
                        ),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
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
      builder: (sheetCtx) => StickyBottomSheetLayout(
        bodyPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.business_center_outlined, color: Color(0xFF4F46E5), size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LocalizationService.pick(
                            ko: '거래처 수첩 (B2B 납품처)',
                            en: 'Vendors & Instructors Directory',
                            ja: '取引先・講師帳簿',
                            zh: '供应商与讲师名录',
                            vi: 'Danh bạ đối tác & giảng viên',
                            es: 'Directorio de Proveedores',
                          ),
                          softWrap: true,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(sheetCtx)),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              LocalizationService.pick(
                ko: '교재사, 기구사, 관리사무소, 파트너 강사의 계좌 및 연락처 목록입니다.',
                en: 'Save bank/payout accounts & contacts for suppliers, landlords, and instructors.',
                ja: '教材社・管理会社・パートナー講師の口座や連絡先をまとめて管理できます。',
                zh: '保存教材商、物业及合作讲师的收款账户与联系方式。',
                vi: 'Lưu tài khoản & liên hệ của nhà cung cấp, chủ nhà và giảng viên.',
                es: 'Guarda cuentas de pago y contactos de proveedores, alquiler y profesores.',
              ),
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),

            if (vendors.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    LocalizationService.pick(
                      ko: '등록된 거래처가 없습니다.',
                      en: 'No vendors registered yet.',
                      ja: '登録された取引先はありません。',
                      zh: '暂无已登记的供应商或讲师。',
                      vi: 'Chưa có đối tác nào được lưu.',
                      es: 'No hay proveedores registrados.',
                    ),
                    style: const TextStyle(color: AppTheme.textTertiary),
                  ),
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
                                    LocalizationService.localizeBuiltInLabel(v.category),
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
                                      title: Text(
                                        LocalizationService.pick(
                                          ko: '거래처 삭제',
                                          en: 'Delete Vendor',
                                          ja: '取引先を削除',
                                          zh: '删除供应商',
                                          vi: 'Xóa đối tác',
                                          es: 'Eliminar Proveedor',
                                        ),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      content: Text(LocalizationService.pick(
                                        ko: '\'${v.name}\' 거래처를 삭제하시겠습니까?',
                                        en: 'Remove \'${v.name}\' from directory?',
                                        ja: '「${v.name}」を削除しますか？',
                                        zh: '确定删除「${v.name}」吗？',
                                        vi: 'Xóa đối tác \'${v.name}\'?',
                                        es: '¿Eliminar a \'${v.name}\'?',
                                      )),
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
                                  SnackBar(
                                    content: Text(LocalizationService.pick(
                                      ko: '${v.bankName} 계좌번호가 복사되었습니다.',
                                      en: 'Copied ${v.bankName} account details.',
                                      ja: '${v.bankName} の口座情報をコピーしました。',
                                      zh: '已复制 ${v.bankName} 账户信息。',
                                      vi: 'Đã sao chép tài khoản ${v.bankName}.',
                                      es: 'Cuenta de ${v.bankName} copiada.',
                                    )),
                                    behavior: SnackBarBehavior.floating,
                                  ),
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
                              child: Text(
                                LocalizationService.pick(
                                  ko: '통화',
                                  en: 'Call',
                                  ja: '発信',
                                  zh: '拨打',
                                  vi: 'Gọi',
                                  es: 'Llamar',
                                ),
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (v.memo != null && v.memo!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${LocalizationService.pick(ko: '메모', en: 'Note', ja: 'メモ', zh: '备注', vi: 'Ghi chú', es: 'Nota')}: ${v.memo}',
                          style: const TextStyle(fontSize: 11.5, color: AppTheme.textTertiary),
                        ),
                      ],
                    ],
                  ),
                );
              }),
          ],
        ),
        footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        footer: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _openAddEditVendorDialog(context),
            icon: const Icon(Icons.add, size: 18, color: Color(0xFF4F46E5)),
            label: Text(
              LocalizationService.pick(
                ko: '새 거래처 등록하기',
                en: 'Add New Vendor / Instructor',
                ja: '新しい取引先・講師を登録',
                zh: '添加新供应商 / 讲师',
                vi: 'Thêm đối tác / giảng viên mới',
                es: 'Añadir Nuevo Proveedor',
              ),
              style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFF6366F1), width: 1.2),
              backgroundColor: const Color(0xFFEEF2FF),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
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
            editVendor == null
                ? LocalizationService.pick(
                    ko: '새 거래처 등록',
                    en: 'Add Vendor / Payee',
                    ja: '取引先の新規登録',
                    zh: '登记新供应商',
                    vi: 'Thêm đối tác mới',
                    es: 'Nuevo Proveedor',
                  )
                : LocalizationService.pick(
                    ko: '거래처 정보 수정',
                    en: 'Edit Vendor / Payee',
                    ja: '取引先情報を編集',
                    zh: '编辑供应商信息',
                    vi: 'Sửa thông tin đối tác',
                    es: 'Editar Proveedor',
                  ),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: nameCtrl,
                  label: LocalizationService.pick(
                    ko: '상호 / 거래처명 (필수)',
                    en: 'Vendor / Payee Name (Required)',
                    ja: '取引先名・屋号（必須）',
                    zh: '供应商 / 收款方名称（必填）',
                    vi: 'Tên đối tác (Bắt buộc)',
                    es: 'Nombre del proveedor (Obligatorio)',
                  ),
                  hint: LocalizationService.pick(
                    ko: '예: (주)에듀프라임 교재총판',
                    en: 'e.g., EduBooks Co., Coach Sam',
                    ja: '例: 〇〇教材株式会社、佐藤講師',
                    zh: '例: 启智图书有限公司、张教练',
                    vi: 'VD: Công ty Sách Edu, HLV Minh',
                    es: 'Ej: Editorial Edu, Entrenador',
                  ),
                  prefixIcon: Icons.storefront_outlined,
                ),
                const SizedBox(height: 10),
                Text(
                  LocalizationService.pick(
                    ko: '거래처 분류',
                    en: 'Category',
                    ja: '取引先カテゴリ',
                    zh: '分类',
                    vi: 'Danh mục',
                    es: 'Categoría',
                  ),
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: ['교재/교구', '시설/기구', '임대/관리비', '강사/코치료', '소모품/비품', '기타'].map((cat) {
                    final isSel = selectedCategory == cat;
                    return ChoiceChip(
                      label: Text(LocalizationService.localizeBuiltInLabel(cat), style: TextStyle(fontSize: 11.5, color: isSel ? Colors.white : AppTheme.textPrimary)),
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
                  label: LocalizationService.pick(
                    ko: '입금 은행',
                    en: 'Bank / Payment App',
                    ja: '振込先銀行',
                    zh: '收款银行 / 平台',
                    vi: 'Ngân hàng nhận',
                    es: 'Banco / Plataforma',
                  ),
                  hint: LocalizationService.currentCurrency.bankHint,
                  prefixIcon: Icons.account_balance,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: accountCtrl,
                  label: LocalizationService.pick(
                    ko: '계좌번호',
                    en: 'Account Number / IBAN / Handle',
                    ja: '口座番号',
                    zh: '账号 / 收款账号',
                    vi: 'Số tài khoản',
                    es: 'Número de cuenta / IBAN',
                  ),
                  hint: LocalizationService.pick(
                    ko: '숫자만 또는 하이픈 포함',
                    en: 'Account number or payment handle',
                    ja: '口座番号を入力',
                    zh: '输入银行账号或收款号',
                    vi: 'Nhập số tài khoản',
                    es: 'Número de cuenta o referencia',
                  ),
                  prefixIcon: Icons.payment,
                  keyboardType: TextInputType.text,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: holderCtrl,
                  label: LocalizationService.pick(
                    ko: '예금주',
                    en: 'Account Holder',
                    ja: '口座名義',
                    zh: '户名',
                    vi: 'Chủ tài khoản',
                    es: 'Titular de la cuenta',
                  ),
                  hint: LocalizationService.pick(
                    ko: '예: 김영수 (에듀프라임)',
                    en: 'e.g., Alex Morgan',
                    ja: '例: カ）エデュプライム',
                    zh: '例: 李明（启智教育）',
                    vi: 'VD: Nguyễn Văn A',
                    es: 'Ej: Carlos García',
                  ),
                  prefixIcon: Icons.person_outline,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: phoneCtrl,
                  label: LocalizationService.pick(
                    ko: '연락처 (선택)',
                    en: 'Phone (Optional)',
                    ja: '電話番号（任意）',
                    zh: '联系电话（可选）',
                    vi: 'Số điện thoại (Tùy chọn)',
                    es: 'Teléfono (Opcional)',
                  ),
                  hint: LocalizationService.currentCurrency.phoneHint,
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 10),
                AppTextField(
                  controller: memoCtrl,
                  label: LocalizationService.pick(
                    ko: '메모 (선택)',
                    en: 'Memo (Optional)',
                    ja: 'メモ（任意）',
                    zh: '备注（可选）',
                    vi: 'Ghi chú (Tùy chọn)',
                    es: 'Nota (Opcional)',
                  ),
                  hint: LocalizationService.pick(
                    ko: '담당자명, 정기 발주일 등',
                    en: 'Contact person, payout day, etc.',
                    ja: '担当者名、毎月の締日など',
                    zh: '联系人、固定结算日等',
                    vi: 'Tên liên hệ, ngày thanh toán...',
                    es: 'Contacto, día de pago, etc.',
                  ),
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
                    label: editVendor != null
                        ? LocalizationService.pick(
                            ko: '수정 완료',
                            en: 'Update',
                            ja: '更新完了',
                            zh: '保存修改',
                            vi: 'Cập nhật',
                            es: 'Actualizar',
                          )
                        : LocalizationService.pick(
                            ko: '등록 완료',
                            en: 'Add',
                            ja: '登録完了',
                            zh: '确认添加',
                            vi: 'Thêm mới',
                            es: 'Guardar',
                          ),
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () async {
                final name = nameCtrl.text.trim();
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LocalizationService.pick(
                    ko: '거래처 상호를 입력해주세요.',
                    en: 'Please enter a vendor name.',
                    ja: '取引先名を入力してください。',
                    zh: '请输入供应商名称。',
                    vi: 'Vui lòng nhập tên đối tác.',
                    es: 'Ingresa el nombre del proveedor.',
                  ))));
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

                final bm = MonetizationService.instance;
                final vendorLabel = LocalizationService.pick(
                  ko: '거래처',
                  en: 'Vendor',
                  ja: '取引先',
                  zh: '供应商',
                  vi: 'Đối tác',
                  es: 'Proveedor',
                );
                if (editVendor == null) {
                  final curVendors = ref.read(vendorsProvider).value?.length ?? 0;
                  if (!await bm.ensureCreateAllowed(
                    dlgCtx,
                    itemLabel: vendorLabel,
                    currentCount: curVendors,
                    limit: bm.maxVendorLimit,
                  )) {
                    return;
                  }
                  await ref.read(vendorsProvider.notifier).addVendor(vendor);
                } else {
                  if (!await bm.ensureEditAllowed(dlgCtx, itemLabel: vendorLabel)) {
                    return;
                  }
                  await ref.read(vendorsProvider.notifier).updateVendor(vendor);
                  await bm.recordEditUsage();
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
        title: Row(
          children: [
            const Icon(Icons.sync_alt_rounded, color: AppTheme.primaryBlue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LocalizationService.pick(
                  ko: '은행 푸시 알림 장부 매칭',
                  en: 'Bank Push Deposit Auto-Match',
                  ja: '銀行入金通知 自動照合',
                  zh: '银行收款通知自动对账',
                  vi: 'Tự động khớp thông báo ngân hàng',
                  es: 'Detección Automática de Pagos',
                ),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                LocalizationService.pick(
                  ko: '안드로이드 기기에 수신되는 은행 알림을 필터링하여 자동으로 장부와 대조합니다.',
                  en: 'Reads incoming bank/wallet alerts on Android and reconciles matching unpaid invoices automatically.',
                  ja: '端末で受信した銀行入金通知をフィルタリングし、未入金請求書と自動照合します。',
                  zh: '过滤设备收到的银行到账提醒，并自动与待收款账单核销匹配。',
                  vi: 'Lọc thông báo nhận tiền ngân hàng trên thiết bị để tự động gạch nợ hóa đơn.',
                  es: 'Lee las notificaciones bancarias entrantes para conciliar cobros pendientes.',
                ),
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              if (unpaidInvoices.isEmpty)
                Text(LocalizationService.pick(
                  ko: '현재 매칭 대기 중인 미납 청구서가 없습니다.',
                  en: 'There are no unpaid invoices waiting to be matched.',
                  ja: '照合待ちの未入金請求書はありません。',
                  zh: '当前没有待对账的未收款账单。',
                  vi: 'Hiện không có hóa đơn chưa thu nào chờ đối soát.',
                  es: 'No hay cobros pendientes por conciliar.',
                ))
            else
              Column(
                children: unpaidInvoices.take(2).map((inv) {
                    final invoiceMembers = inv.memberIds.map((id) => members.where((m) => m.id == id).firstOrNull).whereType<Member>().toList();
                    final guardianTag = LocalizationService.pick(
                      ko: '학부모',
                      en: 'Payer',
                      ja: '保護者',
                      zh: '家长',
                      vi: 'Phụ huynh',
                      es: 'Pagador',
                    );
                    final payerOrStudent = invoiceMembers.isNotEmpty && invoiceMembers.first.payerName != null
                        ? '${invoiceMembers.first.name} ($guardianTag: ${invoiceMembers.first.payerName})'
                        : inv.title;
                    final simSenderName = invoiceMembers.isNotEmpty && invoiceMembers.first.payerName != null
                        ? invoiceMembers.first.payerName!
                        : (invoiceMembers.isNotEmpty ? invoiceMembers.first.name.split(' ').first : 'Member');

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(payerOrStudent, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                      subtitle: Text(
                        LocalizationService.pick(
                          ko: '${LocalizationService.formatAmount(inv.amount)} 입금 시뮬레이션 (입금자: $simSenderName)',
                          en: 'Simulate ${LocalizationService.formatAmount(inv.amount)} deposit (Sender: $simSenderName)',
                          ja: '${LocalizationService.formatAmount(inv.amount)} 入金テスト (振込人: $simSenderName)',
                          zh: '模拟到账 ${LocalizationService.formatAmount(inv.amount)} (付款人: $simSenderName)',
                          vi: 'Mô phỏng nhận ${LocalizationService.formatAmount(inv.amount)} (Người gửi: $simSenderName)',
                          es: 'Simular ingreso ${LocalizationService.formatAmount(inv.amount)} ($simSenderName)',
                        ),
                      ),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          final event = BankNotificationFilter.parseDepositNotification(
                            packageName: 'viva.republica.toss',
                            title: LocalizationService.currentCurrency.defaultBankName,
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
                                  content: Text(LocalizationService.pick(
                                    ko: '은행 알림 감지 [${match.matchType}]: ${match.matchedMemberName ?? match.invoice.title} (${LocalizationService.formatAmount(event.amount)}) 자동 입금 처리 완료!',
                                    en: 'Deposit Matched [${match.matchType}]: ${match.matchedMemberName ?? match.invoice.title} (${LocalizationService.formatAmount(event.amount)}) marked paid!',
                                    ja: '入金通知検出 [${match.matchType}]: ${match.matchedMemberName ?? match.invoice.title} (${LocalizationService.formatAmount(event.amount)}) 自動入金完了！',
                                    zh: '检测到银行通知 [${match.matchType}]: ${match.matchedMemberName ?? match.invoice.title} (${LocalizationService.formatAmount(event.amount)}) 已自动核销！',
                                    vi: 'Khớp tự động [${match.matchType}]: ${match.matchedMemberName ?? match.invoice.title} (${LocalizationService.formatAmount(event.amount)}) đã thu!',
                                    es: 'Pago detectado [${match.matchType}]: ${match.matchedMemberName ?? match.invoice.title} (${LocalizationService.formatAmount(event.amount)}) confirmado!',
                                  )),
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
                        child: Text(
                          LocalizationService.pick(
                            ko: '자동매칭',
                            en: 'Auto-Match',
                            ja: '自動照合',
                            zh: '自动匹配',
                            vi: 'Khớp ngay',
                            es: 'Conciliar',
                          ),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(LocalizationService.tr('btn_close'))),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService.pick(
                          ko: '간편장부 엑셀 및 세무 관리',
                          en: 'Tax Ledger CSV & Guide',
                          ja: '簡易帳簿CSV & 税務ガイド',
                          zh: '简易账簿CSV与税务指南',
                          vi: 'Sổ thuế CSV & Hướng dẫn',
                          es: 'Libro Fiscal CSV y Guía',
                        ),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                            ? '국세청 표준 사업소득 간편장부 CSV 추출 및 1분 세무 가이드'
                            : LocalizationService.currentCurrency.taxPolicy,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                title: Text(
                  LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                      ? '국세청 사업소득 간편장부 엑셀(CSV) 내보내기'
                      : LocalizationService.pick(
                          ko: '사업소득 간편장부 엑셀(CSV) 내보내기 (${LocalizationService.currentCurrency.code})',
                          en: 'Export Income & Expense Ledger CSV (${LocalizationService.currentCurrency.code})',
                          ja: '収支簡易帳簿 CSVエクスポート (${LocalizationService.currentCurrency.code})',
                          zh: '导出收支明细台账 CSV (${LocalizationService.currentCurrency.code})',
                          vi: 'Xuất sổ thu chi CSV (${LocalizationService.currentCurrency.code})',
                          es: 'Exportar Libro Contable CSV (${LocalizationService.currentCurrency.code})',
                        ),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                subtitle: Text(
                  LocalizationService.pick(
                    ko: '수입과 지출 통합 정렬 엑셀 호환 표준 CSV 생성 및 카톡 공유',
                    en: 'Generate Excel-ready revenue & expense CSV and share with your accountant',
                    ja: '収入・支出を時系列で整理したExcel対応CSVを作成・共有します',
                    zh: '生成兼容 Excel 的收支明细 CSV 表格并可直接分享给会计',
                    vi: 'Tạo tệp CSV chuẩn Excel tổng hợp thu chi để chia sẻ cho kế toán',
                    es: 'Genera un CSV compatible con Excel con ingresos y gastos para tu gestor',
                  ),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
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
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${LocalizationService.tr('common_error')}: $e')));
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
                title: Text(
                  LocalizationService.pick(
                    ko: '소상공인 간편장부 세무 신고 꿀팁 가이드',
                    en: 'Small Business Tax & Bookkeeping Guide',
                    ja: '個人事業主・小規模事業の確定申告ガイド',
                    zh: '小微商户记账与报税实用指南',
                    vi: 'Hướng dẫn kê khai thuế & sổ sách hộ KD',
                    es: 'Guía Práctica Fiscal para Autónomos',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                ),
                subtitle: Text(
                  LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                      ? '5월 종합소득세, 2월 사업장현황신고, 3.3% 원천세 1분 마스터'
                      : LocalizationService.currentCurrency.taxPolicy,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
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
      _titleController.text = LocalizationService.pick(
        ko: '${now.month}월 $feeWord 안내',
        en: '${DateFormat.MMM().format(now)} $feeWord Notice',
        ja: '${now.month}月 $feeWord のご案内',
        zh: '${now.month}月 $feeWord 通知',
        vi: '$feeWord Tháng ${now.month}',
        es: '$feeWord de ${DateFormat.MMM().format(now)}',
      );
      _amountController.text = widget.studio.defaultMonthlyFee > 0
          ? widget.studio.defaultMonthlyFee.toString()
          : (LocalizationService.quickIncrementAmounts().elementAtOrNull(2) ?? 100000).toString();
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

    final fallbackFee = widget.studio.defaultMonthlyFee > 0 ? widget.studio.defaultMonthlyFee : 250000;
    _originalSiblingTotal = totalDefault > 0 ? totalDefault : fallbackFee;
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
    final bundleNames = selectedMembers.map((s) => s.primaryName).join('/');
    _titleController.text = selectedMembers.length > 1
        ? LocalizationService.pick(
            ko: '${now.month}월 $feeWord ($bundleNames 형제·가족 합산${_applySiblingDiscount ? ' [할인적용]' : ''})',
            en: '${DateFormat.MMM().format(now)} $feeWord ($bundleNames Family Bundle${_applySiblingDiscount ? ' [Discount]' : ''})',
            ja: '${now.month}月 $feeWord ($bundleNames 家族まとめ${_applySiblingDiscount ? ' [割引適用]' : ''})',
            zh: '${now.month}月 $feeWord ($bundleNames 家庭合并${_applySiblingDiscount ? ' [已优惠]' : ''})',
            vi: '$feeWord T${now.month} ($bundleNames Gói gia đình${_applySiblingDiscount ? ' [Giảm giá]' : ''})',
            es: '$feeWord ${DateFormat.MMM().format(now)} ($bundleNames Pack Familiar${_applySiblingDiscount ? ' [Desc.]' : ''})',
          )
        : LocalizationService.pick(
            ko: '${selectedMembers.first.primaryName} ${now.month}월 $feeWord 안내',
            en: '${selectedMembers.first.primaryName} - ${DateFormat.MMM().format(now)} $feeWord',
            ja: '${selectedMembers.first.primaryName} ${now.month}月 $feeWord のご案内',
            zh: '${selectedMembers.first.primaryName} ${now.month}月 $feeWord 通知',
            vi: '${selectedMembers.first.primaryName} - $feeWord T${now.month}',
            es: '${selectedMembers.first.primaryName} - $feeWord ${DateFormat.MMM().format(now)}',
          );
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

    return StickyBottomSheetLayout(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.edit_note, color: AppTheme.primaryBlue, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      LocalizationService.pick(
                        ko: '간편 청구서 작성',
                        en: 'Create Quick Invoice',
                        ja: 'かんたん請求書作成',
                        zh: '快速创建账单',
                        vi: 'Tạo hóa đơn nhanh',
                        es: 'Crear Cobro Rápido',
                      ),
                      softWrap: true,
                      style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
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
      ),
      bodyPadding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [

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
                  Row(
                    children: [
                      const Icon(Icons.info_outline, color: AppTheme.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LocalizationService.pick(
                            ko: '등록된 회원이 없어도 바로 작성 가능',
                            en: 'No members yet? Create an invoice right away',
                            ja: '会員未登録でもすぐに請求書を作成できます',
                            zh: '即使尚未添加会员，也可直接开具账单',
                            vi: 'Chưa có hội viên vẫn có thể tạo hóa đơn ngay',
                            es: '¿Sin miembros aún? Crea un cobro al instante',
                          ),
                          softWrap: true,
                          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    LocalizationService.pick(
                      ko: '수신인 성함과 연락처를 직접 입력하시면 청구서 등록과 동시에 회원 명부에도 자동으로 등록할 수 있습니다.',
                      en: 'Enter a recipient name and phone number below — you can auto-save them to your directory too.',
                      ja: '宛名と連絡先を直接入力すれば、請求書と同時に会員名簿にも自動登録できます。',
                      zh: '直接输入收款人姓名和手机号，开单的同时可自动加入会员名录。',
                      vi: 'Nhập tên và số điện thoại bên dưới — hệ thống có thể tự lưu vào danh sách hội viên.',
                      es: 'Ingresa nombre y teléfono abajo; también puedes guardarlo en tu lista.',
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF3B82F6), height: 1.4),
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
                            SnackBar(
                              content: Text(LocalizationService.pick(
                                ko: '체험용 샘플 회원 5명이 등록되었습니다. 다시 청구서를 작성해보세요!',
                                en: 'Loaded 5 sample members. Try creating an invoice now!',
                                ja: '体験用サンプル会員5名を登録しました。もう一度お試しください！',
                                zh: '已载入 5 位演示示例会员，请重新创建账单！',
                                vi: 'Đã tải 5 hội viên mẫu. Hãy tạo hóa đơn lại!',
                                es: '5 miembros de prueba cargados. ¡Crea un cobro ahora!',
                              )),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                      icon: const Icon(Icons.auto_awesome_rounded, size: 15, color: AppTheme.primaryBlue),
                      label: Text(
                        LocalizationService.pick(
                          ko: '체험용 샘플 회원 5명 불러오기',
                          en: 'Load 5 Sample Members',
                          ja: '体験用サンプル会員を5名追加',
                          zh: '加载 5 位演示会员',
                          vi: 'Tải 5 hội viên mẫu',
                          es: 'Cargar 5 Miembros de Prueba',
                        ),
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                      ),
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
            LocalizationService.pick(
              ko: '${widget.studio.memberTitle} 선택 및 대상자 지정',
              en: 'Select ${widget.studio.memberTitle} or Recipient',
              ja: '${widget.studio.memberTitle}を選択・宛先指定',
              zh: '选择${widget.studio.memberTitle}或收款人',
              vi: 'Chọn ${widget.studio.memberTitle} / Người nhận',
              es: 'Seleccionar ${widget.studio.memberTitle} o destinatario',
            ),
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
                      label: Text(LocalizationService.pick(
                        ko: '직접 입력',
                        en: 'Manual Entry',
                        ja: '直接入力',
                        zh: '手动输入',
                        vi: 'Nhập thủ công',
                        es: 'Entrada manual',
                      )),
                      selected: _isDirectInputMode,
                      onSelected: (val) {
                        setState(() {
                          _isDirectInputMode = true;
                          _selectedMemberIds.clear();
                          if (_directNameController.text.trim().isNotEmpty) {
                            _titleController.text = LocalizationService.pick(
                              ko: '${_directNameController.text.trim()} ${now.month}월 $feeWord 안내',
                              en: '${_directNameController.text.trim()} - ${DateFormat.MMM().format(now)} $feeWord',
                              ja: '${_directNameController.text.trim()} ${now.month}月 $feeWord',
                              zh: '${_directNameController.text.trim()} ${now.month}月 $feeWord',
                              vi: '${_directNameController.text.trim()} - $feeWord T${now.month}',
                              es: '${_directNameController.text.trim()} - $feeWord ${DateFormat.MMM().format(now)}',
                            );
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
                          LocalizationService.pick(
                            ko: '동일 연락처 형제: ${unselectedSiblings.map((s) => s.primaryName).join(", ")}',
                            en: 'Family on same phone: ${unselectedSiblings.map((s) => s.primaryName).join(", ")}',
                            ja: '同じ連絡先のご家族: ${unselectedSiblings.map((s) => s.primaryName).join(", ")}',
                            zh: '同手机号家庭成员: ${unselectedSiblings.map((s) => s.primaryName).join(", ")}',
                            vi: 'Cùng số điện thoại: ${unselectedSiblings.map((s) => s.primaryName).join(", ")}',
                            es: 'Mismo teléfono familiar: ${unselectedSiblings.map((s) => s.primaryName).join(", ")}',
                          ),
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
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add_rounded, size: 13, color: AppTheme.primaryBlue),
                              const SizedBox(width: 2),
                              Text(
                                LocalizationService.pick(
                                  ko: '함께 묶기',
                                  en: 'Bundle',
                                  ja: 'まとめる',
                                  zh: '合并账单',
                                  vi: 'Gộp chung',
                                  es: 'Agrupar',
                                ),
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                              ),
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

          // Sibling Bundle & Discount Card
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
                      Flexible(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.family_restroom_rounded, color: Color(0xFF16A34A), size: 18),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                LocalizationService.pick(
                                  ko: '형제·가족 ${_selectedMemberIds.length}명 묶음 합산 청구 모드',
                                  en: 'Family Bundle (${_selectedMemberIds.length} members)',
                                  ja: '家族 ${_selectedMemberIds.length}名 まとめ請求',
                                  zh: '家庭 ${_selectedMemberIds.length}人 合并计费模式',
                                  vi: 'Gói gia đình (${_selectedMemberIds.length} người)',
                                  es: 'Pack Familiar (${_selectedMemberIds.length} miembros)',
                                ),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF15803D)),
                              ),
                            ),
                          ],
                        ),
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
                        child: Text(
                          LocalizationService.pick(
                            ko: '단독 청구로 전환',
                            en: 'Single Only',
                            ja: '個別請求に戻す',
                            zh: '改为单人账单',
                            vi: 'Tách riêng',
                            es: 'Individual',
                          ),
                          style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      LocalizationService.pick(
                        ko: '형제/다자녀 10% 자동 할인 적용',
                        en: 'Apply Family / Sibling Discount',
                        ja: '家族・兄弟割引を自動適用',
                        zh: '应用多子女 / 家庭自动折扣',
                        vi: 'Áp dụng giảm giá gia đình',
                        es: 'Aplicar descuento familiar',
                      ),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      _siblingFixedDiscount > 0
                          ? LocalizationService.pick(
                              ko: '${LocalizationService.formatAmount(_siblingFixedDiscount)} 고정 감면',
                              en: '${LocalizationService.formatAmount(_siblingFixedDiscount)} flat discount',
                              ja: '${LocalizationService.formatAmount(_siblingFixedDiscount)} 定額割引',
                              zh: '立减 ${LocalizationService.formatAmount(_siblingFixedDiscount)}',
                              vi: 'Giảm cố định ${LocalizationService.formatAmount(_siblingFixedDiscount)}',
                              es: 'Descuento fijo de ${LocalizationService.formatAmount(_siblingFixedDiscount)}',
                            )
                          : LocalizationService.pick(
                              ko: '수강료 ${(_siblingDiscountRate * 100).toInt()}% 원터치 감면 계산',
                              en: '${(_siblingDiscountRate * 100).toInt()}% off bundle total',
                              ja: '${(_siblingDiscountRate * 100).toInt()}% ワンタッチ割引',
                              zh: '立享 ${(_siblingDiscountRate * 100).toInt()}% 折扣优惠',
                              vi: 'Giảm ${(_siblingDiscountRate * 100).toInt()}% tổng hóa đơn',
                              es: '${(_siblingDiscountRate * 100).toInt()}% de descuento aplicado',
                            ),
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
                        _buildDiscountChip(
                          LocalizationService.pick(ko: '10% 할인 (기본)', en: '10% Off', ja: '10%割引', zh: '9折 (10%减免)', vi: 'Giảm 10%', es: '-10% (Base)'),
                          0.10,
                          0,
                        ),
                        _buildDiscountChip(
                          LocalizationService.pick(ko: '5% 할인', en: '5% Off', ja: '5%割引', zh: '95折 (-5%)', vi: 'Giảm 5%', es: '-5%'),
                          0.05,
                          0,
                        ),
                        _buildDiscountChip(
                          LocalizationService.pick(ko: '15% 할인', en: '15% Off', ja: '15%割引', zh: '85折 (-15%)', vi: 'Giảm 15%', es: '-15%'),
                          0.15,
                          0,
                        ),
                        _buildDiscountChip(
                          LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                              ? '-2만원 할인'
                              : '-${LocalizationService.formatAmount(LocalizationService.fixedDiscountPreset)}',
                          0,
                          LocalizationService.fixedDiscountPreset,
                        ),
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
                          Text('${LocalizationService.pick(ko: '정상 합계', en: 'Subtotal', ja: '合計', zh: '原价合计', vi: 'Tổng', es: 'Subtotal')}: ${LocalizationService.formatAmount(_originalSiblingTotal)}', style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B))),
                          Text('${LocalizationService.pick(ko: '할인', en: 'Disc.', ja: '割引', zh: '优惠', vi: 'Giảm', es: 'Desc.')}: -${LocalizationService.formatAmount(_calculatedSiblingDiscount)}', style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFFE11D48))),
                          Text('${LocalizationService.pick(ko: '최종 청구', en: 'Total', ja: '請求額', zh: '实收', vi: 'Tổng thu', es: 'Total')}: ${LocalizationService.formatAmount(_originalSiblingTotal - _calculatedSiblingDiscount)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
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
              label: LocalizationService.pick(
                ko: '${widget.studio.memberTitle} 성함 / 수신인 성함',
                en: '${widget.studio.memberTitle} / Recipient Name',
                ja: '${widget.studio.memberTitle}名・宛名',
                zh: '${widget.studio.memberTitle}姓名 / 收件人姓名',
                vi: 'Tên ${widget.studio.memberTitle} / Người nhận',
                es: 'Nombre del ${widget.studio.memberTitle} / destinatario',
              ),
              hint: LocalizationService.pick(
                ko: '예: 김철수',
                en: 'e.g., Alex Kim',
                ja: '例: 佐藤 健太',
                zh: '例: 张伟',
                vi: 'VD: Nguyễn Minh',
                es: 'Ej: Carlos López',
              ),
              prefixIcon: Icons.person_outline,
              onChanged: (val) {
                final name = val.trim();
                if (name.isNotEmpty) {
                  _titleController.text = LocalizationService.pick(
                    ko: '$name ${now.month}월 $feeWord 안내',
                    en: '$name - ${DateFormat.MMM().format(now)} $feeWord',
                    ja: '$name ${now.month}月 $feeWord',
                    zh: '$name ${now.month}月 $feeWord',
                    vi: '$name - $feeWord T${now.month}',
                    es: '$name - $feeWord ${DateFormat.MMM().format(now)}',
                  );
                }
              },
            ),
            const SizedBox(height: 6),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _autoRegisterMember,
              onChanged: (val) => setState(() => _autoRegisterMember = val ?? true),
              title: Text(
                LocalizationService.pick(
                  ko: '${widget.studio.memberTitle} 명부에도 신규 회원으로 자동 등록하기',
                  en: 'Auto-save to ${widget.studio.memberTitle} directory',
                  ja: '${widget.studio.memberTitle}名簿にも新規登録する',
                  zh: '同时自动保存至${widget.studio.memberTitle}名录',
                  vi: 'Tự động lưu vào danh sách ${widget.studio.memberTitle}',
                  es: 'Guardar automáticamente en la lista de ${widget.studio.memberTitle}',
                ),
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
              Expanded(
                child: Text(
                  LocalizationService.pick(
                    ko: '업종별 청구 템플릿 (원터치 자동 완성)',
                    en: 'One-Tap Fee Templates',
                    ja: '業種別請求テンプレート（ワンタップ入力）',
                    zh: '行业账单模板（一键填充）',
                    vi: 'Mẫu hóa đơn gợi ý (Điền 1 chạm)',
                    es: 'Plantillas de Cobro Rápido',
                  ),
                  softWrap: true,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => _showQuickAddInvoiceTemplateDialog(context),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.add_circle_outline, size: 14, color: Color(0xFF8B5CF6)),
                      const SizedBox(width: 3),
                      Text(
                        LocalizationService.pick(
                          ko: '새 서식 추가',
                          en: 'Add Template',
                          ja: '書式追加',
                          zh: '添加模板',
                          vi: 'Thêm mẫu',
                          es: 'Nueva Plantilla',
                        ),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF8B5CF6)),
                      ),
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
                      label: Text('${template.title} (${LocalizationService.formatAmount(template.defaultAmount)})'),
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
            label: LocalizationService.pick(
              ko: '청구 제목',
              en: 'Invoice Title',
              ja: '請求タイトル',
              zh: '账单标题',
              vi: 'Tiêu đề hóa đơn',
              es: 'Título del cobro',
            ),
            hint: LocalizationService.pick(
              ko: '예: ${now.month}월 정기 $feeWord 안내',
              en: 'e.g., ${DateFormat.MMM().format(now)} Monthly $feeWord',
              ja: '例: ${now.month}月分 $feeWord のご案内',
              zh: '例: ${now.month}月常规 $feeWord 通知',
              vi: 'VD: $feeWord tháng ${now.month}',
              es: 'Ej: $feeWord de ${DateFormat.MMM().format(now)}',
            ),
            prefixIcon: Icons.description_outlined,
          ),
          const SizedBox(height: 14),

          // Amount & Preset Buttons
          AppTextField(
            controller: _amountController,
            label: '${LocalizationService.pick(ko: '청구 금액', en: 'Amount', ja: '請求金額', zh: '账单金额', vi: 'Số tiền', es: 'Importe')} (${LocalizationService.currentCurrency.symbol})',
            hint: (LocalizationService.quickIncrementAmounts().elementAtOrNull(2) ?? 100000).toString(),
            prefixIcon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
            suffix: Padding(
              padding: const EdgeInsets.only(right: 16, top: 14),
              child: Text(LocalizationService.currentCurrency.symbol, style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: LocalizationService.quickIncrementAmounts()
                .map((amt) => _buildPresetButton('+${LocalizationService.formatAmount(amt)}', amt))
                .toList(),
          ),
          const SizedBox(height: 14),

          // Due Date Selection
          Text(
            LocalizationService.pick(
              ko: '납부 기한 설정',
              en: 'Due Date',
              ja: 'お支払い期限',
              zh: '付款截止日期',
              vi: 'Hạn thanh toán',
              es: 'Fecha de vencimiento',
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: Text(LocalizationService.pick(
                  ko: '일주일 후 (+7일)',
                  en: '+7 Days',
                  ja: '1週間後 (+7日)',
                  zh: '7天后 (+7天)',
                  vi: '7 ngày tới',
                  es: 'En 7 días',
                )),
                selected: _dueDate.difference(DateTime.now()).inDays <= 7 && _dueDate.difference(DateTime.now()).inDays >= 6,
                onSelected: (val) {
                  if (val) setState(() => _dueDate = DateTime.now().add(const Duration(days: 7)));
                },
              ),
              ChoiceChip(
                label: Text(LocalizationService.pick(
                  ko: '${now.month}월 말일까지',
                  en: 'End of ${DateFormat.MMM().format(now)}',
                  ja: '${now.month}月末まで',
                  zh: '本月底前',
                  vi: 'Cuối tháng ${now.month}',
                  es: 'Fin de mes',
                )),
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
            label: LocalizationService.pick(
              ko: '수신인 연락처 (보호자 / 회원)',
              en: 'Recipient Phone (Parent / Member)',
              ja: '宛先電話番号（保護者・会員）',
              zh: '接收手机号（家长 / 会员）',
              vi: 'SĐT người nhận (Phụ huynh / Hội viên)',
              es: 'Teléfono destinatario (Padre / Miembro)',
            ),
            hint: LocalizationService.currentCurrency.phoneHint,
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 12),

          // Option to launch SMS editor directly
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _sendSmsRightNow,
            onChanged: (val) => setState(() => _sendSmsRightNow = val ?? true),
            title: Text(
              LocalizationService.pick(
                ko: '등록 완료 후 바로 청구문자 발송창 띄우기',
                en: 'Open SMS / Messenger send dialog right after saving',
                ja: '登録完了後すぐに請求メッセージ送信画面を開く',
                zh: '创建后立即打开催款通知发送窗口',
                vi: 'Mở cửa sổ gửi tin nhắn ngay sau khi lưu',
                es: 'Abrir envío de aviso justo al guardar',
              ),
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
        ],
      ),
      footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      footer: Consumer(
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
                    SnackBar(
                      content: Text(LocalizationService.pick(
                        ko: '청구 금액을 0원보다 크게 입력해주세요.',
                        en: 'Please enter an amount greater than 0.',
                        ja: '請求金額は0より大きく入力してください。',
                        zh: '请输入大于 0 的账单金额。',
                        vi: 'Vui lòng nhập số tiền lớn hơn 0.',
                        es: 'Ingresa un importe mayor a 0.',
                      )),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                if (phone.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.pick(
                        ko: '수신인 연락처를 입력해주세요.',
                        en: 'Please enter a recipient phone number.',
                        ja: '受信先電話番号を入力してください。',
                        zh: '请输入接收手机号。',
                        vi: 'Vui lòng nhập số điện thoại người nhận.',
                        es: 'Ingresa el teléfono del destinatario.',
                      )),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                if (_isDirectInputMode) {
                  final directName = _directNameController.text.trim();
                  if (directName.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.pick(
                          ko: '청구 대상자의 이름을 입력해주세요.',
                          en: 'Please enter the recipient name.',
                          ja: '請求対象者のお名前を入力してください。',
                          zh: '请输入收款对象姓名。',
                          vi: 'Vui lòng nhập tên người nhận.',
                          es: 'Ingresa el nombre del destinatario.',
                        )),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final bm = MonetizationService.instance;
                  final curInvCount = ref.read(invoicesProvider).value?.length ?? 0;
                  final invNoun = LocalizationService.pick(ko: '청구서', en: 'Invoice', ja: '請求書', zh: '账单', vi: 'Hóa đơn', es: 'Cobro');
                  if (!await bm.ensureCreateAllowed(
                    context,
                    itemLabel: invNoun,
                    currentCount: curInvCount,
                    limit: bm.maxInvoiceLimit,
                  )) {
                    return;
                  }

                  if (!context.mounted) return;
                  String memberId = 'mem_${const Uuid().v4().substring(0, 8)}';
                  Member? newMember;
                  if (_autoRegisterMember) {
                    final curMemCount = ref.read(membersProvider).value?.length ?? 0;
                    if (!await bm.ensureCreateAllowed(
                      context,
                      itemLabel: widget.studio.memberTitle,
                      currentCount: curMemCount,
                      limit: bm.maxMemberLimit,
                    )) {
                      return;
                    }
                    if (!context.mounted) return;
                    newMember = Member(
                      id: memberId,
                      name: directName,
                      phone: phone,
                      groupName: LocalizationService.localizeBuiltInLabel('일반'),
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
                    title: title.isEmpty
                        ? LocalizationService.pick(
                            ko: '$directName ${now.month}월 $feeWord 안내',
                            en: '$directName - ${DateFormat.MMM().format(now)} $feeWord',
                            ja: '$directName ${now.month}月 $feeWord',
                            zh: '$directName ${now.month}月 $feeWord',
                            vi: '$directName - $feeWord T${now.month}',
                            es: '$directName - $feeWord ${DateFormat.MMM().format(now)}',
                          )
                        : title,
                    amount: amount,
                    dueDate: _dueDate,
                    status: PaymentStatus.unpaid,
                  );

                  await ref.read(invoicesProvider.notifier).addInvoice(newInvoice);
                  if (!context.mounted) return;
                  Navigator.pop(context);

                  if (!_sendSmsRightNow) {
                    MonetizationService.instance.triggerSmartInterstitialAd(
                      cooldownSeconds: 75,
                      actionThreshold: 2,
                    );
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.pick(
                        ko: '${newInvoice.title} (${LocalizationService.formatAmount(amount)}) 청구서가 등록되었습니다.',
                        en: 'Created invoice: ${newInvoice.title} (${LocalizationService.formatAmount(amount)})',
                        ja: '${newInvoice.title} (${LocalizationService.formatAmount(amount)}) を登録しました。',
                        zh: '已创建账单: ${newInvoice.title} (${LocalizationService.formatAmount(amount)})',
                        vi: 'Đã tạo hóa đơn: ${newInvoice.title} (${LocalizationService.formatAmount(amount)})',
                        es: 'Cobro creado: ${newInvoice.title} (${LocalizationService.formatAmount(amount)})',
                      )),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );

                  if (_sendSmsRightNow) {
                    widget.onSendSms(newInvoice, newMember != null ? [newMember] : []);
                  }
                } else {
                  if (_selectedMemberIds.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.pick(
                          ko: '청구 대상 회원을 선택해주세요.',
                          en: 'Please select a recipient member.',
                          ja: '請求対象の会員を選択してください。',
                          zh: '请选择需要收费的会员。',
                          vi: 'Vui lòng chọn hội viên cần thu.',
                          es: 'Selecciona un miembro destinatario.',
                        )),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  final bm = MonetizationService.instance;
                  final curInvCount = ref.read(invoicesProvider).value?.length ?? 0;
                  final invNoun = LocalizationService.pick(ko: '청구서', en: 'Invoice', ja: '請求書', zh: '账单', vi: 'Hóa đơn', es: 'Cobro');
                  if (!await bm.ensureCreateAllowed(
                    context,
                    itemLabel: invNoun,
                    currentCount: curInvCount,
                    limit: bm.maxInvoiceLimit,
                  )) {
                    return;
                  }

                  final newInvoice = Invoice(
                    id: 'inv_${const Uuid().v4().substring(0, 8)}',
                    memberIds: _selectedMemberIds.toList(),
                    recipientPhone: phone,
                    title: title.isEmpty
                        ? LocalizationService.pick(
                            ko: '${now.month}월 $feeWord 안내',
                            en: '${DateFormat.MMM().format(now)} $feeWord Notice',
                            ja: '${now.month}月 $feeWord のご案内',
                            zh: '${now.month}月 $feeWord 通知',
                            vi: '$feeWord Tháng ${now.month}',
                            es: '$feeWord ${DateFormat.MMM().format(now)}',
                          )
                        : title,
                    amount: amount,
                    dueDate: _dueDate,
                    status: PaymentStatus.unpaid,
                  );

                  await ref.read(invoicesProvider.notifier).addInvoice(newInvoice);
                  if (!context.mounted) return;
                  Navigator.pop(context);

                  if (!_sendSmsRightNow) {
                    MonetizationService.instance.triggerSmartInterstitialAd(
                      cooldownSeconds: 75,
                      actionThreshold: 2,
                    );
                  }

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(LocalizationService.pick(
                        ko: '${newInvoice.title} (${LocalizationService.formatAmount(amount)}) 청구서가 등록되었습니다.',
                        en: 'Created invoice: ${newInvoice.title} (${LocalizationService.formatAmount(amount)})',
                        ja: '${newInvoice.title} (${LocalizationService.formatAmount(amount)}) を登録しました。',
                        zh: '已创建账单: ${newInvoice.title} (${LocalizationService.formatAmount(amount)})',
                        vi: 'Đã tạo hóa đơn: ${newInvoice.title} (${LocalizationService.formatAmount(amount)})',
                        es: 'Cobro creado: ${newInvoice.title} (${LocalizationService.formatAmount(amount)})',
                      )),
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
                _sendSmsRightNow
                    ? LocalizationService.pick(
                        ko: '청구서 등록 및 즉시 문자 발송',
                        en: 'Save & Send Invoice Now',
                        ja: '登録してすぐ請求送信',
                        zh: '创建并立即发送账单',
                        vi: 'Lưu & gửi thông báo ngay',
                        es: 'Guardar y Enviar Aviso',
                      )
                    : LocalizationService.pick(
                        ko: '청구서 장부 등록 완료',
                        en: 'Save Invoice to Ledger',
                        ja: '台帳に請求書を登録',
                        zh: '完成创建账单',
                        vi: 'Lưu hóa đơn vào sổ',
                        es: 'Guardar Cobro en Libro',
                      ),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          );
        },
      ),
    );
  }

  void _showQuickAddInvoiceTemplateDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: (LocalizationService.quickIncrementAmounts().elementAtOrNull(2) ?? 100000).toString());
    final tagCtrl = TextEditingController(
      text: LocalizationService.pick(ko: '정기수납', en: 'Recurring', ja: '定期', zh: '常规收费', vi: 'Định kỳ', es: 'Periódico'),
    );

    showDialog(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          LocalizationService.pick(
            ko: '새 청구 서식 추가',
            en: 'New Invoice Template',
            ja: '新しい請求書式を追加',
            zh: '新建账单模板',
            vi: 'Thêm mẫu hóa đơn mới',
            es: 'Nueva Plantilla de Cobro',
          ),
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppTextField(
                controller: titleCtrl,
                label: LocalizationService.pick(ko: '청구 항목명', en: 'Template Title', ja: '請求項目名', zh: '账单名称', vi: 'Tên mục thu', es: 'Nombre del concepto'),
                hint: LocalizationService.pick(
                  ko: '예: 교재비 / 워크북, PT 10회 재등록',
                  en: 'e.g., Workbook Fee, 10-Session Renewal',
                  ja: '例: 教材費、回数券10回更新',
                  zh: '例: 教材费、10次私教课续费',
                  vi: 'VD: Tài liệu, Gói gia hạn 10 buổi',
                  es: 'Ej: Materiales, Bono 10 sesiones',
                ),
                prefixIcon: Icons.receipt_outlined,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: amountCtrl,
                label: '${LocalizationService.pick(ko: '기본 청구 금액', en: 'Default Amount', ja: '基本請求金額', zh: '默认金额', vi: 'Số tiền mặc định', es: 'Importe base')} (${LocalizationService.currentCurrency.symbol})',
                hint: '100',
                prefixIcon: Icons.payments_outlined,
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: tagCtrl,
                label: LocalizationService.pick(ko: '분류 태그 (선택)', en: 'Category Tag (Optional)', ja: 'タグ（任意）', zh: '分类标签（可选）', vi: 'Thẻ phân loại (Tùy chọn)', es: 'Etiqueta (Opcional)'),
                hint: LocalizationService.pick(ko: '예: 정기수납, 교재/재료, 레슨비', en: 'e.g., Monthly, Materials, Lessons', ja: '例: 月謝, 教材, レッスン', zh: '例: 月费, 教材, 课时费', vi: 'VD: Hàng tháng, Tài liệu', es: 'Ej: Mensual, Material, Clases'),
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
                  label: LocalizationService.pick(
                    ko: '추가 및 적용',
                    en: 'Add & Apply',
                    ja: '追加して適用',
                    zh: '添加并应用',
                    vi: 'Thêm & Áp dụng',
                    es: 'Añadir y Aplicar',
                  ),
                  size: ZeroButtonSize.medium,
                  fullWidth: true,
                  onPressed: () async {
              final title = titleCtrl.text.trim();
              final amount = int.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
              final tag = tagCtrl.text.trim();

              if (title.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LocalizationService.pick(
                  ko: '청구 항목명을 입력해주세요.',
                  en: 'Please enter a template title.',
                  ja: '請求項目名を入力してください。',
                  zh: '请输入账单项目名称。',
                  vi: 'Vui lòng nhập tên mục thu.',
                  es: 'Ingresa el concepto del cobro.',
                ))));
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
      period: LocalizationService.pick(
        ko: '${widget.expense.date.month}월',
        en: DateFormat.MMM().format(widget.expense.date),
        ja: '${widget.expense.date.month}月',
        zh: '${widget.expense.date.month}月',
        vi: 'Tháng ${widget.expense.date.month}',
        es: DateFormat.MMM().format(widget.expense.date),
      ),
      details: '${widget.expense.title} (${LocalizationService.localizeBuiltInLabel(widget.expense.paymentMethod)})',
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
    final incomeTax = (widget.expense.amount * 0.03).round();
    final localTax = (widget.expense.amount * 0.003).round();

    return StickyBottomSheetLayout(
      header: Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
        child: Row(
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
                        LocalizationService.pick(
                          ko: '${widget.expense.vendorName} 강사료 정산서',
                          en: '${widget.expense.vendorName} Payout Statement',
                          ja: '${widget.expense.vendorName} 講師報酬明細',
                          zh: '${widget.expense.vendorName} 讲师薪酬结算单',
                          vi: 'Bảng lương GV ${widget.expense.vendorName}',
                          es: 'Liquidación de ${widget.expense.vendorName}',
                        ),
                        softWrap: true,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                              ? '3.3% 원천징수'
                              : LocalizationService.withholdingDescription,
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    LocalizationService.pick(
                      ko: '${widget.expense.date.month}월 정산 • ${widget.expense.title}',
                      en: '${DateFormat.MMM().format(widget.expense.date)} Payout • ${widget.expense.title}',
                      ja: '${widget.expense.date.month}月精算 • ${widget.expense.title}',
                      zh: '${widget.expense.date.month}月结算 • ${widget.expense.title}',
                      vi: 'Kỳ T${widget.expense.date.month} • ${widget.expense.title}',
                      es: '${DateFormat.MMM().format(widget.expense.date)} • ${widget.expense.title}',
                    ),
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
      ),
      bodyPadding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                _buildSummaryRow(
                  LocalizationService.pick(
                    ko: '총 지급액 (공제 전 총액)',
                    en: 'Gross Payout',
                    ja: '総支給額（税引前）',
                    zh: '应发总额（税前）',
                    vi: 'Tổng thu nhập (trước thuế)',
                    es: 'Importe Bruto',
                  ),
                  LocalizationService.formatAmount(widget.expense.amount),
                  isBold: true,
                ),
                const Divider(height: 14, color: Color(0xFFE2E8F0)),
                if (LocalizationService.supportsTossTransfer) ...[
                  _buildSummaryRow(
                    LocalizationService.pick(ko: '사업소득세 (국세 3.0%)', en: 'National Income Tax (3.0%)', ja: '所得税 (3.0%)', zh: '个人所得税 (3.0%)', vi: 'Thuế TNCN TW (3.0%)', es: 'Impuesto Renta (3.0%)'),
                    '-${LocalizationService.formatAmount(incomeTax)}',
                    textColor: const Color(0xFFE11D48),
                  ),
                  const SizedBox(height: 4),
                  _buildSummaryRow(
                    LocalizationService.pick(ko: '지방소득세 (지방세 0.3%)', en: 'Local Surtax (0.3%)', ja: '地方住民税 (0.3%)', zh: '地方附加税 (0.3%)', vi: 'Thuế địa phương (0.3%)', es: 'Impuesto Local (0.3%)'),
                    '-${LocalizationService.formatAmount(localTax)}',
                    textColor: const Color(0xFFE11D48),
                  ),
                  const SizedBox(height: 4),
                ],
                _buildSummaryRow(
                  LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                      ? '원천징수 합계 (3.3%)'
                      : LocalizationService.withholdingDescription,
                  '-${LocalizationService.formatAmount(widget.expense.withholdingTax)}',
                  textColor: const Color(0xFFE11D48),
                  isBold: true,
                ),
                const Divider(height: 14, color: Color(0xFFE2E8F0)),
                _buildSummaryRow(
                  LocalizationService.pick(
                    ko: '차인 지급액 (실수령 입금액)',
                    en: 'Net Transfer Amount',
                    ja: '差引手取り振込額',
                    zh: '实发净额 (实付转账)',
                    vi: 'Thực nhận sau khấu trừ',
                    es: 'Neto a Transferir',
                  ),
                  LocalizationService.formatAmount(widget.expense.actualPayoutAmount),
                  textColor: const Color(0xFF4F46E5),
                  isBold: true,
                  fontSize: 15,
                ),
                if (widget.vendor?.bankName != null && widget.vendor?.accountNumber != null) ...[
                  const SizedBox(height: 6),
                  _buildSummaryRow(
                    LocalizationService.pick(ko: '입금 계좌', en: 'Bank Account', ja: '振込口座', zh: '收款账户', vi: 'Tài khoản nhận', es: 'Cuenta Bancaria'),
                    '${widget.vendor!.bankName} ${widget.vendor!.accountNumber}',
                    textColor: AppTheme.textSecondary,
                    fontSize: 11.5,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Editable message field
          Text(
            LocalizationService.pick(
              ko: '정산 명세서 메시지 본문 미리보기 (수정 가능)',
              en: 'Payout Statement Message Preview (Editable)',
              ja: '報酬明細メッセージ（編集可能）',
              zh: '薪酬结算明细消息预览（可编辑）',
              vi: 'Xem trước bảng kê lương (Có thể sửa)',
              es: 'Vista previa de liquidación (Editable)',
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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
        ],
      ),
      footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      footer: Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: WrapAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _messageController.text));
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(LocalizationService.pick(
                    ko: '정산서가 클립보드에 복사되었습니다.',
                    en: 'Payout statement copied to clipboard.',
                    ja: '明細書をクリップボードにコピーしました。',
                    zh: '结算单已复制到剪贴板。',
                    vi: 'Đã sao chép bảng kê vào khay nhớ tạm.',
                    es: 'Liquidación copiada al portapapeles.',
                  )),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
            label: Text(
              LocalizationService.pick(ko: '내용 복사', en: 'Copy', ja: 'コピー', zh: '复制', vi: 'Sao chép', es: 'Copiar'),
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
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
              label: Text(
                LocalizationService.pick(ko: '문자(SMS) 전송', en: 'Send SMS', ja: 'SMS送信', zh: '发送短信', vi: 'Gửi SMS', es: 'Enviar SMS'),
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
              ),
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
                subject: LocalizationService.pick(
                  ko: '[${widget.studio.studioName}] 강사료 정산서',
                  en: '[${widget.studio.studioName}] Payout Statement',
                  ja: '[${widget.studio.studioName}] 報酬明細書',
                  zh: '[${widget.studio.studioName}] 薪酬结算单',
                  vi: '[${widget.studio.studioName}] Bảng kê lương',
                  es: '[${widget.studio.studioName}] Liquidación',
                ),
              );
            },
            icon: const Icon(Icons.chat_bubble_rounded, size: 15, color: Color(0xFF1E1E1E)),
            label: Text(
              LocalizationService.pick(
                ko: '카톡 정산서 전송',
                en: 'Share Statement',
                ja: '明細を送信',
                zh: '分享结算单',
                vi: 'Chia sẻ bảng kê',
                es: 'Compartir',
              ),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF1E1E1E)),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFEE500),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
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

