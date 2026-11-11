import 'package:flutter/material.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';

class SeniorEasyGuideModal extends StatelessWidget {
  const SeniorEasyGuideModal({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (ctx) => const SeniorEasyGuideModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 360;
    final hPad = isCompact ? 14.0 : 20.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 4, 8, 12),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isCompact ? 8 : 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryBlue.withAlpha(80), width: 1.5),
                ),
                child: Icon(
                  Icons.elderly_rounded,
                  color: AppTheme.trustBlue,
                  size: isCompact ? 24 : 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocalizationService.pick(
                        ko: '큰글씨 간편 사용 안내',
                        en: 'Large Text Mode Quick Guide',
                        ja: '大きな文字モード かんたん案内',
                        zh: '大字关怀模式简明指南',
                        vi: 'Hướng dẫn Chế độ Chữ Lớn',
                        es: 'Guía Rápida de Texto Grande',
                      ),
                      style: TextStyle(
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      LocalizationService.pick(
                        ko: '돋보기 없이도 3초 만에 끝내는 쉬운 사용법',
                        en: 'Big buttons & high-contrast cards — done in 3 seconds',
                        ja: '見やすい大きな文字とボタンで迷わず3秒操作',
                        zh: '无需老花镜，超大字体与按键 3 秒完成日常操作',
                        vi: 'Chữ to, nút bấm rõ ràng — thao tác chỉ trong 3 giây',
                        es: 'Botones grandes y alto contraste en 3 segundos',
                      ),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 24, color: Colors.black87),
                splashRadius: 20,
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        const Divider(height: 1, thickness: 1.2, color: Color(0xFFE2E8F0)),

        // Content Steps List
        Flexible(
          child: ListView(
            padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 16),
            children: [
              _buildStepCard(
                stepNumber: '1',
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF059669),
                title: LocalizationService.pick(
                  ko: '오늘 온 학생 출석 찍기',
                  en: 'Check In Today\'s Visitors',
                  ja: '今日の出席をチェックする',
                  zh: '为到店学员快速打卡',
                  vi: 'Điểm danh hội viên hôm nay',
                  es: 'Registrar Asistencia de Hoy',
                ),
                description: LocalizationService.pick(
                  ko: '화면 상단의 [📌 큰글씨 간편 출석]을 누르면 학생 이름이 아주 크게 나옵니다.\n학생 이름 옆의 초록색 [출석 완료] 버튼만 누르면 바로 출석 체크가 끝납니다.',
                  en: 'Tap [Large Check-In] at the top to see extra-large names.\nTap the big green [Check In] button next to any name.',
                  ja: '上部の[かんたん出席]を開くと名前が大きく表示されます。\n緑の[出席完了]ボタンを押すだけで完了です。',
                  zh: '点击顶部[大字快速考勤]，超大字号显示名单。\n点击姓名旁的绿色[完成签到]按钮即可打卡。',
                  vi: 'Nhấn [Điểm danh nhanh] ở trên để xem tên cỡ lớn.\nChạm nút xanh [Điểm danh] cạnh tên hội viên là xong.',
                  es: 'Pulsa [Asistencia Fácil] arriba para ver nombres grandes y toca el botón verde.',
                ),
                tip: LocalizationService.pick(
                  ko: '💡 학생이 직접 번호를 누르게 하려면 [무인 키오스크]를 켜두시면 됩니다.',
                  en: '💡 Turn on [Kiosk] at the entrance so visitors can check themselves in.',
                  ja: '💡 生徒様自身に入力してもらう場合は[キオスク]をご利用ください。',
                  zh: '💡 开启入口[无人考勤机]，可让学员自助签到。',
                  vi: '💡 Bật [Kiosk] tại cửa nếu muốn học viên tự nhập mã điểm danh.',
                  es: '💡 Activa el [Quiosco] en la entrada para registro autónomo.',
                ),
              ),
              const SizedBox(height: 14),
              _buildStepCard(
                stepNumber: '2',
                icon: Icons.mark_email_read_rounded,
                iconColor: AppTheme.trustBlue,
                title: LocalizationService.pick(
                  ko: '이번 달 수강료(회비) 문자 보내기',
                  en: 'Send Monthly Fee Reminders',
                  ja: '今月の月謝・会費メッセージ送信',
                  zh: '发送本月待收学费提醒',
                  vi: 'Gửi tin nhắn nhắc phí tháng này',
                  es: 'Enviar Avisos de Cobro del Mes',
                ),
                description: LocalizationService.pick(
                  ko: '화면 상단의 [💌 회비(수강료) 문자]를 누르면 이번 달 회비를 아직 안 낸 회원 명단이 나옵니다.\n파란색 [문자 보내기] 버튼을 누르면 등록된 수납 계좌번호와 금액이 적힌 문자가 바로 만들어집니다.',
                  en: 'Tap [Billing Messages] to list everyone with an unpaid fee.\nTap the blue [Send] button to pre-fill amount and bank details automatically.',
                  ja: '[請求メッセージ]を押すと未入金の方が表示されます。\n青い[送信]ボタンを押すと金額と口座入りのメッセージが作成されます。',
                  zh: '点击[收费短信]查看待缴费名单。\n点击蓝色[发送]按钮即可自动生成含金额与账户的提醒短信。',
                  vi: 'Nhấn [Nhắn tin thu phí] để xem người chưa đóng tiền.\nNhấn [Gửi tin] để tạo sẵn tin nhắn kèm số tiền & tài khoản.',
                  es: 'Pulsa [Avisos de Cobro] para ver pagos pendientes y enviar con un toque.',
                ),
                tip: LocalizationService.pick(
                  ko: '💡 카카오톡이나 일반 문자(SMS) 중 편한 방식으로 무료 전송됩니다.',
                  en: '💡 Send at \$0 cost via your built-in SMS app or messaging app.',
                  ja: '💡 お使いのSMSアプリやメッセージアプリから無料で送信できます。',
                  zh: '💡 支持通过手机自带短信或常用聊天应用零成本免费发送。',
                  vi: '💡 Gửi hoàn toàn miễn phí qua ứng dụng SMS hoặc Zalo/Messenger.',
                  es: '💡 Se envía gratis mediante tu app de SMS o WhatsApp.',
                ),
              ),
              const SizedBox(height: 14),
              _buildStepCard(
                stepNumber: '3',
                icon: Icons.phone_in_talk_rounded,
                iconColor: const Color(0xFFD97706),
                title: LocalizationService.pick(
                  ko: '학생이나 학부모님께 바로 전화 걸기',
                  en: 'Call Members or Parents in 1 Tap',
                  ja: '会員・保護者様へワンタップ電話発信',
                  zh: '一键拨打学员或家长电话',
                  vi: 'Gọi trực tiếp cho học viên / phụ huynh',
                  es: 'Llamar con 1 Toque',
                ),
                description: LocalizationService.pick(
                  ko: '[📞 원생·학부모 전화]를 누르고 이름 옆의 [전화 걸기] 버튼을 누르면 스마트폰 통화 화면으로 바로 연결됩니다.\n연락처를 찾거나 번호를 외우실 필요가 없습니다.',
                  en: 'Tap [Quick Call Directory] and press [Call] next to any name — dials right away with zero searching.',
                  ja: '[クイック電話帳]を開いて[発信]を押すだけでそのまま電話がかかります。',
                  zh: '打开[一键通话名录]，点击姓名旁的[拨打电话]即可直连通话。',
                  vi: 'Mở [Danh bạ gọi nhanh] và chạm [Gọi điện] ngay cạnh tên.',
                  es: 'Abre [Llamada Rápida] y pulsa [Llamar] sin buscar números.',
                ),
                tip: LocalizationService.pick(
                  ko: '💡 학부모님 번호가 등록되어 있으면 부모님께 먼저 전화가 걸립니다.',
                  en: '💡 Automatically prioritizes the parent/payer contact if saved.',
                  ja: '💡 保護者番号が登録されている場合は保護者様へ優先発信します。',
                  zh: '💡 若填有家长联系方式，将优先拨打家长电话。',
                  vi: '💡 Ưu tiên gọi số phụ huynh/người thanh toán nếu đã lưu.',
                  es: '💡 Prioriza el número del padre/pagador si está guardado.',
                ),
              ),
              const SizedBox(height: 14),
              _buildStepCard(
                stepNumber: '4',
                icon: Icons.zoom_in_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: LocalizationService.pick(
                  ko: '글씨 크기 및 원래 모드로 돌아가기',
                  en: 'Switch Back to Standard View Anytime',
                  ja: '文字サイズを通常モードに戻す',
                  zh: '随时切换字体大小或返回标准视图',
                  vi: 'Chuyển về giao diện chuẩn bất cứ lúc nào',
                  es: 'Volver a la Vista Normal Cuando Quieras',
                ),
                description: LocalizationService.pick(
                  ko: '화면 오른쪽 위의 [👓 큰글씨 ON] 버튼을 누르면 언제든지 보통 글씨 화면으로 돌아갈 수 있습니다.\n[설정] 메뉴에서도 원하실 때 언제든 켜고 끄실 수 있습니다.',
                  en: 'Tap the text-size icon at the top right (or toggle in Settings) anytime to switch between Large Text and Standard layouts.',
                  ja: '右上の文字サイズアイコンまたは[設定]から、いつでも通常表示に戻せます。',
                  zh: '随时点击右上角[大字]图标或在[设置]中切换回标准视图。',
                  vi: 'Chạm biểu tượng cỡ chữ ở góc trên hoặc vào [Cài đặt] để bật/tắt tùy ý.',
                  es: 'Toca el icono de tamaño arriba a la derecha para alternar cuando quieras.',
                ),
                tip: LocalizationService.pick(
                  ko: '💡 눈이 침침하실 땐 언제든 켜두시면 글씨가 1.4배 커져 편안합니다.',
                  en: '💡 Leave it ON whenever you prefer 1.4x larger typography and bolder borders.',
                  ja: '💡 文字が読みづらいときはオンにすると1.4倍のサイズで快適に見えます。',
                  zh: '💡 开启后文字自动放大 1.4 倍并增强对比度，阅读更轻松。',
                  vi: '💡 Bật lên bất cứ lúc nào để phóng to chữ 1.4x rõ nét.',
                  es: '💡 Mantenlo activo para ver todo un 40% más grande y claro.',
                ),
              ),
            ],
          ),
        ),
        // Bottom Confirm Button
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 10, hPad, 16),
          child: SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.trustBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                elevation: 1,
              ),
              onPressed: () => Navigator.pop(context),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  LocalizationService.pick(
                    ko: '확인했습니다 (닫기)',
                    en: 'Got It (Close)',
                    ja: '確認しました（閉じる）',
                    zh: '我已了解（关闭）',
                    vi: 'Đã hiểu (Đóng)',
                    es: 'Entendido (Cerrar)',
                  ),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStepCard({
    required String stepNumber,
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required String tip,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFCBD5E1), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: iconColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  stepNumber,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Icon(icon, color: iconColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w900,
                    color: Colors.black,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: const TextStyle(
              fontSize: 14.5,
              height: 1.55,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              tip,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
