class ExtractedText {
  final String text;
  final int totalPages;
  final List<int> extractedPages;
  final int pageCount;
  final String? methodUsed;
  final ExtractionDetails? extractionDetails;
  final double? processingTimeSeconds;

  ExtractedText({
    required this.text,
    required this.totalPages,
    required this.extractedPages,
    required this.pageCount,
    this.methodUsed,
    this.extractionDetails,
    this.processingTimeSeconds,
  });

  factory ExtractedText.fromJson(Map<String, dynamic> json) {
    ExtractionDetails? details;
    final detailsJson = json['extraction_details'];
    if (detailsJson is Map<String, dynamic>) {
      details = ExtractionDetails.fromJson(detailsJson);
    }

    return ExtractedText(
      text: json['text'] as String? ?? '',
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
      extractedPages: (json['extracted_pages'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
      methodUsed: json['method_used'] as String?,
      extractionDetails: details,
      processingTimeSeconds: (json['processing_time_seconds'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'total_pages': totalPages,
      'extracted_pages': extractedPages,
      'page_count': pageCount,
      if (methodUsed != null) 'method_used': methodUsed,
      if (extractionDetails != null) 'extraction_details': extractionDetails!.toJson(),
      if (processingTimeSeconds != null) 'processing_time_seconds': processingTimeSeconds,
    };
  }
}

class ExtractionDetails {
  final int embeddedTextPages;
  final int ocrPages;
  final int failedPages;

  ExtractionDetails({
    required this.embeddedTextPages,
    required this.ocrPages,
    required this.failedPages,
  });

  factory ExtractionDetails.fromJson(Map<String, dynamic> json) {
    return ExtractionDetails(
      embeddedTextPages: (json['embedded_text_pages'] as num?)?.toInt() ?? 0,
      ocrPages: (json['ocr_pages'] as num?)?.toInt() ?? 0,
      failedPages: (json['failed_pages'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'embedded_text_pages': embeddedTextPages,
      'ocr_pages': ocrPages,
      'failed_pages': failedPages,
    };
  }
}
