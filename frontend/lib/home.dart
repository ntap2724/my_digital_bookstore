import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/widgets/primary_button.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    // Listen for auth/profile changes to auto-refresh UI
    AuthService.instance.addListener(_onAuthChanged);
  }

  void _onAuthChanged() {
    if (!mounted || _loading) return;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final me = await AuthService.instance.me();
      setState(() => _user = me == null ? null : _normalizeUser(me));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    AuthService.instance.removeListener(_onAuthChanged);
    super.dispose();
  }

  Map<String, dynamic> _normalizeUser(Map<String, dynamic> u) {
    final copy = Map<String, dynamic>.from(u);
    final g = u['gender']?.toString();
    if (g != null) {
      copy['gender'] = _normGender(g);
    }
    return copy;
  }

  String _normGender(String g) {
    final s = g.trim().toLowerCase();
    if (s == 'male' || s == 'm' || s == 'nam' || s.startsWith('nam')) return 'male';
    if (s == 'female' || s == 'f' || s == 'nu' || s == 'nữ' || s == 'nữ' || s.startsWith('nữ')) return 'female';
    if (s == 'other' || s == 'khac' || s == 'khác') return 'other';
    return 'other';
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/accounts', (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(
        title: Text(t.home),
        actions: [
          IconButton(
            tooltip: t.refresh,
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red),
                    const SizedBox(height: 8),
                    Text(
                      '${t.errorLoadingInfo}:\n$_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                        PrimaryButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: Text(t.retry),
                        ),
                  ],
                ),
              )
            : _user == null
            ? Center(child: Text(t.noUserData))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.helloUser(_user!['name']?.toString() ?? 'User'),
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 6),
                  Text(t.emailLabel(_user!['email']?.toString() ?? '-')),
                  const SizedBox(height: 20),
                  Text(
                    t.rawData,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text(
                        const JsonEncoder.withIndent('  ').convert(_user),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildDrawer() {
    final t = context.l10n;
    final name = _user?['name']?.toString() ?? 'User';
    final email = _user?['email']?.toString() ?? '';
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text(name),
              accountEmail: Text(email),
              currentAccountPicture: const CircleAvatar(
                child: Icon(Icons.person),
              ),
              margin: EdgeInsets.zero,
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  ListTile(
                    leading: const Icon(Icons.home_outlined),
                    title: Text(t.home),
                  ),
                  ListTile(
                    leading: const Icon(Icons.switch_account_outlined),
                    title: Text(t.switchAccount),
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).pushNamed('/accounts');
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(t.drawerSettings),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed('/settings');
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(t.drawerLogout),
              onTap: () {
                Navigator.of(context).pop();
                _logout();
              },
            ),
          ],
        ),
      ),
    );
  }
}
