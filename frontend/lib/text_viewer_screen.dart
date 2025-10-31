import 'dart:io' show File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/extracted_text.dart';
import 'package:my_flutter_app/services/settings_service.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

class TextViewerScreen extends StatefulWidget {
  const TextViewerScreen({
    super.key,
    required this.extractedText,
    required this.bookTitle,
  });

  final ExtractedText extractedText;
  final String bookTitle;

  static const routeName = '/text-viewer';

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  bool _showMetadata = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final settings = SettingsController.instance;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.extractedTextTitle),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: t.copyToClipboard,
            onPressed: _copyToClipboard,
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.download),
              tooltip: t.saveAsFile,
              onPressed: _saveAsFile,
            ),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Metadata card
          if (_showMetadata)
            Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            t.extractionMetadata,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          iconSize: 20,
                          onPressed: () {
                            setState(() {
                              _showMetadata = false;
                            });
                          },
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      t.totalPagesLabel(widget.extractedText.totalPages.toString()),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.extractedPagesLabel(
                        _formatExtractedPages(widget.extractedText.extractedPages),
                      ),
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      t.pageCountLabel(widget.extractedText.pageCount.toString()),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          // Text content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                widget.extractedText.text.isNotEmpty
                    ? widget.extractedText.text
                    : t.noTextExtracted,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontFamily: 'monospace',
                  height: 1.5,
                  fontSize: 14 * settings.fontScale,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatExtractedPages(List<int> pages) {
    if (pages.isEmpty) return '';
    if (pages.length <= 10) {
      return pages.join(', ');
    }
    // Show first 10 and indicate more
    final first10 = pages.take(10).join(', ');
    return '$first10... (+${pages.length - 10} more)';
  }

  Future<void> _copyToClipboard() async {
    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);
    final t = context.l10n;
    try {
      await Clipboard.setData(
        ClipboardData(text: widget.extractedText.text),
      );
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white),
              const SizedBox(width: 8),
              Text(t.copiedToClipboard),
            ],
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(t.failedToCopy),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    }
  }

  Future<void> _saveAsFile() async {
    final t = context.l10n;
    if (_saving) return;

    setState(() {
      _saving = true;
    });

    final messenger = ScaffoldMessenger.of(context);
    final theme = Theme.of(context);

    try {
      if (kIsWeb) {
        await _saveAsFileWeb();
      } else {
        await _saveAsFileNative();
      }
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text('${t.failedToSave}: $e'),
          backgroundColor: theme.colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  Future<void> _saveAsFileWeb() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final filename = _sanitizeFilename(widget.bookTitle);
    
    // Create a blob and trigger download
    final bytes = widget.extractedText.text.codeUnits;
    final blob = html.Blob([bytes], 'text/plain');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', '${filename}_extracted.txt')
      ..click();
    html.Url.revokeObjectUrl(url);

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(t.downloadStarted),
      ),
    );
  }

  Future<void> _saveAsFileNative() async {
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final filename = _sanitizeFilename(widget.bookTitle);
    
    // Get documents directory
    final directory = await getApplicationDocumentsDirectory();
    final filePath = '${directory.path}/${filename}_extracted.txt';
    final file = File(filePath);
    
    // Write text to file
    await file.writeAsString(widget.extractedText.text);

    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('${t.savedTo}: $filePath'),
        duration: const Duration(seconds: 4),
        action: Platform.isAndroid || Platform.isIOS
            ? null
            : SnackBarAction(
                label: t.ok,
                onPressed: () {},
              ),
      ),
    );
  }

  String _sanitizeFilename(String name) {
    // Remove or replace invalid filename characters
    return name
        .replaceAll(RegExp(r'[<>:"/\\|?*]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .trim();
  }
}
