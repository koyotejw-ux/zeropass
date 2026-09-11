import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);

  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('onboarding_completed') ?? false);

  runApp(
    ProviderScope(
      child: ZeroPassApp(showOnboarding: showOnboarding),
    ),
  );
}

class ZeroPassApp extends StatefulWidget {
  final bool showOnboarding;
  const ZeroPassApp({super.key, required this.showOnboarding});

  @override
  State<ZeroPassApp> createState() => _ZeroPassAppState();
}

class _ZeroPassAppState extends State<ZeroPassApp> {
  late bool _showOnboarding;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    setState(() {
      _showOnboarding = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZeroPass (제로패스)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: _showOnboarding
          ? OnboardingScreen(onFinish: _finishOnboarding)
          : const HomeNavigationScreen(),
    );
  }
}
