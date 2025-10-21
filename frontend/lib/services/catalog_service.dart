import 'package:flutter/foundation.dart' show ValueListenable, ValueNotifier;
import 'package:flutter/material.dart';
import 'package:my_flutter_app/models/author.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/models/book_review.dart';
import 'package:my_flutter_app/models/category.dart';
import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/auth_service.dart';

class CatalogService {
  CatalogService._();

  static final CatalogService instance = CatalogService._();

  final ApiClient _client = ApiClient.instance;

  final Map<String, List<Category>> _categoryCache = {};
  final Map<String, Future<List<Category>>> _categoryPending = {};
  final Map<String, List<Author>> _authorCache = {};
  final Map<String, Future<List<Author>>> _authorPending = {};
  final Map<String, PaginatedResult<Book>> _bookCache = {};
  final Map<String, Future<PaginatedResult<Book>>> _bookPending = {};
  List<Book>? _allBooksCache;
  Future<List<Book>>? _allBooksPending;
  String? _allBooksCacheKey;
  String? _currentOwnerKey;

  final Map<int, Map<String, dynamic>> _reviewsCache = {};
  final Map<int, Future<Map<String, dynamic>>> _reviewsPending = {};
  final Map<int, BookReview?> _userReviewCache = {};
  final Map<int, Future<BookReview?>> _userReviewPending = {};

  final ValueNotifier<int?> _ownedBookNotifier = ValueNotifier<int?>(null);

  ValueListenable<int?> get ownedBookUpdates => _ownedBookNotifier;

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

    if (!forceRefresh) {
      final cached = _categoryCache[key];
      if (cached != null) return List<Category>.unmodifiable(cached);
      final pending = _categoryPending[key];
      if (pending != null) return pending;
    } else {
      _categoryCache.remove(key);
      _categoryPending.remove(key);
    }

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
              : const <Category>[];
          _categoryCache[key] = list;
          _categoryPending.remove(key);
          return List<Category>.unmodifiable(list);
        })
        .catchError((error) {
          _categoryPending.remove(key);
          throw error;
        });

    _categoryPending[key] = future;
    return future;
  }

  Future<Category> getCategory(int id, {bool auth = false}) async {
    final json = await _client.getJson('/api/categories/$id', auth: auth);
    return Category.fromJson(_unwrap(json));
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

    if (!forceRefresh) {
      final cached = _authorCache[key];
      if (cached != null) return List<Author>.unmodifiable(cached);
      final pending = _authorPending[key];
      if (pending != null) return pending;
    } else {
      _authorCache.remove(key);
      _authorPending.remove(key);
    }

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
              : const <Author>[];
          _authorCache[key] = list;
          _authorPending.remove(key);
          return List<Author>.unmodifiable(list);
        })
        .catchError((error) {
          _authorPending.remove(key);
          throw error;
        });

    _authorPending[key] = future;
    return future;
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

    if (!forceRefresh) {
      final cached = _bookCache[key];
      if (cached != null) return cached;
      final pending = _bookPending[key];
      if (pending != null) return pending;
    } else {
      _bookCache.remove(key);
      _bookPending.remove(key);
    }

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
          _bookCache[key] = result;
          _bookPending.remove(key);
          return result;
        })
        .catchError((error) {
          _bookPending.remove(key);
          throw error;
        });

    _bookPending[key] = future;
    return future;
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
    }

    if (!forceRefresh) {
      final cached = _allBooksCache;
      if (cached != null) return List<Book>.unmodifiable(cached);
      final pending = _allBooksPending;
      if (pending != null) return pending;
    } else {
      _allBooksCache = null;
      _allBooksPending = null;
    }

    final future = _fetchAllBooks(auth: auth)
        .then((books) {
          if (_allBooksCacheKey == ownerKey) {
            _allBooksCache = books;
            _allBooksPending = null;
          }
          return List<Book>.unmodifiable(books);
        })
        .catchError((error) {
          if (_allBooksCacheKey == ownerKey) {
            _allBooksPending = null;
          }
          throw error;
        });

    if (_allBooksCacheKey == ownerKey) {
      _allBooksPending = future;
    }
    return future;
  }

  Future<Book> getBook(int id, {bool auth = false}) async {
    final json = await _client.getJson('/api/books/$id', auth: auth);
    return Book.fromJson(_unwrap(json));
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
    }

    if (!forceRefresh) {
      final cached = _reviewsCache[bookId];
      if (cached != null) return cached;
      final pending = _reviewsPending[bookId];
      if (pending != null) return pending;
    }

    final future = _client
        .getJson('/api/books/$bookId/reviews', auth: auth)
        .then((json) {
          debugPrint('📦 Raw API Response:');
          debugPrint('  - Full JSON keys: ${json.keys.join(', ')}');

          final reviewsData = json['reviews'];
          final reviews = reviewsData is List
              ? reviewsData
                    .whereType<Map<String, dynamic>>()
                    .map(BookReview.fromJson)
                    .toList(growable: false)
              : const <BookReview>[];

          debugPrint('📝 Parsed ${reviews.length} reviews');

          double averageRating = 0.0;
          int totalReviews = 0;
          Map<int, int> ratingBreakdown = {}; // 👈 THÊM

          // Parse từ meta
          final meta = json['meta'];
          if (meta is Map<String, dynamic>) {
            averageRating = (meta['average_rating'] as num?)?.toDouble() ?? 0.0;
            totalReviews = (meta['total_reviews'] as num?)?.toInt() ?? 0;

            // ✅ Parse rating breakdown
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
              debugPrint('✅ Rating breakdown: $ratingBreakdown');
            }
          } else {
            // Fallback: parse from root level (new API format)
            averageRating = (json['average_rating'] as num?)?.toDouble() ?? 0.0;
            totalReviews = (json['total_reviews'] as num?)?.toInt() ?? 0;

            // ✅ Parse rating breakdown from root level
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

          // Calculate from reviews if still empty
          if (totalReviews == 0 && reviews.isNotEmpty) {
            totalReviews = reviews.length;
            final sum = reviews.fold<int>(0, (sum, r) => sum + r.rating);
            averageRating = sum / reviews.length;

            // ✅ Calculate breakdown from reviews
            for (var review in reviews) {
              ratingBreakdown[review.rating] =
                  (ratingBreakdown[review.rating] ?? 0) + 1;
            }
            debugPrint(
              '✅ Calculated from reviews: avg=$averageRating, breakdown=$ratingBreakdown',
            );
          }

          final result = {
            'reviews': reviews,
            'average_rating': averageRating,
            'total_reviews': totalReviews,
            'rating_breakdown': ratingBreakdown, // 👈 THÊM
          };

          _reviewsCache[bookId] = result;
          _reviewsPending.remove(bookId);
          return result;
        })
        .catchError((error) {
          debugPrint('❌ Error in getBookReviews: $error');
          _reviewsPending.remove(bookId);
          throw error;
        });

    _reviewsPending[bookId] = future;
    return future;
  }

  // ✅ FIXED: getUserReview with cache
  Future<BookReview?> getUserReview(
    int bookId, {
    bool forceRefresh = false,
  }) async {
    await _prepareOwnerKey(auth: true);
    if (forceRefresh) {
      _userReviewCache.remove(bookId);
      _userReviewPending.remove(bookId);
    }

    if (!forceRefresh) {
      if (_userReviewCache.containsKey(bookId)) {
        return _userReviewCache[bookId];
      }
      final pending = _userReviewPending[bookId];
      if (pending != null) return pending;
    }

    // ✅ Tạo async function riêng với try-catch
    Future<BookReview?> fetchUserReview() async {
      try {
        debugPrint('Fetching user review...');
        final json = await _client.getJson(
          '/api/books/$bookId/my-review',
          auth: true,
        );

        debugPrint('User review response received');
        final payload = json['data'] ?? json['review'];
        if (payload == null) {
          debugPrint('User review payload is null');
          _userReviewCache[bookId] = null;
          _userReviewPending.remove(bookId);
          return null;
        }

        Map<String, dynamic>? reviewJson;
        if (payload is Map<String, dynamic>) {
          reviewJson = payload;
        } else if (payload is Map) {
          reviewJson = Map<String, dynamic>.from(payload);
        }

        if (reviewJson == null) {
          debugPrint('Unexpected user review payload: $payload');
          _userReviewCache[bookId] = null;
          _userReviewPending.remove(bookId);
          return null;
        }

        final review = BookReview.fromJson(reviewJson);
        _userReviewCache[bookId] = review;
        _userReviewPending.remove(bookId);
        return review;
      } catch (error) {
        debugPrint('Error fetching user review: $error');
        _userReviewCache[bookId] = null;
        _userReviewPending.remove(bookId);

        // Treat 404 or missing route as "no review yet"
        if (error is ApiException &&
            (error.statusCode == 404 ||
                error.message.contains('could not be found'))) {
          debugPrint('User has not reviewed yet');
          return null;
        }

        // Return null for other errors instead of throwing
        debugPrint('Other error, returning null');
        return null;
      }
    }


    final future = fetchUserReview();
    _userReviewPending[bookId] = future;
    return future;
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
      if (trimmedTitle != null && trimmedTitle.isNotEmpty) 'title': trimmedTitle,
      if (trimmedComment != null && trimmedComment.isNotEmpty) 'comment': trimmedComment,
    };
    final json = await _client.postJson(
      '/api/books/$bookId/reviews',
      body: payload,
      auth: true,
    );

    // Invalidate cache
    _reviewsCache.remove(bookId);
    _reviewsPending.remove(bookId);
    _userReviewCache.remove(bookId);
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
      if (trimmedTitle != null && trimmedTitle.isNotEmpty) 'title': trimmedTitle,
      if (trimmedComment != null && trimmedComment.isNotEmpty) 'comment': trimmedComment,
    };
    final json = await _client.putJson(
      '/api/books/$bookId/reviews/$reviewId',
      body: payload,
      auth: true,
    );

    // Invalidate cache
    _reviewsCache.remove(bookId);
    _reviewsPending.remove(bookId);
    _userReviewCache.remove(bookId);
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
    _authorCache.clear();
    _authorPending.clear();
    _bookCache.clear();
    _bookPending.clear();
    _allBooksCache = null;
    _allBooksPending = null;
    _allBooksCacheKey = null;
    _reviewsCache.clear();
    _reviewsPending.clear();
    _userReviewCache.clear();
    _userReviewPending.clear();
  }

  void invalidateBooks() {
    _bookCache.clear();
    _bookPending.clear();
    _allBooksCache = null;
    _allBooksPending = null;
  }

  void invalidateAuthors() {
    _authorCache.clear();
    _authorPending.clear();
  }

  void invalidateReviews(int bookId) {
    _reviewsCache.remove(bookId);
    _reviewsPending.remove(bookId);
    _userReviewCache.remove(bookId);
    _userReviewPending.remove(bookId);
  }

  // ==================== OTHER METHODS ====================

  void markBookOwned(int bookId) {
    var changed = false;

    if (_allBooksCache != null) {
      final updated = _allBooksCache!
          .map((book) => book.id == bookId ? book.copyWith(owned: true) : book)
          .toList(growable: false);
      if (!_listEquals(_allBooksCache!, updated)) {
        _allBooksCache = updated;
        changed = true;
      }
    }

    _bookCache.updateAll((key, paginated) {
      final updatedData = paginated.data
          .map((book) => book.id == bookId ? book.copyWith(owned: true) : book)
          .toList(growable: false);
      if (_listEquals(paginated.data, updatedData)) {
        return paginated;
      }
      changed = true;
      return PaginatedResult(
        data: updatedData,
        currentPage: paginated.currentPage,
        lastPage: paginated.lastPage,
        perPage: paginated.perPage,
        total: paginated.total,
      );
    });

    if (changed || _ownedBookNotifier.value != bookId) {
      _ownedBookNotifier.value = bookId;
    }
  }

  bool _listEquals(List<Book> a, List<Book> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].owned != b[i].owned) {
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
