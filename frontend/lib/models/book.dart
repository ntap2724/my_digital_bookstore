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
  final String? fileUrl;
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
    this.fileUrl,
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
      fileUrl: json['file_url']?.toString(),
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
    String? fileUrl,
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
      fileUrl: fileUrl ?? this.fileUrl,
      publishedAt: publishedAt ?? this.publishedAt,
      status: status ?? this.status,
      category: category ?? this.category,
      authors: authors ?? this.authors,
      averageRating: averageRating ?? this.averageRating,
    );
  }
}
