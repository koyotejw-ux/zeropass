import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/chosung_search_service.dart';
import '../services/database_service.dart';
import '../services/kakao_share_service.dart';
import '../services/sms_template_service.dart';
import '../services/coach_mark_service.dart';
import '../services/monetization_service.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coach_mark_dialog.dart';
import '../widgets/digital_pass_card_dialog.dart';
import '../widgets/interactive_guide_dialog.dart';
import '../widgets/mascot_avatar.dart';
import '../widgets/signature_key_visual_hero.dart';
import '../widgets/smart_notification_center_modal.dart';
import '../widgets/attendance_notify_dialog.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/design_system.dart';
import '../widgets/native_inline_ad_card.dart';
import '../widgets/senior_easy_guide_modal.dart';
import '../widgets/schedule_calendar_modal.dart';
import 'home_navigation_screen.dart';
import 'onboarding_screen.dart';
import 'pro_store_screen.dart';
import 'tablet_kiosk_screen.dart';

class PassDashboardScreen extends ConsumerStatefulWidget {
  const PassDashboardScreen({super.key});

  @override
  ConsumerState<PassDashboardScreen> createState() => _PassDashboardScreenState();
}

class _PassDashboardScreenState extends ConsumerState<PassDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _selectedGroup = LocalizationService.tr('all_groups');
  String _statusFilter = '전체'; // '전체', '출결 대기', '체크 완료', '만료 임박'

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openInteractiveGuide(BuildContext context) {
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
                const ZeroPassMascotAvatar(
                  size: 42,
                  icon: Icons.menu_book_rounded,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService.pick(
                          ko: '패시 가이드 센터',
                          en: 'Passy Guide Center',
                          ja: 'ガイドセンター',
                          zh: '使用指南中心',
                          vi: 'Trung tâm hướng dẫn',
                          es: 'Centro de guía',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocalizationService.pick(
                          ko: '원하시는 안내 가이드를 선택해주세요',
                          en: 'Choose a walkthrough guide below',
                          ja: 'ご希望のガイドをお選びください',
                          zh: '请选择您想查看的引导指南',
                          vi: 'Chọn hướng dẫn bạn muốn xem',
                          es: 'Elige una guía paso a paso',
                        ),
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppTheme.textSecondary,
                        ),
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
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              tileColor: const Color(0xFFF8FAFC),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_stories_rounded, color: AppTheme.primaryBlue),
              ),
              title: Text(
                LocalizationService.pick(
                  ko: '서비스 첫걸음 핵심 소개 (온보딩)',
                  en: 'App Feature Overview (Onboarding)',
                  ja: '機能紹介ガイド（オンボーディング）',
                  zh: '核心功能介绍（新手引导）',
                  vi: 'Giới thiệu tính năng chính',
                  es: 'Introducción de funciones',
                ),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              subtitle: Text(
                LocalizationService.pick(
                  ko: '서버비 0원 출결, 무료 문자, 스마트 장부 기능 둘러보기',
                  en: 'Explore offline check-in, zero-fee invoicing & tax ledger',
                  ja: 'オフライン出席・請求・税務帳簿機能を見る',
                  zh: '了解本地签到、免费对账与多国税务台账功能',
                  vi: 'Khám phá điểm danh offline, hóa đơn & sổ thuế',
                  es: 'Explora registro local, cobros y libro fiscal',
                ),
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OnboardingScreen(onFinish: () => Navigator.pop(context))),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              tileColor: const Color(0xFFF8FAFC),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.softMint.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.checklist_rounded, color: AppTheme.softMint),
              ),
              title: Text(
                LocalizationService.pick(
                  ko: '스텝바이스텝 실전 연습 코칭',
                  en: 'Step-by-Step Interactive Practice',
                  ja: 'ステップ式実践コーチング',
                  zh: '手把手实战引导教学',
                  vi: 'Hướng dẫn thực hành từng bước',
                  es: 'Guía práctica paso a paso',
                ),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              subtitle: Text(
                LocalizationService.pick(
                  ko: '스튜디오 정보 설정부터 실제 회원 등록 및 출결 체크 실습',
                  en: 'Practice setting up studio, adding members & checking in',
                  ja: 'スタジオ設定から会員登録・出席チェックまで練習',
                  zh: '从门店设置到添加学员与首次签到的全流程练习',
                  vi: 'Thực hành từ cài đặt trung tâm đến điểm danh',
                  es: 'Practica configurar tu centro, añadir miembros y registrar',
                ),
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              onTap: () {
                Navigator.pop(ctx);
                StepByStepPracticeGuideDialog.show(
                  context,
                  onOpenAddMember: () {
                    HomeNavigationScreen.of(context)?.switchToTab(3);
                  },
                  onOpenSettings: () {
                    HomeNavigationScreen.of(context)?.switchToTab(4);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }


  void _openTabletKioskMode(BuildContext context) {
    // Check if Kiosk Pro unlocked
    final isUnlocked = MonetizationService.instance.isKioskProUnlocked;

    if (isUnlocked) {
      _showKioskLaunchSelector(context);
    } else {
      // Show Kiosk Pro Unlock & Free Trial Offer
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          actionsOverflowButtonSpacing: 8,
          actionsOverflowDirection: VerticalDirection.down,
          actionsAlignment: MainAxisAlignment.end,
          title: Row(
            children: [
              const Icon(Icons.tablet_mac_rounded, color: AppTheme.primaryBlue, size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    LocalizationService.pick(
                      ko: '태블릿 자율출결 키오스크',
                      en: 'Tablet Self Check-in Kiosk',
                      ja: 'タブレット無人受付キオスク',
                      zh: '平板自助考勤终端',
                      vi: 'Kiosk điểm danh tự động',
                      es: 'Quiosco de registro Tablet',
                    ),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Color(0xFF2563EB), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LocalizationService.pick(
                            ko: '매장 입구에 거치해 두면 학생들이 직접 뒷번호 4자리만 누르고 입장!',
                            en: 'Place a tablet at your entrance for 1-tap PIN or Name check-in!',
                            ja: '入口にタブレットを置けば下4桁または名前で即出席！',
                            zh: '放在前台入口即可让学员自助输入4位尾号或姓名签到！',
                            vi: 'Đặt tại quầy để học viên tự nhập PIN 4 số hoặc tên!',
                            es: 'Coloca la tablet en la entrada para registro por PIN o nombre.',
                          ),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.bolt_rounded, size: 16, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LocalizationService.pick(
                                ko: '1초 출석 체크 + 잔여 회차 자동 차감',
                                en: '1-second check-in + auto session deduction',
                                ja: '1秒チェックイン＋残回数自動消化',
                                zh: '1秒快速签到并自动扣除剩余课时',
                                vi: 'Điểm danh 1 giây + tự động trừ buổi',
                                es: 'Check-in en 1s + descuento automático',
                              ),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.mark_chat_read_outlined, size: 16, color: AppTheme.softMint),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LocalizationService.pick(
                                ko: '즉시 학부모/회원 안심 문자 전송',
                                en: 'Instant guardian / member confirmation alert',
                                ja: '保護者・会員様への即時安心通知',
                                zh: '即时生成家长/会员安全到校提醒',
                                vi: 'Thông báo xác nhận tức thì cho phụ huynh/học viên',
                                es: 'Aviso inmediato para miembros o tutores',
                              ),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          const Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LocalizationService.pick(
                                ko: '관리자 비밀번호(0000) 잠금 보호',
                                en: 'Admin PIN (0000) exit lock protection',
                                ja: '管理者PIN（0000）によるロック保護',
                                zh: '管理员密码 (0000) 防误退锁定保护',
                                vi: 'Bảo vệ bằng mã PIN quản trị (0000)',
                                es: 'Protegido con PIN de administrador (0000)',
                              ),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.savings_outlined, size: 16, color: Color(0xFF10B981)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LocalizationService.pick(
                                ko: '타사 월 3~5만원 키오스크 대비 0원 유지비',
                                en: 'No expensive kiosk hardware required',
                                ja: '専用端末不要でコスト大幅削減',
                                zh: '无需高价采购专用考勤硬件',
                                vi: 'Không cần thiết bị chuyên dụng đắt tiền',
                                es: 'Sin costes caros de hardware dedicado',
                              ),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.workspace_premium_rounded, size: 14, color: Color(0xFFD97706)),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              LocalizationService.pick(
                                ko: '정기 구독 시 광고 완전 제거 + 무인 키오스크 무제한',
                                en: 'Subscribe for 100% Ad-Free + Unlimited Kiosk Mode',
                                ja: 'サブスクリプションで広告非表示＋キオスク無制限',
                                zh: '订阅解锁免广告 + 无限次自助终端模式',
                                vi: 'Đăng ký để tắt quảng cáo + mở khóa Kiosk',
                                es: 'Suscríbete para quitar anuncios y usar Quiosco ilimitado',
                              ),
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: Color(0xFFB45309)),
                            ),
                          ),
                        ],
                      ),
                      if (LocalizationService.isDomestic) ...[
                        const SizedBox(height: 4),
                        Text(
                          '지금까지 체크앤페이로 절감한 누적 가치: 약 ${NumberFormat("#,###").format(MonetizationService.instance.estimatedTotalSavedKRW)}원!',
                          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: Color(0xFF92400E)),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ZeroButton.primary(
                  label: LocalizationService.pick(
                    ko: '월 4,900원 키오스크 구독 시작',
                    en: 'Unlock Kiosk Plan',
                    ja: 'キオスクプランを見る',
                    zh: '查看考勤机订阅方案',
                    vi: 'Mở khóa gói Kiosk',
                    es: 'Ver plan Quiosco',
                  ),
                  icon: Icons.workspace_premium_rounded,
                  size: ZeroButtonSize.medium,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProStoreScreen()),
                    );
                  },
                ),
                const SizedBox(height: 8),
                if (MonetizationService.instance.canClaimTemporaryPass)
                  ZeroButton(
                    label: LocalizationService.pick(
                      ko: '짧은 광고 보고 1시간 무료 개방',
                      en: 'Watch Ad for 1h Free Unlock',
                      ja: '動画を見て1時間無料で開放',
                      zh: '看视频免费体验 1 小时',
                      vi: 'Xem quảng cáo mở miễn phí 1 giờ',
                      es: 'Ver anuncio (1h gratis)',
                    ),
                    icon: Icons.play_circle_outline_rounded,
                    variant: ZeroButtonVariant.neutral,
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () {
                      Navigator.pop(ctx);
                      MonetizationService.instance.launchTemporaryPassFlow(
                        context,
                        preferRewardedInterstitial: true,
                        onGranted: () {
                          if (context.mounted) {
                            _showKioskLaunchSelector(context);
                          }
                        },
                      );
                    },
                  ),
                const SizedBox(height: 8),
                ZeroButton(
                  label: LocalizationService.tr('kiosk_empty_demo_btn'),
                  variant: ZeroButtonVariant.secondary,
                  size: ZeroButtonSize.medium,
                  fullWidth: true,
                  onPressed: () {
                    Navigator.pop(ctx);
                    _showKioskLaunchSelector(context);
                  },
                ),
              ],
            ),
          ],
        ),
      );
    }
  }

  /// 키오스크 시작 전 학생 데이터 존재 여부 확인 및 [학생 운영용] vs [원장님 기능 테스트용] 분기
  void _showKioskLaunchSelector(BuildContext context) {
    final members = ref.read(membersProvider).value ?? [];

    // 1. 등록된 학생이 0명인 경우 -> 데이터 부재 안내 및 샘플 등록 / 테스트 모드 선택 모달
    if (members.isEmpty) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 26),
              const SizedBox(width: 8),
              Expanded(
                child: Text(LocalizationService.tr('kiosk_empty_title'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          content: Text(
            LocalizationService.tr('kiosk_empty_desc'),
            style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textPrimary),
          ),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ZeroButton.primary(
                  label: LocalizationService.tr('kiosk_empty_seed_btn'),
                  icon: Icons.group_add_rounded,
                  size: ZeroButtonSize.medium,
                  fullWidth: true,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await DatabaseService.instance.restoreSampleData();
                    await ref.read(membersProvider.notifier).reload();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(LocalizationService.tr('kiosk_empty_seed_btn'))),
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
                  label: LocalizationService.tr('kiosk_empty_demo_btn'),
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
                  label: LocalizationService.tr('common_close'),
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
      return;
    }

    // 2. 학생이 등록되어 있는 경우 -> [📱 운영 키오스크] vs [🧪 기능 테스트] 선택 바텀시트
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
                    color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.tablet_mac_rounded, color: AppTheme.primaryBlue, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService.tr('kiosk_brand_title'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocalizationService.pick(
                          ko: '실제 출석용 또는 관리자 기능 테스트 중 선택하세요.',
                          en: 'Choose Live Kiosk mode or Admin Demo simulation.',
                          ja: '本番用キオスクまたはテストモードをお選びください。',
                          zh: '请选择正式考勤模式或管理员演示测试模式。',
                          vi: 'Chọn chế độ Kiosk thực tế hoặc Chế độ thử nghiệm.',
                          es: 'Elige entre Quiosco real o simulación de prueba.',
                        ),
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
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: AppTheme.primaryBlue.withValues(alpha: 0.35), width: 1.2),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEFF6FF),
                  child: Icon(Icons.touch_app_rounded, color: AppTheme.primaryBlue),
                ),
                title: Text(
                  LocalizationService.pick(
                    ko: '학생 출결 키오스크 (실제 운영용)',
                    en: 'Live Member Check-in Kiosk',
                    ja: '本番用 セルフ受付キオスク',
                    zh: '正式营业自助考勤终端',
                    vi: 'Kiosk điểm danh chính thức',
                    es: 'Quiosco de asistencia real',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  LocalizationService.pick(
                    ko: '입구 태블릿 거치용 전체화면. 체험 핀이 일체 노출되지 않는 클린 화면입니다.',
                    en: 'Clean fullscreen reception display for members (no demo badges).',
                    ja: '入口設置用のフルスクリーン画面（テストピン非表示）。',
                    zh: '门店入口全屏界面，隐藏所有测试标记与体验密码。',
                    vi: 'Màn hình toàn màn hình đặt tại quầy (ẩn mã thử nghiệm).',
                    es: 'Pantalla completa limpia para recepción (sin badges demo).',
                  ),
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TabletKioskScreen(isTestMode: false)),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: const Color(0xFF6366F1).withValues(alpha: 0.35), width: 1.2),
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                leading: const CircleAvatar(
                  backgroundColor: Color(0xFFEEF2FF),
                  child: Icon(Icons.science_rounded, color: Color(0xFF6366F1)),
                ),
                title: Text(
                  LocalizationService.pick(
                    ko: '키오스크 기능 테스트 (체험 모드)',
                    en: 'Interactive Kiosk Demo Simulation',
                    ja: 'キオスク機能テスト（体験モード）',
                    zh: '考勤终端功能测试（演示模式）',
                    vi: 'Thử nghiệm Kiosk (Chế độ mẫu)',
                    es: 'Prueba de Quiosco (Modo Demo)',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  LocalizationService.pick(
                    ko: '1234 체험 핀으로 출결 완료 축하 및 알림 화면 결과를 즉시 확인합니다.',
                    en: 'Test celebration & alert flow immediately with Demo PIN 1234.',
                    ja: '体験PIN「1234」で完了画面や通知動作をすぐ確認できます。',
                    zh: '使用体验码 1234 即可立即预览签到成功动画与通知效果。',
                    vi: 'Dùng mã thử 1234 để kiểm tra màn hình hoàn tất & thông báo.',
                    es: 'Usa el PIN 1234 para probar la pantalla de confirmación.',
                  ),
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const TabletKioskScreen(isTestMode: true)),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    ref.watch(currencyProvider);
    final membersAsync = ref.watch(membersProvider);
    final passRecordsAsync = ref.watch(passRecordsProvider);
    final studioAsync = ref.watch(studioProfileProvider);
    final isSeniorMode = ref.watch(seniorModeProvider);

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        toolbarHeight: isLandscape ? 54 : 64,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLandscape) ...[
              Text(
                LocalizationService.formatHeaderDate(DateTime.now()),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 1),
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                LocalizationService.tr('tab_pass'),
                style: TextStyle(
                  fontSize: isLandscape ? 17 : 20,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // 0. 무인 자율출결 키오스크 (일반 폰/태블릿으로 운영 → 심플 태블릿 아웃라인 아이콘, 우측 아이콘 세트와 동일 계열·동일 크기)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.tablet_android_outlined, size: 21, color: Color(0xFF3F3F46)),
              tooltip: LocalizationService.pick(
                ko: '무인 키오스크 모드',
                en: 'Self Check-In Kiosk Mode',
                ja: 'セルフチェックインキオスク',
                zh: '自助考勤终端模式',
                vi: 'Chế độ Kiosk tự điểm danh',
                es: 'Modo Quiosco de Asistencia',
              ),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () => _openTabletKioskMode(context),
            ),
          ),
          // 1. 스케줄 달력 (주요일정 & 출결 캘린더)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.calendar_month_outlined, size: 21, color: Color(0xFF3F3F46)),
              tooltip: LocalizationService.pick(
                ko: '스케줄 달력',
                en: 'Schedule Calendar',
                ja: '予定カレンダー',
                zh: '课程日程表',
                vi: 'Lịch trình',
                es: 'Calendario',
              ),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () => ScheduleCalendarModal.show(context),
            ),
          ),
          // 2. 스마트 안심 알림 센터 (심플 라인 아이콘)
          SizedBox(
            width: 40,
            height: 40,
            child: IconButton(
              icon: const Icon(Icons.notifications_none_rounded, size: 21, color: Color(0xFF3F3F46)),
              tooltip: LocalizationService.pick(
                ko: '안심 알림 센터',
                en: 'Notification Center',
                ja: '通知センター',
                zh: '安全通知中心',
                vi: 'Trung tâm thông báo',
                es: 'Centro de avisos',
              ),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () => SmartNotificationCenterModal.show(context),
            ),
          ),
          // 3. 시니어 큰글씨 모드 퀵 토글 (공통: 가장 우측 배치)
          Padding(
            padding: const EdgeInsets.only(right: 6),
            child: IconButton(
              icon: Icon(
                Icons.format_size_rounded,
                size: 21,
                color: isSeniorMode ? AppTheme.trustBlue : const Color(0xFF3F3F46),
              ),
              tooltip: LocalizationService.tr('senior_easy_mode'),
              splashRadius: 20,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
              visualDensity: VisualDensity.compact,
              onPressed: () => ref.read(seniorModeProvider.notifier).toggle(),
            ),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
        data: (members) {
          return passRecordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err')),
            data: (passRecords) {
              final studio = studioAsync.value ?? StudioProfile.defaultProfile();

              // Calculate today's stats
              final now = DateTime.now();
              final todayRecords = passRecords.where((r) {
                return r.timestamp.year == now.year &&
                    r.timestamp.month == now.month &&
                    r.timestamp.day == now.day;
              }).toList();

              final checkedMemberIds = todayRecords.map((r) => r.memberId).toSet();
              final attendedCount = todayRecords.where((r) => r.status == AttendanceStatus.attended).length;
              final lateCount = todayRecords.where((r) => r.status == AttendanceStatus.late).length;
              final remainingMembersCount = members.where((m) => !checkedMemberIds.contains(m.id)).length;

              // Long Absent Golden-Time Members (7 days or more)
              final inactiveThreshold = now.subtract(const Duration(days: 7));
              final absentMembers = members.where((m) {
                final memberRecs = passRecords.where((r) => r.memberId == m.id).toList();
                if (memberRecs.isEmpty) {
                  return m.registeredAt.isBefore(inactiveThreshold);
                }
                memberRecs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
                return memberRecs.first.timestamp.isBefore(inactiveThreshold);
              }).toList();

              // Extract all groups
              final groups = [LocalizationService.tr('all_groups'), ...members.map((m) => m.groupName).toSet()];

              // Filter members list using ChosungSearchService and Status filters
              var filteredMembers = members.where((m) {
                if (_selectedGroup != LocalizationService.tr('all_groups') && m.groupName != _selectedGroup) {
                  return false;
                }
                final isChecked = checkedMemberIds.contains(m.id);
                if (_statusFilter == '출결 대기' && isChecked) return false;
                if (_statusFilter == '체크 완료' && !isChecked) return false;
                if (_statusFilter == '만료 임박') {
                  final isSession = m.billingType == BillingType.sessionBased;
                  if (!isSession || m.remainingSessions > 2) return false;
                }
                if (_statusFilter == '골든타임 케어') {
                  if (!absentMembers.any((ab) => ab.id == m.id)) return false;
                }
                if (_searchQuery.isNotEmpty) {
                  if (!ChosungSearchService.matchesAny([m.name, m.phone, m.groupName, m.payerName, m.memo], _searchQuery)) {
                    return false;
                  }
                }
                return true;
              }).toList();

              final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0 ||
                  View.of(context).viewInsets.bottom > 0;
              final isSearching = _searchQuery.isNotEmpty || _searchFocusNode.hasFocus;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isShortHeight = constraints.maxHeight < 560;
                  final hideHero = isLandscape || isKeyboardOpen || isSearching || isShortHeight;

                  return Column(
                    children: [
                      // Full Body Scroll with Sticky Search and Sub-tabs Header
                      Expanded(
                        child: CustomScrollView(
                          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                          slivers: [
                            // 1. Signature Key Visual Hero (Living Aurora Glass & Pulse Radar) or Senior Easy Board
                            if (!hideHero)
                              SliverToBoxAdapter(
                                child: isSeniorMode
                                    ? _buildSeniorEasyBoard(
                                        context: context,
                                        members: members,
                                        todayRecords: todayRecords,
                                        studio: studio,
                                      )
                                    : SignatureKeyVisualHero(
                                        members: members,
                                        todayRecords: todayRecords,
                                        studio: studio,
                                        activeFilter: _statusFilter,
                                        onFilterSelected: (selectedFilter) {
                                          setState(() {
                                            if (_statusFilter == selectedFilter) {
                                              _statusFilter = '전체';
                                            } else {
                                              _statusFilter = selectedFilter;
                                            }
                                          });
                                        },
                                        onOpenKiosk: () => _openTabletKioskMode(context),
                                        onOpenGuide: () => _openInteractiveGuide(context),
                                      ),
                              ),

                            // Landscape Compact Metric Card Fallback
                            if (isLandscape)
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  child: Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: AppTheme.cardShadow,
                                      border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                                      children: [
                                        _buildStatItem(LocalizationService.tr('checked_in'), attendedCount, AppTheme.softMint, isCompact: true),
                                        _buildDivider(),
                                        _buildStatItem(
                                          LocalizationService.pick(
                                            ko: '지각/조퇴',
                                            en: 'Late/Early',
                                            ja: '遅刻・早退',
                                            zh: '迟到/早退',
                                            vi: 'Muộn/Sớm',
                                            es: 'Tarde/Antes',
                                          ),
                                          lateCount,
                                          AppTheme.warning,
                                          isCompact: true,
                                        ),
                                        _buildDivider(),
                                        _buildStatItem(
                                          LocalizationService.pick(
                                            ko: '남은 인원',
                                            en: 'Remaining',
                                            ja: '残りの人数',
                                            zh: '待到人数',
                                            vi: 'Còn lại',
                                            es: 'Pendientes',
                                          ),
                                          remainingMembersCount,
                                          AppTheme.primaryBlue,
                                          isCompact: true,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                            // Golden Time Care Strip (Concise Single-Line + Detail Explanation Modal)
                            if (absentMembers.isNotEmpty && _statusFilter != '골든타임 케어')
                              SliverToBoxAdapter(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
                                  child: ZeroNoticeBanner(
                                    title: '${LocalizationService.tr("golden_time_care")} (${absentMembers.length})',
                                    actionLabel: LocalizationService.tr('view_details'),
                                    icon: Icons.favorite_border_rounded,
                                    variant: ZeroBannerVariant.care,
                                    onAction: () => _showGoldenTimeExplanationModal(context, absentMembers),
                                  ),
                                ),
                              ),

                            // 2. Pinned Sticky Search and Sub-tabs Filter Chips Header
                            SliverPersistentHeader(
                              pinned: true,
                              delegate: _StickySearchAndFilterHeaderDelegate(
                                searchController: _searchController,
                                searchFocusNode: _searchFocusNode,
                                searchQuery: _searchQuery,
                                onSearchChanged: (val) => setState(() => _searchQuery = val.trim()),
                                onSearchClear: () {
                                  _searchController.clear();
                                  setState(() => _searchQuery = '');
                                  _searchFocusNode.unfocus();
                                },
                                groups: groups,
                                selectedGroup: _selectedGroup,
                                onGroupSelected: (g) => setState(() => _selectedGroup = g),
                                statusFilter: _statusFilter,
                                onStatusFilterSelected: (val) => setState(() => _statusFilter = val),
                              ),
                            ),

                            // 3. Member Pass Cards List (Scrolls smoothly beneath the pinned header)
                            if (filteredMembers.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.event_available_outlined, size: 48, color: AppTheme.textTertiary),
                                      const SizedBox(height: 12),
                                      Text(
                                        LocalizationService.tr('no_matching_members'),
                                        style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            else
                              SliverPadding(
                                padding: EdgeInsets.fromLTRB(16, 6, 16, isKeyboardOpen ? 12 : 90),
                                sliver: SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      if (index == filteredMembers.length) {
                                        return const NativeInlineAdCard(placementTag: 'pass_list');
                                      }
                                      final member = filteredMembers[index];
                                      final isChecked = checkedMemberIds.contains(member.id);
                                      final todayPass = isChecked
                                          ? todayRecords.firstWhere((r) => r.memberId == member.id)
                                          : null;

                                      return _buildMemberPassCard(
                                        context,
                                        member,
                                        isChecked,
                                        todayPass,
                                        studio,
                                        absentMembers.any((m) => m.id == member.id),
                                      );
                                    },
                                    childCount: filteredMembers.length + 1,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),

                  // Batch Action Bar placed directly inside body above bottom navigation bar / keyboard
                  Builder(
                    builder: (ctx) {
                      final searchRemainingMembers = filteredMembers.where((m) => !checkedMemberIds.contains(m.id)).toList();
                      final isSearchActive = _searchQuery.isNotEmpty;
                      final targetCount = isSearchActive ? searchRemainingMembers.length : remainingMembersCount;

                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: isLandscape ? 6 : (isKeyboardOpen ? 8 : 9),
                        ),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          border: Border(top: BorderSide(color: AppTheme.borderSubtle, width: 0.8)),
                        ),
                        child: SafeArea(
                          top: false,
                          bottom: false,
                          child: Row(
                            children: [
                              Expanded(
                                child: ZeroButton(
                                  label: isSearchActive
                                      ? (targetCount > 0
                                          ? LocalizationService.pick(
                                              ko: '검색 결과 일괄 출석 ($targetCount명)',
                                              en: 'Check In Filtered ($targetCount)',
                                              ja: '検索結果を一括出席 ($targetCount名)',
                                              zh: '一键签到搜索结果 ($targetCount人)',
                                              vi: 'Điểm danh kết quả ($targetCount)',
                                              es: 'Registrar filtrados ($targetCount)',
                                            )
                                          : LocalizationService.pick(
                                              ko: '검색 회원 출석 완료됨',
                                              en: 'Filtered Members Checked In',
                                              ja: '検索会員は全員出席済み',
                                              zh: '搜索结果已全部签到',
                                              vi: 'Đã điểm danh nhóm lọc',
                                              es: 'Filtrados ya registrados',
                                            ))
                                      : (targetCount > 0
                                          ? LocalizationService.pick(
                                              ko: isLandscape ? '남은 회원 일괄 출석 ($targetCount명)' : '남은 회원 일괄 출석 완료 ($targetCount명)',
                                              en: 'Batch Check-in Remaining ($targetCount)',
                                              ja: '残り会員を一括出席 ($targetCount名)',
                                              zh: '一键批量签到剩余学员 ($targetCount人)',
                                              vi: 'Điểm danh tất cả còn lại ($targetCount)',
                                              es: 'Registro masivo restantes ($targetCount)',
                                            )
                                          : (members.isEmpty
                                              ? LocalizationService.tr('kiosk_empty_title')
                                              : LocalizationService.pick(
                                                  ko: '오늘 모든 회원 출석 완료',
                                                  en: 'All Members Checked In Today',
                                                  ja: '本日の全会員が出席完了',
                                                  zh: '今日所有学员已全部签到',
                                                  vi: 'Hôm nay tất cả đã điểm danh',
                                                  es: 'Todos registrados hoy',
                                                ))),
                                  icon: Icons.done_all_rounded,
                                  variant: targetCount > 0 ? ZeroButtonVariant.tint : ZeroButtonVariant.neutral,
                                  size: isLandscape ? ZeroButtonSize.medium : ZeroButtonSize.large,
                                  fullWidth: true,
                                  onPressed: targetCount > 0
                                      ? () => _handleBatchCheckIn(
                                            context,
                                            targetMembers: isSearchActive ? filteredMembers : null,
                                          )
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    },
  ),
);
}

  Widget _buildStatItem(String label, int count, Color color, {bool isCompact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: isCompact ? 17 : 22,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 11 : 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppTheme.borderSubtle,
    );
  }

  Widget _buildMemberPassCard(
    BuildContext context,
    Member member,
    bool isChecked,
    PassRecord? todayPass,
    StudioProfile studio, [
    bool isLongAbsent = false,
  ]) {
    final isSessionBased = member.billingType == BillingType.sessionBased;
    final isDepleted = isSessionBased && member.remainingSessions == 0;
    final isExpiringSoon = isSessionBased && member.remainingSessions > 0 && member.remainingSessions <= 2;
    final isAtRisk = isDepleted || isExpiringSoon;
    final isSeniorMode = ref.watch(seniorModeProvider);

    Widget buildCardBadge() {
      if (isChecked) {
        return ZeroBadge.success(
          todayPass?.status == AttendanceStatus.late
              ? LocalizationService.pick(ko: '지각', en: 'Late', ja: '遅刻', zh: '迟到', vi: 'Đi muộn', es: 'Tarde')
              : LocalizationService.tr('checked_in'),
          size: ZeroBadgeSize.medium,
          icon: Icons.check_circle_rounded,
        );
      } else if (isDepleted) {
        return ZeroBadge.danger(
          LocalizationService.pick(
            ko: '회차 소진 (0회)',
            en: 'Depleted (0 left)',
            ja: '回数終了 (残0)',
            zh: '课时用尽 (剩0)',
            vi: 'Hết buổi (0)',
            es: 'Agotado (0)',
          ),
          size: ZeroBadgeSize.medium,
        );
      } else if (isExpiringSoon) {
        return ZeroBadge.warning(
          '${LocalizationService.tr('expiring_soon')} (${member.remainingSessions})',
          size: ZeroBadgeSize.medium,
        );
      } else {
        return ZeroBadge.neutral(
          isSessionBased
              ? LocalizationService.trParams('common_sessions_left', {'n': '${member.remainingSessions}'})
              : LocalizationService.tr('billing_type_monthly'),
          size: ZeroBadgeSize.medium,
        );
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(16, 13, 16, 13),
      decoration: BoxDecoration(
        color: isChecked ? const Color(0xFFF8FAFC) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isChecked
              ? AppTheme.softMint.withAlpha((255 * 0.35).round())
              : (isDepleted
                  ? const Color(0xFFFDA4AF)
                  : (isExpiringSoon ? const Color(0xFFFDE68A) : const Color(0xFFE2E8F0))),
          width: (isChecked || isAtRisk) ? 1.2 : 0.9,
        ),
        boxShadow: isChecked ? null : AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Meta Row: Course & Group <-> Attendance Status Badge
          if (isSeniorMode)
            Row(
              children: [
                buildCardBadge(),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      [
                        if (member.secondaryTag != null && member.secondaryTag!.isNotEmpty) member.secondaryTag!,
                        if (member.groupName.isNotEmpty) LocalizationService.localizeBuiltInLabel(member.groupName),
                        if ((member.secondaryTag == null || member.secondaryTag!.isEmpty) && member.groupName.isEmpty)
                          LocalizationService.localizeBuiltInLabel('일반'),
                      ].join(' · '),
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      [
                        if (member.secondaryTag != null && member.secondaryTag!.isNotEmpty) member.secondaryTag!,
                        if (member.groupName.isNotEmpty) LocalizationService.localizeBuiltInLabel(member.groupName),
                        if ((member.secondaryTag == null || member.secondaryTag!.isEmpty) && member.groupName.isEmpty)
                          LocalizationService.localizeBuiltInLabel('일반'),
                      ].join(' · '),
                      softWrap: true,
                      style: const TextStyle(
                        fontFamily: 'Pretendard',
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF475569),
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                buildCardBadge(),
              ],
            ),

          const SizedBox(height: 10),

          // 2. Primary Member Identity (UNCONSTRAINED FULL WIDTH: Avatar + Name + Sessions)
          if (isSeniorMode)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    ZeroAvatar(
                      name: member.name,
                      size: ZeroAvatarSize.medium,
                      backgroundColor: isChecked ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                      textColor: isChecked ? AppTheme.softMint : AppTheme.primaryDark,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        member.name,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        DigitalPassCardDialog.show(
                          context: context,
                          member: member,
                          studio: studio,
                          latestRecord: todayPass,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                        ),
                        child: const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Text(
                    isSessionBased
                        ? '${member.remainingSessions} / ${member.totalSessions} ${LocalizationService.tr('billing_type_session')}'
                        : LocalizationService.tr('common_monthly_pass'),
                    style: TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: isExpiringSoon ? const Color(0xFFE11D48) : const Color(0xFF64748B),
                    ),
                  ),
                ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ZeroAvatar(
                  name: member.name,
                  size: ZeroAvatarSize.medium,
                  backgroundColor: isChecked ? const Color(0xFFECFDF5) : const Color(0xFFF1F5F9),
                  textColor: isChecked ? AppTheme.softMint : AppTheme.primaryDark,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        member.name,
                        softWrap: true,
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        isSessionBased
                            ? LocalizationService.pick(
                                ko: '잔여 회차: ${member.remainingSessions}회 / 총 ${member.totalSessions}회',
                                en: 'Sessions: ${member.remainingSessions} / ${member.totalSessions} left',
                                ja: '残回数: ${member.remainingSessions}回 / 計${member.totalSessions}回',
                                zh: '剩余课时: ${member.remainingSessions}次 / 共${member.totalSessions}次',
                                vi: 'Buổi còn: ${member.remainingSessions} / ${member.totalSessions}',
                                es: 'Sesiones: ${member.remainingSessions} / ${member.totalSessions}',
                              )
                            : LocalizationService.tr('common_monthly_pass'),
                        style: TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: isDepleted
                              ? const Color(0xFFE11D48)
                              : (isExpiringSoon ? const Color(0xFFD97706) : const Color(0xFF64748B)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    DigitalPassCardDialog.show(
                      context: context,
                      member: member,
                      studio: studio,
                      latestRecord: todayPass,
                    );
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE2E8F0), width: 0.8),
                    ),
                    child: const Icon(Icons.qr_code_2_rounded, size: 20, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),

          const SizedBox(height: 12),

          // 3. Action Buttons with Session Recharge & Live Status Transition
          if (!isChecked)
            Row(
              children: [
                Expanded(
                  flex: isAtRisk ? 5 : 10,
                  child: SizedBox(
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () => _handleOneTouchCheckIn(member),
                      icon: const Icon(Icons.check_rounded, size: 20),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isDepleted
                              ? LocalizationService.pick(
                                  ko: '출석(0회)',
                                  en: 'Check In (0)',
                                  ja: '出席(残0)',
                                  zh: '签到(剩0)',
                                  vi: 'Điểm danh (0)',
                                  es: 'Registro (0)',
                                )
                              : LocalizationService.pick(
                                  ko: '체크인',
                                  en: 'Check In',
                                  ja: 'チェックイン',
                                  zh: '签到',
                                  vi: 'Điểm danh',
                                  es: 'Registrar',
                                ),
                          style: const TextStyle(
                            fontFamily: 'Pretendard',
                            fontSize: 15.0,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isDepleted ? const Color(0xFFE11D48) : AppTheme.primaryDark,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ),
                if (isAtRisk) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 5,
                    child: SizedBox(
                      height: 48,
                      child: ZeroButton.tint(
                        label: LocalizationService.pick(
                          ko: '+10회 충전',
                          en: '+10 Top Up',
                          ja: '+10回追加',
                          zh: '+10次充值',
                          vi: '+10 buổi',
                          es: '+10 Sesiones',
                        ),
                        maxLines: 1,
                        icon: Icons.add_circle_outline_rounded,
                        size: ZeroButtonSize.medium,
                        fullWidth: true,
                        onPressed: () async {
                          HapticFeedback.lightImpact();
                          await ref.read(membersProvider.notifier).addSessions(member.id, 10);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('${member.primaryName} +10 (${member.remainingSessions + 10})'),
                                duration: const Duration(seconds: 3),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ],
            )
          else ...[
            if (isAtRisk) ...[
              ZeroButton.tint(
                label: LocalizationService.pick(
                  ko: '${member.primaryName} 10회 충전 (현재 ${member.remainingSessions}회)',
                  en: '+10 Top Up for ${member.primaryName} (${member.remainingSessions})',
                  ja: '${member.primaryName} +10回チャージ (現${member.remainingSessions}回)',
                  zh: '为 ${member.primaryName} 续充 10 次 (当前 ${member.remainingSessions} 次)',
                  vi: 'Nạp +10 buổi cho ${member.primaryName} (Còn ${member.remainingSessions})',
                  es: '+10 sesiones para ${member.primaryName} (Act: ${member.remainingSessions})',
                ),
                icon: Icons.add_circle_outline_rounded,
                size: ZeroButtonSize.medium,
                fullWidth: true,
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await ref.read(membersProvider.notifier).addSessions(member.id, 10);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${member.primaryName} +10 (${member.remainingSessions + 10})'),
                        duration: const Duration(seconds: 3),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 8),
            ],
            if (isSeniorMode)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ZeroButton.tint(
                    label: LocalizationService.pick(
                      ko: '등원 안심 알림 전송 (카톡/SMS)',
                      en: 'Send Check-in Notice',
                      ja: '入室通知を送信',
                      zh: '发送签到提醒',
                      vi: 'Gửi thông báo đã đến',
                      es: 'Enviar aviso llegada',
                    ),
                    icon: Icons.send_rounded,
                    size: ZeroButtonSize.large,
                    fullWidth: true,
                    onPressed: () {
                      AttendanceNotifyDialog.show(
                        context: context,
                        member: member,
                        studio: studio,
                        type: AttendanceNotifyType.checkIn,
                        time: todayPass?.timestamp ?? DateTime.now(),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  ZeroButton(
                    label: LocalizationService.pick(
                      ko: '하원 귀가 알림 전송 (카톡/SMS)',
                      en: 'Send Check-out Notice',
                      ja: '退室通知を送信',
                      zh: '发送签退提醒',
                      vi: 'Gửi thông báo ra về',
                      es: 'Enviar aviso salida',
                    ),
                    icon: Icons.exit_to_app_rounded,
                    variant: ZeroButtonVariant.neutral,
                    size: ZeroButtonSize.large,
                    fullWidth: true,
                    onPressed: () {
                      AttendanceNotifyDialog.show(
                        context: context,
                        member: member,
                        studio: studio,
                        type: AttendanceNotifyType.checkOut,
                        time: DateTime.now(),
                      );
                    },
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: ZeroButton.tint(
                      label: LocalizationService.pick(
                        ko: '등원 안심 알림',
                        en: 'Check-in Alert',
                        ja: '入室通知',
                        zh: '签到通知',
                        vi: 'Báo đã đến',
                        es: 'Aviso llegada',
                      ),
                      icon: Icons.send_rounded,
                      size: ZeroButtonSize.medium,
                      fullWidth: true,
                      onPressed: () {
                        AttendanceNotifyDialog.show(
                          context: context,
                          member: member,
                          studio: studio,
                          type: AttendanceNotifyType.checkIn,
                          time: todayPass?.timestamp ?? DateTime.now(),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ZeroButton(
                      label: LocalizationService.pick(
                        ko: '하원 귀가 알림',
                        en: 'Check-out Alert',
                        ja: '退室通知',
                        zh: '离校通知',
                        vi: 'Báo ra về',
                        es: 'Aviso salida',
                      ),
                      icon: Icons.exit_to_app_rounded,
                      variant: ZeroButtonVariant.neutral,
                      size: ZeroButtonSize.medium,
                      fullWidth: true,
                      onPressed: () {
                        AttendanceNotifyDialog.show(
                          context: context,
                          member: member,
                          studio: studio,
                          type: AttendanceNotifyType.checkOut,
                          time: DateTime.now(),
                        );
                      },
                    ),
                  ),
                ],
              ),
            if (todayPass != null) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => _confirmCancelTodayCheckIn(context, member, todayPass),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.undo_rounded, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          LocalizationService.pick(
                            ko: '오늘 출석 취소 (회차 복구)',
                            en: 'Undo Check-in (Restore)',
                            ja: '本日の出席を取消',
                            zh: '撤销今日签到（退还课时）',
                            vi: 'Hoàn tác điểm danh hôm nay',
                            es: 'Deshacer registro de hoy',
                          ),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],

          // 4. 장기 미출석 (최근 7일+ 결석) 골든타임 안부 톡 케어 슬림 바
          if (!isChecked && isLongAbsent) ...[
            const SizedBox(height: 8),
            ZeroNoticeBanner(
              title: LocalizationService.pick(
                ko: '7일+ 미출석 안심 케어',
                en: 'Absent 7+ Days · Follow Up',
                ja: '7日以上欠席ケア',
                zh: '超7天未签到关怀提醒',
                vi: 'Vắng 7+ ngày · Hỏi thăm',
                es: 'Ausente 7+ días · Seguimiento',
              ),
              actionLabel: LocalizationService.pick(
                ko: '안부 톡',
                en: 'Message',
                ja: '連絡する',
                zh: '去关怀',
                vi: 'Nhắn tin',
                es: 'Contactar',
              ),
              icon: Icons.favorite_rounded,
              variant: ZeroBannerVariant.care,
              onAction: () => _showGoldenTimeCareModal(context, member, studio),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmCancelTodayCheckIn(
    BuildContext context,
    Member member,
    PassRecord passRecord,
  ) async {
    final deduction = passRecord.sessionDeduction ?? 0;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Row(
          children: [
            const Icon(Icons.undo_rounded, color: AppTheme.danger, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LocalizationService.pick(
                  ko: '오늘 출석 취소',
                  en: "Undo Today's Check-in",
                  ja: '本日の出席を取り消す',
                  zh: '撤销今日签到',
                  vi: 'Hủy điểm danh hôm nay',
                  es: 'Anular registro de hoy',
                ),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          LocalizationService.pick(
            ko: '${member.primaryName} 회원의 오늘 출석 체크를 취소하시겠습니까?${deduction > 0 ? '\n차감되었던 $deduction회가 자동으로 복구됩니다.' : ''}',
            en: "Cancel today's check-in for ${member.primaryName}?${deduction > 0 ? '\n$deduction session(s) will be restored.' : ''}",
            ja: '${member.primaryName} 様の本日の出席を取り消しますか？${deduction > 0 ? '\n消化された$deduction回が復元されます。' : ''}',
            zh: '确定撤销 ${member.primaryName} 今天的签到吗？${deduction > 0 ? '\n将自动退还已扣除的 $deduction 次课时。' : ''}',
            vi: 'Hủy điểm danh hôm nay cho ${member.primaryName}?${deduction > 0 ? '\nSẽ hoàn lại $deduction buổi đã trừ.' : ''}',
            es: '¿Anular la asistencia de hoy de ${member.primaryName}?${deduction > 0 ? '\nSe restaurarán $deduction sesión(es).' : ''}',
          ),
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocalizationService.tr('common_close'), style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
            child: Text(LocalizationService.tr('common_confirm'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(passRecordsProvider.notifier).cancelCheckIn(
            record: passRecord,
            member: member,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocalizationService.pick(
                ko: deduction > 0
                    ? '${member.primaryName} 출석이 취소되고 잔여 $deduction회가 복구되었습니다.'
                    : '${member.primaryName} 오늘 출석이 취소되었습니다.',
                en: 'Check-in canceled for ${member.primaryName}.',
                ja: '${member.primaryName} 様の出席を取り消しました。',
                zh: '已撤销 ${member.primaryName} 的签到。',
                vi: 'Đã hủy điểm danh cho ${member.primaryName}.',
                es: 'Asistencia anulada para ${member.primaryName}.',
              ),
            ),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _handleOneTouchCheckIn(Member member) async {
    HapticFeedback.mediumImpact();

    ref.read(passRecordsProvider.notifier).checkInMember(
          member: member,
          status: AttendanceStatus.attended,
        );
    MonetizationService.instance.recordValueAction(checkInCount: 1, smsCount: 1);

    final studio = ref.read(studioProfileProvider).value ?? StudioProfile.defaultProfile();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${member.name} — ${LocalizationService.tr('kiosk_success_headline')}'),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: LocalizationService.pick(
            ko: '안심 알림 전송',
            en: 'Send Alert',
            ja: '通知送信',
            zh: '发送通知',
            vi: 'Gửi thông báo',
            es: 'Enviar aviso',
          ),
          textColor: const Color(0xFFFEE500),
          onPressed: () {
            AttendanceNotifyDialog.show(
              context: context,
              member: member,
              studio: studio,
              type: AttendanceNotifyType.checkIn,
            );
          },
        ),
      ),
    );

    // First-touch coach mark for Check-In
    await CoachMarkDialog.showIfFirstTime(
      context: context,
      coachKey: CoachMarkService.keyCheckIn,
      title: LocalizationService.pick(
        ko: '첫 번째 출석 체크 완료',
        en: 'First Check-in Completed!',
        ja: '最初の出席チェック完了！',
        zh: '已完成首次签到！',
        vi: 'Đã hoàn tất điểm danh đầu tiên!',
        es: '¡Primer registro completado!',
      ),
      message: LocalizationService.pick(
        ko: '회원이 도착했을 때 [체크인]을 누르면 이렇게 1초 만에 회차가 차감돼요.\n\n출석 완료 후 카드 아래의 [출석 알림 문자]를 누르면 부모님께 안심 문자를 비용 0원으로 바로 보낼 수 있어요!',
        en: 'Tap Check In when a member arrives to deduct a session automatically.\n\nAfter check-in, use Send Alert to notify them or their guardian via SMS or Messenger.',
        ja: '会員到着時にチェックインを押すと1秒で記録＆回数が消化されます。\n\nその後［入室通知］から保護者様へ安心メッセージを送れます！',
        zh: '会员到校时点击签到即可1秒扣除课时并生成考勤记录。\n\n随后可通过通知按钮发送安全到校提醒！',
        vi: 'Chạm Điểm danh khi học viên đến để tự động trừ buổi.\n\nSau đó nhấn Gửi thông báo để báo tin qua SMS hoặc tin nhắn.',
        es: 'Pulsa Registrar cuando llegue el miembro para descontar sesión al instante y enviar aviso.',
      ),
      tip: LocalizationService.tr('kiosk_sub_prompt'),
      buttonText: LocalizationService.tr('common_confirm'),
    );
  }

  void _handleBatchCheckIn(BuildContext context, {List<Member>? targetMembers}) async {
    final members = targetMembers ?? (ref.read(membersProvider).value ?? []);
    final passRecords = ref.read(passRecordsProvider).value ?? [];
    final now = DateTime.now();

    final todayCheckedIds = passRecords
        .where((r) => r.timestamp.year == now.year && r.timestamp.month == now.month && r.timestamp.day == now.day)
        .map((r) => r.memberId)
        .toSet();

    final remaining = members.where((m) => !todayCheckedIds.contains(m.id)).toList();

    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocalizationService.tr('kiosk_empty_title')),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actionsOverflowButtonSpacing: 8,
        actionsOverflowDirection: VerticalDirection.down,
        actionsAlignment: MainAxisAlignment.end,
        title: Row(
          children: [
            const Icon(Icons.done_all_rounded, color: AppTheme.primaryBlue, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LocalizationService.pick(
                  ko: '일괄 출석 체크',
                  en: 'Batch Check-in',
                  ja: '一括出席チェック',
                  zh: '批量签到',
                  vi: 'Điểm danh hàng loạt',
                  es: 'Registro masivo',
                ),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          LocalizationService.pick(
            ko: '오늘 아직 출석하지 않은 회원 ${remaining.length}명을 모두 출석 완료 처리하시겠습니까?\n\n(회차권 회원은 잔여 회차가 1회씩 안전하게 차감됩니다)',
            en: 'Check in all ${remaining.length} remaining members today?\n\n(Session-based passes will be deducted by 1 session each.)',
            ja: '未出席の会員 ${remaining.length}名を一括で出席完了にしますか？\n\n（回数券の残回数は1回ずつ自動で消化されます）',
            zh: '确定将今日尚未签到的 ${remaining.length} 名成员全部标记为已签到吗？\n\n（计次卡将自动扣除1次课时）',
            vi: 'Điểm danh đồng loạt cho ${remaining.length} học viên còn lại hôm nay?\n\n(Các gói theo buổi sẽ tự động trừ 1 buổi.)',
            es: '¿Registrar la asistencia de los ${remaining.length} miembros pendientes de hoy?',
          ),
          style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(LocalizationService.tr('common_cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(LocalizationService.tr('common_confirm'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await ref.read(passRecordsProvider.notifier).batchCheckInAll(remaining);
    MonetizationService.instance.recordValueAction(
      checkInCount: remaining.length,
      smsCount: remaining.length,
    );
    MonetizationService.instance.triggerSmartInterstitialAd(
      cooldownSeconds: 90,
      actionThreshold: 2,
    );

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${remaining.length} — ${LocalizationService.tr('kiosk_success_headline')}'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primaryDark,
        ),
      );
    }
  }

  void _showGoldenTimeExplanationModal(BuildContext context, List<Member> absentMembers) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.88,
      builder: (modalCtx) {
        return StickyBottomSheetLayout(
          bodyPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF1F2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFECDD3), width: 1),
                    ),
                    child: const Icon(Icons.favorite_rounded, color: Color(0xFFE11D48), size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService.pick(
                          ko: '장기 미출석 안심 케어 안내',
                          en: 'Long-Term Absence Follow-Up',
                          ja: '長期欠席フォローアップ案内',
                          zh: '长期缺勤会员关怀引导',
                          vi: 'Chăm sóc học viên vắng lâu ngày',
                          es: 'Seguimiento por ausencia prolongada',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocalizationService.pick(
                          ko: '최근 7일 이상 결석한 회원 골든타임 케어',
                          en: 'Members inactive for 7+ consecutive days',
                          ja: '7日以上出席がない会員のフォロー',
                          zh: '连续7天以上未签到的流失预警学员',
                          vi: 'Hội viên chưa điểm danh từ 7 ngày trở lên',
                          es: 'Miembros sin asistencia en los últimos 7+ días',
                        ),
                        style: const TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 22, color: Color(0xFF64748B)),
                  splashRadius: 18,
                  onPressed: () => Navigator.pop(modalCtx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Detailed Guide Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 0.9),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocalizationService.pick(
                      ko: '💡 왜 7일 이상 미출석 관리가 중요한가요?',
                      en: '💡 Why Follow Up After 7 Days?',
                      ja: '💡 なぜ7日以上の欠席ケアが重要？',
                      zh: '💡 为什么关注7天未到校会员如此重要？',
                      vi: '💡 Tại sao cần chăm sóc sau 7 ngày vắng mặt?',
                      es: '💡 ¿Por qué hacer seguimiento tras 7 días?',
                    ),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LocalizationService.pick(
                      ko: '• 7일 이상 결석이 지속되면 출결 습관이 끊겨 중도 이탈로 이어질 확률이 80%에 달합니다.\n'
                          '• 따뜻한 안부 톡이나 간단한 전화 한 통이 회원 복귀율을 78% 이상 높여줍니다.\n'
                          '• 아래 버튼을 누르면 해당 회원들만 모아서 편리하게 안부 메시지를 보낼 수 있습니다.',
                      en: '• Members absent for over 7 days are far more likely to drop out.\n'
                          '• A quick check-in message significantly improves retention.\n'
                          '• Filter below to message inactive members right away.',
                      ja: '• 7日以上欠席が続くと継続率が急落する傾向があります。\n'
                          '• 一言メッセージを送るだけで復帰率が大幅に向上します。\n'
                          '• 下のボタンから対象会員をすぐ絞り込めます。',
                      zh: '• 连续缺勤超过7天更容易中断习惯并导致流失。\n'
                          '• 及时发送问候提醒可显著提升回访率。\n'
                          '• 点击下方按钮即可快速筛选出这些学员并联系。',
                      vi: '• Vắng quá 7 ngày dễ dẫn đến gián đoạn thói quen & bỏ gói.\n'
                          '• Một tin nhắn hỏi thăm nhẹ giúp giữ chân hội viên hiệu quả.\n'
                          '• Nhấn bên dưới để lọc nhanh danh sách cần liên hệ.',
                      es: '• Tras 7 días sin asistir aumenta el riesgo de abandono.\n'
                          '• Un saludo cercano recupera la asistencia rápidamente.\n'
                          '• Filtra abajo para ver y contactar a esos miembros.',
                    ),
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12.5,
                      color: Color(0xFF475569),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '${LocalizationService.tr('expiring_soon')} (${absentMembers.length})',
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: absentMembers.take(8).map((m) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1F2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFFECDD3), width: 0.8),
                  ),
                  child: Text(
                    '${m.name} (${LocalizationService.localizeBuiltInLabel(m.groupName.isNotEmpty ? m.groupName : "일반")})',
                    style: const TextStyle(
                      fontFamily: 'Pretendard',
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFBE123C),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
        footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        footer: SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(modalCtx);
              setState(() => _statusFilter = '골든타임 케어');
            },
            icon: const Icon(Icons.filter_list_rounded, size: 18),
            label: Text(
              LocalizationService.pick(
                ko: '대상 회원 ${absentMembers.length}명 목록 바로보기',
                en: 'View Inactive Members (${absentMembers.length})',
                ja: '対象会員 ${absentMembers.length}名を表示',
                zh: '查看需关怀会员 (${absentMembers.length}人)',
                vi: 'Xem ${absentMembers.length} hội viên vắng lâu',
                es: 'Ver miembros inactivos (${absentMembers.length})',
              ),
            ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE11D48),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(
                  fontFamily: 'Pretendard',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _showGoldenTimeCareModal(BuildContext context, Member member, StudioProfile studio) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (modalCtx) => _GoldenTimeCareSheet(
        member: member,
        studio: studio,
      ),
    );
  }

  Widget _buildSeniorEasyBoard({
    required BuildContext context,
    required List<Member> members,
    required List<PassRecord> todayRecords,
    required StudioProfile studio,
  }) {
    final now = DateTime.now();
    final todayRecs = todayRecords.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();
    final checkedMemberIds = todayRecs.map((r) => r.memberId).toSet();
    final attendedToday = todayRecs.where((r) => r.status == AttendanceStatus.attended).length;
    final totalMembers = members.length;
    final remainingCount = members.where((m) => !checkedMemberIds.contains(m.id)).length;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF6FF),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.trustBlue, width: 2.0),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.trustBlue,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.elderly_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  LocalizationService.tr('senior_board_title'),
                  softWrap: true,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                    letterSpacing: -0.4,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => SeniorEasyGuideModal.show(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.trustBlue.withAlpha(120), width: 1.2),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.help_outline_rounded, size: 15, color: AppTheme.trustBlue),
                      const SizedBox(width: 4),
                      Text(
                        LocalizationService.pick(
                          ko: '설명서',
                          en: 'Guide',
                          ja: 'ガイド',
                          zh: '说明书',
                          vi: 'Hướng dẫn',
                          es: 'Guía',
                        ),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.trustBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withAlpha(200),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppTheme.trustBlue.withAlpha(60), width: 1.0),
            ),
            child: Text(
              LocalizationService.pick(
                ko: '오늘 출석: $attendedToday명  ·  미출석: $remainingCount명 (총 $totalMembers명)',
                en: 'Checked In: $attendedToday · Waiting: $remainingCount (Total: $totalMembers)',
                ja: '本日出席: $attendedToday名 · 未出席: $remainingCount名 (計$totalMembers名)',
                zh: '今日已签: $attendedToday人 · 未签: $remainingCount人 (共$totalMembers人)',
                vi: 'Đã đến: $attendedToday · Chờ: $remainingCount (Tổng $totalMembers)',
                es: 'Asistencia: $attendedToday · Pendientes: $remainingCount (Total $totalMembers)',
              ),
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: AppTheme.trustBlue,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // 3 Big Touch Action Tiles (Senior Mode 1-Column Full-Width Stack)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSeniorActionTile(
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF059669),
                bgColor: const Color(0xFFECFDF5),
                borderColor: const Color(0xFF10B981),
                title: LocalizationService.tr('senior_attendance'),
                subtitle: LocalizationService.tr('senior_attendance_sub'),
                badgeText: '$attendedToday / $totalMembers · ${LocalizationService.tr('kiosk_tap_checkin')}',
                onTap: () => _showSeniorAttendanceSheet(context, members, todayRecords),
              ),
              const SizedBox(height: 10),
              _buildSeniorActionTile(
                icon: Icons.mark_email_read_rounded,
                iconColor: AppTheme.trustBlue,
                bgColor: const Color(0xFFEFF6FF),
                borderColor: AppTheme.trustBlue,
                title: LocalizationService.tr('senior_billing'),
                subtitle: LocalizationService.tr('senior_billing_sub'),
                badgeText: LocalizationService.tr('common_send_sms'),
                onTap: () => _showSeniorBillingSheet(context, members, studio),
              ),
              const SizedBox(height: 10),
              _buildSeniorActionTile(
                icon: Icons.phone_in_talk_rounded,
                iconColor: const Color(0xFFD97706),
                bgColor: const Color(0xFFFFFBEB),
                borderColor: const Color(0xFFF59E0B),
                title: LocalizationService.tr('senior_call'),
                subtitle: LocalizationService.tr('senior_call_sub'),
                badgeText: LocalizationService.pick(
                  ko: '전화 연결',
                  en: 'Call Now',
                  ja: '発信する',
                  zh: '立即拨打',
                  vi: 'Gọi ngay',
                  es: 'Llamar ahora',
                ),
                onTap: () => _showSeniorCallSheet(context, members),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSeniorActionTile({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String title,
    required String subtitle,
    required String badgeText,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: iconColor.withAlpha(25),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(icon, color: iconColor, size: 26),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(Icons.arrow_forward_ios_rounded, size: 16, color: iconColor.withAlpha(180)),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor.withAlpha(120), width: 1.2),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        badgeText,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w800,
                          color: iconColor,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.touch_app_rounded, size: 15, color: iconColor),
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

  void _showSeniorAttendanceSheet(
    BuildContext context,
    List<Member> members,
    List<PassRecord> todayRecords,
  ) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (modalCtx) => _SeniorAttendanceModalSheet(
        members: members,
        todayRecords: todayRecords,
      ),
    );
  }

  void _showSeniorBillingSheet(
    BuildContext context,
    List<Member> members,
    StudioProfile studio,
  ) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (modalCtx) => _SeniorBillingModalSheet(
        members: members,
        studio: studio,
      ),
    );
  }

  void _showSeniorCallSheet(
    BuildContext context,
    List<Member> members,
  ) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (modalCtx) => _SeniorCallModalSheet(
        members: members,
      ),
    );
  }
}

class _GoldenTimeCareSheet extends StatefulWidget {
  final Member member;
  final StudioProfile studio;

  const _GoldenTimeCareSheet({
    required this.member,
    required this.studio,
  });

  @override
  State<_GoldenTimeCareSheet> createState() => _GoldenTimeCareSheetState();
}

class _GoldenTimeCareSheetState extends State<_GoldenTimeCareSheet> {
  late final TextEditingController _messageController;
  int _selectedPresetIndex = 0;

  List<Map<String, String>> get _presets => [
    {
      'title': LocalizationService.pick(
        ko: '🌸 따뜻한 안부',
        en: '🌸 Warm Check-in',
        ja: '🌸 ご挨拶',
        zh: '🌸 温馨问候',
        vi: '🌸 Hỏi thăm',
        es: '🌸 Saludo cercano',
      ),
      'text': LocalizationService.pick(
        ko: '[${widget.studio.studioName}] 안녕하세요, ${widget.member.primaryName}님! 요즘 환절기인데 건강히 잘 지내고 계신가요? 늘 회원님의 활기차고 건강한 하루를 응원합니다. 수업 일정 관련해 언제든 편하게 말씀해주세요 :)',
        en: '[${widget.studio.studioName}] Hi ${widget.member.primaryName}! Just checking in—hope you are doing well. Let us know anytime you would like to book your next session!',
        ja: '[${widget.studio.studioName}] ${widget.member.primaryName}様、こんにちは！その後お変わりありませんか？次回のご予約など、いつでもお気軽にご連絡ください。',
        zh: '[${widget.studio.studioName}] ${widget.member.primaryName} 您好！近期有空记得回来继续课程锻炼哦，随时欢迎预约合适时间！',
        vi: '[${widget.studio.studioName}] Xin chào ${widget.member.primaryName}! Chúc bạn luôn khỏe mạnh, hãy nhắn cho chúng tôi khi bạn sẵn sàng xếp lịch buổi tiếp theo nhé!',
        es: '[${widget.studio.studioName}] ¡Hola ${widget.member.primaryName}! Te enviamos un saludo y quedamos a tu disposición para agendar tu próxima sesión.',
      ),
    },
    {
      'title': LocalizationService.pick(
        ko: '🧘 복귀 & 스케줄',
        en: '🧘 Resume Schedule',
        ja: '🧘 再開・日程調整',
        zh: '🧘 恢复安排',
        vi: '🧘 Sắp xếp lịch',
        es: '🧘 Retomar horario',
      ),
      'text': LocalizationService.pick(
        ko: '[${widget.studio.studioName}] 안녕하세요, ${widget.member.primaryName}님! 바쁘신 일정이 마무리되실 때 언제든 편하게 다시 찾아주세요. 회원님께 맞춘 편안한 수업 스케줄로 바로 준비해드리겠습니다!',
        en: '[${widget.studio.studioName}] Hi ${widget.member.primaryName}, whenever your schedule clears up, feel free to drop by—we will gladly adjust a session time for you!',
        ja: '[${widget.studio.studioName}] ${widget.member.primaryName}様、お忙しいスケジュールが落ち着きましたらいつでも再開できますのでお気軽にご相談ください。',
        zh: '[${widget.studio.studioName}] ${widget.member.primaryName} 您好！忙完手头安排随时可以联系我们重新匹配上课时间哦！',
        vi: '[${widget.studio.studioName}] Xin chào ${widget.member.primaryName}, khi thu xếp được thời gian hãy quay lại tập luyện nhé!',
        es: '[${widget.studio.studioName}] ¡Hola ${widget.member.primaryName}! Cuando quieras retomar tus clases, adaptaremos el horario para ti.',
      ),
    },
    {
      'title': LocalizationService.pick(
        ko: '📚 학업/시험 격려',
        en: '📚 Study Support',
        ja: '📚 試験・学習応援',
        zh: '📚 学习加油',
        vi: '📚 Động viên học tập',
        es: '📚 Ánimo con estudios',
      ),
      'text': LocalizationService.pick(
        ko: '[${widget.studio.studioName}] 안녕하세요, ${widget.member.primaryName} 학생/학부모님! 학업과 시험 준비로 많이 바쁘시죠? 건강 챙기면서 파이팅하시고, 일정 끝나면 밝은 모습으로 뵙겠습니다!',
        en: '[${widget.studio.studioName}] Wishing ${widget.member.primaryName} all the best with exams and studies! See you back at ${widget.studio.studioName} soon!',
        ja: '[${widget.studio.studioName}] ${widget.member.primaryName}様、試験や学業の準備でお忙しい時期ですね。落ち着きましたらまた元気なお顔を見せてください！',
        zh: '[${widget.studio.studioName}] ${widget.member.primaryName} 同学加油！考试和忙碌期结束后期待再次在教室见到你！',
        vi: '[${widget.studio.studioName}] Chúc ${widget.member.primaryName} học tập & thi cử thật tốt! Hẹn sớm gặp lại bạn tại trung tâm.',
        es: '[${widget.studio.studioName}] ¡Mucho ánimo a ${widget.member.primaryName} con los exámenes! Te esperamos pronto.',
      ),
    },
    {
      'title': LocalizationService.pick(
        ko: '🏃 운동/수업 재개',
        en: '🏃 Back on Track',
        ja: '🏃 ワークアウト再開',
        zh: '🏃 回归训练',
        vi: '🏃 Quay lại tập luyện',
        es: '🏃 Vuelta al entrenamiento',
      ),
      'text': LocalizationService.pick(
        ko: '[${widget.studio.studioName}] 안녕하세요, ${widget.member.primaryName}님! 잠시 쉬어가시는 동안 몸은 찌뿌둥하지 않으신가요? 활기찬 에너지를 되찾으실 수 있도록 언제든 기다리고 있겠습니다 :)',
        en: '[${widget.studio.studioName}] Missing you at ${widget.studio.studioName}, ${widget.member.primaryName}! Ready whenever you want to jump back in!',
        ja: '[${widget.studio.studioName}] ${widget.member.primaryName}様、そろそろ体を動かしませんか？リフレッシュしにいつでもお越しください！',
        zh: '[${widget.studio.studioName}] ${widget.member.primaryName} 您好，好久不见！期待您回来恢复活力和状态！',
        vi: '[${widget.studio.studioName}] ${widget.member.primaryName} ơi, hẹn gặp lại bạn sớm để tiếp tục năng lượng tích cực nhé!',
        es: '[${widget.studio.studioName}] ¡Te echamos de menos ${widget.member.primaryName}! Te esperamos para volver con energía.',
      ),
    },
  ];

  @override
  void initState() {
    super.initState();
    _messageController = TextEditingController(text: _presets.first['text']);
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _applyPreset(int index) {
    setState(() {
      _selectedPresetIndex = index;
      _messageController.text = _presets[index]['text']!;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StickyBottomSheetLayout(
      bodyPadding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      body: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF7ED),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFFED7AA)),
                ),
                child: const Icon(Icons.favorite_rounded, color: Color(0xFFEA580C), size: 20),
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
                          widget.member.primaryName,
                          softWrap: true,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFEDD5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            LocalizationService.pick(
                              ko: '골든타임 안심 케어',
                              en: 'Follow-Up Care',
                              ja: '安心フォローケア',
                              zh: '重点关怀提醒',
                              vi: 'Chăm sóc hội viên',
                              es: 'Seguimiento especial',
                            ),
                            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFFC2410C)),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.member.phone} · ${LocalizationService.tr('expiring_soon')}',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Situation Preset Chips
          Text(
            LocalizationService.pick(
              ko: '상황별 안부 메시지 템플릿 선택',
              en: 'Quick Follow-Up Message Presets',
              ja: '状況別メッセージテンプレート',
              zh: '选择关怀问候话术模板',
              vi: 'Chọn mẫu tin nhắn hỏi thăm',
              es: 'Plantillas de mensaje rápido',
            ),
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: List.generate(_presets.length, (i) {
              final isSelected = _selectedPresetIndex == i;
              return ChoiceChip(
                label: Text(_presets[i]['title']!),
                labelStyle: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFFC2410C) : const Color(0xFF475569),
                ),
                selected: isSelected,
                selectedColor: const Color(0xFFFFEDD5),
                backgroundColor: const Color(0xFFF8FAFC),
                side: BorderSide(
                  color: isSelected ? const Color(0xFFF97316) : const Color(0xFFE2E8F0),
                  width: isSelected ? 1.2 : 0.8,
                ),
                onSelected: (_) => _applyPreset(i),
              );
            }),
          ),
          const SizedBox(height: 14),

          // Editable Text Area
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: TextField(
              controller: _messageController,
              maxLines: 5,
              style: const TextStyle(fontSize: 13.5, height: 1.45, color: Color(0xFF1E293B)),
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.all(14),
                border: InputBorder.none,
                hintText: LocalizationService.pick(
                  ko: '회원님께 전할 따뜻한 안부 메시지를 입력하세요.',
                  en: 'Write a friendly follow-up message.',
                  ja: 'メッセージを入力してください。',
                  zh: '请输入问候消息内容。',
                  vi: 'Nhập lời nhắn hỏi thăm.',
                  es: 'Escribe tu mensaje de saludo.',
                ),
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
                  content: Text(LocalizationService.tr('common_copied')),
                  behavior: SnackBarBehavior.floating,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy_rounded, size: 14, color: AppTheme.textSecondary),
            label: Text(LocalizationService.tr('common_copy'), style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final text = _messageController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context);
              await SmsTemplateService.launchNativeSms(
                recipientPhone: widget.member.phone,
                body: text,
              );
            },
            icon: const Icon(Icons.sms_rounded, size: 15, color: Colors.white),
            label: Text(LocalizationService.tr('common_send_sms'), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final text = _messageController.text.trim();
              if (text.isEmpty) return;
              Navigator.pop(context);
              await KakaoShareService.shareMessage(
                text: text,
                subject: widget.studio.studioName,
              );
            },
            icon: const Icon(Icons.chat_bubble_rounded, size: 15, color: Color(0xFF1E1E1E)),
            label: Text(
              LocalizationService.isDomestic ? '카카오톡 안부 톡' : LocalizationService.shareMessengerLabel,
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
}

class _SeniorAttendanceModalSheet extends ConsumerStatefulWidget {
  final List<Member> members;
  final List<PassRecord> todayRecords;

  const _SeniorAttendanceModalSheet({
    required this.members,
    required this.todayRecords,
  });

  @override
  ConsumerState<_SeniorAttendanceModalSheet> createState() => _SeniorAttendanceModalSheetState();
}

class _SeniorAttendanceModalSheetState extends ConsumerState<_SeniorAttendanceModalSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 360;
    final now = DateTime.now();

    final passRecords = ref.watch(passRecordsProvider).value ?? widget.todayRecords;
    final todayRecs = passRecords.where((r) {
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();
    final checkedMemberIds = todayRecs.map((r) => r.memberId).toSet();

    final filtered = widget.members.where((m) {
      if (_filter.isEmpty) return true;
      return m.name.contains(_filter) || m.phone.contains(_filter);
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF10B981).withAlpha(100), width: 1.5),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalizationService.pick(
                            ko: '큰글씨 간편 출석 체크',
                            en: 'Easy Large-Text Check-In',
                            ja: '大きな文字かんたん出席チェック',
                            zh: '大字体便捷签到',
                            vi: 'Điểm danh chữ lớn dễ đọc',
                            es: 'Check-in Fácil (Texto Grande)',
                          ),
                          style: TextStyle(
                            fontSize: isCompact ? 18 : 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          LocalizationService.tr('senior_attendance_sub'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF047857),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 28, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1.2, color: Color(0xFFE2E8F0)),

            // Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: TextField(
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  onChanged: (val) => setState(() => _filter = val.trim()),
                  decoration: InputDecoration(
                    hintText: LocalizationService.tr('common_search'),
                    hintStyle: const TextStyle(fontSize: 14.5, color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue, size: 24),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            // Members List
            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        LocalizationService.tr('kiosk_empty_title'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final m = filtered[i];
                        final isChecked = checkedMemberIds.contains(m.id);

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isChecked ? const Color(0xFFF0FDF4) : Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: isChecked ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                              width: isChecked ? 1.8 : 1.2,
                            ),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: isChecked ? const Color(0xFFDCFCE7) : const Color(0xFFEFF6FF),
                                    child: Text(
                                      m.name.isNotEmpty ? m.name[0] : '?',
                                      style: TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: isChecked ? const Color(0xFF16A34A) : AppTheme.trustBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              m.name,
                                              style: const TextStyle(
                                                fontSize: 18.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFF1F5F9),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                m.groupName,
                                                style: const TextStyle(
                                                  fontSize: 11.5,
                                                  fontWeight: FontWeight.w700,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          m.phone,
                                          style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF475569),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (isChecked)
                                Container(
                                  width: double.infinity,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF16A34A),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                                        const SizedBox(width: 6),
                                        Text(
                                          LocalizationService.tr('checked_in'),
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF059669),
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                      elevation: 0,
                                    ),
                                    icon: const Icon(Icons.check_circle_outline_rounded, size: 20),
                                    label: Text(
                                      LocalizationService.pick(
                                        ko: '출석 확인',
                                        en: 'Confirm Check-In',
                                        ja: '出席確認',
                                        zh: '确认签到',
                                        vi: 'Xác nhận điểm danh',
                                        es: 'Confirmar Check-in',
                                      ),
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                    ),
                                    onPressed: () async {
                                      await ref.read(passRecordsProvider.notifier).checkInMember(member: m);
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              '${m.name} — ${LocalizationService.tr('kiosk_success_headline')}',
                                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                                            ),
                                            backgroundColor: const Color(0xFF059669),
                                            behavior: SnackBarBehavior.floating,
                                            duration: const Duration(seconds: 2),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
  }
}

class _SeniorBillingModalSheet extends StatefulWidget {
  final List<Member> members;
  final StudioProfile studio;

  const _SeniorBillingModalSheet({
    required this.members,
    required this.studio,
  });

  @override
  State<_SeniorBillingModalSheet> createState() => _SeniorBillingModalSheetState();
}

class _SeniorBillingModalSheetState extends State<_SeniorBillingModalSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 360;

    final filtered = widget.members.where((m) {
      if (_filter.isEmpty) return true;
      return m.name.contains(_filter) || m.phone.contains(_filter);
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.trustBlue.withAlpha(100), width: 1.5),
                    ),
                    child: const Icon(Icons.mark_email_read_rounded, color: AppTheme.trustBlue, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalizationService.tr('senior_billing'),
                          style: TextStyle(
                            fontSize: isCompact ? 18 : 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          LocalizationService.tr('senior_billing_sub'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.trustBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 28, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1.2, color: Color(0xFFE2E8F0)),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: TextField(
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  onChanged: (val) => setState(() => _filter = val.trim()),
                  decoration: InputDecoration(
                    hintText: LocalizationService.tr('common_search'),
                    hintStyle: const TextStyle(fontSize: 14.5, color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue, size: 24),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        LocalizationService.tr('kiosk_empty_title'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final m = filtered[i];
                        final formattedFee = LocalizationService.formatAmount(m.defaultFee);
                        final targetPhone = m.phone;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFFEFF6FF),
                                    child: Text(
                                      m.name.isNotEmpty ? m.name[0] : '?',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: AppTheme.trustBlue,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          m.name,
                                          softWrap: true,
                                          style: const TextStyle(
                                            fontSize: 18.5,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                m.payerName != null && m.payerName!.isNotEmpty
                                                    ? LocalizationService.pick(
                                                        ko: '입금자: ${m.payerName}',
                                                        en: 'Payer: ${m.payerName}',
                                                        ja: '振込名: ${m.payerName}',
                                                        zh: '付款人: ${m.payerName}',
                                                        vi: 'Người nộp: ${m.payerName}',
                                                        es: 'Pagador: ${m.payerName}',
                                                      )
                                                    : LocalizationService.pick(
                                                        ko: '연락처: ${m.phone}',
                                                        en: 'Phone: ${m.phone}',
                                                        ja: '連絡先: ${m.phone}',
                                                        zh: '电话: ${m.phone}',
                                                        vi: 'SĐT: ${m.phone}',
                                                        es: 'Tel: ${m.phone}',
                                                      ),
                                                style: const TextStyle(
                                                  fontSize: 13.5,
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF475569),
                                                ),
                                              ),
                                            ),
                                            Text(
                                              formattedFee,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w900,
                                                color: Color(0xFF1D4ED8),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.trustBlue,
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 1,
                                  ),
                                  icon: const Icon(Icons.send_rounded, size: 17),
                                  label: Text(
                                    LocalizationService.tr('common_send_sms'),
                                    style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800),
                                  ),
                                  onPressed: () async {
                                    final amountText = LocalizationService.formatAmount(m.defaultFee);
                                    final bankInfo = widget.studio.accountNumber.isNotEmpty
                                        ? '\n${widget.studio.bankName} ${widget.studio.accountNumber} (${widget.studio.accountHolder})'
                                        : '';
                                    final msg = LocalizationService.pick(
                                      ko: '[${widget.studio.studioName}]\n안녕하세요, ${m.name} 회원님 이번 달 ${widget.studio.feeTitle}($amountText) 입금 안내드립니다.$bankInfo\n감사합니다.',
                                      en: '[${widget.studio.studioName}]\nHi ${m.name}, your monthly ${widget.studio.feeTitle} ($amountText) invoice is ready.$bankInfo\nThank you!',
                                      ja: '[${widget.studio.studioName}]\n${m.name}様、今月の${widget.studio.feeTitle}（$amountText）のご案内です。$bankInfo\nよろしくお願いいたします。',
                                      zh: '[${widget.studio.studioName}]\n您好 ${m.name}，本月${widget.studio.feeTitle}（$amountText）账单如下：$bankInfo\n感谢支持！',
                                      vi: '[${widget.studio.studioName}]\nXin chào ${m.name}, thông báo ${widget.studio.feeTitle} ($amountText).$bankInfo\nXin cảm ơn!',
                                      es: '[${widget.studio.studioName}]\nHola ${m.name}, recordatorio de ${widget.studio.feeTitle} ($amountText).$bankInfo\n¡Gracias!',
                                    );

                                    await SmsTemplateService.launchNativeSms(
                                      recipientPhone: targetPhone,
                                      body: msg,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
  }
}

class _SeniorCallModalSheet extends StatefulWidget {
  final List<Member> members;

  const _SeniorCallModalSheet({
    required this.members,
  });

  @override
  State<_SeniorCallModalSheet> createState() => _SeniorCallModalSheetState();
}

class _SeniorCallModalSheetState extends State<_SeniorCallModalSheet> {
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final isCompact = media.size.width < 360;

    final filtered = widget.members.where((m) {
      if (_filter.isEmpty) return true;
      return m.name.contains(_filter) || m.phone.contains(_filter);
    }).toList();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 8, 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFBEB),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF59E0B).withAlpha(120), width: 1.5),
                    ),
                    child: const Icon(Icons.phone_in_talk_rounded, color: Color(0xFFD97706), size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          LocalizationService.tr('senior_call'),
                          style: TextStyle(
                            fontSize: isCompact ? 18 : 21,
                            fontWeight: FontWeight.w900,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          LocalizationService.tr('senior_call_sub'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFB45309),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 28, color: Colors.black87),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, thickness: 1.2, color: Color(0xFFE2E8F0)),

            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                ),
                child: TextField(
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  onChanged: (val) => setState(() => _filter = val.trim()),
                  decoration: InputDecoration(
                    hintText: LocalizationService.tr('common_search'),
                    hintStyle: const TextStyle(fontSize: 14.5, color: Color(0xFF64748B)),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue, size: 24),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                ),
              ),
            ),

            Expanded(
              child: filtered.isEmpty
                  ? Center(
                      child: Text(
                        LocalizationService.tr('kiosk_empty_title'),
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF64748B)),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final m = filtered[i];
                        final callTarget = m.phone;
                        final label = (m.payerName != null && m.payerName!.isNotEmpty)
                            ? m.payerName!
                            : m.name;

                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
                            boxShadow: AppTheme.cardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  CircleAvatar(
                                    radius: 22,
                                    backgroundColor: const Color(0xFFFEF3C7),
                                    child: Text(
                                      m.name.isNotEmpty ? m.name[0] : '?',
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w900,
                                        color: Color(0xFFD97706),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Wrap(
                                          spacing: 6,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Text(
                                              m.name,
                                              style: const TextStyle(
                                                fontSize: 18.5,
                                                fontWeight: FontWeight.w900,
                                                color: Colors.black,
                                              ),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF3C7),
                                                borderRadius: BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                label,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                  color: Color(0xFFB45309),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          callTarget,
                                          style: const TextStyle(
                                            fontSize: 14.5,
                                            fontWeight: FontWeight.w700,
                                            color: Color(0xFF334155),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF059669),
                                    foregroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  icon: const Icon(Icons.phone_rounded, size: 20),
                                  label: Text(
                                    LocalizationService.tr('senior_call'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                                  ),
                                  onPressed: () async {
                                    final uri = Uri.parse('tel:$callTarget');
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri);
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(content: Text('Dial failed: $callTarget')),
                                        );
                                      }
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
  }
}




class _StickySearchAndFilterHeaderDelegate extends SliverPersistentHeaderDelegate {
  final TextEditingController searchController;
  final FocusNode searchFocusNode;
  final String searchQuery;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback onSearchClear;
  final List<String> groups;
  final String selectedGroup;
  final ValueChanged<String> onGroupSelected;
  final String statusFilter;
  final ValueChanged<String> onStatusFilterSelected;

  const _StickySearchAndFilterHeaderDelegate({
    required this.searchController,
    required this.searchFocusNode,
    required this.searchQuery,
    required this.onSearchChanged,
    required this.onSearchClear,
    required this.groups,
    required this.selectedGroup,
    required this.onGroupSelected,
    required this.statusFilter,
    required this.onStatusFilterSelected,
  });

  @override
  double get minExtent => 88.0;

  @override
  double get maxExtent => 88.0;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return SizedBox(
      height: 88.0,
      child: Container(
        color: AppTheme.background,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 1. Korean Chosung & Real-time Smart Search Bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
              child: Container(
                height: 42,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.9),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: TextField(
                  controller: searchController,
                  focusNode: searchFocusNode,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => searchFocusNode.unfocus(),
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: LocalizationService.pick(
                      ko: '이름·초성(ㅇㄷㅎ)·뒷번호 4자리 검색',
                      en: 'Search name, group, or last 4 digits',
                      ja: '名前・グループ・下4桁で検索',
                      zh: '搜索姓名、班级或尾号4位',
                      vi: 'Tìm tên, nhóm hoặc 4 số cuối',
                      es: 'Buscar por nombre, grupo o 4 dígitos',
                    ),
                    hintStyle: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                    prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.textSecondary, size: 19),
                    prefixIconConstraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    suffixIcon: searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 17),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                            onPressed: onSearchClear,
                          )
                        : null,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                  ),
                ),
              ),
            ),
            // 2. Sub-tab Filter Chips (Sticky Bar)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 3),
              child: Row(
                children: [
                  ...groups.take(5).map((g) {
                    final isSelected = selectedGroup == g;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ZeroFilterChip(
                        label: g == LocalizationService.tr('all_groups') ? g : LocalizationService.localizeBuiltInLabel(g),
                        isSelected: isSelected,
                        onTap: () => onGroupSelected(g),
                      ),
                    );
                  }),
                  PopupMenuButton<String>(
                    initialValue: statusFilter,
                    onSelected: onStatusFilterSelected,
                    itemBuilder: (ctx) => [
                      PopupMenuItem(value: '전체', child: Text(LocalizationService.tr('common_all'))),
                      PopupMenuItem(value: '출결 대기', child: Text(LocalizationService.tr('waiting_checkin'))),
                      PopupMenuItem(value: '체크 완료', child: Text(LocalizationService.tr('checked_in'))),
                      PopupMenuItem(value: '만료 임박', child: Text(LocalizationService.tr('expiring_soon'))),
                      PopupMenuItem(
                        value: '골든타임 케어',
                        child: Text(
                          LocalizationService.pick(
                            ko: '골든타임 케어 (7일+ 결석)',
                            en: 'Follow-Up (7+ Days)',
                            ja: '長期欠席 (7日+)',
                            zh: '长期缺勤 (7天+)',
                            vi: 'Vắng 7+ ngày',
                            es: 'Ausente 7+ días',
                          ),
                        ),
                      ),
                    ],
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 11),
                      decoration: BoxDecoration(
                        color: statusFilter != '전체' ? const Color(0xFFEFF6FF) : const Color(0xFFF4F4F5),
                        borderRadius: BorderRadius.circular(16),
                        border: statusFilter != '전체'
                            ? Border.all(color: AppTheme.trustBlue, width: 1.0)
                            : null,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 13,
                            color: statusFilter != '전체' ? AppTheme.trustBlue : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            LocalizationService.pick(
                              ko: '상태: ',
                              en: 'Filter ',
                              ja: '状態: ',
                              zh: '筛选 ',
                              vi: 'Lọc ',
                              es: 'Estado ',
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: statusFilter != '전체' ? FontWeight.w700 : FontWeight.w500,
                              color: statusFilter != '전체' ? AppTheme.trustBlue : AppTheme.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.keyboard_arrow_down, size: 15, color: AppTheme.textSecondary),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () => ScheduleCalendarModal.show(context),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month_rounded, size: 14, color: AppTheme.primaryBlue),
                          const SizedBox(width: 4),
                          Text(
                            LocalizationService.pick(
                              ko: '스케줄 달력',
                              en: 'Calendar',
                              ja: '予定表',
                              zh: '课程日程',
                              vi: 'Lịch trình',
                              es: 'Calendario',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryBlue,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _StickySearchAndFilterHeaderDelegate oldDelegate) {
    return oldDelegate.searchQuery != searchQuery ||
        oldDelegate.selectedGroup != selectedGroup ||
        oldDelegate.statusFilter != statusFilter ||
        oldDelegate.groups != groups;
  }
}
