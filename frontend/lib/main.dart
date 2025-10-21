import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:my_flutter_app/account_list.dart';
import 'package:my_flutter_app/book_detail.dart';
import 'package:my_flutter_app/cart_page.dart';
import 'package:my_flutter_app/change_password.dart';
import 'package:my_flutter_app/forgot_password.dart';
import 'package:my_flutter_app/home.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/login.dart';
import 'package:my_flutter_app/my_books_page.dart';
import 'package:my_flutter_app/orders_page.dart';
import 'package:my_flutter_app/privacy.dart';
import 'package:my_flutter_app/register.dart';
import 'package:my_flutter_app/services/cart_service.dart';
import 'package:my_flutter_app/services/navigation_service.dart';
import 'package:my_flutter_app/services/settings_service.dart';
import 'package:my_flutter_app/settings.dart';
import 'package:my_flutter_app/splash.dart';
import 'package:my_flutter_app/terms.dart';
import 'package:my_flutter_app/update_profile.dart';
import 'package:my_flutter_app/user_admin.dart';
import 'package:my_flutter_app/wallet_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  await SettingsController.instance.load();
  await CartService.instance.ensureLoaded();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settings = SettingsController.instance;

    return AnimatedBuilder(
      animation: settings,

      builder: (context, _) {
        final themeBase = ThemeData(
          colorSchemeSeed: settings.seedColor,

          useMaterial3: true,

          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(),

            filled: true,

            fillColor: Color(0xFFF7F7FB),

            contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          ),
        );

        return MaterialApp(
          navigatorKey: NavigationService.navigatorKey,

          onGenerateTitle: (context) => context.l10n.appName,

          debugShowCheckedModeBanner: false,

          theme: themeBase,

          darkTheme: ThemeData.dark(useMaterial3: true).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: settings.seedColor,

              brightness: Brightness.dark,
            ),

            inputDecorationTheme: const InputDecorationTheme(
              border: OutlineInputBorder(),
            ),
          ),

          themeMode: settings.themeMode,

          locale: settings.locale,

          localizationsDelegates: [
            GlobalMaterialLocalizations.delegate,

            GlobalWidgetsLocalizations.delegate,

            GlobalCupertinoLocalizations.delegate,

            const AppLocalizationsDelegate(),
          ],

          supportedLocales: AppLocalizations.supportedLocales,

          builder: (context, child) {
            final mq = MediaQuery.of(context);

            return MediaQuery(
              data: mq.copyWith(
                textScaler: TextScaler.linear(settings.fontScale),
              ),

              child: child ?? const SizedBox.shrink(),
            );
          },

          initialRoute: '/',

          routes: {
            '/': (_) => const SplashPage(),

            '/login': (_) => const LoginPage(),

            '/register': (_) => const RegistrationPage(),

            '/home': (_) => const HomePage(),

            '/cart': (_) => const CartPage(),
            '/my-books': (_) => const MyBooksPage(),

            '/wallet': (_) => const WalletPage(),

            '/orders': (_) => const OrderHistoryPage(),
            '/admin': (_) => const UserAdminPage(),

            BookDetailPage.routeName: (_) => const BookDetailPage(),

            '/settings': (_) => const SettingsPage(),

            '/forgot': (_) => const ForgotPasswordPage(),

            '/terms': (_) => const TermsPage(),

            '/privacy': (_) => const PrivacyPage(),

            '/update-profile': (_) => const UpdateProfilePage(),

            '/change-password': (_) => const ChangePasswordPage(),

            '/accounts': (_) => const AccountListPage(),
          },
        );
      },
    );
  }
}
