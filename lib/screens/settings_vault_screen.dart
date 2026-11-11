import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../models/custom_category_template.dart';
import '../providers/app_providers.dart';
import '../services/coach_mark_service.dart';
import '../services/data_vault_service.dart';
import '../services/database_service.dart';
import '../services/localization_service.dart';
import '../services/monetization_service.dart';
import '../services/schedule_service.dart';
import '../services/starter_preset_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coach_mark_dialog.dart';
import '../widgets/design_system.dart';
import '../widgets/full_usage_guide_modal.dart';
import '../widgets/interactive_guide_dialog.dart';
import '../widgets/mascot_avatar.dart';
import '../widgets/native_inline_ad_card.dart';
import '../widgets/responsive_dialog_actions.dart';
import '../widgets/senior_easy_guide_modal.dart';
import '../widgets/smart_notification_center_modal.dart';
import '../widgets/tax_guide_modal.dart';
import 'home_navigation_screen.dart';
import 'pro_store_screen.dart';
import 'studio_setup_wizard_screen.dart';
import 'tablet_kiosk_screen.dart';

class SettingsVaultScreen extends ConsumerStatefulWidget {
  final bool enableAutoCoachMark;

  const SettingsVaultScreen({
    super.key,
    this.enableAutoCoachMark = true,
  });

  @override
  ConsumerState<SettingsVaultScreen> createState() => _SettingsVaultScreenState();
}

class _SettingsVaultScreenState extends ConsumerState<SettingsVaultScreen> {
  bool _isKioskDedicated = false;

  @override
  void initState() {
    super.initState();
    _loadKioskDedicatedMode();
    if (widget.enableAutoCoachMark) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        CoachMarkDialog.showIfFirstTime(
          context: context,
          coachKey: CoachMarkService.keySettingsTab,
          title: '로컬 100% 보안 금고',
          message: '체크앤페이는 외부 서버로 단 1바이트의 개인정보도 전송하지 않습니다.\n\n내 스마트폰 기기에만 AES 암호화되어 안전하게 보관되며, 원하실 때 언제든 엑셀(CSV)이나 암호화 백업 파일로 추출할 수 있어요.',
          tip: '스튜디오 상호명, 수납 계좌번호, 자동 문자 양식 편집도 모두 여기서 관리하실 수 있습니다.',
          buttonText: '안심하고 사용할게요',
        );
      });
    }
  }

  Future<void> _loadKioskDedicatedMode() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isKioskDedicated = prefs.getBool('is_kiosk_dedicated_mode') ?? false;
      });
    }
  }

  Future<void> _setKioskDedicatedMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_kiosk_dedicated_mode', value);
    if (mounted) {
      setState(() {
        _isKioskDedicated = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            value
                ? '무인 키오스크 전용 모드가 활성화되었습니다. 이제 앱 실행 시 출결 화면으로 바로 진입합니다.'
                : '무인 키오스크 전용 모드가 해제되었습니다. 앱 실행 시 관리자 대시보드로 진입합니다.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _showEmptyMembersKioskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 26),
            SizedBox(width: 8),
            Expanded(
              child: Text('학생 데이터 등록 필요', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: const Text(
          '등록된 원생 데이터가 없어 학생용 키오스크를 바로 실행할 수 없습니다.\n\n샘플 학생 5명을 등록하여 즉시 학생 모드를 시작하시거나, 기능 테스트 모드로 키오스크를 체험해 보세요.',
          style: TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textPrimary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ZeroButton.primary(
                label: '샘플 5명 등록 후 시작',
                icon: Icons.group_add_rounded,
                size: ZeroButtonSize.medium,
                fullWidth: true,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await DatabaseService.instance.restoreSampleData();
                  await ref.read(membersProvider.notifier).reload();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('샘플 학생 5명이 등록되었습니다. 학생용 키오스크를 시작합니다.')),
                    );
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TabletKioskScreen(isTestMode: false)),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
              ZeroButton(
                label: '기능 테스트 모드',
                icon: Icons.science_rounded,
                variant: ZeroButtonVariant.neutral,
                size: ZeroButtonSize.medium,
                fullWidth: true,
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TabletKioskScreen(isTestMode: true)),
                  );
                },
              ),
              const SizedBox(height: 8),
              ZeroButton(
                label: '닫기',
                variant: ZeroButtonVariant.secondary,
                size: ZeroButtonSize.medium,
                fullWidth: true,
                onPressed: () => Navigator.pop(ctx),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAppPinningGuideDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.screen_lock_portrait_rounded, color: AppTheme.primaryBlue, size: 24),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                '안드로이드 앱 화면 고정 가이드',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '학생들이 유튜브를 보거나 다른 앱으로 이탈하지 못하도록 기기를 완벽한 무인 키오스크로 잠그는 방법입니다.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 14),
              _buildPinStep('1단계: 안드로이드 설정', '스마트폰/태블릿의 [설정] > [보안 및 개인정보 보호] (또는 생체 인식 및 보안) 메뉴로 이동합니다.'),
              const SizedBox(height: 10),
              _buildPinStep('2단계: 앱 고정 켜기', '[기타 보안 설정] > [앱 고정] (또는 화면 고정) 항목을 찾아 켭니다.'),
              const SizedBox(height: 10),
              _buildPinStep('3단계: 체크앤페이 고정', '체크앤페이 키오스크 화면을 켠 뒤, 최근 사용 앱 버튼(III)을 누르고 체크앤페이 아이콘을 터치하여 [이 앱 고정]을 선택합니다.'),
              const SizedBox(height: 10),
              _buildPinStep('해제 방법 (관리자 전용)', '뒤로가기 버튼과 최근 앱 버튼을 동시에 길게 누르면 기기 화면 잠금(패턴/PIN)이 풀리며 해제됩니다.'),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.verified_user_rounded, color: AppTheme.primaryBlue, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '앱 내부에서도 우측 상단 자물쇠 터치 시 관리자 비밀번호(0000)가 없으면 대시보드로 나갈 수 없도록 이중 보호됩니다.',
                        style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ZeroButton.primary(
              label: '확인했습니다',
              size: ZeroButtonSize.medium,
              fullWidth: true,
              onPressed: () => Navigator.pop(ctx),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPinStep(String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 5),
          width: 6,
          height: 6,
          decoration: const BoxDecoration(
            color: AppTheme.primaryBlue,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary)),
              const SizedBox(height: 2),
              Text(desc, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }

  void _openFullUsageGuide(BuildContext context) {
    FullUsageGuideModal.show(
      context,
      onNavigateToTab: (tabIdx) {
        HomeNavigationScreen.of(context)?.switchToTab(tabIdx);
      },
      onOpenProStore: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ProStoreScreen()),
        );
      },
    );
  }

  void _openInteractiveGuide(BuildContext context) {
    StepByStepPracticeGuideDialog.show(
      context,
      onOpenAddMember: () {
        HomeNavigationScreen.of(context)?.switchToTab(3); // 회원 명부 탭
      },
      onOpenSettings: () {
        HomeNavigationScreen.of(context)?.switchToTab(4); // 운영·설정 탭
      },
    );
  }

  void _openIndustryPresetDialog(BuildContext context) {
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 22),
                    SizedBox(width: 8),
                    Text(
                      '업종 맞춤 1초 프리셋',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              '업종을 선택하시면 딱 맞는 출결 용어와 실전 샘플 데이터로 즉시 세팅됩니다.',
              style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ...IndustryPreset.values.map(
              (preset) => ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.chipBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.business_center_outlined, color: AppTheme.primaryBlue, size: 20),
                ),
                title: Text(preset.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: Text('${preset.sampleStudioName} (${preset.category})', style: const TextStyle(fontSize: 11.5)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () async {
                  Navigator.pop(ctx);
                  await StarterPresetService.applyPreset(preset);
                  ref.invalidate(membersProvider);
                  ref.invalidate(passRecordsProvider);
                  ref.invalidate(studioProfileProvider);
                  ref.invalidate(invoicesProvider);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${preset.label} 맞춤 환경으로 세팅되었습니다.'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openGuideCenterSheet(BuildContext context, StudioProfile profile) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.92,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ZeroPassMascotAvatar(
                  size: 42,
                  icon: Icons.menu_book_rounded,
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '실전 가이드 센터',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '스텝바이스텝 가이드, 3단계 팁, 업종별 프리셋 허브',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: AppTheme.textSecondary),
                  onPressed: () => Navigator.pop(ctx),
                  visualDensity: VisualDensity.compact,
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Item 0: 탭별·기능별 전체 사용 가이드 (출결·청구·지출·회원·설정·프로샵)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.menu_book_rounded, color: AppTheme.primaryBlue, size: 22),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '탭별 · 기능별 전체 사용 가이드',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    '출결 체크 · 청구/수납 · 지출/세무 · 회원 명부 · 키오스크/프로샵의 등록·수정·삭제 방법과 더미 데이터 비우기 절차를 한눈에 안내합니다.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A), height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  ZeroButton.primary(
                    label: '메뉴별 전체 사용 가이드 열기',
                    icon: Icons.auto_stories_rounded,
                    fullWidth: true,
                    size: ZeroButtonSize.medium,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openFullUsageGuide(context);
                    },
                  ),
                ],
              ),
            ),

            // Item 1: 스텝바이스텝 실전 연습 가이드 (Interactive Guide)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.play_lesson_rounded, color: AppTheme.primaryBlue, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '스텝바이스텝 4단계 실전 연습 가이드',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '회원 등록 → 출결 체크 → 안심 문자 → 청구서 작성',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    '실제 화면 위에 가이드 마커가 표시되어 단계별로 직접 터치하며 배우는 대화형 인터랙티브 튜토리얼입니다.',
                    style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  ZeroButton.primary(
                    label: '실전 튜토리얼 시작하기',
                    icon: Icons.play_arrow_rounded,
                    fullWidth: true,
                    size: ZeroButtonSize.large,
                    onPressed: () {
                      Navigator.pop(ctx);
                      _openInteractiveGuide(context);
                    },
                  ),
                ],
              ),
            ),

            // Item 2: 초간단 3단계 핵심 이용 가이드
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 20),
                      SizedBox(width: 8),
                      Text(
                        '초간단 3단계 핵심 이용 가이드',
                        style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep(Icons.check_circle_rounded, '1. 출결 & 이용 체크', '첫 번째 탭에서 [체크인] 누르면 출석 일시 기록 & 잔여 회차가 1회 자동 차감됩니다.'),
                  const SizedBox(height: 8),
                  _buildGuideStep(Icons.mark_chat_read_rounded, '2. 비용 0원 안심 문자', '체크 완료 후 [출석/이용 알림]을 누르면 기본 문자 앱으로 보호자/회원에게 즉시 전송됩니다.'),
                  const SizedBox(height: 8),
                  _buildGuideStep(Icons.receipt_long_rounded, '3. 청구서 & 수납 장부', '두 번째 탭에서 ${profile.feeTitle} 청구서를 만들고, 은행 입금 감지로 미납/완납을 자동 정리하세요.'),
                ],
              ),
            ),

            // Item 3: 업종 맞춤 1초 프리셋 전환
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '원클릭 업종 프리셋 전환',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            SizedBox(height: 2),
                            Text(
                              '학원 · PT · 필라테스 · 태권도 · 음악공방 맞춤 세팅',
                              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    '선택하신 업종에 맞춰 출결 안내 문구, 수강료/회비 용어, 맞춤 샘플 회원 데이터가 즉시 구성됩니다.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _openIndustryPresetDialog(context);
                      },
                      icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                      label: const Text('내 업종 맞춤 프리셋 선택하기'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD97706),
                        side: const BorderSide(color: Color(0xFFD97706)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Item 4: 매장 셋업 위저드 다시 실행
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFECFDF5),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: AppTheme.softMint, size: 22),
                ),
                title: const Text('매장 셋업 위저드 다시 실행', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                subtitle: const Text('상호명, 업종, 수납 계좌, 첫 회원 등록 마법사 재실행', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                trailing: const Icon(Icons.chevron_right, size: 20),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (c) => StudioSetupWizardScreen(onFinish: () => Navigator.pop(c)),
                    ),
                  );
                },
              ),
            ),
          ),

            // Item 5: 자주 묻는 질문(FAQ) & 팁
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.help_outline_rounded, color: AppTheme.primaryBlue, size: 20),
                      SizedBox(width: 8),
                      Text(
                        '자주 묻는 질문 (FAQ)',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text('Q. 문자 발송 비용이 왜 0원인가요?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  SizedBox(height: 3),
                  Text('A. 유료 외부 문자 서버 대신 내 스마트폰 기본 무료 문자를 활용하므로 월 통신비 지출이 0원입니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45)),
                  Divider(height: 16),
                  Text('Q. 개인정보가 외부 서버에 전송되나요?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  SizedBox(height: 3),
                  Text('A. 중앙 서버를 두지 않는 100% 온디바이스 로컬 암호화 저장소로, 외부 유출이 원천 차단됩니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45)),
                  Divider(height: 16),
                  Text('Q. 태블릿 무인 키오스크 관리자 비밀번호는?', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  SizedBox(height: 3),
                  Text('A. 기본 마스터 비밀번호는 [0000]이며, 키패드에서 0000을 입력하면 관리자 대시보드로 즉시 복귀합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studioAsync = ref.watch(studioProfileProvider);
    final isSeniorMode = ref.watch(seniorModeProvider);
    final activeLanguage = ref.watch(languageProvider);
    final activeCurrency = ref.watch(currencyProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(LocalizationService.tr('tab_settings')),
        ),
        actions: [
          // 1. PRO VIP 샵 퀵 버튼 (심플 라인 아이콘)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.workspace_premium_outlined, size: 21, color: Color(0xFFD97706)),
              tooltip: 'PRO 샵',
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ProStoreScreen()),
                );
              },
            ),
          ),
          // 2. 로컬 금고 암호화 백업 (심플 라인 아이콘)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.shield_outlined, size: 21, color: AppTheme.textPrimary),
              tooltip: '로컬 금고 암호화 백업',
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () async {
                try {
                  final backupFile = await DataVaultService.exportEncryptedBackup();
                  await DataVaultService.shareBackupFile(backupFile);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('백업 실패: $e')),
                    );
                  }
                }
              },
            ),
          ),
          // 3. 시니어 모드 퀵 토글 (공통: 가장 우측 배치)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: Icon(
                Icons.format_size_rounded,
                size: 21,
                color: isSeniorMode ? AppTheme.primaryBlue : AppTheme.textSecondary,
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
      body: studioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('설정 로딩 오류: $err')),
        data: (profile) {
          final customCatAsync = ref.watch(customCategoryProvider);
          final categoryState = customCatAsync.value ??
              CustomCategoryState.getDefaultsForIndustry(profile.category);
          return ListView(
            padding: AppBottomSheet.responsivePagePadding(context, maxWidth: 720, top: 12, bottom: 90),
            children: [
              // 1. Studio Compact Hero Card (시설 상호명, 로고, 담당자, 업종)
              _buildStudioCompactHeroCard(context, profile),
              const SizedBox(height: 14),

              // 2. VIP Retention ROI Card
              _buildVipMembershipRoiCard(context),
              const SizedBox(height: 10),

              // 3. Senior Mode Quick Toggle
              _buildSeniorModeSection(context, isSeniorMode),
              const SizedBox(height: 16),

              // [그룹 1: 시설 & 브랜드 환경]
              _buildGroupHeader('시설 & 브랜드 환경'),
              _buildRepresentativeTile(
                icon: Icons.storefront_rounded,
                iconColor: AppTheme.primaryBlue,
                iconBgColor: const Color(0xFFEFF6FF),
                title: '${profile.placeTitle} 프로필 및 기본 정보',
                subtitle: '${profile.studioName} · ${profile.category} · ${profile.roleTitle} ${profile.instructorName}',
                onTap: () => _openEditProfileDialog(context, profile),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.badge_outlined,
                iconColor: const Color(0xFF0F172A),
                iconBgColor: const Color(0xFFF1F5F9),
                title: '맞춤 호칭 & 용어 설정',
                subtitle: '호칭: ${profile.roleTitle} · ${profile.memberWord} · ${profile.feeWord} · ${profile.placeTitle}',
                trailingBadge: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '${profile.roleTitle}/${profile.memberWord}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                  ),
                ),
                onTap: () => _showEditTerminologyModal(context, profile),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.category_rounded,
                iconColor: const Color(0xFF8B5CF6),
                iconBgColor: const Color(0xFFF5F3FF),
                title: '업종별 카테고리 & 청구 템플릿',
                subtitle: '${profile.category} 맞춤 수납 항목 및 기본 단가 관리',
                onTap: () => _showCustomCategoryBottomSheet(context, profile, categoryState),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.public_rounded,
                iconColor: const Color(0xFF0284C7),
                iconBgColor: const Color(0xFFF0F9FF),
                title: LocalizationService.tr("global_center_title"),
                subtitle: "${activeLanguage.flag} ${activeLanguage.label} · ${activeCurrency.flag} ${activeCurrency.code} (${activeCurrency.symbol})",
                onTap: () => _showLocalizationBottomSheet(context),
              ),
              const SizedBox(height: 16),

              // [그룹 2: 출결 & 무인 키오스크 운영]
              _buildGroupHeader('출결 & 무인 키오스크 운영'),
              _buildRepresentativeTile(
                icon: Icons.tablet_mac_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFEFF6FF),
                title: '무인 출결 키오스크 기기 설정',
                subtitle: _isKioskDedicated ? '자동 실행 활성화됨 · 입구 거치 모드' : '자동 실행 꺼짐 · 학생용/체험 모드 지원',
                trailingBadge: _isKioskDedicated
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text('자동ON', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669))),
                      )
                    : null,
                onTap: () => _showKioskSettingsBottomSheet(context, profile),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.notifications_active_rounded,
                iconColor: const Color(0xFF059669),
                iconBgColor: const Color(0xFFECFDF5),
                title: '스마트 안심 알림 센터 & 감사 로그',
                subtitle: '등·하원 미발송 알림 일괄 전송, 독촉 릴레이, 전체 감사 로그',
                onTap: () => SmartNotificationCenterModal.show(context),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.edit_note_rounded,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFFFBEB),
                title: '문자 알림 및 청구 서식 관리',
                subtitle: '수강료 청구서, 입실 안심 문자, 퇴실 문자 서식 편집',
                onTap: () => _showSmsTemplatesBottomSheet(context, profile),
              ),
              const SizedBox(height: 16),

              // [그룹 3: 금융 결제 & 데이터 보안]
              _buildGroupHeader('금융 결제 & 데이터 보안'),
              _buildRepresentativeTile(
                icon: Icons.credit_card_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFEFF6FF),
                title: '비대면 신용카드 결제 링크 (0원 연동)',
                subtitle: profile.cardPaymentEnabled ? '비대면 카드결제 켜짐' : '가입비 0원 · 월관리비 0원 · 전용 링크 신청',
                onTap: () => _showCardPaymentBottomSheet(context, profile),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF0F172A),
                iconBgColor: const Color(0xFFF1F5F9),
                title: '로컬 데이터 보안 금고 (100% 온디바이스)',
                subtitle: '암호화 백업, 카카오톡/드라이브 전송, 복원, 초기화',
                onTap: () => _showDataVaultBottomSheet(context),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.security_rounded,
                iconColor: const Color(0xFF059669),
                iconBgColor: const Color(0xFFECFDF5),
                title: '금융 푸시 필터 보안 설정',
                subtitle: profile.autoBankDetectEnabled ? '은행 입금 푸시 감지 켜짐' : '은행 입금 푸시 감지 꺼짐',
                onTap: () => _showBankPushSecurityBottomSheet(context, profile),
              ),
              const SizedBox(height: 16),

              // [그룹 4: 가이드 & 규정 준수]
              _buildGroupHeader('가이드 & 규정 준수'),
              _buildRepresentativeTile(
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFEFF6FF),
                title: '탭별 · 기능별 전체 사용 가이드',
                subtitle: '출결·청구·지출·회원·설정·프로샵 메뉴별 등록/수정/삭제 안내',
                onTap: () => _openFullUsageGuide(context),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.auto_stories_rounded,
                iconColor: const Color(0xFF059669),
                iconBgColor: const Color(0xFFECFDF5),
                title: '실전 가이드 센터 & 튜토리얼',
                subtitle: '4단계 실전 연습 코칭 · 업종 프리셋 · 셋업 마법사 · FAQ',
                onTap: () => _openGuideCenterSheet(context, profile),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.gavel_rounded,
                iconColor: const Color(0xFF64748B),
                iconBgColor: const Color(0xFFF8FAFC),
                title: '법적 고지 및 규정 준수 (Compliance)',
                subtitle: '개인정보 처리방침 · 이용약관 · 로컬 암호화 보안 확약',
                onTap: () => _showComplianceBottomSheet(context),
              ),
              const SizedBox(height: 16),
              const NativeInlineAdCard(placementTag: 'settings_vault'),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStudioCompactHeroCard(BuildContext context, StudioProfile profile) {
    final isSeniorMode = ref.watch(seniorModeProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderSubtle, width: 0.9),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Samsung One UI Profile Header: Avatar + Studio Name & Badges
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: () => _showLogoPickerSheet(context, profile),
                child: Stack(
                  children: [
                    _buildStudioLogoAvatar(profile, size: 56),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryBlue,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 10),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Studio Name: UNCONSTRAINED FULL SOFT-WRAP (NO ELLIPSIS!)
                    Text(
                      profile.studioName,
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 17.5,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.4,
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 6),
                    // Badges Cluster: Category + Logo Status + Logo Action
                    Wrap(
                      spacing: 6,
                      runSpacing: 5,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                          decoration: BoxDecoration(
                            color: const Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFDBEAFE), width: 0.8),
                          ),
                          child: Text(
                            profile.category,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ),
                        if (profile.logoPath != null && profile.logoPath!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFFECFDF5),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFA7F3D0), width: 0.8),
                            ),
                            child: const Text(
                              '로고 적용됨',
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF059669),
                              ),
                            ),
                          ),
                        InkWell(
                          onTap: () => _showLogoPickerSheet(context, profile),
                          borderRadius: BorderRadius.circular(6),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                            child: Text(
                              profile.logoPath != null ? '로고 변경/삭제' : '상호 로고 등록하기',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF64748B),
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // 2. Inset Metadata Card (Instructor, Custom Words, Bank Account - Grouped Cleanly)
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.badge_outlined, size: 14, color: Color(0xFF64748B)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '${profile.instructorName} ${profile.roleTitle} · 호칭: ${profile.memberWord} / ${profile.feeWord}',
                        softWrap: true,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textSecondary,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
                if (profile.bankName.isNotEmpty && profile.accountNumber.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.account_balance_outlined, size: 14, color: Color(0xFF64748B)),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${profile.bankName} ${profile.accountNumber} (${profile.accountHolder})',
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF475569),
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 14),

          // 3. Samsung One UI Action Grid (1 Column Full-Width in Senior Mode)
          if (isSeniorMode)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openEditProfileDialog(context, profile),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                  ),
                  icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.textPrimary),
                  label: const Text(
                    '기본 정보 수정',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                ),
                const SizedBox(height: 10),
                ElevatedButton.icon(
                  onPressed: () => _showEditTerminologyModal(context, profile),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    minimumSize: const Size(double.infinity, 50),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  icon: const Icon(Icons.tune_rounded, size: 18, color: Colors.white),
                  label: const Text(
                    '맞춤 호칭 설정',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _openEditProfileDialog(context, profile),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.0),
                    ),
                    icon: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.textPrimary),
                    label: const Text(
                      '기본 정보 수정',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showEditTerminologyModal(context, profile),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.tune_rounded, size: 15, color: Colors.white),
                    label: const Text(
                      '맞춤 호칭 설정',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w800,
          color: AppTheme.textSecondary,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildRepresentativeTile({
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    Widget? trailingBadge,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isCompact = constraints.maxWidth < 340;
            return Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 12 : 16,
                vertical: 14,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(isCompact ? 8 : 10),
                    decoration: BoxDecoration(
                      color: iconBgColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: isCompact ? 18 : 20),
                  ),
                  SizedBox(width: isCompact ? 10 : 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                          softWrap: true,
                        ),
                        if (isCompact && trailingBadge != null) ...[
                          const SizedBox(height: 4),
                          trailingBadge,
                        ],
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          softWrap: true,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppTheme.textSecondary,
                            letterSpacing: -0.2,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCompact && trailingBadge != null) ...[
                    const SizedBox(width: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 112),
                      child: trailingBadge,
                    ),
                  ],
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppTheme.textTertiary),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSheetHeader(BuildContext context, String title, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 8, 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.4,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
    );
  }

  void _showCustomCategoryBottomSheet(BuildContext context, StudioProfile profile, CustomCategoryState categoryState) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (sheetCtx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetHeader(sheetCtx, '업종별 카테고리 & 템플릿', Icons.category_rounded, const Color(0xFF8B5CF6)),
            _buildCustomCategorySection(context, profile, categoryState),
          ],
        ),
      ),
    );
  }

  void _showLocalizationBottomSheet(BuildContext context) {
    bool autoSuggestCurrency = true;

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final curLang = ref.watch(languageProvider);
          final curCur = ref.watch(currencyProvider);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetHeader(
                  sheetCtx,
                  LocalizationService.tr('global_center_title'),
                  Icons.public_rounded,
                  const Color(0xFF0284C7),
                ),
                Text(
                  LocalizationService.tr('global_center_subtitle'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 16),

                // 1. Language Selection Section
                Row(
                  children: [
                    const Icon(Icons.translate_rounded, size: 18, color: AppTheme.primaryBlue),
                    const SizedBox(width: 8),
                    Text(
                      LocalizationService.tr('language_selector'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AppLanguage.values.map((lang) {
                    final isSelected = lang == curLang;
                    return InkWell(
                      onTap: () async {
                        await ref.read(languageProvider.notifier).setLanguage(
                              lang,
                              autoUpdateCurrency: autoSuggestCurrency,
                            );
                        setSheetState(() {});
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFFEFF6FF) : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppTheme.primaryBlue : AppTheme.borderSubtle,
                            width: isSelected ? 1.8 : 1.0,
                          ),
                          boxShadow: isSelected ? AppTheme.cardShadow : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(lang.flag, style: const TextStyle(fontSize: 18)),
                            const SizedBox(width: 8),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  lang.label,
                                  style: TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                                    color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                                  ),
                                ),
                                Text(
                                  lang.englishLabel,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isSelected ? AppTheme.primaryBlue.withAlpha(204) : AppTheme.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                            if (isSelected) ...[
                              const SizedBox(width: 8),
                              const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.primaryBlue),
                            ],
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                // Auto Suggest Currency Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.sync_rounded, size: 18, color: Color(0xFF0284C7)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LocalizationService.tr('auto_suggest_currency'),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                        ),
                      ),
                      Switch(
                        value: autoSuggestCurrency,
                        activeThumbColor: AppTheme.primaryBlue,
                        onChanged: (val) {
                          setSheetState(() {
                            autoSuggestCurrency = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                // 2. Currency & Accounting Policy Selection
                Row(
                  children: [
                    const Icon(Icons.monetization_on_outlined, size: 18, color: AppTheme.softMint),
                    const SizedBox(width: 8),
                    Text(
                      LocalizationService.tr('currency_selector'),
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Column(
                  children: AppCurrency.values.map((cur) {
                    final isSelected = cur == curCur;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () async {
                          await ref.read(currencyProvider.notifier).setCurrency(cur);
                          setSheetState(() {});
                        },
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF16A34A) : AppTheme.borderSubtle,
                              width: isSelected ? 1.8 : 1.0,
                            ),
                            boxShadow: isSelected ? AppTheme.cardShadow : null,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(cur.flag, style: const TextStyle(fontSize: 20)),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 8,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              '${cur.code} (${cur.symbol})',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w800,
                                                color: isSelected ? const Color(0xFF15803D) : AppTheme.textPrimary,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: cur.decimalPlaces == 0 ? const Color(0xFFEFF6FF) : const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                cur.decimalPlaces == 0 ? '소수점 0자리 (정수)' : '소수점 ${cur.decimalPlaces}자리 (.00)',
                                                style: TextStyle(
                                                  fontSize: 10.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: cur.decimalPlaces == 0 ? const Color(0xFF1D4ED8) : const Color(0xFFB45309),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          cur.displayName,
                                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    const Icon(Icons.check_circle_rounded, size: 20, color: Color(0xFF16A34A)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: isSelected ? Colors.white.withAlpha(204) : const Color(0xFFF8FAFC),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.payment_rounded, size: 13, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            cur.paymentChannels.join(' · '),
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        const Icon(Icons.receipt_long_outlined, size: 13, color: Color(0xFF64748B)),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            cur.taxPolicy,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),
                // 3. Live Preview Card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFF0FDF4), Color(0xFFEFF6FF)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFBAE6FD), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.visibility_outlined, size: 16, color: Color(0xFF0369A1)),
                              const SizedBox(width: 6),
                              Text(
                                LocalizationService.tr('live_preview_card'),
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Color(0xFF0369A1)),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${curLang.flag} ${curLang.label} · ${curCur.flag} ${curCur.code}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(LocalizationService.tr('sample_fee_label'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text(
                            curCur.format(curCur.sampleAmount),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: AppTheme.primaryDark),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(LocalizationService.tr('sample_date_label'), style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Text(
                            LocalizationService.formatDate(DateTime.now()),
                            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('출결 상태 (Status)', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withAlpha(38),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              LocalizationService.tr('checked_in'),
                              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF047857)),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                    onPressed: () => Navigator.pop(sheetCtx),
                    child: Text(
                      LocalizationService.tr('btn_confirm'),
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          );
        },
      ),
    );
  }

  void _showKioskSettingsBottomSheet(BuildContext context, StudioProfile profile) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader(sheetCtx, '무인 출결 키오스크 기기 설정', Icons.tablet_mac_rounded, const Color(0xFF2563EB)),
              Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
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
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '앱 실행 시 키오스크 자동 실행',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                              SizedBox(height: 3),
                              Text(
                                '입구 거치 태블릿으로 설정 시 관리자 대시보드 없이 바로 출결 키오스크로 시작합니다.',
                                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: _isKioskDedicated,
                          activeThumbColor: AppTheme.primaryBlue,
                          onChanged: (val) async {
                            await _setKioskDedicatedMode(val);
                            setSheetState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 20, color: AppTheme.borderSubtle),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.touch_app_rounded, color: AppTheme.primaryBlue),
                      ),
                      title: const Text('학생 출결 키오스크 실행 (실제 운영용)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                      subtitle: const Text('입구 거치용 전체화면. 체험 핀이 일체 숨겨지는 클린 학생 운영 화면입니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        final members = ref.read(membersProvider).value ?? [];
                        if (members.isEmpty) {
                          _showEmptyMembersKioskDialog(context);
                        } else {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TabletKioskScreen(isTestMode: false)),
                          );
                        }
                      },
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEEF2FF),
                        child: Icon(Icons.science_rounded, color: Color(0xFF6366F1)),
                      ),
                      title: const Text('키오스크 기능 테스트 (체험 모드)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                      subtitle: const Text('1234 체험 핀으로 출결 완료 축하 및 알림 화면 결과를 즉시 확인합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const TabletKioskScreen(isTestMode: true)),
                        );
                      },
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFECFDF5),
                        child: Icon(Icons.screen_lock_portrait_rounded, color: AppTheme.softMint),
                      ),
                      title: const Text('안드로이드 앱 화면 고정(Pinning) 가이드', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                      subtitle: const Text('학생들이 홈 화면이나 유튜브 등으로 나가지 못하게 기기를 고정 잠금합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _showAppPinningGuideDialog(context),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.lock_rounded, size: 18, color: Color(0xFFD97706)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '안심 보안 잠금: 등록된 회원이 있을 때는 키오스크에 회원 명단/PIN이 일체 표시되지 않으며, 우측 상단 자물쇠 터치 시 관리자 비밀번호(0000)를 입력해야만 관리자 화면으로 나갈 수 있습니다.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.45),
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
        ),
      ),
    );
  }

  void _showSmsTemplatesBottomSheet(BuildContext context, StudioProfile profile) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.85,
      builder: (sheetCtx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetHeader(sheetCtx, '문자 알림 및 청구 서식 관리', Icons.edit_note_rounded, const Color(0xFFD97706)),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.receipt_long_outlined, color: AppTheme.primaryBlue),
                    ),
                    title: Text('${profile.feeTitle} 청구서 문자 서식 편집', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                    subtitle: Text('${profile.feeTitle} 청구 시 발송되는 기본 문자 내용을 변경합니다.', style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _openTemplateEditorDialog(
                      context: context,
                      title: '${profile.feeTitle} 청구서 문자 서식 편집',
                      initialText: profile.invoiceTemplate,
                      defaultText: StudioProfile.defaultInvoiceTemplate,
                      placeholders: '#{상호명}, #{담당자}, #{직함}, #{회원명}, #{고객호칭}, #{비용호칭}, #{청구제목}, #{금액}, #{계좌정보}, #{계좌복사용}, #{토스송금링크}, #{카드결제링크}, #{납부기한}',
                      profile: profile,
                      onSave: (newTemplate, updatedProfile) {
                        final updated = updatedProfile.copyWith(invoiceTemplate: newTemplate);
                        ref.read(studioProfileProvider.notifier).updateProfile(updated);
                      },
                    ),
                  ),
                  const Divider(height: 16, color: AppTheme.borderSubtle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECFDF5),
                      child: Icon(Icons.mark_chat_read_outlined, color: AppTheme.softMint),
                    ),
                    title: const Text('출석 / 입실 안심 문자 서식 편집', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                    subtitle: const Text('체크인 시 보호자/회원에게 전송되는 안심 문자를 변경합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _openTemplateEditorDialog(
                      context: context,
                      title: '출석 / 입실 문자 서식 편집',
                      initialText: profile.attendanceTemplate,
                      defaultText: StudioProfile.defaultAttendanceTemplate,
                      placeholders: '#{상호명}, #{장소호칭}, #{담당자}, #{직함}, #{회원명}, #{고객호칭}, #{출석시간}, #{잔여회차}',
                      profile: profile,
                      onSave: (newTemplate, updatedProfile) {
                        final updated = updatedProfile.copyWith(attendanceTemplate: newTemplate);
                        ref.read(studioProfileProvider.notifier).updateProfile(updated);
                      },
                    ),
                  ),
                  const Divider(height: 16, color: AppTheme.borderSubtle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFFFBEB),
                      child: Icon(Icons.exit_to_app_rounded, color: AppTheme.warning),
                    ),
                    title: const Text('퇴실 / 일정종료 문자 서식 편집', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                    subtitle: const Text('귀가/퇴실 시 발송되는 완료 안내 문자를 변경합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _openTemplateEditorDialog(
                      context: context,
                      title: '퇴실 / 일정종료 문자 서식 편집',
                      initialText: profile.departureTemplate,
                      defaultText: StudioProfile.defaultDepartureTemplate,
                      placeholders: '#{상호명}, #{장소호칭}, #{담당자}, #{직함}, #{회원명}, #{고객호칭}',
                      profile: profile,
                      onSave: (newTemplate, updatedProfile) {
                        final updated = updatedProfile.copyWith(departureTemplate: newTemplate);
                        ref.read(studioProfileProvider.notifier).updateProfile(updated);
                      },
                    ),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCardPaymentBottomSheet(BuildContext context, StudioProfile profile) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader(sheetCtx, '비대면 신용카드 결제 링크', Icons.credit_card_rounded, AppTheme.primaryBlue),
              Container(
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
                        Flexible(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '가입비 0원 · 월관리비 0원',
                                style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Transform.scale(
                          scale: 0.85,
                          child: Switch(
                            value: profile.cardPaymentEnabled,
                            activeThumbColor: AppTheme.primaryBlue,
                            onChanged: (val) async {
                              final updated = profile.copyWith(cardPaymentEnabled: val);
                              await ref.read(studioProfileProvider.notifier).updateProfile(updated);
                              setSheetState(() {});
                              setState(() {});
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    const Text('원격 비대면 카드 결제 연동', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
                    const SizedBox(height: 4),
                    const Text(
                      '토스페이먼츠, 페이앱, 결제선생 등 사용 중인 PG사의 결제 링크를 연동하면, 청구 문자/카톡에 비대면 카드결제 링크가 자동 포함됩니다.',
                      style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                    ),
                    const SizedBox(height: 14),
                    if (profile.cardPaymentEnabled) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.link_rounded, size: 16, color: AppTheme.primaryBlue),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    profile.cardPaymentUrl.trim().isEmpty
                                        ? '등록된 카드결제 링크 없음 (링크를 설정해주세요)'
                                        : profile.cardPaymentUrl,
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: profile.cardPaymentUrl.trim().isEmpty
                                          ? AppTheme.textSecondary
                                          : AppTheme.textPrimary,
                                    ),
                                    softWrap: true,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              '💡 팁: URL에 {금액}을 입력하면 회원별 청구 금액이 링크에 자동으로 채워집니다.',
                              style: TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (profile.cardPaymentUrl.trim().isEmpty)
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _openCardPaymentUrlDialog(context, profile),
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const Text('결제 링크 설정'),
                          ),
                        )
                      else
                        ResponsiveDialogActions(
                          primaryFirstInColumn: false,
                          secondary: OutlinedButton.icon(
                            onPressed: () => _openCardPaymentUrlDialog(context, profile),
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('결제 링크 설정')),
                          ),
                          primary: ElevatedButton.icon(
                            onPressed: () async {
                              final testUrl = profile.getFormattedCardPaymentUrl(
                                amount: 100000,
                                orderTitle: '테스트${profile.feeWord}',
                                customerName: '홍길동',
                              );
                              final uri = Uri.tryParse(testUrl);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('유효한 웹 링크 형식이 아닙니다. (http:// 또는 https:// 포함)')),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_browser_rounded, size: 15),
                            label: const FittedBox(fit: BoxFit.scaleDown, child: Text('링크 테스트')),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryBlue,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                    ] else ...[
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final updated = profile.copyWith(cardPaymentEnabled: true);
                            await ref.read(studioProfileProvider.notifier).updateProfile(updated);
                            if (context.mounted) {
                              _openCardPaymentUrlDialog(context, updated);
                            }
                          },
                          icon: const Icon(Icons.add_link_rounded, size: 16),
                          label: const Text('비대면 카드결제 기능 켜기'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDataVaultBottomSheet(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (sheetCtx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetHeader(sheetCtx, '로컬 데이터 보안 금고', Icons.lock_outline_rounded, const Color(0xFF0F172A)),
            Material(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEFF6FF),
                      child: Icon(Icons.share_outlined, color: AppTheme.primaryBlue),
                    ),
                    title: const Text('로컬 백업 파일 생성 & 카톡/드라이브 전송', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                    subtitle: const Text('회원·출결·수납 데이터를 암호화하여 카톡/드라이브로 안전 보관합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      final file = await DataVaultService.exportEncryptedBackup();
                      await DataVaultService.shareBackupFile(file);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('백업 파일이 생성되어 공유 창이 열렸습니다: ${file.path.split(Platform.isWindows ? "\\" : "/").last}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 16, color: AppTheme.borderSubtle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFECFDF5),
                      child: Icon(Icons.table_view_outlined, color: AppTheme.softMint),
                    ),
                    title: const Text('수납 장부 엑셀(CSV) 내보내기 & 공유', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                    subtitle: const Text('세무/결산용 엑셀 호환 CSV를 생성하여 카톡/엑셀로 공유합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      final file = await DataVaultService.exportLedgerCsv();
                      await DataVaultService.shareLedgerCsv(file);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('수납 장부 CSV가 생성되어 공유 창이 열렸습니다: ${file.path.split(Platform.isWindows ? "\\" : "/").last}'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                  const Divider(height: 16, color: AppTheme.borderSubtle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFEEF2FF),
                      child: Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5)),
                    ),
                    title: Row(
                      children: [
                        Expanded(
                          child: Text(LocalizationService.taxReportTitle, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                        ),
                        InkWell(
                          onTap: () => TaxGuideModal.show(context),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEEF2FF),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: const Color(0xFFC7D2FE)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.lightbulb_rounded, size: 11, color: Color(0xFF4F46E5)),
                                SizedBox(width: 3),
                                Text('세무 가이드', style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: const Text('수입과 지출을 통합 정렬하여 5월 종합소득세 및 2월 사업장현황신고 세무사용 표준 CSV를 생성합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      try {
                        final file = await DataVaultService.exportSimplifiedBookkeepingCsv();
                        await DataVaultService.shareSimplifiedBookkeepingCsv(file);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('국세청 간편장부 CSV가 생성되어 공유 창이 열렸습니다: ${file.path.split(Platform.isWindows ? "\\" : "/").last}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('간편장부 내보내기 오류: $e')));
                        }
                      }
                    },
                  ),
                  const Divider(height: 16, color: AppTheme.borderSubtle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFF0FDF4),
                      child: Icon(Icons.restore_page_outlined, color: AppTheme.softMint),
                    ),
                    title: const Text('백업 데이터 복원하기 (텍스트 / JSON)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                    subtitle: const Text('카카오톡 등으로 보관한 백업 JSON 내용을 입력하여 복원합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _openRestoreDataDialog(context),
                  ),
                  const Divider(height: 16, color: AppTheme.borderSubtle),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFFEF2F2),
                      child: Icon(Icons.cleaning_services_outlined, color: AppTheme.danger),
                    ),
                    title: const Text('체험용 가상 데이터 비우기 (실제 운영 시작)', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.danger)),
                    subtitle: const Text('샘플 5명 데이터를 모두 지우고 실제 회원만 등록합니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () => _showResetDataDialog(context),
                  ),
                ],
              ),
            ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showResetDataDialog(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        actionsAlignment: MainAxisAlignment.end,
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: AppTheme.danger, size: 22),
            SizedBox(width: 8),
            Expanded(
              child: Text('연습 데이터를 모두 비우시겠습니까?', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Text(
            '현재 등록된 가상 회원, 출석 기록, 청구서 내역이 모두 삭제되어 실제 운영 모드로 초기화됩니다.\n(스튜디오 프로필 설정은 유지됩니다.)',
            style: TextStyle(height: 1.5, fontSize: 13),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          ResponsiveDialogActions(
            secondary: ZeroButton(
              label: LocalizationService.tr('btn_cancel'),
              variant: ZeroButtonVariant.neutral,
              size: ZeroButtonSize.medium,
              fullWidth: true,
              onPressed: () => Navigator.pop(c, false),
            ),
            primary: ZeroButton.danger(
              label: '깨끗이 비우기',
              icon: Icons.delete_sweep_rounded,
              size: ZeroButtonSize.medium,
              fullWidth: true,
              onPressed: () => Navigator.pop(c, true),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('체험용 데이터가 모두 비워졌습니다. 이제 실제 회원과 장부를 등록해 보세요!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _showBankPushSecurityBottomSheet(BuildContext context, StudioProfile profile) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.60,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader(sheetCtx, '금융 푸시 필터 보안 설정', Icons.security_rounded, const Color(0xFF059669)),
              Container(
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
                        const Expanded(
                          child: Text(
                            '은행 입금 푸시 알림 자동 감지 (안드로이드)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Switch(
                          value: profile.autoBankDetectEnabled,
                          activeThumbColor: AppTheme.primaryBlue,
                          onChanged: (val) {
                            ref.read(studioProfileProvider.notifier).toggleBankDetect(val);
                            setSheetState(() {});
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryBlue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '검증된 1금융권/인터넷은행 앱 패키지만 엄격 필터링하며, 개인 카카오톡 및 일반 문자는 즉시 자동 폐기(Drop)하여 일체의 프라이버시 침해를 원천 차단합니다.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                            ),
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
    );
  }

  void _showComplianceBottomSheet(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.65,
      builder: (sheetCtx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetHeader(sheetCtx, '법적 고지 및 규정 준수 (Compliance)', Icons.gavel_rounded, const Color(0xFF64748B)),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Row(
                    children: [
                      Icon(Icons.verified_user_rounded, size: 18, color: Color(0xFF059669)),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '100% 로컬 온디바이스 보안 보증',
                          style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10),
                  Text(
                    '본 앱은 오프라인 장부 및 메시지 서식 도구이며, 모든 데이터는 기기에만 AES 암호화 보관됩니다. 원격 중앙 서버 및 제3자 분석 서버로 데이터를 전송하지 않습니다.\n회원 정보 수집 동의 및 회원과의 수납·거래 책임은 운영자 본인에게 있습니다.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildVipMembershipRoiCard(BuildContext context) {
    return AnimatedBuilder(
      animation: MonetizationService.instance,
      builder: (context, _) {
        final bm = MonetizationService.instance;
        final isVip = bm.isPermanentVip;
        final isTemp = bm.isTemporaryPassActive;
        final fmt = NumberFormat('#,###');

        return Container(
          margin: const EdgeInsets.only(bottom: 18),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.45),
              width: 1.2,
            ),
            boxShadow: AppTheme.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      '👑 ${bm.retentionTierTitle}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFBBF24),
                      ),
                    ),
                  ),
                  Text(
                    '🔥 연속 ${bm.activeStreakDays}일 스마트 운영 중',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFE2E8F0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isVip
                    ? '올인원 VIP 멤버십 활성화 완료'
                    : '누적 절감 가치: 약 ${fmt.format(bm.estimatedTotalSavedKRW)}원',
                style: const TextStyle(
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                  letterSpacing: -0.3,
                ),
                softWrap: true,
              ),
              const SizedBox(height: 4),
              Text(
                isVip
                    ? '모든 광고가 차단되었으며 입구 거치형 무인 출결 키오스크를 무제한으로 이용하실 수 있습니다.'
                    : isTemp
                        ? '현재 1시간 무료 VIP 체험권이 작동 중입니다 (${bm.remainingTemporaryPassFormatted}). 월 1,900원(한 달 구독)으로 쾌적한 매장을 유지하세요.'
                        : '0원 문자(${bm.cumulativeSavedSmsCount}건)와 자동 출결(${bm.cumulativeCheckInCount}건)로 아낀 비용으로 광고 없는 VIP 매장과 무인 키오스크를 시작하세요.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: Colors.white.withValues(alpha: 0.82),
                  height: 1.4,
                ),
                softWrap: true,
              ),
              const SizedBox(height: 14),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProStoreScreen()),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF59E0B),
                        foregroundColor: const Color(0xFF0F172A),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      icon: const Icon(Icons.workspace_premium_rounded, size: 16, color: Color(0xFF0F172A)),
                      label: Text(
                        isVip ? 'VIP 구독 관리 열기' : '월 1,900원~ VIP 멤버십 보기',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  if (!isVip) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          if (bm.isAnyRewardedAdAvailable) {
                            bm.showBestRewardedAd(
                              onRewarded: () async {
                                await bm.grantTemporaryAdFreeHours(1, includeKiosk: true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('1시간 광고 제거 + 무인 키오스크 VIP 패스가 활성화되었습니다!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                              onFailed: () async {
                                await bm.grantTemporaryAdFreeHours(1, includeKiosk: true);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('응원 혜택으로 1시간 올인원 VIP 패스가 무료로 활성화되었습니다!'),
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              },
                            );
                          } else {
                            bm.grantTemporaryAdFreeHours(1, includeKiosk: true);
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('1시간 광고 제거 + 무인 키오스크 VIP 패스가 열렸습니다!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.play_circle_outline_rounded, size: 15, color: Color(0xFFFBBF24)),
                        label: const Text(
                          '1시간 VIP 무료 체험',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSeniorModeSection(BuildContext context, bool isSeniorMode) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isSeniorMode ? const Color(0xFFEFF6FF) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSeniorMode ? AppTheme.trustBlue : AppTheme.borderSubtle,
          width: isSeniorMode ? 2.0 : 1.0,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSeniorMode ? AppTheme.trustBlue : const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.elderly_rounded,
                    color: isSeniorMode ? Colors.white : AppTheme.trustBlue,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: isSeniorMode ? const Color(0xFFDBEAFE) : const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          isSeniorMode ? '사용 중' : '고령자 맞춤',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: isSeniorMode ? AppTheme.trustBlue : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '시니어 큰글씨 모드',
                          style: TextStyle(
                            fontSize: isSeniorMode ? 18.5 : 16.5,
                            fontWeight: FontWeight.w800,
                            color: isSeniorMode ? AppTheme.trustBlue : AppTheme.textPrimary,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isSeniorMode
                            ? '글씨 1.4배 확대 및 고대비 간편 화면이 적용 중입니다.'
                            : '1.4배 큰글씨 & 고대비 간편 화면으로 편하게 이용하세요',
                        style: TextStyle(
                          fontSize: isSeniorMode ? 14 : 12.5,
                          fontWeight: FontWeight.w500,
                          color: isSeniorMode ? const Color(0xFF1E3A8A) : AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: isSeniorMode,
                  activeThumbColor: AppTheme.trustBlue,
                  onChanged: (val) => ref.read(seniorModeProvider.notifier).setSeniorMode(val),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: isSeniorMode ? AppTheme.trustBlue : AppTheme.borderSubtle,
                        width: isSeniorMode ? 1.6 : 1.0,
                      ),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.help_outline_rounded, size: 18, color: AppTheme.trustBlue),
                    label: const Text(
                      '큰글씨 사용 가이드 보기',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.trustBlue,
                      ),
                    ),
                    onPressed: () => SeniorEasyGuideModal.show(context),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon, Color? iconColor}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: iconColor ?? AppTheme.primaryBlue),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildStudioLogoAvatar(StudioProfile profile, {double size = 64}) {
    final hasLogo = profile.logoPath != null && profile.logoPath!.isNotEmpty && File(profile.logoPath!).existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: hasLogo ? AppTheme.primaryBlue.withValues(alpha: 0.3) : AppTheme.borderSubtle,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.28),
        child: hasLogo
            ? Image.file(
                File(profile.logoPath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.storefront_rounded, color: AppTheme.primaryBlue, size: 28),
                ),
              )
            : const Center(
                child: Icon(Icons.storefront_rounded, color: Color(0xFF64748B), size: 28),
              ),
      ),
    );
  }

  Future<void> _showLogoPickerSheet(BuildContext context, StudioProfile profile) async {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.85,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSheetHeader(ctx, '상호 및 브랜드 로고 관리', Icons.photo_camera_rounded, AppTheme.primaryBlue),
            const SizedBox(height: 4),
            const Text('무인 키오스크 상단 및 알림장에 우리 학원 전용 로고가 표기됩니다.', style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.photo_library_outlined, color: AppTheme.primaryBlue),
                ),
                title: const Text('갤러리에서 로고 선택', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('정사각형 또는 가로형 PNG/JPG 이미지 권장', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickAndSaveLogo(ImageSource.gallery, profile);
                },
              ),
            ),
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF10B981).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.camera_alt_outlined, color: Color(0xFF10B981)),
                ),
                title: const Text('카메라로 직접 촬영', style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: const Text('명함, 간판, 학원 서식 사진을 즉석에서 촬영', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _pickAndSaveLogo(ImageSource.camera, profile);
                },
              ),
            ),
            if (profile.logoPath != null && profile.logoPath!.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFECDD3)),
                ),
                child: ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, color: Color(0xFFEF4444)),
                  ),
                  title: const Text('등록된 로고 삭제', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444))),
                  subtitle: const Text('기본 마스코트 아이콘으로 복원합니다.', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(studioProfileProvider.notifier).updateProfile(profile.copyWith(clearLogo: true));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('상호 로고가 삭제되어 기본 아이콘으로 복원되었습니다.')),
                      );
                    }
                  },
                ),
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSaveLogo(ImageSource source, StudioProfile profile) async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 88, maxWidth: 1000);
      if (picked == null) return;

      final appDir = await getApplicationDocumentsDirectory();
      final fileName = 'studio_logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');

      await ref.read(studioProfileProvider.notifier).updateProfile(
        profile.copyWith(logoPath: savedImage.path),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('상호 로고가 성공적으로 등록되었습니다! 키오스크에 즉시 적용됩니다.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('로고 등록 중 오류가 발생했습니다: $e')),
        );
      }
    }
  }

  void _showEditTerminologyModal(BuildContext context, StudioProfile current) {
    String selectedMember = current.customMemberTerm ?? current.memberWord;
    String selectedFee = current.customFeeTerm ?? current.feeWord;
    String selectedRole = current.customRoleTerm ?? current.roleTitle;
    String selectedPlace = current.customPlaceTerm ?? current.placeTitle;

    final customMemberCtrl = TextEditingController(
      text: StudioProfile.memberTermOptions.contains(selectedMember) ? '' : selectedMember,
    );
    final customFeeCtrl = TextEditingController(
      text: StudioProfile.feeTermOptions.contains(selectedFee) ? '' : selectedFee,
    );
    final customRoleCtrl = TextEditingController(
      text: StudioProfile.roleTermOptions.contains(selectedRole) ? '' : selectedRole,
    );
    final customPlaceCtrl = TextEditingController(
      text: StudioProfile.placeTermOptions.contains(selectedPlace) ? '' : selectedPlace,
    );
    bool isCustomMember = !StudioProfile.memberTermOptions.contains(selectedMember);
    bool isCustomFee = !StudioProfile.feeTermOptions.contains(selectedFee);
    bool isCustomRole = !StudioProfile.roleTermOptions.contains(selectedRole);
    bool isCustomPlace = !StudioProfile.placeTermOptions.contains(selectedPlace);

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.92,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final activeMemberTerm = isCustomMember
                ? (customMemberCtrl.text.trim().isEmpty ? '회원' : customMemberCtrl.text.trim())
                : selectedMember;
            final activeFeeTerm = isCustomFee
                ? (customFeeCtrl.text.trim().isEmpty ? '회비' : customFeeCtrl.text.trim())
                : selectedFee;
            final activeRoleTerm = isCustomRole
                ? (customRoleCtrl.text.trim().isEmpty ? '대표' : customRoleCtrl.text.trim())
                : selectedRole;
            final activePlaceTerm = isCustomPlace
                ? (customPlaceCtrl.text.trim().isEmpty ? '매장' : customPlaceCtrl.text.trim())
                : selectedPlace;

            return SingleChildScrollView(
              padding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetHeader(ctx, '맞춤 호칭 & 용어 설정', Icons.badge_rounded, const Color(0xFF0F172A)),
                  const SizedBox(height: 6),
                  const Text(
                    '고객, 수납 비용, 운영자 직함(대표/원장/실장 등), 장소 호칭을 매장 성격에 맞게 직접 정할 수 있으며 문자와 알림장에 즉시 반영됩니다.',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 18),

                  // 1. Member Term
                  const Text('1. 고객 / 회원 호칭 선택', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.memberTermOptions.map((term) {
                        final isSel = !isCustomMember && selectedMember == term;
                        return ChoiceChip(
                          label: Text(term, style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          )),
                          selected: isSel,
                          selectedColor: AppTheme.primaryBlue,
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                isCustomMember = false;
                                selectedMember = term;
                              });
                            }
                          },
                        );
                      }),
                      ChoiceChip(
                        label: Text('직접 입력', style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isCustomMember ? FontWeight.w800 : FontWeight.w600,
                          color: isCustomMember ? Colors.white : AppTheme.textPrimary,
                        )),
                        selected: isCustomMember,
                        selectedColor: AppTheme.primaryBlue,
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          setModalState(() {
                            isCustomMember = true;
                          });
                        },
                      ),
                    ],
                  ),
                  if (isCustomMember) ...[
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: customMemberCtrl,
                      label: '직접 입력 호칭',
                      hint: '예: 수련생, 아동, 멘티, 골퍼, 회원님',
                      prefixIcon: Icons.edit_outlined,
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 2. Fee Term
                  const Text('2. 청구 / 수납 비용 호칭 선택', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.feeTermOptions.map((term) {
                        final isSel = !isCustomFee && selectedFee == term;
                        return ChoiceChip(
                          label: Text(term, style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          )),
                          selected: isSel,
                          selectedColor: const Color(0xFF4F46E5),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                isCustomFee = false;
                                selectedFee = term;
                              });
                            }
                          },
                        );
                      }),
                      ChoiceChip(
                        label: Text('직접 입력', style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isCustomFee ? FontWeight.w800 : FontWeight.w600,
                          color: isCustomFee ? Colors.white : AppTheme.textPrimary,
                        )),
                        selected: isCustomFee,
                        selectedColor: const Color(0xFF4F46E5),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          setModalState(() {
                            isCustomFee = true;
                          });
                        },
                      ),
                    ],
                  ),
                  if (isCustomFee) ...[
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: customFeeCtrl,
                      label: '직접 입력 비용명',
                      hint: '예: 레슨비, 강습료, 교재비, 회비',
                      prefixIcon: Icons.payments_outlined,
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 3. Operator Role Term (대표/원장/실장 등)
                  const Text('3. 운영자 직함 호칭 선택', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.roleTermOptions.map((term) {
                        final isSel = !isCustomRole && selectedRole == term;
                        return ChoiceChip(
                          label: Text(term, style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          )),
                          selected: isSel,
                          selectedColor: const Color(0xFF059669),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                isCustomRole = false;
                                selectedRole = term;
                              });
                            }
                          },
                        );
                      }),
                      ChoiceChip(
                        label: Text('직접 입력', style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isCustomRole ? FontWeight.w800 : FontWeight.w600,
                          color: isCustomRole ? Colors.white : AppTheme.textPrimary,
                        )),
                        selected: isCustomRole,
                        selectedColor: const Color(0xFF059669),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          setModalState(() {
                            isCustomRole = true;
                          });
                        },
                      ),
                    ],
                  ),
                  if (isCustomRole) ...[
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: customRoleCtrl,
                      label: '직접 입력 직함',
                      hint: '예: 총괄실장, 수석코치, 디자이너, 매니저',
                      prefixIcon: Icons.person_pin_outlined,
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 4. Place Term (스튜디오/학원/센터 등)
                  const Text('4. 사업장 성격 호칭 선택', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.placeTermOptions.map((term) {
                        final isSel = !isCustomPlace && selectedPlace == term;
                        return ChoiceChip(
                          label: Text(term, style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          )),
                          selected: isSel,
                          selectedColor: const Color(0xFF0F172A),
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                isCustomPlace = false;
                                selectedPlace = term;
                              });
                            }
                          },
                        );
                      }),
                      ChoiceChip(
                        label: Text('직접 입력', style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: isCustomPlace ? FontWeight.w800 : FontWeight.w600,
                          color: isCustomPlace ? Colors.white : AppTheme.textPrimary,
                        )),
                        selected: isCustomPlace,
                        selectedColor: const Color(0xFF0F172A),
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          setModalState(() {
                            isCustomPlace = true;
                          });
                        },
                      ),
                    ],
                  ),
                  if (isCustomPlace) ...[
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: customPlaceCtrl,
                      label: '직접 입력 사업장 호칭',
                      hint: '예: 클리닉, 연습실, 작업실, 랩',
                      prefixIcon: Icons.storefront_outlined,
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 5. Live Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF38BDF8)),
                            SizedBox(width: 6),
                            Text('실시간 앱·문자 표기 미리보기', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF38BDF8))),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text('• 안내장: [${current.studioName}] 홍길동 $activeMemberTerm님의 $activeFeeTerm 청구서', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('• 출결: [${current.studioName}] $activeMemberTerm님이 $activePlaceTerm에 도착하여 체크인 완료', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                        const SizedBox(height: 4),
                        Text('• 발신/서명: ${current.studioName} ($activeRoleTerm: ${current.instructorName})', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final updated = current.copyWith(
                          customMemberTerm: activeMemberTerm,
                          customFeeTerm: activeFeeTerm,
                          customRoleTerm: activeRoleTerm,
                          customPlaceTerm: activePlaceTerm,
                        );
                        await ref.read(studioProfileProvider.notifier).updateProfile(updated);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('맞춤 호칭($activeRoleTerm · $activeMemberTerm · $activeFeeTerm · $activePlaceTerm)이 저장되었습니다.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('맞춤 호칭 저장하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openEditProfileDialog(BuildContext context, StudioProfile current) {
    final studioCtrl = TextEditingController(text: current.studioName);
    final instructorCtrl = TextEditingController(text: current.instructorName);
    final bankCtrl = TextEditingController(text: current.bankName);
    final accountCtrl = TextEditingController(text: current.accountNumber);
    final holderCtrl = TextEditingController(text: current.accountHolder);
    final cardUrlCtrl = TextEditingController(text: current.cardPaymentUrl);
    bool cardEnabled = current.cardPaymentEnabled;
    String? modalLogoPath = current.logoPath;
    bool modalClearLogo = false;

    String selectedCategory = current.category;
    final customCategoryCtrl = TextEditingController();
    bool isCustom = !StudioProfile.businessCategories.contains(current.category) || current.category == '기타 / 맞춤업종';
    if (isCustom && current.category != '기타 / 맞춤업종') {
      customCategoryCtrl.text = current.category;
    }

    String selectedRole = current.customRoleTerm ?? current.roleTitle;
    final customRoleCtrl = TextEditingController(
      text: StudioProfile.roleTermOptions.contains(selectedRole) ? '' : selectedRole,
    );
    bool isCustomRole = !StudioProfile.roleTermOptions.contains(selectedRole);

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.92,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetHeader(ctx, '스튜디오 프로필 수정', Icons.storefront_rounded, AppTheme.primaryBlue),
                  const SizedBox(height: 4),
                  const Text('청구서 및 알림 문자에 표기될 사업장 정보입니다.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 18),

                  // Modal Logo Selector
                  Center(
                    child: GestureDetector(
                      onTap: () async {
                        final picker = ImagePicker();
                        final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1000);
                        if (picked != null) {
                          final appDir = await getApplicationDocumentsDirectory();
                          final fileName = 'studio_logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
                          final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');
                          setModalState(() {
                            modalLogoPath = savedImage.path;
                            modalClearLogo = false;
                          });
                        }
                      },
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(22),
                              border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.35), width: 1.5),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(22),
                              child: (modalLogoPath != null && !modalClearLogo && File(modalLogoPath!).existsSync())
                                  ? Image.file(
                                      File(modalLogoPath!),
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Center(
                                        child: Icon(Icons.storefront_rounded, color: AppTheme.primaryBlue, size: 36),
                                      ),
                                    )
                                  : const Center(
                                      child: Icon(Icons.add_photo_alternate_outlined, color: AppTheme.primaryBlue, size: 36),
                                    ),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppTheme.primaryBlue,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 2),
                              ),
                              child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton.icon(
                          onPressed: () async {
                            final picker = ImagePicker();
                            final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 88, maxWidth: 1000);
                            if (picked != null) {
                              final appDir = await getApplicationDocumentsDirectory();
                              final fileName = 'studio_logo_${DateTime.now().millisecondsSinceEpoch}.jpg';
                              final savedImage = await File(picked.path).copy('${appDir.path}/$fileName');
                              setModalState(() {
                                modalLogoPath = savedImage.path;
                                modalClearLogo = false;
                              });
                            }
                          },
                          icon: const Icon(Icons.photo_library_outlined, size: 15),
                          label: Text(modalLogoPath != null && !modalClearLogo ? '로고 변경' : '상호 로고 등록'),
                        ),
                        if (modalLogoPath != null && !modalClearLogo) ...[
                          const SizedBox(width: 4),
                          TextButton(
                            onPressed: () {
                              setModalState(() {
                                modalClearLogo = true;
                                modalLogoPath = null;
                              });
                            },
                            child: const Text('삭제', style: TextStyle(color: Color(0xFFEF4444))),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  AppTextField(
                    controller: studioCtrl,
                    label: '상호명 / 스튜디오명',
                    hint: '예: 체크앤페이 스튜디오',
                    prefixIcon: Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 14),

                  // Business Category Selector
                  const Text(
                    '사업장 업종 카테고리',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: StudioProfile.businessCategories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat, style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        )),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryBlue,
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              selectedCategory = cat;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  if (selectedCategory == '기타 / 맞춤업종') ...[
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: customCategoryCtrl,
                      label: '직접 입력 카테고리',
                      hint: '예: 바리스타 학원, 가죽 공방, 보컬 레슨',
                      prefixIcon: Icons.category_outlined,
                    ),
                  ],
                  const SizedBox(height: 14),

                  AppTextField(
                    controller: instructorCtrl,
                    label: '담당자 성명',
                    hint: '예: 홍길동',
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 12),
                  const Text('직함 / 호칭 (문자·명세서에 반영)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.roleTermOptions.map((term) {
                        final isSel = !isCustomRole && selectedRole == term;
                        return ChoiceChip(
                          label: Text(term, style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSel ? FontWeight.w800 : FontWeight.w600,
                            color: isSel ? Colors.white : AppTheme.textPrimary,
                          )),
                          selected: isSel,
                          selectedColor: AppTheme.primaryBlue,
                          backgroundColor: const Color(0xFFF1F5F9),
                          onSelected: (val) {
                            if (val) {
                              setModalState(() {
                                isCustomRole = false;
                                selectedRole = term;
                              });
                            }
                          },
                        );
                      }),
                      ChoiceChip(
                        label: Text('직접 입력', style: TextStyle(
                          fontSize: 12,
                          fontWeight: isCustomRole ? FontWeight.w800 : FontWeight.w600,
                          color: isCustomRole ? Colors.white : AppTheme.textPrimary,
                        )),
                        selected: isCustomRole,
                        selectedColor: AppTheme.primaryBlue,
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          setModalState(() => isCustomRole = true);
                        },
                      ),
                    ],
                  ),
                  if (isCustomRole) ...[
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: customRoleCtrl,
                      label: '직접 입력 직함',
                      hint: '예: 실장, 코치, 총괄매니저',
                      prefixIcon: Icons.person_pin_outlined,
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: bankCtrl,
                    label: '수납 은행명',
                    hint: '예: 토스뱅크, 국민은행',
                    prefixIcon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: accountCtrl,
                    label: '수납 계좌번호',
                    hint: '예: 3333-01-2345678',
                    prefixIcon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: holderCtrl,
                    label: '예금주 성명',
                    hint: '예: 홍길동',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('비대면 카드결제 링크 사용 (0원 연동)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: const Text('토스페이먼츠/페이앱 등 원격 결제 URL 연동', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    value: cardEnabled,
                    activeThumbColor: AppTheme.primaryBlue,
                    onChanged: (val) {
                      setModalState(() {
                        cardEnabled = val;
                      });
                    },
                  ),
                  if (cardEnabled) ...[
                    const SizedBox(height: 8),
                    AppTextField(
                      controller: cardUrlCtrl,
                      label: '비대면 카드결제 URL ({금액} 자동치환 지원)',
                      hint: '예: https://pay.toss.im/_m/...',
                      prefixIcon: Icons.link_rounded,
                      keyboardType: TextInputType.url,
                    ),
                  ],
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final finalCat = selectedCategory == '기타 / 맞춤업종' && customCategoryCtrl.text.trim().isNotEmpty
                            ? customCategoryCtrl.text.trim()
                            : selectedCategory;
                        final finalRole = isCustomRole
                            ? (customRoleCtrl.text.trim().isEmpty ? '대표' : customRoleCtrl.text.trim())
                            : selectedRole;
                        final updated = current.copyWith(
                          studioName: studioCtrl.text.trim(),
                          instructorName: instructorCtrl.text.trim(),
                          bankName: bankCtrl.text.trim(),
                          accountNumber: accountCtrl.text.trim(),
                          accountHolder: holderCtrl.text.trim(),
                          category: finalCat,
                          customRoleTerm: finalRole,
                          cardPaymentEnabled: cardEnabled,
                          cardPaymentUrl: cardUrlCtrl.text.trim(),
                          logoPath: modalLogoPath,
                          clearLogo: modalClearLogo,
                        );
                        await ref.read(studioProfileProvider.notifier).updateProfile(updated);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('스튜디오 프로필 및 카테고리가 저장되었습니다.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('저장하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openCardPaymentUrlDialog(BuildContext context, StudioProfile current) {
    final urlCtrl = TextEditingController(text: current.cardPaymentUrl);
    AppBottomSheet.show(
      context: context,
      builder: (ctx) {
        return SingleChildScrollView(
          padding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      '비대면 카드결제 링크 설정',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      softWrap: true,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '토스페이먼츠(페이링크), 페이앱(결제선생), 카카오페이 등 비대면 결제 URL을 등록하세요.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: urlCtrl,
                label: '카드결제 링크 (URL)',
                hint: 'https://pay.toss.im/_m/... 또는 https://payapp.kr/L/...',
                prefixIcon: Icons.link_rounded,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('{금액}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                    backgroundColor: const Color(0xFFEFF6FF),
                    onPressed: () {
                      urlCtrl.text = '${urlCtrl.text}{금액}';
                    },
                  ),
                  ActionChip(
                    label: const Text('{회원명}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                    backgroundColor: const Color(0xFFEFF6FF),
                    onPressed: () {
                      urlCtrl.text = '${urlCtrl.text}{회원명}';
                    },
                  ),
                  ActionChip(
                    label: const Text('{상품명}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                    backgroundColor: const Color(0xFFEFF6FF),
                    onPressed: () {
                      urlCtrl.text = '${urlCtrl.text}{상품명}';
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final updated = current.copyWith(
                      cardPaymentUrl: urlCtrl.text.trim(),
                      cardPaymentEnabled: true,
                    );
                    await ref.read(studioProfileProvider.notifier).updateProfile(updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('카드결제 링크가 저장되었습니다.')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: const Text('저장하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openRestoreDataDialog(BuildContext context) {
    final jsonController = TextEditingController();

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.85,
      builder: (ctx) {
        return SingleChildScrollView(
          padding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '백업 데이터 복원하기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '카카오톡이나 메일로 내보냈던 백업 파일(.json)의 내용을 전체 복사하여 아래에 붙여넣어 주세요.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: jsonController,
                label: '백업 JSON 내용 붙여넣기',
                hint: '{\n  "version": "1.0.0",\n  "members": [...]\n}',
                maxLines: 10,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final text = jsonController.text.trim();
                    if (text.isEmpty) return;

                    final success = await DataVaultService.restoreFromBackupJson(text);
                    if (ctx.mounted) Navigator.pop(ctx);

                    if (success) {
                      await ref.read(membersProvider.notifier).reload();
                      await ref.read(passRecordsProvider.notifier).reload();
                      await ref.read(invoicesProvider.notifier).reload();
                      await ref.read(studioProfileProvider.notifier).reload();
                      await ref.read(vendorsProvider.notifier).reload();
                      await ref.read(expensesProvider.notifier).reload();
                      await ref.read(notificationLogsProvider.notifier).reload();
                      await ref.read(schedulesProvider.notifier).reload();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('백업 데이터가 복원되었습니다.'),
                            backgroundColor: AppTheme.softMint,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('올바르지 않은 백업 데이터 형식이거나 복원에 실패했습니다.'),
                            backgroundColor: AppTheme.danger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.restore, color: Colors.white),
                  label: const Text('지금 바로 데이터 복원하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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

  Widget _buildGuideStep(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: const BoxDecoration(
            color: Color(0xFFEFF6FF),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 14,
            color: AppTheme.primaryBlue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                TextSpan(
                  text: desc,
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openTemplateEditorDialog({
    required BuildContext context,
    required String title,
    required String initialText,
    required String defaultText,
    required String placeholders,
    required StudioProfile profile,
    required Function(String, StudioProfile) onSave,
  }) {
    final textController = TextEditingController(text: initialText);
    final studioNameController = TextEditingController(text: profile.studioName);
    final instructorController = TextEditingController(text: profile.instructorName);
    final bankController = TextEditingController(text: profile.bankName);
    final accountController = TextEditingController(text: profile.accountNumber);
    final holderController = TextEditingController(text: profile.accountHolder);

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.92,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Live preview generation with comprehensive placeholder support
            final previewBank = bankController.text.trim().isEmpty ? '토스뱅크' : bankController.text.trim();
            final previewAccount = accountController.text.trim().isEmpty ? '1000-2026-8899' : accountController.text.trim();
            final previewHolder = holderController.text.trim().isEmpty ? '담당자' : holderController.text.trim();
            final previewStudio = studioNameController.text.trim().isEmpty ? '스튜디오' : studioNameController.text.trim();
            final previewInstructor = instructorController.text.trim().isEmpty ? '담당자' : instructorController.text.trim();
            final cleanAccOnly = previewAccount.replaceAll(RegExp(r'[^0-9]'), '');
            final previewCopyAcc = '$previewBank $previewAccount $previewHolder';
            final previewToss = 'supertoss://send?bank=${Uri.encodeComponent(previewBank)}&account=$cleanAccOnly&amount=250000';
            final previewCard = profile.cardPaymentEnabled && profile.cardPaymentUrl.isNotEmpty
                ? profile.getFormattedCardPaymentUrl(amount: 250000, orderTitle: '9월 정기 ${profile.feeWord}', customerName: '김민준')
                : 'https://pay.toss.im/_m/sample123';

            String previewText = textController.text
                .replaceAll('#{상호명}', previewStudio)
                .replaceAll('#{담당자}', previewInstructor)
                .replaceAll('#{대표자}', previewInstructor)
                .replaceAll('#{강사명}', previewInstructor)
                .replaceAll('#{직함}', profile.roleTitle)
                .replaceAll('#{고객호칭}', profile.memberWord)
                .replaceAll('#{비용호칭}', profile.feeWord)
                .replaceAll('#{장소호칭}', profile.placeTitle)
                .replaceAll('#{회원명}', '김민준')
                .replaceAll('#{계좌정보}', '$previewBank $previewAccount ($previewHolder)')
                .replaceAll('#{계좌복사용}', previewCopyAcc)
                .replaceAll('#{토스송금링크}', previewToss)
                .replaceAll('#{카드결제링크}', previewCard)
                .replaceAll('{카드결제링크}', previewCard)
                .replaceAll('#{금액}', '250,000')
                .replaceAll('#{청구제목}', '9월 정기 ${profile.feeWord}')
                .replaceAll('#{안내내용}', '9월 정기 ${profile.feeWord}')
                .replaceAll('#{납부기한}', '2026.09.20')
                .replaceAll('#{출석시간}', '14:30')
                .replaceAll('#{잔여회차}', '• 잔여 회차 : 9회');

            return SingleChildScrollView(
              padding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          softWrap: true,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () {
                        textController.text = defaultText;
                        setModalState(() {});
                      },
                      icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AppTheme.primaryBlue),
                      label: const Text('권장 서식 초기화', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '필수 변수(상호명, 담당자, 계좌 등)를 수정하면 문자에 즉시 반영됩니다.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // 1. Dedicated Input Fields for Essential Variables
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryBlue),
                            SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '문자에 삽입되는 필수 기본 정보',
                                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: studioNameController,
                          label: '사업장 상호/브랜드명 (#{상호명})',
                          hint: '예: 체크앤페이 스튜디오 / 학원 / 공방',
                          prefixIcon: Icons.storefront_outlined,
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: instructorController,
                          label: '담당자 성명 (#{담당자})',
                          hint: '예: 홍길동',
                          prefixIcon: Icons.badge_outlined,
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            if (constraints.maxWidth < 320) {
                              return Column(
                                children: [
                                  AppTextField(
                                    controller: bankController,
                                    label: '입금 은행 (#{계좌정보})',
                                    hint: '토스뱅크',
                                    prefixIcon: Icons.account_balance_outlined,
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                  const SizedBox(height: 12),
                                  AppTextField(
                                    controller: holderController,
                                    label: '예금주 성명',
                                    hint: '홍길동',
                                    prefixIcon: Icons.person_outline,
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ],
                              );
                            }
                            return Row(
                              children: [
                                Expanded(
                                  child: AppTextField(
                                    controller: bankController,
                                    label: '입금 은행 (#{계좌정보})',
                                    hint: '토스뱅크',
                                    prefixIcon: Icons.account_balance_outlined,
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AppTextField(
                                    controller: holderController,
                                    label: '예금주 성명',
                                    hint: '홍길동',
                                    prefixIcon: Icons.person_outline,
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: accountController,
                          label: '입금 계좌번호',
                          hint: '3333-01-2345678',
                          prefixIcon: Icons.credit_card_outlined,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Template Editor with Placeholders Chips
                  const Text(
                    '문자 서식 양식 편집',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: placeholders.split(',').map((p) {
                      final tag = p.trim();
                      return ActionChip(
                        backgroundColor: const Color(0xFFEFF6FF),
                        label: Text(tag, style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          final currentText = textController.text;
                          final selection = textController.selection;
                          final newText = selection.isValid && selection.start >= 0
                              ? currentText.replaceRange(selection.start, selection.end, tag)
                              : '$currentText $tag';
                          textController.text = newText;
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: textController,
                    label: '문자 본문 (치환 태그 클릭 시 본문에 추가됩니다)',
                    maxLines: 7,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // 3. Live Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: const Border(left: BorderSide(color: AppTheme.softMint, width: 3.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 14, color: AppTheme.softMint),
                            SizedBox(width: 6),
                            Text(
                              '실제 발송 문자 미리보기',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          previewText,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final updatedProfile = profile.copyWith(
                          studioName: studioNameController.text.trim(),
                          instructorName: instructorController.text.trim(),
                          bankName: bankController.text.trim(),
                          accountNumber: accountController.text.trim(),
                          accountHolder: holderController.text.trim(),
                        );
                        onSave(textController.text.trim(), updatedProfile);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('문자 서식 및 상호/계좌 정보가 안전하게 저장되었습니다.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('서식 & 정보 함께 저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildCustomCategorySection(
    BuildContext context,
    StudioProfile profile,
    CustomCategoryState categoryState,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle('업종별 맞춤 카테고리 및 청구 서식 관리', icon: Icons.category_rounded),
        Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderSubtle),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.tune_rounded, color: AppTheme.primaryBlue, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          '어떤 업종이든 100% 맞춤형! 등록 그룹과 청구서 항목을 사업장 특성에 맞게 자유롭게 편집하세요.',
                          style: TextStyle(fontSize: 12.5, color: Colors.blueGrey[800], height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // 1. Group Categories
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFEFF6FF),
                    child: Icon(Icons.groups_outlined, color: AppTheme.primaryBlue),
                  ),
                  title: const Text('수업 / 반 그룹 카테고리 관리', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                  subtitle: Text(
                    '등록된 그룹 ${categoryState.groupCategories.length}개 (${categoryState.groupCategories.take(3).join(', ')}${categoryState.groupCategories.length > 3 ? ' 외' : ''})',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _openGroupCategoryManager(context),
                ),
                const Divider(height: 16, color: AppTheme.borderSubtle),

                // 2. Member Registration Quick Templates
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFECFDF5),
                    child: Icon(Icons.playlist_add_check_rounded, color: AppTheme.softMint),
                  ),
                  title: const Text('학생 등록 간편 템플릿 관리', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                  subtitle: Text(
                    '등록된 템플릿 ${categoryState.memberTemplates.length}개 (선택 시 그룹·금액·회차 원터치 채움)',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _openMemberTemplateManager(context),
                ),
                const Divider(height: 16, color: AppTheme.borderSubtle),

                // 3. Invoice Item & Fee Templates
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFF3E8FF),
                    child: Icon(Icons.receipt_long_rounded, color: Color(0xFF8B5CF6)),
                  ),
                  title: const Text('청구 항목 및 금액 템플릿 관리', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                  subtitle: Text(
                    '등록된 항목 ${categoryState.invoiceTemplates.length}개 (정규수강료, 교재비, 재등록 등)',
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _openInvoiceTemplateManager(context),
                ),
                const Divider(height: 16, color: AppTheme.borderSubtle),

                // 4. One-touch Industry Preset Reset
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const CircleAvatar(
                    backgroundColor: Color(0xFFFFFBEB),
                    child: Icon(Icons.auto_fix_high_rounded, color: AppTheme.warning),
                  ),
                  title: const Text('원터치 업종별 프리셋 불러오기', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary)),
                  subtitle: const Text(
                    '학원, 피트니스, 필라테스, 태권도, 음악/공방 템플릿으로 원클릭 초기화',
                    style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => _openIndustryPresetResetDialog(context),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openGroupCategoryManager(BuildContext context) {
    final textController = TextEditingController();

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.85,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final catState = ref.watch(customCategoryProvider).value ??
                CustomCategoryState.getDefaultsForIndustry('입시 / 보습학원');

            return SingleChildScrollView(
              padding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('수업 / 반 그룹 카테고리 관리', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('학생 등록 시 선택할 수 있는 수업 그룹 목록입니다. 불필요한 항목은 삭제하고 새로운 그룹을 자유롭게 추가하세요.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 18),

                  // Add new group row
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: textController,
                          label: '새 그룹 이름',
                          hint: '예: 고등 내신반, 1:1 기구필라',
                          prefixIcon: Icons.add_circle_outline,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Padding(
                        padding: const EdgeInsets.only(top: 24),
                        child: ElevatedButton(
                          onPressed: () async {
                            final name = textController.text.trim();
                            if (name.isNotEmpty) {
                              await ref.read(customCategoryProvider.notifier).addGroupCategory(name);
                              textController.clear();
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('\'$name\' 그룹이 추가되었습니다.'), duration: const Duration(seconds: 1)),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryBlue,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: const Text('추가', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text('현재 등록된 그룹 (${catState.groupCategories.length}개)',
                      style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
                  const SizedBox(height: 10),

                  if (catState.groupCategories.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: const Text('등록된 그룹이 없습니다. 상단에서 추가해보세요.', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: catState.groupCategories.map((group) {
                        return Chip(
                          backgroundColor: const Color(0xFFF1F5F9),
                          label: Text(group, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onDeleted: () async {
                            await ref.read(customCategoryProvider.notifier).removeGroupCategory(group);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('\'$group\' 그룹이 삭제되었습니다.'), duration: const Duration(seconds: 1)),
                              );
                            }
                          },
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Color(0xFFE2E8F0))),
                        );
                      }).toList(),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openMemberTemplateManager(BuildContext context) {
    final currencyFormat = NumberFormat('#,###');

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final catState = ref.watch(customCategoryProvider).value ??
                CustomCategoryState.getDefaultsForIndustry('입시 / 보습학원');

            return SingleChildScrollView(
              padding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('학생 등록 간편 템플릿', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('회원 등록 시 탭 한 번으로 그룹명, 수강유형, 기본 수강료를 자동 입력해 주는 편리한 템플릿입니다.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 14),
                  ZeroButton.primary(
                    label: '새 학생 등록 템플릿 추가하기',
                    icon: Icons.add_rounded,
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () => _openAddMemberTemplateDialog(context, catState),
                  ),
                  const SizedBox(height: 18),

                  if (catState.memberTemplates.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Text('등록된 템플릿이 없습니다. 우측 상단에서 새 템플릿을 만들어보세요.', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  else
                    ...catState.memberTemplates.map((template) {
                      final isSession = template.billingType == BillingType.sessionBased;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              backgroundColor: isSession ? const Color(0xFFEFF6FF) : const Color(0xFFECFDF5),
                              radius: 18,
                              child: Icon(
                                isSession ? Icons.confirmation_number_outlined : Icons.calendar_month_outlined,
                                color: isSession ? AppTheme.primaryBlue : AppTheme.softMint,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(template.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${template.groupName} · ${isSession ? '회차형 (${template.defaultSessions}회)' : '정기월납'} · ${currencyFormat.format(template.defaultFee)}원',
                                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 20),
                              onPressed: () async {
                                await ref.read(customCategoryProvider.notifier).removeMemberTemplate(template.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('\'${template.label}\' 템플릿이 삭제되었습니다.'), duration: const Duration(seconds: 1)),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openAddMemberTemplateDialog(BuildContext context, CustomCategoryState catState) {
    final labelCtrl = TextEditingController();
    final groupCtrl = TextEditingController(text: catState.groupCategories.isNotEmpty ? catState.groupCategories.first : '일반');
    final feeCtrl = TextEditingController(text: '300000');
    final sessionsCtrl = TextEditingController(text: '10');
    BillingType billingType = BillingType.monthlyRecurring;

    showDialog(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('새 학생 등록 템플릿', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: labelCtrl,
                      label: '템플릿 표시 이름',
                      hint: '예: 중등 수학 정규반, 1:1 PT 10회',
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: groupCtrl,
                      label: '수업 / 그룹명',
                      hint: '예: 중등수학, 기구필라테스',
                      prefixIcon: Icons.group_outlined,
                    ),
                    const SizedBox(height: 12),
                    const Text('수강 유형', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary)),
                    const SizedBox(height: 6),
                    SegmentedButton<BillingType>(
                      segments: const [
                        ButtonSegment(value: BillingType.monthlyRecurring, label: Text('정기 월납')),
                        ButtonSegment(value: BillingType.sessionBased, label: Text('회차 차감형')),
                      ],
                      selected: {billingType},
                      onSelectionChanged: (val) => setDlgState(() => billingType = val.first),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: feeCtrl,
                      label: '기본 수강료 (원)',
                      hint: '300000',
                      prefixIcon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    if (billingType == BillingType.sessionBased) ...[
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: sessionsCtrl,
                        label: '기본 회차',
                        hint: '10',
                        prefixIcon: Icons.confirmation_number_outlined,
                        keyboardType: TextInputType.number,
                      ),
                    ],
                  ],
                ),
              ),
              actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              actions: [
                ResponsiveDialogActions(
                  secondary: ZeroButton(
                    label: LocalizationService.tr('btn_cancel'),
                    variant: ZeroButtonVariant.neutral,
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () => Navigator.pop(dlgContext),
                  ),
                  primary: ZeroButton.primary(
                    label: '저장',
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () async {
                      final label = labelCtrl.text.trim();
                      final group = groupCtrl.text.trim();
                      final fee = int.tryParse(feeCtrl.text.replaceAll(',', '').trim()) ?? 0;
                      final sessions = int.tryParse(sessionsCtrl.text.trim()) ?? 0;

                      if (label.isEmpty || group.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('템플릿명과 그룹명을 입력해주세요.')));
                        return;
                      }

                      final newTemplate = MemberCategoryTemplate(
                        id: 'tpl_${DateTime.now().millisecondsSinceEpoch}',
                        label: label,
                        groupName: group,
                        billingType: billingType,
                        defaultFee: fee,
                        defaultSessions: billingType == BillingType.sessionBased ? sessions : 0,
                      );

                      await ref.read(customCategoryProvider.notifier).saveMemberTemplate(newTemplate);
                      if (dlgContext.mounted) Navigator.pop(dlgContext);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _openInvoiceTemplateManager(BuildContext context) {
    final currencyFormat = NumberFormat('#,###');

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final catState = ref.watch(customCategoryProvider).value ??
                CustomCategoryState.getDefaultsForIndustry('입시 / 보습학원');

            return SingleChildScrollView(
              padding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('청구 항목 및 금액 템플릿', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('청구서 작성 시 자주 사용하는 수납 항목과 권장 금액을 등록해 두면 터치 한 번으로 빠르게 청구서를 작성할 수 있습니다.',
                      style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
                  const SizedBox(height: 14),
                  ZeroButton.primary(
                    label: '새 청구 항목 템플릿 추가하기',
                    icon: Icons.add_rounded,
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () => _openAddInvoiceTemplateDialog(context),
                  ),
                  const SizedBox(height: 16),

                  if (catState.invoiceTemplates.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: const Text('등록된 청구 항목이 없습니다. 우측 상단에서 새 항목을 등록해보세요.', style: TextStyle(color: AppTheme.textSecondary)),
                    )
                  else
                    ...catState.invoiceTemplates.map((template) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Row(
                          children: [
                            const CircleAvatar(
                              backgroundColor: Color(0xFFF3E8FF),
                              radius: 18,
                              child: Icon(Icons.receipt_long_rounded, color: Color(0xFF8B5CF6), size: 18),
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
                                      Text(template.title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                                      if (template.category != null && template.category!.isNotEmpty)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFE0E7FF),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(template.category!, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4338CA))),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('기본 청구 금액 : ₩${currencyFormat.format(template.defaultAmount)}',
                                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 20),
                              onPressed: () async {
                                await ref.read(customCategoryProvider.notifier).removeInvoiceTemplate(template.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('\'${template.title}\' 항목이 삭제되었습니다.'), duration: const Duration(seconds: 1)),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                      );
                    }),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openAddInvoiceTemplateDialog(BuildContext context) {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController(text: '100000');
    final tagCtrl = TextEditingController(text: '정기수납');

    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('새 청구 항목 추가', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
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
            ResponsiveDialogActions(
              secondary: ZeroButton(
                label: LocalizationService.tr('btn_cancel'),
                variant: ZeroButtonVariant.neutral,
                size: ZeroButtonSize.medium,
                fullWidth: true,
                onPressed: () => Navigator.pop(dlgContext),
              ),
              primary: ZeroButton.primary(
                label: '저장',
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
                  if (dlgContext.mounted) Navigator.pop(dlgContext);
                },
              ),
            ),
          ],
        );
      },
    );
  }

  void _openIndustryPresetResetDialog(BuildContext context) {
    final presets = [
      {'category': '입시 / 보습학원', 'title': '📚 학원 · 공부방 · 보습학원', 'desc': '초·중·고등반, 정규수강료, 교재비, 특강비'},
      {'category': '피트니스 / PT', 'title': '🏋️ 피트니스 · PT · 헬스', 'desc': '1:1 PT, 듀엣, 헬스회원권, 락커/운동복'},
      {'category': '필라테스 / 요가', 'title': '🧘 필라테스 · 요가 · 댄스', 'desc': '개인 기구필라, 소그룹 리포머, 요가정기권'},
      {'category': '태권도 / 무술', 'title': '🥋 태권도 · 체육관 · 무술', 'desc': '유치부, 초등부, 시범단, 정기심사비, 도복비'},
      {'category': '음악 / 피아노', 'title': '🎨 음악 · 피아노 · 미술공방', 'desc': '피아노기초, 도예정규반, 가마소성비, 악보비'},
      {'category': '기타 / 맞춤업종', 'title': '🏢 기타 / 맞춤업종 (범용)', 'desc': '일반 정규반, 10회 이용권, 소모품/재료비'},
    ];

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.85,
      builder: (ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('원터치 업종별 프리셋 불러오기', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
              const SizedBox(height: 6),
              const Text('선택하신 업종에 가장 최적화된 그룹 및 청구 서식으로 일괄 재구성합니다. 기존 서식은 해당 업종의 기본 템플릿으로 교체됩니다.',
                  style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4)),
              const SizedBox(height: 16),
              ...presets.map((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE2E8F0)),
                    ),
                    tileColor: const Color(0xFFF8FAFC),
                    title: Text(p['title']!, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                    subtitle: Text(p['desc']!, style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppTheme.textSecondary),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await ref.read(customCategoryProvider.notifier).resetToIndustry(p['category']!);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('${p['title']} 템플릿 프리셋이 성공적으로 적용되었습니다.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                  ),
                );
              }),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }
}
