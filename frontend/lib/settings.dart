import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/settings_service.dart';
import 'package:my_flutter_app/widgets/primary_button.dart';
import 'package:my_flutter_app/widgets/responsive_navigation_wrapper.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _language = 'vi';
  bool _darkMode = false;
  int _colorIndex = 0; // 0..3
  String _fontSize = 'normal';
  bool _loggedIn = false;
  bool _isAdmin = false;

  List<Color> get _colors => SettingsController.palette;

  @override
  void initState() {
    super.initState();
    final s = SettingsController.instance;
    _language = s.language;
    _darkMode = s.darkMode;
    _colorIndex = s.colorIndex;
    _fontSize = s.fontSize;
    _checkLoggedIn();
  }

  Future<void> _checkLoggedIn() async {
    final token = await AuthService.instance.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      setState(() {
        _loggedIn = false;
        _isAdmin = false;
      });
      return;
    }
    try {
      final me = await AuthService.instance.me();
      if (!mounted) return;
      final role = me?['role']?.toString().toLowerCase();
      setState(() {
        _loggedIn = true;
        _isAdmin = role == 'admin';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loggedIn = true;
        _isAdmin = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final divider = Divider(color: Theme.of(context).dividerColor);
    return ResponsiveNavigationWrapper(
      currentRoute: '/settings',
      appBar: AppBar(
        title: Text(t.settings),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.mic),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          _rowHeader(
            label: t.language,
            trailing: DropdownButton<String>(
              value: _language,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: 'vi', child: Text(t.vietnamese)),
                DropdownMenuItem(value: 'en', child: Text(t.english)),
              ],
              onChanged: (v) async {
                final value = v ?? 'vi';
                setState(() => _language = value);
                await SettingsController.instance.setLanguage(value);
              },
            ),
          ),
          divider,
          _rowHeader(
            label: t.darkMode,
            trailing: Switch(
              value: _darkMode,
              onChanged: (v) async {
                setState(() => _darkMode = v);
                await SettingsController.instance.setDarkMode(v);
              },
            ),
          ),
          divider,
          _rowHeader(
            label: t.color,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_colors.length, (i) => _colorDot(i)),
            ),
          ),
          divider,
          _rowHeader(
            label: t.fontSize,
            trailing: DropdownButton<String>(
              value: _fontSize,
              underline: const SizedBox.shrink(),
              items: [
                DropdownMenuItem(value: 'small', child: Text(t.fontSmall)),
                DropdownMenuItem(value: 'normal', child: Text(t.fontNormal)),
                DropdownMenuItem(value: 'large', child: Text(t.fontLarge)),
              ],
              onChanged: (v) async {
                final value = v ?? 'normal';
                setState(() => _fontSize = value);
                await SettingsController.instance.setFontSize(value);
              },
            ),
          ),
          if (_loggedIn) ...[
            const SizedBox(height: 16),
            PrimaryButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/update-profile');
              },
              child: Text(t.changeInfoTitle),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              onPressed: () {
                Navigator.of(context).pushNamed('/change-password');
              },
              child: Text(t.changePassword),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              onPressed: _isAdmin
                  ? null
                  : () async {
                      final ctx = context;
                      final ok = await showDialog<bool>(
                        context: ctx,
                        builder: (dctx) => AlertDialog(
                          title: Text(t.deleteAccount),
                          content: Text(t.deleteAccountWarning),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(dctx).pop(false),
                              child: Text(t.cancel),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red.shade600,
                                foregroundColor: Colors.white,
                                elevation: 0,
                              ),
                              onPressed: () => Navigator.of(dctx).pop(true),
                              child: Text(t.deleteAccount),
                            ),
                          ],
                        ),
                      );
                      if (ok != true) return;
                      final success = await AuthService.instance
                          .deleteAccountPermanently();
                      if (!ctx.mounted) return;
                      if (success) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(t.deleteAccountSuccess)),
                        );
                        Navigator.of(
                          ctx,
                        ).pushNamedAndRemoveUntil('/login', (r) => false);
                      } else {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(t.deleteAccountFailed)),
                        );
                      }
                    },
              child: Text(t.deleteAccount),
            ),
            if (_isAdmin)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  t.userDeleteDisabled,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
                ),
              ),
          ],
          const SizedBox(height: 16),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.tosShort),
            trailing: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/terms');
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(t.view),
            ),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(t.privacyShort),
            trailing: TextButton.icon(
              onPressed: () {
                Navigator.of(context).pushNamed('/privacy');
              },
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(t.view),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _rowHeader({required String label, required Widget trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          trailing,
        ],
      ),
    );
  }

  Widget _colorDot(int i) {
    final selected = _colorIndex == i;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: InkWell(
        onTap: () async {
          setState(() => _colorIndex = i);
          await SettingsController.instance.setColorIndex(i);
        },
        customBorder: const CircleBorder(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: selected ? 30 : 24,
          height: selected ? 30 : 24,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _colors[i],
            border: Border.all(
              color: selected ? Colors.black26 : Colors.black12,
              width: selected ? 2 : 1,
            ),
          ),
          child: selected
              ? const Icon(Icons.check, size: 16, color: Colors.white)
              : null,
        ),
      ),
    );
  }
}
