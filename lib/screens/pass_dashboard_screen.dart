import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';

class PassDashboardScreen extends ConsumerStatefulWidget {
  const PassDashboardScreen({super.key});

  @override
  ConsumerState<PassDashboardScreen> createState() => _PassDashboardScreenState();
}

class _PassDashboardScreenState extends ConsumerState<PassDashboardScreen> {
  String _selectedGroup = '전체 그룹';
  String _statusFilter = '전체'; // '전체', '수업 전', '체크 완료'

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final passRecordsAsync = ref.watch(passRecordsProvider);
    final studioAsync = ref.watch(studioProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('M월 d일 EEEE', 'ko_KR').format(DateTime.now()),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 2),
            const Text(
              '원터치 출결 체크',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                letterSpacing: -0.8,
              ),
            ),
          ],
        ),
        actions: [
          // 출결선생 스타일 학부모 출결 문자 발송 설정 바로가기 안내
          IconButton(
            icon: const Icon(Icons.mark_chat_read_outlined),
            tooltip: '출결 알림 안내',
            onPressed: () => _showAttendanceHelpDialog(context),
          ),
        ],
        toolbarHeight: 74,
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('데이터 로딩 오류: $err')),
        data: (members) {
          return passRecordsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('기록 로딩 오류: $err')),
            data: (passRecords) {
              final studio = studioAsync.value ?? StudioProfile.defaultProfile();

              // Calculate today's stats
              final now = DateTime.now();
              final todayRecords = passRecords.where((r) {
                return r.timestamp.year == now.year &&
                    r.timestamp.month == now.month &&
                    r.timestamp.day == now.day;
              }).toList();

              final checkedMemberIds = todayRecords.map((r) => r.memberId).toSet();
              final attendedCount = todayRecords.where((r) => r.status == AttendanceStatus.attended).length;
              final lateCount = todayRecords.where((r) => r.status == AttendanceStatus.late).length;
              final remainingMembersCount = members.where((m) => !checkedMemberIds.contains(m.id)).length;

              // Extract all groups
              final groups = ['전체 그룹', ...members.map((m) => m.groupName).toSet()];

              // Filter members list
              var filteredMembers = members.where((m) {
                if (_selectedGroup != '전체 그룹' && m.groupName != _selectedGroup) {
                  return false;
                }
                final isChecked = checkedMemberIds.contains(m.id);
                if (_statusFilter == '수업 전' && isChecked) return false;
                if (_statusFilter == '체크 완료' && !isChecked) return false;
                return true;
              }).toList();

              return Column(
                children: [
                  // 1. Metric Summary Card (Toss Financial Aesthetics)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: AppTheme.cardShadow,
                        border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem('출석 완료', attendedCount, AppTheme.softMint),
                          _buildDivider(),
                          _buildStatItem('지각/보강', lateCount, AppTheme.warning),
                          _buildDivider(),
                          _buildStatItem('출결 대기', remainingMembersCount, AppTheme.primaryBlue),
                        ],
                      ),
                    ),
                  ),

                  // 2. Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                    child: Row(
                      children: [
                        ...groups.take(4).map((g) {
                          final isSelected = _selectedGroup == g;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(g),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  _selectedGroup = g;
                                });
                              },
                              backgroundColor: Colors.white,
                              selectedColor: AppTheme.primaryDark,
                              labelStyle: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppTheme.textPrimary,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                                side: BorderSide(
                                  color: isSelected ? Colors.transparent : AppTheme.borderSubtle,
                                ),
                              ),
                              showCheckmark: false,
                            ),
                          );
                        }),
                        PopupMenuButton<String>(
                          initialValue: _statusFilter,
                          onSelected: (val) => setState(() => _statusFilter = val),
                          itemBuilder: (ctx) => [
                            const PopupMenuItem(value: '전체', child: Text('전체 보기')),
                            const PopupMenuItem(value: '수업 전', child: Text('수업 전 (출결 대기)')),
                            const PopupMenuItem(value: '체크 완료', child: Text('체크 완료')),
                          ],
                          child: Chip(
                            label: Row(
                              children: [
                                Text('상태: $_statusFilter'),
                                const Icon(Icons.keyboard_arrow_down, size: 16),
                              ],
                            ),
                            backgroundColor: Colors.white,
                            side: const BorderSide(color: AppTheme.borderSubtle),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 3. Member Pass Cards List
                  Expanded(
                    child: filteredMembers.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.event_available_outlined, size: 48, color: AppTheme.textTertiary),
                                const SizedBox(height: 12),
                                const Text(
                                  '해당 조건의 회원이 없습니다',
                                  style: TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(18, 4, 18, 90),
                            itemCount: filteredMembers.length,
                            itemBuilder: (context, index) {
                              final member = filteredMembers[index];
                              final isChecked = checkedMemberIds.contains(member.id);
                              final todayPass = isChecked
                                  ? todayRecords.firstWhere((r) => r.memberId == member.id)
                                  : null;

                              return _buildMemberPassCard(context, member, isChecked, todayPass, studio);
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha((255 * 0.06).round()),
              offset: const Offset(0, -4),
              blurRadius: 16,
            ),
          ],
        ),
        child: SafeArea(
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _handleBatchCheckIn(context),
                  icon: const Icon(Icons.done_all, color: Colors.white),
                  label: const Text('남은 회원 일괄 출석 완료'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryDark,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 28,
      color: AppTheme.borderSubtle,
    );
  }

  Widget _buildMemberPassCard(
    BuildContext context,
    Member member,
    bool isChecked,
    PassRecord? todayPass,
    StudioProfile studio,
  ) {
    final initials = member.name.isNotEmpty ? member.name.substring(0, 1) : '?';
    final isSessionBased = member.billingType == BillingType.sessionBased;
    final isExpiringSoon = isSessionBased && member.remainingSessions <= 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isChecked ? AppTheme.softMint.withAlpha((255 * 0.4).round()) : AppTheme.borderSubtle,
          width: isChecked ? 1.4 : 0.8,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Initials Avatar
              CircleAvatar(
                radius: 22,
                backgroundColor: isChecked ? AppTheme.softMint.withAlpha((255 * 0.15).round()) : AppTheme.chipBackground,
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isChecked ? AppTheme.softMint : AppTheme.primaryDark,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Member Info & Badges
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          member.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.chipBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            member.groupName,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (isSessionBased) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: isExpiringSoon
                                  ? AppTheme.danger.withAlpha((255 * 0.12).round())
                                  : AppTheme.primaryBlue.withAlpha((255 * 0.1).round()),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${member.remainingSessions}/${member.totalSessions}회 남음',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: isExpiringSoon ? AppTheme.danger : AppTheme.primaryBlue,
                              ),
                            ),
                          ),
                        ] else ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.softMint.withAlpha((255 * 0.12).round()),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              '정기 결제 패스',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.softMint,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),

              // Check-in Action Button
              if (isChecked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.softMint.withAlpha((255 * 0.15).round()),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle, size: 16, color: AppTheme.softMint),
                      const SizedBox(width: 4),
                      Text(
                        todayPass?.status == AttendanceStatus.late ? '지각' : '출석됨',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.softMint,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton(
                  onPressed: () => _handleOneTouchCheckIn(member),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text(
                    '체크인',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                ),
            ],
          ),

          // 출결선생 스타일: 체크 완료 시 [등원 문자 알림], [하원 문자 알림] 퀵 서식 발송 버튼 제공
          if (isChecked) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: AppTheme.borderSubtle),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final msg = SmsTemplateService.generateAttendanceMessage(
                        studio: studio,
                        member: member,
                        time: todayPass?.timestamp ?? DateTime.now(),
                      );
                      await SmsTemplateService.launchNativeSms(recipientPhone: member.phone, body: msg);
                    },
                    icon: const Icon(Icons.send_rounded, size: 14, color: AppTheme.primaryBlue),
                    label: const Text('출석 알림 문자', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final msg = SmsTemplateService.generateDepartureMessage(
                        studio: studio,
                        member: member,
                        time: DateTime.now(),
                      );
                      await SmsTemplateService.launchNativeSms(recipientPhone: member.phone, body: msg);
                    },
                    icon: const Icon(Icons.exit_to_app_rounded, size: 14, color: AppTheme.textSecondary),
                    label: const Text('하원 알림 문자', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      side: const BorderSide(color: AppTheme.borderSubtle),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _handleOneTouchCheckIn(Member member) {
    HapticFeedback.mediumImpact();

    ref.read(passRecordsProvider.notifier).checkInMember(
          member: member,
          status: AttendanceStatus.attended,
        );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${member.name} 출석 체크 완료 (잔여 회차가 안전하게 차감되었습니다)'),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _handleBatchCheckIn(BuildContext context) async {
    final members = ref.read(membersProvider).value ?? [];
    final passRecords = ref.read(passRecordsProvider).value ?? [];
    final now = DateTime.now();

    final todayCheckedIds = passRecords
        .where((r) => r.timestamp.year == now.year && r.timestamp.month == now.month && r.timestamp.day == now.day)
        .map((r) => r.memberId)
        .toSet();

    final remaining = members.where((m) => !todayCheckedIds.contains(m.id)).toList();

    if (remaining.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('오늘 남은 출석 대상 회원이 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    await ref.read(passRecordsProvider.notifier).batchCheckInAll(remaining);

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${remaining.length}명의 회원이 일괄 출석 처리되었습니다.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.primaryDark,
        ),
      );
    }
  }

  void _showAttendanceHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('간편 출결 & 문자 알림 안내'),
        content: const Text(
          '1. [체크인] 탭 한 번으로 출석이 기록되고 회차가 자동 차감됩니다.\n'
          '2. 체크 후 나타나는 [출석 알림 문자] 및 [하원 알림 문자]를 누르면 비용 0원으로 학부모/회원에게 안심 알림 문자를 바로 전송할 수 있습니다.\n'
          '3. 모든 데이터는 기기에만 저장되어 서버비가 전혀 들지 않습니다.',
          style: TextStyle(height: 1.5, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('확인'),
          ),
        ],
      ),
    );
  }
}
