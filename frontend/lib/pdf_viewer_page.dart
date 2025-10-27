import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/services/catalog_service.dart';
import 'package:my_flutter_app/services/pdf_service.dart';

class PdfViewerPage extends StatefulWidget {
  final Book book;

  const PdfViewerPage({super.key, required this.book});

  static const routeName = '/pdf-viewer';

  @override
  State<PdfViewerPage> createState() => _PdfViewerPageState();
}

class _PdfViewerPageState extends State<PdfViewerPage> {
  final PdfService _pdfService = PdfService.instance;
  final CatalogService _catalogService = CatalogService.instance;

  String? _pdfPath;
  bool _loading = true;
  String? _error;
  double _downloadProgress = 0.0;

  int _currentPage = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _downloadAndLoadPdf();
  }

  Future<void> _downloadAndLoadPdf() async {
    setState(() {
      _loading = true;
      _error = null;
      _downloadProgress = 0.0;
    });

    try {
      final path = await _pdfService.downloadBookPdf(
        widget.book.id,
        onProgress: (progress) {
          if (mounted) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
      );

      if (mounted) {
        setState(() {
          _pdfPath = path;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _openAskDialog() {
    final t = context.l10n;
    final questionController = TextEditingController();
    bool submitting = false;
    String? answer;
    String? error;

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              Future<void> submit() async {
                final question = questionController.text.trim();
                if (question.isEmpty || submitting) return;
                setModalState(() {
                  submitting = true;
                  answer = null;
                  error = null;
                });
                try {
                  final result = await _catalogService.askBookQuestion(
                    widget.book.id,
                    question,
                  );
                  setModalState(() {
                    answer = result;
                  });
                } catch (e) {
                  setModalState(() {
                    error = e.toString();
                  });
                } finally {
                  setModalState(() {
                    submitting = false;
                  });
                }
              }

              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      t.askBookTitle,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: questionController,
                      maxLines: 4,
                      minLines: 2,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: t.askBookPromptLabel,
                        hintText: t.askBookPlaceholder,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (submitting) ...[
                      Row(
                        children: [
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(t.askBookGenerating),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ] else ...[
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: Text(t.cancel),
                          ),
                          const SizedBox(width: 12),
                          FilledButton(
                            onPressed: submit,
                            child: Text(t.askBookSubmit),
                          ),
                        ],
                      ),
                    ],
                    if (answer != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        t.askBookAnswerHeading,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.all(16),
                        child: SelectableText(answer!),
                      ),
                    ],
                    if (error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        error ?? t.askBookErrorGeneric,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    ).whenComplete(questionController.dispose);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.book.title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: t.askBookTitle,
            onPressed: _openAskDialog,
            icon: const Icon(Icons.question_answer_outlined),
          ),
          if (_totalPages > 0)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  '$_currentPage / $_totalPages',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
        ],
      ),
      body: _buildBody(t),
    );
  }

  Widget _buildBody(AppLocalizations t) {
    if (_loading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              _downloadProgress > 0
                  ? '${(_downloadProgress * 100).toStringAsFixed(0)}%'
                  : t.downloadingPdf,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (widget.book.pdfFileSize != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.book.formattedFileSize,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                'Error',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _downloadAndLoadPdf,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    if (_pdfPath == null) {
      return Center(
        child: Text(t.pdfNotAvailable),
      );
    }

    return PDFView(
      filePath: _pdfPath!,
      enableSwipe: true,
      swipeHorizontal: false,
      autoSpacing: true,
      pageFling: true,
      pageSnap: true,
      defaultPage: _currentPage,
      fitPolicy: FitPolicy.BOTH,
      preventLinkNavigation: false,
      onRender: (pages) {
        if (mounted) {
          setState(() {
            _totalPages = pages ?? 0;
          });
        }
      },
      onViewCreated: (PDFViewController controller) {
        // PDF controller ready
      },
      onPageChanged: (int? page, int? total) {
        if (mounted) {
          setState(() {
            _currentPage = (page ?? 0) + 1;
            _totalPages = total ?? 0;
          });
        }
      },
      onError: (error) {
        if (mounted) {
          setState(() {
            _error = error.toString();
          });
        }
      },
    );
  }
}




