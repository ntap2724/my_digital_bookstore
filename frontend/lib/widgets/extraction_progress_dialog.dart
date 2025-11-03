import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/extraction_method.dart';

class ExtractionProgressDialog extends StatefulWidget {
  const ExtractionProgressDialog({
    super.key,
    required this.method,
    required this.pageCount,
    this.pages,
  });

  final ExtractionMethod method;
  final int pageCount;
  final String? pages;

  @override
  State<ExtractionProgressDialog> createState() => _ExtractionProgressDialogState();
}

class _ExtractionProgressDialogState extends State<ExtractionProgressDialog> {
  late final int _targetPages;
  late final double _secondsPerPage;
  late final Duration _estimatedDuration;
  late final DateTime _start;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _targetPages = _estimatePages();
    _secondsPerPage = _secondsForMethod(widget.method);
    final estimatedSeconds = math.max(5, (_targetPages * _secondsPerPage).round());
    _estimatedDuration = Duration(seconds: estimatedSeconds);
    _start = DateTime.now();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _elapsed = DateTime.now().difference(_start);
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final methodLabel = widget.method.getDisplayName(context);
    final pagesDisplay = widget.pages?.trim().isNotEmpty == true
        ? widget.pages!.trim()
        : t.allPages;
    final pageCountLabel = t.pageCountLabel(_targetPages.toString());
    final progressValue = _progressValue;
    final processedPages = _processedPages;
    final remainingPages = math.max(0, _targetPages - processedPages);
    final embeddedPages = _embeddedTextPages(processedPages);
    final ocrPages = _ocrPages(processedPages);
    final percent = progressValue != null ? (progressValue * 100).clamp(0, 99) : null;
    final statusText = progressValue != null
        ? '${percent!.toStringAsFixed(0)}%'
        : t.extractingText;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(t.extractingTextProgress),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.methodUsed(methodLabel)),
            const SizedBox(height: 4),
            Text('${t.pages}: $pagesDisplay • $pageCountLabel'),
            const SizedBox(height: 16),
            LinearProgressIndicator(value: progressValue),
            const SizedBox(height: 8),
            Text(statusText),
            const SizedBox(height: 4),
            Text(
              t.processingPage(
                math.min(_targetPages, math.max(1, processedPages + 1)).toString(),
                _targetPages.toString(),
              ),
            ),
            if (progressValue != null && progressValue >= 0.9) ...[
              const SizedBox(height: 4),
              Text(
                t.almostDone,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
            const SizedBox(height: 16),
            Text(t.embeddedTextPages(embeddedPages.toString())),
            Text(t.ocrPages(ocrPages.toString())),
            Text(t.remainingPages(remainingPages.toString())),
            const SizedBox(height: 12),
            Text(
              t.estimatedTime(_estimatedDuration.inSeconds.toString()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  double _secondsForMethod(ExtractionMethod method) {
    switch (method) {
      case ExtractionMethod.text:
        return 1;
      case ExtractionMethod.ocr:
        return 7;
      case ExtractionMethod.combined:
        return 3;
    }
  }

  int _estimatePages() {
    if (widget.pages == null || widget.pages!.trim().isEmpty) {
      return widget.pageCount > 0 ? widget.pageCount : 25;
    }
    final tokens = widget.pages!.split(',');
    final pages = <int>{};
    for (final raw in tokens) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      if (part.contains('-')) {
        final range = part.split('-');
        if (range.length != 2) continue;
        final start = int.tryParse(range.first.trim());
        final end = int.tryParse(range.last.trim());
        if (start == null || end == null) continue;
        final low = math.min(start, end);
        final high = math.max(start, end);
        if (high - low > 500) {
          continue;
        }
        for (var i = low; i <= high; i++) {
          pages.add(i);
        }
      } else {
        final page = int.tryParse(part);
        if (page != null) {
          pages.add(page);
        }
      }
    }
    if (pages.isEmpty) {
      return 10;
    }
    return pages.length;
  }

  double? get _progressValue {
    final totalMs = _estimatedDuration.inMilliseconds;
    if (totalMs <= 0) return null;
    if (_elapsed.inSeconds <= 1) return null;
    final ratio = _elapsed.inMilliseconds / totalMs;
    if (ratio >= 0.98) {
      return 0.98;
    }
    return ratio.clamp(0.0, 0.98);
  }

  int get _processedPages {
    if (_secondsPerPage <= 0) return 0;
    final processed = (_elapsed.inSeconds / _secondsPerPage).floor();
    return math.min(_targetPages, math.max(0, processed));
  }

  int _embeddedTextPages(int processed) {
    switch (widget.method) {
      case ExtractionMethod.text:
        return processed;
      case ExtractionMethod.ocr:
        return 0;
      case ExtractionMethod.combined:
        return math.min(processed, (processed * 0.6).round());
    }
  }

  int _ocrPages(int processed) {
    switch (widget.method) {
      case ExtractionMethod.text:
        return 0;
      case ExtractionMethod.ocr:
        return processed;
      case ExtractionMethod.combined:
        final embedded = _embeddedTextPages(processed);
        return math.max(0, processed - embedded);
    }
  }
}
