import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'pass_dashboard_screen.dart';
import 'billing_ledger_screen.dart';
import 'member_directory_screen.dart';
import 'settings_vault_screen.dart';

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
    SettingsVaultScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
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
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          backgroundColor: Colors.white,
          indicatorColor: AppTheme.primaryBlue.withAlpha((255 * 0.12).round()),
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
              icon: Icon(Icons.shield_outlined),
              selectedIcon: Icon(Icons.shield, color: AppTheme.primaryBlue),
              label: '설정·보안',
            ),
          ],
        ),
      ),
    );
  }
}
