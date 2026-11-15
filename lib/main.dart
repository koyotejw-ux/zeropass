import 'package:flutter_localizations/flutter_localizations.dart';
import 'services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_navigation_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/studio_setup_wizard_screen.dart';
import 'screens/tablet_kiosk_screen.dart';
import 'services/monetization_service.dart';
import 'providers/app_providers.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    initializeDateFormatting('ko_KR', null),
    initializeDateFormatting('en_US', null),
    initializeDateFormatting('ja_JP', null),
    initializeDateFormatting('zh_CN', null),
    initializeDateFormatting('vi_VN', null),
    initializeDateFormatting('es_ES', null),
  ]);

  await MonetizationService.instance.initialize();
  await LocalizationService.initialize();

  final prefs = await SharedPreferences.getInstance();
  final showOnboarding = !(prefs.getBool('onboarding_completed') ?? false);
  final showSetupWizard = !(prefs.getBool('setup_wizard_completed') ?? false);
  final isKioskDedicated = prefs.getBool('is_kiosk_dedicated_mode') ?? false;

  // 스토어 규격 실물 캡처 또는 환경 설정에 따른 광고 제거 모드 활성화
  final storeCaptureAdFree = prefs.getBool('store_screenshot_ad_free') ?? true;
  if (storeCaptureAdFree) {
    MonetizationService.storeScreenshotMode = true;
  }

  runApp(
    ProviderScope(
      child: ZeroPassApp(
        showOnboarding: showOnboarding,
        showSetupWizard: showSetupWizard,
        isKioskDedicated: isKioskDedicated,
      ),
    ),
  );
}

class ZeroPassApp extends ConsumerStatefulWidget {
  final bool showOnboarding;
  final bool showSetupWizard;
  final bool isKioskDedicated;
  const ZeroPassApp({
    super.key,
    required this.showOnboarding,
    required this.showSetupWizard,
    this.isKioskDedicated = false,
  });

  @override
  ConsumerState<ZeroPassApp> createState() => _ZeroPassAppState();
}

class _ZeroPassAppState extends ConsumerState<ZeroPassApp> {
  late bool _showOnboarding;
  late bool _showSetupWizard;

  @override
  void initState() {
    super.initState();
    _showOnboarding = widget.showOnboarding;
    _showSetupWizard = widget.showSetupWizard;
  }

  void _finishOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_completed', true);
    setState(() {
      _showOnboarding = false;
    });
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
    final isSeniorMode = ref.watch(seniorModeProvider);
    final activeLang = ref.watch(languageProvider);
    ref.watch(currencyProvider);

    Widget homeScreen;
    if (_showOnboarding) {
      homeScreen = OnboardingScreen(onFinish: _finishOnboarding);
    } else if (_showSetupWizard) {
      homeScreen = StudioSetupWizardScreen(onFinish: _finishSetupWizard);
    } else if (widget.isKioskDedicated) {
      homeScreen = const TabletKioskScreen();
    } else {
      homeScreen = const HomeNavigationScreen();
    }

    return MaterialApp(
      navigatorKey: MonetizationService.rootNavigatorKey,
      title: LocalizationService.tr('app_name'),
      debugShowCheckedModeBanner: false,
      locale: Locale(activeLang.code),
      supportedLocales: AppLanguage.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: isSeniorMode ? AppTheme.seniorTheme : AppTheme.lightTheme,
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: isSeniorMode ? 1.25 : 0.85,
        maxScaleFactor: isSeniorMode ? 1.55 : 1.15,
        child: child ?? const SizedBox.shrink(),
      ),
      home: homeScreen,
    );
  }
}

