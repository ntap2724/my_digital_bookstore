class BookReview {
  final int id;
  final int rating;
  final String? comment;
  final String? title;
  final DateTime? createdAt;
  final Map<String, dynamic>? user;

  const BookReview({
    required this.id,
    required this.rating,
    this.comment,
    this.title,
    this.createdAt,
    this.user,
  });

  factory BookReview.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final createdRaw = json['created_at']?.toString();
    if (createdRaw != null && createdRaw.isNotEmpty) {
      try {
        createdAt = DateTime.parse(createdRaw);
      } catch (_) {}
    }

    return BookReview(
      id: (json['id'] as num?)?.toInt() ?? 0,
      rating: (json['rating'] as num?)?.toInt() ?? 0,
      comment: json['comment']?.toString(),
      title: json['title'] as String?,
      createdAt: createdAt,
      user: json['user'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['user'] as Map)
          : null,
    );
  }
}
