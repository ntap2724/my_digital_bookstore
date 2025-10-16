import 'package:my_flutter_app/models/book.dart';

class OrderItem {
  final int id;
  final int bookId;
  final int quantity;
  final int unitCredit;
  final int totalCredit;
  final Book? book;

  const OrderItem({
    required this.id,
    required this.bookId,
    required this.quantity,
    required this.unitCredit,
    required this.totalCredit,
    this.book,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    final bookJson = json['book'];
    return OrderItem(
      id: (json['id'] as num?)?.toInt() ?? 0,
      bookId: (json['book_id'] as num?)?.toInt() ?? 0,
      quantity: (json['quantity'] as num?)?.toInt() ?? 0,
      unitCredit: (json['unit_credit'] as num?)?.toInt() ?? 0,
      totalCredit: (json['total_credit'] as num?)?.toInt() ?? 0,
      book: bookJson is Map<String, dynamic> ? Book.fromJson(bookJson) : null,
    );
  }
}
