import 'package:my_flutter_app/models/extraction_method.dart';

class ExtractionOptions {
  const ExtractionOptions({
    required this.allPages,
    this.pageSelection,
    required this.method,
    required this.languageCode,
  });

  final bool allPages;
  final String? pageSelection;
  final ExtractionMethod method;
  final String languageCode;

  String? get pagesForApi {
    if (allPages) return null;
    final trimmed = pageSelection?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
