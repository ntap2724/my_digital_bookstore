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
  _MenuState? _cachedMenuState;

  @override
  void initState() {
    super.initState();
    _loadStateSync(); // Load immediately from cache
    _loadStateAsync(); // Then refresh from network
  }

  /// Load user info synchronously from AuthService cache (instant)
  Future<void> _loadStateSync() async {
    try {
      // Load from persistent or in-memory cache (fast!)
      final cachedProfile = await AuthService.instance.getCachedProfile();

      if (cachedProfile != null) {
        final name = cachedProfile['name']?.toString().trim();
        final email = cachedProfile['email']?.toString().trim();
        final role = cachedProfile['role']?.toString().toLowerCase();
        final isAdmin = role == 'admin';

        if (mounted) {
          setState(() {
            _cachedMenuState = _MenuState(
              name: (name != null && name.isNotEmpty) ? name : null,
              email: (email != null && email.isNotEmpty) ? email : null,
              isAdmin: isAdmin,
            );
          });
        }
      }
    } catch (_) {}
  }

  /// Load user info asynchronously from network (background refresh)
  Future<void> _loadStateAsync() async {
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

    if (!mounted) return;

    setState(() {
      _cachedMenuState = _MenuState(
        name: displayName,
        email: email,
        isAdmin: isAdmin,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Drawer(
      child: Column(
        children: [
          _buildHeader(context, t, _cachedMenuState),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                // Primary navigation items
                for (final item in _primaryItems)
                  _buildNavigationItem(context, t, item, isPrimary: true),

                // Secondary navigation items
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 8,
                  ),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.5),
                  ),
                ),
                for (final item in _secondaryItems)
                  _buildNavigationItem(context, t, item, isPrimary: false),

                // Admin section (if admin) - moved to the end
                if (_cachedMenuState?.isAdmin ?? false) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 8,
                    ),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.5),
                    ),
                  ),
                  _buildNavigationItem(context, t, _adminItem, isAdmin: true),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    AppLocalizations t,
    _MenuState? state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final name = state?.name ?? '';
    final email = state?.email ?? '';
    final initial = name.isNotEmpty
        ? name[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primaryContainer,
            colorScheme.primary.withValues(alpha: 0.8),
          ],
        ),
      ),
      child: SafeArea(
        left: false,
        right: false,
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
                // Avatar with double circle effect
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: 28,
                    backgroundColor: colorScheme.surface,
                    child: CircleAvatar(
                      radius: 26,
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: Text(
                        initial,
                        style: textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Name
                Text(
                  name.isNotEmpty ? name : t.welcome,
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  // Email
                  Text(
                    email,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationItem(
    BuildContext context,
    AppLocalizations t,
    _NavItem item, {
    bool isPrimary = true,
    bool isAdmin = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;
    final isSelected = item.route == widget.currentRoute;

    // Determine colors based on state and type
    Color? backgroundColor;
    Color? foregroundColor;
    Color? iconColor;

    if (isSelected) {
      backgroundColor = colorScheme.surfaceContainerHighest;
      foregroundColor = colorScheme.onSurface;
      iconColor = colorScheme.onSecondaryContainer;
    } else if (isAdmin) {
      backgroundColor = Colors.transparent;
      foregroundColor = colorScheme.primary;
      iconColor = colorScheme.primary;
    } else {
      backgroundColor = Colors.transparent;
      foregroundColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
      iconColor = colorScheme.onSurfaceVariant.withValues(alpha: 0.7);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        child: InkWell(
          onTap: () => _onItemTap(context, item),
          borderRadius: BorderRadius.circular(28),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: isSelected
                  ? Border(
                      left: BorderSide(
                        color: colorScheme.primary,
                        width: 4,
                      ),
                    )
                  : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(
                  isSelected ? item.selectedIcon ?? item.icon : item.icon,
                  size: 24,
                  color: iconColor,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    item.label(t),
                    style: (isPrimary
                            ? textTheme.labelLarge
                            : textTheme.bodyMedium)
                        ?.copyWith(
                      color: foregroundColor,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
    this.selectedIcon,
    required this.label,
  });

  final String route;
  final IconData icon;
  final IconData? selectedIcon;
  final String Function(AppLocalizations) label;
}

const _primaryItems = [
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

const _secondaryItems = [
  _NavItem(
    route: '/settings',
    icon: Icons.settings_outlined,
    selectedIcon: Icons.settings,
    label: _labelSettings,
  ),
  _NavItem(
    route: '/accounts',
    icon: Icons.people_alt_outlined,
    selectedIcon: Icons.people_alt,
    label: _labelManageAccounts,
  ),
];

const _adminItem = _NavItem(
  route: '/admin',
  icon: Icons.admin_panel_settings_outlined,
  selectedIcon: Icons.admin_panel_settings,
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
