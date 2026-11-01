import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/member.dart';
import '../models/pass_record.dart';
import '../models/studio_profile.dart';
import '../providers/app_providers.dart';
import '../services/chosung_search_service.dart';
import '../services/sms_template_service.dart';
import '../services/coach_mark_service.dart';
import '../services/monetization_service.dart';
import '../theme/app_theme.dart';
import '../widgets/coach_mark_dialog.dart';
import '../widgets/digital_pass_card_dialog.dart';
import '../widgets/interactive_guide_dialog.dart';
import '../widgets/signature_key_visual_hero.dart';
import 'home_navigation_screen.dart';
import 'onboarding_screen.dart';
import 'tablet_kiosk_screen.dart';

class PassDashboardScreen extends ConsumerStatefulWidget {
  const PassDashboardScreen({super.key});

  @override
  ConsumerState<PassDashboardScreen> createState() => _PassDashboardScreenState();
}

class _PassDashboardScreenState extends ConsumerState<PassDashboardScreen> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _selectedGroup = '전체 그룹';
  String _statusFilter = '전체'; // '전체', '출결 대기', '체크 완료', '만료 임박'

  @override
  void initState() {
    super.initState();
    _searchFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _openInteractiveGuide(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Color(0xFF1E293B),
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/icons/splash_icon.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '패시 가이드 센터',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '원하시는 안내 가이드를 선택해주세요',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              tileColor: const Color(0xFFF8FAFC),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_stories_rounded, color: AppTheme.primaryBlue),
              ),
              title: const Text(
                '서비스 첫걸음 핵심 소개 (온보딩)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              subtitle: const Text(
                '서버비 0원 출결, 무료 문자, 스마트 장부 기능 둘러보기',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => OnboardingScreen(onFinish: () => Navigator.pop(context))),
                );
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: Colors.grey.shade200),
              ),
              tileColor: const Color(0xFFF8FAFC),
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.softMint.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.checklist_rounded, color: AppTheme.softMint),
              ),
              title: const Text(
                '스텝바이스텝 실전 연습 코칭',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              subtitle: const Text(
                '스튜디오 정보 설정부터 실제 회원 등록 및 출결 체크 실습',
                style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
              ),
              trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textSecondary),
              onTap: () {
                Navigator.pop(ctx);
                StepByStepPracticeGuideDialog.show(
                  context,
                  onOpenAddMember: () {
                    HomeNavigationScreen.of(context)?.switchToTab(2);
                  },
                  onOpenSettings: () {
                    HomeNavigationScreen.of(context)?.switchToTab(3);
                  },
                );
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }


  void _openTabletKioskMode(BuildContext context) {
    // Check if Kiosk Pro unlocked
    final isUnlocked = MonetizationService.instance.isKioskProUnlocked;

    if (isUnlocked) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (ctx) => const TabletKioskScreen()),
      );
    } else {
      // Show Kiosk Pro Unlock & Free Trial Offer
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: const [
              Icon(Icons.tablet_mac_rounded, color: AppTheme.primaryBlue, size: 26),
              SizedBox(width: 8),
              Text('태블릿 자율출결 키오스크', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.star_rounded, color: Color(0xFF2563EB), size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '매장 입구에 거치해 두면 학생들이 직접 뒷번호 4자리만 누르고 입장!',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: Color(0xFF1E40AF)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.bolt_rounded, size: 16, color: AppTheme.primaryBlue),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '1초 출석 체크 + 잔여 회차 자동 차감',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.mark_chat_read_outlined, size: 16, color: AppTheme.softMint),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '즉시 학부모/회원 안심 문자 전송',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Icon(Icons.lock_outline_rounded, size: 16, color: Color(0xFFF59E0B)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '관리자 비밀번호(0000) 잠금 보호',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(Icons.savings_outlined, size: 16, color: Color(0xFF10B981)),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '타사 월 3~5만원 키오스크 대비 0원 유지비',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Color(0xFF334155)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('키오스크 프로 평생 소장권', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                      Text('19,900원 (1회)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                // Free Trial Run directly!
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const TabletKioskScreen()),
                );
              },
              child: const Text('무료 체험 실행해보기'),
            ),
            ElevatedButton(
              onPressed: () async {
                await MonetizationService.instance.setDebugUnlock(kioskPro: true);
                if (ctx.mounted) Navigator.pop(ctx);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('키오스크 프로 모드가 활성화되었습니다.')),
                  );
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (c) => const TabletKioskScreen()),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: const Text('프로 평생 소장권 구매', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final membersAsync = ref.watch(membersProvider);
    final passRecordsAsync = ref.watch(passRecordsProvider);
    final studioAsync = ref.watch(studioProfileProvider);

    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        toolbarHeight: isLandscape ? 56 : 72,
        titleSpacing: 16,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!isLandscape) ...[
              Text(
                DateFormat('M월 d일 EEEE', 'ko_KR').format(DateTime.now()),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
            ],
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                '원터치 출결 체크',
                style: TextStyle(
                  fontSize: isLandscape ? 17 : 20.5,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                  letterSpacing: -0.6,
                ),
              ),
            ),
          ],
        ),
        actions: [
          // Tab 0 필수 전용 기능: 매장 입구 무인 자율출결 키오스크 모드 (중복 제거 & 단일 필수 메뉴 집중)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => _openTabletKioskMode(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.primaryBlue.withValues(alpha: 0.3)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.tablet_mac_rounded, color: AppTheme.primaryBlue, size: 17),
                        SizedBox(width: 5),
                        Text(
                          '무인 키오스크',
                          style: TextStyle(
                            color: AppTheme.primaryBlue,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
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

              // Filter members list using ChosungSearchService and Status filters
              var filteredMembers = members.where((m) {
                if (_selectedGroup != '전체 그룹' && m.groupName != _selectedGroup) {
                  return false;
                }
                final isChecked = checkedMemberIds.contains(m.id);
                if (_statusFilter == '출결 대기' && isChecked) return false;
                if (_statusFilter == '체크 완료' && !isChecked) return false;
                if (_statusFilter == '만료 임박') {
                  final isSession = m.billingType == BillingType.sessionBased;
                  if (!isSession || m.remainingSessions > 2) return false;
                }
                if (_searchQuery.isNotEmpty) {
                  if (!ChosungSearchService.matchesAny([m.name, m.phone, m.groupName, m.payerName, m.memo], _searchQuery)) {
                    return false;
                  }
                }
                return true;
              }).toList();

              final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0 ||
                  View.of(context).viewInsets.bottom > 0;
              final isSearching = _searchQuery.isNotEmpty || _searchFocusNode.hasFocus;

              return LayoutBuilder(
                builder: (context, constraints) {
                  final isShortHeight = constraints.maxHeight < 560;
                  final hideHero = isLandscape || isKeyboardOpen || isSearching || isShortHeight;

                  return Column(
                    children: [
                      // Signature Portfolio Key Visual Hero (Living Aurora Glass & Pulse Radar)
                      if (!hideHero)
                        SignatureKeyVisualHero(
                          members: members,
                          todayRecords: todayRecords,
                          studio: studio,
                          onOpenKiosk: () => _openTabletKioskMode(context),
                          onOpenGuide: () => _openInteractiveGuide(context),
                        ),

                  // 0. Korean Chosung & Real-time Smart Search Bar
                  Padding(
                    padding: const EdgeInsets.fromLTRB(18, 6, 18, 6),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                        boxShadow: AppTheme.cardShadow,
                      ),
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _searchFocusNode.unfocus(),
                        onChanged: (val) => setState(() => _searchQuery = val.trim()),
                        decoration: InputDecoration(
                          hintText: '이름·초성(ㅇㄷㅎ)·뒷번호 4자리 검색',
                          hintStyle: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary),
                          prefixIcon: const Icon(Icons.search_rounded, color: AppTheme.primaryBlue, size: 21),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                    _searchFocusNode.unfocus();
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        ),
                      ),
                    ),
                  ),

                  // Landscape Compact Metric Card Fallback
                  if (isLandscape)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: AppTheme.cardShadow,
                          border: Border.all(color: AppTheme.borderSubtle, width: 0.8),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildStatItem('출석 완료', attendedCount, AppTheme.softMint, isCompact: true),
                            _buildDivider(),
                            _buildStatItem('지각/보강', lateCount, AppTheme.warning, isCompact: true),
                            _buildDivider(),
                            _buildStatItem('출결 대기', remainingMembersCount, AppTheme.primaryBlue, isCompact: true),
                          ],
                        ),
                      ),
                    ),

                  // 2. Filter Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    child: Row(
                      children: [
                        ...groups.take(5).map((g) {
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
                                fontSize: 12.5,
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
                            const PopupMenuItem(value: '출결 대기', child: Text('출결 대기만')),
                            const PopupMenuItem(value: '체크 완료', child: Text('체크 완료만')),
                            const PopupMenuItem(value: '만료 임박', child: Text('만료 임박(2회 이하)')),
                          ],
                          child: Chip(
                            label: Row(
                              children: [
                                Text('필터: $_statusFilter'),
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
                            padding: EdgeInsets.fromLTRB(18, 4, 18, isKeyboardOpen ? 12 : 90),
                            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
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

                  // Batch Action Bar placed directly inside body above bottom navigation bar / keyboard
                  Builder(
                    builder: (ctx) {
                      final searchRemainingMembers = filteredMembers.where((m) => !checkedMemberIds.contains(m.id)).toList();
                      final isSearchActive = _searchQuery.isNotEmpty;
                      final targetCount = isSearchActive ? searchRemainingMembers.length : remainingMembersCount;

                      return Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: isLandscape ? 6 : (isKeyboardOpen ? 8 : 10),
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: const Border(top: BorderSide(color: AppTheme.borderSubtle, width: 0.8)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withAlpha((255 * 0.05).round()),
                              offset: const Offset(0, -3),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: SafeArea(
                          top: false,
                          bottom: !isKeyboardOpen,
                          child: Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: targetCount > 0
                                      ? () => _handleBatchCheckIn(
                                            context,
                                            targetMembers: isSearchActive ? filteredMembers : null,
                                          )
                                      : null,
                                  icon: const Icon(Icons.done_all, color: Colors.white, size: 18),
                                  label: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      isSearchActive
                                          ? (targetCount > 0
                                              ? '검색 결과 일괄 출석 ($targetCount명)'
                                              : '검색 회원 출석 완료됨')
                                          : (isLandscape ? '남은 회원 일괄 출석' : '남은 회원 일괄 출석 완료'),
                                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5),
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.primaryDark,
                                    disabledBackgroundColor: Colors.grey.shade400,
                                    padding: EdgeInsets.symmetric(vertical: isLandscape ? 8 : (isKeyboardOpen ? 10 : 12)),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          );
        },
      );
    },
  ),
);
}

  Widget _buildStatItem(String label, int count, Color color, {bool isCompact = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: isCompact ? 17 : 22,
            fontWeight: FontWeight.w800,
            color: color,
            letterSpacing: -0.5,
          ),
        ),
        SizedBox(height: isCompact ? 2 : 4),
        Text(
          label,
          style: TextStyle(
            fontSize: isCompact ? 11 : 12,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Top Section: Avatar + Full-width Name & Group (Extends all the way across)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isChecked ? AppTheme.softMint.withAlpha((255 * 0.15).round()) : AppTheme.chipBackground,
                  border: Border.all(
                    color: isChecked ? AppTheme.softMint : AppTheme.borderSubtle,
                    width: 0.8,
                  ),
                ),
                child: ClipOval(
                  child: member.photoPath != null &&
                          member.photoPath!.isNotEmpty &&
                          File(member.photoPath!).existsSync()
                      ? Image.file(
                          File(member.photoPath!),
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                        )
                      : Center(
                          child: Text(
                            initials,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: isChecked ? AppTheme.softMint : AppTheme.primaryDark,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
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
              ),
              InkWell(
                onTap: () {
                  DigitalPassCardDialog.show(
                    context: context,
                    member: member,
                    studio: studio,
                    latestRecord: todayPass,
                  );
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0xFFBFDBFE), width: 0.8),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.badge_outlined, size: 13, color: AppTheme.primaryBlue),
                      SizedBox(width: 4),
                      Text(
                        '패스 카드',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Middle Row: Pass Type / Session Badge & One-touch Check-in Button
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              if (isSessionBased) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isExpiringSoon
                        ? AppTheme.danger.withAlpha((255 * 0.12).round())
                        : AppTheme.primaryBlue.withAlpha((255 * 0.1).round()),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${member.remainingSessions}/${member.totalSessions}회 남음 ${isExpiringSoon ? "(만료임박)" : ""}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isExpiringSoon ? AppTheme.danger : AppTheme.primaryBlue,
                    ),
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.softMint.withAlpha((255 * 0.12).round()),
                    borderRadius: BorderRadius.circular(8),
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

              // Check-in Action Button / Status Badge
              if (isChecked)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.softMint.withAlpha((255 * 0.15).round()),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle, size: 15, color: AppTheme.softMint),
                      const SizedBox(width: 5),
                      Text(
                        todayPass?.status == AttendanceStatus.late ? '지각' : '출석 완료',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.softMint,
                        ),
                      ),
                    ],
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () => _handleOneTouchCheckIn(member),
                  icon: const Icon(Icons.check, size: 15, color: Colors.white),
                  label: const Text(
                    '체크인',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
                    icon: const Icon(Icons.send_rounded, size: 13, color: AppTheme.primaryBlue),
                    label: const Text('출석 알림', style: TextStyle(fontSize: 11.5)),
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
                    icon: const Icon(Icons.exit_to_app_rounded, size: 13, color: AppTheme.textSecondary),
                    label: const Text('하원 알림', style: TextStyle(fontSize: 11.5)),
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

  void _handleOneTouchCheckIn(Member member) async {
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

    // First-touch coach mark for Check-In
    await CoachMarkDialog.showIfFirstTime(
      context: context,
      coachKey: CoachMarkService.keyCheckIn,
      title: '첫 번째 출석 체크 완료',
      message: '회원이 도착했을 때 [체크인]을 누르면 이렇게 1초 만에 회차가 차감돼요.\n\n출석 완료 후 카드 아래의 [출석 알림 문자]를 누르면 부모님께 안심 문자를 비용 0원으로 바로 보낼 수 있어요!',
      tip: '정기권 회원은 출석 기록만 남고, 회차권 회원은 1회씩 자동 차감됩니다.',
      buttonText: '확인',
    );
  }

  void _handleBatchCheckIn(BuildContext context, {List<Member>? targetMembers}) async {
    final members = targetMembers ?? (ref.read(membersProvider).value ?? []);
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
          content: Text('출석 대상 회원이 없습니다.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // UX 고도화: 대량 일괄 출석 처리 전 확인 다이얼로그 (실수 터치 방지)
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.done_all_rounded, color: AppTheme.primaryBlue, size: 24),
            SizedBox(width: 8),
            Text('일괄 출석 체크', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          ],
        ),
        content: Text(
          '오늘 아직 출석하지 않은 회원 ${remaining.length}명을 모두 출석 완료 처리하시겠습니까?\n\n(회차권 회원은 잔여 회차가 1회씩 안전하게 차감됩니다)',
          style: const TextStyle(fontSize: 13.5, height: 1.45, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소', style: TextStyle(color: AppTheme.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('일괄 출석 완료', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

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
}

