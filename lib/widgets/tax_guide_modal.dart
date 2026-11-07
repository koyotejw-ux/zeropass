import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../theme/app_theme.dart';

class TaxGuideModal extends StatelessWidget {
  const TaxGuideModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const TaxGuideModal(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
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
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '국세청 간편장부 & 세무 꿀팁',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '소상공인 원장님을 위한 1분 세무 마스터 가이드',
                        style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, size: 20, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 20, color: AppTheme.borderSubtle),

          // Scrollable content
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              children: [
                // 1. 간편장부란?
                _buildInfoCard(
                  icon: Icons.help_outline_rounded,
                  iconColor: AppTheme.primaryBlue,
                  bgColor: const Color(0xFFEFF6FF),
                  borderColor: const Color(0xFFBFDBFE),
                  title: '국세청 표준 사업소득 간편장부란?',
                  body: '소규모 사업자(학원, 교습소, 체육시설, 필라테스 등 수입 7,500만원 미만)를 위해 국세청에서 특별히 고안한 표준 장부입니다. 복식부기(차변/대변)의 어려운 회계 지식 없이도 수입과 비용을 날짜순으로만 적으면 세법상 100% 인정됩니다.',
                ),
                const SizedBox(height: 12),

                // 2. 3대 절세 혜택
                _buildInfoCard(
                  icon: Icons.savings_outlined,
                  iconColor: const Color(0xFF16A34A),
                  bgColor: const Color(0xFFF0FDF4),
                  borderColor: const Color(0xFFBBF7D0),
                  title: '간편장부 작성 시 원장님 3대 혜택',
                  body: '1. 무기장 가산세(산출세액의 20%) 완전 면제\n'
                      '2. 임대료, 강사료, 비품 등 실제 지출 경비 100% 인정으로 소득세 절세\n'
                      '3. 엑셀(CSV) 원클릭 추출로 세무사 기장 수수료 절감',
                ),
                const SizedBox(height: 12),

                // 3. 주요 세무 일정 캘린더
                _buildSectionHeader('📅 놓치면 안 되는 원장님 세무 캘린더'),
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

                // 4. 세무 증빙 3만원 주의사항
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
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Bottom Action
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: AppTheme.borderSubtle)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final uri = Uri.parse('https://www.hometax.go.kr');
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 15, color: Color(0xFF4F46E5)),
                    label: const Text('국세청 홈택스 바로가기', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF4F46E5))),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: const BorderSide(color: Color(0xFFC7D2FE)),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('확인', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ],
      ),
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

