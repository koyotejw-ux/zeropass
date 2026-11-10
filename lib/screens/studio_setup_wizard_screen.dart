import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/database_service.dart';
import '../services/localization_service.dart';
import '../services/monetization_service.dart';
import '../services/schedule_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/mascot_avatar.dart';

class StudioSetupWizardScreen extends ConsumerStatefulWidget {
  final VoidCallback onFinish;

  const StudioSetupWizardScreen({super.key, required this.onFinish});

  @override
  ConsumerState<StudioSetupWizardScreen> createState() => _StudioSetupWizardScreenState();
}

class _StudioSetupWizardScreenState extends ConsumerState<StudioSetupWizardScreen> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // STEP 1: Studio Name & Category
  final TextEditingController _studioNameCtrl = TextEditingController();
  String _selectedCategory = '음악 / 피아노';
  final TextEditingController _customCategoryCtrl = TextEditingController();
  final List<String> _studioPresets = [
    '피아노 음악학원',
    '멘토스 수학학원',
    '필라테스 스튜디오',
    '1:1 바디 PT샵',
    '도예 공방',
    '태권도장',
    '발레 / 댄스스쿨',
    '어린이 미술학원',
    '보컬 / 실용음악',
    '코딩 / 컴퓨터학원',
  ];

  // STEP 2: Bank Account
  late String _selectedBank = LocalizationService.getBankPresets().first;
  final TextEditingController _accountNumberCtrl = TextEditingController();
  final TextEditingController _accountHolderCtrl = TextEditingController();
  List<String> get _bankPresets => LocalizationService.getBankPresets();

  // STEP 3: First Member
  final TextEditingController _memberNameCtrl = TextEditingController();
  final TextEditingController _memberPhoneCtrl = TextEditingController();
  final TextEditingController _memberGroupCtrl = TextEditingController(text: '기초 입문반');
  final TextEditingController _memberFeeCtrl = TextEditingController(text: '250000');
  final TextEditingController _memberSessionsCtrl = TextEditingController(text: '10');
  BillingType _billingType = BillingType.sessionBased;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _pageController.dispose();
    _studioNameCtrl.dispose();
    _customCategoryCtrl.dispose();
    _accountNumberCtrl.dispose();
    _accountHolderCtrl.dispose();
    _memberNameCtrl.dispose();
    _memberPhoneCtrl.dispose();
    _memberGroupCtrl.dispose();
    _memberFeeCtrl.dispose();
    _memberSessionsCtrl.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < 2) {
      _pageController.animateToPage(
        _currentStep + 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
      setState(() {
        _currentStep++;
      });
    } else {
      _completeSetup();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) {
      _pageController.animateToPage(
        _currentStep - 1,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeInOutCubic,
      );
      setState(() {
        _currentStep--;
      });
    }
  }

  Future<void> _completeSetup() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final db = DatabaseService.instance;

      // 1. Clear any dummy demo data so the user starts totally fresh with their own data
      await db.clearAllData();
      await ScheduleService.clearSchedules();
      await MonetizationService.instance.resetMetricsForRealUsage();

      // 2. Save Studio Profile
      final defaultProfile = StudioProfile.defaultProfile();
      final finalCategory = _selectedCategory == '기타 / 맞춤업종' && _customCategoryCtrl.text.trim().isNotEmpty
          ? _customCategoryCtrl.text.trim()
          : _selectedCategory;
      final studio = StudioProfile(
        studioName: _studioNameCtrl.text.trim().isEmpty ? '나의 프라이빗 스튜디오' : _studioNameCtrl.text.trim(),
        instructorName: _accountHolderCtrl.text.trim().isEmpty ? '대표/원장' : _accountHolderCtrl.text.trim(),
        bankName: _selectedBank,
        accountNumber: _accountNumberCtrl.text.trim().isEmpty ? '3333-01-2345678' : _accountNumberCtrl.text.trim(),
        accountHolder: _accountHolderCtrl.text.trim().isEmpty ? '원장님' : _accountHolderCtrl.text.trim(),
        category: finalCategory,
        autoBankDetectEnabled: false,
        invoiceTemplate: defaultProfile.invoiceTemplate,
        attendanceTemplate: defaultProfile.attendanceTemplate,
        departureTemplate: defaultProfile.departureTemplate,
      );
      await ref.read(studioProfileProvider.notifier).updateProfile(studio);

      // 3. Register the very first real student/member if name is given
      if (_memberNameCtrl.text.trim().isNotEmpty) {
        final fee = int.tryParse(_memberFeeCtrl.text.replaceAll(',', '').trim()) ?? 250000;
        final sessions = int.tryParse(_memberSessionsCtrl.text.trim()) ?? 10;
        final member = Member(
          id: const Uuid().v4(),
          name: _memberNameCtrl.text.trim(),
          phone: _memberPhoneCtrl.text.trim().isEmpty ? '010-0000-0000' : _memberPhoneCtrl.text.trim(),
          groupName: _memberGroupCtrl.text.trim().isEmpty ? '기초 입문반' : _memberGroupCtrl.text.trim(),
          billingType: _billingType,
          defaultFee: fee,
          totalSessions: _billingType == BillingType.sessionBased ? sessions : 0,
          remainingSessions: _billingType == BillingType.sessionBased ? sessions : 0,
          registeredAt: DateTime.now(),
        );
        await ref.read(membersProvider.notifier).addMember(member);
      }

      await ref.read(membersProvider.notifier).reload();
      await ref.read(passRecordsProvider.notifier).reload();
      await ref.read(invoicesProvider.notifier).reload();
      await ref.read(vendorsProvider.notifier).reload();
      await ref.read(expensesProvider.notifier).reload();
      await ref.read(notificationLogsProvider.notifier).reload();
      await ref.read(schedulesProvider.notifier).reload();

      widget.onFinish();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('설정 저장 중 오류가 발생했습니다: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: _currentStep > 0
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.primaryDark, size: 18),
                onPressed: _prevStep,
              )
            : null,
        title: Row(
          children: [
            for (int i = 0; i < 3; i++)
              Expanded(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  height: 3.5,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: i <= _currentStep ? AppTheme.primaryDark : const Color(0xFFE4E4E7),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: widget.onFinish,
            child: const Text(
              '건너뛰기',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStep1StudioName(),
                  _buildStep2BankAccount(),
                  _buildStep3FirstMember(),
                ],
              ),
            ),
            // High-End Executive Dynamic CTA Button
            AnimatedPadding(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutQuad,
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 8,
                bottom: MediaQuery.of(context).viewInsets.bottom > 0
                    ? 10
                    : MediaQuery.of(context).viewPadding.bottom + 12,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _currentStep == 2 ? '설정 완료하고 시작하기' : '다음 단계로',
                              style: const TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Icon(
                              _currentStep == 2 ? Icons.check_circle_outline_rounded : Icons.arrow_forward_rounded,
                              size: 18,
                              color: Colors.white,
                            ),
                          ],
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // STEP 1: Studio Name
  Widget _buildStep1StudioName() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          // Luxury Obsidian Badge Emblem
          const ZeroPassMascotAvatar(
            size: 46,
            icon: Icons.storefront_rounded,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE4E4E7), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.trustBlue,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'STEP 01 · 기본 정보',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '사업장 프로필 설정',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '모바일 출결부와 수강료 청구서에 표기될 대표 상호입니다.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 26),

          AppTextField(
            controller: _studioNameCtrl,
            label: '상호명 / 스튜디오명',
            hint: '예: 아르떼 피아노 스튜디오',
            prefixIcon: Icons.storefront_outlined,
            autofocus: true,
          ),
          const SizedBox(height: 20),

          const Text(
            '업종 카테고리',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
          ),
          const SizedBox(height: 4),
          const Text(
            '선택한 업종에 맞추어 맞춤 출결·수납 서식이 자동 적용됩니다.',
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: StudioProfile.businessCategories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    if (cat != '기타 / 맞춤업종' && _studioNameCtrl.text.isEmpty) {
                      _studioNameCtrl.text = '나의 $cat';
                    }
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryDark : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryDark : const Color(0xFFE4E4E7),
                      width: 0.9,
                    ),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_selectedCategory == '기타 / 맞춤업종') ...[
            const SizedBox(height: 14),
            AppTextField(
              controller: _customCategoryCtrl,
              label: '직접 입력 카테고리',
              hint: '예: 바리스타 학원, 가죽 공방, 보컬 레슨',
              prefixIcon: Icons.category_outlined,
            ),
          ],
          const SizedBox(height: 20),

          const Text(
            '추천 상호 프리셋 (터치 시 자동 입력)',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: _studioPresets.map((preset) {
              return InkWell(
                onTap: () {
                  setState(() {
                    _studioNameCtrl.text = preset;
                  });
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F4F5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE4E4E7), width: 0.8),
                  ),
                  child: Text(
                    preset,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  // STEP 2: Bank Account
  Widget _buildStep2BankAccount() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const ZeroPassMascotAvatar(
            size: 46,
            icon: Icons.account_balance_wallet_rounded,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE4E4E7), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.trustBlue,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'STEP 02 · 정산 계좌',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '수납 정산 계좌 연동',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '수강료 청구서 발행 시 송금 링크와 함께 1초 자동 첨부됩니다.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            '입금 은행 선택',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bankPresets.map((bank) {
              final isSelected = _selectedBank == bank;
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedBank = bank;
                  });
                },
                borderRadius: BorderRadius.circular(10),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8.5),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primaryDark : const Color(0xFFFAFAFA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppTheme.primaryDark : const Color(0xFFE4E4E7),
                      width: 0.9,
                    ),
                  ),
                  child: Text(
                    bank,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      color: isSelected ? Colors.white : AppTheme.textPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          AppTextField(
            controller: _accountNumberCtrl,
            label: '계좌번호',
            hint: '예: 3333-01-2345678',
            prefixIcon: Icons.account_balance_wallet_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _accountHolderCtrl,
            label: '예금주 성함',
            hint: '예: 홍길동',
            prefixIcon: Icons.person_outline,
          ),
        ],
      ),
    );
  }

  // STEP 3: First Member
  Widget _buildStep3FirstMember() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const ZeroPassMascotAvatar(
            size: 46,
            icon: Icons.person_add_alt_1_rounded,
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE4E4E7), width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5.5,
                  height: 5.5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.trustBlue,
                  ),
                ),
                const SizedBox(width: 6),
                const Text(
                  'STEP 03 · 첫 수강생',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            '첫 번째 회원 등록',
            style: TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '등록 즉시 원터치 출결 체크와 잔여 회차 관리를 바로 시작할 수 있습니다.',
            style: TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 24),

          AppTextField(
            controller: _memberNameCtrl,
            label: '회원 이름',
            hint: '예: 김민준',
            prefixIcon: Icons.badge_outlined,
            autofocus: true,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _memberPhoneCtrl,
            label: '연락처 (안심 알림 및 청구 문자용)',
            hint: '예: 010-1234-5678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _memberGroupCtrl,
            label: '소속 클래스 / 그룹',
            hint: '예: 기초 입문반, 월수금 저녁반',
            prefixIcon: Icons.group_outlined,
          ),
          const SizedBox(height: 16),

          const Text(
            '패스 결제 방식',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: const Color(0xFFF4F4F5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE4E4E7), width: 0.8),
            ),
            child: Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _billingType = BillingType.sessionBased),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _billingType == BillingType.sessionBased ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _billingType == BillingType.sessionBased
                            ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha((255 * 0.05).round()),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '회차 차감형 (10회 등)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _billingType == BillingType.sessionBased ? FontWeight.w700 : FontWeight.w500,
                            color: _billingType == BillingType.sessionBased ? AppTheme.primaryDark : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _billingType = BillingType.monthlyRecurring),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _billingType == BillingType.monthlyRecurring ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: _billingType == BillingType.monthlyRecurring
                            ? [
                                BoxShadow(
                                  color: Colors.black.withAlpha((255 * 0.05).round()),
                                  blurRadius: 4,
                                  offset: const Offset(0, 1),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '월 정기권 (정액제)',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: _billingType == BillingType.monthlyRecurring ? FontWeight.w700 : FontWeight.w500,
                            color: _billingType == BillingType.monthlyRecurring ? AppTheme.primaryDark : AppTheme.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          if (_billingType == BillingType.sessionBased) ...[
            AppTextField(
              controller: _memberSessionsCtrl,
              label: '기본 등록 회차',
              hint: '10',
              prefixIcon: Icons.confirmation_number_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
          ],

          AppTextField(
            controller: _memberFeeCtrl,
            label: '기본 수강료 (원)',
            hint: '250000',
            prefixIcon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
