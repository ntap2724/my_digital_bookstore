import 'package:my_flutter_app/models/wallet_transaction.dart';

class Wallet {
  final int id;
  final int userId;
  final int balance;
  final DateTime? updatedAt;
  final List<WalletTransaction> transactions;

  const Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    this.updatedAt,
    this.transactions = const [],
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    DateTime? updatedAt;
    final updatedRaw = json['updated_at']?.toString();
    if (updatedRaw != null && updatedRaw.isNotEmpty) {
      try {
        updatedAt = DateTime.parse(updatedRaw);
      } catch (_) {}
    }

    final txJson = json['transactions'];

    return Wallet(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      balance: (json['balance'] as num?)?.toInt() ?? 0,
      updatedAt: updatedAt,
      transactions: txJson is List
          ? txJson
                .whereType<Map<String, dynamic>>()
                .map(WalletTransaction.fromJson)
                .toList(growable: false)
          : const [],
    );
  }
}
