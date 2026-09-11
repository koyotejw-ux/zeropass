import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_navigation_screen.dart';
import 'screens/studio_setup_wizard_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);

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
      title: 'ZeroPass (제로패스)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _showSetupWizard
          ? StudioSetupWizardScreen(onFinish: _finishSetupWizard)
          : const HomeNavigationScreen(),
    );
  }
}
