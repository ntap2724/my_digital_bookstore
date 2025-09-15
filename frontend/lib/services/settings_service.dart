import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController extends ChangeNotifier {
  SettingsController._();
  static final SettingsController instance = SettingsController._();

  // Palette used across the app (keep in sync with settings UI)
  static const List<Color> palette = <Color>[
    Color(0xFF3B82F6), // blue
    Color(0xFF22C55E), // green
    Color(0xFF8B5CF6), // purple
    Color(0xFFF97316), // orange
  ];

  // Backing fields with sensible defaults
  String _language = 'vi';
  bool _darkMode = false;
  int _colorIndex = 0; // 0..3
  String _fontSize = 'normal'; // small | normal | large

  // Getters
  String get language => _language;
  bool get darkMode => _darkMode;
  int get colorIndex => _colorIndex;
  String get fontSize => _fontSize;

  // Derived values for convenience
  Locale get locale =>
      _language == 'en' ? const Locale('en', 'US') : const Locale('vi', 'VN');
  ThemeMode get themeMode => _darkMode ? ThemeMode.dark : ThemeMode.light;
  Color get seedColor => palette[_colorIndex.clamp(0, palette.length - 1)];
  double get fontScale => switch (_fontSize) {
    'small' => 0.9,
    'large' => 1.15,
    _ => 1.0,
  };

  // Keys
  static const _kLanguage = 'settings.language';
  static const _kDarkMode = 'settings.darkMode';
  static const _kLightMode = 'settings.lightMode'; // legacy key (for migration)
  static const _kColorIndex = 'settings.colorIndex';
  static const _kFontSize = 'settings.fontSize';

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _language = prefs.getString(_kLanguage) ?? _language;
    // Prefer new darkMode key; fallback migrate from old lightMode
    if (prefs.containsKey(_kDarkMode)) {
      _darkMode = prefs.getBool(_kDarkMode) ?? _darkMode;
    } else if (prefs.containsKey(_kLightMode)) {
      final legacyLight = prefs.getBool(_kLightMode);
      if (legacyLight != null) {
        _darkMode = !legacyLight;
        // write new key for future
        await prefs.setBool(_kDarkMode, _darkMode);
      }
    }
    _colorIndex = prefs.getInt(_kColorIndex) ?? _colorIndex;
    _fontSize = prefs.getString(_kFontSize) ?? _fontSize;
    notifyListeners();
  }

  Future<void> setLanguage(String value) async {
    if (value == _language) return;
    _language = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kLanguage, _language);
    notifyListeners();
  }

  Future<void> setDarkMode(bool value) async {
    if (value == _darkMode) return;
    _darkMode = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kDarkMode, _darkMode);
    notifyListeners();
  }

  Future<void> setColorIndex(int value) async {
    if (value == _colorIndex) return;
    _colorIndex = value.clamp(0, palette.length - 1);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kColorIndex, _colorIndex);
    notifyListeners();
  }

  Future<void> setFontSize(String value) async {
    if (value == _fontSize) return;
    _fontSize = (value == 'small' || value == 'large') ? value : 'normal';
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kFontSize, _fontSize);
    notifyListeners();
  }
}
