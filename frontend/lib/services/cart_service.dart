import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/models/cart_item.dart';
import 'package:my_flutter_app/services/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CartItemAlreadyExistsException implements Exception {
  const CartItemAlreadyExistsException(this.bookId);
  final int bookId;
}

class BookAlreadyOwnedException implements Exception {
  const BookAlreadyOwnedException(this.bookId);
  final int bookId;
}

class CartService extends ChangeNotifier {
  CartService._() {
    _load();
  }

  static final CartService instance = CartService._();

  static const _storageKey = 'cart_items';

  final List<CartItem> _items = [];

  bool _loaded = false;
  Future<void>? _loadingFuture;

  List<CartItem> get items => List.unmodifiable(_items);
  bool get isLoaded => _loaded;
  bool get isEmpty => _items.isEmpty;
  int get totalQuantity => _items.length;
  int get totalCredits =>
      _items.fold<int>(0, (sum, item) => sum + item.totalCredit);

  CartItem? itemFor(int bookId) {
    try {
      return _items.firstWhere((item) => item.bookId == bookId);
    } catch (_) {
      return null;
    }
  }

  Future<void> ensureLoaded() => _load();

  Future<void> addBook(Book book) async {
    await _load();

    final existingIndex = _items.indexWhere((item) => item.bookId == book.id);
    if (existingIndex >= 0) {
      throw CartItemAlreadyExistsException(book.id);
    }
    if (book.owned) {
      throw BookAlreadyOwnedException(book.id);
    }

    _items.add(CartItem.fromBook(book));

    await _persist();
    notifyListeners();
  }

  Future<void> updateQuantity(int bookId, int quantity) async {
    await _load();

    final index = _items.indexWhere((item) => item.bookId == bookId);
    if (index < 0) return;

    if (quantity <= 0) {
      _items.removeAt(index);

      await _persist();
      notifyListeners();
      return;
    } else {
      return;
    }
  }

  Future<void> remove(int bookId) async {
    await _load();
    _items.removeWhere((item) => item.bookId == bookId);
    await _persist();
    notifyListeners();
  }

  Future<void> clear() async {
    await _load();
    if (_items.isEmpty) return;
    _items.clear();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = _items.map((item) => item.toJson()).toList(growable: false);
      await prefs.setString(_storageKey, jsonEncode(data));
    } catch (error, stack) {
      AppLogger.e('Failed to persist cart', error, stack);
    }
  }

  Future<void> _load() {
    if (_loaded) {
      return Future.value();
    }
    if (_loadingFuture != null) {
      return _loadingFuture!;
    }

    _loadingFuture = () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(_storageKey);
        if (raw == null || raw.isEmpty) {
          return;
        }

        final decoded = jsonDecode(raw);
        if (decoded is! List) {
          AppLogger.w('Cart data is not a list; ignoring');
          return;
        }

        _items
          ..clear()
          ..addAll(() {
            final seen = <int>{};
            return decoded
                .whereType<Map>()
                .map((item) => item.cast<String, dynamic>())
                .map(CartItem.fromJson)
                .where((item) {
                  if (seen.contains(item.bookId)) {
                    return false;
                  }
                  seen.add(item.bookId);
                  return true;
                })
                .toList(growable: false);
          }());
      } catch (error, stack) {
        AppLogger.e('Failed to load cart', error, stack);
        _items.clear();
      } finally {
        _loaded = true;
        _loadingFuture = null;
        notifyListeners();
      }
    }();

    return _loadingFuture!;
  }
}
