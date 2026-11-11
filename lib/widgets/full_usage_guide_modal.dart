import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/localization_service.dart';
import '../services/monetization_service.dart';
import '../services/schedule_service.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'design_system.dart';
import 'responsive_dialog_actions.dart';

/// 운영·설정 탭에서 각 메뉴(출결/청구/지출·세무/회원/설정·키오스크·프로샵)별
/// 등록·조회·수정·삭제 및 실사용 데이터 전환 방법을 한눈에 안내하는 종합 사용 가이드 모달.
class FullUsageGuideModal extends ConsumerStatefulWidget {
  final ValueChanged<int>? onNavigateToTab;
  final VoidCallback? onOpenProStore;

  const FullUsageGuideModal({
    super.key,
    this.onNavigateToTab,
    this.onOpenProStore,
  });

  static Future<void> show(
    BuildContext context, {
    ValueChanged<int>? onNavigateToTab,
    VoidCallback? onOpenProStore,
  }) {
    return AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.94,
      builder: (_) => FullUsageGuideModal(
        onNavigateToTab: onNavigateToTab,
        onOpenProStore: onOpenProStore,
      ),
    );
  }

  @override
  ConsumerState<FullUsageGuideModal> createState() => _FullUsageGuideModalState();
}

class _FullUsageGuideModalState extends ConsumerState<FullUsageGuideModal> {
  int _selectedSection = 0;

  List<_GuideCategoryMeta> _buildCategories() => [
        _GuideCategoryMeta(
          index: 0,
          label: LocalizationService.pick(ko: '출결 체크', en: 'Check-In', ja: '出席', zh: '考勤', vi: 'Điểm danh', es: 'Asistencia'),
          icon: Icons.fact_check_outlined,
          tabIndex: 0,
        ),
        _GuideCategoryMeta(
          index: 1,
          label: LocalizationService.pick(ko: '청구·수납', en: 'Billing', ja: '請求', zh: '账单', vi: 'Hóa đơn', es: 'Cobros'),
          icon: Icons.receipt_long_outlined,
          tabIndex: 1,
        ),
        _GuideCategoryMeta(
          index: 2,
          label: LocalizationService.pick(ko: '지출·세무', en: 'Tax & Expense', ja: '支出・税務', zh: '支出税务', vi: 'Thuế & Chi', es: 'Gastos/Imp.'),
          icon: Icons.account_balance_wallet_outlined,
          tabIndex: 2,
        ),
        _GuideCategoryMeta(
          index: 3,
          label: LocalizationService.pick(ko: '회원 명부', en: 'Members', ja: '会員名簿', zh: '名册', vi: 'Hội viên', es: 'Miembros'),
          icon: Icons.groups_outlined,
          tabIndex: 3,
        ),
        _GuideCategoryMeta(
          index: 4,
          label: LocalizationService.pick(ko: '설정·프로샵', en: 'Settings/PRO', ja: '設定・PRO', zh: '设置/PRO', vi: 'Cài đặt/PRO', es: 'Ajustes/PRO'),
          icon: Icons.tune_outlined,
          tabIndex: 4,
        ),
      ];

  Future<void> _handleClearDummyDataAndStartReal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: AppTheme.primaryBlue, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LocalizationService.pick(
                  ko: '더미 데이터 비우고 실사용 시작',
                  en: 'Clear Sample Data & Start Live',
                  ja: 'サンプル消去＆本番運用開始',
                  zh: '清空演示数据并开始正式使用',
                  vi: 'Xóa dữ liệu mẫu & Bắt đầu thật',
                  es: 'Borrar datos de prueba y empezar',
                ),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          LocalizationService.pick(
            ko: '연습용 샘플 회원·출석·청구·거래처·지출·일정 데이터를 모두 지우고 실제 매장 데이터만 입력할 수 있는 깨끗한 상태로 초기화합니다.\n(스튜디오 상호·계좌·템플릿 설정은 유지됩니다.)',
            en: 'Removes all sample members, check-ins, invoices, vendors, expenses, and events to leave a clean slate for your live business.\n(Your studio profile, payout account, and message templates will be preserved.)',
            ja: '練習用のサンプル会員・出席・請求・取引先・支出・予定データをすべて消去し、実店舗データのみを管理できる状態にします。\n（スタジオ情報・口座・テンプレート設定は保持されます。）',
            zh: '清除全部演练用会员、考勤、账单、供应商、支出和日程数据，恢复干净状态以便录入真实门店数据。\n（机构资料、收款账户和短信模板配置将保留。）',
            vi: 'Xóa toàn bộ hội viên mẫu, lượt điểm danh, hóa đơn, nhà cung cấp, chi phí và lịch để bắt đầu sạch sẽ.\n(Thông tin cơ sở, tài khoản và mẫu tin nhắn vẫn được giữ nguyên.)',
            es: 'Elimina todos los alumnos, asistencias, facturas, gastos y eventos ficticios para empezar en limpio.\n(Tu estudio, cuenta de cobro y plantillas se conservan.)',
          ),
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          ResponsiveDialogActions(
            secondary: TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: Text(LocalizationService.tr('btn_cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            primary: ElevatedButton(
              onPressed: () => Navigator.pop(dlgCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  LocalizationService.pick(
                    ko: '깨끗이 비우고 시작',
                    en: 'Clear & Start',
                    ja: '消去して開始',
                    zh: '清空并开始',
                    vi: 'Xóa & Bắt đầu',
                    es: 'Borrar y empezar',
                  ),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final db = ref.read(databaseServiceProvider);
    await db.clearAllData();
    await ScheduleService.clearSchedules();
    await MonetizationService.instance.resetMetricsForRealUsage();
    await ref.read(membersProvider.notifier).reload();
    await ref.read(passRecordsProvider.notifier).reload();
    await ref.read(invoicesProvider.notifier).reload();
    await ref.read(vendorsProvider.notifier).reload();
    await ref.read(expensesProvider.notifier).reload();
    await ref.read(notificationLogsProvider.notifier).reload();
    await ref.read(schedulesProvider.notifier).reload();

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.pick(
              ko: '더미 데이터가 모두 비워졌습니다! 이제 회원 명부에서 실제 회원을 등록해 보세요.',
              en: 'All sample data cleared! Add your first real member in the Members tab.',
              ja: 'サンプルデータを消去しました！会員名簿タブから実際の会員を登録してください。',
              zh: '演示数据已全部清空！请前往学员名册添加您的真实会员。',
              vi: 'Đã xóa toàn bộ dữ liệu mẫu! Hãy thêm hội viên thật trong tab Hội viên.',
              es: '¡Datos de prueba borrados! Añade tu primer miembro real en Miembros.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      widget.onNavigateToTab?.call(3); // 회원 명부 탭으로 이동
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(studioProfileProvider).value ?? StudioProfile.defaultProfile();
    final membersCount = ref.watch(membersProvider).value?.length ?? 0;
    final categories = _buildCategories();
    final selectedCat = categories[_selectedSection];

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 360;
        final isWide = constraints.maxWidth >= 520;
        final hPad = isCompact ? 12.0 : 16.0;

        return Column(
          children: [
            // 1. Header
            Padding(
              padding: EdgeInsets.fromLTRB(hPad + 2, 12, 8, 8),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.menu_book_rounded, color: AppTheme.primaryBlue, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalizationService.pick(
                            ko: '체크앤페이 전체 메뉴·기능 가이드',
                            en: 'Complete Feature & Menu Guide',
                            ja: 'Check & Pay 全機能・メニューガイド',
                            zh: '全功能与菜单操作指南',
                            vi: 'Hướng dẫn toàn bộ tính năng & menu',
                            es: 'Guía Completa de Funciones',
                          ),
                          style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          softWrap: true,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          LocalizationService.pick(
                            ko: '각 탭별 등록·수정·삭제 및 실사용 운영 방법 안내',
                            en: 'How to add, edit, delete records & go live across every tab',
                            ja: '各タブの登録・編集・削除と本番運用ステップのご案内',
                            zh: '各标签页的增删改操作与正式运营切换指引',
                            vi: 'Cách thêm, sửa, xóa và chuyển sang vận hành thật ở mọi tab',
                            es: 'Cómo crear, editar, borrar registros y operar en cada pestaña',
                          ),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // 2. Category Selector Chips (Wrap cleanly on wide layouts, horizontal scroll on narrow mobile)
            if (isWide)
              Padding(
                padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: categories.map((cat) => _buildCategoryChip(cat)).toList(),
                ),
              )
            else
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => _buildCategoryChip(categories[i]),
                ),
              ),
            const Divider(height: 1, color: AppTheme.borderSubtle),

            // 3. Body Scrollable Content
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 24),
                children: [
                  // Quick Real-Data Transition Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: EdgeInsets.all(isCompact ? 12 : 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.rocket_launch_rounded, size: 18, color: AppTheme.primaryBlue),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                LocalizationService.pick(
                                  ko: '현재 등록된 회원: $membersCount명 · 실사용 전환 체크',
                                  en: 'Current Members: $membersCount · Live Launch Check',
                                  ja: '現在の登録会員: $membersCount名 · 本番移行チェック',
                                  zh: '当前已登记会员：$membersCount 人 · 正式启用检查',
                                  vi: 'Hội viên hiện có: $membersCount · Kiểm tra vận hành thật',
                                  es: 'Miembros actuales: $membersCount · Listo para empezar',
                                ),
                                style: const TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF1E3A8A),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          LocalizationService.pick(
                            ko: '앱 설치 직후에는 기능 체험을 위한 샘플 데이터가 들어 있습니다. 본인 매장의 실제 회원·수납·지출을 관리하려면 먼저 샘플 데이터를 비우고 스튜디오 정보(상호·입금 계좌)를 입력하세요.',
                            en: 'Sample data is preloaded right after install for hands-on practice. When ready for your real studio, clear sample records and enter your studio name & payout info.',
                            ja: '初期状態では体験用のサンプルデータが入っています。実際の店舗運用を始めるには、サンプルを消去して屋号・入金口座を設定してください。',
                            zh: '安装后已内置演示数据供您体验功能。准备正式使用时，请先清空演示数据并配置门店名称与收款账户。',
                            vi: 'Dữ liệu mẫu được cài sẵn để bạn trải nghiệm. Khi sẵn sàng dùng thật, hãy xóa dữ liệu mẫu và nhập thông tin cơ sở.',
                            es: 'La app incluye datos de prueba para practicar. Cuando estés listo, bórralos y registra tu centro y cuenta.',
                          ),
                          style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.45),
                        ),
                        const SizedBox(height: 10),
                        ZeroButton.primary(
                          label: LocalizationService.pick(
                            ko: '샘플 데이터 비우고 실사용 시작하기',
                            en: 'Clear Sample Data & Go Live',
                            ja: 'サンプルデータを消去して開始',
                            zh: '清空演示数据并开始正式使用',
                            vi: 'Xóa dữ liệu mẫu & Dùng thật',
                            es: 'Borrar datos de prueba y empezar',
                          ),
                          icon: Icons.cleaning_services_rounded,
                          size: ZeroButtonSize.medium,
                          fullWidth: true,
                          onPressed: _handleClearDummyDataAndStartReal,
                        ),
                      ],
                    ),
                  ),

                  // Section Guide Cards
                  ..._buildSectionCards(_selectedSection, profile),
                ],
              ),
            ),

            // Sticky Bottom CTA Bar
            if (widget.onNavigateToTab != null || (_selectedSection == 4 && widget.onOpenProStore != null))
              StickyBottomSheetFooter(
                padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.onNavigateToTab != null)
                      ZeroButton.secondary(
                        label: LocalizationService.pick(
                          ko: '${selectedCat.label} 탭으로 바로 이동하기',
                          en: 'Open ${selectedCat.label} Tab',
                          ja: '${selectedCat.label}タブへ移動',
                          zh: '立即前往${selectedCat.label}标签页',
                          vi: 'Mở tab ${selectedCat.label}',
                          es: 'Ir a ${selectedCat.label}',
                        ),
                        icon: Icons.arrow_forward_rounded,
                        size: ZeroButtonSize.large,
                        fullWidth: true,
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onNavigateToTab?.call(selectedCat.tabIndex);
                        },
                      ),
                    if (_selectedSection == 4 && widget.onOpenProStore != null) ...[
                      if (widget.onNavigateToTab != null) const SizedBox(height: 8),
                      ZeroButton.primary(
                        label: LocalizationService.pick(
                          ko: '프로샵(VIP 구독 · 1시간 무료 체험) 열기',
                          en: 'Open PRO Store (VIP Plans · 1-Hr Free Trial)',
                          ja: 'PROショップ（VIPプラン・1時間無料体験）を開く',
                          zh: '打开 PRO 商城（VIP 套餐 · 1小时免费试用）',
                          vi: 'Mở Cửa hàng PRO (Gói VIP · Dùng thử 1 giờ)',
                          es: 'Abrir Tienda PRO (Planes VIP · Prueba 1h gratis)',
                        ),
                        icon: Icons.workspace_premium_rounded,
                        size: ZeroButtonSize.large,
                        fullWidth: true,
                        onPressed: () {
                          Navigator.pop(context);
                          widget.onOpenProStore?.call();
                        },
                      ),
                    ],
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildCategoryChip(_GuideCategoryMeta cat) {
    final isSelected = _selectedSection == cat.index;
    return ChoiceChip(
      avatar: Icon(
        cat.icon,
        size: 16,
        color: isSelected ? Colors.white : AppTheme.primaryBlue,
      ),
      label: Text(cat.label),
      selected: isSelected,
      selectedColor: AppTheme.primaryDark,
      backgroundColor: const Color(0xFFF1F5F9),
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        color: isSelected ? Colors.white : AppTheme.textPrimary,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      onSelected: (_) => setState(() => _selectedSection = cat.index),
    );
  }

  List<Widget> _buildSectionCards(int section, StudioProfile profile) {
    final supportsToss = LocalizationService.supportsTossTransfer;
    final withholdingPct = '${(LocalizationService.defaultWithholdingRate * 100).toStringAsFixed(1)}%';
    switch (section) {
      case 0:
        return [
          _buildGuideCard(
            icon: Icons.touch_app_rounded,
            iconColor: AppTheme.primaryBlue,
            title: LocalizationService.pick(
              ko: '1. 1초 원터치 출석 체크 & 취소',
              en: '1. 1-Tap Check-In & Undo',
              ja: '1. 1秒ワンタッチ出席チェック＆取消',
              zh: '1. 1秒一键签到与撤回',
              vi: '1. Điểm danh 1 chạm & Hoàn tác',
              es: '1. Check-in en 1 toque y Deshacer',
            ),
            steps: LocalizationService.pickList(
              ko: const [
                '등록(체크인): 회원 카드의 [체크인] 버튼을 누르면 즉시 오늘 출석이 기록되며, 회차권 회원은 잔여 회차가 1회 자동 차감됩니다.',
                '출석 취소(회차 복구): 잘못 체크인한 경우 출석 완료 카드 아래 [오늘 출석 취소 (회차 복구)]를 누르면 기록이 삭제되고 차감된 회차가 즉시 복구됩니다.',
                '일괄 출석: 상단 우측 [일괄 출석]을 누르면 현재 필터에서 미출석 상태인 회원들을 한 번에 출석 처리할 수 있습니다.',
              ],
              en: const [
                'Check-In: Tap [Check-In] on any member card to log attendance today and automatically deduct 1 session pass if session-based.',
                'Undo Check-In: Tap [Undo Today Check-In] below a completed card to remove the log and restore the deducted session.',
                'Batch Check-In: Tap [Batch] in the header to check in all unvisited members matching your current filter at once.',
              ],
              ja: const [
                '登録（チェックイン）：会員カードの［チェックイン］を押すと即座に出席記録され、回数券会員は残回数が1回自動減算されます。',
                '出席取消（回数復旧）：誤ってチェックインした場合は［本日の出席を取消］を押すと記録が削除され回数が戻ります。',
                '一括出席：右上の［一括出席］を押すと、現在の絞り込み条件で未出席の会員をまとめてチェックインできます。',
              ],
              zh: const [
                '签到登记：点击会员卡【签到】即可记录当日考勤，次卡会员自动扣减1次余课。',
                '撤销签到：误点签到时可点击卡片下方的撤销按钮，立即删除记录并返还课次。',
                '批量签到：点击右上角批量签到，可一次性为当前筛选中的未到会员完成签到。',
              ],
              vi: const [
                'Điểm danh: Nhấn [Check-In] trên thẻ hội viên để ghi nhận hôm nay và tự động trừ 1 buổi nếu dùng gói buổi.',
                'Hoàn tác: Nhấn nút hoàn tác bên dưới thẻ đã điểm danh để xóa lượt và hoàn lại buổi.',
                'Điểm danh hàng loạt: Nhấn nút hàng loạt ở góc trên để điểm danh nhanh tất cả hội viên chưa đến.',
              ],
              es: const [
                'Registrar Check-in: Pulsa [Check-In] en la tarjeta para anotar la asistencia y descontar 1 sesión automáticamente.',
                'Deshacer: Pulsa deshacer debajo de una tarjeta completada para borrar el registro y devolver la sesión.',
                'Check-in masivo: Usa el botón superior para registrar de una vez a todos los alumnos filtrados pendientes.',
              ],
            ),
          ),
          _buildGuideCard(
            icon: Icons.filter_alt_outlined,
            iconColor: const Color(0xFF059669),
            title: LocalizationService.pick(
              ko: '2. KPI 요약 필터 & 잔여 회차 충전',
              en: '2. KPI Filters & Pass Top-Ups',
              ja: '2. KPIフィルター＆残回数チャージ',
              zh: '2. KPI筛选与课时充值',
              vi: '2. Bộ lọc KPI & Nạp thêm buổi',
              es: '2. Filtros KPI y Recarga de Bonos',
            ),
            steps: LocalizationService.pickList(
              ko: const [
                '대시보드 상단 요약 카드(전체 / 오늘 출석 / 미출석 / 만료 임박)를 누르면 해당 상태의 회원만 바로 걸러서 볼 수 있습니다.',
                '회차권 회원의 잔여 회차가 2회 이하(만료 임박)가 되면 [+10회 충전] 버튼이 나타나 1초 만에 회차를 연장할 수 있습니다.',
                '7일 이상 출석 기록이 없는 회원은 [7일+ 미출석 안심 케어] 배너가 표시되며 상황별 안부 톡/문자를 보낼 수 있습니다.',
              ],
              en: const [
                'Tap any KPI card (Total / Attended / Absent / Low Passes) at the top to filter members instantly.',
                'When a session-based member has 2 or fewer sessions left, tap [+10 Sessions] to top up in one tap.',
                'Members inactive for 7+ days appear in the [7-Day Care] banner so you can send a quick check-in message.',
              ],
              ja: const [
                '上部のサマリーカード（全体 / 本日出席 / 未出席 / 期限迫る）をタップすると該当会員のみを瞬時に抽出します。',
                '回数券会員の残回数が2回以下になると［+10回チャージ］ボタンが表示され、1秒で更新できます。',
                '7日以上出席記録がない会員には安心ケアバナーが表示され、状況別のフォロー連絡を送れます。',
              ],
              zh: const [
                '点击顶部汇总卡片（全部 / 今日已到 / 未到 / 即将到期）即可瞬间筛选对应会员。',
                '当次卡会员剩余课时≤2次时，卡片将出现【+10次充值】快捷按钮。',
                '连续7天以上未签到的会员将展示关怀横幅，方便一键发送回访短信。',
              ],
              vi: const [
                'Chạm vào các thẻ KPI (Tổng / Đã đến / Vắng / Sắp hết) để lọc nhanh danh sách hội viên.',
                'Khi gói buổi còn từ 2 buổi trở xuống, nút [+10 buổi] xuất hiện để gia hạn ngay lập tức.',
                'Hội viên nghỉ trên 7 ngày sẽ hiển thị ở mục Chăm sóc 7 ngày để gửi tin nhắn hỏi thăm.',
              ],
              es: const [
                'Pulsa cualquier tarjeta KPI superior (Total / Asistieron / Ausentes / Por vencer) para filtrar al instante.',
                'Cuando un bono tenga 2 sesiones o menos, aparecerá el botón [+10] para recargar en 1 segundo.',
                'Los alumnos sin asistencia en más de 7 días aparecen en el aviso de seguimiento para contactarlos.',
              ],
            ),
          ),
          _buildGuideCard(
            icon: Icons.qr_code_2_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: LocalizationService.pick(
              ko: '3. 안심 알림 · QR 패스 · 캘린더 · 키오스크',
              en: '3. Alerts · QR Pass · Calendar · Kiosk',
              ja: '3. 安心通知・QRパス・カレンダー・キオスク',
              zh: '3. 安心通知 · 二维码通行证 · 日历 · 自助终端',
              vi: '3. Thông báo · Thẻ QR · Lịch · Kiosk',
              es: '3. Avisos · Pase QR · Calendario · Kiosco',
            ),
            steps: LocalizationService.pickList(
              ko: const [
                '등·하원 안심 알림: 출석 완료 후 [등원 안심 알림] / [하원 귀가 알림]으로 카카오톡(0원) 또는 기본 문자 앱(0원) 발송이 가능합니다.',
                '디지털 패스 QR: 회원 카드 우측 QR 아이콘을 누르면 회원에게 공유 가능한 모바일 회원증 이미지를 띄울 수 있습니다.',
                '상단 아이콘 기능: 왼쪽부터 [무인 키오스크], [출결·일정 캘린더(일정 등록·수정·삭제)], [스마트 안심 알림 센터(미발송 브리핑/이력/서식)], [큰글씨 모드]입니다.',
              ],
              en: const [
                'Arrival & Departure Alerts: Send zero-fee arrival or departure messages via SMS or share sheet right after check-in.',
                'Digital QR Pass: Tap the QR icon on a member card to open a shareable mobile membership pass.',
                'Top Bar Icons: Left to right — [Self Check-In Kiosk], [Attendance & Event Calendar], [Smart Notification Center], and [Senior/Large Mode].',
              ],
              ja: const [
                '出欠安心通知：チェックイン後にアプリ共有または標準SMSで到着・帰宅通知を送信できます。',
                'デジタルQRパス：会員カードのQRアイコンから共有可能なモバイル会員証を表示できます。',
                '上部アイコン：左から［無人キオスク］［出欠・予定カレンダー］［スマート通知センター］［大きな文字モード］です。',
              ],
              zh: const [
                '到离店安心通知：签到后可通过系统短信或分享功能免费向家长/会员发送到达或离开通知。',
                '数字二维码会员卡：点击会员卡右侧二维码图标即可展示并分享电子会员卡。',
                '顶部图标依次为：[自助签到终端]、[考勤日程日历]、[智能通知中心]、[大字关怀模式]。',
              ],
              vi: const [
                'Thông báo đến/về: Gửi tin nhắn xác nhận qua SMS hoặc ứng dụng chia sẻ ngay sau khi điểm danh.',
                'Thẻ QR điện tử: Nhấn biểu tượng QR trên thẻ hội viên để mở và chia sẻ thẻ thành viên.',
                'Thanh biểu tượng trên cùng: [Kiosk tự check-in], [Lịch & Sự kiện], [Trung tâm thông báo], [Chế độ chữ lớn].',
              ],
              es: const [
                'Avisos de llegada/salida: Envía alertas gratuitas por SMS o app tras cada check-in.',
                'Pase Digital QR: Pulsa el icono QR en la tarjeta para mostrar y compartir el carné móvil.',
                'Iconos superiores: [Kiosco autónomo], [Calendario de asistencia y eventos], [Centro de avisos] y [Modo lectura fácil].',
              ],
            ),
          ),
        ];

      case 1:
        return [
          _buildGuideCard(
            icon: Icons.add_card_rounded,
            iconColor: AppTheme.primaryBlue,
            title: LocalizationService.pick(
              ko: '1. 청구서 발행(단일 & 형제/가족 묶음)',
              en: '1. Issue Invoices (Single & Family Bundle)',
              ja: '1. 請求書発行（個別・兄弟/家族まとめ）',
              zh: '1. 开具账单（个人与家庭合并账单）',
              vi: '1. Phát hành hóa đơn (Đơn lẻ & Gia đình)',
              es: '1. Emitir Facturas (Individual y Familiar)',
            ),
            steps: LocalizationService.pickList(
              ko: [
                '등록: 우측 하단 [+ ${profile.feeTitle} 청구서] 버튼을 눌러 대상 회원을 선택하고 항목·금액·납부기한을 입력해 발행합니다.',
                '형제 묶음 청구: 연락처(보호자 번호)가 같은 여러 회원을 함께 선택하면 합산 금액으로 한 번에 청구서를 만들 수 있습니다.',
                '조회/검색: 상단 상태 필터(전체/미납/완납)와 이름·연락처 검색으로 청구 내역을 빠르게 확인합니다.',
              ],
              en: [
                'Create: Tap [+ ${profile.feeTitle}] at the bottom right, pick members, set amount & due date, and issue.',
                'Family Bundle: Select multiple members sharing a guardian phone to generate a combined invoice automatically.',
                'Filter & Search: Filter by All / Unpaid / Paid or search by member name or phone number.',
              ],
              ja: [
                '作成：右下の［+ ${profile.feeTitle}］ボタンから対象会員・項目・金額・期限を入力して発行します。',
                '兄弟まとめ請求：連絡先が同じ複数会員をまとめて選択すると合算請求書を一度に作成できます。',
                '絞り込み・検索：ステータス（すべて/未納/領収済）と名前・電話番号検索ですぐに照会できます。',
              ],
              zh: [
                '开具账单：点击右下角【+ ${profile.feeTitle}】按钮选择会员、收费项、金额和截止日期即可生成。',
                '家庭合并账单：同时勾选同一联系电话下的多位学员，系统自动合并计算总金额。',
                '筛选与搜索：通过顶部状态（全部/未付/已结清）及姓名电话快速检索。',
              ],
              vi: [
                'Tạo hóa đơn: Nhấn [+ ${profile.feeTitle}] ở góc dưới phải, chọn hội viên, nhập số tiền và hạn thanh toán.',
                'Gộp gia đình: Chọn nhiều hội viên cùng SĐT người giám hộ để tạo hóa đơn gộp một lần.',
                'Lọc & Tìm kiếm: Lọc theo Tất cả / Chưa thu / Đã thu hoặc tìm theo tên và SĐT.',
              ],
              es: [
                'Crear: Pulsa [+ ${profile.feeTitle}] abajo a la derecha, elige miembros, importe y vencimiento.',
                'Factura familiar: Selecciona varios alumnos con el mismo teléfono de contacto para agrupar el cobro.',
                'Filtrar y buscar: Filtra por Todos / Impagos / Pagados o busca por nombre y teléfono.',
              ],
            ),
          ),
          _buildGuideCard(
            icon: Icons.edit_note_rounded,
            iconColor: const Color(0xFFD97706),
            title: LocalizationService.pick(
              ko: '2. 청구서 수정 · 삭제 · 완납 처리 · 수납 취소',
              en: '2. Edit · Delete · Mark Paid · Revert',
              ja: '2. 請求書の編集・削除・入金消込・取消',
              zh: '2. 账单修改 · 删除 · 核销入账 · 撤回未付',
              vi: '2. Sửa · Xóa · Xác nhận thu · Hoàn tác',
              es: '2. Editar · Eliminar · Cobrar · Revertir',
            ),
            steps: LocalizationService.pickList(
              ko: const [
                '청구서 수정/삭제: 각 청구서 카드 우측 상단의 [⋮] 버튼을 누르면 금액·항목·기한·연락처 수정 또는 청구서 삭제를 할 수 있습니다.',
                '수납 완료 처리: 미납 카드의 [수납 확인 완료]를 눌러 계좌이체/현금/카드 결제를 기록하면 완납 상태로 전환됩니다.',
                '수납 취소(미납 전환): 완납된 카드 우측 상단 [⋮] → [수납 취소 (미납 전환)]으로 실수 처리한 건을 되돌릴 수 있습니다.',
              ],
              en: const [
                'Edit / Delete: Tap [⋮] on any invoice card to edit amount, items, due date, phone, or delete it.',
                'Mark Paid: Tap [Mark Paid] on an unpaid invoice and record Transfer / Cash / Card payment.',
                'Revert Payment: On paid cards, tap [⋮] → [Revert to Unpaid] to undo accidental confirmations.',
              ],
              ja: const [
                '編集・削除：請求書カード右上の［⋮］から金額・項目・期限・連絡先の編集や削除ができます。',
                '入金完了処理：未納カードの［入金確認完了］を押し、振込・現金・カードなどの支払方法を記録します。',
                '入金取消（未納へ戻す）：領収済カード右上の［⋮］→［未納に戻す］で誤操作を取り消せます。',
              ],
              zh: const [
                '修改与删除：点击账单卡片右上角【⋮】，可修改金额、名目、日期或删除账单。',
                '确认收款：在未付卡片点击【确认收款】，选择转账/现金/刷卡等方式后转为已结清。',
                '撤回入账：若误核销，可在已收款卡片右上角【⋮】中点击撤回为未付状态。',
              ],
              vi: const [
                'Sửa / Xóa: Nhấn [⋮] ở góc phải thẻ hóa đơn để sửa số tiền, hạn nộp, SĐT hoặc xóa.',
                'Xác nhận thu: Nhấn [Xác nhận đã thu] trên thẻ chưa thu để ghi nhận chuyển khoản/tiền mặt/thẻ.',
                'Hoàn tác thu: Trên thẻ đã thu, nhấn [⋮] → [Hoàn tác về chưa thu] nếu xác nhận nhầm.',
              ],
              es: const [
                'Editar / Eliminar: Pulsa [⋮] en cada factura para editar importe, vencimiento, contacto o borrarla.',
                'Marcar pagada: Pulsa [Confirmar cobro] y registra transferencia, efectivo o tarjeta.',
                'Revertir cobro: En facturas pagadas, usa [⋮] → [Volver a impago] para corregir errores.',
              ],
            ),
          ),
          _buildGuideCard(
            icon: Icons.send_to_mobile_rounded,
            iconColor: const Color(0xFF059669),
            title: LocalizationService.pick(
              ko: '3. 0원 청구 발송 · 입금 감지 · 장부 CSV',
              en: '3. Billing Messages · Bank Alert Match · CSV',
              ja: '3. 請求送信・入金検知・帳簿CSV出力',
              zh: '3. 零费发送账单 · 入账识别 · CSV账本导出',
              vi: '3. Gửi hóa đơn · Đối soát ngân hàng · Xuất CSV',
              es: '3. Envío de Cobros · Alertas Bancarias · CSV',
            ),
            steps: supportsToss
                ? LocalizationService.pickList(
                    ko: const [
                      '카톡/SMS 청구 & 리마인드: 입금 계좌번호, 토스 송금 링크, (설정 시) 비대면 카드결제 링크가 자동 포함된 문자를 비용 0원으로 전송합니다.',
                      '은행 입금 푸시 감지: 안드로이드에서 은행 입금 알림 문구를 붙여넣기/감지하면 일치하는 미납 청구서를 찾아 원클릭 완납 처리합니다.',
                      '수납 장부 엑셀 내보내기: 상단 다운로드 아이콘을 누르면 전체 수납 내역이 UTF-8 엑셀(CSV) 파일로 생성됩니다.',
                    ],
                    en: const [
                      'Messaging & SMS Billing: Sends payout details and your optional remote card payment link with zero platform cost.',
                      'Bank Alert Matching: Paste or detect incoming bank deposit notifications to match unpaid invoices and mark them paid in one tap.',
                      'CSV Ledger Export: Tap the download icon at the top to export all revenue records as a UTF-8 CSV spreadsheet.',
                    ],
                    ja: const [
                      'メッセンジャー/SMS請求：振込口座やオンラインカード決済リンク入りの案内を追加料金0円で送信できます。',
                      '銀行入金通知照合：銀行からの入金通知文面を検知・貼付すると該当の未納請求書を自動照合します。',
                      '売上CSV出力：上部のダウンロードアイコンからUTF-8対応のCSVファイルを書き出せます。',
                    ],
                    zh: const [
                      '零平台费发单：自动附带收款账户和（若已配置）远程刷卡链接，通过社交软件或手机短信发送。',
                      '银行入账推送识别：粘贴或自动识别银行入账通知文本，一键匹配未结账单并核销。',
                      '账本CSV导出：点击顶部下载按钮即可生成兼容 Excel 的 UTF-8 CSV 账单报表。',
                    ],
                    vi: const [
                      'Gửi hóa đơn SMS/Chia sẻ: Tự động kèm thông tin tài khoản và link thanh toán thẻ từ xa với 0 phí nền tảng.',
                      'Khớp thông báo ngân hàng: Dán hoặc đọc thông báo tiền vào để khớp và xác nhận hóa đơn chưa thu.',
                      'Xuất sổ thu CSV: Nhấn nút tải xuống ở trên để xuất toàn bộ giao dịch ra file CSV UTF-8.',
                    ],
                    es: const [
                      'Envío de cobros: Incluye datos bancarios y enlace de pago con tarjeta opcional sin comisiones extra.',
                      'Detección bancaria: Pega o detecta avisos de transferencia recibida para conciliar facturas pendientes.',
                      'Exportar CSV: Pulsa descargar arriba para generar una hoja CSV UTF-8 compatible con Excel.',
                    ],
                  )
                : LocalizationService.pickList(
                    ko: const [
                      '카톡/SMS 청구 & 리마인드: 입금 계좌정보와 (설정 시) 비대면 카드결제 링크가 자동 포함된 안내 문자를 전송합니다.',
                      '은행 입금 푸시 감지: 은행 입금 알림 문구를 붙여넣기/감지하면 일치하는 미납 청구서를 찾아 원클릭 완납 처리합니다.',
                      '수납 장부 엑셀 내보내기: 상단 다운로드 아이콘을 누르면 전체 수납 내역이 UTF-8 엑셀(CSV) 파일로 생성됩니다.',
                    ],
                    en: const [
                      'Messaging & SMS Billing: Sends payout details and your optional remote card payment link with zero platform cost.',
                      'Bank Alert Matching: Paste or detect incoming bank deposit notifications to match unpaid invoices and mark them paid in one tap.',
                      'CSV Ledger Export: Tap the download icon at the top to export all revenue records as a UTF-8 CSV spreadsheet.',
                    ],
                    ja: const [
                      'メッセンジャー/SMS請求：振込口座やオンラインカード決済リンク入りの案内を追加料金0円で送信できます。',
                      '銀行入金通知照合：銀行からの入金通知文面を検知・貼付すると該当の未納請求書を自動照合します。',
                      '売上CSV出力：上部のダウンロードアイコンからUTF-8対応のCSVファイルを書き出せます。',
                    ],
                    zh: const [
                      '零平台费发单：自动附带收款账户和（若已配置）远程刷卡链接，通过社交软件或手机短信发送。',
                      '银行入账推送识别：粘贴或自动识别银行入账通知文本，一键匹配未结账单并核销。',
                      '账本CSV导出：点击顶部下载按钮即可生成兼容 Excel 的 UTF-8 CSV 账单报表。',
                    ],
                    vi: const [
                      'Gửi hóa đơn SMS/Chia sẻ: Tự động kèm thông tin tài khoản và link thanh toán thẻ từ xa với 0 phí nền tảng.',
                      'Khớp thông báo ngân hàng: Dán hoặc đọc thông báo tiền vào để khớp và xác nhận hóa đơn chưa thu.',
                      'Xuất sổ thu CSV: Nhấn nút tải xuống ở trên để xuất toàn bộ giao dịch ra file CSV UTF-8.',
                    ],
                    es: const [
                      'Envío de cobros: Incluye datos bancarios y enlace de pago con tarjeta opcional sin comisiones extra.',
                      'Detección bancaria: Pega o detecta avisos de transferencia recibida para conciliar facturas pendientes.',
                      'Exportar CSV: Pulsa descargar arriba para generar una hoja CSV UTF-8 compatible con Excel.',
                    ],
                  ),
          ),
        ];

      case 2:
        return [
          _buildGuideCard(
            icon: Icons.receipt_outlined,
            iconColor: const Color(0xFFE11D48),
            title: LocalizationService.pick(
              ko: '1. 지출·매입 장부 등록 · 수정 · 삭제',
              en: '1. Log · Edit · Delete Expenses',
              ja: '1. 支出・仕入帳簿の登録・編集・削除',
              zh: '1. 支出与采购台账增删改',
              vi: '1. Ghi nhận · Sửa · Xóa Chi phí',
              es: '1. Registrar · Editar · Borrar Gastos',
            ),
            steps: LocalizationService.pickList(
              ko: [
                '지출 등록: 우측 하단 [+ 지출/매입 등록]에서 임대료·교재비·소모품·강사료 등 지출 내역과 결제수단, 세무증빙 유형을 등록합니다.',
                '수정/삭제/지급토글: 등록된 지출 카드의 수정·삭제 아이콘으로 내역을 변경/삭제하고, 미지급/지급완료 상태를 원터치로 전환할 수 있습니다.',
                '3.3% 원천징수 자동 계산: 강사료/프리랜서 비용 등록 시 [3.3% 원천징수 적용]을 켜면 세액과 실지급액이 자동 계산되며 정산 명세서 문자를 보낼 수 있습니다.',
              ],
              en: [
                'Log Expense: Tap [+ Expense] at the bottom right to record rent, supplies, payroll, payment method, and tax receipt type.',
                'Edit / Delete / Status: Use the card actions to edit, delete, or toggle Unpaid/Paid status with one tap.',
                'Auto Withholding ($withholdingPct): Enable tax withholding on instructor/contractor payouts to auto-compute net pay and send settlement notices.',
              ],
              ja: [
                '支出登録：右下の［+ 支出登録］から家賃・教材費・講師報酬などの明細、支払方法、証憑区分を登録します。',
                '編集・削除・支払切替：カードのアイコンから編集・削除・未払/支払済の切り替えが可能です。',
                '源泉徴収（$withholdingPct）自動計算：講師報酬等で源泉徴収をオンにすると税額と手取額を自動計算し、明細通知も送れます。',
              ],
              zh: [
                '记录支出：点击右下角【+ 记一笔支出】，录入房租、教材、耗材、课时费及支付方式和税务凭证。',
                '修改与状态切换：可随时编辑/删除记录，并一键切换待付款与已付款状态。',
                '代扣代缴自动计算（$withholdingPct）：在登记讲师或自由职业者报酬时开启，即可自动核算税额与实发金额并发送明细。',
              ],
              vi: [
                'Ghi chi phí: Nhấn [+ Chi phí] để nhập tiền thuê, tài liệu, lương giáo viên, phương thức thanh toán và chứng từ.',
                'Sửa / Xóa / Trạng thái: Chỉnh sửa, xóa hoặc chuyển trạng thái Chưa trả / Đã trả chỉ với 1 chạm.',
                'Tự tính khấu trừ thuế ($withholdingPct): Bật khi chi trả thù lao giảng viên để tự động tính thuế và số thực nhận.',
              ],
              es: [
                'Registrar gasto: Pulsa [+ Gasto] abajo para anotar alquiler, material, honorarios, método de pago y justificante.',
                'Editar / Estado: Modifica, borra o alterna entre Pendiente y Pagado con un toque.',
                'Retención automática ($withholdingPct): Actívala en pagos a profesores para calcular retención y neto automáticamente.',
              ],
            ),
          ),
          _buildGuideCard(
            icon: Icons.store_mall_directory_outlined,
            iconColor: AppTheme.primaryBlue,
            title: LocalizationService.pick(
              ko: '2. 거래처 장부 & 계좌 관리',
              en: '2. Vendors & Payout Accounts',
              ja: '2. 取引先リスト＆口座管理',
              zh: '2. 供应商名录与账户管理',
              vi: '2. Quản lý Nhà cung cấp & Tài khoản',
              es: '2. Proveedores y Cuentas',
            ),
            steps: LocalizationService.pickList(
              ko: const [
                '거래처 등록/수정/삭제: 상단 [거래처 관리]에서 자주 거래하는 교재사·관리사무소·강사 연락처와 입금 계좌를 등록·수정·삭제합니다.',
                '지출 내역 입력 시 등록된 거래처를 바로 불러와 매입처를 빠르게 연결할 수 있습니다.',
              ],
              en: const [
                'Vendor Directory: Add, edit, or delete frequent publishers, landlords, or freelance instructors along with their bank details under [Vendors].',
                'Link a saved vendor directly when logging a new expense for faster entry.',
              ],
              ja: const [
                '取引先の登録・編集・削除：上部の［取引先管理］でよく使う業者や講師の連絡先・振込口座を管理できます。',
                '支出入力時に保存済みの取引先をワンタップで呼び出せます。',
              ],
              zh: const [
                '供应商增删改：在顶部【供应商管理】维护常用教材商、物业及讲师联系方式与收款账号。',
                '登记支出时可直接关联已保存的供应商，无需重复输入。',
              ],
              vi: const [
                'Danh bạ nhà cung cấp: Thêm, sửa, xóa thông tin liên hệ và tài khoản của đối tác hoặc giảng viên.',
                'Chọn nhanh nhà cung cấp đã lưu khi ghi nhận chi phí mới.',
              ],
              es: const [
                'Directorio de proveedores: Gestiona contactos y cuentas bancarias de editoriales, arrendadores o profesores.',
                'Selecciona un proveedor guardado al anotar gastos para agilizar el registro.',
              ],
            ),
          ),
          _buildGuideCard(
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF059669),
            title: LocalizationService.pick(
              ko: '3. 국세청 표준 간편장부 & 세무 가이드',
              en: '3. Tax Bookkeeping Ledger & Filing Guide',
              ja: '3. 簡易帳簿CSV出力＆税務申告ガイド',
              zh: '3. 标准收支简易账本与报税指南',
              vi: '3. Sổ kế toán CSV & Hướng dẫn Thuế',
              es: '3. Libro Contable CSV y Guía Fiscal',
            ),
            steps: LocalizationService.currentCurrency == AppCurrency.krw
                ? LocalizationService.pickList(
                    ko: const [
                      '국세청 표준 사업소득 간편장부 CSV: 완납된 매출(수입)과 지출(비용), 증빙 유형, 3.3% 원천징수 내역을 날짜순으로 통합한 세무사 제출용 엑셀 파일을 1초 만에 추출합니다.',
                      '상단 세무 가이드에서 종합소득세(5월), 부가세/사업장현황신고(2월), 원천세(매월 10일) 신고 일정과 홈택스 바로가기를 확인할 수 있습니다.',
                    ],
                    en: const [
                      'Simplified Tax Ledger CSV: Export a unified chronological CSV of paid revenue, expenses, receipt types, and 3.3% withholding for your accountant in 1 tap.',
                      'Regional Tax Guide: Review local filing schedules (Income Tax, VAT/Status Filing, Withholding Tax) and quick tax portal shortcuts.',
                    ],
                    ja: const [
                      '簡易帳簿CSV出力：入金済売上・経費・証憑区分・源泉徴収明細を日付順に統合した税理士提出用CSVをワンタップ出力します。',
                      '税務ガイド：各地域の申告スケジュールと税務ポータルへのショートカットを確認できます。',
                    ],
                    zh: const [
                      '标准收支简易账本CSV：一键导出按日期排序的实收、支出、凭证类型及代扣税明细分表，直接交付会计师。',
                      '税务指南：查看适用地区的申报周期节点及官方税务申报入口。',
                    ],
                    vi: const [
                      'Xuất sổ kế toán CSV: Kết xuất file CSV tổng hợp doanh thu đã thu, chi phí, chứng từ và thuế khấu trừ theo ngày.',
                      'Hướng dẫn thuế: Xem lịch kê khai thuế theo quốc gia và quy tắc chứng từ khấu trừ.',
                    ],
                    es: const [
                      'Libro contable CSV: Exporta un archivo cronológico con ingresos cobrados, gastos, justificantes y retenciones.',
                      'Guía fiscal regional: Consulta calendarios de declaración y portales oficiales según tu moneda/región.',
                    ],
                  )
                : LocalizationService.pickList(
                    ko: [
                      '세무 신고용 간편장부 CSV: 완납된 매출(수입)과 지출(비용), 증빙 유형, 원천징수($withholdingPct) 내역을 날짜순으로 통합한 회계·세무 제출용 CSV 파일을 1초 만에 추출합니다.',
                      '상단 세무 가이드에서 선택하신 통화·국가 기준의 확정신고 일정과 경비 증빙 가이드를 확인할 수 있습니다.',
                    ],
                    en: [
                      'Tax Bookkeeping CSV: Export a unified chronological CSV of paid revenue, expenses, receipt types, and $withholdingPct withholding for your accountant in 1 tap.',
                      'Country Tax Guide: View localized filing calendars, deduction rules, and official tax authority guidance for your selected region.',
                    ],
                    ja: [
                      '確定申告用CSV帳簿：入金済売上・経費・証憑区分・源泉徴収（$withholdingPct）を日付順に統合したCSVを1秒で出力します。',
                      '税務ガイド：選択中の通貨・国に応じた申告期限と経費処理ポイントを確認できます。',
                    ],
                    zh: [
                      '税务账本CSV导出：一键生成按日期汇总的已收款、支出、凭证与代扣税（$withholdingPct）财务报表。',
                      '本地税务指南：根据当前所选国家/币种查看对应的报税时间表与合规抵扣说明。',
                    ],
                    vi: [
                      'Xuất sổ thuế CSV: Tạo file CSV tổng hợp doanh thu, chi phí, chứng từ và khấu trừ ($withholdingPct) chỉ với 1 chạm.',
                      'Hướng dẫn thuế khu vực: Xem lịch kê khai và quy tắc khấu trừ phù hợp với quốc gia/tiền tệ đã chọn.',
                    ],
                    es: [
                      'Libro contable CSV: Exporta en 1 toque el historial cronológico de ingresos, gastos, recibos y retenciones ($withholdingPct).',
                      'Guía fiscal local: Consulta calendarios y normas fiscales adaptadas al país o moneda seleccionada.',
                    ],
                  ),
          ),
        ];

      case 3:
        return [
          _buildGuideCard(
            icon: Icons.person_add_alt_1_outlined,
            iconColor: AppTheme.primaryBlue,
            title: LocalizationService.pick(
              ko: '1. 회원 등록 · 사진 · 업종 간편 템플릿',
              en: '1. Register Members · Photos · Quick Presets',
              ja: '1. 会員登録・顔写真・業種別テンプレート',
              zh: '1. 登记会员 · 头像 · 行业快捷套餐模板',
              vi: '1. Thêm Hội viên · Ảnh · Mẫu nhanh',
              es: '1. Alta de Miembros · Foto · Plantillas',
            ),
            steps: LocalizationService.pickList(
              ko: const [
                '신규 등록: 우측 하단 [+ 회원 등록]을 눌러 이름, 입금자(학부모) 성함, 연락처, 수업/그룹, 회차권 또는 정기권을 입력합니다.',
                '초간편 템플릿 & 그룹 추가: 업종별 간편 템플릿 칩을 누르면 수강료와 회차가 자동 입력되며, [+ 새 그룹 추가]로 맞춤 반 이름을 만들 수 있습니다.',
                '프로필 사진: 카메라/갤러리로 사진을 등록하면 무인 키오스크 출석 시 회원 얼굴이 화면에 표시됩니다.',
              ],
              en: const [
                'Add Member: Tap [+ Add Member] at the bottom right to enter name, payer/guardian name, phone, class/group, and pass or monthly plan.',
                'Quick Presets & Custom Groups: Tap an industry preset chip to auto-fill tuition and sessions, or tap [+ New Group] to create custom classes.',
                'Profile Photo: Attach a camera or gallery photo so the member\'s avatar appears at Self Check-In Kiosk.',
              ],
              ja: const [
                '新規登録：右下の［+ 会員登録］から氏名・保護者/振込名・連絡先・クラス・回数券/月謝を登録します。',
                'テンプレート＆グループ追加：業種テンプレートを押すと金額と回数が自動入力され、［+ 新規グループ］で独自クラスも作成できます。',
                'プロフィール写真：カメラやギャラリーから写真を登録するとキオスク受付画面に表示されます。',
              ],
              zh: const [
                '新增会员：点击右下角【+ 新增会员】，填写姓名、付款人/家长、电话、班级及次卡或月卡套餐。',
                '快捷模板与分组：点击行业套餐标签自动填充金额与次数，还可自定义新增分组班级。',
                '头像照片：支持拍照或相册上传，自助终端签到时将显示会员头像。',
              ],
              vi: const [
                'Đăng ký mới: Nhấn [+ Thêm hội viên] để nhập tên, người thanh toán/phụ huynh, SĐT, lớp và gói học.',
                'Mẫu nhanh & Nhóm tùy chỉnh: Chọn chip mẫu để tự điền học phí và số buổi, hoặc tạo tên lớp mới.',
                'Ảnh đại diện: Thêm ảnh từ camera hoặc thư viện để hiển thị khi hội viên check-in trên Kiosk.',
              ],
              es: const [
                'Nuevo miembro: Pulsa [+ Nuevo] abajo a la derecha para registrar nombre, pagador/tutor, teléfono, grupo y tarifa.',
                'Plantillas rápidas y grupos: Pulsa un chip para autorrellenar cuota y sesiones o añade tus propios grupos.',
                'Foto de perfil: Sube una foto para mostrar el avatar del alumno al fichar en el Kiosco.',
              ],
            ),
          ),
          _buildGuideCard(
            icon: Icons.manage_accounts_outlined,
            iconColor: const Color(0xFFD97706),
            title: LocalizationService.pick(
              ko: '2. 회원 정보 수정 · 삭제 · 회차 충전 · 이력 관리',
              en: '2. Edit · Delete · Top Up · History',
              ja: '2. 会員情報の編集・削除・チャージ・履歴管理',
              zh: '2. 修改 · 删除 · 充次 · 历史记录管理',
              vi: '2. Sửa · Xóa · Nạp buổi · Lịch sử',
              es: '2. Editar · Borrar · Recargar · Historial',
            ),
            steps: LocalizationService.pickList(
              ko: const [
                '정보 수정: 회원 카드를 터치해 상세 창을 연 뒤 우측 상단 연필(✏️) 아이콘을 누르면 이름, 연락처, 입금자명, 그룹, 수강료, 잔여 회차, 메모를 모두 수정할 수 있습니다.',
                '회원 삭제: 상세 창 우측 상단 휴지통(🗑️) 아이콘을 누르면 확인 후 회원과 해당 출석 기록을 안전하게 삭제합니다.',
                '타임라인 & 즉시 처리: 상세 창에서 [+10회 충전], [청구서 즉시 발송], [출석 기록 타임라인(개별 출석 취소 가능)], [수납 내역 로그]를 한곳에서 처리합니다.',
              ],
              en: const [
                'Edit Info: Tap any member card to open details, then tap the pencil (✏️) icon to update name, phone, payer, group, fee, passes, or notes.',
                'Delete Member: Tap the trash (🗑️) icon inside member details to safely remove the member and their attendance records.',
                'Timeline & Actions: Top up passes (+10), issue an instant invoice, review/undo attendance timeline, and inspect payment logs in one view.',
              ],
              ja: const [
                '情報編集：会員カードを開き右上の鉛筆アイコン（✏️）から氏名・電話・名義・クラス・金額・残回数・メモをすべて編集できます。',
                '会員削除：詳細画面右上のゴミ箱（🗑️）から会員と出席履歴を安全に削除できます。',
                'タイムライン・即時操作：［+10回チャージ］［即時請求］［出席履歴（個別取消可）］［入金履歴］を一画面で管理できます。',
              ],
              zh: const [
                '修改资料：点击会员卡片打开详情页，点击右上角铅笔图标（✏️）即可编辑全部资料、课次与备注。',
                '删除会员：点击详情页右上角垃圾桶图标（🗑️）确认后可安全删除该会员及考勤记录。',
                '时间线与快捷操作：在同一详情页可【+10次充次】、【立即发单】、查看/撤销单条考勤及核查缴费历史。',
              ],
              vi: const [
                'Sửa thông tin: Chạm thẻ hội viên rồi nhấn biểu tượng bút chì (✏️) ở góc trên để sửa mọi thông tin và số buổi.',
                'Xóa hội viên: Nhấn biểu tượng thùng rác (🗑️) ở góc trên màn chi tiết để xóa an toàn hội viên và lịch sử điểm danh.',
                'Dòng thời gian: Nạp nhanh +10 buổi, phát hành hóa đơn ngay, xem/hủy từng lượt điểm danh và lịch sử thu tiền.',
              ],
              es: const [
                'Editar datos: Abre la ficha y pulsa el lápiz (✏️) para modificar nombre, teléfono, grupo, cuota, sesiones o notas.',
                'Eliminar: Pulsa la papelera (🗑️) en la ficha para borrar de forma segura el perfil y sus registros.',
                'Historial y acciones: Recarga +10 sesiones, factura al instante y revisa o anula asistencias y cobros.',
              ],
            ),
          ),
          _buildGuideCard(
            icon: Icons.campaign_outlined,
            iconColor: const Color(0xFF059669),
            title: LocalizationService.pick(
              ko: '3. 초성 검색 · 순차 릴레이 발송 · 명부 CSV',
              en: '3. Smart Search · Sequential Dispatch · CSV',
              ja: '3. 高速検索・順次リレー一斉送信・名簿CSV',
              zh: '3. 智能检索 · 逐一批量发送 · 名册CSV',
              vi: '3. Tìm kiếm nhanh · Gửi lần lượt · Xuất CSV',
              es: '3. Búsqueda Rápida · Envío Secuencial · CSV',
            ),
            steps: LocalizationService.pickList(
              ko: const [
                '초성 검색: 검색창에 이름 전체뿐 아니라 초성(예: ㄱㄷㅎ)이나 전화번호 뒷자리를 입력해도 즉시 검색됩니다.',
                '순차 릴레이 단체 발송: 상단 메시지 아이콘 또는 [릴레이 발송]을 누르면 현재 검색/그룹 필터된 회원들에게 공지·안내 문자를 한 명씩 끊김 없이 순차 전송할 수 있습니다.',
                '명부 엑셀(CSV): 상단 다운로드 아이콘으로 전체 회원 명부를 엑셀 파일로 추출합니다.',
              ],
              en: const [
                'Instant Search: Search by full/partial name, phone digits, or class group in real time.',
                'Sequential Relay Dispatch: Tap the message icon to walk through selected/filtered members one-by-one via messenger or SMS.',
                'Directory CSV Export: Tap the download icon at the top to export your full member roster to CSV.',
              ],
              ja: const [
                '即時検索：氏名や電話番号の下4桁、クラス名で素早く絞り込みできます。',
                '順次リレー送信：上部メッセージアイコンから、抽出中の会員へ順番に案内メッセージを送れます。',
                '名簿CSV出力：ダウンロードボタンから全会員リストをCSV形式でエクスポートできます。',
              ],
              zh: const [
                '极速检索：支持姓名关键词、首字母及电话尾号实时搜索匹配。',
                '逐一队列群发：点击顶部消息图标，即可按当前筛选人群逐个发送定制通知，无缝衔接。',
                '名册CSV导出：点击顶部下载图标可将全部会员花名册导出为 CSV 表格。',
              ],
              vi: const [
                'Tìm kiếm tức thì: Tìm theo tên, số điện thoại cuối hoặc nhóm lớp theo thời gian thực.',
                'Gửi lần lượt thông minh: Nhấn biểu tượng tin nhắn để gửi thông báo lần lượt cho nhóm hội viên đã lọc.',
                'Xuất danh bạ CSV: Nhấn nút tải xuống để xuất toàn bộ danh sách hội viên ra file CSV.',
              ],
              es: const [
                'Búsqueda rápida: Filtra en tiempo real por nombre, dígitos de teléfono o grupo.',
                'Envío secuencial: Pulsa el icono de mensajes para enviar avisos personalizados uno a uno sin bloqueos.',
                'Exportar directorio CSV: Descarga toda la lista de miembros en formato CSV.',
              ],
            ),
          ),
        ];

      case 4:
      default:
        return [
          _buildGuideCard(
            icon: Icons.business_outlined,
            iconColor: AppTheme.primaryBlue,
            title: LocalizationService.pick(
              ko: '1. 내 스튜디오 · 계좌 · 문자 서식 · 맞춤 용어',
              en: '1. Studio · Payout Account · Templates · Terms',
              ja: '1. スタジオ設定・口座・書式・用語カスタマイズ',
              zh: '1. 机构资料 · 收款账户 · 模板 · 自定义称呼',
              vi: '1. Cơ sở · Tài khoản · Mẫu tin · Thuật ngữ',
              es: '1. Estudio · Cuenta · Plantillas · Términos',
            ),
            steps: supportsToss
                ? LocalizationService.pickList(
                    ko: const [
                      '기본 정보: 상단 프로필 카드를 눌러 스튜디오 상호, 대표자명, 로고 사진, 업종, 입금 계좌번호를 설정하면 모든 청구서와 알림장에 즉시 반영됩니다.',
                      '맞춤 용어 & 다국어: 원생/회원/수강생, 수강료/회비/레슨비 등 매장 호칭과 언어/통화를 자유롭게 변경할 수 있습니다.',
                      '문자 템플릿 & 비대면 카드결제: 등원/하원/청구 문자 문구를 원하는 어투로 편집하고, 토스/카드결제 링크를 연동할 수 있습니다.',
                    ],
                    en: const [
                      'Profile & Payout: Set your studio name, manager, logo, industry, and payout bank details to populate all invoices & notices.',
                      'Custom Terms & Languages: Customize terminology (Student/Member/Client, Tuition/Dues) and switch between 6 languages & 10 currencies.',
                      'Templates & Remote Card Pay: Tailor check-in, check-out, and billing templates, and connect your remote card payment link.',
                    ],
                    ja: const [
                      '基本情報：スタジオ名・担当者・ロゴ・業種・振込口座を設定すると、すべての請求書と通知に即時反映されます。',
                      '用語カスタマイズ＆多言語：会員呼称や料金名称、6言語・10通貨を自由に切り替えられます。',
                      'テンプレート＆オンライン決済：出欠・請求文面を編集し、カード決済リンクを連携できます。',
                    ],
                    zh: const [
                      '基本资料：填写机构名称、负责人、Logo、行业类型与收款账户，所有账单和通知立即同步更新。',
                      '自定义称呼与多语言：可修改会员/学费等称呼，并自由切换6种语言及10种国家货币与税务规则。',
                      '文案模板与远程刷卡：自由编辑到离店/催缴话术，并绑定在线刷卡收款链接。',
                    ],
                    vi: const [
                      'Thông tin cơ bản: Thiết lập tên cơ sở, người quản lý, logo, ngành nghề và tài khoản ngân hàng cho toàn bộ hóa đơn.',
                      'Thuật ngữ & Đa ngôn ngữ: Tùy biến cách xưng hô (Học viên/Hội viên, Học phí/Phí) và chuyển 6 ngôn ngữ, 10 tiền tệ.',
                      'Mẫu tin nhắn & Link thẻ: Chỉnh sửa nội dung thông báo và gắn link thanh toán thẻ từ xa.',
                    ],
                    es: const [
                      'Perfil y cobros: Configura nombre, responsable, logotipo, sector y cuenta bancaria para tus facturas y avisos.',
                      'Términos e idiomas: Personaliza etiquetas (Alumno/Socio, Cuota) y cambia entre 6 idiomas y 10 divisas.',
                      'Plantillas y tarjeta: Edita textos de avisos e integra tu enlace de cobro con tarjeta.',
                    ],
                  )
                : LocalizationService.pickList(
                    ko: const [
                      '기본 정보: 상단 프로필 카드를 눌러 스튜디오 상호, 대표자명, 로고 사진, 업종, 입금 계좌번호를 설정하면 모든 청구서와 알림장에 즉시 반영됩니다.',
                      '맞춤 용어 & 다국어: 원생/회원/수강생, 수강료/회비/레슨비 등 매장 호칭과 언어/통화를 자유롭게 변경할 수 있습니다.',
                      '문자 템플릿 & 비대면 카드결제: 등원/하원/청구 문자 문구를 원하는 어투로 편집하고, 원격 카드결제 링크를 연동할 수 있습니다.',
                    ],
                    en: const [
                      'Profile & Payout: Set your studio name, manager, logo, industry, and payout bank details to populate all invoices & notices.',
                      'Custom Terms & Languages: Customize terminology (Student/Member/Client, Tuition/Dues) and switch between 6 languages & 10 currencies.',
                      'Templates & Remote Card Pay: Tailor check-in, check-out, and billing templates, and connect your remote card payment link.',
                    ],
                    ja: const [
                      '基本情報：スタジオ名・担当者・ロゴ・業種・振込口座を設定すると、すべての請求書と通知に即時反映されます。',
                      '用語カスタマイズ＆多言語：会員呼称や料金名称、6言語・10通貨を自由に切り替えられます。',
                      'テンプレート＆オンライン決済：出欠・請求文面を編集し、カード決済リンクを連携できます。',
                    ],
                    zh: const [
                      '基本资料：填写机构名称、负责人、Logo、行业类型与收款账户，所有账单和通知立即同步更新。',
                      '自定义称呼与多语言：可修改会员/学费等称呼，并自由切换6种语言及10种国家货币与税务规则。',
                      '文案模板与远程刷卡：自由编辑到离店/催缴话术，并绑定在线刷卡收款链接。',
                    ],
                    vi: const [
                      'Thông tin cơ bản: Thiết lập tên cơ sở, người quản lý, logo, ngành nghề và tài khoản ngân hàng cho toàn bộ hóa đơn.',
                      'Thuật ngữ & Đa ngôn ngữ: Tùy biến cách xưng hô (Học viên/Hội viên, Học phí/Phí) và chuyển 6 ngôn ngữ, 10 tiền tệ.',
                      'Mẫu tin nhắn & Link thẻ: Chỉnh sửa nội dung thông báo và gắn link thanh toán thẻ từ xa.',
                    ],
                    es: const [
                      'Perfil y cobros: Configura nombre, responsable, logotipo, sector y cuenta bancaria para tus facturas y avisos.',
                      'Términos e idiomas: Personaliza etiquetas (Alumno/Socio, Cuota) y cambia entre 6 idiomas y 10 divisas.',
                      'Plantillas y tarjeta: Edita textos de avisos e integra tu enlace de cobro con tarjeta.',
                    ],
                  ),
          ),
          _buildGuideCard(
            icon: Icons.tablet_mac_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: LocalizationService.pick(
              ko: '2. 무인 출결 키오스크 & 로컬 보안 금고',
              en: '2. Self Check-In Kiosk & Local Data Vault',
              ja: '2. 無人チェックインキオスク＆ローカル金庫',
              zh: '2. 自助签到终端与本地数据保险库',
              vi: '2. Kiosk Điểm danh & Két dữ liệu cục bộ',
              es: '2. Kiosco de Check-in y Bóveda Local',
            ),
            steps: LocalizationService.pickList(
              ko: const [
                '무인 키오스크: 공기계 폰이나 태블릿을 입구에 두고 회원이 전화번호 뒷4자리를 누르면 자동 출석 & 회차 차감됩니다. 관리자 PIN(기본 0000)으로 잠금을 해제합니다.',
                '100% 로컬 보안 금고: 모든 데이터는 외부 서버 전송 없이 기기에만 저장됩니다. [로컬 데이터 보안 금고]에서 JSON 전체 백업 파일을 카카오톡 "나에게 보내기"나 드라이브에 보관하고 언제든 복원하세요.',
                '실사용 전환: [데이터 초기화(연습 데이터 비우기)]로 샘플 데이터를 지우고 실제 운영을 시작할 수 있습니다.',
              ],
              en: const [
                'Self Check-In Kiosk: Place a phone or tablet at your entrance; members check in via last 4 phone digits or Name Lookup. Exit via Admin PIN (default 0000).',
                '100% Offline Local Vault: Your data never leaves your device unless you back up. Export/import encrypted JSON backups anytime to Drive or local files.',
                'Go Live: Use [Clear Sample Data] anytime to wipe demo data and begin real operations.',
              ],
              ja: const [
                '無人キオスク：入口にタブレット等を設置し、電話番号下4桁または名前検索で会員がセルフチェックインできます（管理者PIN 0000で解除）。',
                '100%ローカル保存金庫：データは外部サーバーに送信されません。JSONバックアップファイルをクラウド等に保存していつでも復元できます。',
                '本番移行：サンプルデータ消去で練習データをリセットし、いつでも実運用へ切り替えられます。',
              ],
              zh: const [
                '自助签到终端：将闲置手机或平板置于前台，会员输入手机尾号或搜索姓名即可自助签到（管理员PIN默认0000解锁）。',
                '100%本地隐私存储：所有数据仅存于设备本地，不上传外部服务器。支持导出全量JSON备份文件并随时恢复。',
                '正式启用：可随时清空演示数据，进入真实门店管理模式。',
              ],
              vi: const [
                'Kiosk tự điểm danh: Đặt máy tính bảng ở lối vào; hội viên điểm danh bằng 4 số cuối SĐT hoặc tìm theo tên (thoát bằng mã PIN 0000).',
                'Két dữ liệu 100% ngoại tuyến: Dữ liệu chỉ lưu trên thiết bị. Xuất hoặc khôi phục bản sao lưu JSON bất kỳ lúc nào.',
                'Chuyển sang dùng thật: Xóa dữ liệu mẫu để bắt đầu vận hành thực tế ngay.',
              ],
              es: const [
                'Kiosco de entrada: Coloca una tablet en recepción; los alumnos fichan con los 4 últimos dígitos o búsqueda por nombre (PIN admin 0000).',
                'Bóveda 100% local: Tus datos nunca salen del dispositivo. Exporta o restaura copias JSON cuando quieras.',
                'Paso a producción: Borra los datos de prueba para iniciar la gestión real de tu centro.',
              ],
            ),
          ),
          _buildGuideCard(
            icon: Icons.workspace_premium_rounded,
            iconColor: const Color(0xFFD97706),
            title: LocalizationService.pick(
              ko: '3. 프로샵(구독 플랜) · 광고 제거 · 무료 체험',
              en: '3. PRO Store Plans · Ad-Free · Free Trial',
              ja: '3. PROショップ（サブスク）・広告非表示・無料体験',
              zh: '3. PRO商城套餐 · 去广告 · 免费试用',
              vi: '3. Cửa hàng PRO · Gỡ quảng cáo · Dùng thử',
              es: '3. Tienda PRO · Sin Anuncios · Prueba Gratis',
            ),
            steps: LocalizationService.currentCurrency == AppCurrency.krw
                ? LocalizationService.pickList(
                    ko: const [
                      '무료 VIP 1시간 체험: 프로샵에서 짧은 보상형 광고 1회를 시청하면 1시간 동안 광고 완전 제거 + 태블릿 키오스크를 무료로 체험할 수 있습니다.',
                      '정기 구독(Google Play): 광고 제거(월 ₩1,900), 태블릿 키오스크(월 ₩4,900), 올인원 VIP(월 ₩5,900 / 연 ₩59,000) 중 필요에 맞게 선택하며 위약금 없이 언제든 해지 가능합니다.',
                      '구독 복원: 기기 변경이나 앱 재설치 후에는 프로샵 우측 상단 [구독 복원] 버튼으로 기존 구글 플레이 구독 권한을 즉시 복원할 수 있습니다.',
                    ],
                    en: const [
                      '1-Hour Free VIP Pass: Watch a short rewarded ad in PRO Store to unlock ad-free use + Kiosk mode for 1 hour.',
                      'Flexible Subscriptions: Choose Ad-Free, Tablet Kiosk, or All-in-One VIP (Monthly/Annual) via the Store with cancel-anytime billing.',
                      'Restore Purchases: Tap [Restore] in PRO Store after reinstalling or switching devices to recover your active plan immediately.',
                    ],
                    ja: const [
                      'VIP 1時間無料体験：PROショップでリワード広告を1回視聴すると1時間、広告なし＋キオスク機能を体験できます。',
                      '定期プラン：広告削除・タブレットキオスク・オールインワンVIP（月額/年額）から選択でき、いつでも解約可能です。',
                      '購入の復元：機種変更や再インストール後はPROショップの［購入を復元］ボタンで権限を即復元できます。',
                    ],
                    zh: const [
                      'VIP 1小时免费试用：在PRO商城观看1次激励广告即可体验1小时全功能去广告及自助终端模式。',
                      '灵活订阅：提供去广告、平板终端及全功能VIP（月付/年付）方案，支持随时取消。',
                      '恢复购买：更换设备或重装应用后，点击PRO商城右上角恢复按钮即可立即找回会员权益。',
                    ],
                    vi: const [
                      'Dùng thử VIP 1 giờ: Xem 1 quảng cáo thưởng trong PRO Store để mở khóa không quảng cáo + Kiosk trong 1 giờ.',
                      'Gói đăng ký linh hoạt: Chọn Gỡ quảng cáo, Kiosk hoặc VIP Trọn gói (Tháng/Năm), hủy bất kỳ lúc nào.',
                      'Khôi phục gói: Nhấn nút Khôi phục trong PRO Store sau khi đổi máy hoặc cài lại ứng dụng.',
                    ],
                    es: const [
                      'Prueba VIP de 1 hora: Mira un anuncio recompensado en Tienda PRO para probar sin anuncios + Kiosco durante 1h.',
                      'Planes flexibles: Elige Sin Anuncios, Kiosco o VIP Todo-en-Uno (mensual/anual), cancelables en cualquier momento.',
                      'Restaurar compras: Pulsa [Restaurar] en Tienda PRO al cambiar de dispositivo para recuperar tu suscripción.',
                    ],
                  )
                : LocalizationService.pickList(
                    ko: const [
                      '무료 VIP 1시간 체험: 프로샵에서 짧은 보상형 광고 1회를 시청하면 1시간 동안 광고 완전 제거 + 태블릿 키오스크를 무료로 체험할 수 있습니다.',
                      '정기 구독(스토어): 광고 제거, 태블릿 키오스크, 올인원 VIP(월간/연간) 중 필요에 맞게 선택하며 언제든 해지 가능합니다.',
                      '구독 복원: 기기 변경이나 앱 재설치 후에는 프로샵 우측 상단 [구독 복원] 버튼으로 기존 구독 권한을 즉시 복원할 수 있습니다.',
                    ],
                    en: const [
                      '1-Hour Free VIP Pass: Watch a short rewarded ad in PRO Store to unlock ad-free use + Kiosk mode for 1 hour.',
                      'Flexible Subscriptions: Choose Ad-Free, Tablet Kiosk, or All-in-One VIP (Monthly/Annual) via the Store with cancel-anytime billing.',
                      'Restore Purchases: Tap [Restore] in PRO Store after reinstalling or switching devices to recover your active plan immediately.',
                    ],
                    ja: const [
                      'VIP 1時間無料体験：PROショップでリワード広告を1回視聴すると1時間、広告なし＋キオスク機能を体験できます。',
                      '定期プラン：広告削除・タブレットキオスク・オールインワンVIP（月額/年額）から選択でき、いつでも解約可能です。',
                      '購入の復元：機種変更や再インストール後はPROショップの［購入を復元］ボタンで権限を即復元できます。',
                    ],
                    zh: const [
                      'VIP 1小时免费试用：在PRO商城观看1次激励广告即可体验1小时全功能去广告及自助终端模式。',
                      '灵活订阅：提供去广告、平板终端及全功能VIP（月付/年付）方案，支持随时取消。',
                      '恢复购买：更换设备或重装应用后，点击PRO商城右上角恢复按钮即可立即找回会员权益。',
                    ],
                    vi: const [
                      'Dùng thử VIP 1 giờ: Xem 1 quảng cáo thưởng trong PRO Store để mở khóa không quảng cáo + Kiosk trong 1 giờ.',
                      'Gói đăng ký linh hoạt: Chọn Gỡ quảng cáo, Kiosk hoặc VIP Trọn gói (Tháng/Năm), hủy bất kỳ lúc nào.',
                      'Khôi phục gói: Nhấn nút Khôi phục trong PRO Store sau khi đổi máy hoặc cài lại ứng dụng.',
                    ],
                    es: const [
                      'Prueba VIP de 1 hora: Mira un anuncio recompensado en Tienda PRO para probar sin anuncios + Kiosco durante 1h.',
                      'Planes flexibles: Elige Sin Anuncios, Kiosco o VIP Todo-en-Uno (mensual/anual), cancelables en cualquier momento.',
                      'Restaurar compras: Pulsa [Restaurar] en Tienda PRO al cambiar de dispositivo para recuperar tu suscripción.',
                    ],
                  ),
          ),
        ];
    }
  }

  Widget _buildGuideCard({
    required IconData icon,
    required Color iconColor,
    required String title,
    required List<String> steps,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.9),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 18, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.map(
            (s) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 6),
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(color: iconColor, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s,
                      style: const TextStyle(
                        fontSize: 12.8,
                        color: Color(0xFF334155),
                        height: 1.5,
                      ),
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
}

class _GuideCategoryMeta {
  final int index;
  final String label;
  final IconData icon;
  final int tabIndex;

  const _GuideCategoryMeta({
    required this.index,
    required this.label,
    required this.icon,
    required this.tabIndex,
  });
}

