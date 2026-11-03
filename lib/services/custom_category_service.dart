import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/custom_category_template.dart';

class CustomCategoryService {
  CustomCategoryService._();
  static final CustomCategoryService instance = CustomCategoryService._();

  static const String _keyGroupCategories = 'zeropass_custom_group_categories';
  static const String _keyMemberTemplates = 'zeropass_custom_member_templates';
  static const String _keyInvoiceTemplates = 'zeropass_custom_invoice_templates';

  /// Loads custom category state. If never saved before, generates defaults based on [industryCategory].
  Future<CustomCategoryState> loadCategories({String? industryCategory}) async {
    final prefs = await SharedPreferences.getInstance();

    final rawGroups = prefs.getString(_keyGroupCategories);
    final rawMemberTemplates = prefs.getString(_keyMemberTemplates);
    final rawInvoiceTemplates = prefs.getString(_keyInvoiceTemplates);

    if (rawGroups == null && rawMemberTemplates == null && rawInvoiceTemplates == null) {
      // First time initialization: load default preset for the studio's industry
      final defaults = CustomCategoryState.getDefaultsForIndustry(
        industryCategory ?? '입시 / 보습학원',
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

    // Fallback if any section is empty
    if (groupCategories.isEmpty || memberTemplates.isEmpty || invoiceTemplates.isEmpty) {
      final fallback = CustomCategoryState.getDefaultsForIndustry(
        industryCategory ?? '기타 / 맞춤업종',
      );
      if (groupCategories.isEmpty) groupCategories = fallback.groupCategories;
      if (memberTemplates.isEmpty) memberTemplates = fallback.memberTemplates;
      if (invoiceTemplates.isEmpty) invoiceTemplates = fallback.invoiceTemplates;
    }

    return CustomCategoryState(
      groupCategories: groupCategories,
      memberTemplates: memberTemplates,
      invoiceTemplates: invoiceTemplates,
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
  }

  /// Resets categories and templates to the specified industry preset
  Future<CustomCategoryState> resetToIndustry(String industryCategory) async {
    final defaults = CustomCategoryState.getDefaultsForIndustry(industryCategory);
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
}
