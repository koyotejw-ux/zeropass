import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'screens/home_navigation_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko_KR', null);

  runApp(
    const ProviderScope(
      child: ZeroPassApp(),
    ),
  );
}

class ZeroPassApp extends StatelessWidget {
  const ZeroPassApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ZeroPass (제로패스)',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const HomeNavigationScreen(),
    );
  }
}
