import 'package:flutter/material.dart';
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
    final mediaQuery = MediaQuery.of(context);
    final isCompact = mediaQuery.size.width < 360;

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
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.primaryBlue.withAlpha(80), width: 1.5),
                ),
                child: const Icon(
                  Icons.elderly_rounded,
                  color: AppTheme.trustBlue,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '어르신 원장님 큰글씨 사용 안내',
                      style: TextStyle(
                        fontSize: isCompact ? 18 : 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        letterSpacing: -0.4,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      '돋보기 없이도 3초 만에 끝내는 쉬운 사용법',
                      style: TextStyle(
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
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              _buildStepCard(
                stepNumber: '1',
                icon: Icons.check_circle_rounded,
                iconColor: const Color(0xFF059669),
                title: '오늘 온 학생 출석 찍기',
                description:
                    '화면 상단의 [📌 큰글씨 간편 출석]을 누르면 학생 이름이 아주 크게 나옵니다.\n학생 이름 옆의 초록색 [출석 완료] 버튼만 누르면 바로 출석 체크가 끝납니다.',
                tip: '💡 학생이 직접 번호를 누르게 하려면 [무인 키오스크]를 켜두시면 됩니다.',
              ),
              const SizedBox(height: 14),
              _buildStepCard(
                stepNumber: '2',
                icon: Icons.mark_email_read_rounded,
                iconColor: AppTheme.trustBlue,
                title: '이번 달 수강료(회비) 문자 보내기',
                description:
                    '화면 상단의 [💌 회비(수강료) 문자]를 누르면 이번 달 회비를 아직 안 낸 학생 명단이 나옵니다.\n파란색 [문자 보내기] 버튼을 누르면 원장님의 수납 계좌번호와 금액이 적힌 문자가 바로 만들어집니다.',
                tip: '💡 카카오톡이나 일반 문자(SMS) 중 편한 방식으로 무료 전송됩니다.',
              ),
              const SizedBox(height: 14),
              _buildStepCard(
                stepNumber: '3',
                icon: Icons.phone_in_talk_rounded,
                iconColor: const Color(0xFFD97706),
                title: '학생이나 학부모님께 바로 전화 걸기',
                description:
                    '[📞 원생·학부모 전화]를 누르고 이름 옆의 [전화 걸기] 버튼을 누르면 스마트폰 통화 화면으로 바로 연결됩니다.\n연락처를 찾거나 번호를 외우실 필요가 없습니다.',
                tip: '💡 학부모님 번호가 등록되어 있으면 부모님께 먼저 전화가 걸립니다.',
              ),
              const SizedBox(height: 14),
              _buildStepCard(
                stepNumber: '4',
                icon: Icons.zoom_in_rounded,
                iconColor: const Color(0xFF7C3AED),
                title: '글씨 크기 및 원래 모드로 돌아가기',
                description:
                    '화면 오른쪽 위의 [👓 큰글씨 ON] 버튼을 누르면 언제든지 보통 글씨 화면으로 돌아갈 수 있습니다.\n[설정] 메뉴에서도 원하실 때 언제든 켜고 끄실 수 있습니다.',
                tip: '💡 눈이 침침하실 땐 언제든 켜두시면 글씨가 1.4배 커져 편안합니다.',
              ),
            ],
          ),
        ),
        // Bottom Confirm Button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
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
              child: const Text(
                '확인했습니다 (닫기)',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
