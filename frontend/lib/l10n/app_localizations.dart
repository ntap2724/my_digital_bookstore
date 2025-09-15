import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/widgets.dart';

class AppLocalizations {
  final Locale locale;
  final Map<String, String> _strings;
  final Map<String, String> _fallback;

  AppLocalizations._(this.locale, this._strings, this._fallback);

  static const supportedLocales = [Locale('en'), Locale('vi')];

  static Future<AppLocalizations> load(Locale locale) async {
    final lang = locale.languageCode.toLowerCase();
    final primaryPath = 'assets/l10n/$lang.json';
    final fallbackPath = 'assets/l10n/en.json';

    Map<String, String> decode(String src) {
      final map = (jsonDecode(src) as Map).cast<String, dynamic>();
      return map.map((k, v) => MapEntry(k, v.toString()));
    }

    // Load primary; if missing, fallback to en
    Map<String, String> primary;
    try {
      final s = await rootBundle.loadString(primaryPath, cache: false);
      primary = decode(s);
    } catch (_) {
      final s = await rootBundle.loadString(fallbackPath, cache: false);
      primary = decode(s);
    }

    // Load fallback EN for missing keys
    Map<String, String> fb;
    try {
      final s = await rootBundle.loadString(fallbackPath, cache: false);
      fb = decode(s);
    } catch (_) {
      fb = const {};
    }

    return AppLocalizations._(locale, primary, fb);
  }

  static AppLocalizations of(BuildContext context) {
    final t = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(t != null, 'AppLocalizations not found in widget tree.');
    return t!;
  }

  String _t(String key) => _strings[key] ?? _fallback[key] ?? key;

  String _fmt(String key, Map<String, String> params) {
    var s = _t(key);
    params.forEach((k, v) => s = s.replaceAll('{$k}', v));
    return s;
  }

  // ---- App / Common ----
  String get appName => _t('appName');
  String get settings => _t('settings');
  String get view => _t('view');
  String get welcome => _t('welcome');
  String get initializing => _t('initializing');
  String get home => _t('home');
  String get refresh => _t('refresh');
  String get retry => _t('retry');
  String get noUserData => _t('noUserData');
  String get rawData => _t('rawData');
  String get drawerSettings => _t('drawerSettings');
  String get drawerLogout => _t('drawerLogout');

  // ---- Dynamic helpers ----
  String errorPrefix(String message) =>
      _fmt('errorPrefix', {'message': message});
  String helloUser(String name) => _fmt('helloUser', {'name': name});
  String emailLabel(String email) => _fmt('emailLabel', {'email': email});
  String linkSentTo(String email) => _fmt('linkSentTo', {'email': email});
  String confirmRemoveMessage(String email) =>
      _fmt('confirmRemoveMessage', {'email': email});

  // ---- Auth / Login / Register ----
  String get login => _t('login');
  String get register => _t('register');
  String get loginSuccess => _t('loginSuccess');
  String get loginFailed => _t('loginFailed');
  String get invalidCredentials => _t('invalidCredentials');
  String get emailNotFound => _t('emailNotFound');
  String get signInWithAnotherEmail => _t('signInWithAnotherEmail');
  String get continueAction => _t('continueAction');
  String get forgotPassword => _t('forgotPassword');
  String get sending => _t('sending');
  String get sendLink => _t('sendLink');
  String get forgotInstruction => _t('forgotInstruction');
  String get haveAccount => _t('haveAccount');
  String get noAccount => _t('noAccount');
  String get loggingIn => _t('loggingIn');

  // ---- Fields / Validation ----
  String get email => _t('email');
  String get emailRequired => _t('emailRequired');
  String get emailInvalid => _t('emailInvalid');
  String get password => _t('password');
  String get passwordRequired => _t('passwordRequired');
  String get showPassword => _t('showPassword');
  String get hidePassword => _t('hidePassword');
  String get fullName => _t('fullName');
  String get fullNameHint => _t('fullNameHint');
  String get fullNameRequired => _t('fullNameRequired');
  String get fullNameTooShort => _t('fullNameTooShort');
  String get phone => _t('phone');
  String get phoneHint => _t('phoneHint');
  String get phoneRequired => _t('phoneRequired');
  String get phoneInvalid => _t('phoneInvalid');
  String get dateOfBirth => _t('dateOfBirth');
  String get selectDate => _t('selectDate');
  String get gender => _t('gender');
  String get male => _t('male');
  String get female => _t('female');
  String get other => _t('other');
  String get genderRequired => _t('genderRequired');
  String get confirmPassword => _t('confirmPassword');
  String get confirmPasswordRequired => _t('confirmPasswordRequired');
  String get confirmPasswordMismatch => _t('confirmPasswordMismatch');
  String get confirmPasswordMatch => _t('confirmPasswordMatch');
  String get passwordNotStrong => _t('passwordNotStrong');
  String get passwordRuleLen => _t('passwordRuleLen');
  String get passwordRuleUpper => _t('passwordRuleUpper');
  String get passwordRuleLower => _t('passwordRuleLower');
  String get passwordRuleDigit => _t('passwordRuleDigit');
  String get passwordRuleSpecial => _t('passwordRuleSpecial');
  String get passwordOk => _t('passwordOk');
  String get dobRequired => _t('dobRequired');
  String get ageRequirement => _t('ageRequirement');

  // ---- Settings ----
  String get language => _t('language');
  String get vietnamese => _t('vietnamese');
  String get english => _t('english');
  String get darkMode => _t('darkMode');
  String get color => _t('color');
  String get fontSize => _t('fontSize');
  String get fontSmall => _t('fontSmall');
  String get fontNormal => _t('fontNormal');
  String get fontLarge => _t('fontLarge');
  String get changeInfoTitle => _t('changeInfoTitle');
  String get changePassword => _t('changePassword');
  String get tosPrivacy => _t('tosPrivacy');
  String get tosShort => _t('tosShort');
  String get privacyShort => _t('privacyShort');
  String get agreePrefix => _t('agreePrefix');
  String get and => _t('and');
  String get registerSuccess => _t('registerSuccess');
  String get registerFailed => _t('registerFailed');
  String get deleteAccount => _t('deleteAccount');
  String get deleteAccountWarning => _t('deleteAccountWarning');
  String get emailAlreadyTaken => _t('emailAlreadyTaken');
  String get registerTitle => _t('registerTitle');
  String get registerSubtitle => _t('registerSubtitle');

  // ---- Change password ----
  String get changePasswordTitle => _t('changePasswordTitle');
  String get currentPassword => _t('currentPassword');
  String get newPassword => _t('newPassword');
  String get confirmNewPassword => _t('confirmNewPassword');
  String get passwordMustDiffer => _t('passwordMustDiffer');
  String get passwordChanged => _t('passwordChanged');

  // ---- Accounts ----
  String get manageAccounts => _t('manageAccounts');
  String get noAccounts => _t('noAccounts');
  String get active => _t('active');
  String get remove => _t('remove');
  String get cancel => _t('cancel');
  String get addAccount => _t('addAccount');
  String get confirmRemoveTitle => _t('confirmRemoveTitle');
  String get confirmLogoutMessage => _t('confirmLogoutMessage');
  String get switchAccount => _t('switchAccount');

  // ---- Dangerous actions ----
  String get deleteAccountSuccess => _t('deleteAccountSuccess');
  String get deleteAccountFailed => _t('deleteAccountFailed');

  // ---- Update profile ----
  String get saveChanges => _t('saveChanges');
  String get unsavedChangesTitle => _t('unsavedChangesTitle');
  String get unsavedChangesMessage => _t('unsavedChangesMessage');
  String get discard => _t('discard');
  String get stay => _t('stay');
  String get profileUpdated => _t('profileUpdated');

  // ---- Error texts ----
  String get errorLoadingInfo => _t('errorLoadingInfo');
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    final lang = locale.languageCode.toLowerCase();
    return lang == 'en' || lang == 'vi';
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    // Use SynchronousFuture if you cache results; here we load assets per locale.
    return AppLocalizations.load(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}

extension AppLocalizationsBuildContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
