import 'package:my_flutter_app/models/book.dart';

class CartItem {
  const CartItem({
    required this.bookId,
    required this.title,
    required this.creditPrice,
    this.coverImageUrl,
    this.book,
    this.quantity = 1,
  }) : assert(quantity > 0, 'quantity must be positive');

  final int bookId;
  final String title;
  final int creditPrice;
  final String? coverImageUrl;
  final Book? book;
  final int quantity;

  int get totalCredit => creditPrice * quantity;

  CartItem copyWith({
    Book? book,
    String? title,
    String? coverImageUrl,
    int? creditPrice,
    int? quantity,
  }) {
    return CartItem(
      bookId: bookId,
      title: title ?? this.title,
      creditPrice: creditPrice ?? this.creditPrice,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      book: book ?? this.book,
      quantity: quantity ?? this.quantity,
    );
  }

  factory CartItem.fromBook(Book book) {
    return CartItem(
      bookId: book.id,
      title: book.title,
      creditPrice: book.creditPrice,
      coverImageUrl: book.coverImageUrl,
      book: book,
      quantity: 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book_id': bookId,
      'title': title,
      'credit_price': creditPrice,
      'cover_image_url': coverImageUrl,
      'quantity': quantity,
    };
  }

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
      bookId: (json['book_id'] as num?)?.toInt() ?? 0,
      title: json['title']?.toString() ?? '',
      creditPrice: (json['credit_price'] as num?)?.toInt() ?? 0,
      coverImageUrl: json['cover_image_url']?.toString(),
      quantity: 1,
    );
  }
}
