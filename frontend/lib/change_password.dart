import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/app_form_field.dart';
import 'package:my_flutter_app/widgets/form_utils.dart';
import 'package:my_flutter_app/widgets/primary_button.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final FocusNode _newFocus = FocusNode();
  bool _ob1 = true, _ob2 = true, _ob3 = true;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _newFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _newFocus.dispose();
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool _isStrong(String v) {
    if (v.length < 8) return false;
    final up = RegExp(r'[A-Z]').hasMatch(v);
    final lo = RegExp(r'[a-z]').hasMatch(v);
    final di = RegExp(r'\d').hasMatch(v);
    final sp = RegExp(r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/;+=]').hasMatch(v);
    return up && lo && di && sp;
  }

  Widget _passwordChecklist(String v, AppLocalizations t) {
    final hasLen = v.length >= 8;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(v);
    final hasLower = RegExp(r'[a-z]').hasMatch(v);
    final hasDigit = RegExp(r'\d').hasMatch(v);
    final hasSpecial = RegExp(
      r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/;+=]',
    ).hasMatch(v);

    Widget item(bool ok, String text) => Row(
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

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    FocusScope.of(context).unfocus();
    final res = await AuthService.instance.changePassword(
      currentPassword: _currentCtrl.text,
      newPassword: _newCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.success) {
      // If the user had a remembered token, clear it so future logins require password
      try {
        await AuthService.instance.clearSavedTokenForActiveAccount();
      } catch (_) {}
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(context.l10n.passwordChanged)));
      Navigator.of(context).pop();
    } else {
      final msg = res.message ?? context.l10n.errorPrefix('');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(t.changePasswordTitle)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AppFormField(
                      controller: _currentCtrl,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      obscureText: _ob1,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t.currentPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _ob1 = !_ob1),
                          icon: Icon(
                            _ob1 ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? t.passwordRequired : null,
                    ),
                    const SizedBox(height: 0),
                    AppFormField(
                      controller: _newCtrl,
                      focusNode: _newFocus,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      obscureText: _ob2,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t.newPassword,
                        prefixIcon: const Icon(Icons.password_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _ob2 = !_ob2),
                          icon: Icon(
                            _ob2 ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      bottomSpacing: 0,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.isEmpty) return t.passwordRequired;
                        if (!_isStrong(v)) return t.passwordNotStrong;
                        if (v == _currentCtrl.text) return t.passwordMustDiffer;
                        return null;
                      },
                    ),
                    Builder(builder: (context) {
                      final theme = Theme.of(context);
                      final showChecklist = _newFocus.hasFocus;
                      final hasText = _newCtrl.text.isNotEmpty;
                      final showPositive = hasText &&
                          !showChecklist &&
                          _isStrong(_newCtrl.text) &&
                          _newCtrl.text != _currentCtrl.text;
                      if (!showChecklist && !showPositive) {
                        return const SizedBox(height: 16);
                      }
                      final okStyle = helperTextStyle(context)
                          .copyWith(color: theme.colorScheme.primary);
                      return FieldHelper(
                        child: showChecklist
                            ? _passwordChecklist(_newCtrl.text, t)
                            : Text(t.passwordOk, style: okStyle),
                      );
                    }),
                    AppFormField(
                      controller: _confirmCtrl,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      obscureText: _ob3,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: t.confirmNewPassword,
                        prefixIcon: const Icon(Icons.lock_person_outlined),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _ob3 = !_ob3),
                          icon: Icon(
                            _ob3 ? Icons.visibility : Icons.visibility_off,
                          ),
                        ),
                      ),
                      bottomSpacing: 0,
                      onChanged: (_) => setState(() {}),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return t.confirmPasswordRequired;
                        }
                        if (v != _newCtrl.text) {
                          return t.confirmPasswordMismatch;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    Builder(builder: (context) {
                      final ok =
                          _confirmCtrl.text.isNotEmpty && _confirmCtrl.text == _newCtrl.text;
                      if (!ok) return const SizedBox(height: 16);
                      final style = helperTextStyle(context)
                          .copyWith(color: Theme.of(context).colorScheme.primary);
                      return FieldHelper(
                        child: Text(context.l10n.confirmPasswordMatch, style: style),
                      );
                    }),
                    const SizedBox(height: 4),
                    PrimaryButton.icon(
                      onPressed: _submitting ? null : _submit,
                      icon: _submitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.key_outlined),
                      label: Text(
                        _submitting ? t.sending : t.changePasswordTitle,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
