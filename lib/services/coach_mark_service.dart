import 'package:shared_preferences/shared_preferences.dart';

class CoachMarkService {
  static const String keyCheckIn = 'coach_mark_check_in_shown';
  static const String keyBillingTab = 'coach_mark_billing_tab_shown';
  static const String keyMemberTab = 'coach_mark_member_tab_shown';
  static const String keySettingsTab = 'coach_mark_settings_tab_shown';
  static const String keySendInvoice = 'coach_mark_send_invoice_shown';

  static Future<bool> shouldShow(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return !(prefs.getBool(key) ?? false);
  }

  static Future<void> markShown(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, true);
  }

  static Future<void> resetAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keyCheckIn);
    await prefs.remove(keyBillingTab);
    await prefs.remove(keyMemberTab);
    await prefs.remove(keySettingsTab);
    await prefs.remove(keySendInvoice);
  }
}
