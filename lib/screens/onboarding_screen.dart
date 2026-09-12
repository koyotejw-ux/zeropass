import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _currentPage = 0;

  final List<OnboardingPageData> _pages = [
    const OnboardingPageData(
      icon: Icons.waving_hand_rounded,
      tag: '반가워요 사장님! 👋',
      title: '서버비 0원 출결·장부 비서\n펭귄 패시예요! 🐧',
      subtitle: '학원, 공방, PT, 필라테스, 스터디룸 등\n모든 1인 사장님과 강사님을 위해 태어났어요.\n월 고정비 없이 스마트폰 하나로 가볍게 시작해요!',
      highlightText: '월 0원 평생 무료 · 100% 로컬 암호화',
    ),
    const OnboardingPageData(
      icon: Icons.touch_app_rounded,
      tag: '1초 출결 & 자동 차감 ✨',
      title: '회원 터치 한 번으로\n출석 체크와 잔여 횟수 차감!',
      subtitle: '수강생이나 회원이 오면 [체크인]만 누르세요.\n출석 일시 기록과 잔여 회차가 1초 만에 깔끔하게 정리돼요.',
      highlightText: '정기권(무제한) · 횟수권(자동 차감) 완벽 지원',
    ),
    const OnboardingPageData(
      icon: Icons.chat_bubble_outline_rounded,
      tag: '비용 0원 무제한 문자 💬',
      title: '내 폰 기본 문자로 전송!\n통신비 0원으로 안심 알림',
      subtitle: '등·하원 알림, 수업 완료 안내, 수강료 청구서까지!\n유료 문자 서버를 거치지 않고 내 스마트폰 문자 앱으로 무제한 발송해요.',
      highlightText: '80자 제한 없는 장문(LMS) · 박스 서식 온전 전송',
    ),
    const OnboardingPageData(
      icon: Icons.receipt_long_rounded,
      tag: '청구 & 은행 입금 자동화 💰',
      title: '스마트 수납 장부와\n은행 입금 자동 감지 비서',
      subtitle: '계좌번호 복사링크와 토스 송금링크가 담긴 청구서를 보내고,\n은행 앱 입금 알림으로 미납과 완납을 자동 정리하세요.',
      highlightText: '엑셀(CSV) 내보내기 · 1초 리마인드 재청구',
    ),
    const OnboardingPageData(
      icon: Icons.security_rounded,
      tag: '100% 안심 로컬 금고 🛡️',
      title: '외부 서버 전송 0%!\n오직 사장님 기기에만 암호화',
      subtitle: '회원 정보와 장부 데이터가 외부 서버로 절대 새어 나가지 않아요.\n원할 땐 언제든 카톡이나 드라이브로 백업·복원할 수 있어요.',
      highlightText: '서버 유출 원천 차단 · 오프라인 완벽 작동',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            return isLandscape ? _buildLandscapeLayout() : _buildPortraitLayout();
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout() {
    final page = _pages[_currentPage];

    return Column(
      children: [
        // Top App Bar Area: Indicator & Skip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Page step badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentPage + 1} / ${_pages.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              // Skip Button
              TextButton(
                onPressed: widget.onFinish,
                child: const Text(
                  '건너뛰기',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Scrollable Main Content (작은 폰이나 폴드 외부 화면에서도 짤리지 않음)
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                const SizedBox(height: 10),
                // Mascot Image with Soft Floating Halo & Action Badge
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 170,
                      height: 170,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1E293B),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryBlue.withValues(alpha: 0.22),
                            blurRadius: 28,
                            spreadRadius: 4,
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
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppTheme.softMint,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Icon(page.icon, size: 22, color: Colors.white),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Tag
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.chipBackground,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    page.tag,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.primaryBlue,
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Title
                Text(
                  page.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.6,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 12),

                // Subtitle
                Text(
                  page.subtitle,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14.5,
                    color: AppTheme.textSecondary,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 16),

                // Key Highlight Pill
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AppTheme.softMint),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          page.highlightText,
                          style: const TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334155),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Bottom Controls
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            children: [
              // Page Indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _pages.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: _currentPage == index ? 24 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: _currentPage == index ? AppTheme.primaryBlue : AppTheme.borderSubtle,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (_currentPage < _pages.length - 1) {
                      setState(() => _currentPage++);
                    } else {
                      widget.onFinish();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: Text(
                    _currentPage == _pages.length - 1 ? '제로패스 100% 무료 시작하기' : '다음 알아보기',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout() {
    final page = _pages[_currentPage];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          // Left: Mascot Character
          Expanded(
            flex: 1,
            child: Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 170,
                    height: 170,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF1E293B),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                          blurRadius: 20,
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
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: AppTheme.softMint,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(page.icon, size: 20, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Right: Texts & Actions
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      page.tag,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    page.title,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    page.subtitle,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Indicators
                      Row(
                        children: List.generate(
                          _pages.length,
                          (index) => AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            margin: const EdgeInsets.only(right: 6),
                            width: _currentPage == index ? 20 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _currentPage == index ? AppTheme.primaryBlue : AppTheme.borderSubtle,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: () {
                          if (_currentPage < _pages.length - 1) {
                            setState(() => _currentPage++);
                          } else {
                            widget.onFinish();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: Text(
                          _currentPage == _pages.length - 1 ? '시작하기' : '다음',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class OnboardingPageData {
  final IconData icon;
  final String title;
  final String subtitle;
  final String tag;
  final String highlightText;

  const OnboardingPageData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.highlightText,
  });
}
