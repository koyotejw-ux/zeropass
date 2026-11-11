import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import '../widgets/mascot_avatar.dart';
import '../widgets/region_language_picker.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  final VoidCallback onFinish;
  const OnboardingScreen({super.key, required this.onFinish});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  int _currentPage = 0;

  List<OnboardingPageData> _buildPages() {
    return [
      OnboardingPageData(
        icon: Icons.domain_verification_rounded,
        tag: LocalizationService.tr('onb_slide1_badge'),
        title: LocalizationService.tr('onb_slide1_title'),
        subtitle: LocalizationService.tr('onb_slide1_desc'),
        highlightText: LocalizationService.isDomestic
            ? '기본 기능 0원 무료 이용 · 100% 독립 로컬 보안'
            : 'Free Starter Plan · 100% Private Local DB',
      ),
      OnboardingPageData(
        icon: Icons.touch_app_rounded,
        tag: LocalizationService.tr('onb_slide2_badge'),
        title: LocalizationService.tr('onb_slide2_title'),
        subtitle: LocalizationService.tr('onb_slide2_desc'),
        highlightText:
            '${LocalizationService.tr('billing_type_monthly')} · ${LocalizationService.tr('billing_type_session')}',
      ),
      OnboardingPageData(
        icon: Icons.chat_bubble_outline_rounded,
        tag: LocalizationService.tr('onb_slide3_badge'),
        title: LocalizationService.tr('onb_slide3_title'),
        subtitle: LocalizationService.tr('onb_slide3_desc'),
        highlightText: LocalizationService.currentCurrency.paymentChannelsSummary,
      ),
      OnboardingPageData(
        icon: Icons.receipt_long_rounded,
        tag: LocalizationService.tr('onb_slide4_badge'),
        title: LocalizationService.tr('onb_slide4_title'),
        subtitle: LocalizationService.tr('onb_slide4_desc'),
        highlightText: LocalizationService.currentCurrency.taxPolicy,
      ),
      OnboardingPageData(
        icon: Icons.security_rounded,
        tag: LocalizationService.tr('onb_slide5_badge'),
        title: LocalizationService.tr('onb_slide5_title'),
        subtitle: LocalizationService.tr('onb_slide5_desc'),
        highlightText: LocalizationService.tr('kiosk_mode_name'),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    ref.watch(currencyProvider);
    final pages = _buildPages();

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isLandscape = constraints.maxWidth > constraints.maxHeight;

            return isLandscape ? _buildLandscapeLayout(pages) : _buildPortraitLayout(pages);
          },
        ),
      ),
    );
  }

  Widget _buildPortraitLayout(List<OnboardingPageData> pages) {
    final page = pages[_currentPage];

    return Column(
      children: [
        // Top App Bar Area: Indicator, Region Picker & Skip
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            children: [
              // Page step badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_currentPage + 1} / ${pages.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primaryBlue,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Flexible(child: RegionLanguageChip()),
              const Spacer(),
              // Skip Button
              TextButton(
                onPressed: widget.onFinish,
                child: Text(
                  LocalizationService.tr('onb_skip'),
                  style: const TextStyle(
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
                    ZeroPassMascotAvatar(
                      size: 170,
                      isLightMode: true,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.22),
                          blurRadius: 28,
                          spreadRadius: 4,
                        ),
                      ],
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
                    pages.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 22 : 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: _currentPage == index ? AppTheme.primaryDark : AppTheme.borderSubtle,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),

                // Action Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      if (_currentPage < pages.length - 1) {
                        setState(() => _currentPage++);
                      } else {
                        widget.onFinish();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryDark,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text(
                      _currentPage == pages.length - 1
                          ? LocalizationService.tr('onb_start')
                          : LocalizationService.tr('onb_next'),
                      style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, letterSpacing: -0.2),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLandscapeLayout(List<OnboardingPageData> pages) {
    final page = pages[_currentPage];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: Row(
        children: [
          // Left: Mascot Character
          Expanded(
            flex: 1,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const RegionLanguageChip(),
                const SizedBox(height: 12),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ZeroPassMascotAvatar(
                      size: 155,
                      isLightMode: true,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.primaryBlue.withValues(alpha: 0.25),
                          blurRadius: 20,
                        ),
                      ],
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
              ],
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
                          pages.length,
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
                          if (_currentPage < pages.length - 1) {
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
                          _currentPage == pages.length - 1
                              ? LocalizationService.tr('onb_start')
                              : LocalizationService.tr('onb_next'),
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
