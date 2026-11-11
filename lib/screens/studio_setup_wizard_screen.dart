import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../models/member.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/database_service.dart';
import '../services/localization_service.dart';
import '../services/monetization_service.dart';
import '../services/region_workflow_service.dart';
import '../services/schedule_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/mascot_avatar.dart';
import '../widgets/region_language_picker.dart';

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

  List<String> _getLocalizedStudioPresets(AppLanguage lang) {
    switch (lang) {
      case AppLanguage.korean:
        return [
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
      case AppLanguage.english:
        return [
          'Harmony Piano Academy',
          'Apex Math Tutoring',
          'Luna Pilates Studio',
          'Prime 1:1 Fitness PT',
          'Clay & Craft Workshop',
          'Tiger Taekwondo Dojo',
          'Urban Dance Collective',
          'CodeLab Academy',
        ];
      case AppLanguage.japanese:
        return [
          'さくらピアノ教室',
          '進研ゼミ・個別学習塾',
          'ルナ ピラティススタジオ',
          'プライベートPTジム',
          '陶芸アトリエ',
          '正道空手・テコンドー道場',
        ];
      case AppLanguage.chinese:
        return [
          '星光钢琴艺术中心',
          '思源数学培优班',
          '悦心普拉提工作室',
          '极速1对1私教馆',
          '泥塑陶艺工坊',
          '尚武跆拳道馆',
        ];
      case AppLanguage.vietnamese:
        return [
          'Học viện Piano Harmony',
          'Trung tâm Toán Tư Duy',
          'Luna Pilates Studio',
          'Phòng tập PT Cá Nhân',
          'Xưởng Gốm Nghệ Thuật',
          'Võ đường Taekwondo',
        ];
      case AppLanguage.spanish:
        return [
          'Academia de Piano Sol',
          'Centro de Matemáticas',
          'Estudio Pilates Luna',
          'Gimnasio Entrenamiento 1:1',
          'Taller de Cerámica',
          'Escuela de Taekwondo',
        ];
    }
  }

  // STEP 2: Bank Account
  late String _selectedBank = LocalizationService.getBankPresets().first;
  final TextEditingController _accountNumberCtrl = TextEditingController();
  final TextEditingController _accountHolderCtrl = TextEditingController();
  List<String> get _bankPresets => LocalizationService.getBankPresets();

  // STEP 3: First Member
  final TextEditingController _memberNameCtrl = TextEditingController();
  final TextEditingController _memberPhoneCtrl = TextEditingController();
  final TextEditingController _memberGroupCtrl = TextEditingController(
    text: LocalizationService.localizeBuiltInLabel('정규반'),
  );
  final TextEditingController _memberFeeCtrl = TextEditingController(
    text: LocalizationService.currentCurrency.defaultFeeBase.toString(),
  );
  final TextEditingController _memberSessionsCtrl = TextEditingController(text: '10');
  BillingType _billingType = BillingType.sessionBased;

  bool _isSubmitting = false;

  void _syncRegionalDefaultsOnChange() {
    setState(() {
      final presets = LocalizationService.getBankPresets();
      if (!presets.contains(_selectedBank)) {
        _selectedBank = presets.first;
      }
      _memberFeeCtrl.text = LocalizationService.currentCurrency.defaultFeeBase.toString();
      _memberGroupCtrl.text = LocalizationService.localizeBuiltInLabel('정규반');
    });
  }

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
      final meta = RegionWorkflowService.defaultStudioMetadata(
        LocalizationService.currentLanguage,
        LocalizationService.currentCurrency,
      );
      final studio = StudioProfile(
        studioName: _studioNameCtrl.text.trim().isEmpty
            ? meta['studioName']!
            : _studioNameCtrl.text.trim(),
        instructorName: _accountHolderCtrl.text.trim().isEmpty
            ? meta['instructorName']!
            : _accountHolderCtrl.text.trim(),
        bankName: _selectedBank,
        accountNumber: _accountNumberCtrl.text.trim().isEmpty
            ? meta['accountNumber']!
            : _accountNumberCtrl.text.trim(),
        accountHolder: _accountHolderCtrl.text.trim().isEmpty
            ? meta['accountHolder']!
            : _accountHolderCtrl.text.trim(),
        category: finalCategory,
        autoBankDetectEnabled: false,
        invoiceTemplate: defaultProfile.invoiceTemplate,
        attendanceTemplate: defaultProfile.attendanceTemplate,
        departureTemplate: defaultProfile.departureTemplate,
      );
      await ref.read(studioProfileProvider.notifier).updateProfile(studio, triggerAd: false);

      // 3. Register the very first real student/member if name is given
      if (_memberNameCtrl.text.trim().isNotEmpty) {
        final fee = int.tryParse(_memberFeeCtrl.text.replaceAll(',', '').trim()) ??
            LocalizationService.currentCurrency.defaultFeeBase;
        final sessions = int.tryParse(_memberSessionsCtrl.text.trim()) ?? 10;
        final member = Member(
          id: const Uuid().v4(),
          name: _memberNameCtrl.text.trim(),
          phone: _memberPhoneCtrl.text.trim().isEmpty
              ? (LocalizationService.isDomestic ? '010-0000-0000' : '555-010-0000')
              : _memberPhoneCtrl.text.trim(),
          groupName: _memberGroupCtrl.text.trim().isEmpty
              ? LocalizationService.localizeBuiltInLabel('정규반')
              : _memberGroupCtrl.text.trim(),
          billingType: _billingType,
          defaultFee: fee,
          totalSessions: _billingType == BillingType.sessionBased ? sessions : 0,
          remainingSessions: _billingType == BillingType.sessionBased ? sessions : 0,
          registeredAt: DateTime.now(),
        );
        await ref.read(membersProvider.notifier).addMember(member, triggerAd: false);
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
          SnackBar(content: Text('${LocalizationService.tr('wiz_err_required')} ($e)')),
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
    final lang = ref.watch(languageProvider);
    ref.watch(currencyProvider);

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
            child: Text(
              LocalizationService.tr('onb_skip'),
              style: const TextStyle(
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
                  _buildStep1StudioName(lang),
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
                              _currentStep == 2
                                  ? LocalizationService.tr('wiz_finish')
                                  : LocalizationService.tr('wiz_next'),
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
  Widget _buildStep1StudioName(AppLanguage lang) {
    final presets = _getLocalizedStudioPresets(lang);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ZeroPassMascotAvatar(
                size: 46,
                icon: Icons.storefront_rounded,
              ),
              const Spacer(),
              RegionLanguageChip(onChanged: _syncRegionalDefaultsOnChange),
            ],
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
                Text(
                  LocalizationService.trParams('wiz_header_badge', {'step': '1'}),
                  style: const TextStyle(
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
          Text(
            LocalizationService.tr('wiz_step1_title'),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            LocalizationService.tr('wiz_step1_desc'),
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 22),

          AppTextField(
            controller: _studioNameCtrl,
            label: LocalizationService.tr('wiz_label_studio_name'),
            hint: LocalizationService.tr('wiz_hint_studio_name'),
            prefixIcon: Icons.storefront_outlined,
            autofocus: true,
          ),
          const SizedBox(height: 20),

          Text(
            LocalizationService.tr('wiz_label_category'),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: StudioProfile.businessCategories.map((cat) {
              final isSelected = _selectedCategory == cat;
              final displayCat = LocalizationService.industryCategoryLabel(cat);
              return InkWell(
                onTap: () {
                  setState(() {
                    _selectedCategory = cat;
                    if (cat != '기타 / 맞춤업종' && _studioNameCtrl.text.isEmpty) {
                      _studioNameCtrl.text = displayCat;
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
                    displayCat,
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
              label: LocalizationService.tr('wiz_label_category'),
              hint: LocalizationService.tr('wiz_hint_studio_name'),
              prefixIcon: Icons.category_outlined,
            ),
          ],
          const SizedBox(height: 20),

          Text(
            LocalizationService.tr('wiz_hint_studio_name'),
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: presets.map((preset) {
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
                Text(
                  LocalizationService.trParams('wiz_header_badge', {'step': '2'}),
                  style: const TextStyle(
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
          Text(
            LocalizationService.tr('wiz_step2_title'),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            LocalizationService.tr('wiz_step2_desc'),
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 24),

          Text(
            LocalizationService.tr('wiz_label_bank'),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
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
            label: LocalizationService.tr('wiz_label_account_num'),
            hint: LocalizationService.tr('wiz_hint_account_num'),
            prefixIcon: Icons.account_balance_wallet_outlined,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _accountHolderCtrl,
            label: LocalizationService.tr('wiz_label_holder'),
            hint: LocalizationService.tr('wiz_hint_instructor_name'),
            prefixIcon: Icons.person_outline,
          ),
        ],
      ),
    );
  }

  // STEP 3: First Member
  Widget _buildStep3FirstMember() {
    final currency = LocalizationService.currentCurrency;
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
                Text(
                  LocalizationService.trParams('wiz_header_badge', {'step': '3'}),
                  style: const TextStyle(
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
          Text(
            LocalizationService.tr('wiz_step3_title'),
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w800,
              color: AppTheme.primaryDark,
              height: 1.25,
              letterSpacing: -0.6,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            LocalizationService.tr('wiz_step3_desc'),
            style: const TextStyle(
              fontSize: 13.5,
              color: AppTheme.textSecondary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 24),

          AppTextField(
            controller: _memberNameCtrl,
            label: LocalizationService.tr('wiz_hint_instructor_name').replaceFirst('e.g. ', ''),
            hint: LocalizationService.tr('kiosk_demo_member_name'),
            prefixIcon: Icons.badge_outlined,
            autofocus: true,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _memberPhoneCtrl,
            label: 'Phone / SMS',
            hint: LocalizationService.isDomestic ? '010-1234-5678' : '+1 555-010-1234',
            prefixIcon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: 16),

          AppTextField(
            controller: _memberGroupCtrl,
            label: LocalizationService.localizeBuiltInLabel('정규반'),
            hint: LocalizationService.localizeBuiltInLabel('일반반'),
            prefixIcon: Icons.group_outlined,
          ),
          const SizedBox(height: 16),

          Text(
            '${LocalizationService.tr('billing_type_session')} / ${LocalizationService.tr('billing_type_monthly')}',
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppTheme.primaryDark),
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
                          LocalizationService.tr('billing_type_session'),
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
                          LocalizationService.tr('billing_type_monthly'),
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
              label: LocalizationService.trParams('common_sessions_unit', {'n': '10'}),
              hint: '10',
              prefixIcon: Icons.confirmation_number_outlined,
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
          ],

          AppTextField(
            controller: _memberFeeCtrl,
            label: '${LocalizationService.tr('sms_default_order_title')} (${currency.code} ${currency.symbol})',
            hint: '${currency.defaultFeeBase}',
            prefixIcon: Icons.payments_outlined,
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
