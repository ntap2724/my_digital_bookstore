import 'package:my_flutter_app/models/book.dart';

class UserBook {
  const UserBook({
    required this.id,
    required this.userId,
    required this.bookId,
    this.orderId,
    this.firstPurchasedAt,
    this.lastPurchasedAt,
    this.lastOpenedAt,
    this.book,
  });

  final int id;
  final int userId;
  final int bookId;
  final int? orderId;
  final DateTime? firstPurchasedAt;
  final DateTime? lastPurchasedAt;
  final DateTime? lastOpenedAt;
  final Book? book;

  UserBook copyWith({
    DateTime? lastOpenedAt,
    DateTime? lastPurchasedAt,
    Book? book,
  }) {
    return UserBook(
      id: id,
      userId: userId,
      bookId: bookId,
      orderId: orderId,
      firstPurchasedAt: firstPurchasedAt,
      lastPurchasedAt: lastPurchasedAt ?? this.lastPurchasedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      book: book ?? this.book,
    );
  }

  factory UserBook.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String key) {
      final raw = json[key]?.toString();
      if (raw == null || raw.isEmpty) {
        return null;
      }
      try {
        return DateTime.parse(raw);
      } catch (_) {
        return null;
      }
    }

    Book? parseBook() {
      final raw = json['book'];
      if (raw is Map<String, dynamic>) {
        return Book.fromJson(raw);
      }
      if (raw is Map) {
        return Book.fromJson(raw.cast<String, dynamic>());
      }
      return null;
    }

    return UserBook(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      bookId: (json['book_id'] as num?)?.toInt() ?? 0,
      orderId: (json['order_id'] as num?)?.toInt(),
      firstPurchasedAt: parseDate('first_purchased_at'),
      lastPurchasedAt: parseDate('last_purchased_at'),
      lastOpenedAt: parseDate('last_opened_at'),
      book: parseBook(),
    );
  }
}
