import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';

class BillingLedgerScreen extends ConsumerStatefulWidget {
  const BillingLedgerScreen({super.key});

  @override
  ConsumerState<BillingLedgerScreen> createState() => _BillingLedgerScreenState();
}

class _BillingLedgerScreenState extends ConsumerState<BillingLedgerScreen> {
  int _selectedTab = 0; // 0: 미납 / 청구 대상, 1: 수납 완료 내역
  final NumberFormat _currencyFormat = NumberFormat('#,###');

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

              // Filter Invoices
              final unpaidInvoices = invoices.where((i) => i.status == PaymentStatus.unpaid).toList();
              final paidInvoices = invoices.where((i) => i.status == PaymentStatus.paid).toList();

              // Calculate metrics
              final totalUnpaidAmount = unpaidInvoices.fold<int>(0, (sum, i) => sum + i.amount);
              final totalPaidAmount = paidInvoices.fold<int>(0, (sum, i) => sum + i.amount);

              // Members nearing session expiry (remaining <= 1)
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

                  // 2. Segmented Control & Filter Chips
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

                  // Expiring Sessions Warning Strip (if any)
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
                                '회차 만료 임박 회원: ${expiringMembers.map((m) => m.name.split(' ').first).join(', ')} (${expiringMembers.length}명)',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB45309),
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                _openQuickInvoiceForMember(context, expiringMembers.first, studio);
                              },
                              child: const Text(
                                '재등록 청구',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.primaryBlue,
                                  decoration: TextDecoration.underline,
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
          '청구서 전송',
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
                  overflow: TextOverflow.ellipsis,
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
              // 1. One-touch SMS / Kakao native send (0 server cost)
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _sendSmsInvoice(context, studio, invoiceMembers, invoice),
                  icon: const Icon(Icons.sms_outlined, size: 16),
                  label: const Text('문자 서식 전송'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. Manual Cash / Card Mark as Paid
              if (!isPaid)
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showPaymentConfirmDialog(context, invoice),
                    icon: const Icon(Icons.check, size: 16, color: Colors.white),
                    label: const Text('수납 확인'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.softMint,
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
  ) async {
    final message = SmsTemplateService.generateInvoiceMessage(
      studio: studio,
      members: members,
      invoice: invoice,
    );

    final success = await SmsTemplateService.launchNativeSms(
      recipientPhone: invoice.recipientPhone,
      body: message,
    );

    if (!success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('문자 앱을 실행할 수 없습니다. 번호를 확인해주세요.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showPaymentConfirmDialog(BuildContext context, Invoice invoice) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
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
                const SizedBox(height: 20),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.account_balance, color: AppTheme.primaryBlue),
                  ),
                  title: const Text('계좌 입금 확인'),
                  subtitle: const Text('은행 통장으로 입금 완료됨'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(invoicesProvider.notifier).markAsPaid(
                          invoiceId: invoice.id,
                          paymentMethod: 'TRANSFER',
                        );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFECFDF5),
                    child: Icon(Icons.credit_card, color: AppTheme.softMint),
                  ),
                  title: const Text('오프라인 카드 단말기'),
                  subtitle: const Text('학원/스튜디오 현장 카드 결제'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(invoicesProvider.notifier).markAsPaid(
                          invoiceId: invoice.id,
                          paymentMethod: 'OFFLINE_CARD',
                        );
                  },
                ),
                ListTile(
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFFBEB),
                    child: Icon(Icons.payments_outlined, color: AppTheme.warning),
                  ),
                  title: const Text('현금 수납'),
                  subtitle: const Text('현장 현금 수령'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(invoicesProvider.notifier).markAsPaid(
                          invoiceId: invoice.id,
                          paymentMethod: 'CASH',
                        );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _openQuickInvoiceForMember(BuildContext context, Member member, StudioProfile studio) {
    _openQuickInvoiceSheet(context, [member], studio, initialMember: member);
  }

  void _openQuickInvoiceSheet(
    BuildContext context,
    List<Member> allMembers,
    StudioProfile studio, {
    Member? initialMember,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _QuickInvoiceModal(
        allMembers: allMembers,
        studio: studio,
        initialMember: initialMember,
      ),
    );
  }
}

class _QuickInvoiceModal extends StatefulWidget {
  final List<Member> allMembers;
  final StudioProfile studio;
  final Member? initialMember;

  const _QuickInvoiceModal({
    required this.allMembers,
    required this.studio,
    this.initialMember,
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
    if (widget.initialMember != null) {
      _selectMember(widget.initialMember!);
    } else if (widget.allMembers.isNotEmpty) {
      _selectMember(widget.allMembers.first);
    }
  }

  void _selectMember(Member m) {
    _selectedMemberIds.clear();
    _selectedMemberIds.add(m.id);

    // Sibling auto-detection: check if other members share the same phone!
    final siblings = widget.allMembers.where((other) => other.phone == m.phone).toList();
    for (final sib in siblings) {
      _selectedMemberIds.add(sib.id);
    }

    final totalDefaultFee = widget.allMembers
        .where((item) => _selectedMemberIds.contains(item.id))
        .fold<int>(0, (sum, item) => sum + item.defaultFee);

    final title = siblings.length > 1
        ? '${m.registeredAt.month}월 수강 패스 (${siblings.map((s) => s.name.split(' ').first).join('/')} 형제 합산)'
        : '${m.name.split(' ').first} 수강 패스 안내';

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
            TextField(
              controller: _titleController,
              decoration: InputDecoration(
                labelText: '청구 제목',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),

            // Amount & Preset Buttons
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '청구 금액 (원)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                suffixText: '원',
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
            const SizedBox(height: 12),

            // Recipient Phone
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: '수신인 연락처 (학부모/회원)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 20),

            // Submit Button
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
                      '청구서 생성 완료',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
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
