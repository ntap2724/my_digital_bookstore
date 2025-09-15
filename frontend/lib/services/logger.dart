import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void d(Object? message) => debugPrint('[D] $message');
  static void i(Object? message) => debugPrint('[I] $message');
  static void w(Object? message) => debugPrint('[W] $message');
  static void e(Object? message, [Object? error, StackTrace? stack]) {
    debugPrint('[E] $message');
    if (error != null) debugPrint('  error: $error');
    if (stack != null) debugPrintStack(stackTrace: stack);
  }
}
