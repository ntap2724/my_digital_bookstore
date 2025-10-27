import 'package:my_flutter_app/config.dart';
import 'package:my_flutter_app/models/author.dart';
import 'package:my_flutter_app/models/category.dart';

class Book {
  final int id;
  final String title;
  final String slug;
  final String? subtitle;
  final String? description;
  final int creditPrice;
  final int availableCopies;
  final bool owned;
  final String? isbn;
  final String? language;
  final String? coverImageUrl;
  final String? pdfFilename;
  final int? pdfFileSize;
  final int? pdfPageCount;
  final DateTime? publishedAt;
  final String status;
  final Category? category;
  final List<Author> authors;
  final double averageRating;

  const Book({
    required this.id,
    required this.title,
    required this.slug,
    this.subtitle,
    this.description,
    required this.creditPrice,
    required this.availableCopies,
    this.owned = false,
    this.isbn,
    this.language,
    this.coverImageUrl,
    this.pdfFilename,
    this.pdfFileSize,
    this.pdfPageCount,
    this.publishedAt,
    required this.status,
    this.category,
    this.authors = const [],
    this.averageRating = 0.0,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    final categoryJson = json['category'];
    final authorsJson = json['authors'];
    DateTime? publishedAt;
    final publishedRaw = json['published_at']?.toString();
    if (publishedRaw != null && publishedRaw.isNotEmpty) {
      try {
        publishedAt = DateTime.parse(publishedRaw);
      } catch (_) {}
    }

    bool parseOwned(dynamic value) {
      if (value is bool) {
        return value;
      }
      if (value is num) {
        return value != 0;
      }
      if (value is String) {
        final normalized = value.trim().toLowerCase();
        return normalized == 'true' || normalized == '1';
      }
      return false;
    }

    return Book(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      creditPrice: (json['credit_price'] as num?)?.toInt() ?? 0,
      availableCopies: (json['available_copies'] as num?)?.toInt() ?? 0,
      isbn: json['isbn']?.toString(),
      language: json['language']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString(),
      pdfFilename: json['pdf_filename']?.toString(),
      pdfFileSize: (json['pdf_file_size'] as num?)?.toInt(),
      pdfPageCount: (json['pdf_page_count'] as num?)?.toInt(),
      publishedAt: publishedAt,
      status: json['status']?.toString() ?? 'draft',
      category: categoryJson is Map<String, dynamic>
          ? Category.fromJson(categoryJson)
          : null,
      authors: authorsJson is List
          ? authorsJson
                .whereType<Map<String, dynamic>>()
                .map(Author.fromJson)
                .toList(growable: false)
          : const [],
      owned: parseOwned(json['owned']),
      averageRating: (json['average_rating'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Book copyWith({
    int? id,
    String? title,
    String? slug,
    String? subtitle,
    String? description,
    int? creditPrice,
    int? availableCopies,
    bool? owned,
    String? isbn,
    String? language,
    String? coverImageUrl,
    String? pdfFilename,
    int? pdfFileSize,
    int? pdfPageCount,
    DateTime? publishedAt,
    String? status,
    Category? category,
    List<Author>? authors,
    double? averageRating,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      slug: slug ?? this.slug,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      creditPrice: creditPrice ?? this.creditPrice,
      availableCopies: availableCopies ?? this.availableCopies,
      owned: owned ?? this.owned,
      isbn: isbn ?? this.isbn,
      language: language ?? this.language,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      pdfFilename: pdfFilename ?? this.pdfFilename,
      pdfFileSize: pdfFileSize ?? this.pdfFileSize,
      pdfPageCount: pdfPageCount ?? this.pdfPageCount,
      publishedAt: publishedAt ?? this.publishedAt,
      status: status ?? this.status,
      category: category ?? this.category,
      authors: authors ?? this.authors,
      averageRating: averageRating ?? this.averageRating,
    );
  }

  /// Check if book has a PDF file
  bool get hasPdf => pdfFilename != null && pdfFilename!.isNotEmpty;

  /// Get formatted file size
  String get formattedFileSize {
    if (pdfFileSize == null) return 'Unknown';
    final mb = pdfFileSize! / (1024 * 1024);
    return '${mb.toStringAsFixed(2)} MB';
  }

  String? get resolvedCoverImageUrl {
    final raw = coverImageUrl?.trim();
    if (raw == null || raw.isEmpty) return null;

    final baseUri = Uri.tryParse(AppConfig.apiBaseUrl);
    final schemePattern = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://');

    if (!schemePattern.hasMatch(raw)) {
      if (raw.startsWith('//')) {
        final scheme = baseUri?.scheme.isNotEmpty == true ? baseUri!.scheme : 'https';
        return '$scheme:$raw';
      }

      final hostMatch = RegExp(r'^([a-zA-Z0-9.-]+(?::\d+)?)(/.*)?$').firstMatch(raw);
      if (hostMatch != null) {
        final candidateHost = hostMatch.group(1)!;
        final hasDot = candidateHost.contains('.');
        final hasColon = candidateHost.contains(':');
        if (hasDot || hasColon) {
          final hostOnly = candidateHost.split(':').first;
          final isIpv4 = RegExp(r'^\d{1,3}(?:\.\d{1,3}){3}$').hasMatch(hostOnly);
          final scheme = isIpv4
              ? (baseUri?.scheme.isNotEmpty == true ? baseUri!.scheme : 'http')
              : 'https';
          return '$scheme://$raw';
        }
      }
    }

    final parsed = Uri.tryParse(raw);

    if (parsed == null) return raw;

    if (parsed.hasScheme) {
      final host = parsed.host.toLowerCase();
      if (baseUri != null &&
          baseUri.host.isNotEmpty &&
          (host == 'localhost' || host == '127.0.0.1')) {
        final scheme = baseUri.scheme.isNotEmpty ? baseUri.scheme : parsed.scheme;
        final port = parsed.hasPort
            ? parsed.port
            : (baseUri.hasPort ? baseUri.port : null);
        return parsed
            .replace(
              scheme: scheme,
              host: baseUri.host,
              port: port,
            )
            .toString();
      }
      return parsed.toString();
    }

    if (parsed.host.isNotEmpty) {
      final scheme = baseUri?.scheme ?? 'http';
      return parsed.replace(scheme: scheme).toString();
    }

    if (baseUri != null) {
      return baseUri.resolveUri(parsed).toString();
    }

    return raw;
  }
}
