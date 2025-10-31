import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/models/book_review.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/cart_service.dart';
import 'package:my_flutter_app/services/catalog_service.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/text_viewer_screen.dart';
import 'package:my_flutter_app/widgets/extract_text_dialog.dart';
import 'package:my_flutter_app/widgets/rating_stars.dart';
import 'package:my_flutter_app/widgets/responsive_navigation_wrapper.dart';

class BookDetailArgs {
  const BookDetailArgs({required this.bookId, this.initial});

  final int bookId;
  final Book? initial;
}

class BookDetailPage extends StatefulWidget {
  const BookDetailPage({super.key});

  static const routeName = '/book';

  @override
  State<BookDetailPage> createState() => _BookDetailPageState();
}

class _BookDetailPageState extends State<BookDetailPage> {
  final _catalogService = CatalogService.instance;
  final _orderService = OrderService.instance;
  final CartService _cartService = CartService.instance;

  Book? _book;
  bool _loading = true;
  bool _purchasing = false;
  bool _addingToCart = false;
  bool _extractingText = false;
  String? _error;

  // Review state
  List<BookReview> _reviews = [];
  double _averageRating = 0.0;
  int _totalReviews = 0;
  Map<int, int> _ratingBreakdown = {};
  bool _loadingReviews = true;
  BookReview? _userReview;
  int? _currentUserId;

  @override
  void initState() {
    super.initState();
    _cartService.ensureLoaded();
    _cartService.addListener(_onCartChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args = ModalRoute.of(context)?.settings.arguments as BookDetailArgs?;
    if (_book == null && _loading) {
      _book = args?.initial;
      final bookId = args?.bookId ?? _book?.id ?? 0;
      _loadBook(bookId);
      _loadReviews(bookId);
    }
  }

  void _onCartChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  void dispose() {
    _cartService.removeListener(_onCartChanged);
    super.dispose();
  }

  Future<void> _loadBook(int bookId) async {
    if (bookId <= 0) {
      setState(() {
        _error = 'Invalid book id';
        _loading = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final book = await _catalogService.getBook(bookId, auth: true);
      if (!mounted) return;
      setState(() => _book = book);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadCurrentUserId() async {
    try {
      final userData = await AuthService.instance.me();
      if (!mounted) return;
      setState(() {
        _currentUserId = (userData?['id'] as num?)?.toInt();
      });
    } catch (e) {
      // User not logged in or error - that's fine
      if (!mounted) return;
      setState(() => _currentUserId = null);
    }
  }

  Future<void> _loadReviews(int bookId) async {
    if (bookId <= 0) return;

    setState(() => _loadingReviews = true);

    try {
      final loggedIn = await AuthService.instance.isLoggedIn();
      debugPrint('🔐 User logged in: $loggedIn');

      // Load current user ID if logged in
      if (loggedIn) {
        await _loadCurrentUserId();
      }

      debugPrint('📥 Loading reviews...');
      final data = await _catalogService.getBookReviews(
        bookId,
        forceRefresh: false, // Use smart caching instead of force refresh
      );

      debugPrint('✅ Reviews loaded successfully');
      debugPrint('📊 Reviews count: ${(data['reviews'] as List).length}');
      debugPrint('⭐ Average rating: ${data['average_rating']}');
      debugPrint('📊 Total reviews: ${data['total_reviews']}');
      debugPrint('📊 Breakdown: ${data['rating_breakdown']}');

      BookReview? userReview;
      if (loggedIn) {
        debugPrint('👤 Loading user review...');
        userReview = await _catalogService.getUserReview(
          bookId,
          forceRefresh: false, // Use smart caching instead of force refresh
        );

        if (userReview != null) {
          debugPrint(
            '✅ User review found: ID=${userReview.id}, Rating=${userReview.rating}',
          );
        } else {
          debugPrint('ℹ️ User has not reviewed this book');
        }
      }

      if (!mounted) return;
      setState(() {
        _reviews = data['reviews'] as List<BookReview>;
        _averageRating = data['average_rating'] as double;
        _totalReviews = data['total_reviews'] as int;
        _ratingBreakdown = Map<int, int>.from(data['rating_breakdown'] as Map);
        _userReview = userReview;
        _loadingReviews = false;
      });

      debugPrint('🎉 Review section updated successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading reviews: $e');
      debugPrint('Stack trace: $stackTrace');

      if (!mounted) return;
      setState(() => _loadingReviews = false);
    }
  }

  Future<void> _submitReview(int rating, String? title, String? comment) async {
    final book = _book;
    if (book == null) return;

    final messenger = ScaffoldMessenger.of(context);
    final t = context.l10n;

    try {
      final loggedIn = await AuthService.instance.isLoggedIn();
      if (!loggedIn) {
        messenger.showSnackBar(
          SnackBar(content: Text(t.bookReviewLoginRequired)),
        );
        return;
      }

      debugPrint('📝 Submitting review: rating=$rating');

      final BookReview newReview;
      if (_userReview != null) {
        debugPrint('✏️ Updating existing review ID=${_userReview!.id}');
        newReview = await _catalogService.updateReview(
          bookId: book.id,
          reviewId: _userReview!.id,
          rating: rating,
          title: title,
          comment: comment,
        );
        debugPrint('✅ Review updated: ID=${newReview.id}');
      } else {
        debugPrint('➕ Creating new review');
        newReview = await _catalogService.submitReview(
          bookId: book.id,
          rating: rating,
          title: title,
          comment: comment,
        );
        debugPrint('✅ Review created: ID=${newReview.id}');
      }

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(content: Text(t.bookReviewSubmitSuccess)),
      );

      // Update UI immediately
      setState(() {
        if (_userReview != null) {
          // Update existing review in list
          final index = _reviews.indexWhere((r) => r.id == _userReview!.id);
          if (index != -1) {
            _reviews = List<BookReview>.from(_reviews);
            _reviews[index] = newReview;
            debugPrint('✅ Updated review in list at index $index');
          }
        } else {
          // Add new review to list
          _reviews = [newReview, ..._reviews];
          _totalReviews++;
          debugPrint('✅ Added new review to list, total now: $_totalReviews');
        }

        _userReview = newReview;

        // Recalculate average
        if (_reviews.isNotEmpty) {
          final sum = _reviews.fold<int>(0, (sum, r) => sum + r.rating);
          _averageRating = sum / _reviews.length;
          debugPrint('✅ Recalculated average: $_averageRating');
        }
      });

      debugPrint('🎉 UI updated successfully');

      // Reload from server after a short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          debugPrint('🔄 Reloading reviews from server...');
          _loadReviews(book.id);
        }
      });
    } on ApiException catch (e) {
      debugPrint('❌ API Error: ${e.message}');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e, stackTrace) {
      debugPrint('❌ Unexpected error: $e');
      debugPrint('Stack: $stackTrace');
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _addToCart(Book book, AppLocalizations t) async {
    if (_addingToCart) return;
    if (book.owned) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.bookAlreadyOwned)));
      return;
    }
    if (_cartService.itemFor(book.id) != null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.cartAlreadyContains)));
      return;
    }
    setState(() => _addingToCart = true);
    try {
      await _cartService.addBook(book);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.addedToCart)));
    } on CartItemAlreadyExistsException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.cartAlreadyContains)));
    } on BookAlreadyOwnedException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.bookAlreadyOwned)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.cartUpdateFailed)));
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  Future<void> _purchase(Book book, AppLocalizations t) async {
    if (_purchasing) return;
    if (book.owned) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.bookAlreadyOwned)));
      return;
    }
    setState(() => _purchasing = true);
    try {
      await _orderService.placeOrder(
        items: [
          {'book_id': book.id, 'quantity': 1},
        ],
      );
      if (_cartService.itemFor(book.id) != null) {
        await _cartService.remove(book.id);
      }
      if (!mounted) return;
      final updatedAvailable =
          book.availableCopies > 0 ? book.availableCopies - 1 : 0;
      final updated = book.copyWith(
        owned: true,
        availableCopies: updatedAvailable,
      );
      _catalogService.markBookOwned(
        book.id,
        availableCopies: updatedAvailable,
      );
      setState(() => _book = updated);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.purchaseWithCredits)));
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = e.message.isNotEmpty ? e.message : t.notEnoughCredits;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _purchasing = false);
    }
  }

  Future<void> _handleExtractText(Book book) async {
    if (_extractingText) return;
    final result = await showExtractTextDialog(context);
    if (!mounted || result == null) return;
    final trimmed = result.trim();
    await _performExtractText(book, trimmed);
  }

  Future<void> _performExtractText(Book book, String pages) async {
    if (_extractingText || !mounted) return;
    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    final isAllPages = pages.isEmpty;
    final loadingMessage =
        isAllPages ? t.extractingText : t.extractingTextFromPages;

    setState(() => _extractingText = true);

    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 16),
              Expanded(
                child: Text(loadingMessage),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final extracted = await _catalogService.extractText(
        book.id,
        isAllPages ? null : pages,
      );
      if (!mounted) return;

      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _extractingText = false);

      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => TextViewerScreen(
            extractedText: extracted,
            bookTitle: book.title,
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _extractingText = false);
      final message = _mapExtractionError(e);
      _showExtractionErrorDialog(book, pages, message);
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context, rootNavigator: true).pop();
      setState(() => _extractingText = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('${t.errorExtractingText}: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    }
  }

  void _showExtractionErrorDialog(Book book, String pages, String message) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(context.l10n.errorExtractingText),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(context.l10n.cancel),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _performExtractText(book, pages);
            },
            child: Text(context.l10n.retry),
          ),
        ],
      ),
    );
  }

  String _mapExtractionError(ApiException e) {
    final t = context.l10n;
    switch (e.statusCode) {
      case 400:
        final message = e.body?['message']?.toString() ?? e.message;
        return message.isNotEmpty ? message : t.errorInvalidFormat;
      case 403:
        return t.errorNotAuthorized;
      case 404:
        return t.errorBookNotFound;
      case 500:
        return t.errorServerError;
      case 503:
        return t.errorTimeout;
      default:
        final lower = e.message.toLowerCase();
        if (lower.contains('connect') || lower.contains('network')) {
          return t.errorNetworkConnection;
        }
        return e.message.isNotEmpty ? e.message : t.errorServerError;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final book = _book;
    
    return ResponsiveNavigationWrapper(
      currentRoute: '/book',
      appBar: AppBar(title: Text(book?.title ?? t.details)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: () => _loadBook(book?.id ?? 0))
          : book == null
          ? Center(child: Text(t.catalogEmpty))
          : _buildBookContent(context, book, t),
    );
  }

  Widget _buildBookContent(BuildContext context, Book book, AppLocalizations t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        
        // Breakpoints aligned with ResponsiveNavigationWrapper:
        // Mobile: < 600, Tablet: 600-840, Desktop: >= 840
        final isTablet = screenWidth >= 600 && screenWidth < 840;
        final isDesktop = screenWidth >= 840;
        
        if (isDesktop) {
          // Desktop: Two-column layout within the ResponsiveNavigationWrapper content area
          // Use two-column only if screen is wide enough
          if (constraints.maxWidth >= 1200) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left column: Book details with card wrapper
                Expanded(
                  flex: 1,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: _BookDetailBody(
                          book: book,
                          purchasing: _purchasing,
                          addingToCart: _addingToCart,
                          isInCart: _cartService.itemFor(book.id) != null,
                          onPurchase: () => _purchase(book, t),
                          onAddToCart: () => _addToCart(book, t),
                          showExtractAction: book.owned && book.hasPdf,
                          onExtractText: () => _handleExtractText(book),
                          extractingText: _extractingText,
                          isDesktop: true,
                        ),
                      ),
                    ),
                  ),
                ),
                // Spacing between columns
                const SizedBox(width: 16),
                // Right column: Reviews with max-width constraint
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 900),
                      child: _ReviewsSection(
                        reviews: _reviews,
                        averageRating: _averageRating,
                        totalReviews: _totalReviews,
                        ratingBreakdown: _ratingBreakdown,
                        loading: _loadingReviews,
                        userReview: _userReview,
                        bookOwned: book.owned,
                        onSubmitReview: _submitReview,
                        currentUserId: _currentUserId,
                        isDesktop: true,
                      ),
                    ),
                  ),
                ),
              ],
            );
          } else {
            // Smaller desktop/tablet: Single column with smart padding and top alignment
            final horizontalPadding = (constraints.maxWidth * 0.05).clamp(24.0, 60.0);
            return Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: 24,
                    ),
                    child: Column(
                      children: [
                        Card(
                          elevation: 4,
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: _BookDetailBody(
                              book: book,
                              purchasing: _purchasing,
                              addingToCart: _addingToCart,
                              isInCart: _cartService.itemFor(book.id) != null,
                              onPurchase: () => _purchase(book, t),
                              onAddToCart: () => _addToCart(book, t),
                              showExtractAction: book.owned && book.hasPdf,
                              onExtractText: () => _handleExtractText(book),
                              extractingText: _extractingText,
                              isDesktop: true,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        Card(
                          elevation: 4,
                          child: _ReviewsSection(
                            reviews: _reviews,
                            averageRating: _averageRating,
                            totalReviews: _totalReviews,
                            ratingBreakdown: _ratingBreakdown,
                            loading: _loadingReviews,
                            userReview: _userReview,
                            bookOwned: book.owned,
                            onSubmitReview: _submitReview,
                            currentUserId: _currentUserId,
                            isDesktop: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }
        } else if (isTablet) {
          // Tablet (600-840px): Single column with Card wrapper and moderate padding
          return Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  child: Column(
                    children: [
                      Card(
                        elevation: 4,
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: _BookDetailBody(
                            book: book,
                            purchasing: _purchasing,
                            addingToCart: _addingToCart,
                            isInCart: _cartService.itemFor(book.id) != null,
                            onPurchase: () => _purchase(book, t),
                            onAddToCart: () => _addToCart(book, t),
                            showExtractAction: book.owned && book.hasPdf,
                            onExtractText: () => _handleExtractText(book),
                            extractingText: _extractingText,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 4,
                        child: _ReviewsSection(
                          reviews: _reviews,
                          averageRating: _averageRating,
                          totalReviews: _totalReviews,
                          ratingBreakdown: _ratingBreakdown,
                          loading: _loadingReviews,
                          userReview: _userReview,
                          bookOwned: book.owned,
                          onSubmitReview: _submitReview,
                          currentUserId: _currentUserId,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        } else {
          // Mobile (< 600px): Single column with Card wrapper and minimal padding
          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                children: [
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: _BookDetailBody(
                        book: book,
                        purchasing: _purchasing,
                        addingToCart: _addingToCart,
                        isInCart: _cartService.itemFor(book.id) != null,
                        onPurchase: () => _purchase(book, t),
                        onAddToCart: () => _addToCart(book, t),
                        showExtractAction: book.owned && book.hasPdf,
                        onExtractText: () => _handleExtractText(book),
                        extractingText: _extractingText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Card(
                    elevation: 4,
                    child: _ReviewsSection(
                      reviews: _reviews,
                      averageRating: _averageRating,
                      totalReviews: _totalReviews,
                      ratingBreakdown: _ratingBreakdown,
                      loading: _loadingReviews,
                      userReview: _userReview,
                      bookOwned: book.owned,
                      onSubmitReview: _submitReview,
                      currentUserId: _currentUserId,
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      },
    );
  } // 👈 ĐÃ ĐÓNG ĐÚNG METHOD build
} // 👈 ĐÃ ĐÓNG CLASS _BookDetailPageState

// 👇 CÁC CLASS BÊN NGOÀI

class _BookDetailBody extends StatelessWidget {
  const _BookDetailBody({
    required this.book,
    required this.purchasing,
    required this.addingToCart,
    required this.isInCart,
    required this.onPurchase,
    required this.onAddToCart,
    this.showExtractAction = false,
    this.onExtractText,
    this.extractingText = false,
    this.isDesktop = false,
  });

  final Book book;
  final bool purchasing;
  final bool addingToCart;
  final bool isInCart;
  final VoidCallback onPurchase;
  final VoidCallback onAddToCart;
  final bool showExtractAction;
  final VoidCallback? onExtractText;
  final bool extractingText;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final padding = isDesktop 
        ? const EdgeInsets.all(24)
        : const EdgeInsets.all(16);

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title with responsive text size
          Text(
            book.title, 
            style: isDesktop 
                ? Theme.of(context).textTheme.headlineMedium
                : Theme.of(context).textTheme.headlineSmall,
          ),
          if (book.subtitle != null && book.subtitle!.isNotEmpty) ...[
            SizedBox(height: isDesktop ? 12 : 8),
            Text(
              book.subtitle!,
              style: isDesktop
                  ? Theme.of(context).textTheme.titleLarge
                  : Theme.of(context).textTheme.titleMedium,
            ),
          ],
          SizedBox(height: isDesktop ? 16 : 12),
          
          // Authors and Category - Always vertical for clean layout
          if (book.authors.isNotEmpty)
            Text(
              '${t.bookAuthors}: ${book.authors.map((a) => a.name).join(', ')}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          if (book.category != null) ...[
            SizedBox(height: isDesktop ? 8 : 4),
            Text(
              '${t.bookCategory}: ${book.category!.name}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ],
          
          SizedBox(height: isDesktop ? 16 : 12),
          
          // Price with prominent display on desktop
          Text(
            t.bookPrice(book.creditPrice.toString()),
            style: isDesktop
                ? Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold,
                    )
                : Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: isDesktop ? 16 : 12),
          
          // Status
          Text(
            _statusLabel(context, book.status),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          SizedBox(height: isDesktop ? 24 : 16),
          
          // Description
          Text(
            book.description?.trim().isNotEmpty == true
                ? book.description!
                : t.bookNoDescription,
            style: isDesktop
                ? Theme.of(context).textTheme.bodyLarge
                : Theme.of(context).textTheme.bodyMedium,
          ),
          SizedBox(height: isDesktop ? 32 : 16),
          
          // Responsive button layout
          if (isDesktop) ...[
            // Desktop: Expanded buttons that adapt to available space
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: addingToCart || isInCart || book.owned
                        ? null
                        : onAddToCart,
                    icon: addingToCart
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isInCart
                                ? Icons.check_circle_outline
                                : Icons.add_shopping_cart_outlined,
                          ),
                    label: Text(
                      addingToCart
                          ? context.l10n.loading
                          : isInCart
                          ? context.l10n.cartAlreadyContains
                          : context.l10n.addToCart,
                    ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: purchasing || book.owned ? null : onPurchase,
                    icon: purchasing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            book.owned
                                ? Icons.check_circle
                                : Icons.shopping_cart_checkout_outlined,
                          ),
                    label: Text(
                      purchasing
                          ? context.l10n.loading
                          : book.owned
                          ? context.l10n.bookOwnedTag
                          : context.l10n.purchaseWithCredits,
                    ),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                  ),
                ),
              ],
            ),
          ] else ...[
            // Mobile: Current layout
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: addingToCart || isInCart || book.owned
                        ? null
                        : onAddToCart,
                    icon: addingToCart
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            isInCart
                                ? Icons.check_circle_outline
                                : Icons.add_shopping_cart_outlined,
                          ),
                    label: Text(
                      addingToCart
                          ? context.l10n.loading
                          : isInCart
                          ? context.l10n.cartAlreadyContains
                          : context.l10n.addToCart,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: purchasing || book.owned ? null : onPurchase,
                    icon: purchasing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            book.owned
                                ? Icons.check_circle
                                : Icons.shopping_cart_checkout_outlined,
                          ),
                    label: Text(
                      purchasing
                          ? context.l10n.loading
                          : book.owned
                          ? context.l10n.bookOwnedTag
                          : context.l10n.purchaseWithCredits,
                    ),
                  ),
                ),
              ],
            ),
          ],
          
          // Extract Text button - only shown if book is owned and has PDF
          if (showExtractAction && book.hasPdf) ...[
            SizedBox(height: isDesktop ? 16 : 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: (extractingText || onExtractText == null)
                    ? null
                    : onExtractText,
                icon: extractingText
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.text_fields),
                label: Text(
                  extractingText ? context.l10n.extractingText : context.l10n.extractText,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: Size(0, isDesktop ? 48 : 40),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _statusLabel(BuildContext context, String status) {
    final t = context.l10n;
    switch (status.toLowerCase()) {
      case 'published':
        return t.bookStatusPublished;
      case 'archived':
        return t.bookStatusArchived;
      default:
        return t.bookStatusDraft;
    }
  }
}

class _ReviewsSection extends StatefulWidget {
  const _ReviewsSection({
    required this.reviews,
    required this.averageRating,
    required this.totalReviews,
    required this.ratingBreakdown,
    required this.loading,
    required this.userReview,
    required this.bookOwned,
    required this.onSubmitReview,
    this.currentUserId,
    this.isDesktop = false,
  });

  final List<BookReview> reviews;
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingBreakdown;
  final bool loading;
  final BookReview? userReview;
  final bool bookOwned;
  final Function(int rating, String? title, String? comment) onSubmitReview;
  final int? currentUserId;
  final bool isDesktop;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  String _sortBy = 'most_helpful';
  bool _isExpanded = true;

  List<BookReview> get _sortedReviews {
    final reviews = List<BookReview>.from(widget.reviews);

    switch (_sortBy) {
      case 'most_recent':
        reviews.sort((a, b) {
          if (a.createdAt == null || b.createdAt == null) return 0;
          return b.createdAt!.compareTo(a.createdAt!);
        });
        break;
      case 'highest':
        reviews.sort((a, b) => b.rating.compareTo(a.rating));
        break;
      case 'lowest':
        reviews.sort((a, b) => a.rating.compareTo(b.rating));
        break;
      case 'most_helpful':
      default:
        break;
    }

    return reviews;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final maxWidth = widget.isDesktop ? 800.0 : double.infinity;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        // ✅ Header
        Container(
          padding: EdgeInsets.all(widget.isDesktop ? 20 : 16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 1),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.bookReviewsTitle,
                  style: widget.isDesktop
                      ? theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        )
                      : theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                ),
              ),
              if (!widget.loading && widget.totalReviews > 0)
                IconButton(
                  icon: AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Icon(Icons.keyboard_arrow_down),
                  ),
                  onPressed: () {
                    setState(() {
                      _isExpanded = !_isExpanded;
                    });
                  },
                  tooltip: _isExpanded ? 'Collapse' : 'Expand',
                ),
            ],
          ),
        ),

        // ✅ Rating Summary
        if (_isExpanded && widget.totalReviews > 0)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isDesktop ? 24 : 16,
              vertical: widget.isDesktop ? 32 : 24,
            ),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: widget.isDesktop
                ? Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.averageRating.toStringAsFixed(1),
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 12),
                            RatingStars(rating: widget.averageRating, size: 24),
                            const SizedBox(height: 8),
                            Text(
                              t.bookRatingCount(widget.totalReviews),
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.textTheme.bodyMedium?.color?.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 48),
                      Expanded(
                        flex: 3,
                        child: _RatingBreakdown(
                          ratingBreakdown: widget.ratingBreakdown,
                          totalReviews: widget.totalReviews,
                          isDesktop: true,
                        ),
                      ),
                    ],
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 2,
                        child: Column(
                          children: [
                            Text(
                              widget.averageRating.toStringAsFixed(1),
                              style: theme.textTheme.displayLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            RatingStars(rating: widget.averageRating, size: 20),
                            const SizedBox(height: 4),
                            Text(
                              t.bookRatingCount(widget.totalReviews),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.textTheme.bodySmall?.color?.withValues(
                                  alpha: 0.7,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 32),
                      Expanded(
                        flex: 3,
                        child: _RatingBreakdown(
                          ratingBreakdown: widget.ratingBreakdown,
                          totalReviews: widget.totalReviews,
                        ),
                      ),
                    ],
                  ),
          ),

        // ✅ Review Composer (MOVED UP - before sort)
        if (_isExpanded && widget.bookOwned)
          Container(
            padding: EdgeInsets.all(widget.isDesktop ? 20 : 16),
            color: theme.colorScheme.surfaceContainerHighest.withValues(
              alpha: 0.3,
            ),
            child: _ReviewComposer(
              userReview: widget.userReview,
              onSubmit: widget.onSubmitReview,
              isDesktop: widget.isDesktop,
            ),
          ),

        // ✅ Sort dropdown (MOVED DOWN - after composer)
        if (_isExpanded && !widget.loading && widget.reviews.isNotEmpty)
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isDesktop ? 24 : 16,
              vertical: widget.isDesktop ? 16 : 12,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: widget.isDesktop
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        t.bookReviewSortBy,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 16),
                      DropdownButton<String>(
                        value: _sortBy,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: 'most_helpful',
                            child: Text(t.bookReviewSortMostHelpful),
                          ),
                          DropdownMenuItem(
                            value: 'most_recent',
                            child: Text(t.bookReviewSortMostRecent),
                          ),
                          DropdownMenuItem(
                            value: 'highest',
                            child: Text(t.bookReviewSortHighestRating),
                          ),
                          DropdownMenuItem(
                            value: 'lowest',
                            child: Text(t.bookReviewSortLowestRating),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortBy = value);
                          }
                        },
                      ),
                    ],
                  )
                : Row(
                    children: [
                      Text(
                        t.bookReviewSortBy,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 12),
                      DropdownButton<String>(
                        value: _sortBy,
                        underline: const SizedBox(),
                        items: [
                          DropdownMenuItem(
                            value: 'most_helpful',
                            child: Text(t.bookReviewSortMostHelpful),
                          ),
                          DropdownMenuItem(
                            value: 'most_recent',
                            child: Text(t.bookReviewSortMostRecent),
                          ),
                          DropdownMenuItem(
                            value: 'highest',
                            child: Text(t.bookReviewSortHighestRating),
                          ),
                          DropdownMenuItem(
                            value: 'lowest',
                            child: Text(t.bookReviewSortLowestRating),
                          ),
                        ],
                        onChanged: (value) {
                          if (value != null) {
                            setState(() => _sortBy = value);
                          }
                        },
                      ),
                    ],
                  ),
          ),

        // ✅ Reviews List
        if (_isExpanded && widget.loading)
          Padding(
            padding: EdgeInsets.all(widget.isDesktop ? 48 : 32),
            child: const Center(child: CircularProgressIndicator()),
          )
        else if (_isExpanded && widget.reviews.isEmpty)
          Padding(
            padding: EdgeInsets.all(widget.isDesktop ? 48 : 32),
            child: Center(
              child: Text(
                t.bookNoReviews, 
                style: widget.isDesktop 
                    ? theme.textTheme.bodyLarge
                    : theme.textTheme.bodyLarge,
              ),
            ),
          )
        else if (_isExpanded)
          widget.isDesktop
              ? Container(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _sortedReviews.length,
                    separatorBuilder: (_, _) =>
                        Divider(height: 1, thickness: 1, color: theme.dividerColor),
                    itemBuilder: (context, index) {
                      return _MSStoreReviewCard(
                        review: _sortedReviews[index],
                        currentUserId: widget.currentUserId,
                        isDesktop: true,
                      );
                    },
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _sortedReviews.length,
                  separatorBuilder: (_, _) =>
                      Divider(height: 1, thickness: 1, color: theme.dividerColor),
                  itemBuilder: (context, index) {
                    return _MSStoreReviewCard(
                      review: _sortedReviews[index],
                      currentUserId: widget.currentUserId,
                    );
                  },
                ),
        ],
      ),
    );
  }
}

class _ReviewComposer extends StatefulWidget {
  const _ReviewComposer({
    required this.userReview, 
    required this.onSubmit,
    this.isDesktop = false,
  });

  final BookReview? userReview;
  final Function(int rating, String? title, String? comment) onSubmit;
  final bool isDesktop;

  @override
  State<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<_ReviewComposer> {
  late final TextEditingController _titleController;
  late final TextEditingController _commentController;
  late int _rating;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.userReview;
    _rating = existing?.rating ?? 0;
    _titleController = TextEditingController(text: existing?.title ?? '');
    _commentController = TextEditingController(text: existing?.comment ?? '');
  }

  @override
  void dispose() {
    _titleController.dispose();
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      final t = context.l10n;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.bookReviewRatingRequired)));
      return;
    }

    final title = _titleController.text.trim();
    final comment = _commentController.text.trim();
    if (comment.isEmpty) {
      final t = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.bookReviewContentRequired)),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await widget.onSubmit(_rating, title, comment);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final isUpdate = widget.userReview != null;

    return ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: widget.isDesktop ? 700 : double.infinity,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isUpdate ? t.bookReviewComposerUpdateTitle : t.bookReviewComposerTitle,
            style: widget.isDesktop
                ? theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  )
                : theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
          ),
          SizedBox(height: widget.isDesktop ? 20 : 16),

          // ✅ Rating selector
          Text(
            t.bookReviewRatingLabel,
            style: widget.isDesktop
                ? theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  )
                : theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
          ),
          SizedBox(height: widget.isDesktop ? 12 : 8),
          RatingSelector(
            rating: _rating,
            onRatingChanged: (value) => setState(() => _rating = value),
          ),

          SizedBox(height: widget.isDesktop ? 20 : 16),

          // ✅ Title field
          TextField(
            controller: _titleController,
            maxLength: 100,
            style: widget.isDesktop ? theme.textTheme.bodyLarge : null,
            decoration: InputDecoration(
              labelText: t.bookReviewTitleLabel,
              hintText: t.bookReviewTitleHint,
              border: const OutlineInputBorder(),
              counterText: '',
            ),
          ),

          SizedBox(height: widget.isDesktop ? 20 : 16),

          // ✅ Comment field
          TextField(
            controller: _commentController,
            maxLines: widget.isDesktop ? 6 : 4,
            maxLength: 1000,
            textAlignVertical: TextAlignVertical.top,
            style: widget.isDesktop ? theme.textTheme.bodyLarge : null,
            decoration: InputDecoration(
              labelText: t.bookReviewCommentLabel,
              hintText: t.bookReviewCommentHint,
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),

          SizedBox(height: widget.isDesktop ? 24 : 16),

          // ✅ Submit button
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: _submitting
                  ? SizedBox(
                      width: widget.isDesktop ? 20 : 16,
                      height: widget.isDesktop ? 20 : 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(
                isUpdate ? t.bookReviewUpdateButton : t.bookReviewSubmitButton,
                style: widget.isDesktop ? theme.textTheme.titleSmall : null,
              ),
              style: widget.isDesktop
                  ? FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                    )
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({
    required this.ratingBreakdown,
    required this.totalReviews,
    this.isDesktop = false,
  });

  final Map<int, int> ratingBreakdown;
  final int totalReviews;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        for (int star = 5; star >= 1; star--)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                // Star number
                Text(
                  '$star',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.star, size: 16, color: Colors.amber),
                const SizedBox(width: 8),

                // Progress bar
                Expanded(
                  child: _RatingBar(
                    count: ratingBreakdown[star] ?? 0,
                    total: totalReviews,
                    isDesktop: isDesktop,
                  ),
                ),

                const SizedBox(width: 8),

                // Count
                SizedBox(
                  width: isDesktop ? 40 : 32,
                  child: Text(
                    '${ratingBreakdown[star] ?? 0}',
                    style: isDesktop 
                        ? theme.textTheme.bodyMedium
                        : theme.textTheme.bodySmall,
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _RatingBar extends StatelessWidget {
  const _RatingBar({required this.count, required this.total, this.isDesktop = false});

  final int count;
  final int total;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = total > 0 ? count / total : 0.0;

    return Stack(
      children: [
        // Background
        Container(
          height: isDesktop ? 10 : 8,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(isDesktop ? 5 : 4),
          ),
        ),

        // Filled portion
        FractionallySizedBox(
          widthFactor: percentage,
          child: Container(
            height: isDesktop ? 10 : 8,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(isDesktop ? 5 : 4),
            ),
          ),
        ),
      ],
    );
  }
}

class _MSStoreReviewCard extends StatefulWidget {
  const _MSStoreReviewCard({required this.review, this.currentUserId, this.isDesktop = false});

  final BookReview review;
  final int? currentUserId;
  final bool isDesktop;

  @override
  State<_MSStoreReviewCard> createState() => _MSStoreReviewCardState();
}

class _MSStoreReviewCardState extends State<_MSStoreReviewCard> {
  late bool _liked;
  late bool _disliked;
  late int _likeCount;
  late int _dislikeCount;
  bool _isUpdating = false;
  String? _currentUserVote; // ✅ Track current vote state across clicks

  @override
  void initState() {
    super.initState();
    // ✅ Initialize from backend data
    _initializeVoteState();
  }

  @override
  void didUpdateWidget(_MSStoreReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // ✅ Update when review data changes
    if (oldWidget.review.id != widget.review.id ||
        oldWidget.review.userVote != widget.review.userVote ||
        oldWidget.review.helpfulCount != widget.review.helpfulCount ||
        oldWidget.review.notHelpfulCount != widget.review.notHelpfulCount) {
      _initializeVoteState();
    }
  }

  void _initializeVoteState() {
    _likeCount = widget.review.helpfulCount;
    _dislikeCount = widget.review.notHelpfulCount;
    _currentUserVote = widget.review.userVote; // ✅ Initialize current vote
    _liked = _currentUserVote == 'like';
    _disliked = _currentUserVote == 'dislike';
  }

  bool get _isOwnReview =>
      widget.currentUserId != null &&
      widget.review.userId == widget.currentUserId;

  Future<void> _toggleLike() async {
    if (_isUpdating) return;

    // Check if user is logged in
    final isLoggedIn = await AuthService.instance.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đánh giá')),
      );
      return;
    }

    // Optimistic update
    final previousLiked = _liked;
    final previousDisliked = _disliked;
    final previousLikeCount = _likeCount;
    final previousDislikeCount = _dislikeCount;

    setState(() {
      _isUpdating = true;
      if (_liked) {
        _liked = false;
        _likeCount--;
      } else {
        _liked = true;
        _likeCount++;
        if (_disliked) {
          _disliked = false;
          _dislikeCount--;
        }
      }
    });

    try {
      final result = await CatalogService.instance.toggleLike(
        widget.review.id,
        _currentUserVote, // ✅ Use current vote state, not widget.review.userVote
      );

      if (!mounted) return;

      // Update with actual values from backend
      setState(() {
        _likeCount = result['helpful_count'] as int;
        _dislikeCount = result['not_helpful_count'] as int;
        final userVote = result['user_vote'] as String?;
        _currentUserVote = userVote; // ✅ Update current vote state
        _liked = userVote == 'like';
        _disliked = userVote == 'dislike';
        _isUpdating = false;
      });
    } catch (e) {
      // Rollback on error
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _disliked = previousDisliked;
        _likeCount = previousLikeCount;
        _dislikeCount = previousDislikeCount;
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật: ${e.toString()}')),
      );
    }
  }

  Future<void> _toggleDislike() async {
    if (_isUpdating) return;

    // Check if user is logged in
    final isLoggedIn = await AuthService.instance.isLoggedIn();
    if (!isLoggedIn) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng đăng nhập để đánh giá')),
      );
      return;
    }

    // Optimistic update
    final previousLiked = _liked;
    final previousDisliked = _disliked;
    final previousLikeCount = _likeCount;
    final previousDislikeCount = _dislikeCount;

    setState(() {
      _isUpdating = true;
      if (_disliked) {
        _disliked = false;
        _dislikeCount--;
      } else {
        _disliked = true;
        _dislikeCount++;
        if (_liked) {
          _liked = false;
          _likeCount--;
        }
      }
    });

    try {
      final result = await CatalogService.instance.toggleDislike(
        widget.review.id,
        _currentUserVote, // ✅ Use current vote state, not widget.review.userVote
      );

      if (!mounted) return;

      // Update with actual values from backend
      setState(() {
        _likeCount = result['helpful_count'] as int;
        _dislikeCount = result['not_helpful_count'] as int;
        final userVote = result['user_vote'] as String?;
        _currentUserVote = userVote; // ✅ Update current vote state
        _liked = userVote == 'like';
        _disliked = userVote == 'dislike';
        _isUpdating = false;
      });
    } catch (e) {
      // Rollback on error
      if (!mounted) return;
      setState(() {
        _liked = previousLiked;
        _disliked = previousDisliked;
        _likeCount = previousLikeCount;
        _dislikeCount = previousDislikeCount;
        _isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Không thể cập nhật: ${e.toString()}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final userName = widget.review.user?['name']?.toString();
    final displayName = userName?.isNotEmpty == true
        ? userName!
        : t.bookReviewAnonymous;
    final title = widget.review.title?.trim().isNotEmpty == true
        ? widget.review.title!
        : t.bookReviewNoTitle;

    return widget.isDesktop
        ? Container(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Rating stars
                RatingStars(rating: widget.review.rating.toDouble(), size: 18),

                const SizedBox(height: 12),

                // ✅ Title (bold)
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 16),

                // ✅ Review content
                if (widget.review.comment != null &&
                    widget.review.comment!.isNotEmpty) ...[
                  Text(widget.review.comment!, style: theme.textTheme.bodyLarge),
                  const SizedBox(height: 20),
                ],

                // ✅ Footer: Author, Date, Actions
                Row(
                  children: [
                    // Author & Date
                    Expanded(
                      child: Wrap(
                        spacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          Text(
                            '•',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(widget.review.createdAt),
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.textTheme.bodyMedium?.color?.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ Like/Dislike buttons (hidden for own reviews)
                    if (!_isOwnReview)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Like button
                          TextButton.icon(
                            onPressed: _isUpdating ? null : _toggleLike,
                            icon: Icon(
                              _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                              size: 20,
                              color: _liked ? theme.colorScheme.primary : null,
                            ),
                            label: Text(
                              '$_likeCount',
                              style: TextStyle(
                                color: _liked ? theme.colorScheme.primary : null,
                                fontWeight: _liked ? FontWeight.w600 : null,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: const Size(0, 44),
                            ),
                          ),

                          const SizedBox(width: 8),

                          // Dislike button
                          TextButton.icon(
                            onPressed: _isUpdating ? null : _toggleDislike,
                            icon: Icon(
                              _disliked
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_outlined,
                              size: 20,
                              color: _disliked ? theme.colorScheme.error : null,
                            ),
                            label: Text(
                              '$_dislikeCount',
                              style: TextStyle(
                                color: _disliked ? theme.colorScheme.error : null,
                                fontWeight: _disliked ? FontWeight.w600 : null,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              minimumSize: const Size(0, 44),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          )
        : Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ Rating stars
                RatingStars(rating: widget.review.rating.toDouble(), size: 16),

                const SizedBox(height: 8),

                // ✅ Title (bold)
                Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),

                const SizedBox(height: 12),

                // ✅ Review content
                if (widget.review.comment != null &&
                    widget.review.comment!.isNotEmpty) ...[
                  Text(widget.review.comment!, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 16),
                ],

                // ✅ Footer: Author, Date, Actions
                Row(
                  children: [
                    // Author & Date
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          Text(
                            '•',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                          Text(
                            _formatDate(widget.review.createdAt),
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.textTheme.bodySmall?.color?.withValues(
                                alpha: 0.7,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ Like/Dislike buttons (hidden for own reviews)
                    if (!_isOwnReview)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Like button
                          TextButton.icon(
                            onPressed: _isUpdating ? null : _toggleLike,
                            icon: Icon(
                              _liked ? Icons.thumb_up : Icons.thumb_up_outlined,
                              size: 16,
                              color: _liked ? theme.colorScheme.primary : null,
                            ),
                            label: Text(
                              '$_likeCount',
                              style: TextStyle(
                                color: _liked ? theme.colorScheme.primary : null,
                                fontWeight: _liked ? FontWeight.w600 : null,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: const Size(0, 36),
                            ),
                          ),

                          const SizedBox(width: 4),

                          // Dislike button
                          TextButton.icon(
                            onPressed: _isUpdating ? null : _toggleDislike,
                            icon: Icon(
                              _disliked
                                  ? Icons.thumb_down
                                  : Icons.thumb_down_outlined,
                              size: 16,
                              color: _disliked ? theme.colorScheme.error : null,
                            ),
                            label: Text(
                              '$_dislikeCount',
                              style: TextStyle(
                                color: _disliked ? theme.colorScheme.error : null,
                                fontWeight: _disliked ? FontWeight.w600 : null,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              minimumSize: const Size(0, 36),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '-';

    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inDays > 30) {
      final months = (diff.inDays / 30).floor();
      return months == 1
          ? 'Khoảng 1 tháng trước'
          : 'Khoảng $months tháng trước';
    } else if (diff.inDays > 7) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? 'Khoảng 1 tuần trước' : 'Khoảng $weeks tuần trước';
    } else if (diff.inDays > 0) {
      return diff.inDays == 1
          ? 'Khoảng 1 ngày trước'
          : 'Khoảng ${diff.inDays} ngày trước';
    } else if (diff.inHours > 0) {
      return diff.inHours == 1
          ? 'Khoảng 1 giờ trước'
          : 'Khoảng ${diff.inHours} giờ trước';
    } else {
      return 'Vừa xong';
    }
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.errorPrefix(error), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(t.tryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
