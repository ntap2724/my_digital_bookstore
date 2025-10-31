import 'package:flutter/foundation.dart'
    show ValueListenable, ValueNotifier, VoidCallback;
import 'package:my_flutter_app/models/author.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/models/book_review.dart';
import 'package:my_flutter_app/models/category.dart';
import 'package:my_flutter_app/models/extracted_text.dart';
import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class CatalogService {
  CatalogService._();

  static final CatalogService instance = CatalogService._();

  final ApiClient _client = ApiClient.instance;

  final Map<String, List<Category>> _categoryCache = {};
  final Map<String, Future<List<Category>>> _categoryPending = {};
  final Map<String, DateTime?> _categoryCacheTimestamp = {};

  final Map<String, List<Author>> _authorCache = {};
  final Map<String, Future<List<Author>>> _authorPending = {};
  final Map<String, DateTime?> _authorCacheTimestamp = {};

  final Map<String, PaginatedResult<Book>> _bookCache = {};
  final Map<String, Future<PaginatedResult<Book>>> _bookPending = {};
  final Map<String, DateTime?> _bookCacheTimestamp = {};

  List<Book>? _allBooksCache;
  Future<List<Book>>? _allBooksPending;
  String? _allBooksCacheKey;
  DateTime? _allBooksCacheTimestamp;
  String? _currentOwnerKey;

  final Map<int, Map<String, dynamic>> _reviewsCache = {};
  final Map<int, Future<Map<String, dynamic>>> _reviewsPending = {};
  final Map<int, DateTime?> _reviewsCacheTimestamp = {};

  final Map<int, BookReview?> _userReviewCache = {};
  final Map<int, Future<BookReview?>> _userReviewPending = {};
  final Map<int, DateTime?> _userReviewCacheTimestamp = {};

  final ValueNotifier<int?> _ownedBookNotifier = ValueNotifier<int?>(null);
  final ValueNotifier<int> _cacheUpdateVersion = ValueNotifier<int>(0);

  ValueListenable<int?> get ownedBookUpdates => _ownedBookNotifier;
  ValueListenable<int> get cacheUpdates => _cacheUpdateVersion;

  void addCacheListener(VoidCallback listener) {
    _cacheUpdateVersion.addListener(listener);
  }

  void removeCacheListener(VoidCallback listener) {
    _cacheUpdateVersion.removeListener(listener);
  }

  // Cache refresh interval (5 minutes for better performance)
  static const Duration _cacheRefreshInterval = Duration(minutes: 5);

  // ==================== SMART CACHING METHODS ====================

  /// Check if cache entry is stale (older than refresh interval)
  bool _isCacheStale(DateTime? timestamp) {
    if (timestamp == null) return true;
    return DateTime.now().difference(timestamp) > _cacheRefreshInterval;
  }

  /// Check if cached data should be refreshed based on timestamp
  bool _shouldRefreshCache(String cacheType, String key) {
    switch (cacheType) {
      case 'categories':
        return _isCacheStale(_categoryCacheTimestamp[key]);
      case 'authors':
        return _isCacheStale(_authorCacheTimestamp[key]);
      case 'books':
        return _isCacheStale(_bookCacheTimestamp[key]);
      case 'allBooks':
        return _isCacheStale(_allBooksCacheTimestamp);
      case 'reviews':
        return _isCacheStale(_reviewsCacheTimestamp[int.parse(key)]);
      case 'userReview':
        return _isCacheStale(_userReviewCacheTimestamp[int.parse(key)]);
      default:
        return false;
    }
  }

  // ==================== HELPER METHODS FOR STALE-WHILE-REVALIDATE ====================

  void _scheduleCategoryRefresh({
    required String key,
    String? search,
    required bool auth,
  }) {
    if (_categoryPending[key] != null) return;
    _fetchCategoriesFromApi(key: key, search: search, auth: auth)
        .catchError((_) => <Category>[]);
  }

  Future<List<Category>> _fetchCategoriesFromApi({
    required String key,
    String? search,
    required bool auth,
  }) {
    final future = _client
        .getJson(
          '/api/categories',
          query: {if (search != null && search.isNotEmpty) 'search': search},
          auth: auth,
        )
        .then((json) {
          final data = json['data'];
          final list = data is List
              ? data
                    .whereType<Map<String, dynamic>>()
                    .map(Category.fromJson)
                    .toList(growable: false)
              : <Category>[];
          _categoryCache[key] = list;
          _categoryCacheTimestamp[key] = DateTime.now();
          _notifyCacheUpdated();
          return List<Category>.unmodifiable(list);
        });

    _categoryPending[key] = future;
    return future.whenComplete(() {
      if (identical(_categoryPending[key], future)) {
        _categoryPending.remove(key);
      }
    });
  }

  void _scheduleAuthorRefresh({
    required String key,
    String? search,
    required bool auth,
  }) {
    if (_authorPending[key] != null) return;
    _fetchAuthorsFromApi(key: key, search: search, auth: auth)
        .catchError((_) => <Author>[]);
  }

  Future<List<Author>> _fetchAuthorsFromApi({
    required String key,
    String? search,
    required bool auth,
  }) {
    final future = _client
        .getJson(
          '/api/authors',
          query: {if (search != null && search.isNotEmpty) 'search': search},
          auth: auth,
        )
        .then((json) {
          final data = json['data'];
          final list = data is List
              ? data
                    .whereType<Map<String, dynamic>>()
                    .map(Author.fromJson)
                    .toList(growable: false)
              : <Author>[];
          _authorCache[key] = list;
          _authorCacheTimestamp[key] = DateTime.now();
          _notifyCacheUpdated();
          return List<Author>.unmodifiable(list);
        });

    _authorPending[key] = future;
    return future.whenComplete(() {
      if (identical(_authorPending[key], future)) {
        _authorPending.remove(key);
      }
    });
  }

  void _notifyCacheUpdated() {
    _cacheUpdateVersion.value++;
  }

  void _scheduleBookRefresh({
    required String key,
    required String ownerKey,
    required int page,
    required int perPage,
    String? search,
    int? categoryId,
    int? authorId,
    String? status,
    required bool auth,
  }) {
    if (_bookPending[key] != null) return;
    _fetchBooksFromApi(
      key: key,
      ownerKey: ownerKey,
      page: page,
      perPage: perPage,
      search: search,
      categoryId: categoryId,
      authorId: authorId,
      status: status,
      auth: auth,
    ).catchError((_) => PaginatedResult<Book>(
          data: const [],
          currentPage: page,
          lastPage: page,
          perPage: perPage,
          total: 0,
        ));
  }

  Future<PaginatedResult<Book>> _fetchBooksFromApi({
    required String key,
    required String ownerKey,
    required int page,
    required int perPage,
    String? search,
    int? categoryId,
    int? authorId,
    String? status,
    required bool auth,
  }) {
    final future = _client
        .getJson(
          '/api/books',
          query: {
            'page': page,
            'per_page': perPage,
            if (search != null && search.isNotEmpty) 'search': search,
            if (categoryId != null) 'category_id': categoryId,
            if (authorId != null) 'author_id': authorId,
            if (status != null && status.isNotEmpty) 'status': status,
          },
          auth: auth,
        )
        .then((json) {
          final result = PaginatedResult.fromJson(
            json,
            (item) => Book.fromJson(item),
          );
          final shouldStore = !auth || _currentOwnerKey == ownerKey;
          if (shouldStore) {
            _bookCache[key] = result;
            _bookCacheTimestamp[key] = DateTime.now();
            _notifyCacheUpdated();
          }
          return result;
        });

    _bookPending[key] = future;
    return future.whenComplete(() {
      if (identical(_bookPending[key], future)) {
        _bookPending.remove(key);
      }
    });
  }

  void _scheduleAllBooksRefresh({
    required String ownerKey,
    required bool auth,
  }) {
    if (_allBooksPending != null) return;
    _fetchAllBooksFromApi(ownerKey: ownerKey, auth: auth)
        .catchError((_) => <Book>[]);
  }

  Future<List<Book>> _fetchAllBooksFromApi({
    required String ownerKey,
    required bool auth,
  }) {
    final future = _fetchAllBooks(auth: auth).then((books) {
      if (_allBooksCacheKey == ownerKey) {
        _allBooksCache = books;
        _allBooksCacheTimestamp = DateTime.now();
        _notifyCacheUpdated();
      }
      return List<Book>.unmodifiable(books);
    });

    if (_allBooksCacheKey == ownerKey) {
      _allBooksPending = future;
    }
    return future.whenComplete(() {
      if (_allBooksCacheKey == ownerKey &&
          identical(_allBooksPending, future)) {
        _allBooksPending = null;
      }
    });
  }

  void _scheduleReviewsRefresh({required int bookId, required bool auth}) {
    if (_reviewsPending[bookId] != null) return;
    _fetchReviewsFromApi(bookId: bookId, auth: auth)
        .catchError((_) => <String, dynamic>{});
  }

  Future<Map<String, dynamic>> _fetchReviewsFromApi({
    required int bookId,
    required bool auth,
  }) {
    final future = _client
        .getJson('/api/books/$bookId/reviews', auth: auth)
        .then((json) {
          final reviewsData = json['reviews'];
          final reviews = reviewsData is List
              ? reviewsData
                    .whereType<Map<String, dynamic>>()
                    .map(BookReview.fromJson)
                    .toList(growable: false)
              : <BookReview>[];

          double averageRating = 0.0;
          int totalReviews = 0;
          Map<int, int> ratingBreakdown = {};

          final meta = json['meta'];
          if (meta is Map<String, dynamic>) {
            averageRating = (meta['average_rating'] as num?)?.toDouble() ?? 0.0;
            totalReviews = (meta['total_reviews'] as num?)?.toInt() ?? 0;

            final breakdown = meta['rating_breakdown'];
            if (breakdown is Map) {
              breakdown.forEach((key, value) {
                final rating = int.tryParse(key.toString());
                final count = value is int
                    ? value
                    : (value as num?)?.toInt() ?? 0;
                if (rating != null) {
                  ratingBreakdown[rating] = count;
                }
              });
            }
          } else {
            averageRating = (json['average_rating'] as num?)?.toDouble() ?? 0.0;
            totalReviews = (json['total_reviews'] as num?)?.toInt() ?? 0;

            final breakdown = json['rating_breakdown'];
            if (breakdown is Map) {
              breakdown.forEach((key, value) {
                final rating = int.tryParse(key.toString());
                final count = value is int
                    ? value
                    : (value as num?)?.toInt() ?? 0;
                if (rating != null) {
                  ratingBreakdown[rating] = count;
                }
              });
            }
          }

          if (totalReviews == 0 && reviews.isNotEmpty) {
            totalReviews = reviews.length;
            final sum = reviews.fold<int>(0, (sum, r) => sum + r.rating);
            averageRating = sum / reviews.length;

            for (var review in reviews) {
              ratingBreakdown[review.rating] =
                  (ratingBreakdown[review.rating] ?? 0) + 1;
            }
          }

          final result = {
            'reviews': reviews,
            'average_rating': averageRating,
            'total_reviews': totalReviews,
            'rating_breakdown': ratingBreakdown,
          };

          _reviewsCache[bookId] = result;
          _reviewsCacheTimestamp[bookId] = DateTime.now();
          _notifyCacheUpdated();
          return result;
        });

    _reviewsPending[bookId] = future;
    return future.whenComplete(() {
      if (identical(_reviewsPending[bookId], future)) {
        _reviewsPending.remove(bookId);
      }
    });
  }

  void _scheduleUserReviewRefresh(int bookId) {
    if (_userReviewPending[bookId] != null) return;
    _fetchUserReviewFromApi(bookId: bookId).catchError((_) => null);
  }

  Future<BookReview?> _fetchUserReviewFromApi({required int bookId}) {
    Future<BookReview?> loader() async {
      try {
        final json = await _client.getJson(
          '/api/books/$bookId/my-review',
          auth: true,
        );

        final payload = json['data'] ?? json['review'];
        if (payload == null) {
          _userReviewCache[bookId] = null;
          _userReviewCacheTimestamp[bookId] = DateTime.now();
          _notifyCacheUpdated();
          return null;
        }

        Map<String, dynamic>? reviewJson;
        if (payload is Map<String, dynamic>) {
          reviewJson = payload;
        } else if (payload is Map) {
          reviewJson = Map<String, dynamic>.from(payload);
        }

        if (reviewJson == null) {
          _userReviewCache.remove(bookId);
          _userReviewCacheTimestamp.remove(bookId);
          return null;
        }

        final review = BookReview.fromJson(reviewJson);
        _userReviewCache[bookId] = review;
        _userReviewCacheTimestamp[bookId] = DateTime.now();
        _notifyCacheUpdated();
        return review;
      } on ApiException catch (error) {
        final message = error.message.toLowerCase();
        if (error.statusCode == 404 ||
            message.contains('not found') ||
            message.contains('could not be found')) {
          _userReviewCache[bookId] = null;
          _userReviewCacheTimestamp[bookId] = DateTime.now();
          _notifyCacheUpdated();
          return null;
        }
        _userReviewCache.remove(bookId);
        _userReviewCacheTimestamp.remove(bookId);
        return null;
      } catch (_) {
        _userReviewCache.remove(bookId);
        _userReviewCacheTimestamp.remove(bookId);
        return null;
      }
    }

    final future = loader();
    _userReviewPending[bookId] = future;
    return future.whenComplete(() {
      if (identical(_userReviewPending[bookId], future)) {
        _userReviewPending.remove(bookId);
      }
    });
  }

  // ==================== EXISTING METHODS ====================

  Future<List<Category>> fetchCategories({
    String? search,
    bool auth = false,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey('categories', {
      'search': search?.trim().toLowerCase(),
      'auth': auth,
    });

    if (forceRefresh) {
      _categoryCache.remove(key);
      _categoryPending.remove(key);
      _categoryCacheTimestamp.remove(key);
    } else {
      final cached = _categoryCache[key];
      if (cached != null) {
        final stale = _shouldRefreshCache('categories', key);
        if (stale) {
          _scheduleCategoryRefresh(
            key: key,
            search: search,
            auth: auth,
          );
        }
        return Future.value(List<Category>.unmodifiable(cached));
      }
      final pending = _categoryPending[key];
      if (pending != null) return pending;
    }

    return _fetchCategoriesFromApi(
      key: key,
      search: search,
      auth: auth,
    );
  }

  Future<Category> getCategory(int id, {bool auth = false}) async {
    final json = await _client.getJson('/api/categories/$id', auth: auth);
    return Category.fromJson(_unwrap(json));
  }

  /// Simplified method to get all categories (convenience wrapper)
  Future<List<Category>> getCategories({bool forceRefresh = false}) async {
    return fetchCategories(auth: true, forceRefresh: forceRefresh);
  }

  Future<List<Author>> fetchAuthors({
    String? search,
    bool auth = false,
    bool forceRefresh = false,
  }) async {
    final key = _cacheKey('authors', {
      'search': search?.trim().toLowerCase(),
      'auth': auth,
    });

    if (forceRefresh) {
      _authorCache.remove(key);
      _authorPending.remove(key);
      _authorCacheTimestamp.remove(key);
    } else {
      final cached = _authorCache[key];
      if (cached != null) {
        final stale = _shouldRefreshCache('authors', key);
        if (stale) {
          _scheduleAuthorRefresh(
            key: key,
            search: search,
            auth: auth,
          );
        }
        return Future.value(List<Author>.unmodifiable(cached));
      }
      final pending = _authorPending[key];
      if (pending != null) return pending;
    }

    return _fetchAuthorsFromApi(
      key: key,
      search: search,
      auth: auth,
    );
  }

  Future<Author> getAuthor(int id, {bool auth = false}) async {
    final json = await _client.getJson('/api/authors/$id', auth: auth);
    return Author.fromJson(_unwrap(json));
  }

  Future<PaginatedResult<Book>> fetchBooks({
    int page = 1,
    int perPage = 12,
    String? search,
    int? categoryId,
    int? authorId,
    String? status,
    bool auth = false,
    bool forceRefresh = false,
  }) async {
    final ownerKey = await _prepareOwnerKey(auth: auth);
    final key = _cacheKey('books', {
      'page': page,
      'per_page': perPage,
      'search': search?.trim().toLowerCase(),
      'category_id': categoryId,
      'author_id': authorId,
      'status': status?.trim().toLowerCase(),
      'auth': auth,
      'owner': ownerKey,
    });

    if (forceRefresh) {
      _bookCache.remove(key);
      _bookPending.remove(key);
      _bookCacheTimestamp.remove(key);
    } else {
      final cached = _bookCache[key];
      if (cached != null) {
        final stale = _shouldRefreshCache('books', key);
        if (stale) {
          _scheduleBookRefresh(
            key: key,
            ownerKey: ownerKey,
            page: page,
            perPage: perPage,
            search: search,
            categoryId: categoryId,
            authorId: authorId,
            status: status,
            auth: auth,
          );
        }
        return Future.value(cached);
      }
      final pending = _bookPending[key];
      if (pending != null) return pending;
    }

    return _fetchBooksFromApi(
      key: key,
      ownerKey: ownerKey,
      page: page,
      perPage: perPage,
      search: search,
      categoryId: categoryId,
      authorId: authorId,
      status: status,
      auth: auth,
    );
  }

  Future<List<Book>> getAllBooks({
    bool forceRefresh = false,
    bool auth = false,
  }) async {
    final ownerKey = await _prepareOwnerKey(auth: auth);

    if (_allBooksCacheKey != ownerKey) {
      _allBooksCache = null;
      _allBooksPending = null;
      _allBooksCacheKey = ownerKey;
      _allBooksCacheTimestamp = null;
    }

    if (forceRefresh) {
      _allBooksCache = null;
      _allBooksPending = null;
      _allBooksCacheTimestamp = null;
    } else {
      final cached = _allBooksCache;
      if (cached != null) {
        final stale = _isCacheStale(_allBooksCacheTimestamp);
        if (stale) {
          _scheduleAllBooksRefresh(ownerKey: ownerKey, auth: auth);
        }
        return Future.value(List<Book>.unmodifiable(cached));
      }
      final pending = _allBooksPending;
      if (pending != null) return pending;
    }

    return _fetchAllBooksFromApi(
      ownerKey: ownerKey,
      auth: auth,
    );
  }

  Future<Book> getBook(int id, {bool auth = false}) async {
    final json = await _client.getJson('/api/books/$id', auth: auth);
    return Book.fromJson(_unwrap(json));
  }

  Future<String> askBookQuestion(int bookId, String question) async {
    final response = await _client.postJson(
      '/api/books/$bookId/ask',
      body: {'question': question},
      auth: true,
    );

    final answer = response['answer']?.toString();
    if (answer == null || answer.isEmpty) {
      throw ApiException('Failed to get AI answer');
    }

    return answer;
  }

  Future<ExtractedText> extractText(int bookId, String? pages) async {
    final payload = <String, dynamic>{};
    final trimmed = pages?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      payload['pages'] = trimmed;
    }

    try {
      final response = await _client.postJson(
        '/api/books/$bookId/extract-text',
        body: payload.isEmpty ? null : payload,
        auth: true,
      );
      return ExtractedText.fromJson(response);
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to extract text: $e');
    }
  }

  Future<List<Book>> _fetchAllBooks({bool auth = false}) async {
    const perPage = 100;
    final List<Book> books = [];
    var page = 1;
    while (true) {
      final json = await _client.getJson(
        '/api/books',
        query: {'page': page, 'per_page': perPage},
        auth: auth,
      );
      final result = PaginatedResult.fromJson(
        json,
        (item) => Book.fromJson(item),
      );
      books.addAll(result.data);
      if (page >= result.lastPage) break;
      page += 1;
    }
    return books;
  }

  // ==================== REVIEW METHODS ====================

  Future<Map<String, dynamic>> getBookReviews(
    int bookId, {
    bool forceRefresh = false,
    bool auth = true,
  }) async {
    await _prepareOwnerKey(auth: auth);

    if (forceRefresh) {
      _reviewsCache.remove(bookId);
      _reviewsPending.remove(bookId);
      _reviewsCacheTimestamp.remove(bookId);
    } else {
      final cached = _reviewsCache[bookId];
      if (cached != null) {
        final stale = _shouldRefreshCache('reviews', bookId.toString());
        if (stale) {
          _scheduleReviewsRefresh(bookId: bookId, auth: auth);
        }
        return Future.value(cached);
      }
      final pending = _reviewsPending[bookId];
      if (pending != null) return pending;
    }

    return _fetchReviewsFromApi(
      bookId: bookId,
      auth: auth,
    );
  }

  Future<BookReview?> getUserReview(
    int bookId, {
    bool forceRefresh = false,
  }) async {
    await _prepareOwnerKey(auth: true);

    if (forceRefresh) {
      _userReviewCache.remove(bookId);
      _userReviewPending.remove(bookId);
      _userReviewCacheTimestamp.remove(bookId);
    } else {
      if (_userReviewCache.containsKey(bookId)) {
        final stale = _shouldRefreshCache('userReview', bookId.toString());
        if (stale) {
          _scheduleUserReviewRefresh(bookId);
        }
        return Future.value(_userReviewCache[bookId]);
      }
      final pending = _userReviewPending[bookId];
      if (pending != null) return pending;
    }

    return _fetchUserReviewFromApi(bookId: bookId);
  }

  // ✅ FIXED: submitReview with cache invalidation
  Future<BookReview> submitReview({
    required int bookId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    final trimmedTitle = title?.trim();
    final trimmedComment = comment?.trim();
    final payload = <String, dynamic>{
      'rating': rating,
      if (trimmedTitle != null && trimmedTitle.isNotEmpty)
        'title': trimmedTitle,
      if (trimmedComment != null && trimmedComment.isNotEmpty)
        'comment': trimmedComment,
    };
    final json = await _client.postJson(
      '/api/books/$bookId/reviews',
      body: payload,
      auth: true,
    );

    // Invalidate cache
    _reviewsCache.remove(bookId);
    _reviewsCacheTimestamp.remove(bookId);
    _reviewsPending.remove(bookId);
    _userReviewCache.remove(bookId);
    _userReviewCacheTimestamp.remove(bookId);
    _userReviewPending.remove(bookId);

    return BookReview.fromJson(_unwrap(json));
  }

  // ✅ FIXED: updateReview with cache invalidation
  Future<BookReview> updateReview({
    required int bookId,
    required int reviewId,
    required int rating,
    String? title,
    String? comment,
  }) async {
    final trimmedTitle = title?.trim();
    final trimmedComment = comment?.trim();
    final payload = <String, dynamic>{
      'rating': rating,
      if (trimmedTitle != null && trimmedTitle.isNotEmpty)
        'title': trimmedTitle,
      if (trimmedComment != null && trimmedComment.isNotEmpty)
        'comment': trimmedComment,
    };
    final json = await _client.putJson(
      '/api/books/$bookId/reviews/$reviewId',
      body: payload,
      auth: true,
    );

    // Invalidate cache
    _reviewsCache.remove(bookId);
    _reviewsCacheTimestamp.remove(bookId);
    _reviewsPending.remove(bookId);
    _userReviewCache.remove(bookId);
    _userReviewCacheTimestamp.remove(bookId);
    _userReviewPending.remove(bookId);

    return BookReview.fromJson(_unwrap(json));
  }

  // ==================== BOOK CRUD METHODS ====================

  Future<Book> createBook(Map<String, dynamic> payload) async {
    final json = await _client.postJson(
      '/api/books',
      body: payload,
      auth: true,
    );
    invalidateBooks();
    return Book.fromJson(_unwrap(json));
  }

  Future<Book> updateBook(int id, Map<String, dynamic> payload) async {
    final json = await _client.putJson(
      '/api/books/$id',
      body: payload,
      auth: true,
    );
    invalidateBooks();
    return Book.fromJson(_unwrap(json));
  }

  Future<void> deleteBook(int id) async {
    await _client.deleteJson('/api/books/$id', auth: true);
    invalidateBooks();
  }

  // ==================== AUTHOR CRUD METHODS ====================

  Future<Author> createAuthor(Map<String, dynamic> payload) async {
    final json = await _client.postJson(
      '/api/authors',
      body: payload,
      auth: true,
    );
    invalidateAuthors();
    return Author.fromJson(_unwrap(json));
  }

  Future<Author> updateAuthor(int id, Map<String, dynamic> payload) async {
    final json = await _client.putJson(
      '/api/authors/$id',
      body: payload,
      auth: true,
    );
    invalidateAuthors();
    return Author.fromJson(_unwrap(json));
  }

  Future<void> deleteAuthor(int id) async {
    await _client.deleteJson('/api/authors/$id', auth: true);
    invalidateAuthors();
  }

  // ==================== CACHE INVALIDATION ====================

  void invalidateCache() {
    _categoryCache.clear();
    _categoryPending.clear();
    _categoryCacheTimestamp.clear();

    _authorCache.clear();
    _authorPending.clear();
    _authorCacheTimestamp.clear();

    _bookCache.clear();
    _bookPending.clear();
    _bookCacheTimestamp.clear();

    _allBooksCache = null;
    _allBooksPending = null;
    _allBooksCacheKey = null;
    _allBooksCacheTimestamp = null;

    _reviewsCache.clear();
    _reviewsPending.clear();
    _reviewsCacheTimestamp.clear();

    _userReviewCache.clear();
    _userReviewPending.clear();
    _userReviewCacheTimestamp.clear();
    _notifyCacheUpdated();
  }

  void invalidateBooks() {
    _bookCache.clear();
    _bookPending.clear();
    _bookCacheTimestamp.clear();

    _allBooksCache = null;
    _allBooksPending = null;
    _allBooksCacheTimestamp = null;
    _notifyCacheUpdated();
  }

  void invalidateAuthors() {
    _authorCache.clear();
    _authorPending.clear();
    _authorCacheTimestamp.clear();
    _notifyCacheUpdated();
  }

  void invalidateReviews(int bookId) {
    _reviewsCache.remove(bookId);
    _reviewsPending.remove(bookId);
    _reviewsCacheTimestamp.remove(bookId);

    _userReviewCache.remove(bookId);
    _userReviewPending.remove(bookId);
    _userReviewCacheTimestamp.remove(bookId);
    _notifyCacheUpdated();
  }

  // ==================== OTHER METHODS ====================

  void markBookOwned(int bookId, {int? availableCopies}) {
    Book applyUpdate(Book book) {
      final newCopies =
          availableCopies ??
          (book.availableCopies > 0 ? book.availableCopies - 1 : 0);
      if (book.owned && book.availableCopies == newCopies) {
        return book;
      }
      final sanitizedCopies = newCopies < 0 ? 0 : newCopies;
      return book.copyWith(owned: true, availableCopies: sanitizedCopies);
    }

    if (_allBooksCache != null) {
      final updated = _allBooksCache!
          .map((book) => book.id == bookId ? applyUpdate(book) : book)
          .toList(growable: false);
      if (!_listEquals(_allBooksCache!, updated)) {
        _allBooksCache = updated;
      }
    }

    _bookCache.updateAll((key, paginated) {
      var listChanged = false;
      final updatedData = paginated.data
          .map((book) {
            if (book.id != bookId) return book;
            final updatedBook = applyUpdate(book);
            if (!identical(book, updatedBook)) {
              listChanged = true;
            }
            return updatedBook;
          })
          .toList(growable: false);

      if (!listChanged) {
        return paginated;
      }

      return PaginatedResult(
        data: updatedData,
        currentPage: paginated.currentPage,
        lastPage: paginated.lastPage,
        perPage: paginated.perPage,
        total: paginated.total,
      );
    });

    // Notify listeners so UI can refresh inventories.
    if (_ownedBookNotifier.value == bookId) {
      _ownedBookNotifier.value = null;
    }
    _ownedBookNotifier.value = bookId;
  }

  bool _listEquals(List<Book> a, List<Book> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id ||
          a[i].owned != b[i].owned ||
          a[i].availableCopies != b[i].availableCopies) {
        return false;
      }
    }
    return true;
  }

  String _cacheKey(String prefix, Map<String, Object?> params) {
    final entries =
        params.entries
            .where((e) => e.value != null && e.value.toString().isNotEmpty)
            .map((e) => '${e.key}=${e.value}')
            .toList()
          ..sort();
    return '$prefix:${entries.join('&')}';
  }

  /// Vote on a review (like or dislike)
  Future<Map<String, dynamic>> voteReview(
    int reviewId,
    String voteType, // 'like' or 'dislike'
  ) async {
    if (voteType != 'like' && voteType != 'dislike') {
      throw ArgumentError('voteType must be "like" or "dislike"');
    }

    try {
      final response = await _client.postJson(
        '/api/reviews/$reviewId/vote',
        body: {'vote_type': voteType},
        auth: true,
      );

      return {
        'success': response['success'] as bool? ?? true,
        'action': response['action'] as String? ?? 'created',
        'helpful_count': response['helpful_count'] as int? ?? 0,
        'not_helpful_count': response['not_helpful_count'] as int? ?? 0,
        'user_vote': response['user_vote'] as String?,
      };
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to vote on review: $e');
    }
  }

  /// Remove vote from a review
  Future<Map<String, dynamic>> removeVote(int reviewId) async {
    try {
      final response = await _client.deleteJson(
        '/api/reviews/$reviewId/vote',
        auth: true,
      );

      return {
        'success': response['success'] as bool? ?? true,
        'helpful_count': response['helpful_count'] as int? ?? 0,
        'not_helpful_count': response['not_helpful_count'] as int? ?? 0,
        'user_vote': null,
      };
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to remove vote: $e');
    }
  }

  /// Get vote status for a review
  Future<Map<String, dynamic>> getVoteStatus(int reviewId) async {
    try {
      final response = await _client.getJson(
        '/api/reviews/$reviewId/vote',
        auth: true,
      );

      return {
        'review_id': response['review_id'] as int,
        'helpful_count': response['helpful_count'] as int? ?? 0,
        'not_helpful_count': response['not_helpful_count'] as int? ?? 0,
        'user_vote': response['user_vote'] as String?,
      };
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Failed to get vote status: $e');
    }
  }

  /// Toggle like on a review (helper method)
  Future<Map<String, dynamic>> toggleLike(
    int reviewId,
    String? currentVote,
  ) async {
    if (currentVote == 'like') {
      // Remove like
      return await removeVote(reviewId);
    } else {
      // Add like (will auto-remove dislike if exists)
      return await voteReview(reviewId, 'like');
    }
  }

  /// Toggle dislike on a review (helper method)
  Future<Map<String, dynamic>> toggleDislike(
    int reviewId,
    String? currentVote,
  ) async {
    if (currentVote == 'dislike') {
      // Remove dislike
      return await removeVote(reviewId);
    } else {
      // Add dislike (will auto-remove like if exists)
      return await voteReview(reviewId, 'dislike');
    }
  }

  Future<String> _resolveOwnerKey({required bool auth}) async {
    if (!auth) return '__public__';
    final id = await AuthService.instance.getCurrentActiveId();
    if (id == null || id.isEmpty) return '__guest__';
    return 'user:$id';
  }

  Future<String> _prepareOwnerKey({required bool auth}) async {
    final key = await _resolveOwnerKey(auth: auth);
    if (auth && _currentOwnerKey != key) {
      _currentOwnerKey = key;
      _clearUserScopedCaches();
    }
    return key;
  }

  void _clearUserScopedCaches() {
    _allBooksCache = null;
    _allBooksPending = null;
    _allBooksCacheKey = null;
    _bookCache.clear();
    _bookPending.clear();
    _reviewsCache.clear();
    _reviewsPending.clear();
    _userReviewCache.clear();
    _userReviewPending.clear();
    _ownedBookNotifier.value = null;
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
}
