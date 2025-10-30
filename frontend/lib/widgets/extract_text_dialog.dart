import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';

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
      // Show bottom sheet on mobile
      return _buildBottomSheet(context, t, theme);
    } else {
      // Show dialog on tablet/desktop
      return _buildDialog(context, t, theme);
    }
  }

  Widget _buildDialog(BuildContext context, AppLocalizations t, ThemeData theme) {
    return AlertDialog(
      title: Text(t.extractTextFromPdf),
      content: SizedBox(
        width: 400,
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

  Widget _buildBottomSheet(BuildContext context, AppLocalizations t, ThemeData theme) {
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
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // All pages option
          InkWell(
            onTap: () {
              setState(() {
                _allPages = true;
                _errorText = null;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
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
          // Specific pages option
          InkWell(
            onTap: () {
              setState(() {
                _allPages = false;
                _errorText = null;
              });
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Radio<bool>(
                    value: false,
                    groupValue: _allPages,
                    onChanged: (value) {
                      setState(() {
                        _allPages = value ?? true;
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
          // Text field for page selection
          if (!_allPages) ...[
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
          ],
        ],
      ),
    );
  }

  bool get _canExtract {
    if (_allPages) return true;
    final input = _controller.text.trim();
    if (input.isEmpty) return false;
    return _validatePageInput(input) == null;
  }

  String? _validatePageInput(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Empty is valid (means all pages)
    }

    // Check for allowed characters only
    final allowedPattern = RegExp(r'^[\d,\s\-]+$');
    if (!allowedPattern.hasMatch(value)) {
      return context.l10n.pageInputInvalid;
    }

    return null; // Valid format, backend will do detailed validation
  }

  void _onExtract() {
    if (_allPages) {
      Navigator.of(context).pop(''); // Return empty string for all pages
    } else {
      final pages = _controller.text.trim();
      if (pages.isEmpty || _validatePageInput(pages) != null) {
        return;
      }
      Navigator.of(context).pop(pages);
    }
  }
}

/// Show the extract text dialog/bottom sheet
/// Returns the page selection string or null if cancelled
Future<String?> showExtractTextDialog(BuildContext context) async {
  final screenWidth = MediaQuery.of(context).size.width;
  final isMobile = screenWidth < 600;

  if (isMobile) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => const ExtractTextDialog(),
    );
  } else {
    return showDialog<String>(
      context: context,
      builder: (context) => const ExtractTextDialog(),
    );
  }
}
