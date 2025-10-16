import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/models/user_book.dart';
import 'package:my_flutter_app/services/api_client.dart';

class LibraryService {
  LibraryService._();

  static final LibraryService instance = LibraryService._();

  final ApiClient _client = ApiClient.instance;

  final Map<String, PaginatedResult<UserBook>> _cache = {};
  final Map<String, Future<PaginatedResult<UserBook>>> _pending = {};
  final Map<int, UserBook> _bookCache = {};
  final Map<int, Future<UserBook>> _bookPending = {};

  Future<PaginatedResult<UserBook>> fetchLibrary({
    int page = 1,
    int perPage = 12,
    bool forceRefresh = false,
  }) {
    final key = _cacheKey({'page': page, 'per_page': perPage});

    if (!forceRefresh && _cache.containsKey(key)) {
      return Future.value(_cache[key]);
    }
    if (!forceRefresh && _pending.containsKey(key)) {
      return _pending[key]!;
    }

    final future = _client
        .getJson(
          '/api/my-books',
          query: {'page': page, 'per_page': perPage},
          auth: true,
        )
        .then((json) {
          final result = PaginatedResult.fromJson(
            json,
            (item) => UserBook.fromJson(item),
          );
          _cache[key] = result;
          _pending.remove(key);
          return result;
        })
        .catchError((error) {
          _pending.remove(key);
          throw error;
        });

    _pending[key] = future;
    return future;
  }

  Future<UserBook> getByBook(int bookId, {bool forceRefresh = false}) {
    if (!forceRefresh && _bookCache.containsKey(bookId)) {
      return Future.value(_bookCache[bookId]);
    }
    if (!forceRefresh && _bookPending.containsKey(bookId)) {
      return _bookPending[bookId]!;
    }

    final future = _client
        .getJson('/api/my-books/$bookId', auth: true)
        .then((json) {
          final userBook = UserBook.fromJson(_unwrap(json));
          _bookCache[bookId] = userBook;
          _bookPending.remove(bookId);
          return userBook;
        })
        .catchError((error) {
          _bookPending.remove(bookId);
          throw error;
        });

    _bookPending[bookId] = future;
    return future;
  }

  Future<UserBook> markOpened(int bookId) async {
    final json = await _client.postJson(
      '/api/my-books/$bookId/opened',
      auth: true,
    );

    final userBook = UserBook.fromJson(_unwrap(json));
    _bookCache[bookId] = userBook;
    _cache.clear();
    return userBook;
  }

  void invalidateCache() {
    _cache.clear();
    _pending.clear();
    _bookCache.clear();
    _bookPending.clear();
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
