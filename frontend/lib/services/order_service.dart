import 'package:my_flutter_app/models/order.dart';
import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/services/api_client.dart';

class OrderService {
  OrderService._();

  static final OrderService instance = OrderService._();

  final ApiClient _client = ApiClient.instance;

  final Map<String, PaginatedResult<Order>> _ordersCache = {};
  final Map<String, Future<PaginatedResult<Order>>> _ordersPending = {};
  final Map<int, Order> _orderCache = {};
  final Map<int, Future<Order>> _orderPending = {};

  Future<PaginatedResult<Order>> fetchOrders({
    int page = 1,
    int perPage = 10,
    String? status,
    int? userId,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey({
      'page': page,
      'per_page': perPage,
      'status': status?.trim().toLowerCase(),
      'user_id': userId,
    });

    if (!forceRefresh && _ordersCache.containsKey(key)) {
      return _ordersCache[key]!;
    }
    if (!forceRefresh && _ordersPending.containsKey(key)) {
      return _ordersPending[key]!;
    }

    final future = _client
        .getJson(
          '/api/orders',
          query: {
            'page': page,
            'per_page': perPage,
            if (status != null && status.isNotEmpty) 'status': status,
            if (userId != null) 'user_id': userId,
          },
          auth: true,
        )
        .then((json) {
          final result =
              PaginatedResult.fromJson(json, (item) => Order.fromJson(item));
          _ordersCache[key] = result;
          _ordersPending.remove(key);
          return result;
        }).catchError((error) {
          _ordersPending.remove(key);
          throw error;
        });

    _ordersPending[key] = future;
    return future;
  }

  Future<Order> getOrder(int id, {bool forceRefresh = false}) async {
    if (!forceRefresh && _orderCache.containsKey(id)) {
      return _orderCache[id]!;
    }
    if (!forceRefresh && _orderPending.containsKey(id)) {
      return _orderPending[id]!;
    }

    final future =
        _client.getJson('/api/orders/$id', auth: true).then((json) {
      final order = Order.fromJson(_unwrap(json));
      _orderCache[id] = order;
      _orderPending.remove(id);
      return order;
    }).catchError((error) {
      _orderPending.remove(id);
      throw error;
    });

    _orderPending[id] = future;
    return future;
  }

  Future<Order> placeOrder({
    required List<Map<String, dynamic>> items,
    String? note,
  }) async {
    final payload = <String, dynamic>{
      'items': items,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    final json = await _client.postJson(
      '/api/orders',
      body: payload,
      auth: true,
    );

    invalidateCache();
    return Order.fromJson(_unwrap(json));
  }

  Future<Order> cancelOrder(int id, {String? reason}) async {
    final payload = <String, dynamic>{
      if (reason != null && reason.isNotEmpty) 'reason': reason,
    };

    final json = await _client.postJson(
      '/api/orders/$id/cancel',
      body: payload.isEmpty ? null : payload,
      auth: true,
    );

    invalidateCache();
    return Order.fromJson(_unwrap(json));
  }

  void invalidateCache() {
    _ordersCache.clear();
    _ordersPending.clear();
    _orderCache.clear();
    _orderPending.clear();
  }

  String _cacheKey(Map<String, Object?> params) {
    final entries = params.entries
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
