import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/navigation_service.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _goNext());
  }

  @override
  void dispose() {
    debugPrint('Splash disposed');
    super.dispose();
  }

  Future<void> _goNext() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    try {
      debugPrint('Splash: checking token...');
      final token = await AuthService.instance
          .getToken()
          .timeout(const Duration(seconds: 3), onTimeout: () => null);
      debugPrint('Splash: token = $token');
      if (token != null && token.isNotEmpty) {
        debugPrint('Splash: routing to /home');
        NavigationService.navigatorKey.currentState
            ?.pushReplacementNamed('/home');
        return;
      }
    } catch (_) {}
    debugPrint('Splash: routing to /login');
    NavigationService.navigatorKey.currentState?.pushReplacementNamed('/login');
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color.primary.withValues(alpha: 0.06),
              color.primaryContainer.withValues(alpha: 0.16),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: color.primary.withValues(alpha: 0.12),
                child: Icon(Icons.flutter_dash, size: 42, color: color.primary),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.welcome,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                context.l10n.initializing,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
