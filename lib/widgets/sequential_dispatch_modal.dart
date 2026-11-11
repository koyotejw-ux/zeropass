import 'package:flutter/material.dart';
import '../models/custom_category_template.dart';
import '../models/invoice.dart';
import '../models/member.dart';
import '../models/notification_log.dart';
import '../models/studio_profile.dart';
import '../services/custom_category_service.dart';
import '../services/database_service.dart';
import '../services/kakao_share_service.dart';
import '../services/localization_service.dart';
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
  String? _selectedCustomTemplateId;
  List<CustomMessageTemplate> _customMessageTemplates = [];

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
    _loadCustomMessageTemplates();

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

  Future<void> _loadCustomMessageTemplates() async {
    final catState = await CustomCategoryService.instance.loadCategories(
      industryCategory: widget.studio.category,
    );
    if (!mounted) return;
    setState(() {
      _customMessageTemplates = catState.messageTemplates;
    });
  }

  Future<void> _saveCurrentBodyAsCustomTemplate() async {
    final body = _templateController.text.trim();
    if (body.isEmpty) return;

    final titleCtrl = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dlgCtx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          LocalizationService.pick(
            ko: '내 맞춤 서식으로 저장',
            en: 'Save as Custom Template',
            ja: 'マイテンプレートとして保存',
            zh: '保存为自定义模板',
            vi: 'Lưu làm mẫu tùy chỉnh',
            es: 'Guardar como Plantilla',
          ),
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
        content: AppTextField(
          controller: titleCtrl,
          label: LocalizationService.pick(
            ko: '서식 제목',
            en: 'Template Title',
            ja: 'テンプレート名',
            zh: '模板名称',
            vi: 'Tiêu đề mẫu',
            es: 'Título de plantilla',
          ),
          hint: LocalizationService.pick(
            ko: '예: 특강 모집 안내, 휴강 공지',
            en: 'e.g. Workshop Invite, Holiday Notice',
            ja: '例：特別講座のご案内、休講のお知らせ',
            zh: '例：特训招新通知、停课公告',
            vi: 'VD: Mời học chuyên đề, Thông báo nghỉ lễ',
            es: 'Ej. Aviso de taller, Cierre festivo',
          ),
          prefixIcon: Icons.bookmark_add_outlined,
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          ResponsiveDialogActions(
            secondary: TextButton(
              onPressed: () => Navigator.pop(dlgCtx, false),
              child: Text(LocalizationService.tr('btn_cancel'), style: const TextStyle(color: AppTheme.textSecondary)),
            ),
            primary: ElevatedButton(
              onPressed: () async {
                final title = titleCtrl.text.trim();
                if (title.isEmpty) return;
                final newTpl = CustomMessageTemplate(
                  id: 'msg_tpl_${DateTime.now().millisecondsSinceEpoch}',
                  title: title,
                  body: body,
                  categoryTag: LocalizationService.pick(
                    ko: '일괄발송',
                    en: 'Bulk Dispatch',
                    ja: '一斉送信',
                    zh: '批量发送',
                    vi: 'Gửi hàng loạt',
                    es: 'Envío masivo',
                  ),
                );
                final updated = await CustomCategoryService.instance.saveMessageTemplate(
                  newTpl,
                  industryCategory: widget.studio.category,
                );
                if (mounted) {
                  setState(() {
                    _customMessageTemplates = updated.messageTemplates;
                    _selectedCustomTemplateId = newTpl.id;
                  });
                }
                if (dlgCtx.mounted) Navigator.pop(dlgCtx, true);
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryBlue),
              child: Text(
                LocalizationService.pick(
                  ko: '서식 저장',
                  en: 'Save Template',
                  ja: '保存する',
                  zh: '保存模板',
                  vi: 'Lưu mẫu',
                  es: 'Guardar',
                ),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
    titleCtrl.dispose();
    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocalizationService.pick(
              ko: '현재 문구가 내 맞춤 서식에 저장되었습니다.',
              en: 'Message saved to your custom templates.',
              ja: '現在のメッセージをマイテンプレートに保存しました。',
              zh: '当前文本已保存至自定义模板。',
              vi: 'Đã lưu nội dung vào mẫu tùy chỉnh.',
              es: 'Mensaje guardado en tus plantillas personalizadas.',
            ),
          ),
        ),
      );
    }
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
            .where((m) => m.billingType == BillingType.sessionBased && m.remainingSessions <= 2)
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
        SnackBar(
          content: Text(
            LocalizationService.pick(
              ko: '발송 대상 회원이 없습니다. 대상을 선택해주세요.',
              en: 'No recipient members matched. Please select targets.',
              ja: '送信対象の会員がいません。対象を選択してください。',
              zh: '没有可发送的会员，请先选择对象。',
              vi: 'Không có hội viên nào được chọn. Vui lòng chọn đối tượng.',
              es: 'No hay destinatarios seleccionados. Elige un grupo.',
            ),
          ),
        ),
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

    final subject = LocalizationService.pick(
      ko: '[${widget.studio.studioName}] 안내',
      en: '[${widget.studio.studioName}] Notice',
      ja: '[${widget.studio.studioName}] お知らせ',
      zh: '[${widget.studio.studioName}] 通知',
      vi: '[${widget.studio.studioName}] Thông báo',
      es: '[${widget.studio.studioName}] Aviso',
    );
    // Send Share/Kakao
    if (widget.onShareKakao != null) {
      await widget.onShareKakao!(updatedMsg, subject);
    } else {
      await KakaoShareService.shareMessage(
        text: updatedMsg,
        subject: subject,
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

    return StickyBottomSheetLayout(
      key: const ValueKey('config_phase'),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(Icons.mark_chat_unread_outlined, color: AppTheme.primaryBlue, size: 22),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LocalizationService.pick(
                          ko: '스마트 순차 단체발송',
                          en: 'Smart Sequential Dispatch',
                          ja: 'スマート順次一斉送信',
                          zh: '智能逐一批量发送',
                          vi: 'Gửi lần lượt thông minh',
                          es: 'Envío Secuencial Inteligente',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            LocalizationService.pick(
              ko: '문자비 0원 카톡 또는 문자 앱으로 여러 회원에게 맞춤 메시지를 순차적으로 릴레이 발송합니다.',
              en: 'Send personalized messages one-by-one via your messaging app or SMS with zero platform fees.',
              ja: 'メッセンジャーまたは標準SMSを使い、複数の会員へ個別メッセージを順次リレー送信します。',
              zh: '通过免费社交应用或系统短信，依次向多位会员发送个性化通知。',
              vi: 'Gửi tin nhắn cá nhân hóa lần lượt qua ứng dụng nhắn tin hoặc SMS với 0 phí nền tảng.',
              es: 'Envía mensajes personalizados uno por uno mediante tu app de mensajería o SMS sin coste extra.',
            ),
            style: const TextStyle(fontSize: 12.5, color: AppTheme.textSecondary, height: 1.3),
          ),
          const SizedBox(height: 14),

          // 1. 발송 대상 선택
          Text(
            LocalizationService.pick(
              ko: '1. 발송 대상 선택',
              en: '1. Select Recipients',
              ja: '1. 送信対象の選択',
              zh: '1. 选择发送对象',
              vi: '1. Chọn người nhận',
              es: '1. Elegir Destinatarios',
            ),
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildTargetChip(
                  LocalizationService.pick(
                    ko: '전체 회원 (${widget.allMembers.length}명)',
                    en: 'All Members (${widget.allMembers.length})',
                    ja: '全会員 (${widget.allMembers.length}名)',
                    zh: '全部会员 (${widget.allMembers.length})',
                    vi: 'Tất cả (${widget.allMembers.length})',
                    es: 'Todos (${widget.allMembers.length})',
                  ),
                  _TargetFilterMode.all,
                ),
                const SizedBox(width: 6),
                _buildTargetChip(
                  LocalizationService.pick(
                    ko: '그룹별 선택',
                    en: 'By Group',
                    ja: 'グループ別',
                    zh: '按分组筛选',
                    vi: 'Theo nhóm',
                    es: 'Por grupo',
                  ),
                  _TargetFilterMode.byGroup,
                ),
                const SizedBox(width: 6),
                _buildTargetChip(
                  LocalizationService.pick(
                    ko: '미납 회원만',
                    en: 'Unpaid Only',
                    ja: '未納会員のみ',
                    zh: '仅未缴费会员',
                    vi: 'Chỉ chưa đóng phí',
                    es: 'Solo impagos',
                  ),
                  _TargetFilterMode.unpaidOnly,
                ),
                const SizedBox(width: 6),
                _buildTargetChip(
                  LocalizationService.pick(
                    ko: '만료 임박(2회이하)',
                    en: 'Low Passes (≤2)',
                    ja: '残り僅か (2回以下)',
                    zh: '即将到期 (≤2次)',
                    vi: 'Sắp hết (≤2 buổi)',
                    es: 'Por vencer (≤2)',
                  ),
                  _TargetFilterMode.expiringOnly,
                ),
                const SizedBox(width: 6),
                _buildTargetChip(
                  LocalizationService.pick(
                    ko: '직접 선택 (${_selectedMemberIds.length}명)',
                    en: 'Custom Select (${_selectedMemberIds.length})',
                    ja: '個別選択 (${_selectedMemberIds.length}名)',
                    zh: '手动挑选 (${_selectedMemberIds.length})',
                    vi: 'Tự chọn (${_selectedMemberIds.length})',
                    es: 'Selección manual (${_selectedMemberIds.length})',
                  ),
                  _TargetFilterMode.customSelect,
                ),
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
                  final displayGroup = LocalizationService.localizeBuiltInLabel(g);
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(
                        LocalizationService.pick(
                          ko: '$displayGroup ($count명)',
                          en: '$displayGroup ($count)',
                          ja: '$displayGroup ($count名)',
                          zh: '$displayGroup ($count)',
                          vi: '$displayGroup ($count)',
                          es: '$displayGroup ($count)',
                        ),
                        style: TextStyle(fontSize: 12, color: isSel ? Colors.white : AppTheme.textPrimary),
                      ),
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
                    title: Text('${m.name} (${LocalizationService.localizeBuiltInLabel(m.groupName)})', style: const TextStyle(fontSize: 13)),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  LocalizationService.pick(
                    ko: '2. 메시지 양식(템플릿) 선택',
                    en: '2. Choose Message Template',
                    ja: '2. メッセージテンプレート選択',
                    zh: '2. 选择消息模板',
                    vi: '2. Chọn mẫu tin nhắn',
                    es: '2. Elegir Plantilla de Mensaje',
                  ),
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                ),
              ),
              TextButton.icon(
                onPressed: _saveCurrentBodyAsCustomTemplate,
                icon: const Icon(Icons.bookmark_add_outlined, size: 15, color: AppTheme.primaryBlue),
                label: Text(
                  LocalizationService.pick(
                    ko: '내 서식으로 저장',
                    en: 'Save Template',
                    ja: 'マイ書式に保存',
                    zh: '存为我的模板',
                    vi: 'Lưu làm mẫu',
                    es: 'Guardar plantilla',
                  ),
                  style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...DispatchTemplateType.values.map((t) {
                  final isSel = _selectedCustomTemplateId == null && _selectedTemplateType == t;
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
                            _selectedCustomTemplateId = null;
                            _selectedTemplateType = t;
                            _templateController.text = SequentialDispatchService.getDefaultTemplate(t);
                          });
                        }
                      },
                    ),
                  );
                }),
                ..._customMessageTemplates.map((ct) {
                  final isSel = _selectedCustomTemplateId == ct.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      avatar: Icon(
                        Icons.bookmark_rounded,
                        size: 14,
                        color: isSel ? Colors.white : const Color(0xFF4F46E5),
                      ),
                      label: Text(
                        ct.title,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                          color: isSel ? Colors.white : AppTheme.textPrimary,
                        ),
                      ),
                      selected: isSel,
                      selectedColor: const Color(0xFF4F46E5),
                      backgroundColor: const Color(0xFFF5F3FF),
                      onSelected: (val) {
                        if (val) {
                          setState(() {
                            _selectedCustomTemplateId = ct.id;
                            _selectedTemplateType = DispatchTemplateType.custom;
                            _templateController.text = ct.body;
                          });
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Quick Insert Variable Chips
          Row(
            children: [
              Text(
                LocalizationService.pick(
                  ko: '변수 자동 치환 태그:',
                  en: 'Merge Tags:',
                  ja: '差し込みタグ:',
                  zh: '自动替换变量:',
                  vi: 'Thẻ tự điền:',
                  es: 'Etiquetas:',
                ),
                style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppTheme.textSecondary),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildVariableChip('#{회원명}', displayLabel: LocalizationService.pick(ko: '#{회원명}', en: 'Member', ja: '#{会員名}', zh: '#{会员名}', vi: 'Hội viên', es: 'Miembro')),
                      _buildVariableChip('#{고객호칭}', displayLabel: LocalizationService.pick(ko: '#{고객호칭}', en: 'Title', ja: '#{呼称}', zh: '#{称呼}', vi: 'Danh xưng', es: 'Tratamiento')),
                      _buildVariableChip('#{상호명}', displayLabel: LocalizationService.pick(ko: '#{상호명}', en: 'Studio', ja: '#{屋号}', zh: '#{机构名}', vi: 'Cơ sở', es: 'Centro')),
                      _buildVariableChip('#{담당자}', displayLabel: LocalizationService.pick(ko: '#{담당자}', en: 'Staff', ja: '#{担当者}', zh: '#{负责人}', vi: 'Phụ trách', es: 'Responsable')),
                      _buildVariableChip('#{직함}', displayLabel: LocalizationService.pick(ko: '#{직함}', en: 'Role', ja: '#{役職}', zh: '#{职称}', vi: 'Chức danh', es: 'Cargo')),
                      _buildVariableChip('#{그룹명}', displayLabel: LocalizationService.pick(ko: '#{그룹명}', en: 'Group', ja: '#{クラス}', zh: '#{班级}', vi: 'Nhóm', es: 'Grupo')),
                      _buildVariableChip('#{금액}', displayLabel: LocalizationService.pick(ko: '#{금액}', en: 'Amount', ja: '#{金額}', zh: '#{金额}', vi: 'Số tiền', es: 'Importe')),
                      _buildVariableChip('#{계좌정보}', displayLabel: LocalizationService.pick(ko: '#{계좌정보}', en: 'Bank Info', ja: '#{口座情報}', zh: '#{账户}', vi: 'Tài khoản', es: 'Cuenta')),
                      if (LocalizationService.supportsTossTransfer)
                        _buildVariableChip('#{토스송금링크}'),
                      _buildVariableChip('#{카드결제링크}', displayLabel: LocalizationService.pick(ko: '#{카드결제링크}', en: 'Card Link', ja: '#{カード決済}', zh: '#{刷卡链接}', vi: 'Link thẻ', es: 'Enlace Tarjeta')),
                      _buildVariableChip('#{잔여회차}', displayLabel: LocalizationService.pick(ko: '#{잔여회차}', en: 'Sessions', ja: '#{残回数}', zh: '#{余课}', vi: 'Số buổi', es: 'Sesiones')),
                      _buildVariableChip('#{납부기한}', displayLabel: LocalizationService.pick(ko: '#{납부기한}', en: 'Due Date', ja: '#{支払期限}', zh: '#{截止日}', vi: 'Hạn nộp', es: 'Vencimiento')),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          AppTextField(
            controller: _templateController,
            label: LocalizationService.pick(
              ko: '템플릿 본문 내용',
              en: 'Message Template Body',
              ja: 'テンプレート本文',
              zh: '模板正文内容',
              vi: 'Nội dung mẫu tin nhắn',
              es: 'Cuerpo de la plantilla',
            ),
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
                        LocalizationService.pick(
                          ko: '1번째 대상자 (${targets.first.name}) 치환 미리보기',
                          en: 'Preview for 1st recipient (${targets.first.name})',
                          ja: '1人目 (${targets.first.name}) プレビュー',
                          zh: '第1位收件人 (${targets.first.name}) 预览',
                          vi: 'Xem trước người thứ 1 (${targets.first.name})',
                          es: 'Vista previa 1er destinatario (${targets.first.name})',
                        ),
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
                    softWrap: true,
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF475569), height: 1.35),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: targets.isEmpty ? null : _startDispatch,
          icon: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
          label: Text(
            LocalizationService.pick(
              ko: '총 ${targets.length}명 순차 릴레이 발송 시작 🚀',
              en: 'Start Sequential Dispatch (${targets.length}) 🚀',
              ja: '合計${targets.length}名へ順次送信を開始 🚀',
              zh: '开始向 ${targets.length} 人逐一发送 🚀',
              vi: 'Bắt đầu gửi lần lượt (${targets.length} người) 🚀',
              es: 'Iniciar envío secuencial (${targets.length}) 🚀',
            ),
            style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
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

  Widget _buildVariableChip(String tag, {String? displayLabel}) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: ActionChip(
        label: Text(displayLabel ?? tag, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppTheme.primaryBlue)),
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

    return StickyBottomSheetLayout(
      key: const ValueKey('dispatch_phase'),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header with Progress
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryBlue.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        LocalizationService.pick(
                          ko: '${_currentIndex + 1} / $total명',
                          en: '${_currentIndex + 1} / $total',
                          ja: '${_currentIndex + 1} / $total名',
                          zh: '${_currentIndex + 1} / $total',
                          vi: '${_currentIndex + 1} / $total',
                          es: '${_currentIndex + 1} / $total',
                        ),
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.primaryBlue),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        LocalizationService.pick(
                          ko: '순차 릴레이 발송 중',
                          en: 'Sequential Dispatch',
                          ja: '順次リレー送信中',
                          zh: '正在逐一发送',
                          vi: 'Đang gửi lần lượt',
                          es: 'Envío secuencial activo',
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                tooltip: LocalizationService.pick(
                  ko: '발송 중단',
                  en: 'Stop Dispatch',
                  ja: '送信を中止',
                  zh: '停止发送',
                  vi: 'Dừng gửi',
                  es: 'Detener envío',
                ),
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
                LocalizationService.pick(
                  ko: '발송 성공 $sentCount명 (건너뜀 $skippedCount명)',
                  en: 'Sent $sentCount (Skipped $skippedCount)',
                  ja: '送信完了 $sentCount名 (スキップ $skippedCount名)',
                  zh: '已发送 $sentCount (跳过 $skippedCount)',
                  vi: 'Đã gửi $sentCount (Bỏ qua $skippedCount)',
                  es: 'Enviados $sentCount (Omitidos $skippedCount)',
                ),
                style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
              ),
              Text(
                LocalizationService.pick(
                  ko: '${(progress * 100).toInt()}% 완료',
                  en: '${(progress * 100).toInt()}% Done',
                  ja: '${(progress * 100).toInt()}% 完了',
                  zh: '完成 ${(progress * 100).toInt()}%',
                  vi: 'Xong ${(progress * 100).toInt()}%',
                  es: '${(progress * 100).toInt()}% completado',
                ),
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
                    member.name.isNotEmpty ? member.name.substring(0, 1) : '?',
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
                              LocalizationService.localizeBuiltInLabel(member.groupName),
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Color(0xFF475569)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        LocalizationService.pick(
                          ko: '수신 번호: ${currentItem.recipientPhone}',
                          en: 'Phone: ${currentItem.recipientPhone}',
                          ja: '宛先番号: ${currentItem.recipientPhone}',
                          zh: '收件号码: ${currentItem.recipientPhone}',
                          vi: 'SĐT nhận: ${currentItem.recipientPhone}',
                          es: 'Teléfono: ${currentItem.recipientPhone}',
                        ),
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
                      currentItem.sentChannel == 'KAKAO'
                          ? LocalizationService.pick(
                              ko: '카톡 완료',
                              en: 'Shared',
                              ja: '共有完了',
                              zh: '已分享',
                              vi: 'Đã chia sẻ',
                              es: 'Compartido',
                            )
                          : LocalizationService.pick(
                              ko: '문자 완료',
                              en: 'SMS Sent',
                              ja: 'SMS完了',
                              zh: '短信已发',
                              vi: 'Đã gửi SMS',
                              es: 'SMS enviado',
                            ),
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
            label: LocalizationService.pick(
              ko: '${member.name.split(' ').first} 회원 맞춤 메시지 (발송 전 수정 가능)',
              en: 'Message for ${member.name.split(' ').first} (Editable before sending)',
              ja: '${member.name.split(' ').first}様向けメッセージ（送信前に編集可能）',
              zh: '${member.name.split(' ').first} 专属消息（发送前可修改）',
              vi: 'Tin nhắn cho ${member.name.split(' ').first} (Có thể sửa trước khi gửi)',
              es: 'Mensaje para ${member.name.split(' ').first} (Editable)',
            ),
            maxLines: 7,
          ),
          const SizedBox(height: 8),
        ],
      ),
      footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Primary One-Tap Actions (1 Column Full-Width in Senior Mode)
          Builder(
            builder: (context) {
              final isSenior = Theme.of(context).primaryColor == AppTheme.seniorPrimaryBlue;
              final kakaoBtn = ElevatedButton.icon(
                onPressed: _sendCurrentViaKakao,
                icon: const Icon(Icons.chat_bubble_rounded, color: Color(0xFF191919), size: 16),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    LocalizationService.pick(
                      ko: '카톡 0원 전송 후 다음',
                      en: 'Share & Next',
                      ja: '共有して次へ',
                      zh: '分享并下一位',
                      vi: 'Chia sẻ & Tiếp',
                      es: 'Compartir y Siguiente',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: isSenior ? 15 : 13.5,
                      color: const Color(0xFF191919),
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFEE500),
                  foregroundColor: const Color(0xFF191919),
                  minimumSize: isSenior ? const Size(double.infinity, 50) : Size.zero,
                  padding: EdgeInsets.symmetric(vertical: isSenior ? 14 : 14, horizontal: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );

              final smsBtn = ElevatedButton.icon(
                onPressed: _sendCurrentViaSms,
                icon: const Icon(Icons.sms_outlined, color: Colors.white, size: 16),
                label: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    LocalizationService.pick(
                      ko: '문자 전송 후 다음',
                      en: 'Send SMS & Next',
                      ja: 'SMS送信して次へ',
                      zh: '发短信并下一位',
                      vi: 'Gửi SMS & Tiếp',
                      es: 'Enviar SMS y Siguiente',
                    ),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: isSenior ? 15 : 13.5,
                      color: Colors.white,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryBlue,
                  foregroundColor: Colors.white,
                  minimumSize: isSenior ? const Size(double.infinity, 50) : Size.zero,
                  padding: EdgeInsets.symmetric(vertical: isSenior ? 14 : 14, horizontal: 8),
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );

              if (isSenior) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    kakaoBtn,
                    const SizedBox(height: 10),
                    smsBtn,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: kakaoBtn),
                  const SizedBox(width: 8),
                  Expanded(child: smsBtn),
                ],
              );
            },
          ),
          const SizedBox(height: 8),

          // Sub Actions: 건너뛰기, 이전 회원
          ResponsiveDialogActions(
            breakpoint: 320,
            secondary: OutlinedButton.icon(
              onPressed: _currentIndex > 0 ? _moveToPrevious : null,
              icon: const Icon(Icons.arrow_back_ios_new, size: 13),
              label: Text(
                LocalizationService.pick(
                  ko: '이전 회원',
                  en: 'Previous',
                  ja: '前の会員',
                  zh: '上一位',
                  vi: 'Trước',
                  es: 'Anterior',
                ),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            primary: OutlinedButton.icon(
              onPressed: _skipCurrent,
              icon: const Icon(Icons.skip_next_rounded, size: 16),
              label: Text(
                LocalizationService.pick(
                  ko: '이 회원 건너뛰기',
                  en: 'Skip Member',
                  ja: 'スキップ',
                  zh: '跳过此人',
                  vi: 'Bỏ qua',
                  es: 'Omitir',
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                padding: const EdgeInsets.symmetric(vertical: 11),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
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

    return StickyBottomSheetLayout(
      key: const ValueKey('completed_phase'),
      bodyPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      body: Column(
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
          Text(
            LocalizationService.pick(
              ko: '순차 릴레이 발송 완료!',
              en: 'Sequential Dispatch Complete!',
              ja: '順次リレー送信が完了しました！',
              zh: '逐一发送已完成！',
              vi: 'Đã hoàn tất gửi lần lượt!',
              es: '¡Envío secuencial completado!',
            ),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.textPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            LocalizationService.pick(
              ko: '선택된 대상 회원들에게 카카오톡 및 문자로 안내가 성공적으로 전달되었습니다.',
              en: 'Your personalized notices have been delivered to the selected members via messenger or SMS.',
              ja: '選択された会員へメッセージアプリまたはSMSでの送信が完了しました。',
              zh: '已通过社交应用或短信向选定会员顺利完成通知发送。',
              vi: 'Thông báo đã được gửi thành công qua ứng dụng nhắn tin hoặc SMS đến các hội viên đã chọn.',
              es: 'Los avisos se han entregado correctamente por mensajería o SMS.',
            ),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
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
                _buildStatRow(
                  LocalizationService.pick(ko: '총 대상 회원', en: 'Total Recipients', ja: '対象会員合計', zh: '目标会员总数', vi: 'Tổng người nhận', es: 'Total destinatarios'),
                  LocalizationService.pick(ko: '$total명', en: '$total', ja: '$total名', zh: '$total 人', vi: '$total người', es: '$total'),
                  AppTheme.textPrimary,
                ),
                const Divider(height: 16),
                _buildStatRow(
                  LocalizationService.pick(ko: '카카오톡 (0원) 발송', en: 'Messenger Share', ja: 'アプリ共有送信', zh: '社交应用分享', vi: 'Chia sẻ ứng dụng', es: 'Compartido por App'),
                  LocalizationService.pick(ko: '$kakaoCount건', en: '$kakaoCount', ja: '$kakaoCount件', zh: '$kakaoCount 条', vi: '$kakaoCount tin', es: '$kakaoCount'),
                  const Color(0xFFEAB308),
                ),
                const SizedBox(height: 6),
                _buildStatRow(
                  LocalizationService.pick(ko: '기본 문자(SMS) 발송', en: 'SMS Sent', ja: '標準SMS送信', zh: '手机短信发送', vi: 'Gửi SMS', es: 'SMS enviados'),
                  LocalizationService.pick(ko: '$smsCount건', en: '$smsCount', ja: '$smsCount件', zh: '$smsCount 条', vi: '$smsCount tin', es: '$smsCount'),
                  AppTheme.primaryBlue,
                ),
                const SizedBox(height: 6),
                _buildStatRow(
                  LocalizationService.pick(ko: '건너뜀 / 미발송', en: 'Skipped', ja: 'スキップ / 未送信', zh: '已跳过 / 未发', vi: 'Đã bỏ qua', es: 'Omitidos'),
                  LocalizationService.pick(ko: '$skippedCount건', en: '$skippedCount', ja: '$skippedCount件', zh: '$skippedCount 条', vi: '$skippedCount tin', es: '$skippedCount'),
                  AppTheme.textTertiary,
                ),
              ],
            ),
          ),
        ],
      ),
      footerPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      footer: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: () => Navigator.pop(context),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryBlue,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Text(
            LocalizationService.pick(
              ko: '확인 및 닫기',
              en: 'Done & Close',
              ja: '確認して閉じる',
              zh: '确认并关闭',
              vi: 'Xác nhận & Đóng',
              es: 'Aceptar y Cerrar',
            ),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
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
