import 'package:flutter/material.dart';

import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class AppNavigationMenu extends StatefulWidget {
  const AppNavigationMenu({super.key, required this.currentRoute});

  final String currentRoute;

  @override
  State<AppNavigationMenu> createState() => _AppNavigationMenuState();
}

class _AppNavigationMenuState extends State<AppNavigationMenu> {
  late final Future<_MenuState> _menuState;

  @override
  void initState() {
    super.initState();
    _menuState = _loadState();
  }

  Future<_MenuState> _loadState() async {
    AccountInfo? account;
    Map<String, dynamic>? profile;

    try {
      account = await AuthService.instance.getActiveAccount();
    } catch (_) {}

    try {
      profile = await AuthService.instance.me();
    } catch (_) {}

    String? displayName;
    String? email;

    final accountName = account?.name?.trim();
    if (accountName != null && accountName.isNotEmpty) {
      displayName = accountName;
    } else {
      final profileName = profile?['name']?.toString().trim();
      if (profileName != null && profileName.isNotEmpty) {
        displayName = profileName;
      }
    }

    final accountEmail = account?.email.trim();
    if (accountEmail != null && accountEmail.isNotEmpty) {
      email = accountEmail;
    } else {
      final profileEmail = profile?['email']?.toString().trim();
      if (profileEmail != null && profileEmail.isNotEmpty) {
        email = profileEmail;
      }
    }

    final role = profile?['role']?.toString().toLowerCase();
    final isAdmin = role == 'admin';

    return _MenuState(
      name: displayName,
      email: email,
      isAdmin: isAdmin,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Drawer(
      child: SafeArea(
        child: FutureBuilder<_MenuState>(
          future: _menuState,
          builder: (context, snapshot) {
            final data = snapshot.data;
            return Column(
              children: [
                _buildHeader(context, t, data),
                Expanded(
                  child: ListView(
                    children: [
                      for (final item in _primaryItems)
                        _buildTile(context, t, item),
                      if (data?.isAdmin ?? false) ...[
                        const Divider(height: 24),
                        _buildTile(context, t, _adminItem),
                      ],
                      const Divider(height: 24),
                      for (final item in _secondaryItems)
                        _buildTile(context, t, item),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations t,
    _MenuState? state,
  ) {
    final theme = Theme.of(context);
    final name = state?.name ?? '';
    final email = state?.email ?? '';

    return UserAccountsDrawerHeader(
      margin: EdgeInsets.zero,
      currentAccountPicture: CircleAvatar(
        child: Text(
          name.isNotEmpty
              ? name[0].toUpperCase()
              : (email.isNotEmpty ? email[0].toUpperCase() : '?'),
        ),
      ),
      accountName: Text(name.isNotEmpty ? name : t.welcome),
      accountEmail: email.isNotEmpty ? Text(email) : null,
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
      ),
    );
  }

  Widget _buildTile(
    BuildContext context,
    AppLocalizations t,
    _NavItem item,
  ) {
    final isSelected = item.route == widget.currentRoute;
    return ListTile(
      leading: Icon(item.icon),
      title: Text(item.label(t)),
      selected: isSelected,
      onTap: () => _onItemTap(context, item),
    );
  }

  void _onItemTap(BuildContext context, _NavItem item) {
    final navigator = Navigator.of(context);
    if (item.route == widget.currentRoute) {
      navigator.pop();
      return;
    }

    navigator.pop();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = item.route;
      if (target == '/home') {
        navigator.popUntil((route) => route.settings.name == '/home');
        return;
      }
      navigator.pushNamedAndRemoveUntil(
        target,
        (route) {
          if (route.settings.name == '/home') {
            return true;
          }
          return route.isFirst;
        },
      );
    });
  }
}

class _MenuState {
  const _MenuState({
    this.name,
    this.email,
    required this.isAdmin,
  });

  final String? name;
  final String? email;
  final bool isAdmin;
}

class _NavItem {
  const _NavItem({
    required this.route,
    required this.icon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final String Function(AppLocalizations) label;
}

const _primaryItems = [
  _NavItem(
    route: '/home',
    icon: Icons.home_outlined,
    label: _labelHome,
  ),
  _NavItem(
    route: '/my-books',
    icon: Icons.library_books_outlined,
    label: _labelMyBooks,
  ),
  _NavItem(
    route: '/cart',
    icon: Icons.shopping_cart_outlined,
    label: _labelCart,
  ),
  _NavItem(
    route: '/wallet',
    icon: Icons.account_balance_wallet_outlined,
    label: _labelWallet,
  ),
  _NavItem(
    route: '/orders',
    icon: Icons.receipt_long_outlined,
    label: _labelOrders,
  ),
];

const _secondaryItems = [
  _NavItem(
    route: '/settings',
    icon: Icons.settings_outlined,
    label: _labelSettings,
  ),
  _NavItem(
    route: '/accounts',
    icon: Icons.people_alt_outlined,
    label: _labelManageAccounts,
  ),
];

const _adminItem = _NavItem(
  route: '/admin',
  icon: Icons.admin_panel_settings_outlined,
  label: _labelAdmin,
);

String _labelHome(AppLocalizations t) => t.home;
String _labelMyBooks(AppLocalizations t) => t.myBooks;
String _labelCart(AppLocalizations t) => t.cart;
String _labelWallet(AppLocalizations t) => t.wallet;
String _labelOrders(AppLocalizations t) => t.orders;
String _labelSettings(AppLocalizations t) => t.settings;
String _labelManageAccounts(AppLocalizations t) => t.manageAccounts;
String _labelAdmin(AppLocalizations t) => t.adminPanel;
