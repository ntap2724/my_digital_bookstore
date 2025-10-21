import 'package:flutter/material.dart';
import 'package:my_flutter_app/widgets/app_navigation_menu.dart';
import 'package:my_flutter_app/widgets/bottom_navigation_menu.dart';
import 'package:my_flutter_app/widgets/navigation_rail_menu.dart';

/// Responsive navigation wrapper that adapts based on screen size:
/// - Mobile (< 600dp): Drawer + BottomNavigationBar
/// - Tablet (600-840dp): NavigationRail (compact) + Drawer for secondary
/// - Desktop (≥ 840dp): NavigationRail (extended)
class ResponsiveNavigationWrapper extends StatelessWidget {
  const ResponsiveNavigationWrapper({
    super.key,
    required this.currentRoute,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.useDrawer = true,
    this.useBottomNav = true,
    this.useRail = true,
  });

  final String currentRoute;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool useDrawer;
  final bool useBottomNav;
  final bool useRail;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        // Desktop: ≥ 840dp - Extended NavigationRail
        if (width >= 840 && useRail) {
          return _DesktopLayout(
            currentRoute: currentRoute,
            body: body,
            appBar: appBar,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            bottomNavigationBar: bottomNavigationBar,
          );
        }

        // Tablet: 600-840dp - Compact NavigationRail
        if (width >= 600 && useRail) {
          return _TabletLayout(
            currentRoute: currentRoute,
            body: body,
            appBar: appBar,
            floatingActionButton: floatingActionButton,
            floatingActionButtonLocation: floatingActionButtonLocation,
            bottomNavigationBar: bottomNavigationBar,
          );
        }

        // Mobile: < 600dp - Drawer + BottomNavigationBar
        return _MobileLayout(
          currentRoute: currentRoute,
          body: body,
          appBar: appBar,
          floatingActionButton: floatingActionButton,
          floatingActionButtonLocation: floatingActionButtonLocation,
          bottomNavigationBar: bottomNavigationBar,
          useDrawer: useDrawer,
          useBottomNav: useBottomNav,
        );
      },
    );
  }
}

// ==================== Desktop Layout (≥ 840dp) ====================
class _DesktopLayout extends StatelessWidget {
  const _DesktopLayout({
    required this.currentRoute,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
  });

  final String currentRoute;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRailMenu(
            currentRoute: currentRoute,
            extended: true,
            onDestinationSelected: (route) {
              if (route != currentRoute) {
                Navigator.of(context).pushReplacementNamed(route);
              }
            },
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Scaffold(
              appBar: appBar,
              body: body,
              floatingActionButton: floatingActionButton,
              floatingActionButtonLocation: floatingActionButtonLocation,
              bottomNavigationBar: bottomNavigationBar,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Tablet Layout (600-840dp) ====================
class _TabletLayout extends StatelessWidget {
  const _TabletLayout({
    required this.currentRoute,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
  });

  final String currentRoute;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRailMenu(
            currentRoute: currentRoute,
            extended: false,
            onDestinationSelected: (route) {
              if (route != currentRoute) {
                Navigator.of(context).pushReplacementNamed(route);
              }
            },
          ),
          const VerticalDivider(width: 1, thickness: 1),
          Expanded(
            child: Scaffold(
              appBar: appBar,
              body: body,
              floatingActionButton: floatingActionButton,
              floatingActionButtonLocation: floatingActionButtonLocation,
              bottomNavigationBar: bottomNavigationBar,
            ),
          ),
        ],
      ),
    );
  }
}

// ==================== Mobile Layout (< 600dp) ====================
class _MobileLayout extends StatelessWidget {
  const _MobileLayout({
    required this.currentRoute,
    required this.body,
    this.appBar,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    required this.useDrawer,
    required this.useBottomNav,
  });

  final String currentRoute;
  final Widget body;
  final PreferredSizeWidget? appBar;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final bool useDrawer;
  final bool useBottomNav;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: appBar,
      drawer: useDrawer ? AppNavigationMenu(currentRoute: currentRoute) : null,
      body: body,
      floatingActionButton: useDrawer ? null : floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar ??
          (useBottomNav
              ? BottomNavigationMenu(
                  currentRoute: currentRoute,
                  onDestinationSelected: (route) {
                    if (route != currentRoute) {
                      Navigator.of(context).pushReplacementNamed(route);
                    }
                  },
                )
              : null),
    );
  }
}
