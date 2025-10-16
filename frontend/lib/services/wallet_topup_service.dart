import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/models/wallet_topup_request.dart';
import 'package:my_flutter_app/services/api_client.dart';

class WalletTopUpService {
  WalletTopUpService._();

  static final WalletTopUpService instance = WalletTopUpService._();

  final ApiClient _client = ApiClient.instance;

  final Map<String, PaginatedResult<WalletTopUpRequest>> _listCache = {};
  final Map<String, Future<PaginatedResult<WalletTopUpRequest>>> _listPending =
      {};
  final Map<int, WalletTopUpRequest> _requestCache = {};
  final Map<int, Future<WalletTopUpRequest>> _requestPending = {};

  Future<WalletTopUpRequest> create({required int amount, String? note}) async {
    final payload = <String, dynamic>{
      'amount': amount,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final json = await _client.postJson(
      '/api/wallet/top-ups',
      body: payload,
      auth: true,
    );

    invalidateListCache();
    return WalletTopUpRequest.fromJson(_unwrap(json));
  }

  Future<PaginatedResult<WalletTopUpRequest>> fetch({
    int page = 1,
    int perPage = 20,
    String? status,
    int? userId,
    bool forceRefresh = false,
  }) {
    final key = _cacheKey({
      'page': page,
      'per_page': perPage,
      'status': status,
      'user_id': userId,
    });

    if (!forceRefresh && _listCache.containsKey(key)) {
      return Future.value(_listCache[key]);
    }
    if (!forceRefresh && _listPending.containsKey(key)) {
      return _listPending[key]!;
    }

    final future = _client
        .getJson(
          '/api/wallet/top-ups',
          query: {
            'page': page,
            'per_page': perPage,
            if (status != null && status.isNotEmpty) 'status': status,
            if (userId != null) 'user_id': userId,
          },
          auth: true,
        )
        .then((json) {
          final result = PaginatedResult.fromJson(
            json,
            (item) => WalletTopUpRequest.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          );
          _listCache[key] = result;
          _listPending.remove(key);
          return result;
        })
        .catchError((error) {
          _listPending.remove(key);
          throw error;
        });

    _listPending[key] = future;
    return future;
  }

  Future<WalletTopUpRequest> get(int id, {bool forceRefresh = false}) {
    if (!forceRefresh && _requestCache.containsKey(id)) {
      return Future.value(_requestCache[id]);
    }
    if (!forceRefresh && _requestPending.containsKey(id)) {
      return _requestPending[id]!;
    }

    final future = _client
        .getJson('/api/wallet/top-ups/$id', auth: true)
        .then((json) {
          final request = WalletTopUpRequest.fromJson(_unwrap(json));
          _requestCache[id] = request;
          _requestPending.remove(id);
          return request;
        })
        .catchError((error) {
          _requestPending.remove(id);
          throw error;
        });

    _requestPending[id] = future;
    return future;
  }

  Future<WalletTopUpRequest> approve(int id, {String? note}) async {
    final payload = <String, dynamic>{
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final json = await _client.postJson(
      '/api/wallet/top-ups/$id/approve',
      body: payload.isEmpty ? null : payload,
      auth: true,
    );

    invalidate(id: id);
    return WalletTopUpRequest.fromJson(_unwrap(json));
  }

  Future<WalletTopUpRequest> reject(int id, {String? note}) async {
    final payload = <String, dynamic>{
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final json = await _client.postJson(
      '/api/wallet/top-ups/$id/reject',
      body: payload.isEmpty ? null : payload,
      auth: true,
    );

    invalidate(id: id);
    return WalletTopUpRequest.fromJson(_unwrap(json));
  }

  void invalidate({int? id}) {
    if (id != null) {
      _requestCache.remove(id);
      _requestPending.remove(id);
    }
    invalidateListCache();
  }

  void invalidateListCache() {
    _listCache.clear();
    _listPending.clear();
  }

  String _cacheKey(Map<String, Object?> params) {
    final entries =
        params.entries
            .where((e) => e.value != null && e.value.toString().isNotEmpty)
            .map((e) => '${e.key}=${e.value}')
            .toList()
          ..sort();
    return entries.join('&');
  }
}

Map<String, dynamic> _unwrap(Map<String, dynamic> json) {
  final data = json['data'];

  if (data is Map<String, dynamic>) {
    return data;
  }

  if (data is Map) {
    return Map<String, dynamic>.from(data);
  }

  return json;
}
