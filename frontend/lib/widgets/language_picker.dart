import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/services/settings_service.dart';

class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final settings = SettingsController.instance;
    return AnimatedBuilder(
      animation: settings,
      builder: (context, _) {
        return DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            value: settings.language,
            alignment: Alignment.centerRight,
            icon: const Icon(Icons.language),
            items: [
              DropdownMenuItem(value: 'vi', child: Text(t.vietnamese)),
              DropdownMenuItem(value: 'en', child: Text(t.english)),
            ],
            onChanged: (v) {
              if (v == null) return;
              settings.setLanguage(v);
            },
          ),
        );
      },
    );
  }
}
