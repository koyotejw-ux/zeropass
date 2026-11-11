import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/schedule_item.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'design_system.dart';
import '../services/localization_service.dart';
import '../services/monetization_service.dart';

class ScheduleCalendarModal extends ConsumerStatefulWidget {
  final DateTime? initialDate;

  const ScheduleCalendarModal({super.key, this.initialDate});

  static void show(BuildContext context, {DateTime? initialDate}) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.94,
      builder: (_) => ScheduleCalendarModal(initialDate: initialDate),
    );
  }

  @override
  ConsumerState<ScheduleCalendarModal> createState() => _ScheduleCalendarModalState();
}

class _ScheduleCalendarModalState extends ConsumerState<ScheduleCalendarModal> {
  late DateTime _focusedMonth;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    final now = widget.initialDate ?? DateTime.now();
    _focusedMonth = DateTime(now.year, now.month, 1);
    _selectedDate = DateTime(now.year, now.month, now.day);
  }

  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  void _goToToday() {
    final now = DateTime.now();
    setState(() {
      _focusedMonth = DateTime(now.year, now.month, 1);
      _selectedDate = DateTime(now.year, now.month, now.day);
    });
  }

  void _openAddScheduleDialog(BuildContext context, DateTime targetDate, {ScheduleItem? editItem}) {
    final isEdit = editItem != null;
    final titleController = TextEditingController(text: editItem?.title ?? '');
    final memoController = TextEditingController(text: editItem?.memo ?? '');
    var selectedCat = editItem?.category ?? ScheduleCategory.academy;

    showDialog(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_note_rounded, color: AppTheme.primaryBlue, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isEdit
                      ? '${DateFormat('M월 d일', 'ko_KR').format(targetDate)} 일정 수정'
                      : '${DateFormat('M월 d일', 'ko_KR').format(targetDate)} 새 일정 등록',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(2, 4, 2, 8),
                  child: Text('일정 분류', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: ScheduleCategory.values.map((cat) {
                      final isSel = cat == selectedCat;
                      return ChoiceChip(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                        label: Text(cat.label, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? Colors.white : AppTheme.textPrimary)),
                        selected: isSel,
                        selectedColor: Color(cat.colorValue),
                        backgroundColor: const Color(0xFFF1F5F9),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() => selectedCat = cat);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.fromLTRB(2, 6, 2, 8),
                  child: Text('일정 명칭', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: '예: 겨울방학 특강 개강, 정기 모의고사',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.fromLTRB(2, 6, 2, 8),
                  child: Text('상세 메모 (선택)', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: TextField(
                    controller: memoController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: '일정에 대한 간단한 안내나 준비사항을 입력하세요.',
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
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
                    onPressed: () => Navigator.pop(dialogCtx),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ZeroButton.primary(
                    label: isEdit ? '수정하기' : '등록하기',
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      final memo = memoController.text.trim().isEmpty ? null : memoController.text.trim();
                      final bm = MonetizationService.instance;
                      if (isEdit) {
                        if (!await bm.ensureEditAllowed(dialogCtx, itemLabel: '일정')) return;
                        final updated = editItem.copyWith(
                          title: title,
                          category: selectedCat,
                          memo: memo,
                        );
                        await ref.read(schedulesProvider.notifier).updateSchedule(updated);
                        await bm.recordEditUsage();
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('\'$title\' 일정이 수정되었습니다.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else {
                        final curCount = ref.read(schedulesProvider).value?.length ?? 0;
                        if (!await bm.ensureCreateAllowed(
                          dialogCtx,
                          itemLabel: '일정',
                          currentCount: curCount,
                          limit: bm.maxScheduleLimit,
                        )) {
                          return;
                        }
                        final newItem = ScheduleItem(
                          id: 'sch_${DateTime.now().millisecondsSinceEpoch}',
                          title: title,
                          date: targetDate,
                          category: selectedCat,
                          memo: memo,
                          createdAt: DateTime.now(),
                        );
                        await ref.read(schedulesProvider.notifier).addSchedule(newItem);
                        if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('\'$title\' 일정이 등록되었습니다.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
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

  @override
  Widget build(BuildContext context) {
    final passRecordsAsync = ref.watch(passRecordsProvider);
    final membersAsync = ref.watch(membersProvider);
    final invoicesAsync = ref.watch(invoicesProvider);
    final schedulesAsync = ref.watch(schedulesProvider);
    final studioAsync = ref.watch(studioProfileProvider);

    final passRecords = passRecordsAsync.value ?? [];
    final members = membersAsync.value ?? [];
    final invoices = invoicesAsync.value ?? [];
    final schedules = schedulesAsync.value ?? [];
    final studio = studioAsync.value ?? StudioProfile.defaultProfile();

    final memberMap = {for (var m in members) m.id: m};

    // Calculate month metrics
    final year = _focusedMonth.year;
    final month = _focusedMonth.month;
    final firstDayOfWeek = DateTime(year, month, 1).weekday % 7; // Sunday=0, Monday=1...
    final daysInMonth = DateTime(year, month + 1, 0).day;

    // Filter data for selected date
    final selectedDayRecords = passRecords.where((r) {
      return r.timestamp.year == _selectedDate.year &&
          r.timestamp.month == _selectedDate.month &&
          r.timestamp.day == _selectedDate.day;
    }).toList();

    final selectedDaySchedules = schedules.where((s) {
      return s.date.year == _selectedDate.year &&
          s.date.month == _selectedDate.month &&
          s.date.day == _selectedDate.day;
    }).toList();

    final selectedDayInvoices = invoices.where((inv) {
      return inv.dueDate.year == _selectedDate.year &&
          inv.dueDate.month == _selectedDate.month &&
          inv.dueDate.day == _selectedDate.day;
    }).toList();

    return Column(
      children: [
        // Modal Header Bar with Title and Close Button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 12, 10),
          child: Row(
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
                      child: const Icon(Icons.calendar_month_rounded, color: AppTheme.primaryBlue, size: 20),
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        '출결 & 일정 스케줄 달력',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 17,
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
                onPressed: () => Navigator.pop(context),
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
              ),
            ],
          ),
        ),
        // Top Month Navigator Bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: const BoxDecoration(
            color: Color(0xFFF8FAFC),
            border: Border(
              bottom: BorderSide(color: AppTheme.borderSubtle, width: 0.8),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    DateFormat('yyyy년 M월', 'ko_KR').format(_focusedMonth),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                  ),
                  const SizedBox(width: 5),
                  InkWell(
                    onTap: _goToToday,
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: AppTheme.borderSubtle),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '오늘',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _prevMonth,
                    tooltip: '이전 달',
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _nextMonth,
                    tooltip: '다음 달',
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: AppTheme.primaryDark,
                    borderRadius: BorderRadius.circular(7),
                    child: InkWell(
                      onTap: () => _openAddScheduleDialog(context, _selectedDate),
                      borderRadius: BorderRadius.circular(7),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.add, size: 13, color: Colors.white),
                            SizedBox(width: 2),
                            Text('일정 추가', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Calendar Weekday Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: const [
              Expanded(child: Center(child: Text('일', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFEF4444))))),
              Expanded(child: Center(child: Text('월', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)))),
              Expanded(child: Center(child: Text('화', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)))),
              Expanded(child: Center(child: Text('수', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)))),
              Expanded(child: Center(child: Text('목', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)))),
              Expanded(child: Center(child: Text('금', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)))),
              Expanded(child: Center(child: Text('토', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF3B82F6))))),
            ],
          ),
        ),

        // Monthly Grid View
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(6, 0, 6, 8),
          child: _buildMonthGrid(
            year: year,
            month: month,
            firstDayOfWeek: firstDayOfWeek,
            daysInMonth: daysInMonth,
            passRecords: passRecords,
            schedules: schedules,
            invoices: invoices,
          ),
        ),

        const Divider(height: 1, thickness: 1, color: AppTheme.borderSubtle),

        // Selected Date Details (Attendance + Schedule + Due Invoices)
        Expanded(
          child: Container(
            color: AppTheme.background,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
              children: [
                // Selected Day Header Bar (Responsive Wrap)
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
                          width: 4,
                          height: 18,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryBlue,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('M월 d일 (E) 현황', 'ko_KR').format(_selectedDate),
                          style: const TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        _buildCountBadge('출석 ${selectedDayRecords.length}명', const Color(0xFF059669), const Color(0xFFECFDF5)),
                        _buildCountBadge('일정 ${selectedDaySchedules.length}건', const Color(0xFF6366F1), const Color(0xFFEEF2FF)),
                        if (selectedDayInvoices.isNotEmpty)
                          _buildCountBadge('청구 ${selectedDayInvoices.length}건', const Color(0xFFD97706), const Color(0xFFFFFBEB)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // 1. Attendance Records on this Date
                _buildAttendanceCard(selectedDayRecords, memberMap, studio),
                const SizedBox(height: 12),

                // 2. Schedules on this Date
                _buildScheduleCard(selectedDaySchedules),
                const SizedBox(height: 12),

                // 3. Invoices Due on this Date
                if (selectedDayInvoices.isNotEmpty)
                  _buildInvoicesDueCard(selectedDayInvoices, memberMap, studio),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCountBadge(String label, Color textColor, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: textColor),
      ),
    );
  }

  Widget _buildMonthGrid({
    required int year,
    required int month,
    required int firstDayOfWeek,
    required int daysInMonth,
    required List<PassRecord> passRecords,
    required List<ScheduleItem> schedules,
    required List<Invoice> invoices,
  }) {
    final now = DateTime.now();
    final totalCells = ((firstDayOfWeek + daysInMonth + 6) ~/ 7) * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        childAspectRatio: 1.15,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < firstDayOfWeek || index >= firstDayOfWeek + daysInMonth) {
          return const SizedBox.shrink();
        }
        final day = index - firstDayOfWeek + 1;
        final cellDate = DateTime(year, month, day);
        final isToday = cellDate.year == now.year && cellDate.month == now.month && cellDate.day == now.day;
        final isSelected = cellDate.year == _selectedDate.year && cellDate.month == _selectedDate.month && cellDate.day == _selectedDate.day;
        final weekday = cellDate.weekday; // 7=Sun, 6=Sat

        // Day attendance count
        final dayPassCount = passRecords.where((r) {
          return r.timestamp.year == year && r.timestamp.month == month && r.timestamp.day == day;
        }).length;

        // Day schedules
        final daySchedules = schedules.where((s) {
          return s.date.year == year && s.date.month == month && s.date.day == day;
        }).toList();

        // Day invoices due
        final dayInvoicesDue = invoices.where((inv) {
          return inv.dueDate.year == year && inv.dueDate.month == month && inv.dueDate.day == day;
        }).length;

        Color textColor = AppTheme.textPrimary;
        if (weekday == DateTime.sunday) {
          textColor = const Color(0xFFEF4444);
        } else if (weekday == DateTime.saturday) {
          textColor = const Color(0xFF3B82F6);
        }

        return InkWell(
          onTap: () {
            setState(() {
              _selectedDate = cellDate;
            });
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primaryDark
                  : (isToday ? AppTheme.primaryBlue.withValues(alpha: 0.08) : Colors.transparent),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? AppTheme.primaryDark
                    : (isToday ? AppTheme.primaryBlue : Colors.transparent),
                width: isToday || isSelected ? 1.5 : 0,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected || isToday ? FontWeight.w800 : FontWeight.w600,
                    color: isSelected ? Colors.white : textColor,
                  ),
                ),
                const SizedBox(height: 2),
                // Indicator dots / badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (dayPassCount > 0)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : const Color(0xFF059669),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (daySchedules.isNotEmpty)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white70 : const Color(0xFF6366F1),
                          shape: BoxShape.circle,
                        ),
                      ),
                    if (dayInvoicesDue > 0)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.amberAccent : const Color(0xFFD97706),
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                if (dayPassCount > 0) ...[
                  const SizedBox(height: 1),
                  Text(
                    '$dayPassCount명',
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? Colors.white70 : const Color(0xFF059669),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttendanceCard(
    List<PassRecord> records,
    Map<String, Member> memberMap,
    StudioProfile studio,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.fact_check_rounded, size: 18, color: Color(0xFF059669)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${studio.memberTitle} 출결 내역 (${records.length}건)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          if (records.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.event_busy_rounded, size: 32, color: Colors.grey.shade400),
                    const SizedBox(height: 6),
                    Text(
                      '해당 일자에 기록된 ${studio.memberTitle} 출결 내역이 없습니다.',
                      style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: records.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final rec = records[idx];
                final member = memberMap[rec.memberId];
                final name = member?.primaryName ?? '회원';
                final group = member?.groupName ?? '일반';
                final timeStr = DateFormat('HH:mm').format(rec.timestamp);

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFECFDF5),
                    child: Text(
                      name.isNotEmpty ? name[0] : '회',
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                    ),
                  ),
                  title: Row(
                    children: [
                      Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(group, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                  subtitle: Text('$timeStr 체크인 완료', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text('정상 출석', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(List<ScheduleItem> schedules) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Icon(Icons.event_available_rounded, size: 18, color: Color(0xFF6366F1)),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '스튜디오 주요 일정 (${schedules.length}건)',
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                InkWell(
                  onTap: () => _openAddScheduleDialog(context, _selectedDate),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      '+ 일정 추가',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          if (schedules.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
              child: Center(
                child: Text(
                  '등록된 주요 일정이 없습니다. [+ 일정 추가]로 등록해 보세요.',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: schedules.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
              itemBuilder: (context, idx) {
                final sch = schedules[idx];
                return Material(
                  color: Colors.transparent,
                  child: ListTile(
                    dense: true,
                    onTap: () => _openAddScheduleDialog(context, sch.date, editItem: sch),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Color(sch.category.colorValue).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.calendar_today_rounded, size: 17, color: Color(sch.category.colorValue)),
                    ),
                    title: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        sch.title,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                      ),
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: sch.memo != null && sch.memo!.isNotEmpty
                          ? Text(
                              sch.memo!,
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                            )
                          : Text(
                              sch.category.label,
                              style: TextStyle(fontSize: 11.5, color: Color(sch.category.colorValue), fontWeight: FontWeight.w600),
                            ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textTertiary),
                      onPressed: () {
                        ref.read(schedulesProvider.notifier).deleteSchedule(sch.id);
                      },
                      tooltip: '일정 삭제',
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildInvoicesDueCard(
    List<Invoice> invoices,
    Map<String, Member> memberMap,
    StudioProfile studio,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, size: 18, color: Color(0xFFD97706)),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    '${studio.feeTitle} 납부 마감 청구서 (${invoices.length}건)',
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: AppTheme.borderSubtle),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: invoices.length,
            separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFF1F5F9)),
            itemBuilder: (context, idx) {
              final inv = invoices[idx];
              final firstMemberId = inv.memberIds.isNotEmpty ? inv.memberIds.first : null;
              final member = firstMemberId != null ? memberMap[firstMemberId] : null;
              final isPaid = inv.status == PaymentStatus.paid;
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                title: Text(
                  '${member?.primaryName ?? '회원'} - ${inv.title}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  '${NumberFormat('#,###').format(inv.amount)}원 · 기한: ${DateFormat('M/d').format(inv.dueDate)}',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPaid ? '수납완료' : '미납',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: isPaid ? const Color(0xFF059669) : const Color(0xFFD97706),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
