import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_navigation_screen.dart';
import 'screens/studio_setup_wizard_screen.dart';
import 'services/monetization_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);

  await MonetizationService.instance.initialize();

  final prefs = await SharedPreferences.getInstance();
  final showSetupWizard = !(prefs.getBool('setup_wizard_completed') ?? false);

  runApp(
    ProviderScope(
      child: ZeroPassApp(showSetupWizard: showSetupWizard),
    ),
  );
}

class ZeroPassApp extends StatefulWidget {
  final bool showSetupWizard;
  const ZeroPassApp({super.key, required this.showSetupWizard});

  @override
  State<ZeroPassApp> createState() => _ZeroPassAppState();
}

class _ZeroPassAppState extends State<ZeroPassApp> {
  late bool _showSetupWizard;

  @override
  void initState() {
    super.initState();
    _showSetupWizard = widget.showSetupWizard;
  }

  void _finishSetupWizard() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('setup_wizard_completed', true);
    setState(() {
      _showSetupWizard = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '체크앤페이 - 무료 출결관리 & 학원·교습소·PT 회원 수납 출석체크 키오스크',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _showSetupWizard
          ? StudioSetupWizardScreen(onFinish: _finishSetupWizard)
          : const HomeNavigationScreen(),
    );
  }
}
