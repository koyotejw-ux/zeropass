import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pass_dashboard_screen.dart';
import 'billing_ledger_screen.dart';
import 'member_directory_screen.dart';
import 'pro_store_screen.dart';
import 'settings_vault_screen.dart';
import '../widgets/ad_banner_widget.dart';

class HomeNavigationScreen extends StatefulWidget {
  const HomeNavigationScreen({super.key});

  static HomeNavigationScreenState? of(BuildContext context) {
    return context.findAncestorStateOfType<HomeNavigationScreenState>();
  }

  @override
  State<HomeNavigationScreen> createState() => HomeNavigationScreenState();
}

class HomeNavigationScreenState extends State<HomeNavigationScreen> {
  int _currentIndex = 0;

  void switchToTab(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  final List<Widget> _screens = const [
    PassDashboardScreen(),
    BillingLedgerScreen(),
    MemberDirectoryScreen(),
    ProStoreScreen(),
    SettingsVaultScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!isLandscape) const AdBannerWidget(),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha((255 * 0.05).round()),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: NavigationBar(
              height: isLandscape ? 54 : 68,
              selectedIndex: _currentIndex,
              labelBehavior: isLandscape 
                  ? NavigationDestinationLabelBehavior.onlyShowSelected 
                  : NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (index) {
                setState(() {
                  _currentIndex = index;
                });
              },
              backgroundColor: Colors.white,
              indicatorColor: _currentIndex == 3
                  ? const Color(0xFFF59E0B).withAlpha((255 * 0.18).round())
                  : AppTheme.primaryBlue.withAlpha((255 * 0.12).round()),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.check_circle_outline),
                  selectedIcon: Icon(Icons.check_circle, color: AppTheme.primaryBlue),
                  label: '패스 체크',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long, color: AppTheme.primaryBlue),
                  label: '청구·수납',
                ),
                NavigationDestination(
                  icon: Icon(Icons.people_outline),
                  selectedIcon: Icon(Icons.people, color: AppTheme.primaryBlue),
                  label: '회원 관리',
                ),
                NavigationDestination(
                  icon: Badge(
                    label: Text('PRO', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                    backgroundColor: Color(0xFFF59E0B),
                    child: Icon(Icons.workspace_premium_outlined),
                  ),
                  selectedIcon: Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706)),
                  label: 'PRO 샵',
                ),
                NavigationDestination(
                  icon: Icon(Icons.shield_outlined),
                  selectedIcon: Icon(Icons.shield, color: AppTheme.primaryBlue),
                  label: '설정·보안',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
