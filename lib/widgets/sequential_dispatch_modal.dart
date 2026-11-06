import 'package:flutter/material.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/notification_log.dart';
import '../models/studio_profile.dart';
import '../services/database_service.dart';
import '../services/kakao_share_service.dart';
import '../services/sequential_dispatch_service.dart';
import '../services/sms_template_service.dart';
import '../theme/app_theme.dart';
import 'app_bottom_sheet.dart';
import 'app_text_field.dart';
import 'responsive_dialog_actions.dart';

enum _WizardPhase {
  config,
  dispatch,
  completed,
}

enum _TargetFilterMode {
  all,
  byGroup,
  unpaidOnly,
  expiringOnly,
  customSelect,
}

class SequentialDispatchModal extends StatefulWidget {
  final List<Member> allMembers;
  final StudioProfile studio;
  final List<Invoice>? invoices;
  final String? initialTargetGroup;
  final List<String>? initialSelectedMemberIds;
  final DispatchTemplateType? initialTemplateType;
  final Future<bool> Function(String text, String? subject)? onShareKakao;
  final Future<bool> Function(String phone, String body)? onSendSms;

  const SequentialDispatchModal({
    super.key,
    required this.allMembers,
    required this.studio,
    this.invoices,
    this.initialTargetGroup,
    this.initialSelectedMemberIds,
    this.initialTemplateType,
    this.onShareKakao,
    this.onSendSms,
  });

  static Future<void> show({
    required BuildContext context,
    required List<Member> allMembers,
    required StudioProfile studio,
    List<Invoice>? invoices,
    String? initialTargetGroup,
    List<String>? initialSelectedMemberIds,
    DispatchTemplateType? initialTemplateType,
    Future<bool> Function(String text, String? subject)? onShareKakao,
    Future<bool> Function(String phone, String body)? onSendSms,
  }) {
    return AppBottomSheet.show(
      context: context,
      maxHeightRatio: 0.94,
      builder: (_) => SequentialDispatchModal(
        allMembers: allMembers,
        studio: studio,
        invoices: invoices,
        initialTargetGroup: initialTargetGroup,
        initialSelectedMemberIds: initialSelectedMemberIds,
        initialTemplateType: initialTemplateType,
        onShareKakao: onShareKakao,
        onSendSms: onSendSms,
      ),
    );
  }

  @override
  State<SequentialDispatchModal> createState() => _SequentialDispatchModalState();
}

class _SequentialDispatchModalState extends State<SequentialDispatchModal> {
  _WizardPhase _phase = _WizardPhase.config;
  late _TargetFilterMode _filterMode;
  late DispatchTemplateType _selectedTemplateType;

  final TextEditingController _templateController = TextEditingController();
  final Set<String> _selectedMemberIds = {};
  String? _selectedGroup;

  // Dispatch Player State
  List<SequentialDispatchItem> _dispatchQueue = [];
  int _currentIndex = 0;
  final TextEditingController _currentMessageController = TextEditingController();

  @override
  void initState() {
    super.initState();

    _selectedTemplateType = widget.initialTemplateType ?? DispatchTemplateType.billing;
    _templateController.text = SequentialDispatchService.getDefaultTemplate(_selectedTemplateType);

    if (widget.initialSelectedMemberIds != null && widget.initialSelectedMemberIds!.isNotEmpty) {
      _filterMode = _TargetFilterMode.customSelect;
      _selectedMemberIds.addAll(widget.initialSelectedMemberIds!);
    } else if (widget.initialTargetGroup != null) {
      _filterMode = _TargetFilterMode.byGroup;
      _selectedGroup = widget.initialTargetGroup;
    } else if (widget.initialTemplateType == DispatchTemplateType.billing) {
      _filterMode = _TargetFilterMode.unpaidOnly;
    } else {
      _filterMode = _TargetFilterMode.all;
    }
  }

  @override
  void dispose() {
    _templateController.dispose();
    _currentMessageController.dispose();
    super.dispose();
  }

  List<Member> get _filteredMembers {
    switch (_filterMode) {
      case _TargetFilterMode.all:
        return widget.allMembers;
      case _TargetFilterMode.byGroup:
        if (_selectedGroup == null) return widget.allMembers;
        return widget.allMembers.where((m) => m.groupName == _selectedGroup).toList();
      case _TargetFilterMode.unpaidOnly:
        final unpaidMemberIds = (widget.invoices ?? [])
            .where((i) => i.status == PaymentStatus.unpaid)
            .expand((i) => i.memberIds)
            .toSet();
        return widget.allMembers.where((m) => unpaidMemberIds.contains(m.id)).toList();
      case _TargetFilterMode.expiringOnly:
        return widget.allMembers
            .where((m) => m.billingType == BillingType.sessionBased && m.remainingSessions <= 1)
            .toList();
      case _TargetFilterMode.customSelect:
        return widget.allMembers.where((m) => _selectedMemberIds.contains(m.id)).toList();
    }
  }

  List<String> get _availableGroups {
    final groups = widget.allMembers.map((m) => m.groupName).toSet().toList();
    groups.sort();
    return groups;
  }

  void _insertVariable(String tag) {
    final text = _templateController.text;
    final selection = _templateController.selection;
    final start = selection.start >= 0 ? selection.start : text.length;
    final end = selection.end >= 0 ? selection.end : text.length;

    final newText = text.replaceRange(start, end, tag);
    _templateController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: start + tag.length),
    );
    setState(() {});
  }

  void _startDispatch() {
    final targets = _filteredMembers;
    if (targets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('발송 대상 회원이 없습니다. 대상을 선택해주세요.')),
      );
      return;
    }

    _dispatchQueue = SequentialDispatchService.buildDispatchItems(
      members: targets,
      studio: widget.studio,
      template: _templateController.text.trim(),
      invoices: widget.invoices,
    );

    _currentIndex = 0;
    _currentMessageController.text = _dispatchQueue.first.message;
    setState(() {
      _phase = _WizardPhase.dispatch;
    });
  }

  Future<void> _sendCurrentViaKakao() async {
    final item = _dispatchQueue[_currentIndex];
    final updatedMsg = _currentMessageController.text.trim();
    item.message = updatedMsg;

    // Send Kakao
    if (widget.onShareKakao != null) {
      await widget.onShareKakao!(updatedMsg, '[${widget.studio.studioName}] 안내');
    } else {
      await KakaoShareService.shareMessage(
        text: updatedMsg,
        subject: '[${widget.studio.studioName}] 안내',
      );
    }

    item.isSent = true;
    item.sentChannel = 'KAKAO';

    DatabaseService.instance.insertNotificationLog(
      NotificationLog(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${item.member.id}',
        type: _resolveNotifType(_selectedTemplateType),
        memberId: item.member.id,
        memberName: item.member.name,
        recipientPhone: item.recipientPhone,
        channel: 'KAKAO',
        message: updatedMsg,
        sentAt: DateTime.now(),
      ),
    ).catchError((_) {});

    _moveToNext();
  }

  NotificationType _resolveNotifType(DispatchTemplateType type) {
    switch (type) {
      case DispatchTemplateType.billing:
        return NotificationType.billing;
      case DispatchTemplateType.sessionExpiry:
        return NotificationType.sessionExpiry;
      case DispatchTemplateType.notice:
      case DispatchTemplateType.custom:
        return NotificationType.notice;
    }
  }

  Future<void> _sendCurrentViaSms() async {
    final item = _dispatchQueue[_currentIndex];
    final updatedMsg = _currentMessageController.text.trim();
    item.message = updatedMsg;

    // Send SMS
    if (widget.onSendSms != null) {
      await widget.onSendSms!(item.recipientPhone, updatedMsg);
    } else {
      await SmsTemplateService.launchNativeSms(
        recipientPhone: item.recipientPhone,
        body: updatedMsg,
      );
    }

    item.isSent = true;
    item.sentChannel = 'SMS';

    DatabaseService.instance.insertNotificationLog(
      NotificationLog(
        id: 'notif_${DateTime.now().millisecondsSinceEpoch}_${item.member.id}',
        type: _resolveNotifType(_selectedTemplateType),
        memberId: item.member.id,
        memberName: item.member.name,
        recipientPhone: item.recipientPhone,
        channel: 'SMS',
        message: updatedMsg,
        sentAt: DateTime.now(),
      ),
    ).catchError((_) {});

    _moveToNext();
  }

  void _skipCurrent() {
    final item = _dispatchQueue[_currentIndex];
    item.isSent = false;
    item.sentChannel = 'SKIPPED';
    _moveToNext();
  }

  void _moveToNext() {
    if (_currentIndex + 1 < _dispatchQueue.length) {
      setState(() {
        _currentIndex++;
        _currentMessageController.text = _dispatchQueue[_currentIndex].message;
      });
    } else {
      setState(() {
        _phase = _WizardPhase.completed;
      });
    }
  }

  void _moveToPrevious() {
    if (_currentIndex > 0) {
      setState(() {
        _currentIndex--;
        _currentMessageController.text = _dispatchQueue[_currentIndex].message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: _buildCurrentPhaseWidget(),
    );
  }

  Widget _buildCurrentPhaseWidget() {
    switch (_phase) {
      case _WizardPhase.config:
        return _buildConfigPhase();
      case _WizardPhase.dispatch:
        return _buildDispatchPhase();
      case _WizardPhase.completed:
        return _buildCompletedPhase();
    }
  }

  // ==========================================
  // PHASE 1: 발송 설정 및 템플릿 작성 화면
  // ==========================================
  Widget _buildConfigPhase() {
    final targets = _filteredMembers;
    final groups = _availableGroups;

    return SingleChildScrollView(
      key: const ValueKey('config_phase'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.mark_chat_unread_outlined, color: AppTheme.primaryBlue, size: 22),
                  SizedBox(width: 8),
                  Text(
                    '스마트 순차 단체발송',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            '문자비 0원 카톡 또는 문자 앱으로 여러 회원에게 맞춤 메시지를 순차적으로 릴레이 발송합니다.',
            style: TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 14),

          // 1. 발송 대상 선택
          const Text('1. 발송 대상 선택', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTargetChip('전체 회원 (${widget.allMembers.length}명)', _TargetFilterMode.all),
                const SizedBox(width: 6),
                _buildTargetChip('그룹별 선택', _TargetFilterMode.byGroup),
                const SizedBox(width: 6),
                _buildTargetChip('미납 회원만', _TargetFilterMode.unpaidOnly),
                const SizedBox(width: 6),
                _buildTargetChip('만료 임박(1회이하)', _TargetFilterMode.expiringOnly),
                const SizedBox(width: 6),
                _buildTargetChip('직접 선택 (${_selectedMemberIds.length}명)', _TargetFilterMode.customSelect),
              ],
            ),
          ),

          // Sub-filter for Group
          if (_filterMode == _TargetFilterMode.byGroup) ...[
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: groups.map((g) {
                  final isSel = _selectedGroup == g;
                  final count = widget.allMembers.where((m) => m.groupName == g).length;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$g ($count명)', style: TextStyle(fontSize: 12, color: isSel ? Colors.white : AppTheme.textPrimary)),
                      selected: isSel,
                      selectedColor: const Color(0xFF6366F1),
                      backgroundColor: Colors.white,
                      onSelected: (val) {
                        setState(() => _selectedGroup = val ? g : null);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
          ],

          // Sub-filter for Custom Member Selection
          if (_filterMode == _TargetFilterMode.customSelect) ...[
            const SizedBox(height: 8),
            Container(
              constraints: const BoxConstraints(maxHeight: 140),
              decoration: BoxDecoration(
                border: Border.all(color: AppTheme.borderSubtle),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.allMembers.length,
                itemBuilder: (ctx, idx) {
                  final m = widget.allMembers[idx];
                  final isChecked = _selectedMemberIds.contains(m.id);
                  return CheckboxListTile(
                    dense: true,
                    title: Text('${m.name} (${m.groupName})', style: const TextStyle(fontSize: 13)),
                    subtitle: Text(m.phone, style: const TextStyle(fontSize: 11.5)),
                    value: isChecked,
                    activeColor: AppTheme.primaryBlue,
                    onChanged: (val) {
                      setState(() {
                        if (val == true) {
                          _selectedMemberIds.add(m.id);
                        } else {
                          _selectedMemberIds.remove(m.id);
                        }
                      });
                    },
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 16),

          // 2. 템플릿 선택
          const Text('2. 메시지 양식(템플릿) 선택', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary)),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: DispatchTemplateType.values.map((t) {
                final isSel = _selectedTemplateType == t;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: Text(
                      SequentialDispatchService.getTemplateName(t),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                        color: isSel ? Colors.white : AppTheme.textPrimary,
                      ),
                    ),
                    selected: isSel,
                    selectedColor: AppTheme.primaryBlue,
                    backgroundColor: Colors.white,
                    onSelected: (val) {
                      if (val) {
                        setState(() {
                          _selectedTemplateType = t;
                          _templateController.text = SequentialDispatchService.getDefaultTemplate(t);
                        });
                      }
                    },
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 12),

          // Quick Insert Variable Chips
          Row(
            children: [
              const Text('변수 자동 치환 태그:', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary)),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildVariableChip('#{회원명}'),
                      _buildVariableChip('#{그룹명}'),
                      _buildVariableChip('#{금액}'),
                      _buildVariableChip('#{계좌정보}'),
                      _buildVariableChip('#{토스송금링크}'),
                      _buildVariableChip('#{카드결제링크}'),
                      _buildVariableChip('#{잔여회차}'),
                      _buildVariableChip('#{납부기한}'),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          AppTextField(
            controller: _templateController,
            label: '템플릿 본문 내용',
            maxLines: 7,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 14),

          // Preview of 1st recipient
          if (targets.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.borderSubtle),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.preview_outlined, size: 14, color: AppTheme.primaryBlue),
                      const SizedBox(width: 4),
                      Text(
                        '1번째 대상자 (${targets.first.name}) 치환 미리보기',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    SequentialDispatchService.renderMessage(
                      template: _templateController.text.trim(),
                      studio: widget.studio,
                      member: targets.first,
                      invoice: widget.invoices?.where((i) => i.memberIds.contains(targets.first.id)).firstOrNull,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Start Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: targets.isEmpty ? null : _startDispatch,
              icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
              label: Text(
                '총 ${targets.length}명 순차 릴레이 발송 시작 🚀',
                style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildTargetChip(String label, _TargetFilterMode mode) {
    final isSel = _filterMode == mode;
    return ChoiceChip(
      label: Text(label, style: TextStyle(fontSize: 12, fontWeight: isSel ? FontWeight.w700 : FontWeight.w500, color: isSel ? Colors.white : AppTheme.textPrimary)),
      selected: isSel,
      selectedColor: const Color(0xFF0F172A),
      backgroundColor: Colors.white,
      onSelected: (val) {
        if (val) setState(() => _filterMode = mode);
      },
    );
  }

  Widget _buildVariableChip(String tag) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        label: Text(tag, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
        backgroundColor: const Color(0xFFEFF6FF),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(6),
          side: const BorderSide(color: Color(0xFFBFDBFE)),
        ),
        padding: EdgeInsets.zero,
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        onPressed: () => _insertVariable(tag),
      ),
    );
  }

  // ==========================================
  // PHASE 2: 순차 릴레이 발송 플레이어 (Wizard)
  // ==========================================
  Widget _buildDispatchPhase() {
    final total = _dispatchQueue.length;
    final currentItem = _dispatchQueue[_currentIndex];
    final member = currentItem.member;
    final progress = (_currentIndex + 1) / total;

    final sentCount = _dispatchQueue.where((i) => i.isSent).length;
    final skippedCount = _dispatchQueue.where((i) => i.sentChannel == 'SKIPPED').length;

    return SingleChildScrollView(
      key: const ValueKey('dispatch_phase'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / $total명',
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    '순차 릴레이 발송 중',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: '발송 중단',
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Linear Progress Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE2E8F0),
              color: AppTheme.softMint,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '발송 성공 $sentCount명 (건너뜀 $skippedCount명)',
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              Text(
                '${(progress * 100).toInt()}% 완료',
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.softMint),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Current Recipient Info Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppTheme.primaryBlue.withValues(alpha: 0.1),
                  child: Text(
                    member.name.substring(0, 1),
                    style: const TextStyle(color: AppTheme.primaryBlue, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            member.name,
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              member.groupName,
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '수신 번호: ${currentItem.recipientPhone}',
                        style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                if (currentItem.isSent)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFF10B981)),
                    ),
                    child: Text(
                      currentItem.sentChannel == 'KAKAO' ? '카톡 완료' : '문자 완료',
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: Color(0xFF059669)),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Personalized Message Editor
          AppTextField(
            controller: _currentMessageController,
            label: '${member.name.split(' ').first} 회원 맞춤 메시지 (발송 전 수정 가능)',
            maxLines: 7,
          ),
          const SizedBox(height: 14),

          // Primary One-Tap Actions
          Row(
            children: [
              // 1. Kakao Talk 0원 전송
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sendCurrentViaKakao,
                  icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF191919), size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '카톡 0원 전송 후 다음',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF191919)),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE500),
                    foregroundColor: const Color(0xFF191919),
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // 2. 문자(SMS) 앱 전송
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _sendCurrentViaSms,
                  icon: const Icon(Icons.sms_outlined, color: Colors.white, size: 16),
                  label: const FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '문자 전송 후 다음',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Colors.white),
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Sub Actions: 건너뛰기, 이전 회원
          ResponsiveDialogActions(
            breakpoint: 320,
            secondary: OutlinedButton.icon(
              onPressed: _currentIndex > 0 ? _moveToPrevious : null,
              icon: const Icon(Icons.arrow_back_ios_new, size: 13),
              label: const Text('이전 회원'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            primary: OutlinedButton.icon(
              onPressed: _skipCurrent,
              icon: const Icon(Icons.skip_next_rounded, size: 16),
              label: const Text('이 회원 건너뛰기'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  // ==========================================
  // PHASE 3: 발송 완료 및 결과 요약 화면
  // ==========================================
  Widget _buildCompletedPhase() {
    final total = _dispatchQueue.length;
    final kakaoCount = _dispatchQueue.where((i) => i.sentChannel == 'KAKAO').length;
    final smsCount = _dispatchQueue.where((i) => i.sentChannel == 'SMS').length;
    final skippedCount = _dispatchQueue.where((i) => i.sentChannel == 'SKIPPED').length;

    return SingleChildScrollView(
      key: const ValueKey('completed_phase'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3), width: 2),
            ),
            child: const Icon(Icons.check_circle_rounded, color: Color(0xFF059669), size: 48),
          ),
          const SizedBox(height: 16),
          const Text(
            '순차 릴레이 발송 완료!',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          const Text(
            '선택된 대상 회원들에게 카카오톡 및 문자로 안내가 성공적으로 전달되었습니다.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 20),

          // Statistics Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderSubtle),
              boxShadow: AppTheme.cardShadow,
            ),
            child: Column(
              children: [
                _buildStatRow('총 대상 회원', '$total명', AppTheme.textPrimary),
                const Divider(height: 16),
                _buildStatRow('카카오톡 (0원) 발송', '$kakaoCount건', const Color(0xFFEAB308)),
                const SizedBox(height: 6),
                _buildStatRow('기본 문자(SMS) 발송', '$smsCount건', AppTheme.primaryBlue),
                const SizedBox(height: 6),
                _buildStatRow('건너뜀 / 미발송', '$skippedCount건', AppTheme.textTertiary),
              ],
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryBlue,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text(
                '확인 및 닫기',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13.5, color: AppTheme.textSecondary)),
        Text(value, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: valueColor)),
      ],
    );
  }
}
