import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/monetization_service.dart';
import '../services/schedule_service.dart';
import '../theme/app_theme.dart';
import 'mascot_avatar.dart';
import 'design_system.dart';
import 'responsive_dialog_actions.dart';
import '../services/localization_service.dart';

class StepByStepPracticeGuideDialog extends ConsumerStatefulWidget {
  final VoidCallback onOpenAddMember;
  final VoidCallback onOpenSettings;

  const StepByStepPracticeGuideDialog({
    super.key,
    required this.onOpenAddMember,
    required this.onOpenSettings,
  });

  static void show(
    BuildContext context, {
    required VoidCallback onOpenAddMember,
    required VoidCallback onOpenSettings,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => StepByStepPracticeGuideDialog(
        onOpenAddMember: onOpenAddMember,
        onOpenSettings: onOpenSettings,
      ),
    );
  }

  @override
  ConsumerState<StepByStepPracticeGuideDialog> createState() => _StepByStepPracticeGuideDialogState();
}

class _StepByStepPracticeGuideDialogState extends ConsumerState<StepByStepPracticeGuideDialog> {
  int _currentStep = 0;

  List<GuideStepItem> _buildSteps() {
    final supportsToss = LocalizationService.supportsTossTransfer;
    return [
      GuideStepItem(
        title: LocalizationService.pick(
          ko: '1단계: 내 스튜디오 & 입금 계좌 설정하기',
          en: 'Step 1: Set Up Studio & Payout Account',
          ja: 'ステップ1：スタジオ＆入金口座の設定',
          zh: '第1步：设置工作室与收款账户',
          vi: 'Bước 1: Thiết lập Cơ sở & Tài khoản nhận tiền',
          es: 'Paso 1: Configurar Estudio y Cuenta de Cobro',
        ),
        description: LocalizationService.pick(
          ko: '청구서 및 출결 알림 문자에 표시될 상호명, 담당자 성함·직함, 수강료를 입금받을 은행 계좌를 먼저 등록해 볼까요?',
          en: 'Register your studio name, manager title, and bank/payout details shown on invoices and attendance notices first.',
          ja: '請求書や出欠通知に表示される屋号・担当者名・授業料の振込先口座をまず登録しましょう。',
          zh: '先填写将显示在账单与考勤通知中的机构名称、负责人及收款账户信息吧。',
          vi: 'Hãy đăng ký tên cơ sở, người phụ trách và tài khoản nhận học phí hiển thị trên hóa đơn và thông báo điểm danh trước nhé.',
          es: 'Registra primero el nombre de tu centro, responsable y cuenta de cobro que aparecerán en facturas y avisos.',
        ),
        actionLabel: LocalizationService.pick(
          ko: '내 스튜디오 정보 설정하러 가기',
          en: 'Go to Studio Settings',
          ja: 'スタジオ情報を設定する',
          zh: '前往设置工作室信息',
          vi: 'Đi tới Cài đặt Cơ sở',
          es: 'Ir a Ajustes del Estudio',
        ),
        tip: LocalizationService.pick(
          ko: '설정 탭에서 1분 만에 등록할 수 있어요!',
          en: 'You can set this up in under a minute in the Settings tab!',
          ja: '設定タブから1分で簡単に登録できます！',
          zh: '在设置标签页中1分钟即可完成登记！',
          vi: 'Bạn có thể đăng ký chỉ trong 1 phút tại tab Cài đặt!',
          es: '¡Puedes configurarlo en menos de 1 minuto desde Ajustes!',
        ),
        icon: Icons.account_balance_outlined,
      ),
      GuideStepItem(
        title: LocalizationService.pick(
          ko: '2단계: 실제 첫 회원 등록하기',
          en: 'Step 2: Register Your First Member',
          ja: 'ステップ2：最初の会員を登録する',
          zh: '第2步：添加第一位正式会员',
          vi: 'Bước 2: Đăng ký Hội viên đầu tiên',
          es: 'Paso 2: Registrar al Primer Miembro',
        ),
        description: LocalizationService.pick(
          ko: '회원의 이름, 연락처, 소속 클래스(예: 중등수학, 기구필라테스, 피아노반)와 회차권/정기권 수강료를 등록해 볼까요?',
          en: 'Add the member\'s name, phone number, class/group, and session pass or monthly tuition fee.',
          ja: '会員のお名前・連絡先・クラス名（例：ピアノ、ピラティス等）と回数券または月謝を登録しましょう。',
          zh: '登记会员姓名、联系方式、所属班级及课次卡或月度学费金额。',
          vi: 'Nhập tên hội viên, số điện thoại, lớp/nhóm và gói buổi học hoặc học phí định kỳ.',
          es: 'Añade el nombre, contacto, clase o grupo y el bono de sesiones o cuota mensual.',
        ),
        actionLabel: LocalizationService.pick(
          ko: '신규 회원 직접 등록하기',
          en: 'Add New Member Now',
          ja: '新規会員を登録する',
          zh: '立即新增会员',
          vi: 'Thêm hội viên mới ngay',
          es: 'Añadir Nuevo Miembro',
        ),
        tip: LocalizationService.pick(
          ko: '등록된 회원에게는 바로 안심 문자를 보낼 수 있어요!',
          en: 'Once added, you can immediately send check-in alerts to them!',
          ja: '登録した会員にはすぐに出欠安心通知を送れます！',
          zh: '登记后即可随时向该会员发送考勤安心通知！',
          vi: 'Sau khi thêm, bạn có thể gửi thông báo điểm danh ngay lập tức!',
          es: '¡Una vez registrado, podrás enviar avisos de asistencia al instante!',
        ),
        icon: Icons.person_add_alt_1_outlined,
      ),
      GuideStepItem(
        title: LocalizationService.pick(
          ko: '3단계: 1초 만에 출결 체크 & 안심 문자 발송',
          en: 'Step 3: 1-Tap Check-In & Instant Notice',
          ja: 'ステップ3：1秒チェックイン＆安心通知送信',
          zh: '第3步：1秒签到打卡与安心通知发送',
          vi: 'Bước 3: Điểm danh 1 giây & Gửi thông báo',
          es: 'Paso 3: Check-in en 1 seg y Aviso Inmediato',
        ),
        description: LocalizationService.pick(
          ko: '회원이 오면 [체크인] 버튼을 눌러보세요! 잔여 회차가 1회 차감되고, 비용 0원으로 부모님께 등원 알림 문자를 보낼 수 있어요.',
          en: 'Tap [Check-In] when a member arrives! Remaining passes update automatically and you can send a free SMS notice.',
          ja: '会員が来たら［チェックイン］をタップ！残回数が1回減り、0円で安心到着SMSを送信できます。',
          zh: '会员到店时点击【签到】按钮！系统自动扣减1次余课，并可免费通过手机短信发送到达通知。',
          vi: 'Nhấn [Check-In] khi hội viên đến! Số buổi còn lại tự động trừ 1 và gửi SMS thông báo hoàn toàn miễn phí.',
          es: 'Pulsa [Check-In] al llegar el alumno: descuenta 1 sesión y envía un aviso SMS gratuito al instante.',
        ),
        actionLabel: LocalizationService.pick(
          ko: '패스 체크 탭에서 체험하기',
          en: 'Try in Pass Check Tab',
          ja: 'パスチェックタブで試す',
          zh: '前往打卡签到页体验',
          vi: 'Thử trong tab Điểm danh',
          es: 'Probar en pestaña Asistencia',
        ),
        tip: LocalizationService.pick(
          ko: '문자는 내 스마트폰의 무제한 기본 문자로 발송되어 요금이 0원이에요!',
          en: 'Notices use your phone\'s default SMS/messaging app with zero platform fee!',
          ja: '通知はスマホの標準SMSアプリを使うためシステム利用料は0円です！',
          zh: '通知直接调用本机短信应用发送，零额外平台短信费！',
          vi: 'Thông báo dùng ứng dụng tin nhắn mặc định trên điện thoại với 0 phí nền tảng!',
          es: 'Los avisos usan la app de SMS de tu teléfono sin coste de plataforma.',
        ),
        icon: Icons.check_circle_outline,
      ),
      GuideStepItem(
        title: LocalizationService.pick(
          ko: '4단계: 수강료 청구서 작성 & 스마트 수납',
          en: 'Step 4: Tuition Billing & Smart Collection',
          ja: 'ステップ4：授業料請求書の作成＆スマート集金',
          zh: '第4步：创建账单与智能收款对账',
          vi: 'Bước 4: Tạo hóa đơn & Thu học phí thông minh',
          es: 'Paso 4: Facturar Cuotas y Cobro Inteligente',
        ),
        description: LocalizationService.pick(
          ko: '두 번째 탭에서 청구서를 만들고 [청구 문자 전송]을 누르면 완성! 은행 앱에서 입금 푸시가 오면 장부에 자동 체크돼요.',
          en: 'Create an invoice in the Billing tab and tap [Send Invoice]. Incoming bank push alerts can mark payments automatically.',
          ja: '2番目のタブで請求書を作成し［請求を送信］するだけ！銀行の入金通知と連携し自動消込もできます。',
          zh: '在第二个标签页创建账单并发送！收到银行入账推送后即可自动或一键核销入账。',
          vi: 'Tạo hóa đơn ở tab thứ hai và nhấn [Gửi hóa đơn]. Thông báo biến động số dư sẽ tự động đối soát thu tiền.',
          es: 'Crea una factura en Cobros y envíala. Las notificaciones bancarias permiten conciliar pagos automáticamente.',
        ),
        actionLabel: LocalizationService.pick(
          ko: '청구·수납 탭 둘러보기',
          en: 'Explore Billing Tab',
          ja: '請求・集金タブを見る',
          zh: '浏览账单收款标签页',
          vi: 'Khám phá tab Hóa đơn',
          es: 'Ver pestaña Facturación',
        ),
        tip: supportsToss
            ? LocalizationService.pick(
                ko: '카카오페이/토스/제로페이 QR, 지역화폐 결제도 모두 지원해요!',
                en: 'Supports card payment links, bank transfers, and instant digital receipts!',
                ja: 'カード決済リンクや銀行振込、デジタル領収書発行にも対応しています！',
                zh: '支持银行转账、银行卡收款链接及电子收据发送！',
                vi: 'Hỗ trợ chuyển khoản, liên kết thanh toán thẻ và gửi biên nhận điện tử!',
                es: 'Soporta enlaces de pago con tarjeta, transferencia y recibos digitales.',
              )
            : LocalizationService.pick(
                ko: '원격 카드 결제 링크, 계좌이체, 디지털 수납 영수증 발송을 모두 지원해요!',
                en: 'Supports remote card payment links, bank transfers, and instant digital receipts!',
                ja: 'オンラインカード決済リンク・銀行振込・デジタル領収書送信にすべて対応しています！',
                zh: '支持远程银行卡收款链接、银行转账及电子收据发送！',
                vi: 'Hỗ trợ liên kết thanh toán thẻ từ xa, chuyển khoản và gửi biên nhận điện tử!',
                es: 'Soporta enlaces de pago con tarjeta, transferencia bancaria y recibos digitales.',
              ),
        icon: Icons.receipt_long_outlined,
      ),
      GuideStepItem(
        title: LocalizationService.pick(
          ko: '5단계: 준비 완료! 실제 데이터로 전환',
          en: 'Step 5: Ready! Switch to Live Data',
          ja: 'ステップ5：準備完了！実データへ切り替え',
          zh: '第5步：准备就绪！切换为真实运营数据',
          vi: 'Bước 5: Sẵn sàng! Chuyển sang Dữ liệu thật',
          es: 'Paso 5: ¡Listo! Pasar a Datos Reales',
        ),
        description: LocalizationService.pick(
          ko: '충분히 둘러보셨나요? 연습용 가상 데이터는 버튼 하나로 깨끗하게 비우고, 진짜 학원/매장 운영을 시작하세요!',
          en: 'Done exploring? Clear the sample practice data with one tap and start managing your real studio!',
          ja: '体験は十分ですか？練習用のサンプルデータをワンタップで消去して、本番運用を始めましょう！',
          zh: '体验完毕了吗？一键清空练习用演示数据，正式开始您的日常运营吧！',
          vi: 'Đã trải nghiệm xong? Xóa dữ liệu mẫu bằng một chạm và bắt đầu quản lý cơ sở thật ngay!',
          es: '¿Terminaste de explorar? Limpia los datos de prueba con un toque y empieza a gestionar tu centro real.',
        ),
        actionLabel: LocalizationService.pick(
          ko: '연습 데이터 비우고 시작하기',
          en: 'Clear Sample Data & Start',
          ja: 'サンプルデータを消去して開始',
          zh: '清空练习数据并开始',
          vi: 'Xóa dữ liệu mẫu & Bắt đầu',
          es: 'Borrar Datos de Prueba y Empezar',
        ),
        tip: LocalizationService.pick(
          ko: '언제든 설정 탭에서 다시 연습 데이터를 불러올 수도 있어요.',
          en: 'You can reload sample practice data anytime from the Settings tab.',
          ja: '設定タブからいつでも練習用サンプルデータを再読み込みできます。',
          zh: '您随时可以在设置标签页中重新载入练习数据。',
          vi: 'Bạn luôn có thể tải lại dữ liệu mẫu bất kỳ lúc nào trong tab Cài đặt.',
          es: 'Puedes volver a cargar datos de prueba cuando quieras desde Ajustes.',
        ),
        icon: Icons.rocket_launch_outlined,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final steps = _buildSteps();
    final step = steps[_currentStep];
    final width = MediaQuery.sizeOf(context).width;
    final isCompact = width < 360;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: EdgeInsets.symmetric(horizontal: isCompact ? 12 : 16, vertical: 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: EdgeInsets.all(isCompact ? 16 : 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Top Header: Mascot Passy winking face + Step indicator
            Row(
              children: [
                ZeroPassMascotAvatar(
                  size: 52,
                  isLightMode: true,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withAlpha((255 * 0.2).round()),
                      blurRadius: 10,
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 6,
                        runSpacing: 2,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryBlue.withAlpha((255 * 0.12).round()),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'STEP ${_currentStep + 1} / ${steps.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          Text(
                            LocalizationService.pick(
                              ko: '패시의 실전 튜토리얼',
                              en: "Passy's Hands-on Tutorial",
                              ja: 'パッシーの実践チュートリアル',
                              zh: 'Passy 实战教程',
                              vi: 'Hướng dẫn thực hành cùng Passy',
                              es: 'Tutorial práctico de Passy',
                            ),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        LocalizationService.pick(
                          ko: '하나씩 따라 해볼까요?',
                          en: 'Let\'s walk through step by step!',
                          ja: '一つずつ一緒に進めてみましょうか？',
                          zh: '我们一步步跟着操作吧！',
                          vi: 'Hãy cùng làm từng bước nhé!',
                          es: '¿Lo hacemos paso a paso?',
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.grey.shade100,
                    ),
                    child: const Icon(Icons.close, color: AppTheme.textSecondary, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Progress bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (_currentStep + 1) / steps.length,
                backgroundColor: AppTheme.borderSubtle,
                valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primaryBlue),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 20),

            // Step Content Box
            Container(
              padding: const EdgeInsets.all(18),
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
                      Icon(step.icon, color: AppTheme.primaryBlue, size: 22),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          step.title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    step.description,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.55,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.tips_and_updates, size: 16, color: AppTheme.primaryBlue),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            step.tip,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF1E40AF),
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Action button for the current step
            ElevatedButton(
              onPressed: () async {
                if (_currentStep == 0) {
                  Navigator.pop(context);
                  widget.onOpenSettings();
                } else if (_currentStep == 1) {
                  Navigator.pop(context);
                  widget.onOpenAddMember();
                } else if (_currentStep == 4) {
                  // Prompt to clear sample data
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (c) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      actionsOverflowButtonSpacing: 8,
                      actionsOverflowDirection: VerticalDirection.down,
                      actionsAlignment: MainAxisAlignment.end,
                      title: Row(
                        children: [
                          const Icon(Icons.cleaning_services_rounded, color: AppTheme.primaryBlue, size: 22),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              LocalizationService.pick(
                                ko: '연습 데이터를 비우시겠습니까?',
                                en: 'Clear sample practice data?',
                                ja: '練習データを消去しますか？',
                                zh: '确定清空练习数据吗？',
                                vi: 'Xóa dữ liệu thực hành mẫu?',
                                es: '¿Borrar datos de prueba?',
                              ),
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                      content: SingleChildScrollView(
                        child: Text(
                          LocalizationService.pick(
                            ko: '연습용 가상 데이터를 모두 지우고 실제 회원만 등록할 수 있는 깨끗한 상태로 만듭니다.\n(언제든 설정 탭에서 연습 데이터를 다시 불러올 수 있습니다.)',
                            en: 'Removes all sample practice records so you have a clean slate for real members.\n(You can reload sample data anytime from Settings.)',
                            ja: '練習用の仮想データをすべて削除し、実会員のみを登録できるきれいな状態にします。\n（設定タブからいつでも練習データを再読込できます。）',
                            zh: '将清除全部演示数据，恢复为仅登记真实会员的干净状态。\n（随时可在设置页重新加载演示数据。）',
                            vi: 'Xóa toàn bộ dữ liệu mẫu để bắt đầu sạch sẽ với hội viên thật.\n(Luôn có thể tải lại dữ liệu mẫu trong Cài đặt.)',
                            es: 'Elimina todos los datos ficticios para dejar todo listo para miembros reales.\n(Puedes recargarlos en Ajustes cuando quieras.)',
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
                          primary: ZeroButton.primary(
                            label: LocalizationService.pick(
                              ko: '비우고 시작하기',
                              en: 'Clear & Start',
                              ja: '消去して開始',
                              zh: '清空并开始',
                              vi: 'Xóa & Bắt đầu',
                              es: 'Borrar y Empezar',
                            ),
                            icon: Icons.check_rounded,
                            size: ZeroButtonSize.medium,
                            fullWidth: true,
                            onPressed: () => Navigator.pop(c, true),
                          ),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
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
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            LocalizationService.pick(
                              ko: '가상 데이터가 모두 비워졌습니다. 이제 실제 회원을 등록해 보세요!',
                              en: 'All sample data has been cleared. Now add your first real member!',
                              ja: 'サンプルデータをすべて消去しました。実会員を登録してみましょう！',
                              zh: '练习数据已全部清空，现在去添加真实会员吧！',
                              vi: 'Đã xóa toàn bộ dữ liệu mẫu. Hãy thêm hội viên thật ngay!',
                              es: 'Datos de prueba eliminados. ¡Ahora añade a tu primer alumno real!',
                            ),
                          ),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                } else {
                  // Next step
                  if (_currentStep < steps.length - 1) {
                    setState(() => _currentStep++);
                  } else {
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      step.actionLabel,
                      textAlign: TextAlign.center,
                      softWrap: true,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Bottom Navigation buttons: responsive wrap if width is constrained
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                if (_currentStep > 0)
                  TextButton.icon(
                    onPressed: () => setState(() => _currentStep--),
                    icon: const Icon(Icons.arrow_back_rounded, size: 16, color: AppTheme.textSecondary),
                    label: Text(
                      LocalizationService.pick(
                        ko: '이전 단계',
                        en: 'Previous',
                        ja: '前へ',
                        zh: '上一步',
                        vi: 'Bước trước',
                        es: 'Anterior',
                      ),
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  )
                else
                  const SizedBox.shrink(),
                if (_currentStep < steps.length - 1)
                  TextButton.icon(
                    onPressed: () => setState(() => _currentStep++),
                    label: Text(
                      LocalizationService.pick(
                        ko: '다음 단계',
                        en: 'Next Step',
                        ja: '次へ',
                        zh: '下一步',
                        vi: 'Bước tiếp',
                        es: 'Siguiente',
                      ),
                      style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700),
                    ),
                    icon: const Icon(Icons.arrow_forward_rounded, size: 16, color: AppTheme.primaryBlue),
                  )
                else
                  TextButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textSecondary),
                    label: Text(
                      LocalizationService.pick(
                        ko: '닫기',
                        en: 'Close',
                        ja: '閉じる',
                        zh: '关闭',
                        vi: 'Đóng',
                        es: 'Cerrar',
                      ),
                      style: const TextStyle(color: AppTheme.textSecondary),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
}

class GuideStepItem {
  final String title;
  final String description;
  final String actionLabel;
  final String tip;
  final IconData icon;

  const GuideStepItem({
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.tip,
    required this.icon,
  });
}
