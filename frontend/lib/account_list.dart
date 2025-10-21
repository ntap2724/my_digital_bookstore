import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/primary_button.dart';
import 'package:my_flutter_app/widgets/responsive_navigation_wrapper.dart';

class AccountListPage extends StatefulWidget {
  const AccountListPage({super.key});

  @override
  State<AccountListPage> createState() => _AccountListPageState();
}

class _AccountListPageState extends State<AccountListPage> {
  List<AccountInfo> _accounts = const [];
  String? _activeId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final accounts = await AuthService.instance.getAccounts();
      final activeId = await AuthService.instance.getCurrentActiveId();
      if (!mounted) return;
      setState(() {
        _accounts = accounts;
        _activeId = activeId;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _switchTo(String id, String email) async {
    // Determine if this account has a saved token (Remember password)
    final acc = _accounts.firstWhere(
      (a) => a.id == id,
      orElse: () => AccountInfo(id: id, email: email, token: ''),
    );
    if (acc.token.isNotEmpty) {
      // Has token: activate and go home
      await AuthService.instance.setActiveAccount(id);
      if (!mounted) return;
      final switchMessage = context.l10n.switchAccountSuccess(email);
      final shouldToast = await AuthService.instance.isLoggedIn();
      if (!mounted) return;
      if (shouldToast &&
          switchMessage.trim().isNotEmpty &&
          switchMessage != 'switchAccountSuccess') {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(switchMessage)));
      }
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      return;
    }
    // No token saved: clear current active session and go to login for password
    await AuthService.instance.logout();
    if (!mounted) return;
    setState(() => _activeId = null);
    Navigator.of(context).pushNamedAndRemoveUntil(
      '/login',
      (r) => false,
      arguments: {'email': email},
    );
  }

  Future<void> _remove(String id, String email) async {
    final t = context.l10n;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.confirmRemoveTitle),
        content: Text(t.confirmRemoveMessage(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.remove),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final active = await AuthService.instance.getActiveAccount();
    if (active?.id == id) {
      await AuthService.instance.logout();
      final remaining = await AuthService.instance.getAccounts();
      if (!mounted) return;
      if (remaining.isEmpty) {
        Navigator.of(context).pushNamedAndRemoveUntil('/login', (r) => false);
      } else {
        Navigator.of(context).pushNamedAndRemoveUntil('/home', (r) => false);
      }
    } else {
      await AuthService.instance.removeAccount(id);
      if (!mounted) return;
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return ResponsiveNavigationWrapper(
      currentRoute: '/accounts',
      appBar: AppBar(
        title: Text(t.manageAccounts),
        automaticallyImplyLeading: false,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _accounts.isEmpty
          ? Center(child: Text(t.noAccounts))
          : ListView.separated(
              itemBuilder: (context, index) {
                final a = _accounts[index];
                final isActive = a.id == _activeId;
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(
                      (a.name?.isNotEmpty == true
                              ? a.name!.trim()[0]
                              : a.email.trim()[0])
                          .toUpperCase(),
                    ),
                  ),
                  title: Text(a.name?.isNotEmpty == true ? a.name! : a.email),
                  subtitle: a.name?.isNotEmpty == true ? Text(a.email) : null,
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isActive)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            t.active,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      if (!isActive) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: t.remove,
                          onPressed: () => _remove(a.id, a.email),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ],
                  ),
                  onTap: isActive ? null : () => _switchTo(a.id, a.email),
                );
              },
              separatorBuilder: (_, index) => const Divider(height: 1),
              itemCount: _accounts.length,
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: PrimaryButton.icon(
            onPressed: () async {
              // Show confirmation dialog only if currently logged in
              final token = await AuthService.instance.getToken();
              if (!context.mounted) return;

              var shouldProceed = true;
              if (token != null && token.isNotEmpty) {
                final t2 = context.l10n;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: Text(t2.addAccount),
                    content: Text(t2.confirmLogoutMessage),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: Text(t2.cancel),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(t2.continueAction),
                      ),
                    ],
                  ),
                );
                if (ok != true) shouldProceed = false;
                if (!context.mounted) return;
                if (shouldProceed) {
                  await AuthService.instance.logout();
                  if (!context.mounted) return;
                }
              }

              if (!context.mounted || !shouldProceed) return;
              Navigator.of(
                context,
              ).pushNamedAndRemoveUntil('/login', (r) => false);
            },
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: Text(t.addAccount),
          ),
        ),
      ),
    );
  }
}
