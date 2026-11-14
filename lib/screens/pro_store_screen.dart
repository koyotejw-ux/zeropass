import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/localization_service.dart';
import '../services/monetization_service.dart';
import '../theme/app_theme.dart';
import '../widgets/design_system.dart';
import 'tablet_kiosk_screen.dart';

class ProStoreScreen extends StatefulWidget {
  const ProStoreScreen({super.key});

  @override
  State<ProStoreScreen> createState() => _ProStoreScreenState();
}

class _ProStoreScreenState extends State<ProStoreScreen> {
  @override
  void initState() {
    super.initState();
    MonetizationService.instance.checkEntitlementExpirations();
    MonetizationService.instance.fetchProducts();
  }

  Future<void> _startPurchase(String productId) async {
    final result = await MonetizationService.instance.buyProduct(productId);
    if (!result.started && mounted && result.errorMessage != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _claimTemporaryPass(MonetizationService bm, bool isDomestic) async {
    await bm.launchTemporaryPassFlow(context);
  }

  Future<void> _openPlaySubscriptions() async {
    final uri = Uri.parse('https://play.google.com/store/account/subscriptions');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.pick(
              ko: 'Google Play 스토어 앱 > 프로필 > [결제 및 정기 결제]에서 관리하실 수 있습니다.',
              en: 'Manage in Google Play Store > Profile > Payments & subscriptions.',
              ja: 'Google Play ストア > プロフィール > お支払いと定期購入から管理できます。',
              zh: '可在 Google Play 商店 > 个人资料 > 付款与订阅中随时管理。',
              vi: 'Quản lý tại Google Play Store > Hồ sơ > Thanh toán & gói thuê bao.',
              es: 'Gestiona tu plan en Google Play Store > Perfil > Pagos y suscripciones.',
            ),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Widget _buildStoreNoticeBanner(MonetizationService bm) {
    final notice = bm.lastStoreNotice;
    if (notice == null || notice.isEmpty) return const SizedBox.shrink();

    final event = bm.lastStoreEventType;
    final Color accent;
    final Color bg;
    final IconData icon;
    switch (event) {
      case StoreEventType.purchased:
      case StoreEventType.restored:
        accent = const Color(0xFF047857);
        bg = const Color(0xFFECFDF5);
        icon = Icons.verified_rounded;
        break;
      case StoreEventType.pending:
        accent = const Color(0xFFB45309);
        bg = const Color(0xFFFFFBEB);
        icon = Icons.hourglass_top_rounded;
        break;
      case StoreEventType.expired:
      case StoreEventType.error:
        accent = const Color(0xFFBE123C);
        bg = const Color(0xFFFFF1F2);
        icon = Icons.info_outline_rounded;
        break;
      case StoreEventType.canceled:
      case StoreEventType.none:
        accent = AppTheme.textSecondary;
        bg = const Color(0xFFF1F5F9);
        icon = Icons.info_outline_rounded;
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              notice,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: accent,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isDomestic = LocalizationService.isDomestic;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        elevation: 0,
        toolbarHeight: isLandscape ? 50 : 56,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            LocalizationService.proStoreTitle,
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: isLandscape ? 17 : 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: AnimatedBuilder(
              animation: MonetizationService.instance,
              builder: (context, _) {
                final bm = MonetizationService.instance;
                return ZeroButton.tint(
                  label: bm.isRestoringPurchases
                      ? LocalizationService.pick(
                          ko: '복원 중...',
                          en: 'Restoring...',
                          ja: '復元中...',
                          zh: '正在恢复...',
                          vi: 'Đang khôi phục...',
                          es: 'Restaurando...',
                        )
                      : LocalizationService.proStoreRestore,
                  icon: Icons.restore_rounded,
                  size: ZeroButtonSize.medium,
                  isLoading: bm.isRestoringPurchases,
                  onPressed: bm.isRestoringPurchases
                      ? null
                      : () async {
                          final result = await bm.restorePurchases();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(result.message),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                );
              },
            ),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: MonetizationService.instance,
        builder: (context, _) {
          final bm = MonetizationService.instance;
          // 실제 구글 플레이 결제 기반 정기 구독 상태 (1시간 임시 패스 제외)
          final isSubNoAds = bm.isSubscriptionAdsRemoved;
          final isSubKiosk = bm.isSubscriptionKioskPro;
          final isSubAllInOne = bm.isSubscriptionAllInOne;
          final tempPassState = bm.getProductState(MonetizationService.productPassTemporaryVip1h);
          final vipMonthlyState = bm.getProductState(MonetizationService.productSubAllInOneMonthly);
          final vipYearlyState = bm.getProductState(MonetizationService.productSubAllInOneYearly);
          final kioskState = bm.getProductState(MonetizationService.productSubKioskMonthly);
          final adsState = bm.getProductState(MonetizationService.productSubRemoveAdsMonthly);
          final vipMonthlyPrice = bm.getStoreProduct(MonetizationService.productSubAllInOneMonthly)?.price ??
              (isDomestic ? '₩5,900' : '\$4.99');
          final vipYearlyPrice = bm.getStoreProduct(MonetizationService.productSubAllInOneYearly)?.price ??
              (isDomestic ? '₩59,000' : '\$49.99');
          final kioskPrice = bm.getStoreProduct(MonetizationService.productSubKioskMonthly)?.price ??
              (isDomestic ? '₩4,900' : '\$3.99');
          final adsPrice = bm.getStoreProduct(MonetizationService.productSubRemoveAdsMonthly)?.price ??
              (isDomestic ? '₩1,900' : '\$1.49');
          final currencyFmt = NumberFormat('#,###');

          return ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              isLandscape ? 6 : 10,
              16,
              isLandscape ? 36 : 90,
            ),
            children: [
              _buildStoreNoticeBanner(bm),
              // 1. Pro Value Proposition Hero Card
              Container(
                padding: EdgeInsets.all(isLandscape ? 16 : 20),
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
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF0F172A).withValues(alpha: 0.18),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Retention Tier & Streak Pill (Wrap for small viewport resilience)
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFFBBF24).withValues(alpha: 0.45)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.workspace_premium_rounded, size: 13, color: Color(0xFFFBBF24)),
                              const SizedBox(width: 4),
                              Text(
                                bm.retentionTierTitle,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFFFBBF24),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.local_fire_department_rounded, size: 13, color: Color(0xFFF97316)),
                              const SizedBox(width: 4),
                              Text(
                                LocalizationService.pick(
                                  ko: '연속 ${bm.activeStreakDays}일 운영 중',
                                  en: 'Active Streak: ${bm.activeStreakDays}d',
                                  ja: '連続運用 ${bm.activeStreakDays}日目',
                                  zh: '连续使用 ${bm.activeStreakDays} 天',
                                  vi: 'Chuỗi hoạt động ${bm.activeStreakDays} ngày',
                                  es: 'Racha activa: ${bm.activeStreakDays} días',
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.diamond_rounded, color: Color(0xFFFBBF24), size: 28),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isSubAllInOne
                                    ? LocalizationService.pick(
                                        ko: '올인원 VIP 정기 구독 이용 중',
                                        en: 'All-in-One VIP Active',
                                        ja: 'オールインワン VIP 利用中',
                                        zh: '全能 VIP 会员已生效',
                                        vi: 'VIP Toàn Diện đang bật',
                                        es: 'VIP Todo-en-Uno Activo',
                                      )
                                    : (bm.isTemporaryPassActive
                                        ? LocalizationService.pick(
                                            ko: '1시간 올인원 VIP 무료 체험 이용 중',
                                            en: '1-Hour Free VIP Pass Active',
                                            ja: '1時間無料 VIP体験 利用中',
                                            zh: '1小时免费 VIP 体验生效中',
                                            vi: 'Đang dùng thử VIP 1 giờ',
                                            es: 'Pase VIP 1h Gratis Activo',
                                          )
                                        : LocalizationService.pick(
                                            ko: '지금까지 약 ${currencyFmt.format(bm.estimatedTotalSavedKRW)}원 절감!',
                                            en: 'Smart Local Attendance & Billing',
                                            ja: 'スマート店舗管理でコスト削減',
                                            zh: '智能本地化考勤与收银管理',
                                            vi: 'Quản lý điểm danh & thu phí thông minh',
                                            es: 'Asistencia y cobros locales inteligentes',
                                          )),
                                style: TextStyle(
                                  fontSize: isLandscape ? 16 : 18,
                                  fontWeight: FontWeight.w900,
                                  color: Colors.white,
                                  letterSpacing: -0.3,
                                ),
                                softWrap: true,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isSubAllInOne
                                    ? LocalizationService.pick(
                                        ko: '무인 태블릿 키오스크와 100% 광고 없는 최적의 매장 환경이 활성화되어 있습니다.',
                                        en: 'Tablet kiosk and 100% ad-free unlimited workspace active.',
                                        ja: '無人キオスクと完全広告なしの無制限環境が有効です。',
                                        zh: '自助考勤终端及 100% 免广告无限制专业环境已启用。',
                                        vi: 'Kiosk điểm danh & không gian 100% không quảng cáo đã sẵn sàng.',
                                        es: 'Quiosco Tablet y entorno ilimitado 100% sin anuncios activos.',
                                      )
                                    : (bm.isTemporaryPassActive
                                        ? LocalizationService.pick(
                                            ko: '현재 1시간 무료 VIP 체험권이 작동 중입니다 (${bm.remainingTemporaryPassFormatted}). 마음에 드시면 아래 정기 플랜을 구독하세요.',
                                            en: '1-Hour VIP Pass active (${bm.remainingTemporaryPassFormatted}). Subscribe below anytime.',
                                            ja: '1時間無料VIP体験が作動中です（${bm.remainingTemporaryPassFormatted}）。定期プランもご検討ください。',
                                            zh: '当前1小时免费 VIP 体验正在生效（${bm.remainingTemporaryPassFormatted}），欢迎在下方升级订阅。',
                                            vi: 'Thẻ VIP 1 giờ đang chạy (${bm.remainingTemporaryPassFormatted}). Đăng ký bên dưới để dùng liên tục.',
                                            es: 'Prueba VIP de 1h activa (${bm.remainingTemporaryPassFormatted}). Suscríbete abajo cuando quieras.',
                                          )
                                        : LocalizationService.pick(
                                            ko: '무료 문자(${bm.cumulativeSavedSmsCount}건)와 자동 출결(${bm.cumulativeCheckInCount}건)로 아낀 운영비의 일부로 100% 쾌적한 VIP 매장을 완성하세요.',
                                            en: 'Save telecom and ERP overhead with unlimited local check-in and billing.',
                                            ja: '無料通知(${bm.cumulativeSavedSmsCount}件)と自動受付(${bm.cumulativeCheckInCount}件)で店舗コストを大幅削減。',
                                            zh: '已为您节省短信(${bm.cumulativeSavedSmsCount}条)与考勤成本，升级 VIP 享全功能无限制。',
                                            vi: 'Tiết kiệm chi phí SMS & vận hành với hệ thống điểm danh tự động tại chỗ.',
                                            es: 'Ahorra costes de SMS y gestión ERP con registro y cobros locales.',
                                          )),
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.white.withValues(alpha: 0.85),
                                  height: 1.45,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // ROI Comparison Strip (100% Full-Width)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.32),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          Text(
                            LocalizationService.proStoreComparisonOld,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: Color(0xFF94A3B8),
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          Text(
                            LocalizationService.proStoreComparisonNew,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF34D399),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    // Feature Pills: 2x2 Grid with 50%:50% Even Split for 100% Width
                    Column(
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _buildFeaturePill(
                                Icons.autorenew_rounded,
                                LocalizationService.pick(
                                  ko: '위약금 0원 즉시 해지',
                                  en: 'Cancel Anytime',
                                  ja: 'いつでも即解約可能',
                                  zh: '随时取消无违约金',
                                  vi: 'Hủy bất cứ lúc nào',
                                  es: 'Cancela cuando quieras',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFeaturePill(
                                Icons.tablet_android_rounded,
                                LocalizationService.pick(
                                  ko: '태블릿 출결 키오스크',
                                  en: 'Tablet Kiosk Pass',
                                  ja: 'キオスク出席端末',
                                  zh: '平板自助考勤终端',
                                  vi: 'Kiosk điểm danh Tablet',
                                  es: 'Quiosco de asistencia',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _buildFeaturePill(
                                Icons.block_flipped,
                                LocalizationService.pick(
                                  ko: '광고 100% 완전 차단',
                                  en: '100% Ad-Free Space',
                                  ja: '広告を100%遮断',
                                  zh: '100% 彻底去广告',
                                  vi: 'Chặn 100% quảng cáo',
                                  es: '100% Libre de anuncios',
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildFeaturePill(
                                Icons.verified_user_outlined,
                                LocalizationService.pick(
                                  ko: '구글 안전 정기 결제',
                                  en: 'Google Play Billing',
                                  ja: 'Google Play 安全決済',
                                  zh: 'Google Play 官方订阅',
                                  vi: 'Thanh toán Google Play',
                                  es: 'Pago seguro Google Play',
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 1-B. Membership Quota & Limit Comparison Card (VIP 무제한 vs 일반 한도)
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: bm.isUnlimitedVip ? const Color(0xFFF59E0B) : AppTheme.borderSubtle,
                    width: bm.isUnlimitedVip ? 1.4 : 0.9,
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
                            color: bm.isUnlimitedVip ? const Color(0xFFFEF3C7) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            bm.membershipPlanLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: bm.isUnlimitedVip ? const Color(0xFFB45309) : const Color(0xFF334155),
                            ),
                          ),
                        ),
                        Text(
                          bm.isUnlimitedVip
                              ? LocalizationService.pick(
                                  ko: '모든 등록 · 수정 100% 무제한',
                                  en: '100% Unlimited Records & Edits',
                                  ja: '登録・編集 100% 無制限',
                                  zh: '全部新增与编辑 100% 无限制',
                                  vi: 'Không giới hạn thêm & sửa dữ liệu',
                                  es: 'Registros y ediciones 100% ilimitados',
                                )
                              : LocalizationService.pick(
                                  ko: '비-VIP 한도 적용 중 → VIP 시 무제한',
                                  en: 'Plan Limits Active → Unlock All in VIP',
                                  ja: '通常枠適用中 → VIPで完全無制限',
                                  zh: '当前受限于基础额度 → VIP 解锁无限制',
                                  vi: 'Đang áp dụng giới hạn → Mở khóa với VIP',
                                  es: 'Límites activos → Desbloquea todo en VIP',
                                ),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: bm.isUnlimitedVip ? const Color(0xFF059669) : AppTheme.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      bm.isUnlimitedVip
                          ? LocalizationService.pick(
                              ko: '회원 등록, 청구서·지출·일정, 맞춤 서식 생성과 모든 정보 수정이 횟수 제한 없이 무제한 제공됩니다.',
                              en: 'All members, invoices, expenses, schedules, custom templates, and monthly edits are completely unlimited.',
                              ja: '会員登録、請求書・経費・予定、カスタム書式およびすべての編集が回数無制限で利用できます。',
                              zh: '会员档案、账单、收支、日程、自定义模板及每月编辑次数均完全无限制。',
                              vi: 'Tất cả học viên, hóa đơn, chi tiêu, lịch trình, mẫu tùy chỉnh và lượt chỉnh sửa đều không giới hạn.',
                              es: 'Miembros, facturas, gastos, horarios, plantillas personalizadas y ediciones mensuales ilimitados.',
                            )
                          : LocalizationService.pick(
                              ko: '• 현재 한도: 회원 최대 ${bm.maxMemberLimit}명 · 수정 월 ${bm.maxMonthlyEditLimit}회 (남은 수정 ${bm.remainingMonthlyEditCount}회) · 맞춤 서식 ${bm.maxCustomTemplateLimit}개\n• 단독 구독도 등록/수정 한도가 적용되며, 올인원 VIP만 100% 무제한입니다.',
                              en: '• Current limits: up to ${bm.maxMemberLimit} members · ${bm.maxMonthlyEditLimit} edits/mo (${bm.remainingMonthlyEditCount} left) · ${bm.maxCustomTemplateLimit} templates\n• Standalone plans carry limits; All-in-One VIP unlocks 100% unlimited access.',
                              ja: '• 現在の上限: 会員${bm.maxMemberLimit}名・編集月${bm.maxMonthlyEditLimit}回（残り${bm.remainingMonthlyEditCount}回）・書式${bm.maxCustomTemplateLimit}件\n• 単品プランには上限があり、オールインワンVIPのみ完全無制限です。',
                              zh: '• 当前限额: 最多${bm.maxMemberLimit}名会员 · 每月${bm.maxMonthlyEditLimit}次修改（剩${bm.remainingMonthlyEditCount}次）· ${bm.maxCustomTemplateLimit}套模板\n• 单项订阅仍有数量限制，仅全能 VIP 享 100% 无限制。',
                              vi: '• Giới hạn: tối đa ${bm.maxMemberLimit} học viên · ${bm.maxMonthlyEditLimit} lượt sửa/tháng (còn ${bm.remainingMonthlyEditCount}) · ${bm.maxCustomTemplateLimit} mẫu\n• Chỉ gói VIP Toàn Diện mới mở khóa không giới hạn 100%.',
                              es: '• Límite actual: hasta ${bm.maxMemberLimit} miembros · ${bm.maxMonthlyEditLimit} ediciones/mes (quedan ${bm.remainingMonthlyEditCount}) · ${bm.maxCustomTemplateLimit} plantillas\n• Solo VIP Todo-en-Uno ofrece uso 100% ilimitado.',
                            ),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.45),
                    ),
                  ],
                ),
              ),

              // 1-C. Reverse-Trial Bridge Card (100% Full-Width Button)
              if (!isSubAllInOne) ...[
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFF93C5FD), width: 1.2),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: bm.isTemporaryPassActive
                                  ? const Color(0xFF059669)
                                  : (tempPassState == ProductPurchaseState.expired
                                      ? const Color(0xFFD97706)
                                      : AppTheme.primaryBlue),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              bm.isTemporaryPassActive
                                  ? LocalizationService.pick(
                                      ko: '기간제 이용 중',
                                      en: 'Pass Active',
                                      ja: '体験中',
                                      zh: '体验生效中',
                                      vi: 'Đang hoạt động',
                                      es: 'Pase activo',
                                    )
                                  : (tempPassState == ProductPurchaseState.expired
                                      ? LocalizationService.pick(
                                          ko: '기간 만료 · 재이용 가능',
                                          en: 'Expired · Available',
                                          ja: '期間終了 · 再利用可',
                                          zh: '已到期 · 可重新领取',
                                          vi: 'Đã hết hạn · Có thể dùng lại',
                                          es: 'Caducado · Disponible',
                                        )
                                      : LocalizationService.pick(
                                          ko: '결제 전 무료 VIP 체험',
                                          en: 'Free VIP Trial',
                                          ja: '無料 VIP 体験',
                                          zh: '免费 VIP 试用',
                                          vi: 'Dùng thử VIP miễn phí',
                                          es: 'Prueba VIP gratuita',
                                        )),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              bm.isTemporaryPassActive
                                  ? LocalizationService.pick(
                                      ko: '1시간 VIP 패스 이용 중 (${bm.remainingTemporaryPassFormatted})',
                                      en: '1-Hour VIP Active (${bm.remainingTemporaryPassFormatted})',
                                      ja: '1時間VIPパス利用中 (${bm.remainingTemporaryPassFormatted})',
                                      zh: '1小时VIP体验生效中 (${bm.remainingTemporaryPassFormatted})',
                                      vi: 'VIP 1 giờ đang chạy (${bm.remainingTemporaryPassFormatted})',
                                      es: 'VIP 1h activo (${bm.remainingTemporaryPassFormatted})',
                                    )
                                  : (tempPassState == ProductPurchaseState.expired
                                      ? LocalizationService.pick(
                                          ko: '이전 체험 기간 만료 · 다시 시작 가능',
                                          en: 'Previous Pass Expired · Start Again',
                                          ja: '前回の体験が終了 · 再開できます',
                                          zh: '上次体验已到期 · 可再次开启',
                                          vi: 'Lượt thử trước đã hết · Có thể bật lại',
                                          es: 'Prueba anterior caducada · Reactivable',
                                        )
                                      : LocalizationService.pick(
                                          ko: '광고 제거 & 태블릿 키오스크 1시간 무료',
                                          en: 'Try 1-Hour Ad-Free Kiosk for Free',
                                          ja: '広告なし＆キオスクを1時間無料体験',
                                          zh: '免广告与平板考勤终端免费体验 1 小时',
                                          vi: 'Dùng thử 1 giờ Kiosk & không quảng cáo',
                                          es: 'Prueba 1 hora de quiosco sin anuncios gratis',
                                        )),
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF1E40AF),
                              ),
                              softWrap: true,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        bm.isTemporaryPassActive
                            ? LocalizationService.pick(
                                ko: '현재 무료 VIP 기간이 활성화되어 있습니다. 이용 기간 종료(${bm.remainingTemporaryPassFormatted}) 후 다시 무료 체험을 이용하실 수 있습니다.',
                                en: 'Your 1-hour pass is active (${bm.remainingTemporaryPassFormatted}). Re-claim unlocks once it expires.',
                                ja: '無料VIP体験が有効です（${bm.remainingTemporaryPassFormatted}）。終了後に再び開始できます。',
                                zh: '1小时免费VIP当前正在生效（${bm.remainingTemporaryPassFormatted}），到期后可再次开启。',
                                vi: 'Gói VIP 1 giờ đang bật (${bm.remainingTemporaryPassFormatted}). Sẽ mở lại sau khi hết hạn.',
                                es: 'Tu pase de 1h está activo (${bm.remainingTemporaryPassFormatted}). Renovable al caducar.',
                              )
                            : LocalizationService.pick(
                                ko: '광고 1회 시청 시 1시간 동안 광고 완전 제거 및 무인 키오스크를 즉시 이용합니다.',
                                en: 'Watch one short video to unlock 1 hour of unlimited ad-free kiosk mode.',
                                ja: '動画広告を1回視聴すると、1時間すべてのVIP機能とキオスクが使えます。',
                                zh: '观看一次激励视频即可立即畅享 1 小时免广告与无限制 VIP 体验。',
                                vi: 'Xem 1 quảng cáo để mở khóa ngay 1 giờ trải nghiệm VIP không giới hạn.',
                                es: 'Mira 1 anuncio para desbloquear 1 hora de modo quiosco VIP sin anuncios.',
                              ),
                        style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45),
                      ),
                      const SizedBox(height: 14),
                      ZeroButton.primary(
                        label: bm.isTemporaryPassActive
                            ? LocalizationService.pick(
                                ko: '이용 중 (${bm.remainingTemporaryPassFormatted}) · 만료 후 재이용',
                                en: 'Active (${bm.remainingTemporaryPassFormatted})',
                                ja: '利用中 (${bm.remainingTemporaryPassFormatted})',
                                zh: '生效中 (${bm.remainingTemporaryPassFormatted})',
                                vi: 'Đang dùng (${bm.remainingTemporaryPassFormatted})',
                                es: 'Activo (${bm.remainingTemporaryPassFormatted})',
                              )
                            : (tempPassState == ProductPurchaseState.expired
                                ? LocalizationService.pick(
                                    ko: '1시간 무료 VIP 다시 시작하기 (광고 1회)',
                                    en: 'Restart 1-Hour VIP Pass (1 Ad)',
                                    ja: '1時間無料 VIP を再開する (広告1回)',
                                    zh: '再次开启 1 小时 VIP 体验 (观看1次)',
                                    vi: 'Bật lại VIP 1 giờ miễn phí (1 QC)',
                                    es: 'Reiniciar pase VIP 1h (1 anuncio)',
                                  )
                                : LocalizationService.pick(
                                    ko: '1시간 무료 VIP 시작하기 (광고 1회)',
                                    en: 'Start 1-Hour VIP Pass (1 Ad)',
                                    ja: '1時間無料 VIP を始める (広告1回)',
                                    zh: '开启 1 小时免费 VIP 体验 (观看1次)',
                                    vi: 'Bắt đầu VIP 1 giờ miễn phí (1 QC)',
                                    es: 'Iniciar pase VIP 1h (1 anuncio)',
                                  )),
                        icon: bm.isTemporaryPassActive
                            ? Icons.timer_outlined
                            : Icons.play_circle_fill_rounded,
                        fullWidth: true,
                        size: ZeroButtonSize.large,
                        onPressed: bm.canClaimTemporaryPass
                            ? () => _claimTemporaryPass(bm, isDomestic)
                            : null,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
              ],

              // 2. Section Title
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 12),
                child: Row(
                  children: [
                    const Icon(Icons.workspace_premium_rounded, size: 18, color: Color(0xFFD97706)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        LocalizationService.pick(
                          ko: '정기 구독 플랜 (Google Play)',
                          en: 'Subscription Plans (Google Play)',
                          ja: '定期購入プラン (Google Play)',
                          zh: '定期订阅方案 (Google Play)',
                          vi: 'Gói thuê bao định kỳ (Google Play)',
                          es: 'Planes de suscripción (Google Play)',
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Plan 1: [Best] 올인원 VIP 패키지 (월간 ₩5,900 / 연간 ₩59,000)
              () {
                final bool vipPending =
                    vipMonthlyState == ProductPurchaseState.pending ||
                    vipYearlyState == ProductPurchaseState.pending;
                final bool vipYearlyActive = vipYearlyState == ProductPurchaseState.active;
                final bool vipMonthlyActive = vipMonthlyState == ProductPurchaseState.active;
                final bool vipActive = isSubAllInOne || vipMonthlyActive || vipYearlyActive;
                final ProductPurchaseState vipCardState = vipPending
                    ? ProductPurchaseState.pending
                    : (vipActive
                        ? ProductPurchaseState.active
                        : (vipYearlyState == ProductPurchaseState.expired ||
                                vipMonthlyState == ProductPurchaseState.expired
                            ? ProductPurchaseState.expired
                            : ProductPurchaseState.notOwned));
                final DateTime? vipExpiry =
                    bm.getProductExpiry(MonetizationService.productSubAllInOneYearly) ??
                    bm.getProductExpiry(MonetizationService.productSubAllInOneMonthly);

                return _buildStoreProductCard(
                  context: context,
                  badgeIcon: Icons.star_rounded,
                  badgeText: LocalizationService.pick(
                    ko: '가장 인기 있는 올인원 VIP',
                    en: 'Most Popular: All-in-One VIP',
                    ja: '一番人気オールインワンVIP',
                    zh: '最受欢迎全能 VIP 方案',
                    vi: 'Phổ biến nhất: VIP Toàn Diện',
                    es: 'Más popular: VIP Todo-en-Uno',
                  ),
                  badgeColor: const Color(0xFFD97706),
                  badgeBgColor: const Color(0xFFFEF3C7),
                  icon: Icons.auto_awesome_rounded,
                  iconColor: const Color(0xFFD97706),
                  title: LocalizationService.pick(
                    ko: '올인원 VIP 패키지 구독 (추천)',
                    en: 'All-in-One VIP Pass (Recommended)',
                    ja: 'オールインワン VIP パック (おすすめ)',
                    zh: '全能 VIP 尊享会员 (推荐)',
                    vi: 'Gói VIP Toàn Diện (Khuyên dùng)',
                    es: 'Pase VIP Todo-en-Uno (Recomendado)',
                  ),
                  description: LocalizationService.pick(
                    ko: '무인 태블릿 키오스크 + 광고 완전 제거를 하나의 정기 구독으로 모두 누리는 최고 가성비 플랜입니다.',
                    en: 'Tablet Kiosk + 100% Ad-Free experience + unlimited quotas in one subscription.',
                    ja: '無人キオスク＋広告完全非表示＋登録無制限をすべて含む最上位プランです。',
                    zh: '一站囊括无人考勤终端、100% 全去广告与全功能无上限额度，性价比最高。',
                    vi: 'Kết hợp Kiosk Tablet + Tắt 100% quảng cáo + Mở khóa mọi giới hạn trong 1 gói.',
                    es: 'Quiosco Tablet + 100% sin anuncios + uso ilimitado en una sola suscripción.',
                  ),
                  features: LocalizationService.pickList(
                    ko: const [
                      '회원 · 청구 · 지출 · 맞춤 서식 등록 개수 100% 무제한',
                      '모든 정보 수정 · 템플릿 편집 횟수 100% 무제한',
                      '안 쓰는 태블릿/휴대폰을 거치형 무인 출결기로 즉시 변신',
                      '앱 내 모든 배너 및 CRUD 전면 광고 완전 차단',
                      '기기 변경 시에도 구글 계정으로 원클릭 구독 복원',
                    ],
                    en: const [
                      'Unlimited members, invoices, expenses, templates & edits',
                      'Transform any tablet into an entrance attendance kiosk',
                      'Instant 4-digit PIN or Name Lookup check-in',
                      '100% ad-free app experience',
                      'One-click Google Play restore across devices',
                    ],
                    ja: const [
                      '会員・請求・経費・書式・編集回数がすべて100%無制限',
                      '手持ちのタブレットをそのまま無人受付キオスク化',
                      '番号4桁または名前検索で1秒チェックイン＆自動消化',
                      'アプリ内のバナー・全画面広告を100%ブロック',
                      '機種変更時もGoogleアカウントでワンタップ復元',
                    ],
                    zh: const [
                      '会员、账单、收支、日程与模板增删改 100% 无限制',
                      '闲置平板秒变自助扫码/输号前台签到终端',
                      '支持4位尾号或姓名检索1秒签到与自动扣减课时',
                      '彻底去除应用内所有横幅广告及操作弹窗广告',
                      '更换手机或重新安装可通过 Google 账号一键恢复订阅',
                    ],
                    vi: const [
                      'Không giới hạn học viên, hóa đơn, chi tiêu, mẫu & lượt sửa',
                      'Biến máy tính bảng thành kiosk tự điểm danh chuyên nghiệp',
                      'Điểm danh 1 giây bằng 4 số cuối hoặc tìm theo tên',
                      'Loại bỏ 100% quảng cáo banner và toàn màn hình',
                      'Khôi phục thuê bao một chạm qua Google Play',
                    ],
                    es: const [
                      'Miembros, facturas, gastos, plantillas y ediciones ilimitadas',
                      'Convierte cualquier tablet en un quiosco de recepción',
                      'Check-in en 1 segundo por PIN de 4 dígitos o nombre',
                      'Experiencia 100% libre de anuncios',
                      'Restauración en un clic entre dispositivos con Google Play',
                    ],
                  ),
                  priceText: vipActive
                      ? (vipYearlyActive
                          ? LocalizationService.pick(
                              ko: '연간 VIP 구독 중',
                              en: 'Annual VIP Active',
                              ja: '年間VIP 利用中',
                              zh: '年度 VIP 生效中',
                              vi: 'VIP Năm đang bật',
                              es: 'VIP Anual Activo',
                            )
                          : LocalizationService.pick(
                              ko: '월간 VIP 구독 중',
                              en: 'Monthly VIP Active',
                              ja: '月額VIP 利用中',
                              zh: '月度 VIP 生效中',
                              vi: 'VIP Tháng đang bật',
                              es: 'VIP Mensual Activo',
                            ))
                      : LocalizationService.pick(
                          ko: '$vipMonthlyPrice / 월',
                          en: '$vipMonthlyPrice / mo',
                          ja: '$vipMonthlyPrice / 月',
                          zh: '$vipMonthlyPrice / 月',
                          vi: '$vipMonthlyPrice / tháng',
                          es: '$vipMonthlyPrice / mes',
                        ),
                  priceSubtext: vipActive
                      ? (vipExpiry != null
                          ? LocalizationService.pick(
                              ko: '이용 만료(갱신) 예정: ${bm.formatShortDate(vipExpiry)} · 중복 구매 차단됨',
                              en: 'Active until ${bm.formatShortDate(vipExpiry)}',
                              ja: '有効期限（更新予定）: ${bm.formatShortDate(vipExpiry)}',
                              zh: '有效期（预计续费）至 ${bm.formatShortDate(vipExpiry)}',
                              vi: 'Hiệu lực đến ${bm.formatShortDate(vipExpiry)}',
                              es: 'Activo hasta ${bm.formatShortDate(vipExpiry)}',
                            )
                          : LocalizationService.pick(
                              ko: '구독 중입니다 (기간 종료 전 중복 결제 차단됨)',
                              en: 'Subscription active (duplicate billing blocked)',
                              ja: 'ご契約中（重複課金は防止されています）',
                              zh: '订阅生效中（已防止重复扣费）',
                              vi: 'Đang đăng ký (Đã chặn thanh toán trùng)',
                              es: 'Suscripción activa (doble cobro bloqueado)',
                            ))
                      : (vipCardState == ProductPurchaseState.expired && vipExpiry != null
                          ? LocalizationService.pick(
                              ko: '이전 구독 만료 (${bm.formatShortDate(vipExpiry)}) · 다시 구독 가능',
                              en: 'Expired on ${bm.formatShortDate(vipExpiry)} · Resubscribe available',
                              ja: '前回終了（${bm.formatShortDate(vipExpiry)}）・再購入可能',
                              zh: '上次订阅已于 ${bm.formatShortDate(vipExpiry)} 到期 · 可重新订阅',
                              vi: 'Đã hết hạn (${bm.formatShortDate(vipExpiry)}) · Có thể đăng ký lại',
                              es: 'Caducó el ${bm.formatShortDate(vipExpiry)} · Renovable',
                            )
                          : LocalizationService.pick(
                              ko: '또는 연간 결제 시 $vipYearlyPrice / 년 (2개월 할인)',
                              en: 'Or save 2 months with annual billing ($vipYearlyPrice/year)',
                              ja: '年額プランなら2ヶ月分お得 ($vipYearlyPrice/年)',
                              zh: '选择年付立省2个月费用 ($vipYearlyPrice/年)',
                              vi: 'Hoặc tiết kiệm 2 tháng với gói năm ($vipYearlyPrice/năm)',
                              es: 'O ahorra 2 meses con el plan anual ($vipYearlyPrice/año)',
                            )),
                  isUnlocked: vipActive,
                  purchaseState: vipCardState,
                  actionButtonText: vipPending
                      ? LocalizationService.pick(
                          ko: '결제 승인 대기 중...',
                          en: 'Purchase Pending...',
                          ja: '承認待ち...',
                          zh: '等待支付确认...',
                          vi: 'Đang chờ duyệt...',
                          es: 'Pago pendiente...',
                        )
                      : (vipActive
                          ? LocalizationService.pick(
                              ko: '구독 중 (올인원 VIP 이용 중)',
                              en: 'Subscribed (VIP Active)',
                              ja: 'ご契約中（オールインワンVIP）',
                              zh: '已订阅（全能 VIP 使用中）',
                              vi: 'Đang đăng ký (VIP Toàn Diện)',
                              es: 'Suscrito (VIP Activo)',
                            )
                          : (vipCardState == ProductPurchaseState.expired
                              ? LocalizationService.pick(
                                  ko: '올인원 VIP 다시 구독 ($vipMonthlyPrice/월)',
                                  en: 'Resubscribe VIP ($vipMonthlyPrice/mo)',
                                  ja: 'VIPを再開する ($vipMonthlyPrice/月)',
                                  zh: '重新订阅 VIP ($vipMonthlyPrice/月)',
                                  vi: 'Đăng ký lại VIP ($vipMonthlyPrice/th)',
                                  es: 'Renovar VIP ($vipMonthlyPrice/mes)',
                                )
                              : LocalizationService.pick(
                                  ko: '올인원 VIP 구독 시작 ($vipMonthlyPrice/월)',
                                  en: 'Start All-in-One VIP ($vipMonthlyPrice/mo)',
                                  ja: 'オールインワンVIPを始める ($vipMonthlyPrice/月)',
                                  zh: '开启全能 VIP ($vipMonthlyPrice/月)',
                                  vi: 'Đăng ký VIP ($vipMonthlyPrice/th)',
                                  es: 'Activar VIP ($vipMonthlyPrice/mes)',
                                ))),
                  actionIcon: vipActive ? Icons.check_circle_rounded : Icons.star_rounded,
                  secondaryButtonText: vipYearlyActive
                      ? LocalizationService.pick(
                          ko: '태블릿 키오스크 바로 열기',
                          en: 'Launch Tablet Kiosk',
                          ja: 'キオスクをすぐ起動',
                          zh: '立即启动平板终端',
                          vi: 'Mở ngay Kiosk Tablet',
                          es: 'Abrir Quiosco Tablet',
                        )
                      : (vipActive
                          ? LocalizationService.pick(
                              ko: '연간 VIP로 업그레이드 ($vipYearlyPrice/년 · 2개월 할인)',
                              en: 'Upgrade to Annual ($vipYearlyPrice/yr)',
                              ja: '年額VIPへアップグレード ($vipYearlyPrice/年)',
                              zh: '升级至年付 VIP ($vipYearlyPrice/年)',
                              vi: 'Nâng cấp gói năm ($vipYearlyPrice/năm)',
                              es: 'Cambiar a plan anual ($vipYearlyPrice/año)',
                            )
                          : LocalizationService.pick(
                              ko: '연간 구독 2개월 할인 ($vipYearlyPrice/년)',
                              en: 'Save 2 Months with Annual Plan ($vipYearlyPrice/yr)',
                              ja: '年額プラン・2ヶ月分お得 ($vipYearlyPrice/年)',
                              zh: '年付套餐享2个月减免 ($vipYearlyPrice/年)',
                              vi: 'Gói năm tiết kiệm 2 tháng ($vipYearlyPrice/năm)',
                              es: 'Ahorra 2 meses con plan anual ($vipYearlyPrice/año)',
                            )),
                  onAction: (vipActive || vipPending)
                      ? null
                      : () => _startPurchase(MonetizationService.productIdAllInOneMonthly),
                  onSecondaryAction: vipPending
                      ? null
                      : (vipYearlyActive
                          ? () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => const TabletKioskScreen()),
                              );
                            }
                          : () => _startPurchase(MonetizationService.productIdAllInOneYearly)),
                );
              }(),
              const SizedBox(height: 18),

              // Plan 2: 태블릿 자율출결 키오스크 단독 구독 (월 ₩4,900)
              () {
                final bool kioskCovered = kioskState == ProductPurchaseState.coveredByVip;
                final bool kioskPending = kioskState == ProductPurchaseState.pending;
                final bool kioskActive = isSubKiosk ||
                    kioskState == ProductPurchaseState.active ||
                    kioskCovered;
                final ProductPurchaseState effectiveKioskState = kioskPending
                    ? ProductPurchaseState.pending
                    : (kioskCovered
                        ? ProductPurchaseState.coveredByVip
                        : (kioskActive
                            ? ProductPurchaseState.active
                            : (kioskState == ProductPurchaseState.expired
                                ? ProductPurchaseState.expired
                                : ProductPurchaseState.notOwned)));
                final DateTime? kioskExpiry =
                    bm.getProductExpiry(MonetizationService.productSubKioskMonthly);

                return _buildStoreProductCard(
                  context: context,
                  badgeIcon: Icons.tablet_mac_rounded,
                  badgeText: LocalizationService.pick(
                    ko: '태블릿 무인 출결 전용',
                    en: 'Tablet Kiosk Only',
                    ja: 'キオスク専用プラン',
                    zh: '平板考勤机专属版',
                    vi: 'Chuyên dụng Kiosk Tablet',
                    es: 'Solo Quiosco Tablet',
                  ),
                  badgeColor: const Color(0xFF2563EB),
                  badgeBgColor: const Color(0xFFEFF6FF),
                  icon: Icons.tablet_mac_rounded,
                  iconColor: const Color(0xFF2563EB),
                  title: LocalizationService.pick(
                    ko: '태블릿 키오스크 단독 구독',
                    en: 'Tablet Kiosk Standalone',
                    ja: 'タブレットキオスク単独プラン',
                    zh: '平板自助考勤终端单享版',
                    vi: 'Gói Kiosk Tablet Riêng Lẻ',
                    es: 'Quiosco Tablet Individual',
                  ),
                  description: LocalizationService.pick(
                    ko: '학원·공방·피트니스 센터 입구 공기계 태블릿에 거치해두고 회원들이 자율 출석 체크하는 기능만 가볍게 구독하세요.',
                    en: 'Place an extra tablet at your studio entrance for fast self check-ins.',
                    ja: 'スタジオ入口のタブレットで会員様がセルフチェックインできる単体プランです。',
                    zh: '将平板摆放在前台入口即可让学员自助完成签到与课时核销。',
                    vi: 'Đặt máy tính bảng tại quầy để học viên tự điểm danh nhanh chóng.',
                    es: 'Coloca una tablet en la entrada para el registro autónomo de asistentes.',
                  ),
                  features: LocalizationService.pickList(
                    ko: const [
                      '입구 거치형 무인 출결 키오스크 단독 무제한 이용',
                      '회원 뒷번호 4자리 터치 출결 & 자동 회차 차감',
                      '단독 플랜 한도: 회원 최대 30명 · 수정 월 15회 · 서식 8개',
                      '등록·수정 100% 무제한은 [올인원 VIP]에서 제공',
                    ],
                    en: const [
                      'Unlimited entrance self-check-in kiosk mode',
                      '4-digit PIN & Name Lookup touch check-in',
                      'Standalone limits: up to 30 members, 15 edits/month',
                      'Full unlimited quotas require All-in-One VIP',
                    ],
                    ja: const [
                      '入口据え置き無人チェックイン端末が利用可能',
                      '電話番号4桁または名前検索でタッチ出席＆自動消化',
                      '単体上限: 会員30名・月15回編集・書式8件',
                      '全機能の完全無制限はオールインワンVIPに含まれます',
                    ],
                    zh: const [
                      '支持入口平板无人值守自助考勤模式',
                      '支持尾号4位及姓名搜索点击签到并自动扣课时',
                      '单享额度: 最多30名会员 · 每月15次修改 · 8套模板',
                      '全部功能无限制请升级【全能 VIP 方案】',
                    ],
                    vi: const [
                      'Sử dụng không giới hạn chế độ Kiosk tại quầy',
                      'Chạm PIN 4 số hoặc tìm tên & tự động trừ buổi',
                      'Giới hạn gói lẻ: tối đa 30 học viên, 15 lượt sửa/tháng',
                      'Mở khóa không giới hạn 100% với gói VIP Toàn Diện',
                    ],
                    es: const [
                      'Modo quiosco ilimitado en la entrada del centro',
                      'Check-in táctil con PIN de 4 dígitos o nombre',
                      'Límites: hasta 30 miembros y 15 ediciones/mes',
                      'Uso 100% ilimitado incluido en VIP Todo-en-Uno',
                    ],
                  ),
                  priceText: kioskCovered
                      ? LocalizationService.tr('pro_status_included')
                      : (kioskActive
                          ? LocalizationService.tr('pro_status_active')
                          : '$kioskPrice / ${LocalizationService.pick(ko: '월', en: 'mo', ja: '月', zh: '月', vi: 'tháng', es: 'mes')}'),
                  priceSubtext: kioskCovered
                      ? LocalizationService.pick(
                          ko: '올인원 VIP 구독에 포함되어 별도 결제가 필요 없습니다.',
                          en: 'Included with your All-in-One VIP subscription.',
                          ja: 'オールインワンVIPに含まれるため追加料金は不要です。',
                          zh: '已包含在全能 VIP 会员中，无需重复付费。',
                          vi: 'Đã bao gồm trong gói VIP Toàn Diện.',
                          es: 'Incluido en tu suscripción VIP Todo-en-Uno.',
                        )
                      : (kioskActive
                          ? (kioskExpiry != null
                              ? '${bm.formatShortDate(kioskExpiry)} (${LocalizationService.tr('pro_status_active')})'
                              : LocalizationService.tr('pro_status_active'))
                          : (effectiveKioskState == ProductPurchaseState.expired && kioskExpiry != null
                              ? bm.formatShortDate(kioskExpiry)
                              : LocalizationService.pick(
                                  ko: '구글 플레이 매월 자동 갱신 (언제든 취소 가능)',
                                  en: 'Google Play auto-renewal (Cancel anytime)',
                                  ja: 'Google Play 自動更新（いつでも解約可能）',
                                  zh: 'Google Play 按月自动续订（可随时取消）',
                                  vi: 'Tự động gia hạn Google Play (Hủy mọi lúc)',
                                  es: 'Renovación Google Play (Cancela cuando quieras)',
                                ))),
                  isUnlocked: kioskActive,
                  purchaseState: effectiveKioskState,
                  actionButtonText: kioskPending
                      ? LocalizationService.pick(
                          ko: '결제 승인 대기 중...',
                          en: 'Purchase Pending...',
                          ja: '承認待ち...',
                          zh: '等待支付确认...',
                          vi: 'Đang chờ duyệt...',
                          es: 'Pago pendiente...',
                        )
                      : (kioskCovered
                          ? LocalizationService.tr('pro_status_included')
                          : (kioskActive
                              ? LocalizationService.pick(
                                  ko: '구독 중 (키오스크 이용 중)',
                                  en: 'Subscribed (Kiosk Active)',
                                  ja: 'ご契約中 (キオスク有効)',
                                  zh: '已订阅 (考勤机生效中)',
                                  vi: 'Đang đăng ký (Kiosk đang bật)',
                                  es: 'Suscrito (Quiosco Activo)',
                                )
                              : (effectiveKioskState == ProductPurchaseState.expired
                                  ? '${LocalizationService.tr('pro_cta_buy')} ($kioskPrice)'
                                  : '${LocalizationService.tr('pro_cta_buy')} ($kioskPrice)'))),
                  actionIcon: kioskActive ? Icons.check_circle_rounded : Icons.tablet_mac_rounded,
                  secondaryButtonText: kioskActive
                      ? LocalizationService.pick(
                          ko: '키오스크 바로 실행',
                          en: 'Launch Kiosk Mode',
                          ja: 'キオスクを起動',
                          zh: '立即启动考勤机',
                          vi: 'Mở Kiosk ngay',
                          es: 'Abrir modo Quiosco',
                        )
                      : null,
                  onAction: (kioskActive || kioskPending)
                      ? null
                      : () => _startPurchase(MonetizationService.productIdKioskMonthly),
                  onSecondaryAction: kioskActive
                      ? () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const TabletKioskScreen()),
                          );
                        }
                      : null,
                );
              }(),
              const SizedBox(height: 18),

              // Plan 3: 광고 제거 단독 구독 (월 ₩1,900 - 한 달)
              () {
                final bool adsCovered = adsState == ProductPurchaseState.coveredByVip;
                final bool adsPending = adsState == ProductPurchaseState.pending;
                final bool adsActive = isSubNoAds ||
                    adsState == ProductPurchaseState.active ||
                    adsCovered;
                final ProductPurchaseState effectiveAdsState = adsPending
                    ? ProductPurchaseState.pending
                    : (adsCovered
                        ? ProductPurchaseState.coveredByVip
                        : (adsActive
                            ? ProductPurchaseState.active
                            : (adsState == ProductPurchaseState.expired
                                ? ProductPurchaseState.expired
                                : ProductPurchaseState.notOwned)));
                final DateTime? adsExpiry =
                    bm.getProductExpiry(MonetizationService.productSubRemoveAdsMonthly);

                return _buildStoreProductCard(
                  context: context,
                  badgeIcon: Icons.block_flipped,
                  badgeText: LocalizationService.pick(
                    ko: '광고 없는 쾌적함',
                    en: 'Ad-Free Experience',
                    ja: '広告なしの快適空間',
                    zh: '纯净无广告体验',
                    vi: 'Không gian sạch quảng cáo',
                    es: 'Experiencia sin anuncios',
                  ),
                  badgeColor: const Color(0xFF059669),
                  badgeBgColor: const Color(0xFFECFDF5),
                  icon: Icons.block_flipped,
                  iconColor: const Color(0xFF059669),
                  title: LocalizationService.pick(
                    ko: '광고 제거 단독 구독',
                    en: 'Remove Ads Standalone',
                    ja: '広告非表示単独プラン',
                    zh: '免广告单享版',
                    vi: 'Gói Xóa Quảng Cáo',
                    es: 'Solo Sin Anuncios',
                  ),
                  description: LocalizationService.pick(
                    ko: '하단 배너 및 팝업 광고를 완전히 없애 화면을 널찍하고 쾌적하게 사용하고 싶을 때 추천합니다.',
                    en: 'Hide all banner and interstitial ads for a clean, distraction-free workspace.',
                    ja: 'バナーおよび全画面広告を非表示にし、広く見やすい画面で利用できます。',
                    zh: '隐藏所有底部横幅及弹窗广告，享受清爽宽阔的工作界面。',
                    vi: 'Ẩn hoàn toàn banner và quảng cáo toàn màn hình để làm việc gọn gàng hơn.',
                    es: 'Oculta todos los banners y anuncios intersticiales para mayor comodidad.',
                  ),
                  features: LocalizationService.pickList(
                    ko: const [
                      '하단 배너 및 CRUD 전면 광고 완전 숨김',
                      '단독 플랜 한도: 회원 최대 30명 · 수정 월 15회 · 서식 8개',
                      '등록·수정 100% 무제한은 [올인원 VIP]에서 제공',
                    ],
                    en: const [
                      'Completely hide banner and interstitial ads',
                      'Standalone limits: up to 30 members, 15 edits/month',
                      'Full unlimited quotas require All-in-One VIP',
                    ],
                    ja: const [
                      '下部バナーおよび操作時の全画面広告を完全に非表示',
                      '単体上限: 会員30名・月15回編集・書式8件',
                      '全機能の完全無制限はオールインワンVIPに含まれます',
                    ],
                    zh: const [
                      '彻底隐藏底部横幅与操作全屏广告',
                      '单享额度: 最多30名会员 · 每月15次修改 · 8套模板',
                      '全部功能无限制请升级【全能 VIP 方案】',
                    ],
                    vi: const [
                      'Ẩn hoàn toàn quảng cáo banner và toàn màn hình',
                      'Giới hạn gói lẻ: tối đa 30 học viên, 15 lượt sửa/tháng',
                      'Mở khóa không giới hạn 100% với gói VIP Toàn Diện',
                    ],
                    es: const [
                      'Oculta por completo banners y anuncios intersticiales',
                      'Límites: hasta 30 miembros y 15 ediciones/mes',
                      'Uso 100% ilimitado incluido en VIP Todo-en-Uno',
                    ],
                  ),
                  priceText: adsCovered
                      ? LocalizationService.tr('pro_status_included')
                      : (adsActive
                          ? LocalizationService.tr('pro_status_active')
                          : '$adsPrice / ${LocalizationService.pick(ko: '월 (한 달)', en: 'mo', ja: '月', zh: '月', vi: 'tháng', es: 'mes')}'),
                  priceSubtext: adsCovered
                      ? LocalizationService.pick(
                          ko: '올인원 VIP 구독에 포함되어 별도 결제가 필요 없습니다.',
                          en: 'Included with your All-in-One VIP subscription.',
                          ja: 'オールインワンVIPに含まれるため追加料金は不要です。',
                          zh: '已包含在全能 VIP 会员中，无需重复付费。',
                          vi: 'Đã bao gồm trong gói VIP Toàn Diện.',
                          es: 'Incluido en tu suscripción VIP Todo-en-Uno.',
                        )
                      : (adsActive
                          ? (adsExpiry != null
                              ? '${bm.formatShortDate(adsExpiry)} (${LocalizationService.tr('pro_status_active')})'
                              : LocalizationService.tr('pro_status_active'))
                          : (effectiveAdsState == ProductPurchaseState.expired && adsExpiry != null
                              ? bm.formatShortDate(adsExpiry)
                              : LocalizationService.pick(
                                  ko: '부담 없는 한 달 정기 구독 (언제든 구글 플레이에서 해지)',
                                  en: 'Affordable monthly subscription (Cancel anytime)',
                                  ja: 'お手頃な月額プラン（いつでも解約可能）',
                                  zh: '超值按月订阅（可随时在 Google Play 取消）',
                                  vi: 'Gói tháng tiết kiệm (Hủy bất cứ lúc nào)',
                                  es: 'Suscripción mensual económica (Cancela cuando quieras)',
                                ))),
                  isUnlocked: adsActive,
                  purchaseState: effectiveAdsState,
                  actionButtonText: adsPending
                      ? LocalizationService.pick(
                          ko: '결제 승인 대기 중...',
                          en: 'Purchase Pending...',
                          ja: '承認待ち...',
                          zh: '等待支付确认...',
                          vi: 'Đang chờ duyệt...',
                          es: 'Pago pendiente...',
                        )
                      : (adsCovered
                          ? LocalizationService.tr('pro_status_included')
                          : (adsActive
                              ? LocalizationService.pick(
                                  ko: '구독 중 (광고 제거 이용 중)',
                                  en: 'Subscribed (Ad-Free Active)',
                                  ja: 'ご契約中 (広告非表示中)',
                                  zh: '已订阅 (免广告生效中)',
                                  vi: 'Đang đăng ký (Đã tắt quảng cáo)',
                                  es: 'Suscrito (Sin Anuncios Activo)',
                                )
                              : '${LocalizationService.tr('pro_cta_buy')} ($adsPrice)')),
                  actionIcon: adsActive ? Icons.check_circle_rounded : Icons.block_flipped,
                  onAction: (adsActive || adsPending)
                      ? null
                      : () => _startPurchase(MonetizationService.productIdRemoveAdsMonthly),
                );
              }(),
              const SizedBox(height: 22),

              // 3. Subscription Management Notice (100% Full-Width Card & CTA Button)
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
                      children: [
                        const Icon(Icons.shield_outlined, color: AppTheme.primaryBlue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            LocalizationService.pick(
                              ko: '정기 구독 안내 및 해지 방법',
                              en: 'Subscription Terms & Cancellation',
                              ja: '定期購入のご案内および解約方法',
                              zh: '订阅说明与退订方式',
                              vi: 'Điều khoản & cách hủy gói',
                              es: 'Términos y cancelación de suscripción',
                            ),
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      LocalizationService.pick(
                        ko: '• 모든 플랜은 구글 플레이(Google Play) 공식 정기 결제로 안전하게 결제됩니다.\n• 언제든지 [Google Play 스토어 앱 > 우측 상단 프로필 > 결제 및 정기 결제]에서 터치 한 번으로 위약금 없이 즉시 해지하실 수 있습니다.\n• 스마트폰을 교체하거나 재설치하셔도 상단 [구독 복원] 버튼으로 이용 권한이 즉시 동기화됩니다.',
                        en: '• All subscriptions are securely billed through Google Play.\n• Cancel anytime without penalty in Google Play Store > Profile > Payments & subscriptions.\n• Switch devices anytime using the Restore button above.',
                        ja: '• すべてのプランはGoogle Play公式決済で安全に処理されます。\n• いつでもGoogle Playストア＞お支払いと定期購入から違約金なしで即座に解約できます。\n• 機種変更や再インストール時も上部の［購入を復元］で権限を同期できます。',
                        zh: '• 所有方案均通过 Google Play 官方安全扣费。\n• 可随时在 Google Play 商店 > 个人资料 > 付款与订阅中一键无违约金取消。\n• 更换设备或重装后可点击上方「恢复购买」一键同步权益。',
                        vi: '• Mọi gói đều được thanh toán an toàn qua Google Play.\n• Hủy bất kỳ lúc nào không mất phí tại Google Play > Thanh toán & gói thuê bao.\n• Đổi máy mới vẫn khôi phục dễ dàng bằng nút Khôi phục ở trên.',
                        es: '• Todas las suscripciones se facturan de forma segura por Google Play.\n• Cancela sin penalización cuando quieras desde Google Play > Pagos y suscripciones.\n• Cambia de móvil sincronizando tus compras con el botón Restaurar.',
                      ),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppTheme.textSecondary,
                        height: 1.6,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ZeroButton.secondary(
                      label: LocalizationService.pick(
                        ko: 'Google Play 정기 결제 관리',
                        en: 'Manage Google Play Subscriptions',
                        ja: 'Google Play 定期購入を管理',
                        zh: '管理 Google Play 订阅',
                        vi: 'Quản lý gói trên Google Play',
                        es: 'Gestionar suscripciones Google Play',
                      ),
                      icon: Icons.open_in_new_rounded,
                      fullWidth: true,
                      size: ZeroButtonSize.medium,
                      onPressed: _openPlaySubscriptions,
                    ),
                  ],
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 18),

                // Developer Testing Unlock & Reset Row (Debug mode only)
                Row(
                  children: [
                    Expanded(
                      child: ZeroButton.tint(
                        label: LocalizationService.pick(
                          ko: '[테스트] 전체 언락',
                          en: '[Test] Unlock All',
                          ja: '[テスト] 全機能解除',
                          zh: '[测试] 全部解锁',
                          vi: '[Thử] Mở khóa tất cả',
                          es: '[Test] Desbloquear todo',
                        ),
                        icon: Icons.flash_on_rounded,
                        size: ZeroButtonSize.medium,
                        fullWidth: true,
                        onPressed: () {
                          MonetizationService.instance.debugUnlockAll();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                LocalizationService.tr('pro_banner_vip'),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ZeroButton.tint(
                        label: LocalizationService.pick(
                          ko: '[테스트] 초기화',
                          en: '[Test] Reset All',
                          ja: '[テスト] 初期化',
                          zh: '[测试] 重置状态',
                          vi: '[Thử] Đặt lại',
                          es: '[Test] Restablecer',
                        ),
                        icon: Icons.refresh_rounded,
                        size: ZeroButtonSize.medium,
                        fullWidth: true,
                        onPressed: () {
                          MonetizationService.instance.debugResetAll();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                LocalizationService.tr('pro_banner_free'),
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildFeaturePill(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 14, color: const Color(0xFFFBBF24)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 2,
              softWrap: true,
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                color: Colors.white,
                height: 1.25,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStoreProductCard({
    required BuildContext context,
    IconData? badgeIcon,
    required String badgeText,
    required Color badgeColor,
    required Color badgeBgColor,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required List<String> features,
    required String priceText,
    required String priceSubtext,
    required bool isUnlocked,
    ProductPurchaseState purchaseState = ProductPurchaseState.notOwned,
    required String actionButtonText,
    IconData? actionIcon,
    VoidCallback? onAction,
    String? secondaryButtonText,
    VoidCallback? onSecondaryAction,
  }) {
    final String? stateChipLabel;
    final Color stateChipColor;
    final Color stateChipBg;
    switch (purchaseState) {
      case ProductPurchaseState.active:
        stateChipLabel = LocalizationService.pick(
          ko: '구독 중',
          en: 'Subscribed',
          ja: '契約中',
          zh: '已订阅',
          vi: 'Đang dùng',
          es: 'Suscrito',
        );
        stateChipColor = const Color(0xFF047857);
        stateChipBg = const Color(0xFFD1FAE5);
        break;
      case ProductPurchaseState.coveredByVip:
        stateChipLabel = LocalizationService.pick(
          ko: 'VIP 포함',
          en: 'In VIP',
          ja: 'VIPに含む',
          zh: 'VIP 已包含',
          vi: 'Gồm trong VIP',
          es: 'Incluido VIP',
        );
        stateChipColor = const Color(0xFF0F766E);
        stateChipBg = const Color(0xFFCCFBF1);
        break;
      case ProductPurchaseState.pending:
        stateChipLabel = LocalizationService.pick(
          ko: '결제 대기',
          en: 'Pending',
          ja: '承認待ち',
          zh: '待确认',
          vi: 'Đang chờ',
          es: 'Pendiente',
        );
        stateChipColor = const Color(0xFFB45309);
        stateChipBg = const Color(0xFFFEF3C7);
        break;
      case ProductPurchaseState.expired:
        stateChipLabel = LocalizationService.pick(
          ko: '기간 만료 · 재구독 가능',
          en: 'Expired · Renew',
          ja: '期限切れ · 再購入可',
          zh: '已到期 · 可续购',
          vi: 'Hết hạn · Đăng ký lại',
          es: 'Caducado · Renovar',
        );
        stateChipColor = const Color(0xFFBE123C);
        stateChipBg = const Color(0xFFFFE4E6);
        break;
      case ProductPurchaseState.notOwned:
        stateChipLabel = null;
        stateChipColor = badgeColor;
        stateChipBg = badgeBgColor;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? const Color(0xFF10B981)
              : (purchaseState == ProductPurchaseState.pending
                  ? const Color(0xFFF59E0B)
                  : const Color(0xFFE2E8F0)),
          width: (isUnlocked || purchaseState == ProductPurchaseState.pending) ? 1.8 : 1.0,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Badge & Status Pill & Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: badgeBgColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (badgeIcon != null) ...[
                            Icon(badgeIcon, size: 14, color: badgeColor),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            badgeText,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: badgeColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (stateChipLabel != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                        decoration: BoxDecoration(
                          color: stateChipBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: stateChipColor.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          stateChipLabel,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w900,
                            color: stateChipColor,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Title & Description
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            description,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),

          // Features List
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.check_circle_rounded, size: 15, color: AppTheme.softMint),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      f,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF334155),
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.borderSubtle, height: 1),
          const SizedBox(height: 14),

          // Price & Subtext
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                priceText,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: isUnlocked ? const Color(0xFF059669) : const Color(0xFFD97706),
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                priceSubtext,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Primary Action Button (100% Full Width)
          ZeroButton.primary(
            label: actionButtonText,
            icon: isUnlocked ? Icons.check_circle_rounded : actionIcon,
            fullWidth: true,
            size: ZeroButtonSize.large,
            isLoading: purchaseState == ProductPurchaseState.pending,
            onPressed: onAction,
          ),

          // Optional Secondary Action Button (100% Full Width)
          if (secondaryButtonText != null && onSecondaryAction != null) ...[
            const SizedBox(height: 10),
            ZeroButton.secondary(
              label: secondaryButtonText,
              icon: Icons.savings_rounded,
              fullWidth: true,
              size: ZeroButtonSize.large,
              onPressed: onSecondaryAction,
            ),
          ],
        ],
      ),
    );
  }
}
