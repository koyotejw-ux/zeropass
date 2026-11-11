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

  String _formatMonthTitle(DateTime d) {
    if (LocalizationService.currentLanguage == AppLanguage.korean) {
      return DateFormat('yyyy년 M월', 'ko_KR').format(d);
    }
    const enMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const esMonths = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];
    return LocalizationService.pick(
      ko: '${d.year}년 ${d.month}월',
      en: '${enMonths[d.month - 1]} ${d.year}',
      ja: '${d.year}年${d.month}月',
      zh: '${d.year}年${d.month}月',
      vi: 'Th${d.month}/${d.year}',
      es: '${esMonths[d.month - 1]} ${d.year}',
    );
  }

  String _formatSelectedDayHeader(DateTime d) {
    if (LocalizationService.currentLanguage == AppLanguage.korean) {
      return DateFormat('M월 d일 (E) 현황', 'ko_KR').format(d);
    }
    final weekdays = LocalizationService.pickList(
      ko: const ['월', '화', '수', '목', '금', '토', '일'],
      en: const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'],
      ja: const ['月', '火', '水', '木', '金', '土', '日'],
      zh: const ['周一', '周二', '周三', '周四', '周五', '周六', '周日'],
      vi: const ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'],
      es: const ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'],
    );
    final wd = weekdays[(d.weekday - 1).clamp(0, 6)];
    return LocalizationService.pick(
      ko: '${d.month}월 ${d.day}일 ($wd) 현황',
      en: '${LocalizationService.formatDate(d)} ($wd)',
      ja: '${d.month}月${d.day}日 ($wd)',
      zh: '${d.month}月${d.day}日 ($wd)',
      vi: '${LocalizationService.formatDate(d)} ($wd)',
      es: '${LocalizationService.formatDate(d)} ($wd)',
    );
  }

  void _openAddScheduleDialog(BuildContext context, DateTime targetDate, {ScheduleItem? editItem}) {
    final isEdit = editItem != null;
    final titleController = TextEditingController(text: editItem?.title ?? '');
    final memoController = TextEditingController(text: editItem?.memo ?? '');
    var selectedCat = editItem?.category ?? ScheduleCategory.academy;
    final targetDateStr = LocalizationService.currentLanguage == AppLanguage.korean
        ? DateFormat('M월 d일', 'ko_KR').format(targetDate)
        : LocalizationService.formatDate(targetDate);

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
                      ? LocalizationService.pick(
                          ko: '$targetDateStr 일정 수정',
                          en: 'Edit Event ($targetDateStr)',
                          ja: '$targetDateStr 予定を編集',
                          zh: '编辑日程 ($targetDateStr)',
                          vi: 'Sửa lịch ($targetDateStr)',
                          es: 'Editar evento ($targetDateStr)',
                        )
                      : LocalizationService.pick(
                          ko: '$targetDateStr 새 일정 등록',
                          en: 'New Event ($targetDateStr)',
                          ja: '$targetDateStr 新しい予定を追加',
                          zh: '新建日程 ($targetDateStr)',
                          vi: 'Thêm lịch mới ($targetDateStr)',
                          es: 'Nuevo evento ($targetDateStr)',
                        ),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 4, 2, 8),
                  child: Text(
                    LocalizationService.pick(
                      ko: '일정 분류',
                      en: 'Category',
                      ja: 'カテゴリ',
                      zh: '日程分类',
                      vi: 'Phân loại',
                      es: 'Categoría',
                    ),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                  ),
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
                        label: Text(cat.localizedLabel, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w800 : FontWeight.w600, color: isSel ? Colors.white : AppTheme.textPrimary)),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
                  child: Text(
                    LocalizationService.pick(
                      ko: '일정 명칭',
                      en: 'Event Title',
                      ja: '予定タイトル',
                      zh: '日程标题',
                      vi: 'Tên lịch trình',
                      es: 'Título del evento',
                    ),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: TextField(
                    controller: titleController,
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: LocalizationService.pick(
                        ko: '예: 겨울방학 특강 개강, 정기 모의고사',
                        en: 'e.g. Winter Workshop, Belt Test, Tax Filing',
                        ja: '例：特別講座スタート、昇級審査',
                        zh: '例：寒假特训开课、阶段测评',
                        vi: 'VD: Khai giảng khóa mới, Thi đánh giá',
                        es: 'Ej. Taller especial, Examen de nivel',
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF8FAFC),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppTheme.borderSubtle)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 6, 2, 8),
                  child: Text(
                    LocalizationService.pick(
                      ko: '상세 메모 (선택)',
                      en: 'Memo (Optional)',
                      ja: 'メモ（任意）',
                      zh: '详细备注（可选）',
                      vi: 'Ghi chú (Tùy chọn)',
                      es: 'Notas (Opcional)',
                    ),
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  child: TextField(
                    controller: memoController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      hintText: LocalizationService.pick(
                        ko: '일정에 대한 간단한 안내나 준비사항을 입력하세요.',
                        en: 'Add preparation notes or reminders.',
                        ja: '案内事項や持ち物などを入力してください。',
                        zh: '输入说明或准备事项。',
                        vi: 'Nhập ghi chú hoặc lưu ý chuẩn bị.',
                        es: 'Añade detalles o recordatorios.',
                      ),
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
                    label: isEdit
                        ? LocalizationService.pick(ko: '수정하기', en: 'Save', ja: '更新する', zh: '保存修改', vi: 'Cập nhật', es: 'Guardar')
                        : LocalizationService.pick(ko: '등록하기', en: 'Add', ja: '登録する', zh: '添加日程', vi: 'Thêm', es: 'Añadir'),
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      final memo = memoController.text.trim().isEmpty ? null : memoController.text.trim();
                      final bm = MonetizationService.instance;
                      final itemLabel = LocalizationService.pick(ko: '일정', en: 'Schedule', ja: '予定', zh: '日程', vi: 'Lịch', es: 'Evento');
                      if (isEdit) {
                        if (!await bm.ensureEditAllowed(dialogCtx, itemLabel: itemLabel)) return;
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
                              content: Text(
                                LocalizationService.pick(
                                  ko: '\'$title\' 일정이 수정되었습니다.',
                                  en: 'Updated schedule "$title".',
                                  ja: '「$title」の予定を更新しました。',
                                  zh: '已修改日程“$title”。',
                                  vi: 'Đã cập nhật lịch "$title".',
                                  es: 'Evento "$title" actualizado.',
                                ),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else {
                        final curCount = ref.read(schedulesProvider).value?.length ?? 0;
                        if (!await bm.ensureCreateAllowed(
                          dialogCtx,
                          itemLabel: itemLabel,
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
                              content: Text(
                                LocalizationService.pick(
                                  ko: '\'$title\' 일정이 등록되었습니다.',
                                  en: 'Added schedule "$title".',
                                  ja: '「$title」の予定を登録しました。',
                                  zh: '已添加日程“$title”。',
                                  vi: 'Đã thêm lịch "$title".',
                                  es: 'Evento "$title" añadido.',
                                ),
                              ),
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
                    Expanded(
                      child: Text(
                        LocalizationService.pick(
                          ko: '출결 & 일정 스케줄 달력',
                          en: 'Attendance & Schedule Calendar',
                          ja: '出席＆スケジュールカレンダー',
                          zh: '考勤与日程日历',
                          vi: 'Lịch Điểm danh & Hoạt động',
                          es: 'Calendario de Asistencia y Eventos',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
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
                    _formatMonthTitle(_focusedMonth),
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
                      child: Text(
                        LocalizationService.pick(
                          ko: '오늘',
                          en: 'Today',
                          ja: '今日',
                          zh: '今天',
                          vi: 'Hôm nay',
                          es: 'Hoy',
                        ),
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
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
                    tooltip: LocalizationService.pick(ko: '이전 달', en: 'Previous Month', ja: '前月', zh: '上个月', vi: 'Tháng trước', es: 'Mes anterior'),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded, size: 20),
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
                    onPressed: _nextMonth,
                    tooltip: LocalizationService.pick(ko: '다음 달', en: 'Next Month', ja: '翌月', zh: '下个月', vi: 'Tháng sau', es: 'Mes siguiente'),
                  ),
                  const SizedBox(width: 4),
                  Material(
                    color: AppTheme.primaryDark,
                    borderRadius: BorderRadius.circular(7),
                    child: InkWell(
                      onTap: () => _openAddScheduleDialog(context, _selectedDate),
                      borderRadius: BorderRadius.circular(7),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.add, size: 13, color: Colors.white),
                            const SizedBox(width: 2),
                            Text(
                              LocalizationService.pick(ko: '일정 추가', en: 'Add', ja: '追加', zh: '添加', vi: 'Thêm', es: 'Añadir'),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                            ),
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
          child: Builder(
            builder: (_) {
              final dayLabels = LocalizationService.pickList(
                ko: const ['일', '월', '화', '수', '목', '금', '토'],
                en: const ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'],
                ja: const ['日', '月', '火', '水', '木', '金', '土'],
                zh: const ['日', '一', '二', '三', '四', '五', '六'],
                vi: const ['CN', 'T2', 'T3', 'T4', 'T5', 'T6', 'T7'],
                es: const ['Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb'],
              );
              return Row(
                children: List.generate(7, (i) {
                  final color = i == 0
                      ? const Color(0xFFEF4444)
                      : (i == 6 ? const Color(0xFF3B82F6) : AppTheme.textSecondary);
                  return Expanded(
                    child: Center(
                      child: Text(dayLabels[i], style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
                    ),
                  );
                }),
              );
            },
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
                          _formatSelectedDayHeader(_selectedDate),
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
                        _buildCountBadge(
                          LocalizationService.pick(
                            ko: '출석 ${selectedDayRecords.length}명',
                            en: 'Attended ${selectedDayRecords.length}',
                            ja: '出席 ${selectedDayRecords.length}名',
                            zh: '签到 ${selectedDayRecords.length} 人',
                            vi: 'Điểm danh ${selectedDayRecords.length}',
                            es: 'Asist. ${selectedDayRecords.length}',
                          ),
                          const Color(0xFF059669),
                          const Color(0xFFECFDF5),
                        ),
                        _buildCountBadge(
                          LocalizationService.pick(
                            ko: '일정 ${selectedDaySchedules.length}건',
                            en: 'Events ${selectedDaySchedules.length}',
                            ja: '予定 ${selectedDaySchedules.length}件',
                            zh: '日程 ${selectedDaySchedules.length} 条',
                            vi: 'Lịch ${selectedDaySchedules.length}',
                            es: 'Eventos ${selectedDaySchedules.length}',
                          ),
                          const Color(0xFF6366F1),
                          const Color(0xFFEEF2FF),
                        ),
                        if (selectedDayInvoices.isNotEmpty)
                          _buildCountBadge(
                            LocalizationService.pick(
                              ko: '청구 ${selectedDayInvoices.length}건',
                              en: 'Due ${selectedDayInvoices.length}',
                              ja: '請求 ${selectedDayInvoices.length}件',
                              zh: '账单 ${selectedDayInvoices.length} 笔',
                              vi: 'Hóa đơn ${selectedDayInvoices.length}',
                              es: 'Fact. ${selectedDayInvoices.length}',
                            ),
                            const Color(0xFFD97706),
                            const Color(0xFFFFFBEB),
                          ),
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
                    LocalizationService.pick(
                      ko: '$dayPassCount명',
                      en: '$dayPassCount',
                      ja: '$dayPassCount名',
                      zh: '$dayPassCount人',
                      vi: '$dayPassCount',
                      es: '$dayPassCount',
                    ),
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
                    LocalizationService.pick(
                      ko: '${studio.memberTitle} 출결 내역 (${records.length}건)',
                      en: '${studio.memberTitle} Attendance (${records.length})',
                      ja: '${studio.memberTitle} 出席履歴 (${records.length}件)',
                      zh: '${studio.memberTitle} 考勤记录 (${records.length})',
                      vi: 'Điểm danh ${studio.memberTitle} (${records.length})',
                      es: 'Asistencia (${records.length})',
                    ),
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
                      LocalizationService.pick(
                        ko: '해당 일자에 기록된 ${studio.memberTitle} 출결 내역이 없습니다.',
                        en: 'No attendance records logged for this date.',
                        ja: 'この日の出席記録はありません。',
                        zh: '该日期暂无考勤记录。',
                        vi: 'Chưa có lượt điểm danh nào vào ngày này.',
                        es: 'Sin registros de asistencia para esta fecha.',
                      ),
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
                final name = member?.primaryName ?? studio.memberWord;
                final group = LocalizationService.localizeBuiltInLabel(
                  member?.groupName ?? LocalizationService.pick(ko: '일반', en: 'General', ja: '一般', zh: '常规', vi: 'Chung', es: 'General'),
                );
                final timeStr = DateFormat('HH:mm').format(rec.timestamp);

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFECFDF5),
                    child: Text(
                      name.isNotEmpty ? name[0] : '?',
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
                  subtitle: Text(
                    LocalizationService.pick(
                      ko: '$timeStr 체크인 완료',
                      en: 'Checked in at $timeStr',
                      ja: '$timeStr チェックイン済み',
                      zh: '$timeStr 已完成签到',
                      vi: 'Đã điểm danh lúc $timeStr',
                      es: 'Check-in a las $timeStr',
                    ),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      LocalizationService.pick(
                        ko: '정상 출석',
                        en: 'Attended',
                        ja: '出席',
                        zh: '正常出勤',
                        vi: 'Có mặt',
                        es: 'Asistió',
                      ),
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                    ),
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
                          LocalizationService.pick(
                            ko: '스튜디오 주요 일정 (${schedules.length}건)',
                            en: 'Studio Events (${schedules.length})',
                            ja: 'スタジオ予定 (${schedules.length}件)',
                            zh: '机构重要日程 (${schedules.length})',
                            vi: 'Sự kiện cơ sở (${schedules.length})',
                            es: 'Eventos del centro (${schedules.length})',
                          ),
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
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Text(
                      LocalizationService.pick(
                        ko: '+ 일정 추가',
                        en: '+ Add Event',
                        ja: '+ 予定追加',
                        zh: '+ 添加日程',
                        vi: '+ Thêm lịch',
                        es: '+ Añadir',
                      ),
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
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
                  LocalizationService.pick(
                    ko: '등록된 주요 일정이 없습니다. [+ 일정 추가]로 등록해 보세요.',
                    en: 'No events scheduled. Tap [+ Add Event] to create one.',
                    ja: '登録された予定はありません。[+ 予定追加]から登録できます。',
                    zh: '暂无重要日程，点击 [+ 添加日程] 即可创建。',
                    vi: 'Chưa có lịch nào. Nhấn [+ Thêm lịch] để thêm mới.',
                    es: 'Sin eventos programados. Pulsa [+ Añadir] para crear uno.',
                  ),
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
                              sch.category.localizedLabel,
                              style: TextStyle(fontSize: 11.5, color: Color(sch.category.colorValue), fontWeight: FontWeight.w600),
                            ),
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textTertiary),
                      onPressed: () {
                        ref.read(schedulesProvider.notifier).deleteSchedule(sch.id);
                      },
                      tooltip: LocalizationService.pick(ko: '일정 삭제', en: 'Delete Event', ja: '予定を削除', zh: '删除日程', vi: 'Xóa lịch', es: 'Eliminar evento'),
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
                    LocalizationService.pick(
                      ko: '${studio.feeTitle} 납부 마감 청구서 (${invoices.length}건)',
                      en: '${studio.feeTitle} Due Invoices (${invoices.length})',
                      ja: '${studio.feeTitle} 支払期限の請求書 (${invoices.length}件)',
                      zh: '${studio.feeTitle} 到期账单 (${invoices.length})',
                      vi: 'Hóa đơn ${studio.feeTitle} đến hạn (${invoices.length})',
                      es: 'Facturas por vencer (${invoices.length})',
                    ),
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
                  '${member?.primaryName ?? studio.memberWord} - ${inv.title}',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  LocalizationService.pick(
                    ko: '${LocalizationService.formatAmount(inv.amount)} · 기한: ${DateFormat('M/d').format(inv.dueDate)}',
                    en: '${LocalizationService.formatAmount(inv.amount)} · Due: ${LocalizationService.formatDate(inv.dueDate)}',
                    ja: '${LocalizationService.formatAmount(inv.amount)} · 期限: ${DateFormat('M/d').format(inv.dueDate)}',
                    zh: '${LocalizationService.formatAmount(inv.amount)} · 截止: ${DateFormat('M/d').format(inv.dueDate)}',
                    vi: '${LocalizationService.formatAmount(inv.amount)} · Hạn: ${LocalizationService.formatDate(inv.dueDate)}',
                    es: '${LocalizationService.formatAmount(inv.amount)} · Vence: ${LocalizationService.formatDate(inv.dueDate)}',
                  ),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isPaid ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isPaid
                        ? LocalizationService.pick(ko: '수납완료', en: 'Paid', ja: '領収済', zh: '已收款', vi: 'Đã thu', es: 'Pagado')
                        : LocalizationService.pick(ko: '미납', en: 'Unpaid', ja: '未納', zh: '未付', vi: 'Chưa thu', es: 'Impago'),
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
