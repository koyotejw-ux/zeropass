import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_category_template.dart';

class CustomCategoryService {
  CustomCategoryService._();
  static final CustomCategoryService instance = CustomCategoryService._();

  static const String _keyGroupCategories = 'zeropass_custom_group_categories';
  static const String _keyMemberTemplates = 'zeropass_custom_member_templates';
  static const String _keyInvoiceTemplates = 'zeropass_custom_invoice_templates';
  static const String _keyMessageTemplates = 'zeropass_custom_message_templates';

  /// Loads custom category state. If never saved before, generates defaults based on [industryCategory].
  Future<CustomCategoryState> loadCategories({String? industryCategory}) async {
    final prefs = await SharedPreferences.getInstance();

    final rawGroups = prefs.getString(_keyGroupCategories);
    final rawMemberTemplates = prefs.getString(_keyMemberTemplates);
    final rawInvoiceTemplates = prefs.getString(_keyInvoiceTemplates);
    final rawMessageTemplates = prefs.getString(_keyMessageTemplates);

    if (rawGroups == null && rawMemberTemplates == null && rawInvoiceTemplates == null && rawMessageTemplates == null) {
      // First time initialization: load default preset for the studio's industry
      final effectiveIndustry = industryCategory ?? '입시 / 보습학원';
      final defaults = CustomCategoryState.getDefaultsForIndustry(effectiveIndustry).copyWith(
        messageTemplates: CustomCategoryState.getDefaultMessageTemplatesForIndustry(effectiveIndustry),
      );
      await saveCategories(defaults);
      return defaults;
    }

    List<String> groupCategories = [];
    if (rawGroups != null) {
      try {
        final decoded = jsonDecode(rawGroups) as List<dynamic>;
        groupCategories = decoded.map((e) => e.toString()).toList();
      } catch (_) {
        groupCategories = [];
      }
    }

    List<MemberCategoryTemplate> memberTemplates = [];
    if (rawMemberTemplates != null) {
      try {
        final decoded = jsonDecode(rawMemberTemplates) as List<dynamic>;
        memberTemplates = decoded
            .map((e) => MemberCategoryTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        memberTemplates = [];
      }
    }

    List<InvoiceItemTemplate> invoiceTemplates = [];
    if (rawInvoiceTemplates != null) {
      try {
        final decoded = jsonDecode(rawInvoiceTemplates) as List<dynamic>;
        invoiceTemplates = decoded
            .map((e) => InvoiceItemTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        invoiceTemplates = [];
      }
    }

    List<CustomMessageTemplate> messageTemplates = [];
    if (rawMessageTemplates != null) {
      try {
        final decoded = jsonDecode(rawMessageTemplates) as List<dynamic>;
        messageTemplates = decoded
            .map((e) => CustomMessageTemplate.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        messageTemplates = [];
      }
    }

    // Fallback if any section is empty / newly added field not yet seeded
    if (groupCategories.isEmpty || memberTemplates.isEmpty || invoiceTemplates.isEmpty || rawMessageTemplates == null) {
      final effectiveIndustry = industryCategory ?? '기타 / 맞춤업종';
      final fallback = CustomCategoryState.getDefaultsForIndustry(effectiveIndustry);
      if (groupCategories.isEmpty) groupCategories = fallback.groupCategories;
      if (memberTemplates.isEmpty) memberTemplates = fallback.memberTemplates;
      if (invoiceTemplates.isEmpty) invoiceTemplates = fallback.invoiceTemplates;
      if (rawMessageTemplates == null) {
        messageTemplates = CustomCategoryState.getDefaultMessageTemplatesForIndustry(effectiveIndustry);
      }
    }

    return CustomCategoryState(
      groupCategories: groupCategories,
      memberTemplates: memberTemplates,
      invoiceTemplates: invoiceTemplates,
      messageTemplates: messageTemplates,
    );
  }

  /// Persists the complete custom category state
  Future<void> saveCategories(CustomCategoryState state) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(_keyGroupCategories, jsonEncode(state.groupCategories));
    await prefs.setString(
      _keyMemberTemplates,
      jsonEncode(state.memberTemplates.map((e) => e.toMap()).toList()),
    );
    await prefs.setString(
      _keyInvoiceTemplates,
      jsonEncode(state.invoiceTemplates.map((e) => e.toMap()).toList()),
    );
    await prefs.setString(
      _keyMessageTemplates,
      jsonEncode(state.messageTemplates.map((e) => e.toMap()).toList()),
    );
  }

  /// Resets categories and templates to the specified industry preset
  Future<CustomCategoryState> resetToIndustry(String industryCategory) async {
    final defaults = CustomCategoryState.getDefaultsForIndustry(industryCategory).copyWith(
      messageTemplates: CustomCategoryState.getDefaultMessageTemplatesForIndustry(industryCategory),
    );
    await saveCategories(defaults);
    return defaults;
  }

  /// Adds a new group category if not already present
  Future<CustomCategoryState> addGroupCategory(String group, {String? industryCategory}) async {
    final current = await loadCategories(industryCategory: industryCategory);
    final trimmed = group.trim();
    if (trimmed.isEmpty || current.groupCategories.contains(trimmed)) {
      return current;
    }

    final updated = current.copyWith(
      groupCategories: [...current.groupCategories, trimmed],
    );
    await saveCategories(updated);
    return updated;
  }

  /// Renames an existing group category and updates matching member templates
  Future<CustomCategoryState> renameGroupCategory(
    String oldName,
    String newName, {
    String? industryCategory,
  }) async {
    final current = await loadCategories(industryCategory: industryCategory);
    final trimmedNew = newName.trim();
    if (trimmedNew.isEmpty || oldName == trimmedNew) {
      return current;
    }

    final nextGroups = <String>[];
    for (final g in current.groupCategories) {
      final candidate = g == oldName ? trimmedNew : g;
      if (!nextGroups.contains(candidate)) {
        nextGroups.add(candidate);
      }
    }
    final nextMemberTemplates = current.memberTemplates
        .map((t) => t.groupName == oldName ? t.copyWith(groupName: trimmedNew) : t)
        .toList();

    final updated = current.copyWith(
      groupCategories: nextGroups,
      memberTemplates: nextMemberTemplates,
    );
    await saveCategories(updated);
    return updated;
  }

  /// Removes a group category
  Future<CustomCategoryState> removeGroupCategory(String group, {String? industryCategory}) async {
    final current = await loadCategories(industryCategory: industryCategory);
    final updated = current.copyWith(
      groupCategories: current.groupCategories.where((g) => g != group).toList(),
    );
    await saveCategories(updated);
    return updated;
  }

  /// Adds or updates a member template
  Future<CustomCategoryState> saveMemberTemplate(
    MemberCategoryTemplate template, {
    String? industryCategory,
  }) async {
    final current = await loadCategories(industryCategory: industryCategory);
    final list = List<MemberCategoryTemplate>.from(current.memberTemplates);
    final idx = list.indexWhere((t) => t.id == template.id);

    if (idx != -1) {
      list[idx] = template;
    } else {
      list.add(template);
    }

    // Also ensure the groupName is in groupCategories
    List<String> groups = List<String>.from(current.groupCategories);
    if (!groups.contains(template.groupName) && template.groupName.trim().isNotEmpty) {
      groups.add(template.groupName.trim());
    }

    final updated = current.copyWith(
      memberTemplates: list,
      groupCategories: groups,
    );
    await saveCategories(updated);
    return updated;
  }

  /// Removes a member template by ID
  Future<CustomCategoryState> removeMemberTemplate(String id, {String? industryCategory}) async {
    final current = await loadCategories(industryCategory: industryCategory);
    final updated = current.copyWith(
      memberTemplates: current.memberTemplates.where((t) => t.id != id).toList(),
    );
    await saveCategories(updated);
    return updated;
  }

  /// Adds or updates an invoice template
  Future<CustomCategoryState> saveInvoiceTemplate(
    InvoiceItemTemplate template, {
    String? industryCategory,
  }) async {
    final current = await loadCategories(industryCategory: industryCategory);
    final list = List<InvoiceItemTemplate>.from(current.invoiceTemplates);
    final idx = list.indexWhere((t) => t.id == template.id);

    if (idx != -1) {
      list[idx] = template;
    } else {
      list.add(template);
    }

    final updated = current.copyWith(invoiceTemplates: list);
    await saveCategories(updated);
    return updated;
  }

  /// Removes an invoice template by ID
  Future<CustomCategoryState> removeInvoiceTemplate(String id, {String? industryCategory}) async {
    final current = await loadCategories(industryCategory: industryCategory);
    final updated = current.copyWith(
      invoiceTemplates: current.invoiceTemplates.where((t) => t.id != id).toList(),
    );
    await saveCategories(updated);
    return updated;
  }

  /// Adds or updates a custom message template
  Future<CustomCategoryState> saveMessageTemplate(
    CustomMessageTemplate template, {
    String? industryCategory,
  }) async {
    final current = await loadCategories(industryCategory: industryCategory);
    final list = List<CustomMessageTemplate>.from(current.messageTemplates);
    final idx = list.indexWhere((t) => t.id == template.id);

    if (idx != -1) {
      list[idx] = template;
    } else {
      list.add(template);
    }

    final updated = current.copyWith(messageTemplates: list);
    await saveCategories(updated);
    return updated;
  }

  /// Removes a custom message template by ID
  Future<CustomCategoryState> removeMessageTemplate(String id, {String? industryCategory}) async {
    final current = await loadCategories(industryCategory: industryCategory);
    final updated = current.copyWith(
      messageTemplates: current.messageTemplates.where((t) => t.id != id).toList(),
    );
    await saveCategories(updated);
    return updated;
  }
}
