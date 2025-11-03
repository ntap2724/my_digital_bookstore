import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';

enum ExtractionMethod {
  text,
  ocr,
  combined;

  String toApiValue() {
    switch (this) {
      case ExtractionMethod.text:
        return 'text';
      case ExtractionMethod.ocr:
        return 'ocr';
      case ExtractionMethod.combined:
        return 'combined';
    }
  }

  String getDisplayName(BuildContext context) {
    final t = context.l10n;
    switch (this) {
      case ExtractionMethod.text:
        return t.fastTextExtraction;
      case ExtractionMethod.ocr:
        return t.ocrScan;
      case ExtractionMethod.combined:
        return t.smartExtraction;
    }
  }

  String getTooltip(BuildContext context) {
    final t = context.l10n;
    switch (this) {
      case ExtractionMethod.text:
        return t.fastTextTooltip;
      case ExtractionMethod.ocr:
        return t.ocrTooltip;
      case ExtractionMethod.combined:
        return t.smartTooltip;
    }
  }

  IconData getIcon() {
    switch (this) {
      case ExtractionMethod.text:
        return Icons.text_snippet;
      case ExtractionMethod.ocr:
        return Icons.document_scanner;
      case ExtractionMethod.combined:
        return Icons.auto_awesome;
    }
  }
}
