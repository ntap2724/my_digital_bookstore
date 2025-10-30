class ExtractedText {
  final String text;
  final int totalPages;
  final List<int> extractedPages;
  final int pageCount;

  ExtractedText({
    required this.text,
    required this.totalPages,
    required this.extractedPages,
    required this.pageCount,
  });

  factory ExtractedText.fromJson(Map<String, dynamic> json) {
    return ExtractedText(
      text: json['text'] as String? ?? '',
      totalPages: (json['total_pages'] as num?)?.toInt() ?? 0,
      extractedPages: (json['extracted_pages'] as List<dynamic>?)
              ?.map((e) => (e as num).toInt())
              .toList() ??
          [],
      pageCount: (json['page_count'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'text': text,
      'total_pages': totalPages,
      'extracted_pages': extractedPages,
      'page_count': pageCount,
    };
  }
}
