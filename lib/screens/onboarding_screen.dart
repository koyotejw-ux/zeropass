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
      title: '반가워요! 제로패스 마스코트 패시예요',
      subtitle: '학원, 공방, PT, 레슨 등 모든 1인 및 소상공인 대표님을 위한\n서버비 0원 로컬 안심 출결·장부 비서예요.',
      tag: '안녕하세요 👋',
    ),
    const OnboardingPageData(
      title: '터치 한 번으로 출결 & 잔여 회차 자동 차감',
      subtitle: '학생이나 회원이 오면 [체크인]만 누르세요!\n출결 기록과 잔여 횟수가 1초 만에 깔끔하게 정리돼요.',
      tag: '간편 출결 ✨',
    ),
    const OnboardingPageData(
      title: '부모님 안심 문자 & 수강료 청구서 발송',
      subtitle: '등·하원 문자 알림과 수강료 청구 문자를\n비용 0원으로 기본 문자 앱에서 바로 전송할 수 있어요.',
      tag: '0원 문자 💬',
    ),
    const OnboardingPageData(
      title: '모든 데이터는 대표님의 폰에만 암호화 보관',
      subtitle: '원격 서버로 데이터를 보내지 않아 서버비가 들지 않고,\n개인정보 유출 걱정 없이 안전하게 금고에 지켜드려요.',
      tag: '100% 프라이버시 🛡️',
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

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Column(
        children: [
          // Skip Button
          Align(
            alignment: Alignment.topRight,
            child: TextButton(
              onPressed: widget.onFinish,
              child: const Text('건너뛰기', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
            ),
          ),
          const Spacer(),

          // Mascot Image with Soft Floating Halo
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFEFF6FF),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryBlue.withAlpha((255 * 0.15).round()),
                  blurRadius: 30,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                'assets/icons/mascot_passy.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 32),

          // Tag
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.chipBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              page.tag,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
            ),
          ),
          const SizedBox(height: 14),

          // Title & Subtitle
          Text(
            page.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              letterSpacing: -0.6,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            page.subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const Spacer(),

          // Page Indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _pages.length,
              (index) => Container(
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
          const SizedBox(height: 24),

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
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: Text(
                _currentPage == _pages.length - 1 ? '제로패스 지금 시작하기' : '다음으로',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
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
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFEFF6FF),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.primaryBlue.withAlpha((255 * 0.15).round()),
                      blurRadius: 20,
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/icons/mascot_passy.png',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 24),

          // Right: Texts & Actions
          Expanded(
            flex: 1,
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
                    fontSize: 20,
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
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    // Indicators
                    Row(
                      children: List.generate(
                        _pages.length,
                        (index) => Container(
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
        ],
      ),
    );
  }
}

class OnboardingPageData {
  final String title;
  final String subtitle;
  final String tag;

  const OnboardingPageData({
    required this.title,
    required this.subtitle,
    required this.tag,
  });
}
