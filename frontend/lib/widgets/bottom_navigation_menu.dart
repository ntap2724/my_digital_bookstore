import 'package:flutter/material.dart';

import 'package:my_flutter_app/l10n/app_localizations.dart';

class BottomNavigationMenu extends StatelessWidget {
  const BottomNavigationMenu({
    super.key,
    required this.currentRoute,
    required this.onDestinationSelected,
  });

  final String currentRoute;
  final void Function(String route) onDestinationSelected;

  int _getSelectedIndex() {
    for (var i = 0; i < _navItems.length; i++) {
      if (_navItems[i].route == currentRoute) {
        return i;
      }
    }
    return 0; // Default to home
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return NavigationBar(
      selectedIndex: _getSelectedIndex(),
      onDestinationSelected: (index) {
        if (index >= 0 && index < _navItems.length) {
          onDestinationSelected(_navItems[index].route);
        }
      },
      destinations: [
        for (final item in _navItems)
          NavigationDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon ?? item.icon),
            label: item.label(t),
          ),
      ],
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.icon,
    this.selectedIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData? selectedIcon;
  final String Function(AppLocalizations) label;
}

// Bottom nav only shows 5 most important items
const _navItems = [
  _NavItem(
    route: '/home',
    icon: Icons.home_outlined,
    selectedIcon: Icons.home,
    label: _labelHome,
  ),
  _NavItem(
    route: '/my-books',
    icon: Icons.library_books_outlined,
    selectedIcon: Icons.library_books,
    label: _labelMyBooks,
  ),
  _NavItem(
    route: '/cart',
    icon: Icons.shopping_cart_outlined,
    selectedIcon: Icons.shopping_cart,
    label: _labelCart,
  ),
  _NavItem(
    route: '/wallet',
    icon: Icons.account_balance_wallet_outlined,
    selectedIcon: Icons.account_balance_wallet,
    label: _labelWallet,
  ),
  _NavItem(
    route: '/orders',
    icon: Icons.receipt_long_outlined,
    selectedIcon: Icons.receipt_long,
    label: _labelOrders,
  ),
];

String _labelHome(AppLocalizations t) => t.home;
String _labelMyBooks(AppLocalizations t) => t.myBooks;
String _labelCart(AppLocalizations t) => t.cart;
String _labelWallet(AppLocalizations t) => t.wallet;
String _labelOrders(AppLocalizations t) => t.orders;
