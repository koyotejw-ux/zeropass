import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/coach_mark_service.dart';
import '../services/data_vault_service.dart';
import '../theme/app_theme.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_text_field.dart';
import '../widgets/coach_mark_dialog.dart';
import '../widgets/interactive_guide_dialog.dart';
import 'home_navigation_screen.dart';
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

  @override
  Widget build(BuildContext context) {
    final studioAsync = ref.watch(studioProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('설정 · 보안 금고'),
        actions: [
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
                    _buildGuideStep('1', '출결 체크', '첫 번째 탭에서 [체크인] 누르면 출석 기록 & 잔여 회차가 1회 자동 차감됩니다.'),
                    const SizedBox(height: 8),
                    _buildGuideStep('2', '등·하원 안심 문자', '체크 완료 후 [출석/하원 알림]을 누르면 비용 0원으로 부모님께 즉시 문자가 갑니다.'),
                    const SizedBox(height: 8),
                    _buildGuideStep('3', '청구서 & 입금 장부', '두 번째 탭에서 수강료 청구서를 만들고, 은행 푸시 알림으로 수납을 자동 정리하세요.'),
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

              // 1. Studio Profile Card
              _buildSectionTitle('스튜디오 & 강사 프로필'),
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
                    _buildProfileRow('원장 / 강사명', profile.instructorName),
                    const Divider(height: 20, color: AppTheme.borderSubtle),
                    _buildProfileRow('수납 계좌 정보', '${profile.bankName} ${profile.accountNumber}'),
                    const Divider(height: 20, color: AppTheme.borderSubtle),
                    _buildProfileRow('예금주', profile.accountHolder),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => _openEditProfileDialog(context, profile),
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        label: const Text('프로필 및 수납 계좌 변경'),
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
                      title: const Text('청구서 문자 서식 편집', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('수강료 청구 시 발송되는 기본 문자 내용을 변경합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _openTemplateEditorDialog(
                        context: context,
                        title: '청구서 문자 서식 편집',
                        initialText: profile.invoiceTemplate,
                        placeholders: '#{상호명}, #{회원명}, #{청구제목}, #{금액}, #{계좌정보}, #{납부기한}',
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
                      title: const Text('출석/등원 안심 문자 서식 편집', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('체크인 시 학부모/회원에게 전송되는 안심 문자를 변경합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _openTemplateEditorDialog(
                        context: context,
                        title: '출석/등원 문자 서식 편집',
                        initialText: profile.attendanceTemplate,
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
                      title: const Text('하원/수업종료 문자 서식 편집', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('귀가/퇴실 시 발송되는 안내 문자를 변경합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => _openTemplateEditorDialog(
                        context: context,
                        title: '하원/수업종료 문자 서식 편집',
                        initialText: profile.departureTemplate,
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
                        child: Icon(Icons.download_for_offline_outlined, color: AppTheme.primaryBlue),
                      ),
                      title: const Text('로컬 백업 파일(.json) 내보내기', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('출석 및 수납 데이터를 안전하게 보관합니다.'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        final file = await DataVaultService.exportEncryptedBackup();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('백업 파일이 생성되었습니다: ${file.path.split('/').last}'),
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
                      title: const Text('전체 수납 내역 엑셀(CSV) 내보내기', style: TextStyle(fontWeight: FontWeight.w700)),
                      subtitle: const Text('세무 및 장부 결산을 위한 엑셀 호환 CSV 생성'),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () async {
                        final file = await DataVaultService.exportLedgerCsv();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('수납 장부 CSV가 생성되었습니다: ${file.path.split('/').last}'),
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
                            content: const Text(
                              '현재 등록된 가상 회원, 출석 기록, 청구서 내역이 모두 삭제되어 실제 운영 모드로 초기화됩니다.\n(스튜디오 프로필 설정은 유지됩니다.)',
                              style: TextStyle(height: 1.5, fontSize: 13),
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

              // 4. Compliance & Legal Terms Card
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, fontWeight: FontWeight.w500)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
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

    AppBottomSheet.show(
      context: context,
      builder: (ctx) {
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
                hint: '예: 제로패스 스튜디오',
                prefixIcon: Icons.storefront_outlined,
              ),
              const SizedBox(height: 14),
              AppTextField(
                controller: instructorCtrl,
                label: '원장 / 대표 강사명',
                hint: '예: 홍길동 원장',
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
                    final updated = current.copyWith(
                      studioName: studioCtrl.text.trim(),
                      instructorName: instructorCtrl.text.trim(),
                      bankName: bankCtrl.text.trim(),
                      accountNumber: accountCtrl.text.trim(),
                      accountHolder: holderCtrl.text.trim(),
                    );
                    await ref.read(studioProfileProvider.notifier).updateProfile(updated);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('스튜디오 프로필이 저장되었습니다.')),
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
            // Live preview generation
            String previewText = textController.text
                .replaceAll('#{상호명}', studioNameController.text.trim().isEmpty ? '상호명' : studioNameController.text.trim())
                .replaceAll('#{회원명}', '김민준')
                .replaceAll('#{강사명}', instructorController.text.trim().isEmpty ? '원장님' : instructorController.text.trim())
                .replaceAll('#{계좌정보}', '${bankController.text.trim()} ${accountController.text.trim()} (${holderController.text.trim()})')
                .replaceAll('#{금액}', '250,000')
                .replaceAll('#{청구제목}', '9월 수강료')
                .replaceAll('#{납부기한}', '2026.09.20')
                .replaceAll('#{출석시간}', '14:30')
                .replaceAll('#{잔여회차}', '• 잔여 회차: 9회');

            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
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
                          label: '스튜디오 상호명 (#{상호명})',
                          hint: '예: 제로패스 음악학원',
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
