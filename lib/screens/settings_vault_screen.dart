import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
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
import '../services/region_workflow_service.dart';
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
          title: LocalizationService.pick(
            ko: '로컬 100% 보안 금고',
            en: '100% On-Device Local Vault',
            ja: '100% ローカル暗号化保管庫',
            zh: '100% 本地安全加密库',
            vi: 'Kho lưu trữ cục bộ an toàn 100%',
            es: 'Bóveda Local 100% Privada',
          ),
          message: LocalizationService.pick(
            ko: '체크앤페이는 외부 서버로 단 1바이트의 개인정보도 전송하지 않습니다.\n\n내 스마트폰 기기에만 AES 암호화되어 안전하게 보관되며, 원하실 때 언제든 엑셀(CSV)이나 암호화 백업 파일로 추출할 수 있어요.',
            en: 'Check & Pay never sends a single byte of member or billing data to external servers.\n\nEverything stays encrypted on your device and can be exported to CSV or JSON anytime.',
            ja: '外部サーバーへ個人情報を1バイトも送信しません。\n\nお使いの端末内に安全に暗号化保存され、いつでもCSVやバックアップファイルへ出力できます。',
            zh: 'Check & Pay 不会向外部服务器上传任何会员或账单隐私数据。\n\n所有记录安全加密保存在本地设备，可随时导出为 CSV 或备份文件。',
            vi: 'Ứng dụng không gửi bất kỳ dữ liệu cá nhân nào lên máy chủ ngoài.\n\nMọi thứ được lưu an toàn trên thiết bị và có thể xuất CSV/bản sao lưu bất cứ lúc nào.',
            es: 'Check & Pay no envía ni un solo byte de tus datos a servidores externos.\n\nTodo queda cifrado en tu dispositivo y puedes exportarlo a CSV o copia JSON cuando quieras.',
          ),
          tip: LocalizationService.pick(
            ko: '스튜디오 상호명, 수납 계좌번호, 자동 문자 양식 편집도 모두 여기서 관리하실 수 있습니다.',
            en: 'Manage your studio profile, bank/payout details, templates, and country/currency settings here.',
            ja: '屋号・振込先口座・メッセージ書式・国と通貨設定もすべてここから管理できます。',
            zh: '工作室名称、收款账户、消息模板及国家/货币设置均可在此统一管理。',
            vi: 'Quản lý tên trung tâm, tài khoản nhận tiền, mẫu tin nhắn và vùng/tiền tệ ngay tại đây.',
            es: 'Gestiona tu negocio, datos bancarios, plantillas e idioma/moneda desde aquí.',
          ),
          buttonText: LocalizationService.pick(
            ko: '안심하고 사용할게요',
            en: 'Got It, Continue',
            ja: '安心して利用する',
            zh: '放心开始使用',
            vi: 'Đã hiểu, tiếp tục',
            es: 'Entendido, continuar',
          ),
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
                ? LocalizationService.pick(
                    ko: '무인 키오스크 전용 모드가 활성화되었습니다. 이제 앱 실행 시 출결 화면으로 바로 진입합니다.',
                    en: 'Dedicated Kiosk Auto-Launch enabled. App will open directly to check-in screen.',
                    ja: 'キオスク自動起動が有効になりました。次回から受付画面で直接起動します。',
                    zh: '已启用无人考勤机专机模式。下次打开应用将直接进入签到屏。',
                    vi: 'Đã bật tự động mở Kiosk. Ứng dụng sẽ vào thẳng màn hình điểm danh.',
                    es: 'Inicio automático de Quiosco activado. Al abrir irá directo al registro.',
                  )
                : LocalizationService.pick(
                    ko: '무인 키오스크 전용 모드가 해제되었습니다. 앱 실행 시 관리자 대시보드로 진입합니다.',
                    en: 'Dedicated Kiosk Auto-Launch turned off. App opens to Admin Dashboard.',
                    ja: 'キオスク自動起動を解除しました。管理ダッシュボードで起動します。',
                    zh: '已关闭专机自动启动模式。下次将进入管理员控制台。',
                    vi: 'Đã tắt tự động mở Kiosk. Ứng dụng sẽ vào bảng điều khiển quản lý.',
                    es: 'Inicio automático de Quiosco desactivado. Se abrirá el panel admin.',
                  ),
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
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B), size: 26),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LocalizationService.tr('kiosk_empty_members_title'),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: Text(
          LocalizationService.tr('kiosk_empty_members_desc'),
          style: const TextStyle(fontSize: 13.5, height: 1.5, color: AppTheme.textPrimary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ZeroButton.primary(
                label: LocalizationService.tr('kiosk_start_with_samples'),
                icon: Icons.group_add_rounded,
                size: ZeroButtonSize.medium,
                fullWidth: true,
                onPressed: () async {
                  Navigator.pop(ctx);
                  await DatabaseService.instance.restoreSampleData();
                  await ref.read(membersProvider.notifier).reload();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(LocalizationService.pick(
                        ko: '샘플 학생 5명이 등록되었습니다. 학생용 키오스크를 시작합니다.',
                        en: 'Added 5 sample members. Starting Kiosk mode.',
                        ja: 'サンプル会員5名を登録しました。キオスクを開始します。',
                        zh: '已添加 5 位示例会员，正在启动考勤机模式。',
                        vi: 'Đã thêm 5 hội viên mẫu. Bắt đầu chế độ Kiosk.',
                        es: '5 miembros de prueba añadidos. Iniciando Quiosco.',
                      ))),
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
                label: LocalizationService.tr('kiosk_test_mode_btn'),
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
                label: LocalizationService.tr('btn_close'),
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
        title: Row(
          children: [
            const Icon(Icons.screen_lock_portrait_rounded, color: AppTheme.primaryBlue, size: 24),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LocalizationService.pick(
                  ko: '안드로이드 앱 화면 고정 가이드',
                  en: 'Android Screen Pinning / Guided Access',
                  ja: '画面固定（ピン留め）ガイド',
                  zh: '平板应用锁屏 / 屏幕固定指南',
                  vi: 'Hướng dẫn ghim màn hình Kiosk',
                  es: 'Guía de Fijación de Pantalla (Modo Quiosco)',
                ),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
                  ko: '학생들이 유튜브를 보거나 다른 앱으로 이탈하지 못하도록 기기를 완벽한 무인 키오스크로 잠그는 방법입니다.',
                  en: 'Lock your tablet or phone inside the check-in screen so visitors cannot exit to other apps.',
                  ja: '受講生が他のアプリを開けないよう、端末を受付専用キオスクとして固定ロックする方法です。',
                  zh: '将设备锁定在签到界面，防止学员切换到其他应用，打造真正的无人值守前台。',
                  vi: 'Khóa thiết bị trên màn hình điểm danh để học viên không thoát ra ứng dụng khác.',
                  es: 'Bloquea la tablet en la pantalla de registro para que nadie salga a otras apps.',
                ),
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.45),
              ),
              const SizedBox(height: 14),
              _buildPinStep(
                LocalizationService.pick(ko: '1단계: 안드로이드 설정', en: 'Step 1: Device Security Settings', ja: 'ステップ1: 端末の設定', zh: '第1步：系统安全设置', vi: 'Bước 1: Cài đặt bảo mật', es: 'Paso 1: Ajustes de Seguridad'),
                LocalizationService.pick(
                  ko: '스마트폰/태블릿의 [설정] > [보안 및 개인정보 보호] (또는 생체 인식 및 보안) 메뉴로 이동합니다.',
                  en: 'Open Settings > Security & Privacy (on iPad: Accessibility > Guided Access).',
                  ja: '端末の[設定] > [セキュリティとプライバシー] (iPadはアクセスガイド) を開きます。',
                  zh: '进入手机/平板 [设置] > [安全与隐私] > [更多安全设置]。',
                  vi: 'Mở Cài đặt > Bảo mật & Quyền riêng tư > Cài đặt bảo mật khác.',
                  es: 'Abre Ajustes > Seguridad y Privacidad (en iPad: Acceso Guiado).',
                ),
              ),
              const SizedBox(height: 10),
              _buildPinStep(
                LocalizationService.pick(ko: '2단계: 앱 고정 켜기', en: 'Step 2: Enable App Pinning', ja: 'ステップ2: 画面の固定をオン', zh: '第2步：开启屏幕固定', vi: 'Bước 2: Bật ghim ứng dụng', es: 'Paso 2: Activar Fijar App'),
                LocalizationService.pick(
                  ko: '[기타 보안 설정] > [앱 고정] (또는 화면 고정) 항목을 찾아 켭니다.',
                  en: 'Find "App Pinning" (or "Screen Pinning") and toggle it ON.',
                  ja: '[その他のセキュリティ設定] > [画面の固定] をオンにします。',
                  zh: '找到并开启 [屏幕固定 / 应用固定] 开关。',
                  vi: 'Tìm mục [Ghim ứng dụng / Ghim màn hình] và gạt bật.',
                  es: 'Busca y activa "Fijar aplicaciones" o "Fijar pantalla".',
                ),
              ),
              const SizedBox(height: 10),
              _buildPinStep(
                LocalizationService.pick(ko: '3단계: 체크앤페이 고정', en: 'Step 3: Pin Check & Pay', ja: 'ステップ3: アプリをピン留め', zh: '第3步：锁定本应用', vi: 'Bước 3: Ghim Check & Pay', es: 'Paso 3: Fijar Check & Pay'),
                LocalizationService.pick(
                  ko: '체크앤페이 키오스크 화면을 켠 뒤, 최근 사용 앱 버튼(III)을 누르고 체크앤페이 아이콘을 터치하여 [이 앱 고정]을 선택합니다.',
                  en: 'Open Check & Pay Kiosk, open Recent Apps, tap the app icon, and choose "Pin this app".',
                  ja: 'キオスク画面を開いた状態で履歴ボタンを押し、アプリアイコンから[固定]を選択します。',
                  zh: '打开考勤机页面后，点击多任务键，长按或点击应用图标选择[固定此应用]。',
                  vi: 'Mở màn hình Kiosk, nhấn phím Đa nhiệm, chạm biểu tượng app và chọn [Ghim].',
                  es: 'Abre el Quiosco, ve a Apps Recientes, toca el icono y elige "Fijar esta app".',
                ),
              ),
              const SizedBox(height: 10),
              _buildPinStep(
                LocalizationService.pick(ko: '해제 방법 (관리자 전용)', en: 'How to Unpin (Admin)', ja: '解除方法（管理者用）', zh: '解除固定方式（仅限管理员）', vi: 'Cách bỏ ghim (Quản trị)', es: 'Cómo Desfijar (Admin)'),
                LocalizationService.pick(
                  ko: '뒤로가기 버튼과 최근 앱 버튼을 동시에 길게 누르면 기기 화면 잠금(패턴/PIN)이 풀리며 해제됩니다.',
                  en: 'Press & hold Back + Recent Apps together, then unlock with your device PIN.',
                  ja: '戻るボタンと履歴ボタンを同時に長押しし、端末のPINでロック解除します。',
                  zh: '同时长按返回键和多任务键，验证设备锁屏密码即可退出。',
                  vi: 'Nhấn giữ nút Quay lại + Đa nhiệm cùng lúc và nhập mật khẩu máy.',
                  es: 'Mantén pulsado Atrás + Recientes y desbloquea con tu PIN del dispositivo.',
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.verified_user_rounded, color: AppTheme.primaryBlue, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LocalizationService.pick(
                          ko: '앱 내부에서도 우측 상단 자물쇠 터치 시 관리자 비밀번호(0000)가 없으면 대시보드로 나갈 수 없도록 이중 보호됩니다.',
                          en: 'Inside the app too, tapping Exit requires the Admin PIN (default 0000) for double security.',
                          ja: 'アプリ内でも管理者画面へ戻る際は管理者PIN（初期値0000）が必須となり二重で保護されます。',
                          zh: '应用内部退出考勤屏同样需要输入管理员密码（默认 0000），实现双重安全防护。',
                          vi: 'Bên trong app, thoát về màn hình quản lý cũng yêu cầu mã PIN (mặc định 0000).',
                          es: 'Dentro de la app también exige PIN de administrador (0000 por defecto) para salir.',
                        ),
                        style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4, fontWeight: FontWeight.w600),
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
              label: LocalizationService.pick(
                ko: '확인했습니다',
                en: 'Understood',
                ja: '確認しました',
                zh: '我已了解',
                vi: 'Đã hiểu',
                es: 'Entendido',
              ),
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
                Row(
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 22),
                    const SizedBox(width: 8),
                    Text(
                      LocalizationService.pick(
                        ko: '업종 맞춤 1초 프리셋',
                        en: '1-Tap Industry Preset',
                        ja: '業種別 1秒プリセット',
                        zh: '行业模板一键切换',
                        vi: 'Mẫu ngành nghề 1 chạm',
                        es: 'Preajuste de Negocio en 1 Clic',
                      ),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
            Text(
              LocalizationService.pick(
                ko: '업종을 선택하시면 딱 맞는 출결 용어와 실전 샘플 데이터로 즉시 세팅됩니다.',
                en: 'Pick your industry to auto-configure terminology, fee labels, and sample members.',
                ja: '業種を選ぶだけで最適な用語とサンプルデータが一瞬でセットアップされます。',
                zh: '选择所在行业，系统将自动配置专属称呼、收费名称及演示数据。',
                vi: 'Chọn lĩnh vực để tự động thiết lập thuật ngữ và dữ liệu mẫu phù hợp.',
                es: 'Elige tu sector para configurar términos, tarifas y datos de prueba al instante.',
              ),
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
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
                title: Text(preset.localizedLabel, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                subtitle: Text('${preset.localizedSampleStudioName} (${LocalizationService.industryCategoryLabel(preset.category)})', style: const TextStyle(fontSize: 11.5)),
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
                        content: Text(LocalizationService.pick(
                          ko: '${preset.label} 맞춤 환경으로 세팅되었습니다.',
                          en: 'Configured for ${preset.localizedLabel}.',
                          ja: '${preset.localizedLabel}向けにセットアップしました。',
                          zh: '已为您配置为「${preset.localizedLabel}」环境。',
                          vi: 'Đã thiết lập theo mẫu ${preset.localizedLabel}.',
                          es: 'Configurado para ${preset.localizedLabel}.',
                        )),
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
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        LocalizationService.pick(
                          ko: '실전 가이드 센터',
                          en: 'Practical Guide Center',
                          ja: '実践ガイドセンター',
                          zh: '实战指南中心',
                          vi: 'Trung tâm hướng dẫn',
                          es: 'Centro de Guías Prácticas',
                        ),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        LocalizationService.pick(
                          ko: '스텝바이스텝 가이드, 3단계 팁, 업종별 프리셋 허브',
                          en: 'Step-by-step walkthroughs, quick start tips & industry presets',
                          ja: 'ステップガイド・基本3ステップ・業種プリセットハブ',
                          zh: '分步演示教程、3步速成指南与行业模板中心',
                          vi: 'Hướng dẫn từng bước, mẹo nhanh & mẫu ngành nghề',
                          es: 'Tutoriales paso a paso, guía rápida y preajustes',
                        ),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
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

            // Item 0: 탭별·기능별 전체 사용 가이드
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
                  Row(
                    children: [
                      const Icon(Icons.menu_book_rounded, color: AppTheme.primaryBlue, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LocalizationService.pick(
                            ko: '탭별 · 기능별 전체 사용 가이드',
                            en: 'Full Tab-by-Tab User Manual',
                            ja: 'タブ別・機能別 総合使い方ガイド',
                            zh: '各标签页与功能完整使用手册',
                            vi: 'Hướng dẫn toàn bộ từng mục & tính năng',
                            es: 'Manual Completo por Pestaña',
                          ),
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LocalizationService.pick(
                      ko: '출결 체크 · 청구/수납 · 지출/세무 · 회원 명부 · 키오스크/프로샵의 등록·수정·삭제 방법과 더미 데이터 비우기 절차를 한눈에 안내합니다.',
                      en: 'Learn how to create, edit, and delete across Attendance, Billing, Tax, Directory, and Kiosk.',
                      ja: '出欠・請求・支出/税務・会員名簿・キオスクの登録・編集・削除と初期データ削除を案内します。',
                      zh: '全面介绍考勤、账单、支出税务、会员名录、考勤机的增删改操作及清空演示数据方法。',
                      vi: 'Hướng dẫn chi tiết thêm/sửa/xóa và xóa dữ liệu mẫu cho toàn bộ ứng dụng.',
                      es: 'Aprende a crear, editar, borrar y limpiar datos de prueba en toda la app.',
                    ),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E3A8A), height: 1.45),
                  ),
                  const SizedBox(height: 12),
                  ZeroButton.primary(
                    label: LocalizationService.pick(
                      ko: '메뉴별 전체 사용 가이드 열기',
                      en: 'Open Full User Guide',
                      ja: '総合ガイドを開く',
                      zh: '打开完整使用指南',
                      vi: 'Mở hướng dẫn đầy đủ',
                      es: 'Abrir Guía Completa',
                    ),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocalizationService.pick(
                                ko: '스텝바이스텝 4단계 실전 연습 가이드',
                                en: '4-Step Interactive Practice Guide',
                                ja: 'ステップバイステップ 4段階実践ガイド',
                                zh: '4步实战互动演练教程',
                                vi: 'Hướng dẫn thực hành 4 bước tương tác',
                                es: 'Guía Práctica Interactiva (4 Pasos)',
                              ),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LocalizationService.pick(
                                ko: '회원 등록 → 출결 체크 → 안심 문자 → 청구서 작성',
                                en: 'Add Member -> Check-In -> Notify -> Create Invoice',
                                ja: '会員登録 → 出欠チェック → 通知 → 請求書作成',
                                zh: '添加会员 → 签到考勤 → 发送通知 → 创建账单',
                                vi: 'Thêm hội viên → Điểm danh → Báo tin → Tạo hóa đơn',
                                es: 'Alta Miembro -> Check-in -> Aviso -> Crear Cobro',
                              ),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LocalizationService.pick(
                      ko: '실제 화면 위에 가이드 마커가 표시되어 단계별로 직접 터치하며 배우는 대화형 인터랙티브 튜토리얼입니다.',
                      en: 'Interactive walkthrough highlighting each action directly on your live screens.',
                      ja: '実際の画面上にガイドマーカーが表示され、操作しながら学べるチュートリアルです。',
                      zh: '在真实界面上标注引导步骤，手把手点击学习的交互式指南。',
                      vi: 'Hướng dẫn tương tác hiển thị trực tiếp trên màn hình để thực hành ngay.',
                      es: 'Tutorial interactivo que marca cada paso directamente sobre las pantallas reales.',
                    ),
                    style: const TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
                  ),
                  const SizedBox(height: 14),
                  ZeroButton.primary(
                    label: LocalizationService.pick(
                      ko: '실전 튜토리얼 시작하기',
                      en: 'Start Interactive Tutorial',
                      ja: '実践チュートリアルを開始',
                      zh: '开始交互式教程',
                      vi: 'Bắt đầu thực hành',
                      es: 'Iniciar Tutorial Interactivo',
                    ),
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
                  Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, color: Color(0xFFD97706), size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LocalizationService.pick(
                            ko: '초간단 3단계 핵심 이용 가이드',
                            en: '3-Step Quick Start Guide',
                            ja: 'かんたん3ステップ基本ガイド',
                            zh: '超简单 3 步核心入门指南',
                            vi: 'Hướng dẫn nhanh 3 bước cốt lõi',
                            es: 'Guía Rápida en 3 Pasos',
                          ),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildGuideStep(
                    Icons.check_circle_rounded,
                    LocalizationService.pick(
                      ko: '1. 출결 & 이용 체크',
                      en: '1. Attendance & Session Check-In',
                      ja: '1. 出席・利用チェック',
                      zh: '1. 考勤签到与扣次',
                      vi: '1. Điểm danh & Trừ buổi',
                      es: '1. Registro de Asistencia',
                    ),
                    LocalizationService.pick(
                      ko: '첫 번째 탭에서 [체크인] 누르면 출석 일시 기록 & 잔여 회차가 1회 자동 차감됩니다.',
                      en: 'Tap [Check In] on Tab 1 to log timestamp & auto-deduct 1 session.',
                      ja: '最初のタブで[チェックイン]を押すと出席日時が記録され、残回数が1回減算されます。',
                      zh: '在首页点击[签到]，系统自动记录考勤时间并扣减1次剩余课时。',
                      vi: 'Nhấn [Điểm danh] ở tab đầu tiên để lưu giờ và tự động trừ 1 buổi.',
                      es: 'Pulsa [Check-in] en la pestaña 1 para registrar hora y descontar 1 sesión.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildGuideStep(
                    Icons.mark_chat_read_rounded,
                    LocalizationService.pick(
                      ko: '2. 비용 0원 안심 문자',
                      en: '2. Zero-Cost SMS & Messenger Alerts',
                      ja: '2. 0円 安心通知メッセージ',
                      zh: '2. 零费用安心到店通知',
                      vi: '2. Nhắn tin thông báo 0đ',
                      es: '2. Avisos Gratis por SMS / Chat',
                    ),
                    LocalizationService.pick(
                      ko: '체크 완료 후 [출석/이용 알림]을 누르면 기본 문자 앱으로 보호자/회원에게 즉시 전송됩니다.',
                      en: 'Tap [Notify] after check-in to send via your phone SMS or Messenger app.',
                      ja: 'チェック後に通知ボタンを押すと、スマホのSMSやメッセージアプリで即座に送信できます。',
                      zh: '签到后点击通知按钮，直接调用手机短信或聊天应用发送，零额外通信费。',
                      vi: 'Sau khi điểm danh, nhấn thông báo để gửi ngay qua SMS hoặc Zalo/Messenger.',
                      es: 'Tras el registro, pulsa Aviso para enviar por tu app de SMS o WhatsApp.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildGuideStep(
                    Icons.receipt_long_rounded,
                    LocalizationService.pick(
                      ko: '3. 청구서 & 수납 장부',
                      en: '3. Invoicing & Payment Ledger',
                      ja: '3. 請求書 & 入金台帳',
                      zh: '3. 账单开具与收款台账',
                      vi: '3. Hóa đơn & Sổ thu tiền',
                      es: '3. Cobros y Libro Contable',
                    ),
                    LocalizationService.pick(
                      ko: '두 번째 탭에서 ${profile.feeTitle} 청구서를 만들고, 은행 입금 감지로 미납/완납을 자동 정리하세요.',
                      en: 'Create ${profile.feeTitle} invoices on Tab 2 and track paid/unpaid cleanly.',
                      ja: '2番目のタブで${profile.feeTitle}請求書を作成し、未入金・入金済みを管理します。',
                      zh: '在第二个标签页创建${profile.feeTitle}账单，轻松管理待付和已付记录。',
                      vi: 'Tạo hóa đơn ${profile.feeTitle} ở tab 2 và theo dõi đã thu/chưa thu dễ dàng.',
                      es: 'Crea cobros de ${profile.feeTitle} en la pestaña 2 y controla pagos pendientes.',
                    ),
                  ),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              LocalizationService.pick(
                                ko: '원클릭 업종 프리셋 전환',
                                en: '1-Click Industry Preset Switcher',
                                ja: 'ワンクリック業種プリセット切替',
                                zh: '一键切换行业预设模板',
                                vi: 'Chuyển đổi mẫu ngành nghề 1 chạm',
                                es: 'Cambio de Preajuste en 1 Clic',
                              ),
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              LocalizationService.pick(
                                ko: '학원 · PT · 필라테스 · 태권도 · 음악공방 맞춤 세팅',
                                en: 'Tutoring · Gym/PT · Pilates · Martial Arts · Music Studio',
                                ja: '学習塾・ジム・ピラティス・道場・音楽教室に即対応',
                                zh: '培训班 · 健身私教 · 普拉提 · 武馆 · 音乐工坊一键适配',
                                vi: 'Gia sư · Gym/PT · Pilates · Võ thuật · Âm nhạc',
                                es: 'Academias · Fitness · Pilates · Artes Marciales · Música',
                              ),
                              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    LocalizationService.pick(
                      ko: '선택하신 업종에 맞춰 출결 안내 문구, 수강료/회비 용어, 맞춤 샘플 회원 데이터가 즉시 구성됩니다.',
                      en: 'Instant setup with tailored member/fee terms, attendance messages, and sample data.',
                      ja: '選んだ業種に合わせて出欠文面・会費呼称・サンプルデータが即時反映されます。',
                      zh: '根据所选行业即时配置考勤文案、收费称呼与演示会员数据。',
                      vi: 'Tự động cấu hình mẫu tin nhắn, tên gọi và dữ liệu mẫu theo ngành bạn chọn.',
                      es: 'Configura al instante mensajes, términos y miembros de prueba de tu sector.',
                    ),
                    style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.4),
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
                      label: Text(LocalizationService.pick(
                        ko: '내 업종 맞춤 프리셋 선택하기',
                        en: 'Choose Industry Preset',
                        ja: '業種プリセットを選択する',
                        zh: '选择我的行业模板',
                        vi: 'Chọn mẫu ngành nghề của bạn',
                        es: 'Elegir Preajuste del Sector',
                      )),
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
                title: Text(
                  LocalizationService.pick(
                    ko: '매장 셋업 위저드 다시 실행',
                    en: 'Re-run Studio Setup Wizard',
                    ja: 'スタジオ設定ウィザードを再実行',
                    zh: '重新运行门店初始化向导',
                    vi: 'Chạy lại trình thiết lập trung tâm',
                    es: 'Reabrir Asistente de Configuración',
                  ),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                subtitle: Text(
                  LocalizationService.pick(
                    ko: '상호명, 업종, 수납 계좌, 첫 회원 등록 마법사 재실행',
                    en: 'Reconfigure business name, industry, bank account & country settings',
                    ja: '屋号・業種・振込口座・国設定ウィザードをやり直します',
                    zh: '重新配置商号、行业、收款账户及国家货币设置',
                    vi: 'Thiết lập lại tên, ngành nghề, tài khoản ngân hàng & quốc gia',
                    es: 'Reconfigura nombre, sector, cuenta bancaria y país',
                  ),
                  style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                ),
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
                children: [
                  Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, color: AppTheme.primaryBlue, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        LocalizationService.pick(
                          ko: '자주 묻는 질문 (FAQ)',
                          en: 'Frequently Asked Questions',
                          ja: 'よくある質問 (FAQ)',
                          zh: '常见问题解答 (FAQ)',
                          vi: 'Câu hỏi thường gặp (FAQ)',
                          es: 'Preguntas Frecuentes (FAQ)',
                        ),
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    LocalizationService.pick(
                      ko: 'Q. 문자 발송 비용이 왜 0원인가요?',
                      en: 'Q. Why is sending SMS/chat messages free?',
                      ja: 'Q. メッセージ送信が0円なのはなぜですか？',
                      zh: 'Q. 为什么发送通知短信零额外费用？',
                      vi: 'Q. Tại sao gửi tin nhắn thông báo hoàn toàn miễn phí?',
                      es: 'Q. ¿Por qué enviar avisos cuesta 0?',
                    ),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    LocalizationService.pick(
                      ko: 'A. 유료 외부 문자 서버 대신 내 스마트폰 기본 무료 문자를 활용하므로 월 통신비 지출이 0원입니다.',
                      en: 'A. It launches your own phone SMS/messenger app instead of paid cloud SMS gateways.',
                      ja: 'A. 有料サーバーを使わず端末標準のSMS/メッセージアプリから送信するため月額コストは0円です。',
                      zh: 'A. 本应用直接调用手机系统短信与聊天工具发送，无需购买付费短信通道。',
                      vi: 'A. Ứng dụng sử dụng trình nhắn tin có sẵn trên điện thoại của bạn thay vì tổng đài trả phí.',
                      es: 'A. Utiliza la app de SMS o mensajería nativa de tu móvil sin servidores de pago.',
                    ),
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45),
                  ),
                  const Divider(height: 16),
                  Text(
                    LocalizationService.pick(
                      ko: 'Q. 개인정보가 외부 서버에 전송되나요?',
                      en: 'Q. Is customer data uploaded to external servers?',
                      ja: 'Q. 個人情報は外部サーバーへ送信されますか？',
                      zh: 'Q. 客户隐私数据会上传到云端服务器吗？',
                      vi: 'Q. Dữ liệu hội viên có bị tải lên máy chủ ngoài không?',
                      es: 'Q. ¿Se suben los datos de clientes a servidores externos?',
                    ),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    LocalizationService.pick(
                      ko: 'A. 중앙 서버를 두지 않는 100% 온디바이스 로컬 암호화 저장소로, 외부 유출이 원천 차단됩니다.',
                      en: 'A. No! Everything stays 100% locally encrypted on your device with zero cloud tracking.',
                      ja: 'A. いいえ。中央サーバーを持たない100%端末内暗号化ストレージで安全に保護されます。',
                      zh: 'A. 不会！本软件采用100%本地加密数据库存储，绝不上传至任何远程服务器。',
                      vi: 'A. Không! Mọi dữ liệu được mã hóa và lưu hoàn toàn trên thiết bị của bạn.',
                      es: 'A. No. Todo se guarda cifrado localmente en tu dispositivo sin rastreo en la nube.',
                    ),
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45),
                  ),
                  const Divider(height: 16),
                  Text(
                    LocalizationService.pick(
                      ko: 'Q. 태블릿 무인 키오스크 관리자 비밀번호는?',
                      en: 'Q. What is the default Kiosk Admin PIN?',
                      ja: 'Q. キオスクの管理者解除PINは？',
                      zh: 'Q. 考勤机模式的默认管理员密码是多少？',
                      vi: 'Q. Mã PIN quản trị của Kiosk là gì?',
                      es: 'Q. ¿Cuál es el PIN de administrador del Quiosco?',
                    ),
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    LocalizationService.pick(
                      ko: 'A. 기본 마스터 비밀번호는 [0000]이며, 키패드에서 0000을 입력하면 관리자 대시보드로 즉시 복귀합니다.',
                      en: 'A. The default Admin PIN is [0000]. Tap Exit on Kiosk and enter 0000 to return.',
                      ja: 'A. 初期PINは [0000] です。終了ボタンから 0000 を入力すると管理画面に戻ります。',
                      zh: 'A. 默认管理员解锁密码为 [0000]，输入 0000 即可退回到后台控制台。',
                      vi: 'A. Mã PIN mặc định là [0000]. Nhấn Thoát và nhập 0000 để quay lại màn hình quản lý.',
                      es: 'A. El PIN por defecto es [0000]. Pulsa Salir en Quiosco e ingresa 0000 para volver.',
                    ),
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.45),
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
              tooltip: LocalizationService.pick(
                ko: 'PRO 샵',
                en: 'PRO Shop',
                ja: 'PROショップ',
                zh: 'PRO 商店',
                vi: 'Cửa hàng PRO',
                es: 'Tienda PRO',
              ),
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
              tooltip: LocalizationService.pick(
                ko: '로컬 금고 암호화 백업',
                en: 'Encrypted Local Backup',
                ja: 'ローカル暗号化バックアップ',
                zh: '本地加密备份',
                vi: 'Sao lưu mã hóa cục bộ',
                es: 'Copia de Seguridad Cifrada',
              ),
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
                      SnackBar(content: Text('${LocalizationService.tr('common_error')}: $e')),
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
      body: studioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('${LocalizationService.tr('common_error')}: $err')),
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
              _buildGroupHeader(LocalizationService.pick(
                ko: '시설 & 브랜드 환경',
                en: 'Studio & Region Workspace',
                ja: '施設・ブランド設定',
                zh: '场馆与品牌环境',
                vi: 'Trung tâm & Thương hiệu',
                es: 'Negocio y Región',
              )),
              _buildRepresentativeTile(
                icon: Icons.storefront_rounded,
                iconColor: AppTheme.primaryBlue,
                iconBgColor: const Color(0xFFEFF6FF),
                title: LocalizationService.pick(
                  ko: '${profile.placeTitle} 프로필 및 기본 정보',
                  en: '${profile.placeTitle} Profile & Bank Info',
                  ja: '${profile.placeTitle} プロフィール・基本情報',
                  zh: '${profile.placeTitle} 资料与基本账户',
                  vi: 'Hồ sơ ${profile.placeTitle} & Tài khoản',
                  es: 'Perfil del ${profile.placeTitle} y Banco',
                ),
                subtitle: '${profile.studioName} · ${profile.localizedCategoryLabel} · ${profile.roleTitle} ${profile.instructorName}',
                onTap: () => _openEditProfileDialog(context, profile),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.badge_outlined,
                iconColor: const Color(0xFF0F172A),
                iconBgColor: const Color(0xFFF1F5F9),
                title: LocalizationService.pick(
                  ko: '맞춤 호칭 & 용어 설정',
                  en: 'Custom Terminology & Labels',
                  ja: 'カスタム呼称・用語設定',
                  zh: '自定义称呼与术语设置',
                  vi: 'Tùy chỉnh tên gọi & thuật ngữ',
                  es: 'Términos y Etiquetas Personalizadas',
                ),
                subtitle: '${LocalizationService.pick(ko: '호칭', en: 'Terms', ja: '呼称', zh: '称呼', vi: 'Tên gọi', es: 'Términos')}: ${profile.roleTitle} · ${profile.memberWord} · ${profile.feeWord} · ${profile.placeTitle}',
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
                title: LocalizationService.pick(
                  ko: '업종별 카테고리 & 청구 템플릿',
                  en: 'Groups & Invoice Templates',
                  ja: 'クラス分類・請求テンプレート',
                  zh: '行业分类与账单模板',
                  vi: 'Danh mục & Mẫu hóa đơn',
                  es: 'Categorías y Plantillas de Cobro',
                ),
                subtitle: LocalizationService.pick(
                  ko: '${profile.category} 맞춤 수납 항목 및 기본 단가 관리',
                  en: 'Manage class groups and fee presets for ${profile.localizedCategoryLabel}',
                  ja: '${profile.localizedCategoryLabel}向けのクラス・請求単価を管理',
                  zh: '管理「${profile.localizedCategoryLabel}」专属课程分组及默认金额',
                  vi: 'Quản lý nhóm lớp và mức phí mẫu cho ${profile.localizedCategoryLabel}',
                  es: 'Gestiona grupos y tarifas para ${profile.localizedCategoryLabel}',
                ),
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
              _buildGroupHeader(LocalizationService.pick(
                ko: '출결 & 무인 키오스크 운영',
                en: 'Attendance & Self Check-In Kiosk',
                ja: '出席・無人キオスク運用',
                zh: '考勤与无人值守考勤机',
                vi: 'Điểm danh & Vận hành Kiosk',
                es: 'Asistencia y Quiosco de Auto-Registro',
              )),
              _buildRepresentativeTile(
                icon: Icons.tablet_mac_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFEFF6FF),
                title: LocalizationService.pick(
                  ko: '무인 출결 키오스크 기기 설정',
                  en: 'Self Check-In Kiosk Settings',
                  ja: '無人受付キオスク端末設定',
                  zh: '无人考勤机终端设置',
                  vi: 'Cài đặt thiết bị Kiosk điểm danh',
                  es: 'Ajustes de Quiosco de Asistencia',
                ),
                subtitle: _isKioskDedicated
                    ? LocalizationService.pick(
                        ko: '자동 실행 활성화됨 · 입구 거치 모드',
                        en: 'Auto-Launch ON · Front-desk Tablet Mode',
                        ja: '自動起動ON · 店頭設置モード',
                        zh: '已开启自动启动 · 入口前台专机模式',
                        vi: 'Tự khởi động BẬT · Chế độ đặt tại quầy',
                        es: 'Inicio Automático ON · Modo Tablet en Recepción',
                      )
                    : LocalizationService.pick(
                        ko: '자동 실행 꺼짐 · 학생용/체험 모드 지원',
                        en: 'Auto-Launch OFF · Supports PIN & Name Lookup',
                        ja: '自動起動OFF · PIN・名前検索対応',
                        zh: '自动启动已关闭 · 支持 PIN / 姓名搜索模式',
                        vi: 'Tự khởi động TẮT · Hỗ trợ PIN & Tìm tên',
                        es: 'Inicio Automático OFF · Soporta PIN y Búsqueda',
                      ),
                trailingBadge: _isKioskDedicated
                    ? Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFECFDF5),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          LocalizationService.pick(
                            ko: '자동ON',
                            en: 'AUTO ON',
                            ja: '自動ON',
                            zh: '自动开',
                            vi: 'TỰ BẬT',
                            es: 'AUTO ON',
                          ),
                          style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF059669)),
                        ),
                      )
                    : null,
                onTap: () => _showKioskSettingsBottomSheet(context, profile),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.notifications_active_rounded,
                iconColor: const Color(0xFF059669),
                iconBgColor: const Color(0xFFECFDF5),
                title: LocalizationService.pick(
                  ko: '스마트 안심 알림 센터 & 감사 로그',
                  en: 'Smart Notification Hub & Audit Logs',
                  ja: 'スマート安心通知センター・履歴ログ',
                  zh: '智能通知中心与发送审计日志',
                  vi: 'Trung tâm thông báo & Nhật ký gửi',
                  es: 'Centro de Avisos Inteligente y Registro',
                ),
                subtitle: LocalizationService.pick(
                  ko: '등·하원 미발송 알림 일괄 전송, 독촉 릴레이, 전체 감사 로그',
                  en: 'Batch check-in/out alerts, payment reminders & delivery history',
                  ja: '一括出欠通知・未払い催促リレー・送信履歴確認',
                  zh: '批量发送考勤通知、顺序催款提醒及完整发送记录',
                  vi: 'Gửi hàng loạt thông báo điểm danh, nhắc phí & xem lịch sử',
                  es: 'Envíos por lote, recordatorios de pago e historial completo',
                ),
                onTap: () => SmartNotificationCenterModal.show(context),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.edit_note_rounded,
                iconColor: const Color(0xFFD97706),
                iconBgColor: const Color(0xFFFFFBEB),
                title: LocalizationService.pick(
                  ko: '문자 알림 및 청구 서식 관리',
                  en: 'SMS & Message Template Editor',
                  ja: 'メッセージ通知・請求書式管理',
                  zh: '短信通知与账单模板管理',
                  vi: 'Quản lý mẫu tin nhắn & hóa đơn',
                  es: 'Gestor de Plantillas de Avisos y Cobro',
                ),
                subtitle: LocalizationService.pick(
                  ko: '수강료 청구서, 입실 안심 문자, 퇴실 문자 서식 편집',
                  en: 'Customize invoice, check-in & departure messages',
                  ja: '請求・入室・退室メッセージテンプレートの編集',
                  zh: '自定义收费通知、到店及离校模板内容',
                  vi: 'Tùy chỉnh mẫu hóa đơn, điểm danh & tan học',
                  es: 'Edita plantillas de cobro, entrada y salida',
                ),
                onTap: () => _showSmsTemplatesBottomSheet(context, profile),
              ),
              const SizedBox(height: 16),

              // [그룹 3: 금융 결제 & 데이터 보안]
              _buildGroupHeader(LocalizationService.pick(
                ko: '금융 결제 & 데이터 보안',
                en: 'Payments & On-Device Security',
                ja: '決済リンク・データ保護',
                zh: '支付结算与数据安全',
                vi: 'Thanh toán & Bảo mật dữ liệu',
                es: 'Pagos y Seguridad de Datos',
              )),
              _buildRepresentativeTile(
                icon: Icons.credit_card_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFEFF6FF),
                title: LocalizationService.pick(
                  ko: '비대면 신용카드 결제 링크 (0원 연동)',
                  en: 'Online Card Payment Link (Stripe / PayPal / PG)',
                  ja: 'オンラインカード決済リンク設定',
                  zh: '远程在线信用卡支付链接设置',
                  vi: 'Liên kết thanh toán thẻ trực tuyến',
                  es: 'Enlace de Pago Online con Tarjeta',
                ),
                subtitle: profile.cardPaymentEnabled
                    ? LocalizationService.pick(
                        ko: '비대면 카드결제 켜짐',
                        en: 'Online Card Payment Link: Enabled',
                        ja: 'オンラインカード決済: 有効',
                        zh: '在线信用卡链接: 已开启',
                        vi: 'Thanh toán thẻ từ xa: Đang bật',
                        es: 'Enlace de pago con tarjeta: Activado',
                      )
                    : LocalizationService.pick(
                        ko: '가입비 0원 · 월관리비 0원 · 전용 링크 신청',
                        en: 'Connect any checkout URL (Stripe, Square, PayPal, local PG)',
                        ja: 'Stripe・PayPal・各種決済リンクを無料で連携',
                        zh: '绑定您的专属收款链接（零平台抽成或月费）',
                        vi: 'Kết nối link thanh toán riêng hoàn toàn miễn phí',
                        es: 'Conecta tu enlace de Stripe, PayPal o TPV virtual gratis',
                      ),
                onTap: () => _showCardPaymentBottomSheet(context, profile),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.lock_outline_rounded,
                iconColor: const Color(0xFF0F172A),
                iconBgColor: const Color(0xFFF1F5F9),
                title: LocalizationService.pick(
                  ko: '로컬 데이터 보안 금고 (100% 온디바이스)',
                  en: 'Local Data Vault & CSV Export (100% On-Device)',
                  ja: 'ローカルデータ保管庫・CSV出力',
                  zh: '本地安全数据金库（100% 离线加密）',
                  vi: 'Kho bảo mật dữ liệu cục bộ & Xuất CSV',
                  es: 'Bóveda Local de Datos y Exportación CSV',
                ),
                subtitle: LocalizationService.pick(
                  ko: '암호화 백업, 카카오톡/드라이브 전송, 복원, 초기화',
                  en: 'Encrypted backup, Tax/Excel CSV export, restore & sample reset',
                  ja: '暗号化バックアップ・会計CSV出力・復元・データ初期化',
                  zh: '加密备份、税务CSV导出、JSON恢复与重置演示数据',
                  vi: 'Sao lưu mã hóa, xuất sổ thuế CSV, khôi phục & xóa dữ liệu mẫu',
                  es: 'Copia cifrada, CSV contable, restaurar o limpiar datos',
                ),
                onTap: () => _showDataVaultBottomSheet(context),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.security_rounded,
                iconColor: const Color(0xFF059669),
                iconBgColor: const Color(0xFFECFDF5),
                title: LocalizationService.pick(
                  ko: '금융 푸시 필터 보안 설정',
                  en: 'Bank Push Deposit Detector Security',
                  ja: '銀行入金通知自動検出・セキュリティ',
                  zh: '银行到账通知自动识别安全设置',
                  vi: 'Bảo mật bộ lọc thông báo ngân hàng',
                  es: 'Seguridad de Detección de Pagos Bancarios',
                ),
                subtitle: profile.autoBankDetectEnabled
                    ? LocalizationService.pick(
                        ko: '은행 입금 푸시 감지 켜짐',
                        en: 'Auto Deposit Alert Detection: ON',
                        ja: '銀行入金通知の自動検出: オン',
                        zh: '银行入账通知自动识别: 已开启',
                        vi: 'Tự động phát hiện chuyển khoản: Đang bật',
                        es: 'Detección automática bancaria: ACTIVADA',
                      )
                    : LocalizationService.pick(
                        ko: '은행 입금 푸시 감지 꺼짐',
                        en: 'Auto Deposit Alert Detection: OFF',
                        ja: '銀行入金通知の自動検出: オフ',
                        zh: '银行入账通知自动识别: 已关闭',
                        vi: 'Tự động phát hiện chuyển khoản: Đang tắt',
                        es: 'Detección automática bancaria: DESACTIVADA',
                      ),
                onTap: () => _showBankPushSecurityBottomSheet(context, profile),
              ),
              const SizedBox(height: 16),

              // [그룹 4: 가이드 & 규정 준수]
              _buildGroupHeader(LocalizationService.pick(
                ko: '가이드 & 규정 준수',
                en: 'Guides & Legal Compliance',
                ja: 'ガイド・利用規約',
                zh: '使用指南与合规说明',
                vi: 'Hướng dẫn & Tuân thủ pháp lý',
                es: 'Guías y Cumplimiento Legal',
              )),
              _buildRepresentativeTile(
                icon: Icons.menu_book_rounded,
                iconColor: const Color(0xFF2563EB),
                iconBgColor: const Color(0xFFEFF6FF),
                title: LocalizationService.pick(
                  ko: '탭별 · 기능별 전체 사용 가이드',
                  en: 'Full Tab-by-Tab User Manual',
                  ja: 'タブ別・機能別 総合使い方ガイド',
                  zh: '各标签页与功能完整使用手册',
                  vi: 'Hướng dẫn sử dụng toàn diện theo từng mục',
                  es: 'Manual Completo por Pestaña y Función',
                ),
                subtitle: LocalizationService.pick(
                  ko: '출결·청구·지출·회원·설정·프로샵 메뉴별 등록/수정/삭제 안내',
                  en: 'Complete CRUD guide for Check-in, Billing, Tax, Directory & PRO',
                  ja: '出席・請求・税務・名簿・設定・PROの操作方法を一覧で案内',
                  zh: '涵盖考勤、账单、收支税务、会员及 PRO 功能的完整操作指南',
                  vi: 'Hướng dẫn thêm/sửa/xóa cho điểm danh, thu chi, hội viên & PRO',
                  es: 'Guía completa de creación, edición y borrado en toda la app',
                ),
                onTap: () => _openFullUsageGuide(context),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.auto_stories_rounded,
                iconColor: const Color(0xFF059669),
                iconBgColor: const Color(0xFFECFDF5),
                title: LocalizationService.pick(
                  ko: '실전 가이드 센터 & 튜토리얼',
                  en: 'Practical Guide Center & Tutorials',
                  ja: '実践ガイドセンター・チュートリアル',
                  zh: '实战指南中心与互动教程',
                  vi: 'Trung tâm hướng dẫn & Thực hành',
                  es: 'Centro de Guías Prácticas y Tutoriales',
                ),
                subtitle: LocalizationService.pick(
                  ko: '4단계 실전 연습 코칭 · 업종 프리셋 · 셋업 마법사 · FAQ',
                  en: '4-step interactive walkthrough · Industry presets · Setup · FAQ',
                  ja: '4段階実践コーチング・業種プリセット・設定ウィザード・FAQ',
                  zh: '4步实战教程 · 行业模板切换 · 初始化向导 · 常见问题',
                  vi: 'Thực hành 4 bước · Mẫu ngành nghề · Thiết lập lại · FAQ',
                  es: 'Tutorial de 4 pasos · Preajustes · Asistente · FAQ',
                ),
                onTap: () => _openGuideCenterSheet(context, profile),
              ),
              const SizedBox(height: 8),
              _buildRepresentativeTile(
                icon: Icons.gavel_rounded,
                iconColor: const Color(0xFF64748B),
                iconBgColor: const Color(0xFFF8FAFC),
                title: LocalizationService.pick(
                  ko: '법적 고지 및 규정 준수 (Compliance)',
                  en: 'Legal Notice & Privacy Compliance',
                  ja: '法的表記・プライバシーコンプライアンス',
                  zh: '法律声明与数据合规保证',
                  vi: 'Thông báo pháp lý & Bảo mật dữ liệu',
                  es: 'Aviso Legal y Cumplimiento de Privacidad',
                ),
                subtitle: LocalizationService.pick(
                  ko: '개인정보 처리방침 · 이용약관 · 로컬 암호화 보안 확약',
                  en: 'Privacy Policy · Terms · GDPR / CCPA Local Storage Guarantee',
                  ja: 'プライバシーポリシー・利用規約・端末内暗号化保証',
                  zh: '隐私政策 · 服务条款 · 本地加密存储零上传承诺',
                  vi: 'Chính sách bảo mật · Điều khoản · Cam kết lưu cục bộ',
                  es: 'Política de Privacidad · Términos · Garantía Local GDPR',
                ),
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
                            profile.localizedCategoryLabel,
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
                            child: Text(
                              LocalizationService.pick(
                                ko: '로고 적용됨',
                                en: 'Logo Set',
                                ja: 'ロゴ設定済',
                                zh: '已设标志',
                                vi: 'Đã đặt logo',
                                es: 'Logo Activo',
                              ),
                              style: const TextStyle(
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
                              profile.logoPath != null
                                  ? LocalizationService.pick(
                                      ko: '로고 변경/삭제',
                                      en: 'Edit/Remove Logo',
                                      ja: 'ロゴ変更/削除',
                                      zh: '更换/删除标志',
                                      vi: 'Đổi/Xóa logo',
                                      es: 'Cambiar/Borrar Logo',
                                    )
                                  : LocalizationService.pick(
                                      ko: '상호 로고 등록하기',
                                      en: 'Upload Studio Logo',
                                      ja: 'ロゴを登録する',
                                      zh: '上传工作室标志',
                                      vi: 'Tải lên logo',
                                      es: 'Subir Logo',
                                    ),
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
                        '${profile.instructorName} ${profile.roleTitle} · ${LocalizationService.pick(ko: '호칭', en: 'Terms', ja: '呼称', zh: '称呼', vi: 'Tên gọi', es: 'Términos')}: ${profile.memberWord} / ${profile.feeWord}',
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
                  label: Text(
                    LocalizationService.pick(
                      ko: '기본 정보 수정',
                      en: 'Edit Profile Info',
                      ja: '基本情報を編集',
                      zh: '编辑基本资料',
                      vi: 'Sửa thông tin cơ bản',
                      es: 'Editar Perfil',
                    ),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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
                  label: Text(
                    LocalizationService.pick(
                      ko: '맞춤 호칭 설정',
                      en: 'Custom Labels',
                      ja: '呼称をカスタマイズ',
                      zh: '自定义称呼',
                      vi: 'Tùy chỉnh tên gọi',
                      es: 'Personalizar Términos',
                    ),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
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
                    label: Text(
                      LocalizationService.pick(
                        ko: '기본 정보 수정',
                        en: 'Edit Info',
                        ja: '基本情報編集',
                        zh: '编辑资料',
                        vi: 'Sửa thông tin',
                        es: 'Editar Info',
                      ),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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
                    label: Text(
                      LocalizationService.pick(
                        ko: '맞춤 호칭 설정',
                        en: 'Custom Terms',
                        ja: 'カスタム呼称',
                        zh: '自定义称呼',
                        vi: 'Tên gọi riêng',
                        es: 'Términos',
                      ),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
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
                    softWrap: true,
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
            _buildSheetHeader(
              sheetCtx,
              LocalizationService.pick(
                ko: '업종별 카테고리 & 템플릿',
                en: 'Groups & Billing Templates',
                ja: 'クラス分類・テンプレート',
                zh: '行业分类与收费模板',
                vi: 'Danh mục & Mẫu hóa đơn',
                es: 'Categorías y Plantillas',
              ),
              Icons.category_rounded,
              const Color(0xFF8B5CF6),
            ),
            _buildCustomCategorySection(context, profile, categoryState),
          ],
        ),
      ),
    );
  }

  Future<void> _syncProfileDefaultsOnLocaleChange({
    required AppLanguage newLang,
    required AppCurrency newCurrency,
  }) async {
    try {
      final currentProfile = ref.read(studioProfileProvider).value;
      if (currentProfile != null) {
        // If the profile templates or studio name are still untouched defaults, refresh them to match new country
        final isDefaultInvoice = currentProfile.invoiceTemplate.trim() == StudioProfile.defaultInvoiceTemplate.trim() ||
            currentProfile.invoiceTemplate.contains('마인드핏') ||
            currentProfile.invoiceTemplate.contains('수강료') ||
            currentProfile.invoiceTemplate.contains('MindFit') ||
            currentProfile.invoiceTemplate.contains('マインドフィット');
        final isDefaultAttendance = currentProfile.attendanceTemplate.trim() == StudioProfile.defaultAttendanceTemplate.trim() ||
            currentProfile.attendanceTemplate.contains('출석 안심 알림') ||
            currentProfile.attendanceTemplate.contains('MindFit') ||
            currentProfile.attendanceTemplate.contains('登園・出席通知');
        final isDefaultDeparture = currentProfile.departureTemplate.trim() == StudioProfile.defaultDepartureTemplate.trim() ||
            currentProfile.departureTemplate.contains('하원·퇴실 완료 알림') ||
            currentProfile.departureTemplate.contains('MindFit') ||
            currentProfile.departureTemplate.contains('退園・下校完了通知');
        final isDefaultStudioName = currentProfile.studioName == '마인드핏 아카데미 & 스튜디오' ||
            currentProfile.studioName == 'MindFit Academy & Studio' ||
            currentProfile.studioName == 'マインドフィット アカデミー＆スタジオ' ||
            currentProfile.studioName == 'MindFit 学院与运动中心' ||
            currentProfile.studioName == 'MindFit Studio & Academy';

        if (isDefaultInvoice || isDefaultAttendance || isDefaultDeparture || isDefaultStudioName) {
          final meta = RegionWorkflowService.defaultStudioMetadata(newLang, newCurrency);
          final updated = currentProfile.copyWith(
            studioName: isDefaultStudioName ? meta['studioName'] : currentProfile.studioName,
            instructorName: isDefaultStudioName ? meta['instructorName'] : currentProfile.instructorName,
            bankName: currentProfile.bankName == '토스뱅크' || currentProfile.bankName == 'Chase Bank'
                ? meta['bankName']
                : currentProfile.bankName,
            accountHolder: isDefaultStudioName ? meta['accountHolder'] : currentProfile.accountHolder,
            invoiceTemplate: isDefaultInvoice
                ? RegionWorkflowService.defaultInvoiceTemplate(newLang, newCurrency)
                : currentProfile.invoiceTemplate,
            attendanceTemplate: isDefaultAttendance
                ? RegionWorkflowService.defaultAttendanceTemplate(newLang)
                : currentProfile.attendanceTemplate,
            departureTemplate: isDefaultDeparture
                ? RegionWorkflowService.defaultDepartureTemplate(newLang)
                : currentProfile.departureTemplate,
          );
          await ref.read(studioProfileProvider.notifier).updateProfile(updated, triggerAd: false);
        }
      }
    } catch (_) {}
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

          return StickyBottomSheetLayout(
            bodyPadding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            body: Column(
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
                        final nextCur = ref.read(currencyProvider);
                        await _syncProfileDefaultsOnLocaleChange(newLang: lang, newCurrency: nextCur);
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
                          final nextLang = ref.read(languageProvider);
                          await _syncProfileDefaultsOnLocaleChange(newLang: nextLang, newCurrency: cur);
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
                                                cur.decimalPlaces == 0
                                                    ? LocalizationService.pick(
                                                        ko: '소수점 0자리 (정수)',
                                                        en: '0 Decimals (Integer)',
                                                        ja: '小数なし (整数)',
                                                        zh: '0位小数 (整数)',
                                                        vi: 'Không số lẻ',
                                                        es: 'Sin decimales',
                                                      )
                                                    : LocalizationService.pick(
                                                        ko: '소수점 ${cur.decimalPlaces}자리 (.00)',
                                                        en: '${cur.decimalPlaces} Decimals (.00)',
                                                        ja: '小数 ${cur.decimalPlaces}桁 (.00)',
                                                        zh: '${cur.decimalPlaces}位小数 (.00)',
                                                        vi: '${cur.decimalPlaces} số lẻ (.00)',
                                                        es: '${cur.decimalPlaces} decimales (.00)',
                                                      ),
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
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(Icons.payment_rounded, size: 13, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            cur.paymentChannels.join(' · '),
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF334155), fontWeight: FontWeight.w500),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Padding(
                                          padding: EdgeInsets.only(top: 2),
                                          child: Icon(Icons.receipt_long_outlined, size: 13, color: Color(0xFF64748B)),
                                        ),
                                        const SizedBox(width: 4),
                                        Expanded(
                                          child: Text(
                                            cur.taxPolicy,
                                            style: const TextStyle(fontSize: 11, color: Color(0xFF475569)),
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
                          Text(
                            LocalizationService.pick(
                              ko: '출결 상태 (Status)',
                              en: 'Attendance Status',
                              ja: '出席ステータス',
                              zh: '考勤状态',
                              vi: 'Trạng thái điểm danh',
                              es: 'Estado de Asistencia',
                            ),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
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
              ],
            ),
            footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            footer: SizedBox(
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
              _buildSheetHeader(
                sheetCtx,
                LocalizationService.pick(
                  ko: '무인 출결 키오스크 기기 설정',
                  en: 'Self Check-In Kiosk Settings',
                  ja: '無人受付キオスク端末設定',
                  zh: '无人考勤机终端设置',
                  vi: 'Cài đặt thiết bị Kiosk điểm danh',
                  es: 'Ajustes de Quiosco de Asistencia',
                ),
                Icons.tablet_mac_rounded,
                const Color(0xFF2563EB),
              ),
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
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                LocalizationService.pick(
                                  ko: '앱 실행 시 키오스크 자동 실행',
                                  en: 'Auto-Launch Kiosk on App Start',
                                  ja: '起動時にキオスクを自動表示',
                                  zh: '启动应用时自动进入考勤机屏幕',
                                  vi: 'Tự động mở Kiosk khi bật ứng dụng',
                                  es: 'Abrir Quiosco automáticamente al iniciar',
                                ),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                LocalizationService.pick(
                                  ko: '입구 거치 태블릿으로 설정 시 관리자 대시보드 없이 바로 출결 키오스크로 시작합니다.',
                                  en: 'Ideal for front-desk tablets — opens straight into member check-in mode.',
                                  ja: '受付タブレット設置時に管理画面をスキップして直接キオスクを起動します。',
                                  zh: '适用于前台平板，打开即进入会员签到屏，跳过管理后台。',
                                  vi: 'Phù hợp cho máy tính bảng tại quầy — mở thẳng màn hình điểm danh.',
                                  es: 'Ideal para tablets en recepción: abre directo en el modo registro.',
                                ),
                                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
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
                      title: Text(
                        LocalizationService.pick(
                          ko: '학생 출결 키오스크 실행 (실제 운영용)',
                          en: 'Launch Live Member Kiosk',
                          ja: '本番用キオスクを起動',
                          zh: '启动正式版会员考勤机',
                          vi: 'Mở Kiosk chính thức',
                          es: 'Iniciar Quiosco en Vivo',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                      ),
                      subtitle: Text(
                        LocalizationService.pick(
                          ko: '입구 거치용 전체화면. 체험 핀이 일체 숨겨지는 클린 학생 운영 화면입니다.',
                          en: 'Full-screen mode with 4-digit PIN & Name Lookup (sample hints hidden).',
                          ja: '受付用の全画面モード。PIN入力と名前検索の両方に対応します。',
                          zh: '入口全屏签到模式，支持手机后4位 PIN 与姓名搜索。',
                          vi: 'Toàn màn hình tại quầy, hỗ trợ 4 số cuối hoặc tìm theo tên.',
                          es: 'Pantalla completa con teclado PIN de 4 dígitos o búsqueda por nombre.',
                        ),
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                      ),
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
                      title: Text(
                        LocalizationService.pick(
                          ko: '키오스크 기능 테스트 (체험 모드)',
                          en: 'Try Kiosk Preview (Demo Mode)',
                          ja: 'キオスク機能テスト (デモ体験)',
                          zh: '体验考勤机功能 (演示模式)',
                          vi: 'Thử nghiệm Kiosk (Chế độ Demo)',
                          es: 'Probar Quiosco (Modo Demo)',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                      ),
                      subtitle: Text(
                        LocalizationService.pick(
                          ko: '1234 체험 핀으로 출결 완료 축하 및 알림 화면 결과를 즉시 확인합니다.',
                          en: 'Test celebration check-in & notification flow instantly with PIN 1234.',
                          ja: 'デモPIN「1234」で出席完了画面や通知動作をすぐ試せます。',
                          zh: '使用演示密码 1234 快速体验签到成功动画及通知流程。',
                          vi: 'Dùng mã thử 1234 để xem trước hiệu ứng điểm danh & gửi tin.',
                          es: 'Prueba el registro y la pantalla de celebración al instante con PIN 1234.',
                        ),
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                      ),
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
                      title: Text(
                        LocalizationService.pick(
                          ko: '안드로이드 앱 화면 고정(Pinning) 가이드',
                          en: 'Screen Pinning / Tablet Lock Guide',
                          ja: '画面固定（ピン留め）ガイド',
                          zh: '平板屏幕锁定 (Screen Pinning) 指南',
                          vi: 'Hướng dẫn ghim màn hình khóa thiết bị',
                          es: 'Guía de Fijación de Pantalla',
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                      ),
                      subtitle: Text(
                        LocalizationService.pick(
                          ko: '학생들이 홈 화면이나 유튜브 등으로 나가지 못하게 기기를 고정 잠금합니다.',
                          en: 'Prevent visitors from exiting the check-in screen on shared tablets.',
                          ja: '受講生が他のアプリへ移動しないよう端末をロックする方法を確認します。',
                          zh: '防止访客切出考勤页面进入其他应用的平板锁屏教程。',
                          vi: 'Ngăn học viên thoát ra khỏi màn hình điểm danh trên máy chung.',
                          es: 'Evita que los alumnos salgan de la pantalla en tablets compartidas.',
                        ),
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                      ),
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
                        children: [
                          const Icon(Icons.lock_rounded, size: 18, color: Color(0xFFD97706)),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LocalizationService.pick(
                                ko: '안심 보안 잠금: 등록된 회원이 있을 때는 키오스크에 회원 명단/PIN이 일체 표시되지 않으며, 우측 상단 자물쇠 터치 시 관리자 비밀번호(0000)를 입력해야만 관리자 화면으로 나갈 수 있습니다.',
                                en: 'Privacy Guard: No member phone/PIN list is ever exposed on live Kiosk. Exiting requires Admin PIN (0000).',
                                ja: '安心ロック: 会員一覧やPINは表示されず、終了時は管理者パスワード(0000)が必要です。',
                                zh: '隐私保护锁：正式运行模式下隐藏所有会员列表和号码，退出需输入管理员密码(0000)。',
                                vi: 'Bảo mật an toàn: Danh sách SĐT/PIN được ẩn hoàn toàn. Thoát cần mã PIN (0000).',
                                es: 'Bloqueo seguro: No muestra teléfonos ni PINs. Para salir exige PIN admin (0000).',
                              ),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.45),
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
      maxHeightRatio: 0.90,
      builder: (sheetCtx) => Consumer(
        builder: (ctx, ref, _) {
          final latestProfile = ref.watch(studioProfileProvider).value ?? profile;
          final catState = ref.watch(customCategoryProvider).value ??
              CustomCategoryState.getDefaultsForIndustry(latestProfile.category).copyWith(
                messageTemplates: CustomCategoryState.getDefaultMessageTemplatesForIndustry(latestProfile.category),
              );

          return StickyBottomSheetLayout(
            bodyPadding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 8),
            body: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSheetHeader(
                  sheetCtx,
                  LocalizationService.pick(
                    ko: '문자 알림 및 맞춤 서식 관리',
                    en: 'SMS & Message Templates',
                    ja: 'メッセージ・定型文管理',
                    zh: '短信与通知模板管理',
                    vi: 'Quản lý mẫu tin nhắn',
                    es: 'Plantillas de Mensajes',
                  ),
                  Icons.edit_note_rounded,
                  const Color(0xFFD97706),
                ),
                Text(
                  LocalizationService.pick(
                    ko: '자동 발송 기본 3종 서식 편집',
                    en: 'Default Automated Templates (3)',
                    ja: '標準自動テンプレート (3種)',
                    zh: '默认自动消息模板 (3类)',
                    vi: '3 mẫu tin nhắn mặc định',
                    es: '3 Plantillas Automáticas Base',
                  ),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                          title: Text(
                            LocalizationService.pick(
                              ko: '${latestProfile.feeTitle} 청구서 문자 서식 편집',
                              en: 'Edit ${latestProfile.feeTitle} Invoice Template',
                              ja: '${latestProfile.feeTitle} 請求テンプレート編集',
                              zh: '编辑${latestProfile.feeTitle}账单模板',
                              vi: 'Sửa mẫu hóa đơn ${latestProfile.feeTitle}',
                              es: 'Editar Plantilla de ${latestProfile.feeTitle}',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            LocalizationService.pick(
                              ko: '${latestProfile.feeTitle} 청구 시 발송되는 기본 문자 내용을 변경합니다.',
                              en: 'Customize default message text sent with fee invoices.',
                              ja: '請求送信時の標準メッセージ本文を編集します。',
                              zh: '修改发送收费通知时的默认短信文本内容。',
                              vi: 'Chỉnh sửa nội dung tin nhắn khi gửi hóa đơn thu phí.',
                              es: 'Edita el texto predeterminado al enviar cobros.',
                            ),
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => _openTemplateEditorDialog(
                            context: context,
                            title: LocalizationService.pick(
                              ko: '${latestProfile.feeTitle} 청구서 문자 서식 편집',
                              en: 'Edit ${latestProfile.feeTitle} Invoice Template',
                              ja: '${latestProfile.feeTitle} 請求書式編集',
                              zh: '编辑${latestProfile.feeTitle}账单模板',
                              vi: 'Sửa mẫu ${latestProfile.feeTitle}',
                              es: 'Plantilla de ${latestProfile.feeTitle}',
                            ),
                            initialText: latestProfile.invoiceTemplate,
                            defaultText: latestProfile.localizedDefaultInvoiceTemplate,
                            placeholders: LocalizationService.supportsTossTransfer
                                ? '#{상호명}, #{담당자}, #{직함}, #{회원명}, #{고객호칭}, #{비용호칭}, #{청구제목}, #{금액}, #{계좌정보}, #{계좌복사용}, #{토스송금링크}, #{카드결제링크}, #{납부기한}'
                                : '#{상호명}, #{담당자}, #{직함}, #{회원명}, #{고객호칭}, #{비용호칭}, #{청구제목}, #{금액}, #{계좌정보}, #{계좌복사용}, #{카드결제링크}, #{납부기한}',
                            profile: latestProfile,
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
                          title: Text(
                            LocalizationService.pick(
                              ko: '출석 / 입실 안심 문자 서식 편집',
                              en: 'Edit Check-In Arrival Template',
                              ja: '出席・入室通知テンプレート編集',
                              zh: '编辑签到 / 到店通知模板',
                              vi: 'Sửa mẫu thông báo điểm danh',
                              es: 'Editar Plantilla de Entrada',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            LocalizationService.pick(
                              ko: '체크인 시 보호자/회원에게 전송되는 안심 문자를 변경합니다.',
                              en: 'Customize the message sent when a member checks in.',
                              ja: 'チェックイン時に送るお知らせ文面を変更します。',
                              zh: '修改会员签到后发送给本人或家长的通知内容。',
                              vi: 'Tùy chỉnh tin nhắn gửi khi hội viên điểm danh đến lớp.',
                              es: 'Personaliza el mensaje al registrar una asistencia.',
                            ),
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => _openTemplateEditorDialog(
                            context: context,
                            title: LocalizationService.pick(
                              ko: '출석 / 입실 문자 서식 편집',
                              en: 'Edit Check-In Template',
                              ja: '入室通知書式編集',
                              zh: '编辑签到通知模板',
                              vi: 'Sửa mẫu điểm danh',
                              es: 'Plantilla de Entrada',
                            ),
                            initialText: latestProfile.attendanceTemplate,
                            defaultText: latestProfile.localizedDefaultAttendanceTemplate,
                            placeholders: '#{상호명}, #{장소호칭}, #{담당자}, #{직함}, #{회원명}, #{고객호칭}, #{출석시간}, #{잔여회차}',
                            profile: latestProfile,
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
                          title: Text(
                            LocalizationService.pick(
                              ko: '퇴실 / 일정종료 문자 서식 편집',
                              en: 'Edit Departure / Class End Template',
                              ja: '退室・終了通知テンプレート編集',
                              zh: '编辑签退 / 离校通知模板',
                              vi: 'Sửa mẫu thông báo tan học',
                              es: 'Editar Plantilla de Salida',
                            ),
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                          ),
                          subtitle: Text(
                            LocalizationService.pick(
                              ko: '귀가/퇴실 시 발송되는 완료 안내 문자를 변경합니다.',
                              en: 'Customize the message sent when a session ends.',
                              ja: 'レッスン終了・帰宅時の通知文面を編集します。',
                              zh: '修改课程结束或离校时发送的提示内容。',
                              vi: 'Chỉnh sửa tin nhắn gửi khi kết thúc buổi học.',
                              es: 'Edita el mensaje enviado al finalizar la clase.',
                            ),
                            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                          ),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                          onTap: () => _openTemplateEditorDialog(
                            context: context,
                            title: LocalizationService.pick(
                              ko: '퇴실 / 일정종료 문자 서식 편집',
                              en: 'Edit Departure Template',
                              ja: '退室通知書式編集',
                              zh: '编辑离校通知模板',
                              vi: 'Sửa mẫu tan học',
                              es: 'Plantilla de Salida',
                            ),
                            initialText: latestProfile.departureTemplate,
                            defaultText: latestProfile.localizedDefaultDepartureTemplate,
                            placeholders: '#{상호명}, #{장소호칭}, #{담당자}, #{직함}, #{회원명}, #{고객호칭}',
                            profile: latestProfile,
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
                const SizedBox(height: 20),

                // 나만의 맞춤 문자 · 공지 서식
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            LocalizationService.pick(
                              ko: '나만의 맞춤 문자 · 공지 서식',
                              en: 'Custom Notice & Campaign Templates',
                              ja: 'オリジナル連絡・お知らせ書式',
                              zh: '自定义群发公告与提醒模板',
                              vi: 'Mẫu thông báo & tin nhắn riêng',
                              es: 'Plantillas de Aviso Personalizadas',
                            ),
                            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            LocalizationService.pick(
                              ko: '업종에 맞춰 안내·공지·재등록 서식을 직접 만들고 순차 발송에 불러올 수 있습니다.',
                              en: 'Create custom announcements & renewal reminders for batch/relay dispatch.',
                              ja: 'お知らせ・イベント・更新案内を作成し一斉送信で呼び出せます。',
                              zh: '创建放假公告、续费优惠等自定义模板，群发时一键调用。',
                              vi: 'Tạo mẫu thông báo nghỉ lễ, gia hạn riêng để dùng khi gửi hàng loạt.',
                              es: 'Crea avisos de festivos o renovación para envíos en lote.',
                            ),
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                if (catState.messageTemplates.isEmpty)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      LocalizationService.pick(
                        ko: '등록된 맞춤 서식이 없습니다. 상단 버튼으로 우리 매장만의 안내 문구를 만들어 보세요.',
                        en: 'No custom templates yet. Tap the button below to create one.',
                        ja: 'カスタム書式はまだありません。下のボタンから作成できます。',
                        zh: '暂无自定义模板，点击下方按钮创建专属话术。',
                        vi: 'Chưa có mẫu riêng. Nhấn nút bên dưới để tạo mới.',
                        es: 'Sin plantillas aún. Pulsa el botón de abajo para crear una.',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                    ),
                  )
                else
                  ...catState.messageTemplates.map((tpl) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFE2E8F0)),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _openCustomMessageTemplateFormDialog(context, latestProfile, existing: tpl),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(9),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFEFF6FF),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.mark_email_read_outlined, color: AppTheme.primaryBlue, size: 18),
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
                                          tpl.title,
                                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppTheme.textPrimary),
                                        ),
                                        if (tpl.categoryTag != null && tpl.categoryTag!.isNotEmpty)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFE0E7FF),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              tpl.categoryTag!,
                                              style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4338CA)),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      tpl.body,
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, height: 1.35),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue, size: 20),
                                tooltip: LocalizationService.pick(
                                  ko: '서식 수정',
                                  en: 'Edit Template',
                                  ja: '書式を編集',
                                  zh: '编辑模板',
                                  vi: 'Sửa mẫu',
                                  es: 'Editar',
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () => _openCustomMessageTemplateFormDialog(context, latestProfile, existing: tpl),
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 20),
                                tooltip: LocalizationService.pick(
                                  ko: '서식 삭제',
                                  en: 'Delete Template',
                                  ja: '書式を削除',
                                  zh: '删除模板',
                                  vi: 'Xóa mẫu',
                                  es: 'Eliminar',
                                ),
                                visualDensity: VisualDensity.compact,
                                onPressed: () async {
                                  await ref.read(customCategoryProvider.notifier).removeMessageTemplate(tpl.id);
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(LocalizationService.pick(
                                          ko: '\'${tpl.title}\' 서식이 삭제되었습니다.',
                                          en: 'Deleted \'${tpl.title}\'.',
                                          ja: '「${tpl.title}」を削除しました。',
                                          zh: '已删除模板「${tpl.title}」。',
                                          vi: 'Đã xóa mẫu \'${tpl.title}\'.',
                                          es: 'Plantilla \'${tpl.title}\' eliminada.',
                                        )),
                                        duration: const Duration(seconds: 1),
                                      ),
                                    );
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
              ],
            ),
            footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            footer: ZeroButton.primary(
              label: LocalizationService.pick(
                ko: '새 맞춤 문자 서식 만들기',
                en: 'Create New Template',
                ja: '新しい書式を作成',
                zh: '创建新消息模板',
                vi: 'Tạo mẫu tin nhắn mới',
                es: 'Crear Nueva Plantilla',
              ),
              icon: Icons.add_comment_rounded,
              size: ZeroButtonSize.medium,
              fullWidth: true,
              onPressed: () => _openCustomMessageTemplateFormDialog(context, latestProfile),
            ),
          );
        },
      ),
    );
  }

  void _openCustomMessageTemplateFormDialog(
    BuildContext context,
    StudioProfile profile, {
    CustomMessageTemplate? existing,
  }) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final tagCtrl = TextEditingController(
      text: existing?.categoryTag ?? LocalizationService.pick(ko: '공지/안내', en: 'Notice', ja: 'お知らせ', zh: '公告', vi: 'Thông báo', es: 'Aviso'),
    );
    final bodyCtrl = TextEditingController(
      text: existing?.body ??
          LocalizationService.pick(
            ko: '[#{상호명}] 안녕하세요, #{회원명} #{고객호칭}님.\n안내 말씀 전달드립니다.\n문의: #{담당자} #{직함}',
            en: '[#{상호명}] Hello #{회원명},\nQuick update from us.\nContact: #{담당자} (#{직함})',
            ja: '[#{상호명}] #{회원명}様、いつもありがとうございます。\nお知らせをお送りいたします。\n担当: #{담당자} (#{직함})',
            zh: '[#{상호명}] #{회원명} 您好，\n向您发送温馨通知。\n联系人: #{담당자} (#{직함})',
            vi: '[#{상호명}] Xin chào #{회원명},\nXin gửi thông báo đến bạn.\nLiên hệ: #{담당자}',
            es: '[#{상호명}] Hola #{회원명},\nTe enviamos un aviso importante.\nContacto: #{담당자}',
          ),
    );
    final availableTags = [
      '#{상호명}',
      '#{담당자}',
      '#{직함}',
      '#{고객호칭}',
      '#{비용호칭}',
      '#{장소호칭}',
      '#{회원명}',
      '#{그룹명}',
      '#{금액}',
      '#{계좌정보}',
      if (LocalizationService.supportsTossTransfer) '#{토스송금링크}',
      '#{카드결제링크}',
      '#{잔여회차}',
      '#{납부기한}',
    ];

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.92,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final sampleAmount = LocalizationService.formatAmount(LocalizationService.currentCurrency.sampleAmount);
            final previewBody = bodyCtrl.text
                .replaceAll('#{상호명}', profile.studioName)
                .replaceAll('#{담당자}', profile.instructorName)
                .replaceAll('#{직함}', profile.roleTitle)
                .replaceAll('#{고객호칭}', profile.memberWord)
                .replaceAll('#{비용호칭}', profile.feeWord)
                .replaceAll('#{장소호칭}', profile.placeTitle)
                .replaceAll('#{회원명}', LocalizationService.pick(ko: '김민준', en: 'Alex Kim', ja: '佐藤健太', zh: '张明', vi: 'Minh', es: 'Carlos'))
                .replaceAll('#{그룹명}', LocalizationService.localizeBuiltInLabel('정규반'))
                .replaceAll('#{금액}원', sampleAmount)
                .replaceAll('#{금액}', sampleAmount)
                .replaceAll('#{계좌정보}', '${profile.bankName} ${profile.accountNumber} (${profile.accountHolder})')
                .replaceAll('#{토스송금링크}', 'https://toss.me/sample')
                .replaceAll('#{카드결제링크}', profile.cardPaymentUrl.isNotEmpty ? profile.cardPaymentUrl : 'https://pay.example.com/checkout')
                .replaceAll('#{잔여회차}', LocalizationService.pick(ko: '2회', en: '2 left', ja: '残り2回', zh: '剩余2次', vi: 'Còn 2 buổi', es: 'Quedan 2'))
                .replaceAll('#{납부기한}', LocalizationService.formatDate(DateTime.now().add(const Duration(days: 7))));

            return StickyBottomSheetLayout(
              bodyPadding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetHeader(
                    ctx,
                    isEdit
                        ? LocalizationService.pick(
                            ko: '맞춤 문자 서식 수정',
                            en: 'Edit Custom Template',
                            ja: 'カスタム書式を編集',
                            zh: '编辑自定义模板',
                            vi: 'Sửa mẫu tin nhắn',
                            es: 'Editar Plantilla',
                          )
                        : LocalizationService.pick(
                            ko: '새 맞춤 문자 서식 만들기',
                            en: 'New Custom Template',
                            ja: '新しいカスタム書式',
                            zh: '新建自定义模板',
                            vi: 'Tạo mẫu tin nhắn mới',
                            es: 'Nueva Plantilla',
                          ),
                    Icons.mark_chat_read_outlined,
                    AppTheme.primaryBlue,
                  ),
                  AppTextField(
                    controller: titleCtrl,
                    label: LocalizationService.pick(ko: '서식 제목', en: 'Template Title', ja: 'テンプレート名', zh: '模板标题', vi: 'Tiêu đề mẫu', es: 'Título de Plantilla'),
                    hint: LocalizationService.pick(
                      ko: '예: 방학 특강 안내, 홀리데이 휴무 공지, 10회 재등록 혜택',
                      en: 'e.g., Holiday Schedule, Renewal Reminder, Gear Notice',
                      ja: '例: 休校のお知らせ、回数券更新案内',
                      zh: '例: 节假日停课通知、续费优惠提醒',
                      vi: 'VD: Thông báo nghỉ lễ, Nhắc gia hạn',
                      es: 'Ej: Aviso de festivos, Recordatorio renovación',
                    ),
                    prefixIcon: Icons.title_rounded,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: tagCtrl,
                    label: LocalizationService.pick(ko: '분류 태그 (선택)', en: 'Tag (Optional)', ja: 'タグ（任意）', zh: '分类标签（可选）', vi: 'Thẻ (Tùy chọn)', es: 'Etiqueta (Opcional)'),
                    hint: LocalizationService.pick(ko: '예: 공지사항, 이벤트, 재등록, 준비물', en: 'e.g., Notice, Promo, Renewal', ja: '例: お知らせ, 更新, 持ち物', zh: '例: 公告, 活动, 续费', vi: 'VD: Thông báo, Gia hạn', es: 'Ej: Aviso, Promo, Renovación'),
                    prefixIcon: Icons.label_outline_rounded,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    LocalizationService.pick(
                      ko: '터치하여 치환 변수 넣기 (발송 시 자동 변환)',
                      en: 'Tap to insert dynamic tags (auto-filled when sending)',
                      ja: 'タップして自動置換タグを挿入',
                      zh: '点击插入动态变量（发送时自动替换）',
                      vi: 'Chạm để chèn thẻ biến (tự động điền khi gửi)',
                      es: 'Toca para insertar etiquetas dinámicas',
                    ),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: availableTags.map((tag) {
                      return ActionChip(
                        backgroundColor: const Color(0xFFEFF6FF),
                        label: Text(tag, style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          final currentText = bodyCtrl.text;
                          final selection = bodyCtrl.selection;
                          bodyCtrl.text = selection.isValid && selection.start >= 0
                              ? currentText.replaceRange(selection.start, selection.end, tag)
                              : '$currentText $tag';
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: bodyCtrl,
                    label: LocalizationService.pick(ko: '서식 본문', en: 'Template Body', ja: '本文', zh: '正文内容', vi: 'Nội dung mẫu', es: 'Cuerpo del mensaje'),
                    maxLines: 6,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 14),
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
                        Text(
                          LocalizationService.pick(ko: '미리보기', en: 'Preview', ja: 'プレビュー', zh: '实时预览', vi: 'Xem trước', es: 'Vista previa'),
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                        ),
                        const SizedBox(height: 6),
                        Text(previewBody, style: const TextStyle(fontSize: 12.5, color: Color(0xFF1E293B), height: 1.45)),
                      ],
                    ),
                  ),
                ],
              ),
              footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              footer: ZeroButton.primary(
                label: isEdit
                    ? LocalizationService.pick(ko: '수정 내용 저장하기', en: 'Save Changes', ja: '変更を保存', zh: '保存修改', vi: 'Lưu thay đổi', es: 'Guardar Cambios')
                    : LocalizationService.pick(ko: '새 서식 저장하기', en: 'Save Template', ja: '新しい書式を保存', zh: '保存模板', vi: 'Lưu mẫu mới', es: 'Guardar Plantilla'),
                icon: Icons.check_rounded,
                size: ZeroButtonSize.large,
                fullWidth: true,
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final body = bodyCtrl.text.trim();
                  final tag = tagCtrl.text.trim();
                  if (title.isEmpty || body.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(LocalizationService.pick(
                        ko: '서식 제목과 본문을 모두 입력해주세요.',
                        en: 'Please enter both title and message body.',
                        ja: 'タイトルと本文を両方入力してください。',
                        zh: '请输入模板标题和正文内容。',
                        vi: 'Vui lòng nhập đầy đủ tiêu đề và nội dung.',
                        es: 'Ingresa el título y el cuerpo del mensaje.',
                      ))),
                    );
                    return;
                  }
                  final bm = MonetizationService.instance;
                  final tplLabel = LocalizationService.pick(ko: '맞춤 문자 서식', en: 'Template', ja: 'メッセージ書式', zh: '消息模板', vi: 'Mẫu tin nhắn', es: 'Plantilla');
                  if (isEdit) {
                    if (!await bm.ensureEditAllowed(ctx, itemLabel: tplLabel)) {
                      return;
                    }
                  } else {
                    final curMsgs = ref.read(customCategoryProvider).value?.messageTemplates.length ?? 0;
                    if (!await bm.ensureCreateAllowed(
                      ctx,
                      itemLabel: tplLabel,
                      currentCount: curMsgs,
                      limit: bm.maxCustomTemplateLimit,
                    )) {
                      return;
                    }
                  }
                  final tpl = CustomMessageTemplate(
                    id: existing?.id ?? 'msg_tpl_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    body: body,
                    categoryTag: tag.isEmpty ? null : tag,
                  );
                  await ref.read(customCategoryProvider.notifier).saveMessageTemplate(tpl);
                  if (isEdit) {
                    await bm.recordEditUsage();
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(LocalizationService.pick(
                        ko: '\'$title\' 서식이 저장되었습니다.',
                        en: 'Saved \'$title\' template.',
                        ja: '「$title」書式を保存しました。',
                        zh: '已保存模板「$title」。',
                        vi: 'Đã lưu mẫu \'$title\'.',
                        es: 'Plantilla \'$title\' guardada.',
                      ))),
                    );
                  }
                },
              ),
            );
          },
        );
      },
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
              _buildSheetHeader(
                sheetCtx,
                LocalizationService.pick(
                  ko: '비대면 신용카드 결제 링크',
                  en: 'Online Card Payment Link',
                  ja: 'オンラインカード決済リンク',
                  zh: '远程在线信用卡支付链接',
                  vi: 'Liên kết thanh toán thẻ từ xa',
                  es: 'Enlace de Pago con Tarjeta',
                ),
                Icons.credit_card_rounded,
                AppTheme.primaryBlue,
              ),
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
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                LocalizationService.pick(
                                  ko: '가입비 0원 · 월관리비 0원',
                                  en: 'Zero App Fees · Direct Checkout',
                                  ja: '月額費用 0円 · 直接決済リンク',
                                  zh: '零接入费 · 零月费直接绑定',
                                  vi: '0đ phí khởi tạo · Không phí duy trì',
                                  es: 'Sin Comisiones · Enlace Directo',
                                ),
                                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
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
                    Text(
                      LocalizationService.pick(
                        ko: '원격 비대면 카드 결제 연동',
                        en: 'Connect Remote Card Checkout',
                        ja: 'オンラインカード決済連携',
                        zh: '绑定远程在线信用卡收款',
                        vi: 'Kết nối thanh toán thẻ trực tuyến',
                        es: 'Vincular Pago Online con Tarjeta',
                      ),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                          ? '토스페이먼츠, 페이앱, 결제선생 등 사용 중인 PG사의 결제 링크를 연동하면, 청구 문자/카톡에 비대면 카드결제 링크가 자동 포함됩니다.'
                          : LocalizationService.pick(
                              ko: '사용 중인 PG사 결제 링크(Stripe/PayPal/PayApp 등)를 등록하면 청구 메시지에 카드 결제 링크가 자동 포함됩니다.',
                              en: 'Add your Stripe Payment Link, Square, PayPal.me, or local checkout URL to include instant card checkout in invoices.',
                              ja: 'Stripe Payment Links・PayPal・Square等の決済URLを登録すると請求メッセージに自動添付されます。',
                              zh: '绑定 Stripe、PayPal 等在线收款链接后，发送账单时将自动附带银行卡快捷支付链接。',
                              vi: 'Nhập link thanh toán (Stripe, PayPal, Momo, ZaloPay...) để đính kèm tự động vào hóa đơn.',
                              es: 'Añade tu enlace de Stripe, Square o PayPal para incluir el pago con tarjeta en cada cobro.',
                            ),
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
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
                                        ? LocalizationService.pick(
                                            ko: '등록된 카드결제 링크 없음 (링크를 설정해주세요)',
                                            en: 'No payment link configured yet (Tap below to set)',
                                            ja: '決済リンク未設定（下のボタンから設定してください）',
                                            zh: '尚未配置支付链接（请点击下方设置）',
                                            vi: 'Chưa thiết lập link thanh toán',
                                            es: 'Sin enlace configurado aún',
                                          )
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
                            Text(
                              LocalizationService.pick(
                                ko: '💡 팁: URL에 {금액}을 입력하면 회원별 청구 금액이 링크에 자동으로 채워집니다.',
                                en: '💡 Tip: Include {금액} in the URL to auto-fill each invoice amount.',
                                ja: '💡 ヒント: URLに {금액} を含めると請求金額が自動挿入されます。',
                                zh: '💡 提示: 在网址中加入 {금액} 可自动填入每笔账单的具体金额。',
                                vi: '💡 Mẹo: Thêm {금액} vào URL để tự động điền số tiền hóa đơn.',
                                es: '💡 Tip: Usa {금액} en la URL para rellenar el importe automáticamente.',
                              ),
                              style: const TextStyle(fontSize: 11.5, color: Color(0xFF64748B)),
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
                            label: Text(LocalizationService.pick(
                              ko: '결제 링크 설정',
                              en: 'Set Payment Link',
                              ja: '決済リンク設定',
                              zh: '设置支付链接',
                              vi: 'Cài đặt link thanh toán',
                              es: 'Configurar Enlace',
                            )),
                          ),
                        )
                      else
                        ResponsiveDialogActions(
                          primaryFirstInColumn: false,
                          secondary: OutlinedButton.icon(
                            onPressed: () => _openCardPaymentUrlDialog(context, profile),
                            icon: const Icon(Icons.edit_outlined, size: 15),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(LocalizationService.pick(
                                ko: '결제 링크 설정',
                                en: 'Edit Link',
                                ja: 'リンク編集',
                                zh: '编辑链接',
                                vi: 'Sửa link',
                                es: 'Editar Enlace',
                              )),
                            ),
                          ),
                          primary: ElevatedButton.icon(
                            onPressed: () async {
                              final testUrl = profile.getFormattedCardPaymentUrl(
                                amount: LocalizationService.currentCurrency.sampleAmount.toInt(),
                                orderTitle: 'Test ${profile.feeWord}',
                                customerName: LocalizationService.pick(ko: '홍길동', en: 'Alex Kim', ja: '佐藤太郎', zh: '测试会员', vi: 'Nguyễn A', es: 'Carlos'),
                              );
                              final uri = Uri.tryParse(testUrl);
                              if (uri != null && await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(LocalizationService.pick(
                                      ko: '유효한 웹 링크 형식이 아닙니다. (http:// 또는 https:// 포함)',
                                      en: 'Invalid web URL. Must start with http:// or https://.',
                                      ja: '有効なURL形式ではありません。(http:// または https://)',
                                      zh: '无效的网页链接格式（需以 http:// 或 https:// 开头）。',
                                      vi: 'URL không hợp lệ (phải có http:// hoặc https://).',
                                      es: 'URL inválida (debe incluir http:// o https://).',
                                    ))),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.open_in_browser_rounded, size: 15),
                            label: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(LocalizationService.pick(
                                ko: '링크 테스트',
                                en: 'Test Link',
                                ja: 'テストを開く',
                                zh: '测试打开链接',
                                vi: 'Kiểm tra link',
                                es: 'Probar Enlace',
                              )),
                            ),
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
                          label: Text(LocalizationService.pick(
                            ko: '비대면 카드결제 기능 켜기',
                            en: 'Enable Online Card Link',
                            ja: 'オンライン決済リンクを有効化',
                            zh: '开启远程信用卡收款功能',
                            vi: 'Bật thanh toán thẻ trực tuyến',
                            es: 'Activar Enlace de Tarjeta',
                          )),
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
            _buildSheetHeader(
              sheetCtx,
              LocalizationService.pick(
                ko: '로컬 데이터 보안 금고',
                en: 'Local Data Vault',
                ja: 'ローカルデータ保管庫',
                zh: '本地数据安全金库',
                vi: 'Kho bảo mật dữ liệu',
                es: 'Bóveda Local de Datos',
              ),
              Icons.lock_outline_rounded,
              const Color(0xFF0F172A),
            ),
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
                    title: Text(
                      LocalizationService.pick(
                        ko: '로컬 백업 파일 생성 & 카톡/드라이브 전송',
                        en: 'Create Encrypted Backup & Share',
                        ja: '暗号化バックアップ作成・共有',
                        zh: '创建加密备份文件并分享',
                        vi: 'Tạo tệp sao lưu mã hóa & Chia sẻ',
                        es: 'Crear Copia Cifrada y Compartir',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      LocalizationService.pick(
                        ko: '회원·출결·수납 데이터를 암호화하여 카톡/드라이브로 안전 보관합니다.',
                        en: 'Save encrypted members, attendance & billing data safely to your Drive or email.',
                        ja: '会員・出席・請求データを暗号化してクラウドやメールに安全保管します。',
                        zh: '将所有会员、考勤及收款记录加密打包，安全保存至网盘或本地。',
                        vi: 'Mã hóa toàn bộ dữ liệu hội viên, điểm danh & thu chi để lưu trữ an toàn.',
                        es: 'Cifra miembros, asistencia y cobros para guardarlos en tu nube o correo.',
                      ),
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      final file = await DataVaultService.exportEncryptedBackup();
                      await DataVaultService.shareBackupFile(file);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(LocalizationService.pick(
                              ko: '백업 파일이 생성되어 공유 창이 열렸습니다: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              en: 'Backup ready to share: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              ja: 'バックアップファイルを作成しました: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              zh: '备份文件已生成并打开分享: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              vi: 'Đã tạo tệp sao lưu: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              es: 'Copia generada: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                            )),
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
                    title: Text(
                      LocalizationService.pick(
                        ko: '수납 장부 엑셀(CSV) 내보내기 & 공유',
                        en: 'Export Payment Ledger CSV',
                        ja: '入金台帳 CSVエクスポート',
                        zh: '导出收款流水台账 (CSV)',
                        vi: 'Xuất sổ thu tiền CSV',
                        es: 'Exportar Libro de Cobros CSV',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      LocalizationService.pick(
                        ko: '세무/결산용 엑셀 호환 CSV를 생성하여 카톡/엑셀로 공유합니다.',
                        en: 'Generate Excel-compatible billing CSV for accounting & reporting.',
                        ja: '会計・集計用のExcel対応CSVを作成して共有します。',
                        zh: '生成兼容 Excel 的收款明细表，便于对账与归档。',
                        vi: 'Tạo tệp CSV chuẩn Excel để đối soát doanh thu.',
                        es: 'Genera un CSV compatible con Excel para tu contabilidad.',
                      ),
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      final file = await DataVaultService.exportLedgerCsv();
                      await DataVaultService.shareLedgerCsv(file);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(LocalizationService.pick(
                              ko: '수납 장부 CSV가 생성되어 공유 창이 열렸습니다: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              en: 'Ledger CSV ready: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              ja: '台帳CSVを作成しました: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              zh: '收款 CSV 已生成: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              vi: 'Đã tạo CSV sổ thu: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              es: 'CSV generado: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                            )),
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
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.lightbulb_rounded, size: 11, color: Color(0xFF4F46E5)),
                                const SizedBox(width: 3),
                                Text(
                                  LocalizationService.pick(
                                    ko: '세무 가이드',
                                    en: 'Tax Guide',
                                    ja: '税務ガイド',
                                    zh: '税务指南',
                                    vi: 'Hướng dẫn thuế',
                                    es: 'Guía Fiscal',
                                  ),
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    subtitle: Text(
                      LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                          ? '수입과 지출을 통합 정렬하여 5월 종합소득세 및 2월 사업장현황신고 세무사용 표준 CSV를 생성합니다.'
                          : LocalizationService.currentCurrency.taxPolicy,
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                    onTap: () async {
                      try {
                        final file = await DataVaultService.exportSimplifiedBookkeepingCsv();
                        await DataVaultService.shareSimplifiedBookkeepingCsv(file);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(LocalizationService.pick(
                                ko: '국세청 간편장부 CSV가 생성되어 공유 창이 열렸습니다: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                                en: 'Tax CSV ready: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                                ja: '税務CSVを作成しました: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                                zh: '税务账簿 CSV 已生成: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                                vi: 'Đã tạo CSV thuế: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                                es: 'CSV fiscal generado: ${file.path.split(Platform.isWindows ? "\\" : "/").last}',
                              )),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${LocalizationService.tr('common_error')}: $e')));
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
                    title: Text(
                      LocalizationService.pick(
                        ko: '백업 데이터 복원하기 (텍스트 / JSON)',
                        en: 'Restore from Backup (JSON)',
                        ja: 'バックアップデータを復元 (JSON)',
                        zh: '从备份还原数据 (文本 / JSON)',
                        vi: 'Khôi phục dữ liệu (JSON)',
                        es: 'Restaurar desde Copia (JSON)',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                    ),
                    subtitle: Text(
                      LocalizationService.pick(
                        ko: '카카오톡 등으로 보관한 백업 JSON 내용을 입력하여 복원합니다.',
                        en: 'Paste your exported JSON backup text to restore all data.',
                        ja: '保存しておいたバックアップJSONテキストを貼り付けて復元します。',
                        zh: '粘贴之前导出的备份 JSON 内容即可恢复所有记录。',
                        vi: 'Dán nội dung bản sao lưu JSON để khôi phục dữ liệu.',
                        es: 'Pega el texto JSON de tu copia para restaurar todo.',
                      ),
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                    ),
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
                    title: Text(
                      LocalizationService.pick(
                        ko: '체험용 가상 데이터 비우기 (실제 운영 시작)',
                        en: 'Clear Sample Data (Go Live)',
                        ja: 'サンプルデータを削除（本番開始）',
                        zh: '清空演示示例数据（正式投入使用）',
                        vi: 'Xóa dữ liệu mẫu (Bắt đầu chính thức)',
                        es: 'Borrar Datos de Prueba (Uso Real)',
                      ),
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.danger),
                    ),
                    subtitle: Text(
                      LocalizationService.pick(
                        ko: '샘플 5명 데이터를 모두 지우고 실제 회원만 등록합니다.',
                        en: 'Remove demo members, invoices & attendance logs while keeping your studio profile.',
                        ja: 'サンプル会員・履歴を削除し、実際の会員データだけで開始します。',
                        zh: '清除演示会员与账单记录，保留店铺设置以正式录入真实数据。',
                        vi: 'Xóa hội viên và hóa đơn mẫu để bắt đầu nhập dữ liệu thật.',
                        es: 'Borra los datos de prueba manteniendo la configuración de tu estudio.',
                      ),
                      style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
                    ),
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
        title: Row(
          children: [
            const Icon(Icons.cleaning_services_rounded, color: AppTheme.danger, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                LocalizationService.pick(
                  ko: '연습 데이터를 모두 비우시겠습니까?',
                  en: 'Clear all sample/practice data?',
                  ja: 'サンプルデータをすべて消去しますか？',
                  zh: '确定清空所有演示数据吗？',
                  vi: 'Xóa toàn bộ dữ liệu mẫu?',
                  es: '¿Borrar todos los datos de prueba?',
                ),
                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Text(
            LocalizationService.pick(
              ko: '현재 등록된 가상 회원, 출석 기록, 청구서 내역이 모두 삭제되어 실제 운영 모드로 초기화됩니다.\n(스튜디오 프로필 설정은 유지됩니다.)',
              en: 'All current members, attendance logs, and invoices will be cleared for fresh live operation.\n(Your studio profile settings will be kept.)',
              ja: '現在の会員・出席・請求記録がすべて削除され、本番環境へリセットされます。\n（スタジオ設定は保持されます）',
              zh: '当前会员、考勤及账单记录将被清空以正式开始使用。\n（您的门店设置将被保留。）',
              vi: 'Toàn bộ hội viên, điểm danh và hóa đơn hiện tại sẽ bị xóa để chạy chính thức.\n(Thông tin trung tâm vẫn được giữ lại.)',
              es: 'Se borrarán miembros, asistencias y cobros actuales para empezar en limpio.\n(La configuración de tu negocio se mantiene.)',
            ),
            style: const TextStyle(height: 1.5, fontSize: 13),
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
              label: LocalizationService.pick(
                ko: '깨끗이 비우기',
                en: 'Clear All Data',
                ja: 'すべて消去',
                zh: '全部清空',
                vi: 'Xóa sạch',
                es: 'Borrar Todo',
              ),
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
          SnackBar(
            content: Text(LocalizationService.pick(
              ko: '체험용 데이터가 모두 비워졌습니다. 이제 실제 회원과 장부를 등록해 보세요!',
              en: 'Sample data cleared! Start adding your real members and ledger entries.',
              ja: 'サンプルデータを消去しました。実際の会員を登録して始めましょう！',
              zh: '演示数据已全部清空！现在可以录入真实会员与账目了。',
              vi: 'Đã xóa dữ liệu mẫu! Bạn có thể bắt đầu thêm hội viên thật.',
              es: '¡Datos borrados! Ya puedes registrar a tus clientes reales.',
            )),
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
              _buildSheetHeader(
                sheetCtx,
                LocalizationService.pick(
                  ko: '금융 푸시 필터 보안 설정',
                  en: 'Bank Push Filter Security',
                  ja: '銀行入金通知フィルター設定',
                  zh: '银行收款通知过滤安全设置',
                  vi: 'Bảo mật lọc thông báo ngân hàng',
                  es: 'Seguridad de Filtro Bancario',
                ),
                Icons.security_rounded,
                const Color(0xFF059669),
              ),
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
                        Expanded(
                          child: Text(
                            LocalizationService.pick(
                              ko: '은행 입금 푸시 알림 자동 감지 (안드로이드)',
                              en: 'Auto-Detect Bank Deposit Alerts (Android)',
                              ja: '銀行入金通知の自動検出 (Android)',
                              zh: '自动识别银行到账推送通知 (Android)',
                              vi: 'Tự động phát hiện thông báo chuyển khoản (Android)',
                              es: 'Detección automática de avisos bancarios (Android)',
                            ),
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
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
                        children: [
                          const Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryBlue),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LocalizationService.pick(
                                ko: '검증된 1금융권/인터넷은행 앱 패키지만 엄격 필터링하며, 개인 카카오톡 및 일반 문자는 즉시 자동 폐기(Drop)하여 일체의 프라이버시 침해를 원천 차단합니다.',
                                en: 'Only trusted banking notifications are matched on-device. Personal chats and private SMS are immediately ignored.',
                                ja: '承認された銀行アプリの入金通知のみを端末内で照合し、個人チャットや一般SMSは即座に破棄します。',
                                zh: '仅在本地严格匹配受信任银行的到账通知，私人聊天和普通短信将被立即过滤丢弃。',
                                vi: 'Chỉ lọc thông báo nhận tiền ngân hàng trên thiết bị, bỏ qua hoàn toàn tin nhắn cá nhân.',
                                es: 'Solo filtra notificaciones bancarias autorizadas en tu dispositivo; los chats personales se ignoran.',
                              ),
                              style: const TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
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
            _buildSheetHeader(
              sheetCtx,
              LocalizationService.pick(
                ko: '법적 고지 및 규정 준수 (Compliance)',
                en: 'Legal Notice & Compliance',
                ja: '法的表記・コンプライアンス',
                zh: '法律声明与隐私合规',
                vi: 'Thông báo pháp lý & Tuân thủ',
                es: 'Aviso Legal y Cumplimiento',
              ),
              Icons.gavel_rounded,
              const Color(0xFF64748B),
            ),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.verified_user_rounded, size: 18, color: Color(0xFF059669)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          LocalizationService.pick(
                            ko: '100% 로컬 온디바이스 보안 보증',
                            en: '100% On-Device Privacy & GDPR/CCPA Ready',
                            ja: '100% ローカル端末内保存の安全性保証',
                            zh: '100% 本地离线加密隐私保护承诺',
                            vi: 'Cam kết bảo mật 100% dữ liệu trên thiết bị',
                            es: 'Garantía de Privacidad 100% Local (RGPD / CCPA)',
                          ),
                          style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    LocalizationService.pick(
                      ko: '본 앱은 오프라인 장부 및 메시지 서식 도구이며, 모든 데이터는 기기에만 AES 암호화 보관됩니다. 원격 중앙 서버 및 제3자 분석 서버로 데이터를 전송하지 않습니다.\n회원 정보 수집 동의 및 회원과의 수납·거래 책임은 운영자 본인에게 있습니다.',
                      en: 'Check & Pay operates strictly on-device as a ledger and messaging assistant. No member or payment records are transmitted to remote servers. Business operators remain responsible for obtaining local consent and tax filings.',
                      ja: '本アプリは端末内完結型の台帳・通知ツールであり、顧客や売上データは外部サーバーへ送信されません。同意取得や税務申告は事業者の責任で行ってください。',
                      zh: '本应用为纯本地离线台账及通知工具，所有记录均加密保存于本机，不上传至任何远程服务器。经营者须自行遵守当地隐私告知与税务申报法规。',
                      vi: 'Check & Pay hoạt động hoàn toàn ngoại tuyến trên thiết bị của bạn, không gửi dữ liệu lên máy chủ ngoài. Chủ cơ sở chịu trách nhiệm tuân thủ quy định tại địa phương.',
                      es: 'Check & Pay funciona íntegramente en tu dispositivo sin transmitir datos a servidores remotos. El titular es responsable del consentimiento local y sus obligaciones fiscales.',
                    ),
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.5),
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
                    LocalizationService.pick(
                      ko: '🔥 연속 ${bm.activeStreakDays}일 스마트 운영 중',
                      en: '🔥 ${bm.activeStreakDays}-day smart streak',
                      ja: '🔥 連続 ${bm.activeStreakDays}日 運用中',
                      zh: '🔥 已连续高效运营 ${bm.activeStreakDays} 天',
                      vi: '🔥 Chuỗi ${bm.activeStreakDays} ngày vận hành',
                      es: '🔥 Racha activa de ${bm.activeStreakDays} días',
                    ),
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
                    ? LocalizationService.pick(
                        ko: '올인원 VIP 멤버십 활성화 완료',
                        en: 'All-in-One VIP Membership Active',
                        ja: 'オールインワンVIP 有効',
                        zh: '全能 VIP 会员特权已激活',
                        vi: 'Gói VIP Trọn Gói Đang Hoạt Động',
                        es: 'Membresía VIP Todo en Uno Activa',
                      )
                    : LocalizationService.pick(
                        ko: '누적 절감 가치: 약 ${LocalizationService.formatAmount(bm.estimatedTotalSavedKRW)}',
                        en: 'Estimated Value Saved: ${LocalizationService.formatAmount(bm.estimatedTotalSavedKRW)}',
                        ja: '累計節約価値: ${LocalizationService.formatAmount(bm.estimatedTotalSavedKRW)}',
                        zh: '累计节省价值: 约 ${LocalizationService.formatAmount(bm.estimatedTotalSavedKRW)}',
                        vi: 'Giá trị tiết kiệm ước tính: ${LocalizationService.formatAmount(bm.estimatedTotalSavedKRW)}',
                        es: 'Valor ahorrado estimado: ${LocalizationService.formatAmount(bm.estimatedTotalSavedKRW)}',
                      ),
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
                    ? LocalizationService.pick(
                        ko: '모든 광고가 차단되었으며 입구 거치형 무인 출결 키오스크를 무제한으로 이용하실 수 있습니다.',
                        en: 'All ads removed + unlimited members, invoices, and Kiosk unlocked.',
                        ja: '広告非表示＆登録数無制限・キオスク機能フル開放中です。',
                        zh: '已免除全部广告，会员、账单及考勤机权限全部无限制开放。',
                        vi: 'Đã gỡ toàn bộ quảng cáo và mở khóa không giới hạn mọi tính năng.',
                        es: 'Sin anuncios y con miembros, cobros y quiosco ilimitados.',
                      )
                    : isTemp
                        ? LocalizationService.pick(
                            ko: '현재 1시간 무료 VIP 체험권이 작동 중입니다 (${bm.remainingTemporaryPassFormatted}). 월 1,900원(한 달 구독)으로 쾌적한 매장을 유지하세요.',
                            en: '1-Hour VIP Trial Active (${bm.remainingTemporaryPassFormatted}). Upgrade to PRO for unlimited access.',
                            ja: '1時間VIP体験中 (${bm.remainingTemporaryPassFormatted})。広告なしプランで快適に運用できます。',
                            zh: '1小时VIP免费试用生效中 (${bm.remainingTemporaryPassFormatted})，随时升级永久畅享。',
                            vi: 'Đang dùng thử VIP 1 giờ (${bm.remainingTemporaryPassFormatted}). Nâng cấp PRO để dùng không giới hạn.',
                            es: 'Prueba VIP de 1h activa (${bm.remainingTemporaryPassFormatted}). Pásate a PRO cuando quieras.',
                          )
                        : LocalizationService.pick(
                            ko: '0원 문자(${bm.cumulativeSavedSmsCount}건)와 자동 출결(${bm.cumulativeCheckInCount}건)로 아낀 비용으로 광고 없는 VIP 매장과 무인 키오스크를 시작하세요.',
                            en: 'You logged ${bm.cumulativeCheckInCount} check-ins & ${bm.cumulativeSavedSmsCount} free alerts. Upgrade for zero ads & unlimited capacity!',
                            ja: '${bm.cumulativeCheckInCount}回の出席と${bm.cumulativeSavedSmsCount}通の無料通知を記録中。PRO版で広告なし・無制限に。',
                            zh: '已零成本发送${bm.cumulativeSavedSmsCount}条通知并记录${bm.cumulativeCheckInCount}次考勤，立即升级解锁无广告与无限容量！',
                            vi: 'Đã tiết kiệm ${bm.cumulativeSavedSmsCount} tin nhắn & ${bm.cumulativeCheckInCount} lượt điểm danh. Nâng cấp PRO không quảng cáo!',
                            es: 'Llevas ${bm.cumulativeSavedSmsCount} avisos gratis y ${bm.cumulativeCheckInCount} check-ins. ¡Desbloquea PRO sin límites!',
                          ),
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
                        isVip
                            ? LocalizationService.pick(
                                ko: 'VIP 구독 관리 열기',
                                en: 'Manage VIP Membership',
                                ja: 'VIPプランを管理',
                                zh: '管理 VIP 订阅特权',
                                vi: 'Quản lý gói VIP',
                                es: 'Gestionar Suscripción VIP',
                              )
                            : LocalizationService.pick(
                                ko: '월 1,900원~ VIP 멤버십 보기',
                                en: 'View PRO & VIP Plans',
                                ja: 'VIPメンバーシップを見る',
                                zh: '查看 VIP 无广告会员方案',
                                vi: 'Xem các gói PRO & VIP',
                                es: 'Ver Planes PRO y VIP',
                              ),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  if (!isVip) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: bm.canClaimTemporaryPass
                            ? () => bm.launchTemporaryPassFlow(context)
                            : null,
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: Colors.white.withValues(alpha: isTemp ? 0.2 : 0.35),
                          ),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: const Color(0xFF94A3B8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: Icon(
                          isTemp ? Icons.timer_outlined : Icons.play_circle_outline_rounded,
                          size: 15,
                          color: isTemp ? const Color(0xFF34D399) : const Color(0xFFFBBF24),
                        ),
                        label: Text(
                          isTemp
                              ? LocalizationService.pick(
                                  ko: '1시간 VIP 체험 중 (${bm.remainingTemporaryPassFormatted})',
                                  en: '1-Hr Trial Active (${bm.remainingTemporaryPassFormatted})',
                                  ja: '1時間VIP体験中 (${bm.remainingTemporaryPassFormatted})',
                                  zh: '1小时VIP试用中 (${bm.remainingTemporaryPassFormatted})',
                                  vi: 'Đang dùng thử VIP 1h (${bm.remainingTemporaryPassFormatted})',
                                  es: 'Prueba 1h Activa (${bm.remainingTemporaryPassFormatted})',
                                )
                              : LocalizationService.pick(
                                  ko: '1시간 VIP 무료 체험',
                                  en: 'Free 1-Hour VIP Pass',
                                  ja: '1時間 VIP無料体験',
                                  zh: '免费体验 1 小时 VIP',
                                  vi: 'Dùng thử VIP 1 giờ miễn phí',
                                  es: 'Pase VIP Gratis 1 Hora',
                                ),
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
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
                          isSeniorMode
                              ? LocalizationService.pick(ko: '사용 중', en: 'ACTIVE', ja: '有効中', zh: '已启用', vi: 'ĐANG BẬT', es: 'ACTIVO')
                              : LocalizationService.pick(ko: '고령자 맞춤', en: 'ACCESSIBILITY', ja: 'シニア配慮', zh: '大字关怀', vi: 'DỄ ĐỌC', es: 'ACCESIBLE'),
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
                          LocalizationService.pick(
                            ko: '시니어 큰글씨 모드',
                            en: 'Large Text & High-Contrast Mode',
                            ja: 'シニア・大きな文字モード',
                            zh: '关怀大字体模式',
                            vi: 'Chế độ chữ lớn dễ đọc',
                            es: 'Modo Texto Grande y Alto Contraste',
                          ),
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
                            ? LocalizationService.pick(
                                ko: '글씨 1.4배 확대 및 고대비 간편 화면이 적용 중입니다.',
                                en: '1.4x larger typography & high-contrast layout active.',
                                ja: '1.4倍拡大文字・高コントラスト画面が適用中です。',
                                zh: '已启用 1.4 倍超大字体及高对比度简洁布局。',
                                vi: 'Đang áp dụng chữ lớn 1.4x và giao diện tương phản cao.',
                                es: 'Tipografía 1.4x y diseño de alto contraste activos.',
                              )
                            : LocalizationService.pick(
                                ko: '1.4배 큰글씨 & 고대비 간편 화면으로 편하게 이용하세요',
                                en: '1.4x larger text & high-contrast buttons for easy viewing',
                                ja: '1.4倍の大きな文字＆見やすいボタン配置に切り替えます',
                                zh: '开启 1.4 倍放大字体与高对比度护眼大按钮模式',
                                vi: 'Phóng to chữ 1.4 lần & nút bấm tương phản cao',
                                es: 'Texto 1.4x más grande y botones amplios de fácil lectura',
                              ),
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
                    label: Text(
                      LocalizationService.pick(
                        ko: '큰글씨 사용 가이드 보기',
                        en: 'View Large Text Mode Guide',
                        ja: '大きな文字ガイドを見る',
                        zh: '查看大字体模式指南',
                        vi: 'Xem hướng dẫn chế độ chữ lớn',
                        es: 'Ver Guía de Texto Grande',
                      ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
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
            _buildSheetHeader(
              ctx,
              LocalizationService.pick(
                ko: '상호 및 브랜드 로고 관리',
                en: 'Studio Logo & Branding',
                ja: 'ロゴ・ブランド設定',
                zh: '品牌标志管理',
                vi: 'Logo & Thương hiệu',
                es: 'Logo y Marca del Negocio',
              ),
              Icons.photo_camera_rounded,
              AppTheme.primaryBlue,
            ),
            const SizedBox(height: 4),
            Text(
              LocalizationService.pick(
                ko: '무인 키오스크 상단 및 알림장에 우리 학원 전용 로고가 표기됩니다.',
                en: 'Your custom logo appears on the Kiosk welcome screen and member passes.',
                ja: 'キオスク画面やデジタル会員証にオリジナルロゴが表示されます。',
                zh: '您的专属标志将显示在考勤机顶部及会员电子凭证上。',
                vi: 'Logo riêng sẽ hiển thị trên màn hình Kiosk và thẻ hội viên.',
                es: 'Tu logo aparecerá en la pantalla del Quiosco y pases digitales.',
              ),
              style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
            ),
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
                title: Text(
                  LocalizationService.pick(
                    ko: '갤러리에서 로고 선택',
                    en: 'Choose from Gallery',
                    ja: 'ギャラリーから選択',
                    zh: '从相册选择标志',
                    vi: 'Chọn từ thư viện ảnh',
                    es: 'Elegir de la Galería',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  LocalizationService.pick(
                    ko: '정사각형 또는 가로형 PNG/JPG 이미지 권장',
                    en: 'Square or horizontal PNG/JPG recommended',
                    ja: '正方形または横長のPNG/JPG推奨',
                    zh: '建议上传正方形或横向 PNG/JPG 图片',
                    vi: 'Khuyên dùng ảnh PNG/JPG vuông hoặc ngang',
                    es: 'Se recomienda PNG o JPG cuadrado u horizontal',
                  ),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
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
                title: Text(
                  LocalizationService.pick(
                    ko: '카메라로 직접 촬영',
                    en: 'Take Photo with Camera',
                    ja: 'カメラで撮影する',
                    zh: '使用相机拍摄',
                    vi: 'Chụp bằng máy ảnh',
                    es: 'Tomar Foto con Cámara',
                  ),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  LocalizationService.pick(
                    ko: '명함, 간판, 학원 서식 사진을 즉석에서 촬영',
                    en: 'Capture your storefront sign, card, or emblem',
                    ja: '看板・名刺・パンフレットのロゴをその場で撮影',
                    zh: '直接拍摄名片、门店招牌或机构徽标',
                    vi: 'Chụp bảng hiệu hoặc danh thiếp ngay lập tức',
                    es: 'Fotografía tu letrero, tarjeta o logotipo',
                  ),
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
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
                  title: Text(
                    LocalizationService.pick(
                      ko: '등록된 로고 삭제',
                      en: 'Remove Current Logo',
                      ja: '現在のロゴを削除',
                      zh: '删除当前标志',
                      vi: 'Xóa logo hiện tại',
                      es: 'Eliminar Logo Actual',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFEF4444)),
                  ),
                  subtitle: Text(
                    LocalizationService.pick(
                      ko: '기본 마스코트 아이콘으로 복원합니다.',
                      en: 'Restore default brand icon',
                      ja: 'デフォルトのアイコンに戻します',
                      zh: '恢复默认图标展示',
                      vi: 'Khôi phục biểu tượng mặc định',
                      es: 'Restaurar icono predeterminado',
                    ),
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ref.read(studioProfileProvider.notifier).updateProfile(profile.copyWith(clearLogo: true));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(LocalizationService.pick(
                          ko: '상호 로고가 삭제되어 기본 아이콘으로 복원되었습니다.',
                          en: 'Logo removed. Restored default icon.',
                          ja: 'ロゴを削除し初期アイコンに戻しました。',
                          zh: '已删除标志并恢复默认图标。',
                          vi: 'Đã xóa logo và khôi phục mặc định.',
                          es: 'Logo eliminado. Icono restaurado.',
                        ))),
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
          SnackBar(content: Text(LocalizationService.pick(
            ko: '상호 로고가 성공적으로 등록되었습니다! 키오스크에 즉시 적용됩니다.',
            en: 'Logo saved! Now active on your Kiosk screen.',
            ja: 'ロゴを登録しました！キオスクに即時反映されます。',
            zh: '机构标志已保存，考勤机界面将即时更新。',
            vi: 'Đã lưu logo! Hiển thị ngay trên màn hình Kiosk.',
            es: '¡Logo guardado! Ya se muestra en el Quiosco.',
          ))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${LocalizationService.tr('common_error')}: $e')),
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
                ? (customMemberCtrl.text.trim().isEmpty
                    ? LocalizationService.termOptionLabel('회원')
                    : customMemberCtrl.text.trim())
                : LocalizationService.termOptionLabel(selectedMember);
            final activeFeeTerm = isCustomFee
                ? (customFeeCtrl.text.trim().isEmpty
                    ? LocalizationService.termOptionLabel('회비')
                    : customFeeCtrl.text.trim())
                : LocalizationService.termOptionLabel(selectedFee);
            final activeRoleTerm = isCustomRole
                ? (customRoleCtrl.text.trim().isEmpty
                    ? LocalizationService.termOptionLabel('대표')
                    : customRoleCtrl.text.trim())
                : LocalizationService.termOptionLabel(selectedRole);
            final activePlaceTerm = isCustomPlace
                ? (customPlaceCtrl.text.trim().isEmpty
                    ? LocalizationService.termOptionLabel('매장')
                    : customPlaceCtrl.text.trim())
                : LocalizationService.termOptionLabel(selectedPlace);
            final customBtnLabel = LocalizationService.pick(
              ko: '직접 입력',
              en: 'Custom',
              ja: '直接入力',
              zh: '自定义',
              vi: 'Tự nhập',
              es: 'Personalizado',
            );

            return StickyBottomSheetLayout(
              bodyPadding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetHeader(
                    ctx,
                    LocalizationService.pick(
                      ko: '맞춤 호칭 & 용어 설정',
                      en: 'Custom Terminology & Labels',
                      ja: 'カスタム呼称・用語設定',
                      zh: '自定义称呼与术语设置',
                      vi: 'Tùy chỉnh tên gọi & thuật ngữ',
                      es: 'Términos Personalizados',
                    ),
                    Icons.badge_rounded,
                    const Color(0xFF0F172A),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    LocalizationService.pick(
                      ko: '고객, 수납 비용, 운영자 직함(대표/원장/실장 등), 장소 호칭을 매장 성격에 맞게 직접 정할 수 있으며 문자와 알림장에 즉시 반영됩니다.',
                      en: 'Tailor how members, fees, your title, and venue appear across the app, Kiosk, and invoices.',
                      ja: '会員・会費・役職・場所の呼称を業種に合わせてカスタマイズでき、メッセージや画面に即時反映されます。',
                      zh: '自定义会员、费用、管理者职称及场馆称呼，将实时反映在通知文案和全部界面中。',
                      vi: 'Tùy chỉnh cách gọi hội viên, học phí, chức danh và địa điểm trên toàn bộ tin nhắn.',
                      es: 'Adapta los términos para miembros, cuotas, tu cargo y local en toda la app.',
                    ),
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 18),

                  // 1. Member Term
                  Text(
                    LocalizationService.pick(
                      ko: '1. 고객 / 회원 호칭 선택',
                      en: '1. Client / Member Label',
                      ja: '1. お客様・会員の呼称',
                      zh: '1. 客户 / 会员称呼',
                      vi: '1. Tên gọi Hội viên / Khách hàng',
                      es: '1. Término para Clientes / Alumnos',
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.memberTermOptions.map((term) {
                        final isSel = !isCustomMember && selectedMember == term;
                        return ChoiceChip(
                          label: Text(LocalizationService.termOptionLabel(term), style: TextStyle(
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
                        label: Text(customBtnLabel, style: TextStyle(
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
                      label: LocalizationService.pick(ko: '직접 입력 호칭', en: 'Custom Member Term', ja: 'カスタム呼称', zh: '自定义会员称呼', vi: 'Tên gọi tự nhập', es: 'Término personalizado'),
                      hint: LocalizationService.pick(ko: '예: 수련생, 아동, 멘티, 골퍼, 회원님', en: 'e.g., Athlete, Musician, Patient, Mentee', ja: '例: 生徒様, 選手, お子様', zh: '例: 学员, 小朋友, 私教会员', vi: 'VD: Võ sinh, Bé, Học viên', es: 'Ej: Atleta, Alumno, Paciente'),
                      prefixIcon: Icons.edit_outlined,
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 2. Fee Term
                  Text(
                    LocalizationService.pick(
                      ko: '2. 청구 / 수납 비용 호칭 선택',
                      en: '2. Fee / Tuition Label',
                      ja: '2. 請求・料金の呼称',
                      zh: '2. 收费 / 会费名称',
                      vi: '2. Tên gọi Học phí / Phí',
                      es: '2. Término para Cuota / Tarifa',
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.feeTermOptions.map((term) {
                        final isSel = !isCustomFee && selectedFee == term;
                        return ChoiceChip(
                          label: Text(LocalizationService.termOptionLabel(term), style: TextStyle(
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
                        label: Text(customBtnLabel, style: TextStyle(
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
                      label: LocalizationService.pick(ko: '직접 입력 비용명', en: 'Custom Fee Label', ja: 'カスタム料金名', zh: '自定义费用名称', vi: 'Tên phí tự nhập', es: 'Nombre de tarifa'),
                      hint: LocalizationService.pick(ko: '예: 레슨비, 강습료, 교재비, 회비', en: 'e.g., Dues, Retainer, Coaching Fee', ja: '例: 受講料, 材料費, 月会費', zh: '例: 课时费, 材料费, 托管费', vi: 'VD: Phí tập, Học phí, Tài liệu', es: 'Ej: Mensualidad, Bono, Matrícula'),
                      prefixIcon: Icons.payments_outlined,
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 3. Operator Role Term
                  Text(
                    LocalizationService.pick(
                      ko: '3. 운영자 직함 호칭 선택',
                      en: '3. Operator / Staff Title',
                      ja: '3. 管理者・指導者の役職',
                      zh: '3. 管理者 / 老师职称',
                      vi: '3. Chức danh người quản lý',
                      es: '3. Cargo del Responsable',
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.roleTermOptions.map((term) {
                        final isSel = !isCustomRole && selectedRole == term;
                        return ChoiceChip(
                          label: Text(LocalizationService.termOptionLabel(term), style: TextStyle(
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
                        label: Text(customBtnLabel, style: TextStyle(
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
                      label: LocalizationService.pick(ko: '직접 입력 직함', en: 'Custom Title', ja: 'カスタム役職', zh: '自定义职称', vi: 'Chức danh tự nhập', es: 'Cargo personalizado'),
                      hint: LocalizationService.pick(ko: '예: 총괄실장, 수석코치, 디자이너, 매니저', en: 'e.g., Head Coach, Founder, Tutor', ja: '例: ヘッドコーチ, 代表講師', zh: '例: 店长, 总教练, 创始人', vi: 'VD: HLV trưởng, Hiệu trưởng', es: 'Ej: Entrenador Jefe, Director'),
                      prefixIcon: Icons.person_pin_outlined,
                      onChanged: (_) => setModalState(() {}),
                    ),
                  ],
                  const SizedBox(height: 20),

                  // 4. Place Term
                  Text(
                    LocalizationService.pick(
                      ko: '4. 사업장 성격 호칭 선택',
                      en: '4. Venue / Location Label',
                      ja: '4. 施設・場所の呼称',
                      zh: '4. 场馆 / 门店称呼',
                      vi: '4. Tên gọi Cơ sở / Địa điểm',
                      es: '4. Término del Centro / Local',
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.placeTermOptions.map((term) {
                        final isSel = !isCustomPlace && selectedPlace == term;
                        return ChoiceChip(
                          label: Text(LocalizationService.termOptionLabel(term), style: TextStyle(
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
                        label: Text(customBtnLabel, style: TextStyle(
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
                      label: LocalizationService.pick(ko: '직접 입력 사업장 호칭', en: 'Custom Venue Name', ja: 'カスタム場所名', zh: '自定义场馆称呼', vi: 'Tên cơ sở tự nhập', es: 'Nombre del centro'),
                      hint: LocalizationService.pick(ko: '예: 클리닉, 연습실, 작업실, 랩', en: 'e.g., Lab, Dojo, Lounge, Atelier', ja: '例: ラボ, 道場, アトリエ', zh: '例: 诊所, 排练室, 创客空间', vi: 'VD: Võ đường, Lớp học', es: 'Ej: Clínica, Dojo, Taller'),
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
                        Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 14, color: Color(0xFF38BDF8)),
                            const SizedBox(width: 6),
                            Text(
                              LocalizationService.pick(
                                ko: '실시간 앱·문자 표기 미리보기',
                                en: 'Live App & Message Preview',
                                ja: 'リアルタイム表記プレビュー',
                                zh: '应用及短信文案实时预览',
                                vi: 'Xem trước hiển thị thực tế',
                                es: 'Vista Previa en Tiempo Real',
                              ),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF38BDF8)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          LocalizationService.pick(
                            ko: '• 안내장: [${current.studioName}] 홍길동 $activeMemberTerm님의 $activeFeeTerm 청구서',
                            en: '• Invoice: [${current.studioName}] $activeFeeTerm Notice ($activeMemberTerm: Alex)',
                            ja: '• 請求: [${current.studioName}] 佐藤様 ($activeMemberTerm) の $activeFeeTerm',
                            zh: '• 账单: [${current.studioName}] 张明 ($activeMemberTerm) 的 $activeFeeTerm 通知',
                            vi: '• Hóa đơn: [${current.studioName}] $activeFeeTerm ($activeMemberTerm: Minh)',
                            es: '• Cobro: [${current.studioName}] $activeFeeTerm ($activeMemberTerm: Carlos)',
                          ),
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LocalizationService.pick(
                            ko: '• 출결: [${current.studioName}] $activeMemberTerm님이 $activePlaceTerm에 도착하여 체크인 완료',
                            en: '• Check-in: [${current.studioName}] $activeMemberTerm checked in at $activePlaceTerm',
                            ja: '• 出席: [${current.studioName}] $activeMemberTerm様が$activePlaceTermに到着',
                            zh: '• 考勤: [${current.studioName}] $activeMemberTerm 已安全抵达 $activePlaceTerm 并签到',
                            vi: '• Điểm danh: [${current.studioName}] $activeMemberTerm đã đến $activePlaceTerm',
                            es: '• Entrada: [${current.studioName}] $activeMemberTerm ha llegado al $activePlaceTerm',
                          ),
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '• ${LocalizationService.pick(ko: '발신/서명', en: 'Sign-off', ja: '署名', zh: '落款', vi: 'Chữ ký', es: 'Firma')}: ${current.studioName} ($activeRoleTerm: ${current.instructorName})',
                          style: const TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              footer: SizedBox(
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
                        SnackBar(content: Text(LocalizationService.pick(
                          ko: '맞춤 호칭($activeRoleTerm · $activeMemberTerm · $activeFeeTerm · $activePlaceTerm)이 저장되었습니다.',
                          en: 'Saved custom labels ($activeRoleTerm · $activeMemberTerm · $activeFeeTerm · $activePlaceTerm).',
                          ja: '呼称設定 ($activeRoleTerm · $activeMemberTerm · $activeFeeTerm · $activePlaceTerm) を保存しました。',
                          zh: '已保存自定义称呼 ($activeRoleTerm · $activeMemberTerm · $activeFeeTerm · $activePlaceTerm)。',
                          vi: 'Đã lưu tên gọi ($activeRoleTerm · $activeMemberTerm · $activeFeeTerm · $activePlaceTerm).',
                          es: 'Términos guardados ($activeRoleTerm · $activeMemberTerm · $activeFeeTerm · $activePlaceTerm).',
                        ))),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    LocalizationService.pick(
                      ko: '맞춤 호칭 저장하기',
                      en: 'Save Custom Terminology',
                      ja: 'カスタム呼称を保存',
                      zh: '保存自定义称呼',
                      vi: 'Lưu tên gọi tùy chỉnh',
                      es: 'Guardar Términos',
                    ),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
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
            return StickyBottomSheetLayout(
              bodyPadding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetHeader(
                    ctx,
                    LocalizationService.pick(
                      ko: '스튜디오 프로필 수정',
                      en: 'Edit Studio Profile',
                      ja: 'スタジオプロフィール編集',
                      zh: '编辑机构与门店资料',
                      vi: 'Chỉnh sửa hồ sơ trung tâm',
                      es: 'Editar Perfil del Negocio',
                    ),
                    Icons.storefront_rounded,
                    AppTheme.primaryBlue,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LocalizationService.pick(
                      ko: '청구서 및 알림 문자에 표기될 사업장 정보입니다.',
                      en: 'Shown on receipts, Kiosk check-in screens, and billing messages.',
                      ja: '請求書・キオスク・通知メッセージに表示される基本情報です。',
                      zh: '以下信息将用于账单、考勤机欢迎页及短信通知落款。',
                      vi: 'Hiển thị trên hóa đơn, màn hình Kiosk và tin nhắn.',
                      es: 'Visible en recibos, pantalla de quiosco y avisos de cobro.',
                    ),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
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
                          label: Text(
                            modalLogoPath != null && !modalClearLogo
                                ? LocalizationService.pick(ko: '로고 변경', en: 'Change Logo', ja: 'ロゴ変更', zh: '更换标志', vi: 'Đổi logo', es: 'Cambiar Logo')
                                : LocalizationService.pick(ko: '상호 로고 등록', en: 'Upload Logo', ja: 'ロゴ登録', zh: '上传标志', vi: 'Tải lên logo', es: 'Subir Logo'),
                          ),
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
                            child: Text(LocalizationService.tr('btn_delete'), style: const TextStyle(color: Color(0xFFEF4444))),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  AppTextField(
                    controller: studioCtrl,
                    label: LocalizationService.pick(
                      ko: '상호명 / 스튜디오명',
                      en: 'Business / Studio Name',
                      ja: '屋号・教室・スタジオ名',
                      zh: '机构 / 工作室名称',
                      vi: 'Tên trung tâm / Studio',
                      es: 'Nombre del Negocio / Estudio',
                    ),
                    hint: LocalizationService.pick(
                      ko: '예: 체크앤페이 스튜디오',
                      en: 'e.g., MindFit Academy',
                      ja: '例: マインドフィットスタジオ',
                      zh: '例: 星光音乐钢琴教室',
                      vi: 'VD: Trung tâm MindFit',
                      es: 'Ej: Academia MindFit',
                    ),
                    prefixIcon: Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 14),

                  // Business Category Selector
                  Text(
                    LocalizationService.pick(
                      ko: '사업장 업종 카테고리',
                      en: 'Business Industry',
                      ja: '業種カテゴリー',
                      zh: '所属行业分类',
                      vi: 'Lĩnh vực hoạt động',
                      es: 'Sector de Actividad',
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: StudioProfile.businessCategories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(LocalizationService.industryCategoryLabel(cat), style: TextStyle(
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
                      label: LocalizationService.pick(ko: '직접 입력 카테고리', en: 'Custom Category', ja: 'カスタム業種名', zh: '自定义行业名', vi: 'Lĩnh vực tùy chỉnh', es: 'Categoría personalizada'),
                      hint: LocalizationService.pick(ko: '예: 바리스타 학원, 가죽 공방, 보컬 레슨', en: 'e.g., Vocal Coaching, Barista School', ja: '例: ボイトレ教室, 陶芸スタジオ', zh: '例: 声乐私教, 烘焙工作室', vi: 'VD: Dạy thanh nhạc, Pha chế', es: 'Ej: Clases de Canto, Escuela Barista'),
                      prefixIcon: Icons.category_outlined,
                    ),
                  ],
                  const SizedBox(height: 14),

                  AppTextField(
                    controller: instructorCtrl,
                    label: LocalizationService.pick(ko: '담당자 성명', en: 'Instructor / Owner Name', ja: '担当者・代表者名', zh: '负责人姓名', vi: 'Tên người quản lý / GV', es: 'Nombre del Responsable'),
                    hint: LocalizationService.pick(ko: '예: 홍길동', en: 'e.g., Sarah Kim', ja: '例: 佐藤 美咲', zh: '例: 李老师', vi: 'VD: Nguyễn Minh', es: 'Ej: Carlos García'),
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    LocalizationService.pick(
                      ko: '직함 / 호칭 (문자·명세서에 반영)',
                      en: 'Role / Title (Shown on invoices)',
                      ja: '役職・肩書き（メッセージに表示）',
                      zh: '职称 / 头衔（显示在账单与通知中）',
                      vi: 'Chức danh (Hiển thị trong tin nhắn)',
                      es: 'Cargo / Título (Visible en cobros)',
                    ),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      ...StudioProfile.roleTermOptions.map((term) {
                        final isSel = !isCustomRole && selectedRole == term;
                        return ChoiceChip(
                          label: Text(LocalizationService.termOptionLabel(term), style: TextStyle(
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
                        label: Text(LocalizationService.pick(ko: '직접 입력', en: 'Custom', ja: '直接入力', zh: '自定义', vi: 'Tự nhập', es: 'Otro'), style: TextStyle(
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
                      label: LocalizationService.pick(ko: '직접 입력 직함', en: 'Custom Role Title', ja: 'カスタム役職', zh: '自定义职称', vi: 'Chức danh riêng', es: 'Cargo personalizado'),
                      hint: LocalizationService.pick(ko: '예: 실장, 코치, 총괄매니저', en: 'e.g., Founder, Head Coach', ja: '例: マネージャー, 主任コーチ', zh: '例: 店长, 教练', vi: 'VD: Quản lý, HLV', es: 'Ej: Director, Entrenador'),
                      prefixIcon: Icons.person_pin_outlined,
                    ),
                  ],
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: bankCtrl,
                    label: LocalizationService.pick(ko: '수납 은행명', en: 'Receiving Bank / App', ja: '振込先銀行名', zh: '收款银行 / 渠道', vi: 'Ngân hàng nhận', es: 'Banco Receptor'),
                    hint: LocalizationService.currentCurrency.bankHint,
                    prefixIcon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: accountCtrl,
                    label: LocalizationService.pick(ko: '수납 계좌번호', en: 'Account Number / IBAN / Handle', ja: '口座番号', zh: '收款账号 / 银行卡号', vi: 'Số tài khoản', es: 'Número de Cuenta / IBAN'),
                    hint: LocalizationService.supportsTossTransfer ? '예: 3333-01-2345678' : 'e.g., Account / IBAN / @handle',
                    prefixIcon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.text,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: holderCtrl,
                    label: LocalizationService.pick(ko: '예금주 성명', en: 'Account Holder Name', ja: '口座名義', zh: '开户人姓名', vi: 'Tên chủ tài khoản', es: 'Titular de la Cuenta'),
                    hint: LocalizationService.pick(ko: '예: 홍길동', en: 'e.g., MindFit Studio LLC', ja: '例: サトウ ミサキ', zh: '例: 李明', vi: 'VD: Nguyễn Minh', es: 'Ej: MindFit Studio SL'),
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      LocalizationService.pick(
                        ko: '비대면 카드결제 링크 사용 (0원 연동)',
                        en: 'Enable Online Card Checkout Link',
                        ja: 'オンラインカード決済リンクを使用',
                        zh: '启用远程信用卡支付链接',
                        vi: 'Bật liên kết thanh toán thẻ từ xa',
                        es: 'Usar Enlace de Pago con Tarjeta',
                      ),
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    subtitle: Text(
                      LocalizationService.supportsTossTransfer
                          ? LocalizationService.pick(
                              ko: '토스페이먼츠/페이앱 등 원격 결제 URL 연동',
                              en: 'Attach your Stripe, PayPal, or PG checkout URL to invoices',
                              ja: 'Stripe・PayPal・Square等の決済URLを請求書に添付',
                              zh: '在账单中附带 Stripe、PayPal 等在线支付链接',
                              vi: 'Đính kèm link Stripe, PayPal, MoMo vào hóa đơn',
                              es: 'Adjunta enlaces de Stripe, PayPal o Square',
                            )
                          : LocalizationService.currentCurrency.paymentChannels.join(' · '),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
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
                      label: LocalizationService.pick(
                        ko: '비대면 카드결제 URL ({금액} 자동치환 지원)',
                        en: 'Card Checkout URL (Supports {금액} placeholder)',
                        ja: 'オンライン決済URL ({금액} 自動挿入対応)',
                        zh: '在线支付链接 (支持 {금액} 自动替换)',
                        vi: 'URL thanh toán thẻ (Hỗ trợ biến {금액})',
                        es: 'URL de Pago con Tarjeta (Soporta {금액})',
                      ),
                      hint: LocalizationService.supportsTossTransfer ? 'https://pay.toss.im/_m/...' : 'https://buy.stripe.com/... or https://paypal.me/...',
                      prefixIcon: Icons.link_rounded,
                      keyboardType: TextInputType.url,
                    ),
                  ],
                ],
              ),
              footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              footer: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () async {
                    final finalCat = selectedCategory == '기타 / 맞춤업종' && customCategoryCtrl.text.trim().isNotEmpty
                        ? customCategoryCtrl.text.trim()
                        : selectedCategory;
                    final finalRole = isCustomRole
                        ? (customRoleCtrl.text.trim().isEmpty ? LocalizationService.termOptionLabel('대표') : customRoleCtrl.text.trim())
                        : LocalizationService.termOptionLabel(selectedRole);
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
                        SnackBar(content: Text(LocalizationService.pick(
                          ko: '스튜디오 프로필 및 카테고리가 저장되었습니다.',
                          en: 'Studio profile & settings saved.',
                          ja: 'スタジオプロフィールを保存しました。',
                          zh: '门店资料与分类设置已保存。',
                          vi: 'Đã lưu hồ sơ trung tâm.',
                          es: 'Perfil y configuración guardados.',
                        ))),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(LocalizationService.tr('btn_save'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
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
        return StickyBottomSheetLayout(
          bodyPadding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 16),
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
                        ko: '비대면 카드결제 링크 설정',
                        en: 'Set Online Card Payment Link',
                        ja: 'オンラインカード決済リンク設定',
                        zh: '配置在线信用卡支付链接',
                        vi: 'Cài đặt link thanh toán thẻ',
                        es: 'Configurar Enlace de Tarjeta',
                      ),
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      softWrap: true,
                    ),
                  ),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                LocalizationService.supportsTossTransfer && LocalizationService.currentLanguage == AppLanguage.korean
                    ? '토스페이먼츠(페이링크), 페이앱(결제선생), 카카오페이 등 비대면 결제 URL을 등록하세요.'
                    : LocalizationService.pick(
                        ko: '사용 중인 PG/간편결제 링크(Stripe, PayPal, PayApp 등)를 등록하세요.',
                        en: 'Enter your Stripe Payment Link, Square, PayPal.me, or online checkout URL.',
                        ja: 'Stripe・PayPal・Square・PayPay等の決済リンクURLを入力してください。',
                        zh: '请输入您的 Stripe、PayPal 或其它在线支付页面链接。',
                        vi: 'Nhập URL thanh toán (Stripe, PayPal, MoMo...) của bạn.',
                        es: 'Ingresa tu URL de pago (Stripe, PayPal, Square...).',
                      ),
                style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: urlCtrl,
                label: LocalizationService.pick(
                  ko: '카드결제 링크 (URL)',
                  en: 'Card Payment URL',
                  ja: 'カード決済URL',
                  zh: '支付链接 (URL)',
                  vi: 'Liên kết thanh toán (URL)',
                  es: 'Enlace de Pago (URL)',
                ),
                hint: LocalizationService.supportsTossTransfer
                    ? 'https://pay.toss.im/_m/... 또는 https://payapp.kr/L/...'
                    : 'https://buy.stripe.com/... or https://paypal.me/...',
                prefixIcon: Icons.link_rounded,
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: Text(
                      LocalizationService.pick(
                        ko: '{금액}',
                        en: '{amount}',
                        ja: '{金額}',
                        zh: '{金额}',
                        vi: '{số_tiền}',
                        es: '{importe}',
                      ),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                    ),
                    backgroundColor: const Color(0xFFEFF6FF),
                    onPressed: () {
                      urlCtrl.text = '${urlCtrl.text}{금액}';
                    },
                  ),
                  ActionChip(
                    label: Text(
                      LocalizationService.pick(
                        ko: '{회원명}',
                        en: '{name}',
                        ja: '{会員名}',
                        zh: '{姓名}',
                        vi: '{tên}',
                        es: '{nombre}',
                      ),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                    ),
                    backgroundColor: const Color(0xFFEFF6FF),
                    onPressed: () {
                      urlCtrl.text = '${urlCtrl.text}{회원명}';
                    },
                  ),
                  ActionChip(
                    label: Text(
                      LocalizationService.pick(
                        ko: '{상품명}',
                        en: '{title}',
                        ja: '{商品名}',
                        zh: '{项目名}',
                        vi: '{mục}',
                        es: '{concepto}',
                      ),
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                    ),
                    backgroundColor: const Color(0xFFEFF6FF),
                    onPressed: () {
                      urlCtrl.text = '${urlCtrl.text}{상품명}';
                    },
                  ),
                ],
              ),
            ],
          ),
          footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          footer: SizedBox(
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
                    SnackBar(content: Text(LocalizationService.pick(
                      ko: '카드결제 링크가 저장되었습니다.',
                      en: 'Card payment link saved.',
                      ja: 'カード決済リンクを保存しました。',
                      zh: '支付链接已保存。',
                      vi: 'Đã lưu liên kết thanh toán.',
                      es: 'Enlace de pago guardado.',
                    ))),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(LocalizationService.tr('btn_save'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
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
        return StickyBottomSheetLayout(
          bodyPadding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 16),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    LocalizationService.pick(
                      ko: '백업 데이터 복원하기',
                      en: 'Restore Backup Data',
                      ja: 'バックアップデータの復元',
                      zh: '还原备份数据',
                      vi: 'Khôi phục dữ liệu sao lưu',
                      es: 'Restaurar Copia de Seguridad',
                    ),
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                LocalizationService.pick(
                  ko: '카카오톡이나 메일로 내보냈던 백업 파일(.json)의 내용을 전체 복사하여 아래에 붙여넣어 주세요.',
                  en: 'Copy the entire contents of your exported .json backup file and paste it below.',
                  ja: 'エクスポートしたバックアップ(.json)の内容をすべてコピーし、下に貼り付けてください。',
                  zh: '请完整复制之前导出的 .json 备份文件内容并粘贴到下方。',
                  vi: 'Sao chép toàn bộ nội dung tệp sao lưu .json đã xuất và dán vào bên dưới.',
                  es: 'Copia todo el contenido de tu archivo de copia .json y pégalo abajo.',
                ),
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: jsonController,
                label: LocalizationService.pick(
                  ko: '백업 JSON 내용 붙여넣기',
                  en: 'Paste Backup JSON',
                  ja: 'バックアップJSONを貼り付け',
                  zh: '粘贴备份 JSON 内容',
                  vi: 'Dán nội dung JSON sao lưu',
                  es: 'Pega el JSON aquí',
                ),
                hint: '{\n  "version": "1.0.0",\n  "members": [...]\n}',
                maxLines: 10,
              ),
            ],
          ),
          footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          footer: SizedBox(
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
                      SnackBar(
                        content: Text(LocalizationService.pick(
                          ko: '백업 데이터가 복원되었습니다.',
                          en: 'Backup restored successfully.',
                          ja: 'バックアップデータを復元しました。',
                          zh: '备份数据已成功还原。',
                          vi: 'Đã khôi phục dữ liệu thành công.',
                          es: 'Copia restaurada correctamente.',
                        )),
                        backgroundColor: AppTheme.softMint,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(LocalizationService.pick(
                          ko: '올바르지 않은 백업 데이터 형식이거나 복원에 실패했습니다.',
                          en: 'Invalid backup format or restore failed.',
                          ja: '無効なバックアップ形式か、復元に失敗しました。',
                          zh: '备份格式无效或还原失败。',
                          vi: 'Định dạng không hợp lệ hoặc khôi phục thất bại.',
                          es: 'Formato inválido o error al restaurar.',
                        )),
                        backgroundColor: AppTheme.danger,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.restore, color: Colors.white),
              label: Text(
                LocalizationService.pick(
                  ko: '지금 바로 데이터 복원하기',
                  en: 'Restore Data Now',
                  ja: '今すぐデータを復元',
                  zh: '立即还原数据',
                  vi: 'Khôi phục ngay bây giờ',
                  es: 'Restaurar Datos Ahora',
                ),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
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
            final previewBank = bankController.text.trim().isEmpty
                ? LocalizationService.currentCurrency.defaultBankName
                : bankController.text.trim();
            final previewAccount = accountController.text.trim().isEmpty ? '1000-2026-8899' : accountController.text.trim();
            final previewHolder = holderController.text.trim().isEmpty ? profile.studioName : holderController.text.trim();
            final previewStudio = studioNameController.text.trim().isEmpty ? profile.studioName : studioNameController.text.trim();
            final previewInstructor = instructorController.text.trim().isEmpty ? profile.instructorName : instructorController.text.trim();
            final cleanAccOnly = previewAccount.replaceAll(RegExp(r'[^0-9]'), '');
            final previewCopyAcc = '$previewBank $previewAccount $previewHolder';
            final sampleAmtNum = LocalizationService.currentCurrency.sampleAmount.toInt();
            final previewAmount = LocalizationService.formatAmount(sampleAmtNum);
            final previewToss = LocalizationService.supportsTossTransfer
                ? 'supertoss://send?bank=${Uri.encodeComponent(previewBank)}&account=$cleanAccOnly&amount=$sampleAmtNum'
                : '${LocalizationService.currentCurrency.paymentChannels.first}: $previewBank $previewAccount';
            final previewCard = profile.cardPaymentEnabled && profile.cardPaymentUrl.isNotEmpty
                ? profile.getFormattedCardPaymentUrl(
                    amount: sampleAmtNum,
                    orderTitle: profile.feeWord,
                    customerName: LocalizationService.pick(ko: '김민준', en: 'Alex Kim', ja: '佐藤健太', zh: '张明', vi: 'Minh', es: 'Carlos'),
                  )
                : 'https://pay.example.com/checkout';
            final sampleMemberName = LocalizationService.pick(ko: '김민준', en: 'Alex Kim', ja: '佐藤健太', zh: '张明', vi: 'Minh', es: 'Carlos');
            final sampleInvoiceTitle = LocalizationService.pick(
              ko: '9월 정기 ${profile.feeWord}',
              en: 'Monthly ${profile.feeWord}',
              ja: '今月分 ${profile.feeWord}',
              zh: '本月${profile.feeWord}',
              vi: '${profile.feeWord} hàng tháng',
              es: '${profile.feeWord} Mensual',
            );

            String previewText = textController.text
                .replaceAll('#{상호명}', previewStudio)
                .replaceAll('#{담당자}', previewInstructor)
                .replaceAll('#{대표자}', previewInstructor)
                .replaceAll('#{강사명}', previewInstructor)
                .replaceAll('#{직함}', profile.roleTitle)
                .replaceAll('#{고객호칭}', profile.memberWord)
                .replaceAll('#{비용호칭}', profile.feeWord)
                .replaceAll('#{장소호칭}', profile.placeTitle)
                .replaceAll('#{회원명}', sampleMemberName)
                .replaceAll('#{계좌정보}', '$previewBank $previewAccount ($previewHolder)')
                .replaceAll('#{계좌복사용}', previewCopyAcc)
                .replaceAll('#{토스송금링크}', previewToss)
                .replaceAll('#{카드결제링크}', previewCard)
                .replaceAll('{카드결제링크}', previewCard)
                .replaceAll('#{금액}원', previewAmount)
                .replaceAll('#{금액}', previewAmount)
                .replaceAll('#{청구제목}', sampleInvoiceTitle)
                .replaceAll('#{안내내용}', sampleInvoiceTitle)
                .replaceAll('#{납부기한}', LocalizationService.formatDate(DateTime.now().add(const Duration(days: 7))))
                .replaceAll('#{출석시간}', '14:30')
                .replaceAll('#{잔여회차}', LocalizationService.pick(ko: '• 잔여 회차 : 9회', en: '• Remaining: 9 sessions', ja: '• 残り回数: 9回', zh: '• 剩余课时: 9次', vi: '• Còn lại: 9 buổi', es: '• Restantes: 9 sesiones'));

            return StickyBottomSheetLayout(
              bodyPadding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              body: Column(
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
                      label: Text(
                        LocalizationService.pick(
                          ko: '권장 서식 초기화',
                          en: 'Reset to Default',
                          ja: '推奨テンプレートに戻す',
                          zh: '恢复默认模板',
                          vi: 'Khôi phục mặc định',
                          es: 'Restaurar Predeterminada',
                        ),
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    LocalizationService.pick(
                      ko: '필수 변수(상호명, 담당자, 계좌 등)를 수정하면 문자에 즉시 반영됩니다.',
                      en: 'Updates to your studio name, contact, or account details reflect instantly in the message preview.',
                      ja: '屋号・担当者・口座情報を変更すると下のプレビューに即反映されます。',
                      zh: '修改商号、负责人或收款账户后将立即同步至下方预览文案。',
                      vi: 'Thay đổi tên trung tâm, người phụ trách hoặc tài khoản sẽ cập nhật ngay.',
                      es: 'Al editar nombre, contacto o cuenta, la vista previa se actualiza al instante.',
                    ),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
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
                        Row(
                          children: [
                            const Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryBlue),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                LocalizationService.pick(
                                  ko: '문자에 삽입되는 필수 기본 정보',
                                  en: 'Business Info Used in Messages',
                                  ja: 'メッセージに挿入される基本情報',
                                  zh: '自动填充到短信中的基本信息',
                                  vi: 'Thông tin cơ bản chèn vào tin nhắn',
                                  es: 'Datos Básicos en Mensajes',
                                ),
                                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: studioNameController,
                          label: '${LocalizationService.pick(ko: '사업장 상호/브랜드명', en: 'Business Name', ja: '屋号・スタジオ名', zh: '商号 / 品牌名', vi: 'Tên cơ sở', es: 'Nombre del Negocio')} (#{상호명})',
                          hint: LocalizationService.pick(ko: '예: 체크앤페이 스튜디오 / 학원 / 공방', en: 'e.g., MindFit Academy', ja: '例: マインドフィットスタジオ', zh: '例: 星光音乐教室', vi: 'VD: Trung tâm MindFit', es: 'Ej: Academia MindFit'),
                          prefixIcon: Icons.storefront_outlined,
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: instructorController,
                          label: '${LocalizationService.pick(ko: '담당자 성명', en: 'Contact Name', ja: '担当者名', zh: '负责人姓名', vi: 'Người phụ trách', es: 'Responsable')} (#{담당자})',
                          hint: LocalizationService.pick(ko: '예: 홍길동', en: 'e.g., Sarah Kim', ja: '例: 佐藤 美咲', zh: '例: 李老师', vi: 'VD: Nguyễn Minh', es: 'Ej: Carlos'),
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
                                    label: '${LocalizationService.pick(ko: '입금 은행', en: 'Bank / App', ja: '振込銀行', zh: '收款银行', vi: 'Ngân hàng', es: 'Banco')} (#{계좌정보})',
                                    hint: LocalizationService.currentCurrency.defaultBankName,
                                    prefixIcon: Icons.account_balance_outlined,
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                  const SizedBox(height: 12),
                                  AppTextField(
                                    controller: holderController,
                                    label: LocalizationService.pick(ko: '예금주 성명', en: 'Account Holder', ja: '口座名義', zh: '户名', vi: 'Chủ tài khoản', es: 'Titular'),
                                    hint: profile.studioName,
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
                                    label: '${LocalizationService.pick(ko: '입금 은행', en: 'Bank / App', ja: '振込銀行', zh: '收款银行', vi: 'Ngân hàng', es: 'Banco')} (#{계좌정보})',
                                    hint: LocalizationService.currentCurrency.defaultBankName,
                                    prefixIcon: Icons.account_balance_outlined,
                                    onChanged: (_) => setModalState(() {}),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: AppTextField(
                                    controller: holderController,
                                    label: LocalizationService.pick(ko: '예금주 성명', en: 'Account Holder', ja: '口座名義', zh: '户名', vi: 'Chủ tài khoản', es: 'Titular'),
                                    hint: profile.studioName,
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
                          label: LocalizationService.pick(ko: '입금 계좌번호', en: 'Account / IBAN / Handle', ja: '口座番号', zh: '收款账号', vi: 'Số tài khoản', es: 'Cuenta / IBAN'),
                          hint: '1000-2026-8899',
                          prefixIcon: Icons.credit_card_outlined,
                          keyboardType: TextInputType.text,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Template Editor with Placeholders Chips
                  Text(
                    LocalizationService.pick(
                      ko: '문자 서식 양식 편집',
                      en: 'Edit Message Template',
                      ja: 'メッセージ書式の編集',
                      zh: '编辑消息模板正文',
                      vi: 'Chỉnh sửa mẫu tin nhắn',
                      es: 'Editar Plantilla del Mensaje',
                    ),
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
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
                    label: LocalizationService.pick(
                      ko: '문자 본문 (치환 태그 클릭 시 본문에 추가됩니다)',
                      en: 'Message Body (Tap tags above to insert)',
                      ja: 'メッセージ本文（上のタグで自動挿入）',
                      zh: '短信正文（点击上方标签自动插入变量）',
                      vi: 'Nội dung tin nhắn (Chạm thẻ trên để chèn)',
                      es: 'Cuerpo del mensaje (Toca etiquetas para insertar)',
                    ),
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
                        Row(
                          children: [
                            const Icon(Icons.visibility_outlined, size: 14, color: AppTheme.softMint),
                            const SizedBox(width: 6),
                            Text(
                              LocalizationService.pick(
                                ko: '실제 발송 문자 미리보기',
                                en: 'Live Sent Message Preview',
                                ja: '送信メッセージ プレビュー',
                                zh: '实际发送内容预览',
                                vi: 'Xem trước tin nhắn sẽ gửi',
                                es: 'Vista Previa del Envío',
                              ),
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
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
                ],
              ),
              footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              footer: SizedBox(
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
                      SnackBar(content: Text(LocalizationService.pick(
                        ko: '문자 서식 및 상호/계좌 정보가 안전하게 저장되었습니다.',
                        en: 'Template & studio details saved safely.',
                        ja: 'メッセージ書式と基本情報を保存しました。',
                        zh: '消息模板及收款信息已安全保存。',
                        vi: 'Đã lưu mẫu tin nhắn và thông tin tài khoản.',
                        es: 'Plantilla y datos guardados correctamente.',
                      ))),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: Text(
                    LocalizationService.pick(
                      ko: '서식 & 정보 함께 저장하기',
                      en: 'Save Template & Details',
                      ja: '書式と基本情報を保存',
                      zh: '保存模板与基本信息',
                      vi: 'Lưu mẫu & thông tin',
                      es: 'Guardar Plantilla y Datos',
                    ),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
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
        _buildSectionTitle(
          LocalizationService.pick(
            ko: '업종별 맞춤 카테고리 및 청구 서식 관리',
            en: 'Groups & Billing Templates',
            ja: 'クラス分類・請求書式管理',
            zh: '行业分组与账单模板管理',
            vi: 'Quản lý nhóm & mẫu hóa đơn',
            es: 'Grupos y Plantillas de Cobro',
          ),
          icon: Icons.category_rounded,
        ),
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
                          LocalizationService.pick(
                            ko: '어떤 업종이든 100% 맞춤형! 등록 그룹과 청구서 항목을 사업장 특성에 맞게 자유롭게 편집하세요.',
                            en: 'Customize your class groups, member registration presets & billing items for your studio.',
                            ja: '業種に合わせてクラスグループ・会員登録雛形・請求項目を自由に編集できます。',
                            zh: '自由定制适合您门店的课程分组、快速录入会模板及常用账单条目。',
                            vi: 'Tùy chỉnh nhóm lớp, mẫu đăng ký và hạng mục thu phí phù hợp với trung tâm.',
                            es: 'Personaliza grupos, plantillas de alta y conceptos de cobro para tu negocio.',
                          ),
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
                  title: Text(
                    LocalizationService.pick(
                      ko: '수업 / 반 그룹 카테고리 관리',
                      en: 'Manage Class / Group Categories',
                      ja: 'クラス・コース分類管理',
                      zh: '课程 / 班级分组管理',
                      vi: 'Quản lý nhóm lớp học',
                      es: 'Gestionar Grupos y Clases',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    LocalizationService.pick(
                      ko: '등록된 그룹 ${categoryState.groupCategories.length}개 (${categoryState.groupCategories.take(3).map(LocalizationService.localizeBuiltInLabel).join(', ')}${categoryState.groupCategories.length > 3 ? ' 외' : ''})',
                      en: '${categoryState.groupCategories.length} groups (${categoryState.groupCategories.take(3).map(LocalizationService.localizeBuiltInLabel).join(', ')}${categoryState.groupCategories.length > 3 ? '...' : ''})',
                      ja: '${categoryState.groupCategories.length}件 (${categoryState.groupCategories.take(3).map(LocalizationService.localizeBuiltInLabel).join(', ')}${categoryState.groupCategories.length > 3 ? ' 他' : ''})',
                      zh: '共 ${categoryState.groupCategories.length} 个分组 (${categoryState.groupCategories.take(3).map(LocalizationService.localizeBuiltInLabel).join(', ')}${categoryState.groupCategories.length > 3 ? ' 等' : ''})',
                      vi: '${categoryState.groupCategories.length} nhóm (${categoryState.groupCategories.take(3).map(LocalizationService.localizeBuiltInLabel).join(', ')}${categoryState.groupCategories.length > 3 ? '...' : ''})',
                      es: '${categoryState.groupCategories.length} grupos (${categoryState.groupCategories.take(3).map(LocalizationService.localizeBuiltInLabel).join(', ')}${categoryState.groupCategories.length > 3 ? '...' : ''})',
                    ),
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
                  title: Text(
                    LocalizationService.pick(
                      ko: '학생 등록 간편 템플릿 관리',
                      en: 'Quick Member Registration Presets',
                      ja: '会員クイック登録テンプレート',
                      zh: '会员快速录入模板管理',
                      vi: 'Mẫu đăng ký hội viên nhanh',
                      es: 'Plantillas de Alta Rápida',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    LocalizationService.pick(
                      ko: '등록된 템플릿 ${categoryState.memberTemplates.length}개 (선택 시 그룹·금액·회차 원터치 채움)',
                      en: '${categoryState.memberTemplates.length} presets (1-tap fill for group, fee & sessions)',
                      ja: '${categoryState.memberTemplates.length}件 (選択でグループ・料金・回数を自動入力)',
                      zh: '共 ${categoryState.memberTemplates.length} 个模板 (一键填充班级、金额与次数)',
                      vi: '${categoryState.memberTemplates.length} mẫu (Điền 1 chạm nhóm, phí & số buổi)',
                      es: '${categoryState.memberTemplates.length} plantillas (Relleno rápido de grupo y tarifa)',
                    ),
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
                  title: Text(
                    LocalizationService.pick(
                      ko: '청구 항목 및 금액 템플릿 관리',
                      en: 'Invoice Item & Fee Templates',
                      ja: '請求項目・単価テンプレート管理',
                      zh: '账单项目与收费模板管理',
                      vi: 'Quản lý hạng mục & mức phí',
                      es: 'Plantillas de Conceptos e Importes',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    LocalizationService.pick(
                      ko: '등록된 항목 ${categoryState.invoiceTemplates.length}개 (정규수강료, 교재비, 재등록 등)',
                      en: '${categoryState.invoiceTemplates.length} items (Monthly tuition, books, packages, etc.)',
                      ja: '${categoryState.invoiceTemplates.length}件 (月謝・教材費・回数券更新など)',
                      zh: '共 ${categoryState.invoiceTemplates.length} 项 (月费、教材费、续费套餐等)',
                      vi: '${categoryState.invoiceTemplates.length} mục (Học phí, tài liệu, gói gia hạn...)',
                      es: '${categoryState.invoiceTemplates.length} conceptos (Mensualidad, material, bonos...)',
                    ),
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
                  title: Text(
                    LocalizationService.pick(
                      ko: '원터치 업종별 프리셋 불러오기',
                      en: 'Load Industry Preset Pack',
                      ja: 'ワンタッチ業種プリセット読込',
                      zh: '一键载入行业标准模板',
                      vi: 'Tải bộ mẫu theo ngành nghề',
                      es: 'Cargar Preajuste por Sector',
                    ),
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.textPrimary),
                  ),
                  subtitle: Text(
                    LocalizationService.pick(
                      ko: '학원, 피트니스, 필라테스, 태권도, 음악/공방 템플릿으로 원클릭 초기화',
                      en: 'One-tap reset to Academy, Fitness, Pilates, Martial Arts or Studio defaults',
                      ja: '学習塾・ジム・ピラティス・道場・教室用テンプレートをワンクリック読込',
                      zh: '一键重置为培训班、健身私教、普拉提、武馆或艺术工作室默认包',
                      vi: 'Khởi tạo nhanh cho Trung tâm, Gym, Pilates, Võ thuật hoặc Âm nhạc',
                      es: 'Carga plantillas listas para Academia, Fitness, Pilates o Arte',
                    ),
                    style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.35),
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
                  _buildSheetHeader(
                    ctx,
                    LocalizationService.pick(
                      ko: '수업 / 반 그룹 카테고리 관리',
                      en: 'Manage Class / Group Categories',
                      ja: 'クラス・コース分類管理',
                      zh: '课程 / 班级分组管理',
                      vi: 'Quản lý nhóm lớp học',
                      es: 'Gestionar Grupos y Clases',
                    ),
                    Icons.groups_outlined,
                    AppTheme.primaryBlue,
                  ),
                  Text(
                    LocalizationService.pick(
                      ko: '매장/업종에 맞게 그룹을 새로 추가하거나, 그룹을 눌러 이름 수정 및 삭제를 할 수 있습니다.',
                      en: 'Add custom class groups below, or tap any existing chip to rename or remove it.',
                      ja: 'クラスを新しく追加したり、既存のチップをタップして名称変更・削除ができます。',
                      zh: '添加新分组，或点击下方现有标签进行重命名与删除。',
                      vi: 'Thêm nhóm mới bên dưới hoặc chạm vào thẻ hiện có để đổi tên/xóa.',
                      es: 'Añade nuevos grupos o toca cualquiera existente para renombrarlo o eliminarlo.',
                    ),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  // Add new group row
                  Row(
                    children: [
                      Expanded(
                        child: AppTextField(
                          controller: textController,
                          label: LocalizationService.pick(ko: '새 그룹 이름', en: 'New Group Name', ja: '新しいグループ名', zh: '新分组名称', vi: 'Tên nhóm mới', es: 'Nuevo Grupo'),
                          hint: LocalizationService.pick(ko: '예: 고등 내신반, 1:1 기구필라', en: 'e.g., Varsity Class, 1:1 Reformer', ja: '例: ジュニア上級, パーソナル', zh: '例: 提高班, 一对一私教', vi: 'VD: Lớp nâng cao, Tập 1:1', es: 'Ej: Nivel Avanzado, 1:1 Reformer'),
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
                                  SnackBar(
                                    content: Text(LocalizationService.pick(
                                      ko: '\'$name\' 그룹이 추가되었습니다.',
                                      en: 'Added group \'$name\'.',
                                      ja: '「$name」を追加しました。',
                                      zh: '已添加分组「$name」。',
                                      vi: 'Đã thêm nhóm \'$name\'.',
                                      es: 'Grupo \'$name\' añadido.',
                                    )),
                                    duration: const Duration(seconds: 1),
                                  ),
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
                          child: Text(
                            LocalizationService.pick(ko: '추가', en: 'Add', ja: '追加', zh: '添加', vi: 'Thêm', es: 'Añadir'),
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  Text(
                    LocalizationService.pick(
                      ko: '현재 등록된 그룹 (${catState.groupCategories.length}개 · 터치하면 이름 수정)',
                      en: 'Active Groups (${catState.groupCategories.length} · Tap to rename)',
                      ja: '登録済みグループ (${catState.groupCategories.length}件 · タップで編集)',
                      zh: '当前分组 (${catState.groupCategories.length}个 · 点击可改名)',
                      vi: 'Nhóm hiện có (${catState.groupCategories.length} · Chạm để đổi tên)',
                      es: 'Grupos activos (${catState.groupCategories.length} · Toca para editar)',
                    ),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 10),

                  if (catState.groupCategories.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      alignment: Alignment.center,
                      child: Text(
                        LocalizationService.pick(
                          ko: '등록된 그룹이 없습니다. 상단에서 추가해보세요.',
                          en: 'No groups registered yet. Add one above.',
                          ja: 'グループがありません。上から追加してください。',
                          zh: '暂无分组，请在上方输入名称添加。',
                          vi: 'Chưa có nhóm nào. Hãy thêm ở trên.',
                          es: 'Sin grupos aún. Añade uno arriba.',
                        ),
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: catState.groupCategories.map((group) {
                        return InputChip(
                          backgroundColor: const Color(0xFFF1F5F9),
                          avatar: const Icon(Icons.edit_outlined, size: 15, color: AppTheme.primaryBlue),
                          label: Text(LocalizationService.localizeBuiltInLabel(group), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                          onPressed: () => _openRenameGroupDialog(context, group),
                          deleteIcon: const Icon(Icons.close_rounded, size: 16, color: Color(0xFF94A3B8)),
                          onDeleted: () async {
                            await ref.read(customCategoryProvider.notifier).removeGroupCategory(group);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(LocalizationService.pick(
                                    ko: '\'$group\' 그룹이 삭제되었습니다.',
                                    en: 'Deleted group \'$group\'.',
                                    ja: '「$group」を削除しました。',
                                    zh: '已删除分组「$group」。',
                                    vi: 'Đã xóa nhóm \'$group\'.',
                                    es: 'Grupo \'$group\' eliminado.',
                                  )),
                                  duration: const Duration(seconds: 1),
                                ),
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

  void _openRenameGroupDialog(BuildContext context, String oldName) {
    final renameCtrl = TextEditingController(text: oldName);
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          LocalizationService.pick(ko: '그룹 이름 수정', en: 'Rename Group', ja: 'グループ名変更', zh: '修改分组名称', vi: 'Đổi tên nhóm', es: 'Renombrar Grupo'),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
        ),
        content: AppTextField(
          controller: renameCtrl,
          label: LocalizationService.pick(ko: '변경할 그룹 이름', en: 'New Group Name', ja: '新しい名称', zh: '新分组名称', vi: 'Tên nhóm mới', es: 'Nuevo Nombre'),
          hint: LocalizationService.pick(ko: '예: 심화 클래스', en: 'e.g., Honors Class', ja: '例: 上級クラス', zh: '例: 进阶班', vi: 'VD: Lớp nâng cao', es: 'Ej: Clase Avanzada'),
          prefixIcon: Icons.edit_outlined,
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
              label: LocalizationService.tr('btn_save'),
              size: ZeroButtonSize.medium,
              fullWidth: true,
              onPressed: () async {
                final newName = renameCtrl.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LocalizationService.pick(
                    ko: '그룹 이름을 입력해주세요.',
                    en: 'Please enter a group name.',
                    ja: 'グループ名を入力してください。',
                    zh: '请输入分组名称。',
                    vi: 'Vui lòng nhập tên nhóm.',
                    es: 'Ingresa el nombre del grupo.',
                  ))));
                  return;
                }
                final groupItemLabel = LocalizationService.pick(ko: '그룹 이름', en: 'Group', ja: 'グループ', zh: '分组名称', vi: 'Nhóm', es: 'Grupo');
                if (!await MonetizationService.instance.ensureEditAllowed(dlgContext, itemLabel: groupItemLabel)) {
                  return;
                }
                await ref.read(customCategoryProvider.notifier).renameGroupCategory(oldName, newName);
                await MonetizationService.instance.recordEditUsage();
                if (dlgContext.mounted) Navigator.pop(dlgContext);
                if (context.mounted && newName != oldName) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('\'$oldName\' → \'$newName\''), duration: const Duration(seconds: 1)),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  void _openMemberTemplateManager(BuildContext context) {
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final catState = ref.watch(customCategoryProvider).value ??
                CustomCategoryState.getDefaultsForIndustry('입시 / 보습학원');

            return StickyBottomSheetLayout(
              bodyPadding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetHeader(
                    ctx,
                    LocalizationService.pick(
                      ko: '회원 등록 간편 템플릿',
                      en: 'Member Quick Registration Presets',
                      ja: '会員クイック登録テンプレート',
                      zh: '会员快速录入模板',
                      vi: 'Mẫu đăng ký hội viên nhanh',
                      es: 'Plantillas de Alta Rápida',
                    ),
                    Icons.playlist_add_check_rounded,
                    AppTheme.softMint,
                  ),
                  Text(
                    LocalizationService.pick(
                      ko: '업종에 맞게 회원 등록 템플릿을 새로 만들거나 기존 템플릿을 눌러 금액·회차·유형을 수정·삭제할 수 있습니다.',
                      en: 'Tap any preset to edit pricing, billing mode & default session count, or add a new one.',
                      ja: 'テンプレートをタップして金額・回数・月謝設定を変更したり、新規作成できます。',
                      zh: '点击已有模板修改默认金额、课时和计费方式，或新增自定义模板。',
                      vi: 'Chạm mẫu bất kỳ để sửa mức phí, số buổi hoặc thêm mẫu mới.',
                      es: 'Toca una plantilla para editar tarifa, sesiones o añadir una nueva.',
                    ),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  if (catState.memberTemplates.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        LocalizationService.pick(
                          ko: '등록된 템플릿이 없습니다. 상단 버튼으로 새 템플릿을 만들어보세요.',
                          en: 'No member presets yet. Add one below.',
                          ja: 'テンプレートがありません。下のボタンから作成できます。',
                          zh: '暂无会员模板，点击下方按钮添加。',
                          vi: 'Chưa có mẫu nào. Nhấn nút bên dưới để tạo.',
                          es: 'Sin plantillas aún. Crea una abajo.',
                        ),
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    ...catState.memberTemplates.map((template) {
                      final isSession = template.billingType == BillingType.sessionBased;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openAddMemberTemplateDialog(context, catState, existing: template),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
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
                                        '${LocalizationService.localizeBuiltInLabel(template.groupName)} · ${isSession ? LocalizationService.pick(ko: '회차형 (${template.defaultSessions}회)', en: '${template.defaultSessions} Sessions', ja: '回数券 (${template.defaultSessions}回)', zh: '次卡 (${template.defaultSessions}次)', vi: 'Theo buổi (${template.defaultSessions})', es: 'Bono (${template.defaultSessions})') : LocalizationService.pick(ko: '정기월납', en: 'Monthly', ja: '月謝制', zh: '按月收费', vi: 'Hàng tháng', es: 'Mensual')} · ${LocalizationService.formatAmount(template.defaultFee)}',
                                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue, size: 20),
                                  tooltip: LocalizationService.pick(ko: '템플릿 수정', en: 'Edit', ja: '編集', zh: '编辑', vi: 'Sửa', es: 'Editar'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _openAddMemberTemplateDialog(context, catState, existing: template),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 20),
                                  tooltip: LocalizationService.pick(ko: '템플릿 삭제', en: 'Delete', ja: '削除', zh: '删除', vi: 'Xóa', es: 'Eliminar'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    await ref.read(customCategoryProvider.notifier).removeMemberTemplate(template.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(LocalizationService.pick(
                                            ko: '\'${template.label}\' 템플릿이 삭제되었습니다.',
                                            en: 'Deleted \'${template.label}\'.',
                                            ja: '「${template.label}」を削除しました。',
                                            zh: '已删除模板「${template.label}」。',
                                            vi: 'Đã xóa \'${template.label}\'.',
                                            es: 'Eliminada \'${template.label}\'.',
                                          )),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
              footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              footer: ZeroButton.primary(
                label: LocalizationService.pick(
                  ko: '새 등록 템플릿 추가하기',
                  en: 'Add New Member Preset',
                  ja: '新しい会員テンプレートを追加',
                  zh: '添加新会员录入模板',
                  vi: 'Thêm mẫu đăng ký mới',
                  es: 'Añadir Nueva Plantilla',
                ),
                icon: Icons.add_rounded,
                size: ZeroButtonSize.medium,
                fullWidth: true,
                onPressed: () => _openAddMemberTemplateDialog(context, catState),
              ),
            );
          },
        );
      },
    );
  }

  void _openAddMemberTemplateDialog(
    BuildContext context,
    CustomCategoryState catState, {
    MemberCategoryTemplate? existing,
  }) {
    final isEdit = existing != null;
    final labelCtrl = TextEditingController(text: existing?.label ?? '');
    final groupCtrl = TextEditingController(
      text: existing?.groupName ?? (catState.groupCategories.isNotEmpty ? catState.groupCategories.first : LocalizationService.localizeBuiltInLabel('일반')),
    );
    final feeCtrl = TextEditingController(
      text: (existing?.defaultFee ?? LocalizationService.currentCurrency.sampleAmount.toInt()).toString(),
    );
    final sessionsCtrl = TextEditingController(
      text: ((existing?.defaultSessions ?? 0) > 0 ? existing!.defaultSessions : 10).toString(),
    );
    BillingType billingType = existing?.billingType ?? BillingType.monthlyRecurring;

    showDialog(
      context: context,
      builder: (dlgContext) {
        return StatefulBuilder(
          builder: (context, setDlgState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Text(
                isEdit
                    ? LocalizationService.pick(ko: '등록 템플릿 수정', en: 'Edit Preset', ja: 'テンプレート編集', zh: '编辑录入模板', vi: 'Sửa mẫu đăng ký', es: 'Editar Plantilla')
                    : LocalizationService.pick(ko: '새 회원 등록 템플릿', en: 'New Member Preset', ja: '新規会員テンプレート', zh: '新建会员模板', vi: 'Tạo mẫu hội viên mới', es: 'Nueva Plantilla'),
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppTextField(
                      controller: labelCtrl,
                      label: LocalizationService.pick(ko: '템플릿 표시 이름', en: 'Preset Name', ja: '表示名', zh: '模板显示名称', vi: 'Tên mẫu', es: 'Nombre de la Plantilla'),
                      hint: LocalizationService.pick(ko: '예: 중등 수학 정규반, 1:1 PT 10회', en: 'e.g., Monthly Regular, 10-Session Pack', ja: '例: レギュラー月謝, 10回チケット', zh: '例: 常规月卡, 10次私教套餐', vi: 'VD: Lớp thường tháng, Gói 10 buổi', es: 'Ej: Mensualidad, Bono 10 sesiones'),
                      prefixIcon: Icons.badge_outlined,
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: groupCtrl,
                      label: LocalizationService.pick(ko: '수업 / 그룹명', en: 'Class / Group', ja: 'クラス名', zh: '课程 / 分组名称', vi: 'Tên lớp / nhóm', es: 'Grupo / Clase'),
                      hint: LocalizationService.pick(ko: '예: 중등수학, 기구필라테스', en: 'e.g., Pilates, General', ja: '例: ピラティス, 一般', zh: '例: 普拉提, 常规班', vi: 'VD: Pilates, Chung', es: 'Ej: Pilates, General'),
                      prefixIcon: Icons.group_outlined,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      LocalizationService.pick(ko: '수강 / 이용 유형', en: 'Billing Type', ja: '料金体系', zh: '收费类型', vi: 'Hình thức thu phí', es: 'Tipo de Cobro'),
                      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 6),
                    SegmentedButton<BillingType>(
                      segments: [
                        ButtonSegment(
                          value: BillingType.monthlyRecurring,
                          label: Text(LocalizationService.pick(ko: '정기 월납', en: 'Monthly', ja: '定期月謝', zh: '定期月费', vi: 'Hàng tháng', es: 'Mensual')),
                        ),
                        ButtonSegment(
                          value: BillingType.sessionBased,
                          label: Text(LocalizationService.pick(ko: '회차 차감형', en: 'Sessions', ja: '回数券', zh: '按次计费', vi: 'Theo buổi', es: 'Sesiones')),
                        ),
                      ],
                      selected: {billingType},
                      onSelectionChanged: (val) => setDlgState(() => billingType = val.first),
                    ),
                    const SizedBox(height: 12),
                    AppTextField(
                      controller: feeCtrl,
                      label: '${LocalizationService.pick(ko: '기본 금액', en: 'Default Fee', ja: '基本金額', zh: '默认金额', vi: 'Mức phí mặc định', es: 'Tarifa base')} (${LocalizationService.currentCurrency.symbol})',
                      hint: LocalizationService.currentCurrency.sampleAmount.toInt().toString(),
                      prefixIcon: Icons.payments_outlined,
                      keyboardType: TextInputType.number,
                    ),
                    if (billingType == BillingType.sessionBased) ...[
                      const SizedBox(height: 12),
                      AppTextField(
                        controller: sessionsCtrl,
                        label: LocalizationService.pick(ko: '기본 회차', en: 'Default Sessions', ja: '基本回数', zh: '默认次数', vi: 'Số buổi mặc định', es: 'Sesiones incluidas'),
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
                    label: LocalizationService.tr('btn_save'),
                    size: ZeroButtonSize.medium,
                    fullWidth: true,
                    onPressed: () async {
                      final label = labelCtrl.text.trim();
                      final group = groupCtrl.text.trim();
                      final fee = int.tryParse(feeCtrl.text.replaceAll(',', '').trim()) ?? 0;
                      final sessions = int.tryParse(sessionsCtrl.text.trim()) ?? 0;

                      if (label.isEmpty || group.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LocalizationService.pick(
                          ko: '템플릿명과 그룹명을 입력해주세요.',
                          en: 'Please enter preset name and group.',
                          ja: 'テンプレート名とグループ名を入力してください。',
                          zh: '请输入模板名称和分组名。',
                          vi: 'Vui lòng nhập tên mẫu và nhóm.',
                          es: 'Ingresa el nombre y el grupo.',
                        ))));
                        return;
                      }

                      final bm = MonetizationService.instance;
                      final tplNoun = LocalizationService.pick(ko: '회원 등록 템플릿', en: 'Member Preset', ja: '会員テンプレート', zh: '会员模板', vi: 'Mẫu hội viên', es: 'Plantilla');
                      if (isEdit) {
                        if (!await bm.ensureEditAllowed(dlgContext, itemLabel: tplNoun)) {
                          return;
                        }
                      } else {
                        final curCount = catState.memberTemplates.length;
                        if (!await bm.ensureCreateAllowed(
                          dlgContext,
                          itemLabel: tplNoun,
                          currentCount: curCount,
                          limit: bm.maxCustomTemplateLimit,
                        )) {
                          return;
                        }
                      }
                      final newTemplate = MemberCategoryTemplate(
                        id: existing?.id ?? 'tpl_${DateTime.now().millisecondsSinceEpoch}',
                        label: label,
                        groupName: group,
                        billingType: billingType,
                        defaultFee: fee,
                        defaultSessions: billingType == BillingType.sessionBased ? sessions : 0,
                      );

                      await ref.read(customCategoryProvider.notifier).saveMemberTemplate(newTemplate);
                      if (isEdit) {
                        await bm.recordEditUsage();
                      }
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
    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (ctx) {
        return Consumer(
          builder: (context, ref, _) {
            final catState = ref.watch(customCategoryProvider).value ??
                CustomCategoryState.getDefaultsForIndustry('입시 / 보습학원');

            return StickyBottomSheetLayout(
              bodyPadding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
              body: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSheetHeader(
                    ctx,
                    LocalizationService.pick(
                      ko: '청구 항목 및 금액 템플릿',
                      en: 'Invoice Items & Fee Templates',
                      ja: '請求項目・金額テンプレート',
                      zh: '账单条目与收费模板',
                      vi: 'Hạng mục & mẫu hóa đơn',
                      es: 'Conceptos e Importes',
                    ),
                    Icons.receipt_long_rounded,
                    const Color(0xFF8B5CF6),
                  ),
                  Text(
                    LocalizationService.pick(
                      ko: '업종별 수납 항목과 금액을 새로 추가하거나 기존 항목을 눌러 수정·삭제할 수 있습니다.',
                      en: 'Add reusable fee items or tap an existing one to update pricing.',
                      ja: '項目と単価を追加したり、タップして編集・削除できます。',
                      zh: '添加常用收费条目及单价，或点击现有条目修改与删除。',
                      vi: 'Thêm mục thu mới hoặc chạm vào mục hiện có để sửa/xóa.',
                      es: 'Añade conceptos de cobro o toca uno existente para editarlo.',
                    ),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
                  ),
                  const SizedBox(height: 16),

                  if (catState.invoiceTemplates.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Text(
                        LocalizationService.pick(
                          ko: '등록된 청구 항목이 없습니다. 상단 버튼으로 새 항목을 등록해보세요.',
                          en: 'No invoice templates yet. Tap below to add one.',
                          ja: '請求項目がありません。下のボタンから追加できます。',
                          zh: '暂无账单条目，点击下方按钮添加。',
                          vi: 'Chưa có hạng mục nào. Nhấn nút dưới để thêm.',
                          es: 'Sin conceptos aún. Añade uno abajo.',
                        ),
                        style: const TextStyle(color: AppTheme.textSecondary),
                      ),
                    )
                  else
                    ...catState.invoiceTemplates.map((template) {
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => _openAddInvoiceTemplateDialog(context, existing: template),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
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
                                              child: Text(LocalizationService.localizeBuiltInLabel(template.category!), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Color(0xFF4338CA))),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${LocalizationService.pick(ko: '기본 청구 금액', en: 'Default Amount', ja: '基本請求額', zh: '默认金额', vi: 'Số tiền mặc định', es: 'Importe base')} : ${LocalizationService.formatAmount(template.defaultAmount)}',
                                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, color: AppTheme.primaryBlue, size: 20),
                                  tooltip: LocalizationService.pick(ko: '항목 수정', en: 'Edit', ja: '編集', zh: '编辑', vi: 'Sửa', es: 'Editar'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () => _openAddInvoiceTemplateDialog(context, existing: template),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, color: Color(0xFF94A3B8), size: 20),
                                  tooltip: LocalizationService.pick(ko: '항목 삭제', en: 'Delete', ja: '削除', zh: '删除', vi: 'Xóa', es: 'Eliminar'),
                                  visualDensity: VisualDensity.compact,
                                  onPressed: () async {
                                    await ref.read(customCategoryProvider.notifier).removeInvoiceTemplate(template.id);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text(LocalizationService.pick(
                                            ko: '\'${template.title}\' 항목이 삭제되었습니다.',
                                            en: 'Deleted \'${template.title}\'.',
                                            ja: '「${template.title}」を削除しました。',
                                            zh: '已删除条目「${template.title}」。',
                                            vi: 'Đã xóa \'${template.title}\'.',
                                            es: 'Eliminado \'${template.title}\'.',
                                          )),
                                          duration: const Duration(seconds: 1),
                                        ),
                                      );
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                ],
              ),
              footerPadding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              footer: ZeroButton.primary(
                label: LocalizationService.pick(
                  ko: '새 청구 항목 템플릿 추가하기',
                  en: 'Add New Invoice Item',
                  ja: '新しい請求項目を追加',
                  zh: '添加新账单条目',
                  vi: 'Thêm hạng mục hóa đơn mới',
                  es: 'Añadir Nuevo Concepto',
                ),
                icon: Icons.add_rounded,
                size: ZeroButtonSize.medium,
                fullWidth: true,
                onPressed: () => _openAddInvoiceTemplateDialog(context),
              ),
            );
          },
        );
      },
    );
  }

  void _openAddInvoiceTemplateDialog(
    BuildContext context, {
    InvoiceItemTemplate? existing,
  }) {
    final isEdit = existing != null;
    final titleCtrl = TextEditingController(text: existing?.title ?? '');
    final amountCtrl = TextEditingController(
      text: (existing?.defaultAmount ?? LocalizationService.currentCurrency.sampleAmount.toInt()).toString(),
    );
    final tagCtrl = TextEditingController(
      text: existing?.category ?? LocalizationService.pick(ko: '정기수납', en: 'Recurring', ja: '定期', zh: '常规收费', vi: 'Định kỳ', es: 'Mensual'),
    );

    showDialog(
      context: context,
      builder: (dlgContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(
            isEdit
                ? LocalizationService.pick(ko: '청구 항목 수정', en: 'Edit Item', ja: '請求項目を編集', zh: '编辑账单条目', vi: 'Sửa mục thu', es: 'Editar Concepto')
                : LocalizationService.pick(ko: '새 청구 항목 추가', en: 'New Invoice Item', ja: '新規請求項目', zh: '新增账单条目', vi: 'Thêm mục thu mới', es: 'Nuevo Concepto'),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppTextField(
                  controller: titleCtrl,
                  label: LocalizationService.pick(ko: '청구 항목명', en: 'Item Title', ja: '項目名', zh: '账单条目名称', vi: 'Tên mục', es: 'Nombre del Concepto'),
                  hint: LocalizationService.pick(ko: '예: 교재비 / 워크북, PT 10회 재등록', en: 'e.g., Workbook Fee, 10-Session Renewal', ja: '例: 教材費, 10回回数券', zh: '例: 教材费, 10次续费卡', vi: 'VD: Sách bài tập, Gói 10 buổi', es: 'Ej: Libros, Bono 10 sesiones'),
                  prefixIcon: Icons.receipt_outlined,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: amountCtrl,
                  label: '${LocalizationService.pick(ko: '기본 청구 금액', en: 'Default Amount', ja: '基本請求額', zh: '默认金额', vi: 'Số tiền mặc định', es: 'Importe base')} (${LocalizationService.currentCurrency.symbol})',
                  hint: LocalizationService.currentCurrency.sampleAmount.toInt().toString(),
                  prefixIcon: Icons.payments_outlined,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                AppTextField(
                  controller: tagCtrl,
                  label: LocalizationService.pick(ko: '분류 태그 (선택)', en: 'Category Tag (Optional)', ja: 'タグ（任意）', zh: '分类标签（可选）', vi: 'Thẻ (Tùy chọn)', es: 'Etiqueta (Opcional)'),
                  hint: LocalizationService.pick(ko: '예: 정기수납, 교재/재료, 레슨비', en: 'e.g., Monthly, Supplies, Lesson Fee', ja: '例: 月謝, 教材, レッスン', zh: '例: 月费, 材料, 课时', vi: 'VD: Hàng tháng, Tài liệu', es: 'Ej: Mensual, Material, Clases'),
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
                label: LocalizationService.tr('btn_save'),
                size: ZeroButtonSize.medium,
                fullWidth: true,
                onPressed: () async {
                  final title = titleCtrl.text.trim();
                  final amount = int.tryParse(amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
                  final tag = tagCtrl.text.trim();

                  if (title.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(LocalizationService.pick(
                      ko: '청구 항목명을 입력해주세요.',
                      en: 'Please enter an item title.',
                      ja: '項目名を入力してください。',
                      zh: '请输入账单条目名称。',
                      vi: 'Vui lòng nhập tên mục.',
                      es: 'Ingresa el nombre del concepto.',
                    ))));
                    return;
                  }

                  final bm = MonetizationService.instance;
                  final tplLabel = LocalizationService.pick(ko: '청구 항목 템플릿', en: 'Invoice Item', ja: '請求項目', zh: '账单条目', vi: 'Hạng mục', es: 'Concepto');
                  if (isEdit) {
                    if (!await bm.ensureEditAllowed(dlgContext, itemLabel: tplLabel)) {
                      return;
                    }
                  } else {
                    final curCount = ref.read(customCategoryProvider).value?.invoiceTemplates.length ?? 0;
                    if (!await bm.ensureCreateAllowed(
                      dlgContext,
                      itemLabel: tplLabel,
                      currentCount: curCount,
                      limit: bm.maxCustomTemplateLimit,
                    )) {
                      return;
                    }
                  }
                  final newTemplate = InvoiceItemTemplate(
                    id: existing?.id ?? 'inv_tpl_${DateTime.now().millisecondsSinceEpoch}',
                    title: title,
                    defaultAmount: amount,
                    category: tag.isEmpty ? null : tag,
                  );

                  await ref.read(customCategoryProvider.notifier).saveInvoiceTemplate(newTemplate);
                  if (isEdit) {
                    await bm.recordEditUsage();
                  }
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
      {
        'category': '입시 / 보습학원',
        'title': LocalizationService.pick(
          ko: '📚 학원 · 공부방 · 보습학원',
          en: '📚 Academy & Tutoring',
          ja: '📚 学習塾・進学教室',
          zh: '📚 学科辅导与培训机构',
          vi: '📚 Trung tâm học & Gia sư',
          es: '📚 Academia y Clases de Apoyo',
        ),
        'desc': LocalizationService.pick(
          ko: '초·중·고등반, 정규수강료, 교재비, 특강비',
          en: 'Grade groups, monthly tuition, workbooks, exam prep',
          ja: '学年別クラス、月謝、教材費、特別講習',
          zh: '年级分组、常规学费、教材费、特训营',
          vi: 'Nhóm theo lớp, học phí tháng, tài liệu',
          es: 'Grupos por nivel, mensualidad, materiales',
        ),
      },
      {
        'category': '피트니스 / PT',
        'title': LocalizationService.pick(
          ko: '🏋️ 피트니스 · PT · 헬스',
          en: '🏋️ Fitness & Personal Training',
          ja: '🏋️ フィットネス・パーソナルジム',
          zh: '🏋️ 健身工作室与私教 PT',
          vi: '🏋️ Phòng tập Gym & PT',
          es: '🏋️ Fitness y Entrenamiento Personal',
        ),
        'desc': LocalizationService.pick(
          ko: '1:1 PT, 듀엣, 헬스회원권, 락커/운동복',
          en: '1:1 PT, fat-loss program, session passes, locker',
          ja: 'パーソナルPT、回数券、会員費、ロッカー',
          zh: '1对1私教、减脂塑形、次卡套餐、储物柜',
          vi: 'PT 1:1, giảm cân, gói buổi tập',
          es: 'PT 1:1, bonos de sesiones, taquilla',
        ),
      },
      {
        'category': '필라테스 / 요가',
        'title': LocalizationService.pick(
          ko: '🧘 필라테스 · 요가 · 댄스',
          en: '🧘 Pilates, Yoga & Wellness',
          ja: '🧘 ピラティス・ヨガ・ダンス',
          zh: '🧘 普拉提 · 瑜伽 · 舞蹈',
          vi: '🧘 Pilates · Yoga · Múa',
          es: '🧘 Pilates, Yoga y Danza',
        ),
        'desc': LocalizationService.pick(
          ko: '개인 기구필라, 소그룹 리포머, 요가정기권',
          en: 'Reformer Pilates, Mat Yoga, small-group packages',
          ja: 'マシンピラティス、マットヨガ、グループレッスン',
          zh: '器械普拉提、垫上瑜伽、小班定期卡',
          vi: 'Pilates máy, Yoga thảm, gói định kỳ',
          es: 'Pilates máquinas, Yoga suelo, bonos',
        ),
      },
      {
        'category': '태권도 / 무술',
        'title': LocalizationService.pick(
          ko: '🥋 태권도 · 체육관 · 무술',
          en: '🥋 Martial Arts & Dojo',
          ja: '🥋 武道・空手・テコンドー',
          zh: '🥋 武道馆 · 跆拳道 · 空手道',
          vi: '🥋 Võ thuật · Taekwondo · Karate',
          es: '🥋 Artes Marciales y Dojo',
        ),
        'desc': LocalizationService.pick(
          ko: '유치부, 초등부, 시범단, 정기심사비, 도복비',
          en: 'Kids, Juniors, Adult division, belt testing & uniform',
          ja: '幼年部・少年部・昇級審査費・道着',
          zh: '幼儿班、少儿班、考级费、道服费',
          vi: 'Thiếu nhi, thiếu niên, thi lên đai, võ phục',
          es: 'Infantil, juvenil, examen de cinturón',
        ),
      },
      {
        'category': '음악 / 피아노',
        'title': LocalizationService.pick(
          ko: '🎨 음악 · 피아노 · 미술공방',
          en: '🎨 Music, Piano & Art Workshop',
          ja: '🎨 音楽・ピアノ・アート教室',
          zh: '🎨 音乐 · 钢琴 · 美术工坊',
          vi: '🎨 Nhạc · Piano · Mỹ thuật',
          es: '🎨 Música, Piano y Taller de Arte',
        ),
        'desc': LocalizationService.pick(
          ko: '피아노기초, 도예정규반, 가마소성비, 악보비',
          en: 'Hobby lessons, audition prep, sheet music & kiln/materials',
          ja: '趣味コース、受験コース、楽譜・画材費',
          zh: '兴趣启蒙、考级强化、乐谱及耗材费',
          vi: 'Lớp cơ bản, luyện thi, tài liệu nhạc cụ',
          es: 'Clases hobby, conservatorio, partituras/material',
        ),
      },
      {
        'category': '기타 / 맞춤업종',
        'title': LocalizationService.pick(
          ko: '🏢 기타 / 맞춤업종 (범용)',
          en: '🏢 General / Custom Studio',
          ja: '🏢 その他・汎用スタジオ',
          zh: '🏢 通用 / 自定义服务门店',
          vi: '🏢 Ngành khác / Tùy chỉnh',
          es: '🏢 Otros / Negocio Personalizado',
        ),
        'desc': LocalizationService.pick(
          ko: '일반 정규반, 10회 이용권, 소모품/재료비',
          en: 'Standard membership, 10-session pass, supplies',
          ja: '一般会員、10回利用券、備品・消耗品',
          zh: '常规会员、10次通用卡、耗材费',
          vi: 'Gói tiêu chuẩn, vé 10 lượt, phụ phí',
          es: 'Cuota estándar, bono 10 visitas, material',
        ),
      },
    ];

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.85,
      builder: (ctx) {
        return SingleChildScrollView(
          padding: AppBottomSheet.responsiveSheetPadding(ctx, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSheetHeader(
                ctx,
                LocalizationService.pick(
                  ko: '원터치 업종별 프리셋 불러오기',
                  en: 'Load Industry Preset Pack',
                  ja: 'ワンタッチ業種プリセット読込',
                  zh: '一键载入行业标准模板',
                  vi: 'Tải bộ mẫu theo ngành nghề',
                  es: 'Cargar Preajuste por Sector',
                ),
                Icons.auto_fix_high_rounded,
                AppTheme.warning,
              ),
              const SizedBox(height: 6),
              Text(
                LocalizationService.pick(
                  ko: '선택하신 업종에 가장 최적화된 그룹 및 청구 서식으로 일괄 재구성합니다. 기존 서식은 해당 업종의 기본 템플릿으로 교체됩니다.',
                  en: 'Replaces your current group and invoice templates with curated defaults for the chosen industry.',
                  ja: '選んだ業種向けに最適化されたグループと請求テンプレートへ一括切り替えします。',
                  zh: '将当前课程分组和账单模板替换为所选行业的最佳实践预设包。',
                  vi: 'Áp dụng nhanh bộ nhóm lớp và mẫu hóa đơn tối ưu theo ngành bạn chọn.',
                  es: 'Reemplaza tus grupos y plantillas actuales por los preajustes de ese sector.',
                ),
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
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
                            content: Text(LocalizationService.pick(
                              ko: '${p['title']} 템플릿 프리셋이 성공적으로 적용되었습니다.',
                              en: 'Applied ${p['title']} templates.',
                              ja: '${p['title']} テンプレートを適用しました。',
                              zh: '已成功应用「${p['title']}」行业模板。',
                              vi: 'Đã áp dụng bộ mẫu ${p['title']}.',
                              es: 'Plantillas de ${p['title']} aplicadas.',
                            )),
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
