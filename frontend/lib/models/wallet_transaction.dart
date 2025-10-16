class WalletTransaction {
  final int id;
  final String type;
  final int amount;
  final int balanceBefore;
  final int balanceAfter;
  final int? orderId;
  final int? performedBy;
  final String? reference;
  final String? description;
  final Map<String, dynamic>? meta;
  final DateTime? createdAt;

  const WalletTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    this.orderId,
    this.performedBy,
    this.reference,
    this.description,
    this.meta,
    this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    DateTime? createdAt;
    final createdRaw = json['created_at']?.toString();
    if (createdRaw != null && createdRaw.isNotEmpty) {
      try {
        createdAt = DateTime.parse(createdRaw);
      } catch (_) {}
    }

    return WalletTransaction(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? 'credit',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      balanceBefore: (json['balance_before'] as num?)?.toInt() ?? 0,
      balanceAfter: (json['balance_after'] as num?)?.toInt() ?? 0,
      orderId: (json['order_id'] as num?)?.toInt(),
      performedBy: (json['performed_by'] as num?)?.toInt(),
      reference: json['reference']?.toString(),
      description: json['description']?.toString(),
      meta: json['meta'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['meta'] as Map)
          : null,
      createdAt: createdAt,
    );
  }
}
