import 'package:flutter/material.dart';

/// Responsive layout wrapper for authentication pages (login, register, etc.)
/// 
/// Provides adaptive layout based on screen width:
/// - Mobile (<600px): Full width, no card wrapper
/// - Tablet (600-900px): Centered card with 520px max-width
/// - Desktop (≥900px): Centered elevated card with 480px max-width
class ResponsiveAuthLayout extends StatelessWidget {
  final Widget child;

  const ResponsiveAuthLayout({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= 900;
        final isTablet = constraints.maxWidth >= 600 && constraints.maxWidth < 900;
        final isMobile = constraints.maxWidth < 600;
        
        return Container(
          color: isDesktop ? colorScheme.surfaceContainerLowest : null,
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isDesktop 
                    ? 480  // Desktop: 480px card
                    : isTablet 
                        ? 520  // Tablet: 520px
                        : double.infinity,  // Mobile: full width
              ),
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 16 : 0,
                  vertical: 24,
                ),
                child: isDesktop
                    ? Card(
                        elevation: 8,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: child,
                        ),
                      )
                    : isTablet
                        ? Card(
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(32),
                              child: child,
                            ),
                          )
                        : child,  // Mobile: no card wrapper
              ),
            ),
          ),
        );
      },
    );
  }
}
