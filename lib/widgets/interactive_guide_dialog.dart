import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

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

  final List<GuideStepItem> _steps = const [
    GuideStepItem(
      title: '1단계: 내 스튜디오 & 입금 계좌 설정하기',
      description: '청구서 및 출결 알림 문자에 표시될 상호명과 원장님 성함, 수강료를 입금받을 은행 계좌를 먼저 등록해 볼까요?',
      actionLabel: '내 스튜디오 정보 설정하러 가기',
      tip: '설정 탭에서 1분 만에 등록할 수 있어요!',
      icon: Icons.account_balance_outlined,
    ),
    GuideStepItem(
      title: '2단계: 실제 첫 회원 등록하기',
      description: '회원의 이름, 연락처, 소속 클래스(예: 중등수학, 기구필라테스, 피아노반)와 회차권/정기권 수강료를 등록해 볼까요?',
      actionLabel: '신규 회원 직접 등록하기',
      tip: '등록된 회원에게는 바로 안심 문자를 보낼 수 있어요!',
      icon: Icons.person_add_alt_1_outlined,
    ),
    GuideStepItem(
      title: '3단계: 1초 만에 출결 체크 & 안심 문자 발송',
      description: '회원이 오면 [체크인] 버튼을 눌러보세요! 잔여 회차가 1회 차감되고, 비용 0원으로 부모님께 등원 알림 문자를 보낼 수 있어요.',
      actionLabel: '패스 체크 탭에서 체험하기',
      tip: '문자는 내 스마트폰의 무제한 기본 문자로 발송되어 요금이 0원이에요!',
      icon: Icons.check_circle_outline,
    ),
    GuideStepItem(
      title: '4단계: 수강료 청구서 작성 & 스마트 수납',
      description: '두 번째 탭에서 청구서를 만들고 [청구 문자 전송]을 누르면 완성! 은행 앱에서 입금 푸시가 오면 장부에 자동 체크돼요.',
      actionLabel: '청구·수납 탭 둘러보기',
      tip: '카카오페이/토스/제로페이 QR, 지역화폐 결제도 모두 지원해요!',
      icon: Icons.receipt_long_outlined,
    ),
    GuideStepItem(
      title: '5단계: 준비 완료! 실제 데이터로 전환',
      description: '충분히 둘러보셨나요? 연습용 가상 데이터는 버튼 하나로 깨끗하게 비우고, 대표님의 진짜 학원/스튜디오 운영을 시작하세요!',
      actionLabel: '연습 데이터 비우고 시작하기',
      tip: '언제든 설정 탭에서 다시 연습 데이터를 불러올 수도 있어요.',
      icon: Icons.rocket_launch_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final step = _steps[_currentStep];

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            // Top Header: Mascot Passy winking face + Step indicator
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1E293B),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryBlue.withAlpha((255 * 0.2).round()),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/icons/splash_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
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
                              'STEP ${_currentStep + 1} / ${_steps.length}',
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                          const Text(
                            '패시의 실전 튜토리얼',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      const Text(
                        '하나씩 따라 해볼까요?',
                        style: TextStyle(
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
                value: (_currentStep + 1) / _steps.length,
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
                      title: const Text('연습 데이터를 비우시겠습니까?'),
                      content: const Text(
                        '연습용 가상 데이터 5명을 모두 지우고 대표님의 실제 회원만 등록할 수 있는 깨끗한 상태로 만듭니다.\n(언제든 설정 탭에서 연습 데이터를 다시 불러올 수 있습니다.)',
                        style: TextStyle(height: 1.5, fontSize: 13),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(c, false),
                          child: const Text('취소'),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(c, true),
                          style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                          child: const Text('비우고 시작하기'),
                        ),
                      ],
                    ),
                  );

                  if (confirm == true && mounted) {
                    final db = ref.read(databaseServiceProvider);
                    await db.clearAllData();
                    await ref.read(membersProvider.notifier).reload();
                    await ref.read(passRecordsProvider.notifier).reload();
                    await ref.read(invoicesProvider.notifier).reload();
                    if (context.mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('가상 데이터가 모두 비워졌습니다. 이제 대표님의 진짜 회원을 등록해 보세요!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  }
                } else {
                  // Next step
                  if (_currentStep < _steps.length - 1) {
                    setState(() => _currentStep++);
                  } else {
                    Navigator.pop(context);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryDark,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    step.actionLabel,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Bottom Navigation buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_currentStep > 0)
                  TextButton(
                    onPressed: () => setState(() => _currentStep--),
                    child: const Text('이전 단계', style: TextStyle(color: AppTheme.textSecondary)),
                  )
                else
                  const SizedBox(width: 80),
                if (_currentStep < _steps.length - 1)
                  TextButton(
                    onPressed: () => setState(() => _currentStep++),
                    child: const Text('다음 단계로 넘어가기', style: TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                  )
                else
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('닫기', style: TextStyle(color: AppTheme.textSecondary)),
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
