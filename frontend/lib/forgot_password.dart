import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _newPwdCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _emailReg = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');
  final FocusNode _newPwdFocus = FocusNode();
  final FocusNode _confirmFocus = FocusNode();

  bool _emailVerified = false;
  bool _checkingEmail = false;
  bool _submitting = false;
  bool _obscureNew = true;
  bool _obscureConfirm = true;
  String? _emailServerError;

  @override
  void dispose() {
    _newPwdFocus.dispose();
    _confirmFocus.dispose();
    _emailCtrl.dispose();
    _newPwdCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _clearPasswords() {
    _newPwdCtrl.clear();
    _confirmCtrl.clear();
  }

  bool _isStrong(String value) {
    if (value.length < 8) return false;
    final hasUpper = RegExp(r'[A-Z]').hasMatch(value);
    final hasLower = RegExp(r'[a-z]').hasMatch(value);
    final hasDigit = RegExp(r'\d').hasMatch(value);
    final hasSpecial = RegExp(
      r'[!@#\$%^&*(),.?":{}|<>_\-\[\]\\/;+=]',
    ).hasMatch(value);
    return hasUpper && hasLower && hasDigit && hasSpecial;
  }

  Future<void> _verifyEmail() async {
    if (_checkingEmail) return;
    setState(() => _emailServerError = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _checkingEmail = true);
    FocusScope.of(context).unfocus();
    final lookup = await AuthService.instance.emailExists(
      _emailCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _checkingEmail = false);
    if (!lookup.exists) {
      setState(() {
        _emailServerError = context.l10n.emailNotFound;
        _emailVerified = false;
      });
      _formKey.currentState?.validate();
      return;
    }
    setState(() {
      _emailVerified = true;
      _emailServerError = null;
    });
    await Future.delayed(const Duration(milliseconds: 120));
    if (mounted) _newPwdFocus.requestFocus();
  }

  Future<void> _resetPassword() async {
    if (_submitting) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _submitting = true);
    FocusScope.of(context).unfocus();
    final res = await AuthService.instance.resetPassword(
      email: _emailCtrl.text.trim(),
      newPassword: _newPwdCtrl.text,
      confirmPassword: _confirmCtrl.text,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (res.success) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.passwordChanged)));
      Navigator.of(context).pop();
    } else {
      final msg = res.message ?? context.l10n.errorPrefix('');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _submit() {
    if (_emailVerified) {
      _resetPassword();
    } else {
      _verifyEmail();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final busy = _checkingEmail || _submitting;
    return Scaffold(
      appBar: AppBar(title: Text(t.forgotPassword)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    _emailVerified
                        ? t.forgotInstructionStep2
                        : t.forgotInstruction,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailCtrl,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: _emailVerified
                        ? TextInputAction.next
                        : TextInputAction.done,
                    enabled: !busy,
                    decoration: InputDecoration(
                      labelText: t.email,
                      hintText: 'name@example.com',
                      prefixIcon: const Icon(Icons.alternate_email),
                    ),
                    validator: (value) {
                      final s = value?.trim() ?? '';
                      if (s.isEmpty) return t.emailRequired;
                      if (!_emailReg.hasMatch(s)) return t.emailInvalid;
                      return _emailServerError;
                    },
                    onChanged: (value) {
                      if (_emailServerError != null || _emailVerified) {
                        setState(() {
                          _emailServerError = null;
                          if (_emailVerified) {
                            _emailVerified = false;
                            _clearPasswords();
                          }
                        });
                      }
                    },
                    onFieldSubmitted: (_) {
                      if (_emailVerified) {
                        _newPwdFocus.requestFocus();
                      } else {
                        _submit();
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  if (_emailVerified) ...[
                    TextFormField(
                      controller: _newPwdCtrl,
                      focusNode: _newPwdFocus,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      obscureText: _obscureNew,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: t.newPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          onPressed: () =>
                              setState(() => _obscureNew = !_obscureNew),
                          icon: Icon(
                            _obscureNew
                                ? Icons.visibility
                                : Icons.visibility_off,
                          ),
                          tooltip: _obscureNew
                              ? t.showPassword
                              : t.hidePassword,
                        ),
                      ),
                      validator: (value) {
                        final v = value ?? '';
                        if (v.isEmpty) return t.passwordRequired;
                        if (!_isStrong(v)) return t.passwordNotStrong;
                        return null;
                      },
                      onFieldSubmitted: (_) => _confirmFocus.requestFocus(),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmCtrl,
                      focusNode: _confirmFocus,
                      autovalidateMode: AutovalidateMode.onUserInteraction,
                      obscureText: _obscureConfirm,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: t.confirmPassword,
                        prefixIcon: const Icon(Icons.lock_reset),
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
                      validator: (value) {
                        final v = value ?? '';
                        if (v.isEmpty) return t.confirmPasswordRequired;
                        if (v != _newPwdCtrl.text) {
                          return t.confirmPasswordMismatch;
                        }
                        return null;
                      },
                      onFieldSubmitted: (_) => _resetPassword(),
                    ),
                    const SizedBox(height: 16),
                  ],
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primaryContainer,
                        foregroundColor: Theme.of(
                          context,
                        ).colorScheme.onPrimaryContainer,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: busy ? null : _submit,
                      icon: busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Icon(
                              _emailVerified
                                  ? Icons.key
                                  : Icons.check_circle_outline,
                            ),
                      label: Text(
                        busy
                            ? t.sending
                            : (_emailVerified
                                  ? t.resetPassword
                                  : t.verifyEmail),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

