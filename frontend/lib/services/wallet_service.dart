import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/models/wallet.dart';
import 'package:my_flutter_app/models/wallet_transaction.dart';
import 'package:my_flutter_app/services/api_client.dart';

class WalletService {
  WalletService._();

  static final WalletService instance = WalletService._();

  final ApiClient _client = ApiClient.instance;

  Wallet? _currentWalletCache;
  Future<Wallet>? _currentWalletPending;
  final Map<String, Wallet> _walletCache = {};
  final Map<String, Future<Wallet>> _walletPending = {};
  final Map<String, PaginatedResult<Wallet>> _walletListCache = {};
  final Map<String, Future<PaginatedResult<Wallet>>> _walletListPending = {};
  final Map<String, PaginatedResult<WalletTransaction>> _walletTxCache = {};
  final Map<String, Future<PaginatedResult<WalletTransaction>>> _walletTxPending = {};
  final Map<String, PaginatedResult<WalletTransaction>> _currentTxCache = {};
  final Map<String, Future<PaginatedResult<WalletTransaction>>> _currentTxPending = {};

  Future<Wallet> getCurrentWallet({bool forceRefresh = false}) async {
    if (!forceRefresh && _currentWalletCache != null) {
      return _currentWalletCache!;
    }
    if (!forceRefresh && _currentWalletPending != null) {
      return _currentWalletPending!;
    }

    final future = _client.getJson('/api/wallet', auth: true).then((json) {
      final wallet = Wallet.fromJson(_unwrap(json));
      _currentWalletCache = wallet;
      _currentWalletPending = null;
      return wallet;
    }).catchError((error) {
      _currentWalletPending = null;
      throw error;
    });

    _currentWalletPending = future;
    return future;
  }

  Future<PaginatedResult<WalletTransaction>> getCurrentTransactions({
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey('currentTx', {
      'page': page,
      'per_page': perPage,
    });

    if (!forceRefresh && _currentTxCache.containsKey(key)) {
      return _currentTxCache[key]!;
    }
    if (!forceRefresh && _currentTxPending.containsKey(key)) {
      return _currentTxPending[key]!;
    }

    final future = _client
        .getJson(
          '/api/wallet/transactions',
          query: {'page': page, 'per_page': perPage},
          auth: true,
        )
        .then((json) {
          final result = PaginatedResult.fromJson(json, WalletTransaction.fromJson);
          _currentTxCache[key] = result;
          _currentTxPending.remove(key);
          return result;
        }).catchError((error) {
          _currentTxPending.remove(key);
          throw error;
        });

    _currentTxPending[key] = future;
    return future;
  }

  Future<PaginatedResult<Wallet>> listWallets({
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey('list', {
      'page': page,
      'per_page': perPage,
    });

    if (!forceRefresh && _walletListCache.containsKey(key)) {
      return _walletListCache[key]!;
    }
    if (!forceRefresh && _walletListPending.containsKey(key)) {
      return _walletListPending[key]!;
    }

    final future = _client
        .getJson(
          '/api/wallets',
          query: {'page': page, 'per_page': perPage},
          auth: true,
        )
        .then((json) {
          final result = PaginatedResult.fromJson(json, (item) => Wallet.fromJson(item));
          _walletListCache[key] = result;
          _walletListPending.remove(key);
          return result;
        }).catchError((error) {
          _walletListPending.remove(key);
          throw error;
        });

    _walletListPending[key] = future;
    return future;
  }

  Future<Wallet> getWallet(int userId, {bool forceRefresh = false}) async {
    final key = _walletKey(userId);
    if (!forceRefresh && _walletCache.containsKey(key)) {
      return _walletCache[key]!;
    }
    if (!forceRefresh && _walletPending.containsKey(key)) {
      return _walletPending[key]!;
    }

    final future = _client.getJson('/api/wallets/$userId', auth: true).then((json) {
      final wallet = Wallet.fromJson(_unwrap(json));
      _walletCache[key] = wallet;
      _walletPending.remove(key);
      return wallet;
    }).catchError((error) {
      _walletPending.remove(key);
      throw error;
    });

    _walletPending[key] = future;
    return future;
  }

  Future<PaginatedResult<WalletTransaction>> getWalletTransactions(
    int userId, {
    int page = 1,
    int perPage = 20,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey('walletTx', {
      'user': userId,
      'page': page,
      'per_page': perPage,
    });

    if (!forceRefresh && _walletTxCache.containsKey(key)) {
      return _walletTxCache[key]!;
    }
    if (!forceRefresh && _walletTxPending.containsKey(key)) {
      return _walletTxPending[key]!;
    }

    final future = _client
        .getJson(
          '/api/wallets/$userId/transactions',
          query: {'page': page, 'per_page': perPage},
          auth: true,
        )
        .then((json) {
          final result = PaginatedResult.fromJson(json, WalletTransaction.fromJson);
          _walletTxCache[key] = result;
          _walletTxPending.remove(key);
          return result;
        }).catchError((error) {
          _walletTxPending.remove(key);
          throw error;
        });

    _walletTxPending[key] = future;
    return future;
  }

  Future<WalletTransaction> adjustWallet(
    int userId, {
    required String type,
    required int amount,
    String? description,
    String? reference,
    Map<String, dynamic>? meta,
  }) async {
    final payload = <String, dynamic>{
      'type': type,
      'amount': amount,
      if (description != null) 'description': description,
      if (reference != null) 'reference': reference,
      if (meta != null && meta.isNotEmpty) 'meta': meta,
    };

    final json = await _client.postJson(
      '/api/wallets/$userId/adjust',
      body: payload,
      auth: true,
    );

    invalidateWallet(userId);
    return WalletTransaction.fromJson(_unwrap(json));
  }

  void invalidateCache() {
    _currentWalletCache = null;
    _currentWalletPending = null;
    _walletCache.clear();
    _walletPending.clear();
    _walletListCache.clear();
    _walletListPending.clear();
    _walletTxCache.clear();
    _walletTxPending.clear();
    _currentTxCache.clear();
    _currentTxPending.clear();
  }

  void invalidateWallet(int userId) {
    final key = _walletKey(userId);
    _walletCache.remove(key);
    _walletPending.remove(key);
    _walletListCache.clear();
    _walletListPending.clear();
    _walletTxCache.removeWhere((k, _) => k.contains('user=$userId'));
    _walletTxPending.removeWhere((k, _) => k.contains('user=$userId'));
    if (_currentWalletCache?.userId == userId) {
      _currentWalletCache = null;
      _currentWalletPending = null;
      _currentTxCache.clear();
      _currentTxPending.clear();
    }
  }

  String _walletKey(int userId) => 'wallet:$userId';

  String _cacheKey(String prefix, Map<String, Object?> params) {
    final entries = params.entries
        .where((e) => e.value != null && e.value.toString().isNotEmpty)
        .map((e) => '${e.key}=${e.value}')
        .toList()
      ..sort();
    return '$prefix:${entries.join('&')}';
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
