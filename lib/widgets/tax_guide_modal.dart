import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'responsive_dialog_actions.dart';

class TaxGuideModal extends StatelessWidget {
  const TaxGuideModal({super.key});

  static Future<void> show(BuildContext context) {
    return AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.90,
      builder: (ctx) => const TaxGuideModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 360;
    final hPad = isCompact ? 14.0 : 20.0;
    final isKoreaKr = LocalizationService.supportsTossTransfer &&
        LocalizationService.currentLanguage == AppLanguage.korean;
    final cur = LocalizationService.currentCurrency;

    final String portalUrl = switch (cur) {
      AppCurrency.krw => 'https://www.hometax.go.kr',
      AppCurrency.usd => 'https://www.irs.gov/businesses/small-businesses-self-employed',
      AppCurrency.jpy => 'https://www.e-tax.nta.go.jp',
      AppCurrency.gbp => 'https://www.gov.uk/self-assessment-tax-returns',
      AppCurrency.cad => 'https://www.canada.ca/en/revenue-agency.html',
      AppCurrency.aud => 'https://www.ato.gov.au',
      _ => '',
    };

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Header
        Padding(
          padding: EdgeInsets.fromLTRB(hPad, 4, 8, 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFC7D2FE)),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: Color(0xFF4F46E5), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isKoreaKr
                          ? '국세청 간편장부 & 세무 꿀팁'
                          : LocalizationService.pick(
                              ko: '사업소득 간편장부 & 세무 가이드 (${cur.code})',
                              en: 'Small Business Tax & Ledger Guide (${cur.code})',
                              ja: '個人事業主・確定申告ガイド (${cur.code})',
                              zh: '小微商户记账与报税指南 (${cur.code})',
                              vi: 'Hướng dẫn Thuế & Sổ sách KD (${cur.code})',
                              es: 'Guía Fiscal y Libro Contable (${cur.code})',
                            ),
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      softWrap: true,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isKoreaKr
                          ? '1분 세무 마스터 가이드'
                          : LocalizationService.pick(
                              ko: '1분 세무 마스터 가이드 (${cur.taxPolicy})',
                              en: '1-Minute Tax Essentials · ${cur.taxPolicy}',
                              ja: '1分税務ガイド · ${cur.taxPolicy}',
                              zh: '1分钟税务精华 · ${cur.taxPolicy}',
                              vi: 'Tóm tắt thuế 1 phút · ${cur.taxPolicy}',
                              es: 'Guía rápida fiscal · ${cur.taxPolicy}',
                            ),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                splashRadius: 18,
              ),
            ],
          ),
        ),
        const Divider(height: 12, color: AppTheme.borderSubtle),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 4),
              children: [
                if (isKoreaKr) ...[
                  _buildInfoCard(
                    icon: Icons.help_outline_rounded,
                    iconColor: AppTheme.primaryBlue,
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    title: '국세청 표준 사업소득 간편장부란?',
                    body: '소규모 사업자(학원, 교습소, 체육시설, 필라테스 등 수입 7,500만원 미만)를 위해 국세청에서 특별히 고안한 표준 장부입니다. 복식부기(차변/대변)의 어려운 회계 지식 없이도 수입과 비용을 날짜순으로만 적으면 세법상 100% 인정됩니다.',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.savings_outlined,
                    iconColor: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFF0FDF4),
                    borderColor: const Color(0xFFBBF7D0),
                    title: '간편장부 작성 3대 혜택',
                    body: '1. 무기장 가산세(산출세액의 20%) 완전 면제\n'
                        '2. 임대료, 강사료, 비품 등 실제 지출 경비 100% 인정으로 소득세 절세\n'
                        '3. 엑셀(CSV) 원클릭 추출로 세무사 기장 수수료 절감',
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader('📅 놓치면 안 되는 세무 캘린더'),
                  const SizedBox(height: 8),
                  _buildScheduleTile(
                    badge: '5월',
                    badgeColor: const Color(0xFF4F46E5),
                    title: '종합소득세 확정 신고 (모든 개인사업자 필수)',
                    desc: '전년도 1년치 수납 매출과 운영 지출을 정산하여 신고합니다. 체크앤페이에서 [간편장부 CSV]를 내보내어 세무사에게 전달하거나 홈택스에 기재하세요.',
                  ),
                  const SizedBox(height: 8),
                  _buildScheduleTile(
                    badge: '2월',
                    badgeColor: const Color(0xFF059669),
                    title: '면세사업자 사업장현황신고 (학원, 교습소)',
                    desc: '부가가치세 면세 사업자는 2월 10일까지 1년간 수입금액을 홈택스에 신고해야 5월 소득세 신고 시 불이익을 피할 수 있습니다.',
                  ),
                  const SizedBox(height: 8),
                  _buildScheduleTile(
                    badge: '매월 10일',
                    badgeColor: const Color(0xFFEA580C),
                    title: '강사료 3.3% 원천징수 세액 납부',
                    desc: '프리랜서 강사에게 지급 시 공제한 3.3%(국세 3% + 지방소득세 0.3%)를 다음 달 10일까지 홈택스/위택스에서 간편 납부합니다.',
                  ),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                    title: '세무 적격증빙 보관 꿀팁',
                    body: '• 건당 3만 원 초과 지출 시: 반드시 세금계산서, 신용카드, 현금영수증(지출증빙)을 수취해야 가산세(2%)가 없습니다.\n'
                        '• 간이영수증은 3만 원 이하 소액 경비에만 인정됩니다.\n'
                        '• 체크앤페이 간편장부 CSV는 윈도우 엑셀 한글 깨짐 방지(UTF-8 BOM)가 적용되어 세무사에게 그대로 전송하셔도 완벽 호환됩니다.',
                  ),
                ] else ...[
                  _buildInfoCard(
                    icon: Icons.help_outline_rounded,
                    iconColor: AppTheme.primaryBlue,
                    bgColor: const Color(0xFFEFF6FF),
                    borderColor: const Color(0xFFBFDBFE),
                    title: LocalizationService.pick(
                      ko: '${cur.displayName} 간편장부 안내',
                      en: 'Why Track Revenue & Expenses (${cur.taxPolicy})',
                      ja: '簡易帳簿・確定申告のメリット (${cur.taxPolicy})',
                      zh: '小微企业收支简易台账指南 (${cur.taxPolicy})',
                      vi: 'Tại sao nên ghi sổ thu chi (${cur.taxPolicy})',
                      es: 'Por qué llevar Libro Contable (${cur.taxPolicy})',
                    ),
                    body: LocalizationService.pick(
                      ko: '수입과 운영 경비(임대료, 강사료, 교재비)를 날짜순으로 자동 정리해 두면 세무 신고 및 회계사 전달 시 즉시 활용할 수 있습니다.',
                      en: 'Logging studio tuition revenue alongside deductible expenses (rent, equipment, supplies, contractor payouts) keeps your bookkeeping audit-ready year-round.',
                      ja: '売上と経費（家賃・教材費・講師報酬など）を日付順で記録しておくことで、青色申告・白色申告や税理士への共有がスムーズになります。',
                      zh: '按日期顺畅记录营收流水与房租、教材、讲师薪酬等可抵扣成本，年底报税与财务对账一目了然。',
                      vi: 'Ghi chép doanh thu học phí và chi phí thuê mặt bằng, tài liệu, lương giáo viên giúp quyết toán thuế dễ dàng.',
                      es: 'Registrar tus ingresos y gastos deducibles (alquiler, material, colaboradores) facilita el cierre fiscal anual.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.savings_outlined,
                    iconColor: const Color(0xFF16A34A),
                    bgColor: const Color(0xFFF0FDF4),
                    borderColor: const Color(0xFFBBF7D0),
                    title: LocalizationService.pick(
                      ko: '비용 공제 및 CSV 활용 팁',
                      en: '3 Tax & Bookkeeping Advantages',
                      ja: '帳簿付け・CSV活用の3大メリット',
                      zh: '规范记账与 CSV 导出的 3 大优势',
                      vi: '3 lợi ích khi ghi sổ & xuất CSV',
                      es: '3 Ventajas Contables Clave',
                    ),
                    body: LocalizationService.pick(
                      ko: '1. 누락 없는 경비 증빙 정리\n2. 강사 정산 내역(${LocalizationService.withholdingDescription}) 자동 계산\n3. UTF-8 CSV 1초 추출로 세무·회계 비용 절감',
                      en: '1. Maximize legitimate operating expense deductions\n'
                          '2. Track contractor payouts cleanly (${LocalizationService.withholdingDescription})\n'
                          '3. One-tap UTF-8 CSV export compatible with Excel, QuickBooks, and Xero',
                      ja: '1. 経費（家賃・消耗品・備品）の計上漏れ防止\n'
                          '2. 講師報酬の計算サポート（${LocalizationService.withholdingDescription}）\n'
                          '3. Excel対応UTF-8 CSV出力で記帳・確定申告の負担を軽減',
                      zh: '1. 租金、教材、耗材与运营成本完整抵扣不遗漏\n'
                          '2. 合作讲师劳务费自动核算（${LocalizationService.withholdingDescription}）\n'
                          '3. 一键导出 Excel 兼容 UTF-8 CSV，会计对账零障碍',
                      vi: '1. Đầy đủ hóa đơn khấu trừ chi phí thuê phòng, vật tư\n'
                          '2. Tính toán minh bạch lương giảng viên (${LocalizationService.withholdingDescription})\n'
                          '3. Xuất CSV chuẩn UTF-8 mở trực tiếp bằng Excel hoặc gửi kế toán',
                      es: '1. Deduce alquileres, suministros y equipamiento sin olvidos\n'
                          '2. Controla pagos a colaboradores (${LocalizationService.withholdingDescription})\n'
                          '3. Exporta en CSV UTF-8 listo para Excel o tu gestor fiscal',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildSectionHeader(LocalizationService.pick(
                    ko: '📅 지역/국가 기준 주요 포인트',
                    en: '📅 Regional Filing Highlights (${cur.code})',
                    ja: '📅 主な申告・実務スケジュール (${cur.code})',
                    zh: '📅 适用税制关键要点 (${cur.code})',
                    vi: '📅 Lưu ý kê khai theo khu vực (${cur.code})',
                    es: '📅 Puntos Clave Fiscales (${cur.code})',
                  )),
                  const SizedBox(height: 8),
                  _buildScheduleTile(
                    badge: cur.code,
                    badgeColor: const Color(0xFF4F46E5),
                    title: cur.taxPolicy,
                    desc: LocalizationService.pick(
                      ko: '설정된 통화(${cur.code})의 세무 기준에 맞춰 지출 증빙 및 강사 정산 비율(${(LocalizationService.defaultWithholdingRate * 100).toStringAsFixed(1)}%)이 자동 적용됩니다.',
                      en: 'Withholding rate (${(LocalizationService.defaultWithholdingRate * 100).toStringAsFixed(LocalizationService.defaultWithholdingRate == 0.1021 ? 2 : 1)}%) and receipt categories adapt to your selected country.',
                      ja: '選択中の通貨(${cur.code})に合わせ、源泉徴収率(${(LocalizationService.defaultWithholdingRate * 100).toStringAsFixed(LocalizationService.defaultWithholdingRate == 0.1021 ? 2 : 1)}%)や証憑分類が自動調整されます。',
                      zh: '系统已根据当前货币(${cur.code})自动适配预扣税率 (${(LocalizationService.defaultWithholdingRate * 100).toStringAsFixed(1)}%) 与凭证类型。',
                      vi: 'Tỷ lệ khấu trừ (${(LocalizationService.defaultWithholdingRate * 100).toStringAsFixed(1)}%) và chứng từ tự động điều chỉnh theo ${cur.code}.',
                      es: 'La retención (${(LocalizationService.defaultWithholdingRate * 100).toStringAsFixed(1)}%) y comprobantes se adaptan a ${cur.code}.',
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    icon: Icons.warning_amber_rounded,
                    iconColor: const Color(0xFFD97706),
                    bgColor: const Color(0xFFFFFBEB),
                    borderColor: const Color(0xFFFDE68A),
                    title: LocalizationService.pick(
                      ko: '증빙 및 CSV 호환 안내',
                      en: 'Receipt Keeping & Accountant Handoff',
                      ja: '領収書保管・税理士共有のヒント',
                      zh: '票据归档与对账提示',
                      vi: 'Lưu chứng từ & gửi kế toán',
                      es: 'Conservación de Recibos',
                    ),
                    body: LocalizationService.pick(
                      ko: '체크앤페이 CSV 내보내기 파일은 Excel / Google Sheets와 완벽 호환되므로 월말이나 분기별로 백업해 두세요.',
                      en: 'Export your Ledger CSV monthly or quarterly to store alongside bank statements. Consult a licensed CPA / tax advisor for final local filings.',
                      ja: '毎月または四半期ごとにCSVをエクスポートし、通帳明細とあわせて保管してください。最終的な申告は税理士等にご確認ください。',
                      zh: '建议按月或按季度导出 CSV 对账单并与银行流水一并保存，正式申报请以当地执业会计师指导为准。',
                      vi: 'Nên xuất tệp CSV hàng tháng hoặc hàng quý lưu cùng sao kê ngân hàng để phục vụ quyết toán.',
                      es: 'Exporta tu libro CSV cada mes o trimestre para conservarlo junto con tus extractos bancarios.',
                    ),
                  ),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom Action
          Container(
            padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
            ),
            child: ResponsiveDialogActions(
              breakpoint: 340,
              primaryFirstInColumn: false,
              secondary: portalUrl.isEmpty
                  ? null
                  : OutlinedButton.icon(
                      onPressed: () async {
                        final uri = Uri.parse(portalUrl);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      },
                      icon: const Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFF4F46E5)),
                      label: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isKoreaKr
                              ? '국세청 홈택스 바로가기'
                              : LocalizationService.pick(
                                  ko: '공식 세무 포털 열기',
                                  en: 'Official Tax Portal',
                                  ja: '公式税務ポータルを開く',
                                  zh: '访问官方税务门户',
                                  vi: 'Mở cổng thông tin thuế',
                                  es: 'Portal Fiscal Oficial',
                                ),
                          style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4F46E5)),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        side: const BorderSide(color: Color(0xFFC7D2FE)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
              primary: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: Text(LocalizationService.tr('btn_confirm'), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      );
  }

  Widget _buildSectionHeader(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required Color iconColor,
    required Color bgColor,
    required Color borderColor,
    required String title,
    required String body,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: iconColor),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: const TextStyle(fontSize: 12.5, color: Color(0xFF334155), height: 1.45),
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleTile({
    required String badge,
    required Color badgeColor,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: badgeColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              badge,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: badgeColor),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 3),
                Text(
                  desc,
                  style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

