import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/app_providers.dart';
import '../services/localization_service.dart';
import '../theme/app_theme.dart';
import 'pass_dashboard_screen.dart';
import 'billing_ledger_screen.dart';
import 'member_directory_screen.dart';
import 'settings_vault_screen.dart';
import '../widgets/ad_banner_widget.dart';

class HomeNavigationScreen extends ConsumerStatefulWidget {
  const HomeNavigationScreen({super.key});

  static HomeNavigationScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<HomeNavigationScreenState>();
  }

  @override
  ConsumerState<HomeNavigationScreen> createState() => HomeNavigationScreenState();
}

class HomeNavigationScreenState extends ConsumerState<HomeNavigationScreen> {
  int _currentIndex = 0;

  void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _screens = const [
    PassDashboardScreen(),
    BillingLedgerScreen(
      key: ValueKey('nav_billing_only'),
      mode: LedgerScreenMode.billingOnly,
      initialTab: 0,
      enableAutoCoachMark: false,
    ),
    BillingLedgerScreen(
      key: ValueKey('nav_expense_tax_only'),
      mode: LedgerScreenMode.expenseTaxOnly,
      initialTab: 2,
      enableAutoCoachMark: false,
    ),
    MemberDirectoryScreen(
      enableAutoCoachMark: false,
    ),
    SettingsVaultScreen(
      enableAutoCoachMark: false,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    ref.watch(languageProvider);
    ref.watch(currencyProvider);
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;
    final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0 ||
        View.of(context).viewInsets.bottom > 0;

    final isCompact = MediaQuery.of(context).size.width < 360;
    final isSeniorMode = ref.watch(seniorModeProvider);

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: isKeyboardOpen
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!isLandscape) const AdBannerWidget(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: const Border(
                      top: BorderSide(color: AppTheme.borderSubtle, width: 0.9),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.04).round()),
                        blurRadius: 12,
                        offset: const Offset(0, -3),
                      ),
                    ],
                  ),
                  child: NavigationBarTheme(
                    data: NavigationBarThemeData(
                      labelTextStyle: WidgetStateProperty.resolveWith((states) {
                        final isSelected = states.contains(WidgetState.selected);
                        return TextStyle(
                          fontFamily: 'Pretendard',
                          fontSize: isSeniorMode ? 12.5 : (isCompact ? 10.5 : 11.5),
                          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                          color: isSelected
                              ? (isSeniorMode ? AppTheme.seniorPrimaryBlue : AppTheme.primaryDark)
                              : AppTheme.textSecondary,
                          letterSpacing: -0.4,
                        );
                      }),
                    ),
                    child: NavigationBar(
                      height: isLandscape ? 54 : (isSeniorMode ? 76 : 66),
                      selectedIndex: _currentIndex,
                      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
                      onDestinationSelected: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      backgroundColor: Colors.white,
                      indicatorColor: isSeniorMode
                          ? AppTheme.seniorPrimaryBlue.withAlpha((255 * 0.18).round())
                          : const Color(0xFFF1F5F9),
                      destinations: [
                        NavigationDestination(
                          icon: const Icon(Icons.fact_check_outlined, size: 22),
                          selectedIcon: const Icon(Icons.fact_check_rounded, color: AppTheme.primaryDark, size: 22),
                          label: LocalizationService.tr('tab_pass'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.receipt_long_outlined, size: 22),
                          selectedIcon: const Icon(Icons.receipt_long_rounded, color: AppTheme.primaryDark, size: 22),
                          label: LocalizationService.tr('tab_billing'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.account_balance_wallet_outlined, size: 22),
                          selectedIcon: const Icon(Icons.account_balance_wallet_rounded, color: AppTheme.primaryDark, size: 22),
                          label: LocalizationService.tr('tab_tax_expense'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.groups_outlined, size: 22),
                          selectedIcon: const Icon(Icons.groups_rounded, color: AppTheme.primaryDark, size: 22),
                          label: LocalizationService.tr('tab_members'),
                        ),
                        NavigationDestination(
                          icon: const Icon(Icons.tune_outlined, size: 22),
                          selectedIcon: const Icon(Icons.tune_rounded, color: AppTheme.primaryDark, size: 22),
                          label: LocalizationService.tr('tab_settings'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
