import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/bank_notification_filter.dart';
import '../services/coach_mark_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coach_mark_dialog.dart';

class BillingLedgerScreen extends ConsumerStatefulWidget {
  const BillingLedgerScreen({super.key});

  @override
  ConsumerState<BillingLedgerScreen> createState() => _BillingLedgerScreenState();
}

class _BillingLedgerScreenState extends ConsumerState<BillingLedgerScreen> {
  int _selectedTab = 0; // 0: 미납 / 청구 대상, 1: 수납 완료 내역
  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CoachMarkDialog.showIfFirstTime(
        context: context,
        coachKey: CoachMarkService.keyBillingTab,
        title: '수강료 청구 & 수납 장부 💰',
        message: '매월 나가는 수강료 청구 문자를 0원으로 보내고 입금 내역을 관리할 수 있는 장부예요.\n\n우측 하단 [+]를 누르면 동일 연락처의 형제자매까지 자동 합산하여 청구서를 작성할 수 있어요!',
        tip: '수납이 확인되면 [수납 완료] 버튼을 눌러 계좌이체/카드/현금 결제 수단별로 깔끔하게 장부에 기록하세요.',
        buttonText: '장부 둘러보기 ✨',
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final invoicesAsync = ref.watch(invoicesProvider);
    final membersAsync = ref.watch(membersProvider);
    final studioAsync = ref.watch(studioProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('청구 · 수납 관리'),
        actions: [
          // 스마트 입금 푸시 알림 수동 테스트 & 감지 시뮬레이터 (출결선생/토스 스타일)
          IconButton(
            icon: const Icon(Icons.notifications_active_outlined),
            tooltip: '은행 입금 알림 매칭 시뮬레이터',
            onPressed: () {
              final members = membersAsync.value ?? [];
              final unpaid = (invoicesAsync.value ?? []).where((i) => i.status == PaymentStatus.unpaid).toList();
              _showBankNotificationSimulator(context, members, unpaid);
            },
          ),
          IconButton(
            icon: const Icon(Icons.add_card_outlined),
            tooltip: '간편 청구서 작성',
            onPressed: () {
              final members = membersAsync.value ?? [];
              final studio = studioAsync.value ?? StudioProfile.defaultProfile();
              if (members.isNotEmpty) {
                _openQuickInvoiceSheet(context, members, studio);
              }
            },
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

              // 회차 만료 임박 회원 (1회 이하)
              final expiringMembers = members
                  .where((m) => m.billingType == BillingType.sessionBased && m.remainingSessions <= 1)
                  .toList();

              final currentList = _selectedTab == 0 ? unpaidInvoices : paidInvoices;

              return Column(
                children: [
                  // 1. Amount Metric Overview Card
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _selectedTab == 0 ? '수납 대기 총액' : '이번 달 총 수납액',
                                style: const TextStyle(
                                  color: Color(0xFF94A3B8),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withAlpha((255 * 0.1).round()),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _selectedTab == 0 ? '${unpaidInvoices.length}건 미납' : '${paidInvoices.length}건 완료',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            '${_currencyFormat.format(_selectedTab == 0 ? totalUnpaidAmount : totalPaidAmount)}원',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2. Segmented Control
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppTheme.chipBackground,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(3),
                            child: Row(
                              children: [
                                _buildTabButton('미납 / 청구 대상 (${unpaidInvoices.length})', 0),
                                _buildTabButton('수납 완료 내역 (${paidInvoices.length})', 1),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Expiring Sessions Warning Strip (with one-tap warning SMS)
                  if (_selectedTab == 0 && expiringMembers.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.warning.withAlpha((255 * 0.12).round()),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppTheme.warning.withAlpha((255 * 0.3).round())),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded, size: 20, color: AppTheme.warning),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '회차 만료 임박 (${expiringMembers.length}명): ${expiringMembers.map((m) => m.name.split(' ').first).join(', ')}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _sendExpiryAlert(context, studio, expiringMembers.first);
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: AppTheme.warning),
                                ),
                                child: const Text(
                                  '만료 안내문자',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFB45309),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // 3. Invoice List
                  Expanded(
                    child: currentList.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.receipt_long_outlined, size: 48, color: AppTheme.textTertiary),
                                const SizedBox(height: 12),
                                Text(
                                  _selectedTab == 0 ? '미납된 청구서가 없습니다' : '수납 완료 내역이 없습니다',
                                  style: const TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
                            itemCount: currentList.length,
                            itemBuilder: (context, index) {
                              final invoice = currentList[index];
                              final invoiceMembers = invoice.memberIds
                                  .map((id) => memberMap[id])
                                  .whereType<Member>()
                                  .toList();

                              return _buildInvoiceCard(context, invoice, invoiceMembers, studio);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_billing',
        onPressed: () {
          final members = membersAsync.value ?? [];
          final studio = studioAsync.value ?? StudioProfile.defaultProfile();
          if (members.isNotEmpty) {
            _openQuickInvoiceSheet(context, members, studio);
          }
        },
        backgroundColor: AppTheme.primaryBlue,
        icon: const Icon(Icons.edit_note, color: Colors.white),
        label: const Text(
          '새 청구서 작성',
          style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, int tabIndex) {
    final isSelected = _selectedTab == tabIndex;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedTab = tabIndex),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: isSelected ? AppTheme.cardShadow : null,
          ),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceCard(
    BuildContext context,
    Invoice invoice,
    List<Member> invoiceMembers,
    StudioProfile studio,
  ) {
    final isPaid = invoice.status == PaymentStatus.paid;
    final memberNames = invoiceMembers.map((m) => m.name).join(', ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  invoice.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isPaid
                      ? AppTheme.softMint.withAlpha((255 * 0.15).round())
                      : AppTheme.warning.withAlpha((255 * 0.15).round()),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isPaid ? '수납 완료' : '미납',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isPaid ? AppTheme.softMint : const Color(0xFFD97706),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.person_outline, size: 15, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  '$memberNames (${invoice.recipientPhone})',
                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPaid ? '수납 완료일' : '납부 기한',
                    style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    isPaid && invoice.paidAt != null
                        ? DateFormat('yyyy.MM.dd').format(invoice.paidAt!)
                        : DateFormat('yyyy.MM.dd').format(invoice.dueDate),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              Text(
                '${_currencyFormat.format(invoice.amount)}원',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Action Buttons
          Row(
            children: [
              // 1. One-touch SMS native send
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendSmsInvoice(context, studio, invoiceMembers, invoice),
                  icon: const Icon(Icons.sms_outlined, size: 15),
                  label: const Text('청구문자'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 2. 1-Second Reminder SMS (Only for Unpaid)
              if (!isPaid) ...[
                Expanded(
                  child: OutlinedButton.icon(
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
                    icon: const Icon(Icons.notifications_active_outlined, size: 15, color: Color(0xFFD97706)),
                    label: const Text('1초리마인드', style: TextStyle(color: Color(0xFFD97706), fontSize: 12.5)),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFFDE68A)),
                      backgroundColor: const Color(0xFFFFFBEB),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
              ],

              // 3. One-tap Mark as Paid (with Receipt SMS option)
              if (!isPaid)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentConfirmDialog(context, invoice, invoiceMembers, studio),
                    icon: const Icon(Icons.check, size: 15, color: Colors.white),
                    label: const Text('수납확인'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.softMint,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                )
              else
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _sendReceiptSms(context, studio, invoiceMembers, invoice),
                    icon: const Icon(Icons.receipt_outlined, size: 16, color: AppTheme.softMint),
                    label: const Text('영수 확인 문자'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.softMint,
                      side: const BorderSide(color: AppTheme.softMint),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
            ],
          ),
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
                    '청구 문자 내용 확인 & 편집',
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
                '수신: ${invoice.recipientPhone} (전송 전 내용을 자유롭게 수정할 수 있습니다)',
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: textController,
                label: '문자 본문 내용',
                maxLines: 8,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
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
                      label: const Text('문자 앱으로 전송'),
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
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '수납 완료 처리',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                '${invoice.title} (${_currencyFormat.format(invoice.amount)}원)의 결제 수단을 선택하세요.',
                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.account_balance, color: AppTheme.primaryBlue),
                ),
                title: const Text('계좌 입금 확인'),
                subtitle: const Text('은행 통장으로 실시간 무통장 입금 완료'),
                onTap: () => _confirmPayment(ctx, invoice, 'TRANSFER', invoiceMembers, studio),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFECFDF5),
                  child: Icon(Icons.credit_card, color: AppTheme.softMint),
                ),
                title: const Text('오프라인 카드 단말기'),
                subtitle: const Text('매장/학원 현장 신용·체크카드 결제'),
                onTap: () => _confirmPayment(ctx, invoice, 'OFFLINE_CARD', invoiceMembers, studio),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFEF3C7),
                  child: Icon(Icons.qr_code_scanner, color: Color(0xFFD97706)),
                ),
                title: const Text('간편결제 (카카오페이 / 토스 / 제로페이 QR)'),
                subtitle: const Text('매장 비치 QR 코드 또는 송금 링크 결제'),
                onTap: () => _confirmPayment(ctx, invoice, 'EASY_PAY', invoiceMembers, studio),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFF3E8FF),
                  child: Icon(Icons.card_giftcard, color: Color(0xFF9333EA)),
                ),
                title: const Text('지역화폐 · 교육/스포츠 바우처'),
                subtitle: const Text('지역사랑상품권, 평생교육바우처, 스포츠강좌이용권'),
                onTap: () => _confirmPayment(ctx, invoice, 'VOUCHER', invoiceMembers, studio),
              ),
              ListTile(
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFFFFBEB),
                  child: Icon(Icons.payments_outlined, color: AppTheme.warning),
                ),
                title: const Text('현금 수납'),
                subtitle: const Text('현장 현금 수령 및 간이 영수'),
                onTap: () => _confirmPayment(ctx, invoice, 'CASH', invoiceMembers, studio),
              ),
            ],
          ),
        );
      },
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
            label: '영수 문자 발송',
            textColor: AppTheme.softMint,
            onPressed: () => _sendReceiptSms(context, studio, invoiceMembers, invoice),
          ),
          duration: const Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // 은행 앱 푸시 알림 수동 매칭 시뮬레이터 (테스트 & 시연용)
  void _showBankNotificationSimulator(
    BuildContext context,
    List<Member> members,
    List<Invoice> unpaidInvoices,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('은행 푸시 알림 장부 매칭'),
        content: Column(
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
                      subtitle: Text('${_currencyFormat.format(inv.amount)}원 입금 시뮬레이션 (입금자: $simSenderName)'),
                      trailing: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(ctx);
                          // Simulate banking app push with sender name (payerName or student name)
                          final event = BankNotificationFilter.parseDepositNotification(
                            packageName: 'viva.republica.toss',
                            title: '토스뱅크',
                            text: '입금 ${_currencyFormat.format(inv.amount)}원 $simSenderName',
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
                                  content: Text('은행 알림 감지 [${match.matchType}]: ${match.matchedMemberName ?? match.invoice.title} (${_currencyFormat.format(event.amount)}원) 자동 입금 처리 완료!'),
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
      ),
    );
  }
}

class _QuickInvoiceModal extends StatefulWidget {
  final List<Member> allMembers;
  final StudioProfile studio;

  const _QuickInvoiceModal({
    required this.allMembers,
    required this.studio,
  });

  @override
  State<_QuickInvoiceModal> createState() => _QuickInvoiceModalState();
}

class _QuickInvoiceModalState extends State<_QuickInvoiceModal> {
  final Set<String> _selectedMemberIds = {};
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final DateTime _dueDate = DateTime.now().add(const Duration(days: 7));
  final NumberFormat _currencyFormat = NumberFormat('#,###');

  @override
  void initState() {
    super.initState();
    if (widget.allMembers.isNotEmpty) {
      _selectMember(widget.allMembers.first);
    }
  }

  void _selectMember(Member m) {
    _selectedMemberIds.clear();
    _selectedMemberIds.add(m.id);

    final siblings = widget.allMembers.where((other) => other.phone == m.phone).toList();
    for (final sib in siblings) {
      _selectedMemberIds.add(sib.id);
    }

    final totalDefaultFee = widget.allMembers
        .where((item) => _selectedMemberIds.contains(item.id))
        .fold<int>(0, (sum, item) => sum + item.defaultFee);

    final title = siblings.length > 1
        ? '${m.registeredAt.month}월 수강료 (${siblings.map((s) => s.name.split(' ').first).join('/')} 형제 합산)'
        : '${m.name.split(' ').first} 수강료 안내';

    _titleController.text = title;
    _amountController.text = totalDefaultFee.toString();
    _phoneController.text = m.phone;
  }

  void _addAmount(int add) {
    final current = int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
    _amountController.text = (current + add).toString();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                '간편 청구서 작성',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Select Target Member
          const Text(
            '수강 회원 선택 (동일 연락처 형제자매 자동 묶음)',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: widget.allMembers.map((m) {
                final isSelected = _selectedMemberIds.contains(m.id);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(m.name),
                    selected: isSelected,
                    onSelected: (val) {
                      setState(() {
                        _selectMember(m);
                      });
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
              }).toList(),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          AppTextField(
            controller: _titleController,
            label: '청구 제목',
            hint: '예: 9월 정규 수강료 안내',
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
          Row(
            children: [
              _buildPresetButton('+1만', 10000),
              const SizedBox(width: 8),
              _buildPresetButton('+5만', 50000),
              const SizedBox(width: 8),
              _buildPresetButton('+10만', 100000),
            ],
          ),
          const SizedBox(height: 14),

          // Recipient Phone
          AppTextField(
            controller: _phoneController,
            label: '수신인 연락처 (학부모 / 회원)',
            hint: '예: 010-1234-5678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 20),

            Consumer(
              builder: (ctx, ref, _) {
                return SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final amount = int.tryParse(_amountController.text.replaceAll(',', '')) ?? 0;
                      if (amount <= 0 || _selectedMemberIds.isEmpty) return;

                      final newInvoice = Invoice(
                        id: 'inv_${const Uuid().v4().substring(0, 8)}',
                        memberIds: _selectedMemberIds.toList(),
                        recipientPhone: _phoneController.text.trim(),
                        title: _titleController.text.trim(),
                        amount: amount,
                        dueDate: _dueDate,
                        status: PaymentStatus.unpaid,
                      );

                      ref.read(invoicesProvider.notifier).addInvoice(newInvoice);
                      Navigator.pop(context);

                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('${newInvoice.title} (${_currencyFormat.format(amount)}원) 청구서가 등록되었습니다.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(
                      '청구서 등록 완료',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
    );
  }

  Widget _buildPresetButton(String label, int amount) {
    return Expanded(
      child: OutlinedButton(
        onPressed: () => setState(() => _addAmount(amount)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
      ),
    );
  }
}
