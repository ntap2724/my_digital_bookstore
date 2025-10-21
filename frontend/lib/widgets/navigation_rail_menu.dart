import 'package:flutter/material.dart';

import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class NavigationRailMenu extends StatefulWidget {
  const NavigationRailMenu({
    super.key,
    required this.currentRoute,
    required this.onDestinationSelected,
    required this.extended,
  });

  final String currentRoute;
  final void Function(String route) onDestinationSelected;
  final bool extended;

  @override
  State<NavigationRailMenu> createState() => _NavigationRailMenuState();
}

class _NavigationRailMenuState extends State<NavigationRailMenu> {
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

  int _getSelectedIndex() {
    // Find index in primary items
    for (var i = 0; i < _primaryItems.length; i++) {
      if (_primaryItems[i].route == widget.currentRoute) {
        return i;
      }
    }

    // Check secondary items (no admin check needed!)
    for (var i = 0; i < _secondaryItems.length; i++) {
      if (_secondaryItems[i].route == widget.currentRoute) {
        return _primaryItems.length + i;
      }
    }

    // Check admin (at the end)
    if (widget.currentRoute == _adminItem.route) {
      return _primaryItems.length + _secondaryItems.length;
    }

    return 0; // Default to home
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final isAdmin = _cachedMenuState?.isAdmin ?? false;

    return Container(
      width: widget.extended ? 256 : 80,
      color: colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gradient header (edge-to-edge)
          if (widget.extended)
            _buildHeader(context, t, _cachedMenuState)
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(child: _buildCompactUserInfo(context, _cachedMenuState)),
            ),

          // Navigation items
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                // Primary items
                for (var i = 0; i < _primaryItems.length; i++)
                  _buildNavItem(
                    context,
                    t,
                    _primaryItems[i],
                    i == _getSelectedIndex(),
                  ),

                // Secondary items
                for (var i = 0; i < _secondaryItems.length; i++)
                  _buildNavItem(
                    context,
                    t,
                    _secondaryItems[i],
                    _getSelectedIndex() == _primaryItems.length + i,
                  ),

                // Admin item - moved to the end
                if (isAdmin)
                  _buildNavItem(
                    context,
                    t,
                    _adminItem,
                    _getSelectedIndex() == _primaryItems.length + _secondaryItems.length,
                  ),
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
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final name = state?.name ?? '';
    final email = state?.email ?? '';
    final initial = name.isNotEmpty
        ? name[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: colorScheme.surface,
            child: CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(
                initial,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            name.isNotEmpty ? name : t.welcome,
            style: textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: colorScheme.onPrimaryContainer,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          if (email.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              email,
              style: textTheme.bodySmall?.copyWith(
                color: colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context,
    AppLocalizations t,
    _NavItem item,
    bool isSelected,
  ) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return InkWell(
      onTap: () => widget.onDestinationSelected(item.route),
      child: Container(
        height: 56,
        padding: EdgeInsets.symmetric(
          horizontal: widget.extended ? 16 : 8,
          vertical: 4,
        ),
        decoration: BoxDecoration(
          color: isSelected
              ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
              : Colors.transparent,
        ),
        child: widget.extended
            ? Row(
                children: [
                  Icon(
                    isSelected ? item.selectedIcon ?? item.icon : item.icon,
                    size: 24,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      item.label(t),
                      style: textTheme.labelLarge?.copyWith(
                        color: isSelected
                            ? colorScheme.onSurface
                            : colorScheme.onSurfaceVariant,
                        fontWeight:
                            isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isSelected ? item.selectedIcon ?? item.icon : item.icon,
                    size: 24,
                    color: isSelected
                        ? colorScheme.primary
                        : colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.label(t),
                    style: textTheme.labelSmall?.copyWith(
                      color: isSelected
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                    ),
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildCompactUserInfo(BuildContext context, _MenuState? state) {
    final colorScheme = Theme.of(context).colorScheme;
    final name = state?.name ?? '';
    final email = state?.email ?? '';
    final initial = name.isNotEmpty
        ? name[0].toUpperCase()
        : (email.isNotEmpty ? email[0].toUpperCase() : '?');

    return CircleAvatar(
      radius: 20,
      backgroundColor: colorScheme.primaryContainer,
      foregroundColor: colorScheme.onPrimaryContainer,
      child: Text(
        initial,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
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
