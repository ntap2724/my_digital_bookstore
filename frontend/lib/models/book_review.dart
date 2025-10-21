class BookReview {
  BookReview({
    required this.id,
    required this.bookId,
    required this.userId,
    required this.rating,
    this.title,
    this.comment,
    this.user,
    this.createdAt,
    this.updatedAt,
    // NEW: Vote counts and user vote
    this.helpfulCount = 0,
    this.notHelpfulCount = 0,
    this.userVote,
  });

  final int id;
  final int bookId;
  final int userId;
  final int rating;
  final String? title;
  final String? comment;
  final Map<String, dynamic>? user;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  // NEW: Vote fields
  final int helpfulCount;
  final int notHelpfulCount;
  final String? userVote; // 'like', 'dislike', or null

  factory BookReview.fromJson(Map<String, dynamic> json) {
    return BookReview(
      id: json['id'] as int,
      bookId: json['book_id'] as int,
      userId: json['user_id'] as int,
      rating: json['rating'] as int,
      title: json['title'] as String?,
      comment: json['comment'] as String?,
      user: json['user'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      // NEW: Parse vote data
      helpfulCount: json['helpful_count'] as int? ?? 0,
      notHelpfulCount: json['not_helpful_count'] as int? ?? 0,
      userVote: json['user_vote'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'book_id': bookId,
      'user_id': userId,
      'rating': rating,
      'title': title,
      'comment': comment,
      'user': user,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
      'helpful_count': helpfulCount,
      'not_helpful_count': notHelpfulCount,
      'user_vote': userVote,
    };
  }

  BookReview copyWith({
    int? id,
    int? bookId,
    int? userId,
    int? rating,
    String? title,
    String? comment,
    Map<String, dynamic>? user,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? helpfulCount,
    int? notHelpfulCount,
    String? userVote,
  }) {
    return BookReview(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      userId: userId ?? this.userId,
      rating: rating ?? this.rating,
      title: title ?? this.title,
      comment: comment ?? this.comment,
      user: user ?? this.user,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      helpfulCount: helpfulCount ?? this.helpfulCount,
      notHelpfulCount: notHelpfulCount ?? this.notHelpfulCount,
      userVote: userVote ?? this.userVote,
    );
  }
}
