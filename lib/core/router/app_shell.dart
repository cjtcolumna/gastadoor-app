import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../widgets/floating_nav_bar.dart';

const appTabs = [
  NavTab(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home),
  NavTab(
    label: 'Accounts',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
  ),
  NavTab(
    label: 'History',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
  ),
];

/// The frame around the three tabs: the current tab's screen,
/// with the floating tab bar on top of it at the bottom.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  /// Given by go_router. Knows which tab is open and keeps each tab alive.
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Let the screens scroll behind the floating bar.
      extendBody: true,
      body: navigationShell,
      bottomNavigationBar: FloatingNavBar(
        tabs: appTabs,
        currentIndex: navigationShell.currentIndex,
        // Tapping the tab you're already on jumps back to its first page.
        onTap: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
      ),
    );
  }
}
