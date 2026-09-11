import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/data_vault_service.dart';
import '../theme/app_theme.dart';
import 'onboarding_screen.dart';

class SettingsVaultScreen extends ConsumerStatefulWidget {
  const SettingsVaultScreen({super.key});

  @override
  ConsumerState<SettingsVaultScreen> createState() => _SettingsVaultScreenState();
}

class _SettingsVaultScreenState extends ConsumerState<SettingsVaultScreen> {
  @override
  Widget build(BuildContext context) {
    final studioAsync = ref.watch(studioProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('설정 · 보안 금고'),
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
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (ctx) => OnboardingScreen(onFinish: () => Navigator.pop(ctx)),
                          ),
                        );
                      },
                      icon: const Icon(Icons.help_outline, color: Colors.white, size: 16),
                      label: const Text('마스코트 패시와 함께하는 온보딩 다시보기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Colors.white, width: 1.2),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
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
                        context,
                        title: '청구서 문자 서식 편집',
                        initialText: profile.invoiceTemplate,
                        placeholders: '#{상호명}, #{회원명}, #{청구제목}, #{금액}, #{계좌정보}, #{납부기한}',
                        onSave: (newTemplate) {
                          final updated = profile.copyWith(invoiceTemplate: newTemplate);
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
                        context,
                        title: '출석/등원 문자 서식 편집',
                        initialText: profile.attendanceTemplate,
                        placeholders: '#{상호명}, #{회원명}, #{출석시간}, #{잔여회차}',
                        onSave: (newTemplate) {
                          final updated = profile.copyWith(attendanceTemplate: newTemplate);
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
                        context,
                        title: '하원/수업종료 문자 서식 편집',
                        initialText: profile.departureTemplate,
                        placeholders: '#{상호명}, #{회원명}',
                        onSave: (newTemplate) {
                          final updated = profile.copyWith(departureTemplate: newTemplate);
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('스튜디오 프로필 수정', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('청구서 및 알림 문자에 표기될 사업장 정보입니다.', style: TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 18),
                TextField(
                  controller: studioCtrl,
                  decoration: InputDecoration(
                    labelText: '상호명 / 스튜디오명',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: instructorCtrl,
                  decoration: InputDecoration(
                    labelText: '원장 / 대표 강사명',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: bankCtrl,
                  decoration: InputDecoration(
                    labelText: '수납 은행명 (예: 토스뱅크, 국민은행)',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: accountCtrl,
                  decoration: InputDecoration(
                    labelText: '수납 계좌번호',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: holderCtrl,
                  decoration: InputDecoration(
                    labelText: '예금주 성명',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      final updated = current.copyWith(
                        studioName: studioCtrl.text.trim(),
                        instructorName: instructorCtrl.text.trim(),
                        bankName: bankCtrl.text.trim(),
                        accountNumber: accountCtrl.text.trim(),
                        accountHolder: holderCtrl.text.trim(),
                      );
                      ref.read(studioProfileProvider.notifier).updateProfile(updated);
                      Navigator.pop(ctx);
                    },
                    child: const Text('저장하기'),
                  ),
                ),
              ],
            ),
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

  void _openTemplateEditorDialog(
    BuildContext context, {
    required String title,
    required String initialText,
    required String placeholders,
    required Function(String) onSave,
  }) {
    final textController = TextEditingController(text: initialText);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  '사용 가능한 치환 태그:',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 2),
                Text(
                  placeholders,
                  style: const TextStyle(fontSize: 11, color: AppTheme.primaryBlue, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: textController,
                  maxLines: 7,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: const Color(0xFFF8FAFC),
                  ),
                  style: const TextStyle(fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      onSave(textController.text.trim());
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('문자 서식이 안전하게 저장되었습니다.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
                    child: const Text('서식 저장하기'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
