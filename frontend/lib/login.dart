import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/app_form_field.dart';
import 'package:my_flutter_app/widgets/form_utils.dart';
import 'package:my_flutter_app/widgets/link_button.dart';
import 'package:my_flutter_app/widgets/primary_button.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _pwdCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  List<AccountInfo> _accounts = const [];
  bool _showAccounts = false; // legacy inline list (kept off)
  bool _argsProcessed = false;
  bool _remember = false; // remember login/token
  bool _emailConfirmed = false; // step control: email -> password
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _pwdFocus = FocusNode();

  @override
  void dispose() {
    _emailFocus.dispose();
    _pwdFocus.dispose();
    _emailCtrl.dispose();
    _pwdCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_argsProcessed) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        final argEmail = args['email']?.toString();
        if (argEmail != null && argEmail.isNotEmpty) {
          _emailCtrl.text = argEmail;
          _emailConfirmed = true;
          _checkSavedAndMaybeAutoLogin();
        }
      }
      _argsProcessed = true;
    }
  }

  Future<void> _checkSavedAndMaybeAutoLogin() async {
    final email = _emailCtrl.text.trim().toLowerCase();
    if (email.isEmpty) return;
    final accounts = await AuthService.instance.getAccounts();
    try {
      final acc = accounts.firstWhere((a) => a.id == email);
      if (acc.token.isNotEmpty) {
        await AuthService.instance.setActiveAccount(acc.id);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (_) {}
  }

  Future<void> _confirmEmail() async {
    final s = _emailCtrl.text.trim();
    final ok = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(s);
    if (!ok) {
      _formKey.currentState?.validate();
      return;
    }
    // Clear any previous validation error messages on the email field
    // that might have been shown from a prior failed attempt.
    _formKey.currentState?.validate();
    // Check against backend user database
    final exists = await AuthService.instance.emailExists(s);
    if (!exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.emailNotFound)));
      return;
    }
    // Lookup local saved token for auto-login convenience
    final accounts = await AuthService.instance.getAccounts();
    AccountInfo? acc;
    try {
      acc = accounts.firstWhere((a) => a.id == s.toLowerCase());
    } catch (_) {
      acc = null;
    }
    // Auto-login if saved token exists for this email
    if (acc != null && acc.token.isNotEmpty) {
      await AuthService.instance.setActiveAccount(acc.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    setState(() => _emailConfirmed = true);
    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted) _pwdFocus.requestFocus();
  }

  Future<void> _loadAccounts() async {
    final accs = await AuthService.instance.getAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accs;
      _showAccounts = false; // always off
    });
  }

  Future<void> _doLogin() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    FocusScope.of(context).unfocus();
    try {
      final result = await AuthService.instance.login(
        email: _emailCtrl.text.trim(),
        password: _pwdCtrl.text,
        remember: _remember,
      );
      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.l10n.loginSuccess)));
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        var msg = result.message ?? context.l10n.loginFailed;
        if (msg.toLowerCase().contains('invalid credentials')) {
          msg = context.l10n.invalidCredentials;
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
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top bar: Settings (left) + Accounts (right)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        tooltip: t.settings,
                        onPressed: _loading
                            ? null
                            : () =>
                                  Navigator.of(context).pushNamed('/settings'),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                      IconButton(
                        tooltip: t.manageAccounts,
                        onPressed: _loading
                            ? null
                            : () =>
                                  Navigator.of(context).pushNamed('/accounts'),
                        icon: const Icon(Icons.switch_account_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const CircleAvatar(
                    radius: 36,
                    child: Icon(Icons.lock_open, size: 36),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    t.login,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Show user badge only after pressing Continue (email confirmed)
                  const SizedBox(height: 16),
                  Builder(
                    builder: (context) {
                      if (!_emailConfirmed) return const SizedBox.shrink();
                      final email = _emailCtrl.text.trim();
                      AccountInfo? acc;
                      try {
                        final id = email.toLowerCase();
                        acc = _accounts.firstWhere((a) => a.id == id);
                      } catch (_) {}
                      final displayName = (acc?.name?.isNotEmpty == true)
                          ? acc!.name!.trim()
                          : (email.split('@').first);
                      final avatarText =
                          (displayName.isNotEmpty
                                  ? displayName.trim()[0]
                                  : email[0])
                              .toUpperCase();
                      return Column(
                        children: [
                          CircleAvatar(
                            radius: 30,
                            child: Text(
                              avatarText,
                              style: const TextStyle(fontSize: 22),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            displayName,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            email,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: kFieldSpacing),
                        ],
                      );
                    },
                  ),
                  if (_emailConfirmed) ...[
                    LinkButton(
                      context.l10n.signInWithAnotherEmail,
                      centered: true,
                      onPressed: () {
                        setState(() => _emailConfirmed = false);
                        Future.microtask(() => _emailFocus.requestFocus());
                      },
                    ),
                    const SizedBox(height: kFieldSpacing),
                  ],
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_accounts.isNotEmpty && _showAccounts)
                          const SizedBox.shrink()
                        else ...[
                          if (_emailConfirmed == false)
                            AppFormField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: _emailConfirmed
                                  ? TextInputAction.next
                                  : TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.deny(RegExp(r'\s')),
                              ],
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
                              onChanged: (_) => setState(() {}),
                              onFieldSubmitted: (_) =>
                                  _emailConfirmed ? null : _confirmEmail(),
                            ),
                          if (_emailConfirmed == false)
                            const SizedBox(height: 0),
                          if (_emailConfirmed == true)
                            // Show confirmed email in read-only input above password
                            AppFormField(
                              controller: _emailCtrl,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: t.email,
                                prefixIcon: const Icon(Icons.alternate_email),
                              ),
                            ),
                          const SizedBox(height: 0),
                          if (_emailConfirmed == true)
                            AppFormField(
                              controller: _pwdCtrl,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autovalidateMode: AutovalidateMode.onUserInteraction,
                              decoration: InputDecoration(
                                labelText: t.password,
                                prefixIcon: const Icon(Icons.lock_outline),
                                suffixIcon: IconButton(
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                  tooltip: _obscure
                                      ? t.showPassword
                                      : t.hidePassword,
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? t.passwordRequired
                                  : null,
                              onFieldSubmitted: (_) => _doLogin(),
                            ),
                          // Spacing is handled by AppFormField (16px). Avoid extra gap here.
                          // Remember password toggle
                          if (_emailConfirmed == true)
                            Row(
                              children: [
                                Checkbox(
                                  value: _remember,
                                  onChanged: _loading
                                      ? null
                                      : (v) => setState(
                                          () => _remember = v ?? false,
                                        ),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'vi'
                                      ? 'Nhớ mật khẩu'
                                      : 'Remember password',
                                ),
                              ],
                            ),
                          if (_emailConfirmed == true)
                            const SizedBox(height: 8),

                          PrimaryButton.icon(
                            onPressed: _loading
                                ? null
                                : (_emailConfirmed == true
                                      ? _doLogin
                                      : _confirmEmail),
                            icon: _loading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    _emailConfirmed == true
                                        ? Icons.login
                                        : Icons.arrow_forward,
                                  ),
                            label: Text(
                              _loading
                                  ? t.loggingIn
                                  : (_emailConfirmed == true
                                        ? t.login
                                        : t.continueAction),
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.noAccount),
                            LinkButton(
                              t.register,
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.of(context)
                                      .pushReplacementNamed('/register'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.center,
                          child: LinkButton(
                            t.forgotPassword,
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(context).pushNamed('/forgot'),
                            centered: true,
                          ),
                        ),
                      ],
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
