import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';

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
  String _selectedBank = '토스뱅크';
  final TextEditingController _accountNumberCtrl = TextEditingController();
  final TextEditingController _accountHolderCtrl = TextEditingController();
  final List<String> _bankPresets = [
    '토스뱅크',
    '카카오뱅크',
    '국민은행',
    '신한은행',
    '우리은행',
    '하나은행',
    '농협은행',
    '기업은행',
  ];

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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
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
                icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textPrimary, size: 20),
                onPressed: _prevStep,
              )
            : null,
        title: Row(
          children: [
            for (int i = 0; i < 3; i++)
              Expanded(
                child: Container(
                  height: 4,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: i <= _currentStep ? AppTheme.primaryBlue : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: widget.onFinish,
            child: const Text('체험 둘러보기', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
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
            // Toss-style Dynamic CTA button that rises right above the keyboard without overlap
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
                height: 54,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _nextStep,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                        )
                      : Text(
                          _currentStep == 2 ? '등록 완료하고 시작하기 🎉' : '다음으로 넘어가기',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
          const SizedBox(height: 12),
          // Mascot passy avatar
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1E293B),
            ),
            child: ClipOval(
              child: Image.asset('assets/icons/splash_icon.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'STEP 1 / 3',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 6),
          const Text(
            '우리 매장(학원·스튜디오)의\n이름은 무엇인가요?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              height: 1.3,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '청구서 문자와 안심 출결 알림에 상호명으로 표기돼요.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 28),

          AppTextField(
            controller: _studioNameCtrl,
            label: '상호명 / 학원명',
            hint: '예: 패시 피아노 스튜디오',
            prefixIcon: Icons.storefront_outlined,
            autofocus: true,
          ),
          const SizedBox(height: 18),

          const Text(
            '사업장 업종 카테고리',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            '선택한 업종에 맞춰 회원 및 출결 관리 기본값이 최적화됩니다.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: StudioProfile.businessCategories.map((cat) {
              final isSelected = _selectedCategory == cat;
              return ChoiceChip(
                label: Text(cat, style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textPrimary,
                )),
                selected: isSelected,
                selectedColor: AppTheme.primaryBlue,
                backgroundColor: const Color(0xFFF1F5F9),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedCategory = cat;
                      if (cat != '기타 / 맞춤업종' && _studioNameCtrl.text.isEmpty) {
                        _studioNameCtrl.text = '나의 $cat';
                      }
                    });
                  }
                },
              );
            }).toList(),
          ),
          if (_selectedCategory == '기타 / 맞춤업종') ...[
            const SizedBox(height: 12),
            AppTextField(
              controller: _customCategoryCtrl,
              label: '직접 입력 카테고리',
              hint: '예: 바리스타 학원, 가죽 공방, 보컬 레슨',
              prefixIcon: Icons.category_outlined,
            ),
          ],
          const SizedBox(height: 18),

          const Text(
            '자주 사용하는 상호명 칩 (터치하면 자동 입력)',
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _studioPresets.map((preset) {
              return ActionChip(
                backgroundColor: const Color(0xFFF1F5F9),
                label: Text(preset, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                onPressed: () {
                  setState(() {
                    _studioNameCtrl.text = preset;
                  });
                },
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
          const SizedBox(height: 12),
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1E293B),
            ),
            child: ClipOval(
              child: Image.asset('assets/icons/splash_icon.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'STEP 2 / 3',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 6),
          const Text(
            '수납/회비를 입금받으실\n계좌를 등록해 주세요',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              height: 1.3,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '청구 문자를 보낼 때 토스 송금링크와 함께 0원 자동 첨부돼요.',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 24),

          const Text(
            '입금 은행 선택',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _bankPresets.map((bank) {
              final isSelected = _selectedBank == bank;
              return ChoiceChip(
                label: Text(bank),
                selected: isSelected,
                selectedColor: AppTheme.primaryBlue.withAlpha((255 * 0.15).round()),
                labelStyle: TextStyle(
                  color: isSelected ? AppTheme.primaryBlue : AppTheme.textPrimary,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                  fontSize: 13,
                ),
                onSelected: (val) {
                  if (val) {
                    setState(() {
                      _selectedBank = bank;
                    });
                  }
                },
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
          const SizedBox(height: 12),
          Container(
            width: 60,
            height: 60,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Color(0xFF1E293B),
            ),
            child: ClipOval(
              child: Image.asset('assets/icons/splash_icon.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'STEP 3 / 3',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
          ),
          const SizedBox(height: 6),
          const Text(
            '첫 번째 수강생(회원)을\n한 명만 등록해 볼까요?',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
              height: 1.3,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '이름과 연락처만 넣어도 바로 출결 체크를 해볼 수 있어요!',
            style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
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
            label: '연락처 (안심 알림·청구 문자용)',
            hint: '예: 010-1234-5678',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _memberGroupCtrl,
            label: '수업/클래스 그룹',
            hint: '예: 기초 입문반, 월수금 저녁반',
            prefixIcon: Icons.group_outlined,
          ),
          const SizedBox(height: 16),

          const Text(
            '패스 결제 방식',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('회차 차감형 (10회 등)')),
                  selected: _billingType == BillingType.sessionBased,
                  selectedColor: AppTheme.primaryBlue.withAlpha((255 * 0.15).round()),
                  labelStyle: TextStyle(
                    color: _billingType == BillingType.sessionBased ? AppTheme.primaryBlue : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _billingType = BillingType.sessionBased);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceChip(
                  label: const Center(child: Text('월 정기권 (정액제)')),
                  selected: _billingType == BillingType.monthlyRecurring,
                  selectedColor: AppTheme.primaryBlue.withAlpha((255 * 0.15).round()),
                  labelStyle: TextStyle(
                    color: _billingType == BillingType.monthlyRecurring ? AppTheme.primaryBlue : AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  onSelected: (val) {
                    if (val) setState(() => _billingType = BillingType.monthlyRecurring);
                  },
                ),
              ),
            ],
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
