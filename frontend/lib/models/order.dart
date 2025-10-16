import 'package:my_flutter_app/models/order_item.dart';

class Order {
  final int id;
  final int userId;
  final int totalCredit;
  final String status;
  final String? note;
  final DateTime? placedAt;
  final DateTime? completedAt;
  final DateTime? cancelledAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<OrderItem> items;
  final String? userName;
  final String? userEmail;

  const Order({
    required this.id,
    required this.userId,
    required this.totalCredit,
    required this.status,
    this.note,
    this.placedAt,
    this.completedAt,
    this.cancelledAt,
    this.createdAt,
    this.updatedAt,
    this.items = const [],
    this.userName,
    this.userEmail,
  });

  factory Order.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) {
      if (value == null || value.isEmpty) return null;
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }

    final userJson = json['user'];
    String? name;
    String? email;
    if (userJson is Map) {
      final map = userJson.cast<String, dynamic>();
      name = map['name']?.toString();
      email = map['email']?.toString();
    }

    final itemsJson = json['items'];

    return Order(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      totalCredit: (json['total_credit'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      note: json['note']?.toString(),
      placedAt: parseDate(json['placed_at']?.toString()),
      completedAt: parseDate(json['completed_at']?.toString()),
      cancelledAt: parseDate(json['cancelled_at']?.toString()),
      createdAt: parseDate(json['created_at']?.toString()),
      updatedAt: parseDate(json['updated_at']?.toString()),
      items: itemsJson is List
          ? itemsJson
                .whereType<Map<String, dynamic>>()
                .map(OrderItem.fromJson)
                .toList(growable: false)
          : const [],
      userName: name,
      userEmail: email,
    );
  }
}
