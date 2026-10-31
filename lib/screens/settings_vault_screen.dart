import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/coach_mark_service.dart';
import '../services/data_vault_service.dart';
import '../services/localization_service.dart';
import '../services/monetization_service.dart';
import '../services/starter_preset_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coach_mark_dialog.dart';
import '../widgets/interactive_guide_dialog.dart';
import 'home_navigation_screen.dart';
import 'onboarding_screen.dart';
import 'studio_setup_wizard_screen.dart';

class SettingsVaultScreen extends ConsumerStatefulWidget {
  const SettingsVaultScreen({super.key});

  @override
  ConsumerState<SettingsVaultScreen> createState() => _SettingsVaultScreenState();
}

class _SettingsVaultScreenState extends ConsumerState<SettingsVaultScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      CoachMarkDialog.showIfFirstTime(
        context: context,
        coachKey: CoachMarkService.keySettingsTab,
        title: '로컬 100% 보안 금고 🛡️',
        message: '제로패스는 외부 서버로 단 1바이트의 개인정보도 전송하지 않습니다.\n\n대표님의 스마트폰 기기에만 AES 암호화되어 안전하게 보관되며, 원하실 때 언제든 엑셀(CSV)이나 암호화 백업 파일로 추출할 수 있어요.',
        tip: '스튜디오 상호명, 수납 계좌번호, 자동 문자 양식 편집도 모두 여기서 관리하실 수 있습니다.',
        buttonText: '안심하고 사용할게요! 🔒',
      );
    });
  }

  void _openInteractiveGuide(BuildContext context) {
    StepByStepPracticeGuideDialog.show(
      context,
      onOpenAddMember: () {
        HomeNavigationScreen.of(context)?.switchToTab(2); // 회원 관리 탭
      },
      onOpenSettings: () {
        HomeNavigationScreen.of(context)?.switchToTab(3); // 설정 탭
      },
    );
  }

  void _openIndustryPresetDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 22),
                      SizedBox(width: 8),
                      Text(
                        '업종 맞춤 1초 프리셋',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Text(
                '대표님의 업종을 선택하시면 딱 맞는 출결 용어와 실전 샘플 데이터로 즉시 세팅됩니다.',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              const SizedBox(height: 12),
              ...IndustryPreset.values.map(
                (preset) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.business_center_outlined, color: AppTheme.primaryBlue, size: 20),
                  ),
                  title: Text(preset.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5)),
                  subtitle: Text('${preset.sampleStudioName} (${preset.category})', style: const TextStyle(fontSize: 11.5)),
                  trailing: const Icon(Icons.chevron_right, size: 20),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await StarterPresetService.applyPreset(preset);
                    ref.invalidate(membersProvider);
                    ref.invalidate(passRecordsProvider);
                    ref.invalidate(studioProfileProvider);
                    ref.invalidate(invoicesProvider);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('🎉 ${preset.label} 맞춤 환경으로 1초 만에 세팅되었습니다!'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studioAsync = ref.watch(studioProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('설정 · 보안 금고'),
        actions: [
          IconButton(
            icon: const Icon(Icons.school_outlined),
            tooltip: '패시의 온보딩 튜토리얼 다시보기',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (ctx) => OnboardingScreen(onFinish: () => Navigator.pop(ctx)),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.help_outline),
            tooltip: '실전 가이드 튜토리얼',
            onPressed: () => _openInteractiveGuide(context),
          ),
        ],
      ),
      body: studioAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('설정 로딩 오류: $err')),
        data: (profile) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 90),
            children: [
              // 0. Easy Getting Started Guide Card (출결선생처럼 한눈에 알기 쉬운 사용 설명서)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.lightbulb_outline, color: Colors.white, size: 22),
                        SizedBox(width: 8),
                        Text(
                          '초간단 3단계 이용 가이드',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildGuideStep('1', '출결 & 이용 체크', '첫 번째 탭에서 [체크인] 누르면 출석 일시 기록 & 잔여 회차가 1회 자동 차감됩니다.'),
                    const SizedBox(height: 8),
                    _buildGuideStep('2', '비용 0원 안심 문자', '체크 완료 후 [출석/이용 알림]을 누르면 기본 문자 앱으로 보호자/회원에게 즉시 전송됩니다.'),
                    const SizedBox(height: 8),
                    _buildGuideStep('3', '청구서 & 수납 장부', '두 번째 탭에서 ${profile.feeTitle} 청구서를 만들고, 은행 입금 감지로 미납/완납을 자동 정리하세요.'),
                    const SizedBox(height: 14),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => _openInteractiveGuide(context),
                          icon: const Icon(Icons.play_lesson, color: AppTheme.primaryDark, size: 16),
                          label: const Text('스텝바이스텝 가이드', style: TextStyle(color: AppTheme.primaryDark, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (ctx) => StudioSetupWizardScreen(onFinish: () => Navigator.pop(ctx)),
                              ),
                            );
                          },
                          icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 16),
                          label: const Text('매장 셋업 위저드', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.white, width: 1.2),
                            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // 0-1. Industry 1-Second Preset Card
              _buildSectionTitle('🎯 업종 맞춤 1초 프리셋 & 실전 데이터 로드'),
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF3C7),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFFD97706), size: 20),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '원클릭 업종 프리셋 전환',
                                style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                              ),
                              SizedBox(height: 2),
                              Text(
                                '학원 · PT · 필라테스 · 태권도 · 음악공방 맞춤 세팅',
                                style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      '선택하신 업종에 맞춰 출결 안내 문구, 수강료/회비 용어, 맞춤 샘플 회원 데이터가 즉시 구성됩니다.',
                      style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.45),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openIndustryPresetDialog(context),
                        icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                        label: const Text('내 업종 맞춤 프리셋 선택하기'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFD97706),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // 0. Global Language & Currency Localization Card
              _buildSectionTitle('🌐 글로벌 언어 및 통화 설정 (Language & Currency)'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.language_rounded, size: 18, color: AppTheme.primaryBlue),
                            SizedBox(width: 8),
                            Text('앱 언어 (Language)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        DropdownButton<AppLanguage>(
                          value: LocalizationService.currentLanguage,
                          underline: const SizedBox(),
                          borderRadius: BorderRadius.circular(12),
                          items: AppLanguage.values.map((lang) {
                            return DropdownMenuItem<AppLanguage>(
                              value: lang,
                              child: Text(lang.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            );
                          }).toList(),
                          onChanged: (lang) {
                            if (lang != null) {
                              setState(() {
                                LocalizationService.setLanguage(lang);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.monetization_on_outlined, size: 18, color: AppTheme.softMint),
                            SizedBox(width: 8),
                            Text('통화 단위 (Currency)', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                          ],
                        ),
                        DropdownButton<AppCurrency>(
                          value: LocalizationService.currentCurrency,
                          underline: const SizedBox(),
                          borderRadius: BorderRadius.circular(12),
                          items: AppCurrency.values.map((cur) {
                            return DropdownMenuItem<AppCurrency>(
                              value: cur,
                              child: Text('${cur.code} (${cur.symbol})', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                            );
                          }).toList(),
                          onChanged: (cur) {
                            if (cur != null) {
                              setState(() {
                                LocalizationService.setCurrency(cur);
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 1. Studio Profile Card
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildSectionTitle('${profile.placeTitle} & ${profile.roleTitle} 프로필'),
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.chipBackground,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      profile.category,
                      style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.primaryBlue,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    _buildProfileRow('상호 / 브랜드명', profile.studioName),
                    const Divider(height: 20, color: AppTheme.borderSubtle),
                    _buildProfileRow('업종 카테고리', profile.category),
                    const Divider(height: 20, color: AppTheme.borderSubtle),
                    _buildProfileRow(profile.roleTitle, profile.instructorName),
                    const Divider(height: 20, color: AppTheme.borderSubtle),
                    _buildProfileRow('${profile.feeTitle} 수납 계좌', '${profile.bankName} ${profile.accountNumber}'),
                    const Divider(height: 20, color: AppTheme.borderSubtle),
                    _buildProfileRow('예금주', profile.accountHolder),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditProfileDialog(context, profile),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: Text('${profile.placeTitle} 프로필 및 수납 계좌 변경'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. 문자 양식 커스텀 관리 카드 (새로 추가)
              _buildSectionTitle('문자 알림 및 청구 양식 관리 (사용자 정의 서식)'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.receipt_long_outlined, color: AppTheme.primaryBlue),
                      ),
                      title: Text('${profile.feeTitle} 청구서 문자 서식 편집', style: const TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: Text('${profile.feeTitle} 청구 시 발송되는 기본 문자 내용을 변경합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _openTemplateEditorDialog(
                        context: context,
                        title: '${profile.feeTitle} 청구서 문자 서식 편집',
                        initialText: profile.invoiceTemplate,
                        defaultText: StudioProfile.defaultInvoiceTemplate,
                        placeholders: '#{상호명}, #{회원명}, #{청구제목}, #{금액}, #{계좌정보}, #{계좌복사용}, #{토스송금링크}, #{납부기한}',
                        profile: profile,
                        onSave: (newTemplate, updatedProfile) {
                          final updated = updatedProfile.copyWith(invoiceTemplate: newTemplate);
                          ref.read(studioProfileProvider.notifier).updateProfile(updated);
                        },
                      ),
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFECFDF5),
                        child: Icon(Icons.mark_chat_read_outlined, color: AppTheme.softMint),
                      ),
                      title: const Text('출석 / 입실 안심 문자 서식 편집', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('체크인 시 보호자/회원에게 전송되는 안심 문자를 변경합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _openTemplateEditorDialog(
                        context: context,
                        title: '출석 / 입실 문자 서식 편집',
                        initialText: profile.attendanceTemplate,
                        defaultText: StudioProfile.defaultAttendanceTemplate,
                        placeholders: '#{상호명}, #{회원명}, #{출석시간}, #{잔여회차}',
                        profile: profile,
                        onSave: (newTemplate, updatedProfile) {
                          final updated = updatedProfile.copyWith(attendanceTemplate: newTemplate);
                          ref.read(studioProfileProvider.notifier).updateProfile(updated);
                        },
                      ),
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFFFBEB),
                        child: Icon(Icons.exit_to_app_rounded, color: AppTheme.warning),
                      ),
                      title: const Text('퇴실 / 일정종료 문자 서식 편집', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('귀가/퇴실 시 발송되는 완료 안내 문자를 변경합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _openTemplateEditorDialog(
                        context: context,
                        title: '퇴실 / 일정종료 문자 서식 편집',
                        initialText: profile.departureTemplate,
                        defaultText: StudioProfile.defaultDepartureTemplate,
                        placeholders: '#{상호명}, #{회원명}',
                        profile: profile,
                        onSave: (newTemplate, updatedProfile) {
                          final updated = updatedProfile.copyWith(departureTemplate: newTemplate);
                          ref.read(studioProfileProvider.notifier).updateProfile(updated);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 2. Bank Push Parser Security Setting
              _buildSectionTitle('금융 푸시 필터 보안 설정'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            '은행 입금 푸시 알림 자동 감지 (안드로이드)',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                        ),
                        Switch(
                          value: profile.autoBankDetectEnabled,
                          activeThumbColor: AppTheme.primaryBlue,
                          onChanged: (val) {
                            ref.read(studioProfileProvider.notifier).toggleBankDetect(val);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEFF6FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Icon(Icons.shield_outlined, size: 18, color: AppTheme.primaryBlue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '검증된 1금융권/인터넷은행 앱 패키지만 엄격 필터링하며, 개인 카카오톡 및 일반 문자는 즉시 자동 폐기(Drop)하여 일체의 프라이버시 침해를 원천 차단합니다.',
                              style: TextStyle(fontSize: 12, color: Color(0xFF1E40AF), height: 1.4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 3. Local Data Vault (Zero Server)
              _buildSectionTitle('로컬 데이터 금고 (서버 0원 로컬 저장소)'),
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                  boxShadow: AppTheme.cardShadow,
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFEFF6FF),
                        child: Icon(Icons.share_outlined, color: AppTheme.primaryBlue),
                      ),
                      title: const Text('로컬 백업 파일 생성 & 카톡/드라이브 전송', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('회원·출결·수납 데이터를 백업하여 나에게 카톡/드라이브로 보관합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        final file = await DataVaultService.exportEncryptedBackup();
                        await DataVaultService.shareBackupFile(file);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('백업 파일이 생성되어 공유 창이 열렸습니다: ${file.path.split(Platform.isWindows ? '\\' : '/').last}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFECFDF5),
                        child: Icon(Icons.table_view_outlined, color: AppTheme.softMint),
                      ),
                      title: const Text('수납 장부 엑셀(CSV) 내보내기 & 공유', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('세무/결산용 엑셀 호환 CSV를 생성하여 카톡/엑셀로 공유합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        final file = await DataVaultService.exportLedgerCsv();
                        await DataVaultService.shareLedgerCsv(file);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('수납 장부 CSV가 생성되어 공유 창이 열렸습니다: ${file.path.split(Platform.isWindows ? '\\' : '/').last}'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF0FDF4),
                        child: Icon(Icons.restore_page_outlined, color: AppTheme.softMint),
                      ),
                      title: const Text('백업 데이터 복원하기 (텍스트 / JSON)', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('카카오톡 등으로 보관한 백업 JSON 내용을 입력하여 복원합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _openRestoreDataDialog(context),
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFFEF2F2),
                        child: Icon(Icons.cleaning_services_outlined, color: AppTheme.danger),
                      ),
                      title: const Text('체험용 가상 데이터 비우기 (실제 운영 시작)', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.danger)),
                      subtitle: const Text('샘플 5명 데이터를 모두 지우고 실제 회원만 등록합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (c) => AlertDialog(
                            title: const Text('연습 데이터를 모두 비우시겠습니까?'),
                            content: const SingleChildScrollView(
                              child: Text(
                                '현재 등록된 가상 회원, 출석 기록, 청구서 내역이 모두 삭제되어 실제 운영 모드로 초기화됩니다.\n(스튜디오 프로필 설정은 유지됩니다.)',
                                style: TextStyle(height: 1.5, fontSize: 13),
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                              ElevatedButton(
                                onPressed: () => Navigator.pop(c, true),
                                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.danger),
                                child: const Text('깨끗이 비우기', style: TextStyle(color: Colors.white)),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true && context.mounted) {
                          final db = ref.read(databaseServiceProvider);
                          await db.clearAllData();
                          await ref.read(membersProvider.notifier).reload();
                          await ref.read(passRecordsProvider.notifier).reload();
                          await ref.read(invoicesProvider.notifier).reload();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('체험용 데이터가 비워졌습니다. 이제 실제 회원을 등록해 보세요!'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                    ),
                    const Divider(height: 16, color: AppTheme.borderSubtle),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFFF3E8FF),
                        child: Icon(Icons.restart_alt, color: Colors.purple),
                      ),
                      title: const Text('체험용 샘플 데이터 다시 불러오기', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('학원/PT/공방 연습용 5명 예시 데이터를 다시 채웁니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        final db = ref.read(databaseServiceProvider);
                        await db.restoreSampleData();
                        await ref.read(membersProvider.notifier).reload();
                        await ref.read(passRecordsProvider.notifier).reload();
                        await ref.read(invoicesProvider.notifier).reload();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('연습용 샘플 데이터가 성공적으로 복원되었습니다.'),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. CheckAndPay PRO & Monetization Shortcut Card
              _buildSectionTitle('💎 체크앤페이 PRO 멤버십 & 프리미엄 기능'),
              AnimatedBuilder(
                animation: MonetizationService.instance,
                builder: (context, _) {
                  final isNoAds = MonetizationService.instance.isAdsRemoved;
                  final isKiosk = MonetizationService.instance.isKioskProUnlocked;

                  return Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: AppTheme.cardShadow,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(Icons.workspace_premium_rounded, color: Color(0xFFFBBF24), size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isNoAds && isKiosk
                                        ? 'PRO 멤버십 활성화 완료 (VIP)'
                                        : '체크앤페이 PRO 샵 둘러보기',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    isNoAds && isKiosk
                                        ? '키오스크 및 광고 제거 영구 소장권이 모두 켜져 있습니다.'
                                        : '무인 태블릿 키오스크 모드 및 평생 광고 제거권을 확인하세요.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.white.withValues(alpha: 0.7),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              HomeNavigationScreen.of(context)?.switchToTab(3); // PRO 샵 탭으로 이동
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFF59E0B),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.shopping_bag_outlined, size: 16),
                            label: const Text(
                              '전용 PRO 샵 탭 바로가기 💎',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              // 5. Compliance & Legal Terms Card
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Row(
                      children: [
                        Icon(Icons.gavel_outlined, size: 18, color: AppTheme.textSecondary),
                        SizedBox(width: 8),
                        Text(
                          '법적 고지 및 규정 준수 (Compliance)',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Text(
                      '본 앱은 오프라인 장부 및 메시지 서식 도구이며, 모든 데이터는 기기에만 암호화 보관됩니다. 원격 중앙 서버 및 제3자 분석 서버로 데이터를 전송하지 않습니다.\n회원 정보 수집 동의 및 회원과의 수납·거래 책임은 운영자 본인에게 있습니다.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }


  Widget _buildProfileRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 125,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              softWrap: true,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openEditProfileDialog(BuildContext context, StudioProfile current) {
    final studioCtrl = TextEditingController(text: current.studioName);
    final instructorCtrl = TextEditingController(text: current.instructorName);
    final bankCtrl = TextEditingController(text: current.bankName);
    final accountCtrl = TextEditingController(text: current.accountNumber);
    final holderCtrl = TextEditingController(text: current.accountHolder);

    String selectedCategory = current.category;
    final customCategoryCtrl = TextEditingController();
    bool isCustom = !StudioProfile.businessCategories.contains(current.category) || current.category == '기타 / 맞춤업종';
    if (isCustom && current.category != '기타 / 맞춤업종') {
      customCategoryCtrl.text = current.category;
    }

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.92,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('스튜디오 프로필 수정', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('청구서 및 알림 문자에 표기될 사업장 정보입니다.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                  const SizedBox(height: 18),
                  AppTextField(
                    controller: studioCtrl,
                    label: '상호명 / 스튜디오명',
                    hint: '예: 체크앤페이 스튜디오',
                    prefixIcon: Icons.storefront_outlined,
                  ),
                  const SizedBox(height: 14),

                  // Business Category Selector
                  const Text(
                    '사업장 업종 카테고리',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: StudioProfile.businessCategories.map((cat) {
                      final isSelected = selectedCategory == cat;
                      return ChoiceChip(
                        label: Text(cat, style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected ? Colors.white : AppTheme.textPrimary,
                        )),
                        selected: isSelected,
                        selectedColor: AppTheme.primaryBlue,
                        backgroundColor: const Color(0xFFF1F5F9),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() {
                              selectedCategory = cat;
                            });
                          }
                        },
                      );
                    }).toList(),
                  ),
                  if (selectedCategory == '기타 / 맞춤업종') ...[
                    const SizedBox(height: 10),
                    AppTextField(
                      controller: customCategoryCtrl,
                      label: '직접 입력 카테고리',
                      hint: '예: 바리스타 학원, 가죽 공방, 보컬 레슨',
                      prefixIcon: Icons.category_outlined,
                    ),
                  ],
                  const SizedBox(height: 14),

                  AppTextField(
                    controller: instructorCtrl,
                    label: '대표자 / 담당자 성명 (원장·대표·강사·작가)',
                    hint: '예: 홍길동 원장, 김코치',
                    prefixIcon: Icons.badge_outlined,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: bankCtrl,
                    label: '수납 은행명',
                    hint: '예: 토스뱅크, 국민은행',
                    prefixIcon: Icons.account_balance_outlined,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: accountCtrl,
                    label: '수납 계좌번호',
                    hint: '예: 3333-01-2345678',
                    prefixIcon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 14),
                  AppTextField(
                    controller: holderCtrl,
                    label: '예금주 성명',
                    hint: '예: 홍길동',
                    prefixIcon: Icons.person_outline,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        final finalCat = selectedCategory == '기타 / 맞춤업종' && customCategoryCtrl.text.trim().isNotEmpty
                            ? customCategoryCtrl.text.trim()
                            : selectedCategory;
                        final updated = current.copyWith(
                          studioName: studioCtrl.text.trim(),
                          instructorName: instructorCtrl.text.trim(),
                          bankName: bankCtrl.text.trim(),
                          accountNumber: accountCtrl.text.trim(),
                          accountHolder: holderCtrl.text.trim(),
                          category: finalCat,
                        );
                        await ref.read(studioProfileProvider.notifier).updateProfile(updated);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('스튜디오 프로필 및 카테고리가 저장되었습니다.')),
                          );
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      child: const Text('저장하기', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _openRestoreDataDialog(BuildContext context) {
    final jsonController = TextEditingController();

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.85,
      builder: (ctx) {
        return SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '백업 데이터 복원하기',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                '카카오톡이나 메일로 내보냈던 백업 파일(.json)의 내용을 전체 복사하여 아래에 붙여넣어 주세요.',
                style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              AppTextField(
                controller: jsonController,
                label: '백업 JSON 내용 붙여넣기',
                hint: '{\n  "version": "1.0.0",\n  "members": [...]\n}',
                maxLines: 10,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final text = jsonController.text.trim();
                    if (text.isEmpty) return;

                    final success = await DataVaultService.restoreFromBackupJson(text);
                    if (ctx.mounted) Navigator.pop(ctx);

                    if (success) {
                      await ref.read(membersProvider.notifier).reload();
                      await ref.read(passRecordsProvider.notifier).reload();
                      await ref.read(invoicesProvider.notifier).reload();
                      await ref.read(studioProfileProvider.notifier).reload();

                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('🎉 백업 데이터가 완벽하게 복원되었습니다!'),
                            backgroundColor: AppTheme.softMint,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    } else {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('올바르지 않은 백업 데이터 형식이거나 복원에 실패했습니다.'),
                            backgroundColor: AppTheme.danger,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.restore, color: Colors.white),
                  label: const Text('지금 바로 데이터 복원하기', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGuideStep(String num, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 10,
          backgroundColor: Colors.white.withAlpha((255 * 0.25).round()),
          child: Text(
            num,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: '$title: ',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                TextSpan(
                  text: desc,
                  style: const TextStyle(fontSize: 12, color: Color(0xFFDBEAFE), height: 1.3),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _openTemplateEditorDialog({
    required BuildContext context,
    required String title,
    required String initialText,
    required String defaultText,
    required String placeholders,
    required StudioProfile profile,
    required Function(String, StudioProfile) onSave,
  }) {
    final textController = TextEditingController(text: initialText);
    final studioNameController = TextEditingController(text: profile.studioName);
    final instructorController = TextEditingController(text: profile.instructorName);
    final bankController = TextEditingController(text: profile.bankName);
    final accountController = TextEditingController(text: profile.accountNumber);
    final holderController = TextEditingController(text: profile.accountHolder);

    AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.92,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            // Live preview generation with comprehensive placeholder support
            final previewBank = bankController.text.trim().isEmpty ? '토스뱅크' : bankController.text.trim();
            final previewAccount = accountController.text.trim().isEmpty ? '1000-2026-8899' : accountController.text.trim();
            final previewHolder = holderController.text.trim().isEmpty ? '원장님' : holderController.text.trim();
            final previewStudio = studioNameController.text.trim().isEmpty ? '스튜디오' : studioNameController.text.trim();
            final cleanAccOnly = previewAccount.replaceAll(RegExp(r'[^0-9]'), '');
            final previewCopyAcc = '$previewBank $previewAccount $previewHolder';
            final previewToss = 'supertoss://send?bank=${Uri.encodeComponent(previewBank)}&account=$cleanAccOnly&amount=250000';

            String previewText = textController.text
                .replaceAll('#{상호명}', previewStudio)
                .replaceAll('#{회원명}', '김민준')
                .replaceAll('#{강사명}', instructorController.text.trim().isEmpty ? '원장님' : instructorController.text.trim())
                .replaceAll('#{계좌정보}', '$previewBank $previewAccount ($previewHolder)')
                .replaceAll('#{계좌복사용}', previewCopyAcc)
                .replaceAll('#{토스송금링크}', previewToss)
                .replaceAll('#{금액}', '250,000')
                .replaceAll('#{청구제목}', '9월 정기 수강료')
                .replaceAll('#{안내내용}', '9월 정기 수강료')
                .replaceAll('#{납부기한}', '2026.09.20')
                .replaceAll('#{출석시간}', '14:30')
                .replaceAll('#{잔여회차}', '• 잔여 회차 : 9회');

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          textController.text = defaultText;
                          setModalState(() {});
                        },
                        icon: const Icon(Icons.restart_alt_rounded, size: 16, color: AppTheme.primaryBlue),
                        label: const Text('권장 서식 초기화', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '필수 변수(상호명, 계좌 등)를 수정하면 문자에 즉시 반영됩니다.',
                    style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 16),

                  // 1. Dedicated Input Fields for Essential Variables
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.tune_rounded, size: 16, color: AppTheme.primaryBlue),
                            SizedBox(width: 6),
                            Text(
                              '문자에 삽입되는 필수 기본 정보',
                              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        AppTextField(
                          controller: studioNameController,
                          label: '사업장 상호/브랜드명 (#{상호명})',
                          hint: '예: 제로패스 스튜디오 / 학원 / 공방',
                          prefixIcon: Icons.storefront_outlined,
                          onChanged: (_) => setModalState(() {}),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: AppTextField(
                                controller: bankController,
                                label: '입금 은행 (#{계좌정보})',
                                hint: '토스뱅크',
                                prefixIcon: Icons.account_balance_outlined,
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: AppTextField(
                                controller: holderController,
                                label: '예금주 성명',
                                hint: '김원장',
                                prefixIcon: Icons.person_outline,
                                onChanged: (_) => setModalState(() {}),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppTextField(
                          controller: accountController,
                          label: '입금 계좌번호',
                          hint: '3333-01-2345678',
                          prefixIcon: Icons.credit_card_outlined,
                          keyboardType: TextInputType.number,
                          onChanged: (_) => setModalState(() {}),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // 2. Template Editor with Placeholders Chips
                  const Text(
                    '문자 서식 양식 편집',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: placeholders.split(',').map((p) {
                      final tag = p.trim();
                      return ActionChip(
                        backgroundColor: const Color(0xFFEFF6FF),
                        label: Text(tag, style: const TextStyle(fontSize: 11.5, color: AppTheme.primaryBlue, fontWeight: FontWeight.w700)),
                        onPressed: () {
                          final currentText = textController.text;
                          final selection = textController.selection;
                          final newText = selection.isValid && selection.start >= 0
                              ? currentText.replaceRange(selection.start, selection.end, tag)
                              : '$currentText $tag';
                          textController.text = newText;
                          setModalState(() {});
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  AppTextField(
                    controller: textController,
                    label: '문자 본문 (치환 태그 클릭 시 본문에 추가됩니다)',
                    maxLines: 7,
                    keyboardType: TextInputType.multiline,
                    onChanged: (_) => setModalState(() {}),
                  ),
                  const SizedBox(height: 16),

                  // 3. Live Preview Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(14),
                      border: const Border(left: BorderSide(color: AppTheme.softMint, width: 3.5)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.visibility_outlined, size: 14, color: AppTheme.softMint),
                            SizedBox(width: 6),
                            Text(
                              '실제 발송 문자 미리보기',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: Color(0xFF334155)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          previewText,
                          style: const TextStyle(fontSize: 13, color: Color(0xFF1E293B), height: 1.45),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Save Button
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () {
                        final updatedProfile = profile.copyWith(
                          studioName: studioNameController.text.trim(),
                          bankName: bankController.text.trim(),
                          accountNumber: accountController.text.trim(),
                          accountHolder: holderController.text.trim(),
                        );
                        onSave(textController.text.trim(), updatedProfile);
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('문자 서식 및 상호/계좌 정보가 안전하게 저장되었습니다.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryBlue,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        elevation: 0,
                      ),
                      child: const Text('서식 & 정보 함께 저장하기', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
