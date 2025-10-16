class WalletTopUpRequest {
  const WalletTopUpRequest({
    required this.id,
    required this.userId,
    required this.amount,
    required this.status,
    this.note,
    this.responseNote,
    this.respondedBy,
    this.respondedAt,
    this.createdAt,
    this.updatedAt,
    this.user,
    this.responder,
  });

  final int id;
  final int userId;
  final int amount;
  final String status;
  final String? note;
  final String? responseNote;
  final int? respondedBy;
  final DateTime? respondedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final Map<String, dynamic>? user;
  final Map<String, dynamic>? responder;

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  factory WalletTopUpRequest.fromJson(Map<String, dynamic> json) {
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

    Map<String, dynamic>? normalizeUser(dynamic value) {
      if (value is Map<String, dynamic>) {
        return value;
      }
      if (value is Map) {
        return value.cast<String, dynamic>();
      }
      return null;
    }

    return WalletTopUpRequest(
      id: (json['id'] as num?)?.toInt() ?? 0,
      userId: (json['user_id'] as num?)?.toInt() ?? 0,
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      status: json['status']?.toString() ?? 'pending',
      note: json['note']?.toString(),
      responseNote: json['response_note']?.toString(),
      respondedBy: (json['responded_by'] as num?)?.toInt(),
      respondedAt: parseDate('responded_at'),
      createdAt: parseDate('created_at'),
      updatedAt: parseDate('updated_at'),
      user: normalizeUser(json['user']),
      responder: normalizeUser(json['responder']),
    );
  }
}
