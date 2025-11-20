import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/extraction_method.dart';
import 'package:my_flutter_app/models/extraction_options.dart';

class ExtractTextDialog extends StatefulWidget {
  const ExtractTextDialog({super.key});

  @override
  State<ExtractTextDialog> createState() => _ExtractTextDialogState();
}

class _ExtractTextDialogState extends State<ExtractTextDialog> {
  bool _allPages = true;
  final _controller = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? _errorText;
  ExtractionMethod _method = ExtractionMethod.combined;
  String _language = 'eng';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (isMobile) {
      return _buildBottomSheet(context, t, theme);
    } else {
      return _buildDialog(context, t, theme);
    }
  }

  Widget _buildDialog(BuildContext context, AppLocalizations t, ThemeData theme) {
    return AlertDialog(
      title: Text(t.extractTextFromPdf),
      content: SizedBox(
        width: 520,
        child: _buildContent(t, theme),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        ElevatedButton(
          onPressed: _canExtract ? _onExtract : null,
          child: Text(t.extract),
        ),
      ],
    );
  }

  Widget _buildBottomSheet(
    BuildContext context,
    AppLocalizations t,
    ThemeData theme,
  ) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              t.extractTextFromPdf,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            _buildContent(t, theme),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(t.cancel),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: _canExtract ? _onExtract : null,
                  child: Text(t.extract),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(AppLocalizations t, ThemeData theme) {
    final helperStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('📄 ${t.pages}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildPageOptions(t),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            enabled: !_allPages,
            decoration: InputDecoration(
              labelText: t.pageSelection,
              hintText: t.pageSelectionHint,
              helperText: t.pageSelectionHelper,
              helperMaxLines: 2,
              errorText: _errorText,
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.text,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d,\s\-]')),
              LengthLimitingTextInputFormatter(10000),
            ],
            onChanged: (value) {
              setState(() {
                _errorText = _validatePageInput(value);
              });
            },
          ),
          const SizedBox(height: 24),
          Text('🔍 ${t.extractionMethod}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          _buildMethodOption(t, ExtractionMethod.text),
          _buildMethodOption(t, ExtractionMethod.ocr),
          _buildMethodOption(t, ExtractionMethod.combined),
          const SizedBox(height: 24),
          Text('🌐 ${t.ocrLanguage}', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          IgnorePointer(
            ignoring: !_languageEnabled,
            child: Opacity(
              opacity: _languageEnabled ? 1 : 0.5,
              child: DropdownButtonFormField<String>(
                value: _language,
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _language = value);
                },
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  helperText: t.languageForOcr,
                  helperMaxLines: 2,
                  helperStyle: helperStyle,
                ),
                items: [
                  DropdownMenuItem(
                    value: 'eng',
                    child: Text(t.englishLanguage),
                  ),
                  DropdownMenuItem(
                    value: 'vie',
                    child: Text(t.vietnameseLanguage),
                  ),
                  DropdownMenuItem(
                    value: 'eng+vie',
                    child: Text(t.englishVietnamese),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPageOptions(AppLocalizations t) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              _allPages = true;
              _errorText = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: _allPages,
                  onChanged: (value) {
                    setState(() {
                      _allPages = value ?? true;
                      _errorText = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(t.allPages),
              ],
            ),
          ),
        ),
        InkWell(
          onTap: () {
            setState(() {
              _allPages = false;
              _errorText = null;
            });
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              children: [
                Radio<bool>(
                  value: false,
                  groupValue: _allPages,
                  onChanged: (value) {
                    setState(() {
                      _allPages = value == true ? false : true;
                      _errorText = null;
                    });
                  },
                ),
                const SizedBox(width: 8),
                Text(t.specificPages),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMethodOption(AppLocalizations t, ExtractionMethod method) {
    final theme = Theme.of(context);
    final isSelected = _method == method;
    final tooltip = method.getTooltip(context);
    final icon = method.getIcon();
    final titleStyle = theme.textTheme.bodyLarge?.copyWith(
      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
    );

    Widget label;
    if (method == ExtractionMethod.combined) {
      label = Row(
        children: [
          Expanded(
            child: Text(
              method.getDisplayName(context),
              style: titleStyle,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              t.recommended,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    } else {
      label = Text(
        method.getDisplayName(context),
        style: titleStyle,
      );
    }

    return InkWell(
      onTap: () => _onMethodChanged(method),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Radio<ExtractionMethod>(
              value: method,
              groupValue: _method,
              onChanged: (value) {
                if (value != null) {
                  _onMethodChanged(value);
                }
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 20, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Expanded(child: label),
                      Tooltip(
                        message: tooltip,
                        preferBelow: false,
                        child: const Padding(
                          padding: EdgeInsets.only(left: 8, top: 2),
                          child: Icon(Icons.info_outline, size: 18),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tooltip,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _languageEnabled => _method != ExtractionMethod.text;

  bool get _canExtract {
    if (_allPages) return true;
    final input = _controller.text.trim();
    if (input.isEmpty) return false;
    return _validatePageInput(input) == null;
  }

  String? _validatePageInput(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null;
    }

    final allowedPattern = RegExp(r'^[\d,\s\-]+$');
    if (!allowedPattern.hasMatch(value)) {
      return context.l10n.pageInputInvalid;
    }

    return null;
  }

  void _onMethodChanged(ExtractionMethod method) {
    setState(() {
      _method = method;
      if (!_languageEnabled) {
        _language = 'eng';
      }
    });
  }

  void _onExtract() {
    if (!_allPages) {
      final pages = _controller.text.trim();
      if (pages.isEmpty || _validatePageInput(pages) != null) {
        setState(() {
          _errorText = _validatePageInput(pages);
        });
        return;
      }
    }

    final options = ExtractionOptions(
      allPages: _allPages,
      pageSelection: _controller.text.trim(),
      method: _method,
      languageCode: _language,
    );
    Navigator.of(context).pop(options);
  }
}

Future<ExtractionOptions?> showExtractTextDialog(BuildContext context) async {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  if (isMobile) {
    return showModalBottomSheet<ExtractionOptions>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ExtractTextDialog(),
    );
  } else {
    return showDialog<ExtractionOptions>(
      context: context,
      builder: (context) => const ExtractTextDialog(),
    );
  }
}
