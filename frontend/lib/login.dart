import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/app_form_field.dart';
import 'package:my_flutter_app/widgets/bookstore_hero.dart';
import 'package:my_flutter_app/widgets/gradient_card.dart';
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
  String? _lookupName;
  bool _showAccounts = false;
  bool _argsProcessed = false;
  bool _remember = false;
  bool _emailConfirmed = false;
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
        final rawName = (args['displayName'] ?? args['name'])?.toString();
        final trimmedName = rawName?.trim();
        if (trimmedName != null && trimmedName.isNotEmpty) {
          _lookupName = trimmedName;
        }
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
    _formKey.currentState?.validate();
    final lookup = await AuthService.instance.emailExists(s);
    if (!lookup.exists) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.emailNotFound)));
      return;
    }
    final lookupName = () {
      final raw = lookup.name;
      if (raw == null) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    }();
    final accounts = await AuthService.instance.getAccounts();
    AccountInfo? acc;
    try {
      acc = accounts.firstWhere((a) => a.id == s.toLowerCase());
    } catch (_) {
      acc = null;
    }
    if (acc != null && acc.token.isNotEmpty) {
      await AuthService.instance.setActiveAccount(acc.id);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
      return;
    }
    setState(() {
      _emailConfirmed = true;
      _lookupName = lookupName;
    });
    await Future.delayed(const Duration(milliseconds: 50));
    if (mounted) _pwdFocus.requestFocus();
  }

  Future<void> _loadAccounts() async {
    final accs = await AuthService.instance.getAccounts();
    if (!mounted) return;
    setState(() {
      _accounts = accs;
      _showAccounts = false;
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
    final isSmallScreen = MediaQuery.of(context).size.width < 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 16 : 20,
                vertical: isSmallScreen ? 16 : 24,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Hero Section
                  if (!_emailConfirmed)
                    BookStoreHero(
                      icon: Icons.menu_book_rounded,
                      title: t.login,
                      iconSize: isSmallScreen ? 40 : 48,
                    ),
                  // User badge (shown after email confirmation)
                  Builder(
                    builder: (context) {
                      if (!_emailConfirmed) return const SizedBox.shrink();
                      final email = _emailCtrl.text.trim();
                      AccountInfo? acc;
                      try {
                        final id = email.toLowerCase();
                        acc = _accounts.firstWhere((a) => a.id == id);
                      } catch (_) {}
                      final savedName = acc?.name?.trim();
                      final fallbackEmailName = () {
                        final atIndex = email.indexOf('@');
                        if (atIndex > 0) return email.substring(0, atIndex);
                        return email;
                      }();
                      String displayName;
                      if (savedName != null && savedName.isNotEmpty) {
                        displayName = savedName;
                      } else {
                        final lookupName = _lookupName?.trim();
                        if (lookupName != null && lookupName.isNotEmpty) {
                          displayName = lookupName;
                        } else {
                          displayName = fallbackEmailName;
                        }
                      }
                      displayName = displayName.trim();
                      if (displayName.isEmpty) {
                        displayName = fallbackEmailName;
                      }
                      final avatarSource = displayName.isNotEmpty
                          ? displayName
                          : email;
                      final avatarText = avatarSource.isNotEmpty
                          ? avatarSource[0].toUpperCase()
                          : '?';

                      return AnimatedSwitcher(
                        duration: const Duration(milliseconds: 400),
                        child: SizedBox(
                          key: ValueKey(email),
                          width: double.infinity,
                          child: GradientCard(
                            elevation: 2,
                            margin: EdgeInsets.zero,
                            padding: const EdgeInsets.all(24),
                            borderRadius: 16,
                            child: Column(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
                                  ),
                                  child: CircleAvatar(
                                    radius: 36,
                                    backgroundColor:
                                        Theme.of(context).colorScheme.primaryContainer,
                                    child: Text(
                                      avatarText,
                                      style: const TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  displayName,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: Theme.of(context).colorScheme.onPrimaryContainer,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (_emailConfirmed) const SizedBox(height: 16),
                  if (_emailConfirmed) ...[
                    FilledButton.tonalIcon(
                      onPressed: () {
                        setState(() {
                          _emailConfirmed = false;
                          _lookupName = null;
                        });
                        Future.microtask(() => _emailFocus.requestFocus());
                      },
                      icon: const Icon(Icons.swap_horiz, size: 20),
                      label: Text(context.l10n.signInWithAnotherEmail),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 20 : 24),
                  ],
                  // Form
                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        if (_accounts.isNotEmpty && _showAccounts)
                          const SizedBox.shrink()
                        else ...[
                          // Email field (only when not confirmed)
                          if (_emailConfirmed == false)
                            AppFormField(
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
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
                            SizedBox(height: isSmallScreen ? 20 : 24),
                          // Email field (read-only when confirmed)
                          if (_emailConfirmed == true)
                            AppFormField(
                              controller: _emailCtrl,
                              enabled: false,
                              decoration: InputDecoration(
                                labelText: t.email,
                                prefixIcon: const Icon(Icons.alternate_email),
                              ),
                            ),
                          if (_emailConfirmed == true)
                            const SizedBox(height: 16),
                          // Password field
                          if (_emailConfirmed == true)
                            AppFormField(
                              controller: _pwdCtrl,
                              focusNode: _pwdFocus,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
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
                          // Remember password checkbox
                          if (_emailConfirmed == true)
                            SizedBox(height: isSmallScreen ? 16 : 12),
                          if (_emailConfirmed == true)
                            CheckboxListTile(
                              value: _remember,
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              onChanged: _loading
                                  ? null
                                  : (v) => setState(
                                      () => _remember = v ?? false,
                                    ),
                              title: Text(
                                Localizations.localeOf(context).languageCode == 'vi'
                                    ? 'Nhớ mật khẩu'
                                    : 'Remember password',
                              ),
                            ),
                          if (_emailConfirmed == true)
                            SizedBox(height: isSmallScreen ? 20 : 24),
                          if (_emailConfirmed == false) const SizedBox.shrink(),
                          // Primary button (Continue or Login)
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: PrimaryButton.icon(
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
                          ),
                        ],
                        SizedBox(height: isSmallScreen ? 20 : 24),
                        // Register link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(t.noAccount),
                            const SizedBox(width: 4),
                            LinkButton(
                              t.register,
                              onPressed: _loading
                                  ? null
                                  : () => Navigator.of(
                                      context,
                                    ).pushReplacementNamed('/register'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Forgot password link
                        Align(
                          alignment: Alignment.center,
                          child: LinkButton(
                            t.forgotPassword,
                            onPressed: _loading
                                ? null
                                : () => Navigator.of(
                                    context,
                                  ).pushNamed('/forgot'),
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
