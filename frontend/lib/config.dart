import 'package:flutter/foundation.dart'
    show kIsWeb, defaultTargetPlatform, TargetPlatform;

class AppConfig {
  static const bool usePassportPasswordGrant = false;
  static const String passportTokenEndpoint = '/oauth/token';
  static const String simpleLoginEndpoint = '/api/login';
  static const String simpleRegisterEndpoint = '/api/register';
  static const String emailExistsEndpoint = '/api/email-exists';
  static const String passportClientId = 'YOUR_CLIENT_ID';
  static const String passportClientSecret = 'YOUR_CLIENT_SECRET';

  static String get apiBaseUrl {
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;

    if (kIsWeb) return 'http://127.0.0.1:8000';

    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return 'http://10.0.2.2:8000';
      case TargetPlatform.iOS:
        return 'http://127.0.0.1:8000';
      default:
        return 'http://127.0.0.1:8000';
    }
  }
}
