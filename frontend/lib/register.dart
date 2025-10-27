import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/app_form_field.dart';
import 'package:my_flutter_app/widgets/app_small_field.dart';
import 'package:my_flutter_app/widgets/bookstore_hero.dart';
import 'package:my_flutter_app/widgets/form_section.dart';
import 'package:my_flutter_app/widgets/form_utils.dart';
import 'package:my_flutter_app/widgets/link_button.dart';
import 'package:my_flutter_app/widgets/password_strength_meter.dart';
import 'package:my_flutter_app/widgets/responsive_auth_layout.dart';

class RegistrationPage extends StatefulWidget {
  const RegistrationPage({super.key});

  @override
  State<RegistrationPage> createState() => _RegistrationPageState();
}

class _RegistrationPageState extends State<RegistrationPage> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _pwdFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _obscurePwd = true;
  bool _obscureConfirm = true;
  bool _submitting = false;

  DateTime? _dob;
  String? _gender;
  bool _acceptedTerms = false;

  final _emailReg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final _phoneReg = RegExp(r'^(0|\+84)(\d{9})$');

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(() => setState(() {}));
    _emailFocus.addListener(() => setState(() {}));
    _phoneFocus.addListener(() => setState(() {}));
    _pwdFocus.addListener(() => setState(() {}));
    _confirmFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _dobCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _pwdFocus.dispose();
    _confirmFocus.dispose();
    super.dispose();
  }

  bool _isStrongPassword(String value) {
    if (value.length < 8) return false;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final hasLower = RegExp(r'[a-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    final hasSpecial = RegExp(
      r'[!@#\$%^&*(),.?\":{}|<>_\-\[\]\\/;+=]',
    ).hasMatch(value);
    return hasUpper && hasLower && hasDigit && hasSpecial;
  }

  bool get _isReadyToSubmit {
    final nameOk = _fullNameCtrl.text.trim().length >= 2;
    final emailOk = _emailReg.hasMatch(_emailCtrl.text.trim());
    final phoneOk = _phoneReg.hasMatch(
      _phoneCtrl.text.replaceAll(RegExp(r'\s+'), ''),
    );
    final pwd = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;
    final pwdOk = _isStrongPassword(pwd);
    final matchOk = pwd == confirm && confirm.isNotEmpty;
    final dobOk = _dob != null && _age(_dob!) >= 13;
    final genderOk = _gender != null && _gender!.isNotEmpty;
    return nameOk &&
        emailOk &&
        phoneOk &&
        pwdOk &&
        matchOk &&
        dobOk &&
        genderOk &&
        _acceptedTerms;
  }

  int _age(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final init = _dob ?? DateTime(now.year - 18, now.month, now.day);
    final first = DateTime(now.year - 120);
    final last = DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: first,
      lastDate: last,
    );
    if (picked != null) {
      setState(() {
        _dob = picked;
        _dobCtrl.text = _formatDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid || !_isReadyToSubmit || _submitting) return;
    setState(() => _submitting = true);
    FocusScope.of(context).unfocus();
    try {
      final result = await AuthService.instance.register(
        name: _fullNameCtrl.text.trim(),
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        phone: _phoneCtrl.text.trim(),
        dob: _dob!,
        gender: _gender!,
        acceptedTerms: _acceptedTerms,
      );
      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.registerSuccess)));
        // Navigate to home after successful registration and auto-login
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        var msg = result.message ?? context.l10n.registerFailed;
        final lower = msg.toLowerCase();
        if (lower.contains('email') && lower.contains('already been taken')) {
          msg = context.l10n.emailAlreadyTaken;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(msg)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.errorPrefix(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final isSmallScreen = MediaQuery.of(context).size.width < 600;
    final isMobile = MediaQuery.of(context).size.width < 400;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: ResponsiveAuthLayout(
          child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: isSmallScreen ? 8 : 8),
                  // Hero Section
                  BookStoreHero(
                    icon: Icons.auto_stories_rounded,
                    title: t.registerTitle,
                    subtitle: t.registerSubtitle,
                    iconSize: isSmallScreen ? 36 : 40,
                    compact: true,
                  ),
                  // Form
                  Form(
                    key: _formKey,
                    autovalidateMode: AutovalidateMode.disabled,
                    child: Column(
                      children: [
                        // Personal Information Section
                        FormSection(
                          title: t.personalInformation,
                          icon: Icons.person_outline,
                          spacing: isSmallScreen ? 14 : 12,
                          children: [
                            // Full Name
                            AppFormField(
                              controller: _fullNameCtrl,
                              focusNode: _nameFocus,
                              textInputAction: TextInputAction.next,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: t.fullName,
                                hintText: t.fullNameHint,
                                prefixIcon: const Icon(Icons.badge_outlined),
                              ),
                              validator: (v) {
                                final s = v?.trim() ?? '';
                                if (s.isEmpty) return t.fullNameRequired;
                                if (s.length < 2) return t.fullNameTooShort;
                                return null;
                              },
                              onFieldSubmitted: (_) => _emailFocus.requestFocus(),
                            ),
                            // Email
                            AppFormField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.next,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: t.email,
                                hintText: 'name@example.com',
                                prefixIcon: const Icon(Icons.alternate_email),
                              ),
                              validator: (v) {
                                final s = v?.trim() ?? '';
                                if (s.isEmpty) return t.emailRequired;
                                if (!RegExp(
                                  r'^[^\s@]+@[^\s@]+\.[^\s@]+$',
                                ).hasMatch(s)) {
                                  return t.emailInvalid;
                                }
                                return null;
                              },
                              onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                            ),
                            // Phone
                            AppFormField(
                              controller: _phoneCtrl,
                              focusNode: _phoneFocus,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: t.phone,
                                hintText: t.phoneHint,
                                prefixIcon: const Icon(Icons.phone_outlined),
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'[0-9\+\s]'),
                                ),
                              ],
                              validator: (v) {
                                final s = (v ?? '').replaceAll(RegExp(r'\s+'), '');
                                if (s.isEmpty) return t.phoneRequired;
                                if (!_phoneReg.hasMatch(s)) return t.phoneInvalid;
                                return null;
                              },
                              onFieldSubmitted: (_) => _pwdFocus.requestFocus(),
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 24),
                        // Account Security Section
                        FormSection(
                          title: t.accountSecurity,
                          icon: Icons.security_outlined,
                          spacing: isSmallScreen ? 14 : 12,
                          children: [
                            // Password
                            AppFormField(
                              controller: _passwordCtrl,
                              focusNode: _pwdFocus,
                              obscureText: _obscurePwd,
                              textInputAction: TextInputAction.next,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: t.password,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscurePwd = !_obscurePwd),
                                  icon: Icon(
                                    _obscurePwd
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  tooltip: _obscurePwd
                                      ? t.showPassword
                                      : t.hidePassword,
                                ),
                              ),
                              validator: (v) {
                                final s = v ?? '';
                                if (s.isEmpty) return t.passwordRequired;
                                if (!_isStrongPassword(s)) {
                                  return t.passwordNotStrong;
                                }
                                return null;
                              },
                              onChanged: (_) => setState(() {}),
                              onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                            ),
                            // Password Strength Meter (always visible)
                            if (_passwordCtrl.text.isNotEmpty)
                              PasswordStrengthMeter(
                                password: _passwordCtrl.text,
                                showLabel: true,
                                localizations: t,
                              ),
                            // Password checklist/ok message
                            Builder(
                              builder: (context) {
                                final theme = Theme.of(context);
                                final showChecklist = _pwdFocus.hasFocus;
                                final hasText = _passwordCtrl.text.isNotEmpty;
                                final showPositive =
                                    !showChecklist &&
                                    hasText &&
                                    _isStrongPassword(_passwordCtrl.text);
                                if (!showChecklist && !showPositive) {
                                  return const SizedBox.shrink();
                                }
                                final okStyle = helperTextStyle(
                                  context,
                                ).copyWith(color: theme.colorScheme.primary);
                                return FieldHelper(
                                  child: showChecklist
                                      ? _passwordChecklist(_passwordCtrl.text, t)
                                      : Text(t.passwordOk, style: okStyle),
                                );
                              },
                            ),
                            // Confirm Password
                            AppFormField(
                              controller: _confirmCtrl,
                              focusNode: _confirmFocus,
                              obscureText: _obscureConfirm,
                              textInputAction: TextInputAction.done,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: t.confirmPassword,
                                prefixIcon: const Icon(Icons.lock_person_outlined),
                                suffixIcon: IconButton(
                                  onPressed: () => setState(
                                    () => _obscureConfirm = !_obscureConfirm,
                                  ),
                                  icon: Icon(
                                    _obscureConfirm
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  tooltip: _obscureConfirm
                                      ? t.showPassword
                                      : t.hidePassword,
                                ),
                              ),
                              onChanged: (_) => setState(() {}),
                              validator: (v) {
                                if (v == null || v.isEmpty) {
                                  return t.confirmPasswordRequired;
                                }
                                if (v != _passwordCtrl.text) {
                                  return t.confirmPasswordMismatch;
                                }
                                return null;
                              },
                            ),
                            // Confirm password match message
                            Builder(
                              builder: (context) {
                                final ok =
                                    _confirmCtrl.text.isNotEmpty &&
                                    _confirmCtrl.text == _passwordCtrl.text;
                                if (!ok) return const SizedBox.shrink();
                                final style = helperTextStyle(context).copyWith(
                                  color: Theme.of(context).colorScheme.primary,
                                );
                                return FieldHelper(
                                  child: Text(
                                    context.l10n.confirmPasswordMatch,
                                    style: style,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: isSmallScreen ? 20 : 24),
                        // DOB and Gender row/column (responsive)
                        if (isMobile)
                          Column(
                            children: [
                              AppSmallTextField(
                                controller: _dobCtrl,
                                readOnly: true,
                                onTap: _pickDob,
                                decoration: InputDecoration(
                                  labelText: t.dateOfBirth,
                                  prefixIcon: const Icon(Icons.cake_outlined),
                                  suffixIcon: ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Material(
                                      type: MaterialType.transparency,
                                      child: IconButton(
                                        tooltip: t.selectDate,
                                        splashRadius: 20,
                                        onPressed: _pickDob,
                                        icon: const Icon(Icons.event_outlined),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              AppSmallDropdown<String>(
                                initialValue: _gender,
                                autovalidateMode:
                                    AutovalidateMode.onUserInteraction,
                                decoration: InputDecoration(
                                  labelText: t.gender,
                                  prefixIcon: const Icon(Icons.wc_outlined),
                                ),
                                items: [
                                  DropdownMenuItem(
                                    value: 'male',
                                    child: Text(t.male),
                                  ),
                                  DropdownMenuItem(
                                    value: 'female',
                                    child: Text(t.female),
                                  ),
                                  DropdownMenuItem(
                                    value: 'other',
                                    child: Text(t.other),
                                  ),
                                ],
                                onChanged: (v) => setState(() {
                                  _gender = v;
                                }),
                                validator: (v) => (v == null || v.isEmpty)
                                    ? t.genderRequired
                                    : null,
                              ),
                            ],
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: AppSmallTextField(
                                  controller: _dobCtrl,
                                  readOnly: true,
                                  onTap: _pickDob,
                                  decoration: InputDecoration(
                                    labelText: t.dateOfBirth,
                                    prefixIcon: const Icon(Icons.cake_outlined),
                                    suffixIcon: ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Material(
                                        type: MaterialType.transparency,
                                        child: IconButton(
                                          tooltip: t.selectDate,
                                          splashRadius: 20,
                                          onPressed: _pickDob,
                                          icon: const Icon(Icons.event_outlined),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: AppSmallDropdown<String>(
                                  initialValue: _gender,
                                  autovalidateMode:
                                      AutovalidateMode.onUserInteraction,
                                  decoration: InputDecoration(
                                    labelText: t.gender,
                                    prefixIcon: const Icon(Icons.wc_outlined),
                                  ),
                                  items: [
                                    DropdownMenuItem(
                                      value: 'male',
                                      child: Text(t.male),
                                    ),
                                    DropdownMenuItem(
                                      value: 'female',
                                      child: Text(t.female),
                                    ),
                                    DropdownMenuItem(
                                      value: 'other',
                                      child: Text(t.other),
                                    ),
                                  ],
                                  onChanged: (v) => setState(() {
                                    _gender = v;
                                  }),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? t.genderRequired
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        SizedBox(height: isSmallScreen ? 18 : 16),
                        // Terms and Privacy checkbox
                        Theme(
                          data: Theme.of(context).copyWith(
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            hoverColor: Colors.transparent,
                          ),
                          child: CheckboxListTile(
                            value: _acceptedTerms,
                            onChanged: (v) =>
                                setState(() => _acceptedTerms = v ?? false),
                            dense: true,
                            visualDensity: const VisualDensity(
                              horizontal: -4,
                              vertical: -4,
                            ),
                            contentPadding: EdgeInsets.zero,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: RichText(
                              text: TextSpan(
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontSize: 12,
                                ),
                                children: [
                                  TextSpan(text: t.agreeToTermsPrefix),
                                  TextSpan(
                                    text: t.termsOfService,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => Navigator.of(context).pushNamed('/terms'),
                                  ),
                                  TextSpan(text: t.andText),
                                  TextSpan(
                                    text: t.privacyPolicy,
                                    style: TextStyle(
                                      color: Theme.of(context).colorScheme.primary,
                                      decoration: TextDecoration.underline,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    recognizer: TapGestureRecognizer()
                                      ..onTap = () => Navigator.of(context).pushNamed('/privacy'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        // Age requirement warning
                        if (_dob != null && _age(_dob!) < 13)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                t.ageRequirement,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Theme.of(context).colorScheme.error,
                                ),
                              ),
                            ),
                          ),
                        SizedBox(height: isSmallScreen ? 18 : 20),
                        // Register button
                        FilledButton.icon(
                          onPressed: _isReadyToSubmit && !_submitting
                              ? _submit
                              : null,
                          icon: _submitting
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.person_add),
                          label: Text(
                            _submitting ? t.loggingIn : t.register,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(double.infinity, 52),
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Theme.of(context).colorScheme.onPrimary,
                            elevation: 2,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        SizedBox(height: isSmallScreen ? 18 : 20),
                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.haveAccount),
                            const SizedBox(width: 4),
                            LinkButton(
                              t.login,
                              onPressed: () => Navigator.of(
                                context,
                              ).pushReplacementNamed('/login'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              ),
        ),
      ),
    );
  }

  Widget _passwordChecklist(String value, AppLocalizations t) {
    final hasLen = value.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final hasLower = RegExp(r'[a-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    final hasSpecial = RegExp(
      r'[!@#\$%^&*(),.?\":{}|<>_\-\[\]\\/;+=]',
    ).hasMatch(value);

    Widget item(bool ok, String text) {
      return Row(
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            size: 16,
            color: ok ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        item(hasLen, t.passwordRuleLen),
        item(hasUpper, t.passwordRuleUpper),
        item(hasLower, t.passwordRuleLower),
        item(hasDigit, t.passwordRuleDigit),
        item(hasSpecial, t.passwordRuleSpecial),
      ],
    );
  }

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
}
