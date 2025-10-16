import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/models/user.dart';
import 'package:my_flutter_app/services/api_client.dart';

class UserService {
  UserService._();

  static final UserService instance = UserService._();

  final ApiClient _client = ApiClient.instance;
  List<User>? _cachedUsers;
  Future<List<User>>? _cacheFuture;

  Future<PaginatedResult<User>> listUsers({
    int page = 1,
    int perPage = 20,
    String? search,
    String? role,
  }) async {
    final query = <String, dynamic>{
      'page': page,
      'per_page': perPage,
    };

    if (search != null && search.trim().isNotEmpty) {
      query['search'] = search.trim();
    }

    if (role != null && role.trim().isNotEmpty) {
      query['role'] = role.trim();
    }

    final json = await _client.getJson(
      '/api/users',
      query: query,
      auth: true,
    );

    return PaginatedResult.fromJson(json, User.fromJson);
  }

  Future<List<User>> getAllUsers({bool forceRefresh = false}) async {
    if (forceRefresh) {
      invalidateCache();
    } else {
      final cached = _cachedUsers;
      if (cached != null) {
        return List<User>.unmodifiable(cached);
      }
      final pending = _cacheFuture;
      if (pending != null) {
        return pending;
      }
    }

    final future = _fetchAllUsers().then((users) {
      _cachedUsers = users;
      _cacheFuture = null;
      return List<User>.unmodifiable(users);
    }).catchError((error) {
      _cacheFuture = null;
      throw error;
    });

    _cacheFuture = future;
    return future;
  }

  void invalidateCache() {
    _cachedUsers = null;
    _cacheFuture = null;
  }

  Future<List<User>> _fetchAllUsers() async {
    const perPage = 100;
    final List<User> users = [];
    var page = 1;
    while (true) {
      final json = await _client.getJson(
        '/api/users',
        query: {'page': page, 'per_page': perPage},
        auth: true,
      );
      final result = PaginatedResult.fromJson(json, User.fromJson);
      users.addAll(result.data);
      if (page >= result.lastPage) {
        break;
      }
      page += 1;
    }
    return users;
  }

  Future<void> deleteUser(int id) async {
    await _client.deleteJson('/api/users/$id', auth: true);
    final cached = _cachedUsers;
    if (cached != null) {
      _cachedUsers =
          cached.where((user) => user.id != id).toList(growable: false);
    }
  }
}
