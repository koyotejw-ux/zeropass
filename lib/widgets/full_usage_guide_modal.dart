import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
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

  static const List<_GuideCategoryMeta> _categories = [
    _GuideCategoryMeta(index: 0, label: '출결 체크', icon: Icons.fact_check_outlined, tabIndex: 0),
    _GuideCategoryMeta(index: 1, label: '청구·수납', icon: Icons.receipt_long_outlined, tabIndex: 1),
    _GuideCategoryMeta(index: 2, label: '지출·세무', icon: Icons.account_balance_wallet_outlined, tabIndex: 2),
    _GuideCategoryMeta(index: 3, label: '회원 명부', icon: Icons.groups_outlined, tabIndex: 3),
    _GuideCategoryMeta(index: 4, label: '설정·프로샵', icon: Icons.tune_outlined, tabIndex: 4),
  ];

  Future<void> _handleClearDummyDataAndStartReal() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: AppTheme.primaryBlue, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '더미 데이터 비우고 실사용 시작',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: const Text(
          '연습용 샘플 회원·출석·청구·거래처·지출·일정 데이터를 모두 지우고 실제 매장 데이터만 입력할 수 있는 깨끗한 상태로 초기화합니다.\n(스튜디오 상호·계좌·템플릿 설정은 유지됩니다.)',
          style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          ResponsiveDialogActions(
            secondary: TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
            ),
            primary: ElevatedButton(
              onPressed: () => Navigator.pop(dlgCtx, true),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: const FittedBox(
                fit: BoxFit.scaleDown,
                child: Text('깨끗이 비우고 시작', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
        const SnackBar(
          content: Text('더미 데이터가 모두 비워졌습니다! 이제 회원 명부에서 실제 회원을 등록해 보세요.'),
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
    final selectedCat = _categories[_selectedSection];

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
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '체크앤페이 전체 메뉴·기능 가이드',
                          style: TextStyle(fontSize: 17.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          softWrap: true,
                        ),
                        SizedBox(height: 2),
                        Text(
                          '각 탭별 등록·수정·삭제 및 실사용 운영 방법 안내',
                          style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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
                  children: _categories.map((cat) => _buildCategoryChip(cat)).toList(),
                ),
              )
            else
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
                  itemCount: _categories.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (ctx, i) => _buildCategoryChip(_categories[i]),
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
                                '현재 등록된 회원: $membersCount명 · 실사용 전환 체크',
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
                        const Text(
                          '앱 설치 직후에는 기능 체험을 위한 샘플 데이터가 들어 있습니다. 본인 매장의 실제 회원·수납·지출을 관리하려면 먼저 샘플 데이터를 비우고 스튜디오 정보(상호·입금 계좌)를 입력하세요.',
                          style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.45),
                        ),
                        const SizedBox(height: 10),
                        ZeroButton.primary(
                          label: '샘플 데이터 비우고 실사용 시작하기',
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

                  const SizedBox(height: 8),
                  // Jump to Tab CTA
                  if (widget.onNavigateToTab != null)
                    ZeroButton.secondary(
                      label: '${selectedCat.label} 탭으로 바로 이동하기',
                      icon: Icons.arrow_forward_rounded,
                      size: ZeroButtonSize.large,
                      fullWidth: true,
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onNavigateToTab?.call(selectedCat.tabIndex);
                      },
                    ),
                  if (_selectedSection == 4 && widget.onOpenProStore != null) ...[
                    const SizedBox(height: 8),
                    ZeroButton.primary(
                      label: '프로샵(VIP 구독 · 1시간 무료 체험) 열기',
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
    switch (section) {
      case 0:
        return [
          _buildGuideCard(
            icon: Icons.touch_app_rounded,
            iconColor: AppTheme.primaryBlue,
            title: '1. 1초 원터치 출석 체크 & 취소',
            steps: const [
              '등록(체크인): 회원 카드의 [체크인] 버튼을 누르면 즉시 오늘 출석이 기록되며, 회차권 회원은 잔여 회차가 1회 자동 차감됩니다.',
              '출석 취소(회차 복구): 잘못 체크인한 경우 출석 완료 카드 아래 [오늘 출석 취소 (회차 복구)]를 누르면 기록이 삭제되고 차감된 회차가 즉시 복구됩니다.',
              '일괄 출석: 상단 우측 [일괄 출석]을 누르면 현재 필터에서 미출석 상태인 회원들을 한 번에 출석 처리할 수 있습니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.filter_alt_outlined,
            iconColor: const Color(0xFF059669),
            title: '2. KPI 요약 필터 & 잔여 회차 충전',
            steps: const [
              '대시보드 상단 요약 카드(전체 / 오늘 출석 / 미출석 / 만료 임박)를 누르면 해당 상태의 회원만 바로 걸러서 볼 수 있습니다.',
              '회차권 회원의 잔여 회차가 2회 이하(만료 임박)가 되면 [+10회 충전] 버튼이 나타나 1초 만에 회차를 연장할 수 있습니다.',
              '7일 이상 출석 기록이 없는 회원은 [7일+ 미출석 안심 케어] 배너가 표시되며 상황별 안부 톡/문자를 보낼 수 있습니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.qr_code_2_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: '3. 안심 알림 · QR 패스 · 캘린더 · 키오스크',
            steps: const [
              '등·하원 안심 알림: 출석 완료 후 [등원 안심 알림] / [하원 귀가 알림]으로 카카오톡(0원) 또는 기본 문자 앱(0원) 발송이 가능합니다.',
              '디지털 패스 QR: 회원 카드 우측 QR 아이콘을 누르면 회원에게 공유 가능한 모바일 회원증 이미지를 띄울 수 있습니다.',
              '상단 아이콘 기능: 왼쪽부터 [무인 키오스크], [출결·일정 캘린더(일정 등록·수정·삭제)], [스마트 안심 알림 센터(미발송 브리핑/이력/서식)], [큰글씨 모드]입니다.',
            ],
          ),
        ];

      case 1:
        return [
          _buildGuideCard(
            icon: Icons.add_card_rounded,
            iconColor: AppTheme.primaryBlue,
            title: '1. 청구서 발행(단일 & 형제/가족 묶음)',
            steps: [
              '등록: 우측 하단 [+ ${profile.feeTitle} 청구서] 버튼을 눌러 대상 회원을 선택하고 항목·금액·납부기한을 입력해 발행합니다.',
              '형제 묶음 청구: 연락처(보호자 번호)가 같은 여러 회원을 함께 선택하면 합산 금액으로 한 번에 청구서를 만들 수 있습니다.',
              '조회/검색: 상단 상태 필터(전체/미납/완납)와 이름·연락처 검색으로 청구 내역을 빠르게 확인합니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.edit_note_rounded,
            iconColor: const Color(0xFFD97706),
            title: '2. 청구서 수정 · 삭제 · 완납 처리 · 수납 취소',
            steps: const [
              '청구서 수정/삭제: 각 청구서 카드 우측 상단의 [⋮] 버튼을 누르면 금액·항목·기한·연락처 수정 또는 청구서 삭제를 할 수 있습니다.',
              '수납 완료 처리: 미납 카드의 [수납 확인 완료]를 눌러 계좌이체/현금/카드 결제를 기록하면 완납 상태로 전환됩니다.',
              '수납 취소(미납 전환): 완납된 카드 우측 상단 [⋮] → [수납 취소 (미납 전환)]으로 실수 처리한 건을 되돌릴 수 있습니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.send_to_mobile_rounded,
            iconColor: const Color(0xFF059669),
            title: '3. 0원 청구 발송 · 입금 감지 · 장부 CSV',
            steps: const [
              '카톡/SMS 청구 & 리마인드: 입금 계좌번호, 토스 송금 링크, (설정 시) 비대면 카드결제 링크가 자동 포함된 문자를 비용 0원으로 전송합니다.',
              '은행 입금 푸시 감지: 안드로이드에서 은행 입금 알림 문구를 붙여넣기/감지하면 일치하는 미납 청구서를 찾아 원클릭 완납 처리합니다.',
              '수납 장부 엑셀 내보내기: 상단 다운로드 아이콘을 누르면 전체 수납 내역이 UTF-8 엑셀(CSV) 파일로 생성됩니다.',
            ],
          ),
        ];

      case 2:
        return [
          _buildGuideCard(
            icon: Icons.receipt_outlined,
            iconColor: const Color(0xFFE11D48),
            title: '1. 지출·매입 장부 등록 · 수정 · 삭제',
            steps: const [
              '지출 등록: 우측 하단 [+ 지출/매입 등록]에서 임대료·교재비·소모품·강사료 등 지출 내역과 결제수단, 세무증빙 유형을 등록합니다.',
              '수정/삭제/지급토글: 등록된 지출 카드의 수정·삭제 아이콘으로 내역을 변경/삭제하고, 미지급/지급완료 상태를 원터치로 전환할 수 있습니다.',
              '3.3% 원천징수 자동 계산: 강사료/프리랜서 비용 등록 시 [3.3% 원천징수 적용]을 켜면 세액과 실지급액이 자동 계산되며 정산 명세서 문자를 보낼 수 있습니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.store_mall_directory_outlined,
            iconColor: AppTheme.primaryBlue,
            title: '2. 거래처 장부 & 계좌 관리',
            steps: const [
              '거래처 등록/수정/삭제: 상단 [거래처 관리]에서 자주 거래하는 교재사·관리사무소·강사 연락처와 입금 계좌를 등록·수정·삭제합니다.',
              '지출 내역 입력 시 등록된 거래처를 바로 불러와 매입처를 빠르게 연결할 수 있습니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.account_balance_rounded,
            iconColor: const Color(0xFF059669),
            title: '3. 국세청 표준 간편장부 & 세무 가이드',
            steps: const [
              '국세청 표준 사업소득 간편장부 CSV: 완납된 매출(수입)과 지출(비용), 증빙 유형, 3.3% 원천징수 내역을 날짜순으로 통합한 세무사 제출용 엑셀 파일을 1초 만에 추출합니다.',
              '상단 세무 가이드에서 종합소득세(5월), 부가세/사업장현황신고(2월), 원천세(매월 10일) 신고 일정과 홈택스 바로가기를 확인할 수 있습니다.',
            ],
          ),
        ];

      case 3:
        return [
          _buildGuideCard(
            icon: Icons.person_add_alt_1_outlined,
            iconColor: AppTheme.primaryBlue,
            title: '1. 회원 등록 · 사진 · 업종 간편 템플릿',
            steps: const [
              '신규 등록: 우측 하단 [+ 회원 등록]을 눌러 이름, 입금자(학부모) 성함, 연락처, 수업/그룹, 회차권 또는 정기권을 입력합니다.',
              '초간편 템플릿 & 그룹 추가: 업종별 간편 템플릿 칩을 누르면 수강료와 회차가 자동 입력되며, [+ 새 그룹 추가]로 맞춤 반 이름을 만들 수 있습니다.',
              '프로필 사진: 카메라/갤러리로 사진을 등록하면 무인 키오스크 출석 시 회원 얼굴이 화면에 표시됩니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.manage_accounts_outlined,
            iconColor: const Color(0xFFD97706),
            title: '2. 회원 정보 수정 · 삭제 · 회차 충전 · 이력 관리',
            steps: const [
              '정보 수정: 회원 카드를 터치해 상세 창을 연 뒤 우측 상단 연필(✏️) 아이콘을 누르면 이름, 연락처, 입금자명, 그룹, 수강료, 잔여 회차, 메모를 모두 수정할 수 있습니다.',
              '회원 삭제: 상세 창 우측 상단 휴지통(🗑️) 아이콘을 누르면 확인 후 회원과 해당 출석 기록을 안전하게 삭제합니다.',
              '타임라인 & 즉시 처리: 상세 창에서 [+10회 충전], [청구서 즉시 발송], [출석 기록 타임라인(개별 출석 취소 가능)], [수납 내역 로그]를 한곳에서 처리합니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.campaign_outlined,
            iconColor: const Color(0xFF059669),
            title: '3. 초성 검색 · 순차 릴레이 발송 · 명부 CSV',
            steps: const [
              '초성 검색: 검색창에 이름 전체뿐 아니라 초성(예: ㄱㄷㅎ)이나 전화번호 뒷자리를 입력해도 즉시 검색됩니다.',
              '순차 릴레이 단체 발송: 상단 메시지 아이콘 또는 [릴레이 발송]을 누르면 현재 검색/그룹 필터된 회원들에게 공지·안내 문자를 한 명씩 끊김 없이 순차 전송할 수 있습니다.',
              '명부 엑셀(CSV): 상단 다운로드 아이콘으로 전체 회원 명부를 엑셀 파일로 추출합니다.',
            ],
          ),
        ];

      case 4:
      default:
        return [
          _buildGuideCard(
            icon: Icons.business_outlined,
            iconColor: AppTheme.primaryBlue,
            title: '1. 내 스튜디오 · 계좌 · 문자 서식 · 맞춤 용어',
            steps: const [
              '기본 정보: 상단 프로필 카드를 눌러 스튜디오 상호, 대표자명, 로고 사진, 업종, 입금 계좌번호를 설정하면 모든 청구서와 알림장에 즉시 반영됩니다.',
              '맞춤 용어 & 다국어: 원생/회원/수강생, 수강료/회비/레슨비 등 매장 호칭과 언어/통화를 자유롭게 변경할 수 있습니다.',
              '문자 템플릿 & 비대면 카드결제: 등원/하원/청구 문자 문구를 원하는 어투로 편집하고, 토스/카드결제 링크를 연동할 수 있습니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.tablet_mac_rounded,
            iconColor: const Color(0xFF7C3AED),
            title: '2. 무인 출결 키오스크 & 로컬 보안 금고',
            steps: const [
              '무인 키오스크: 공기계 폰이나 태블릿을 입구에 두고 회원이 전화번호 뒷4자리를 누르면 자동 출석 & 회차 차감됩니다. 관리자 PIN(기본 0000)으로 잠금을 해제합니다.',
              '100% 로컬 보안 금고: 모든 데이터는 외부 서버 전송 없이 기기에만 저장됩니다. [로컬 데이터 보안 금고]에서 JSON 전체 백업 파일을 카카오톡 "나에게 보내기"나 드라이브에 보관하고 언제든 복원하세요.',
              '실사용 전환: [데이터 초기화(연습 데이터 비우기)]로 샘플 데이터를 지우고 실제 운영을 시작할 수 있습니다.',
            ],
          ),
          _buildGuideCard(
            icon: Icons.workspace_premium_rounded,
            iconColor: const Color(0xFFD97706),
            title: '3. 프로샵(구독 플랜) · 광고 제거 · 무료 체험',
            steps: const [
              '무료 VIP 1시간 체험: 프로샵에서 짧은 보상형 광고 1회를 시청하면 1시간 동안 광고 완전 제거 + 태블릿 키오스크를 무료로 체험할 수 있습니다.',
              '정기 구독(Google Play): 광고 제거(월 ₩1,900), 태블릿 키오스크(월 ₩4,900), 올인원 VIP(월 ₩5,900 / 연 ₩59,000) 중 필요에 맞게 선택하며 위약금 없이 언제든 해지 가능합니다.',
              '구독 복원: 기기 변경이나 앱 재설치 후에는 프로샵 우측 상단 [구독 복원] 버튼으로 기존 구글 플레이 구독 권한을 즉시 복원할 수 있습니다.',
            ],
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

