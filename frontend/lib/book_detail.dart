import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/models/book_review.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/cart_service.dart';
import 'package:my_flutter_app/services/catalog_service.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/widgets/rating_stars.dart';

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
  String? _error;

  // Review state
  List<BookReview> _reviews = [];
  double _averageRating = 0.0;
  int _totalReviews = 0;
  Map<int, int> _ratingBreakdown = {};
  bool _loadingReviews = true;
  BookReview? _userReview;

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

  Future<void> _loadReviews(int bookId) async {
    if (bookId <= 0) return;

    setState(() => _loadingReviews = true);

    try {
      final loggedIn = await AuthService.instance.isLoggedIn();
      debugPrint('🔐 User logged in: $loggedIn');

      debugPrint('📥 Loading reviews...');
      final data = await _catalogService.getBookReviews(
        bookId,
        forceRefresh: true,
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
          forceRefresh: true,
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

  Future<void> _submitReview(int rating, String? comment) async {
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
          comment: comment,
        );
        debugPrint('✅ Review updated: ID=${newReview.id}');
      } else {
        debugPrint('➕ Creating new review');
        newReview = await _catalogService.submitReview(
          bookId: book.id,
          rating: rating,
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
      final updated = book.copyWith(owned: true);
      _catalogService.markBookOwned(book.id);
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

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final book = _book;
    return Scaffold(
      appBar: AppBar(title: Text(book?.title ?? t.details)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(error: _error!, onRetry: () => _loadBook(book?.id ?? 0))
          : book == null
          ? Center(child: Text(t.catalogEmpty))
          : SingleChildScrollView(
              child: Column(
                children: [
                  _BookDetailBody(
                    book: book,
                    purchasing: _purchasing,
                    addingToCart: _addingToCart,
                    isInCart: _cartService.itemFor(book.id) != null,
                    onPurchase: () => _purchase(book, t),
                    onAddToCart: () => _addToCart(book, t),
                  ),
                  const Divider(height: 32, thickness: 8),
                  _ReviewsSection(
                    reviews: _reviews,
                    averageRating: _averageRating,
                    totalReviews: _totalReviews,
                    ratingBreakdown: _ratingBreakdown,
                    loading: _loadingReviews,
                    userReview: _userReview,
                    bookOwned: book.owned,
                    onSubmitReview: _submitReview,
                  ),
                ],
              ),
            ),
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
  });

  final Book book;
  final bool purchasing;
  final bool addingToCart;
  final bool isInCart;
  final VoidCallback onPurchase;
  final VoidCallback onAddToCart;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(book.title, style: Theme.of(context).textTheme.headlineSmall),
          if (book.subtitle != null && book.subtitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              book.subtitle!,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
          const SizedBox(height: 12),
          if (book.authors.isNotEmpty)
            Text(
              '${t.bookAuthors}: ${book.authors.map((a) => a.name).join(', ')}',
            ),
          if (book.category != null) ...[
            const SizedBox(height: 4),
            Text('${t.bookCategory}: ${book.category!.name}'),
          ],
          const SizedBox(height: 12),
          Text(t.bookPrice(book.creditPrice.toString())),
          const SizedBox(height: 12),
          Text(
            _statusLabel(context, book.status),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          Text(
            book.description?.trim().isNotEmpty == true
                ? book.description!
                : t.bookNoDescription,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 16),
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
  });

  final List<BookReview> reviews;
  final double averageRating;
  final int totalReviews;
  final Map<int, int> ratingBreakdown;
  final bool loading;
  final BookReview? userReview;
  final bool bookOwned;
  final Function(int rating, String? comment) onSubmitReview;

  @override
  State<_ReviewsSection> createState() => _ReviewsSectionState();
}

class _ReviewsSectionState extends State<_ReviewsSection> {
  String _sortBy = 'most_helpful'; // most_helpful, most_recent, highest, lowest

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
        // Keep original order (backend should handle this)
        break;
    }

    return reviews;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ✅ Header with divider
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 8),
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  t.bookReviewsTitle,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!widget.loading && widget.totalReviews > 0)
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_down),
                  onPressed: () {}, // Could collapse section
                ),
            ],
          ),
        ),

        // ✅ Rating Summary
        if (widget.totalReviews > 0)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left: Big number
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
                          color: theme.textTheme.bodySmall?.color?.withOpacity(
                            0.7,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 24),

                // Right: Rating breakdown bars
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

        // ✅ Sort dropdown
        if (!widget.loading && widget.reviews.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 1),
              ),
            ),
            child: Row(
              children: [
                Text(t.bookReviewSortBy, style: theme.textTheme.bodyMedium),
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

        // ✅ Review Composer (if owned)
        if (widget.bookOwned)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.dividerColor, width: 8),
              ),
            ),
            child: _ReviewComposer(
              userReview: widget.userReview,
              onSubmit: widget.onSubmitReview,
            ),
          ),

        // ✅ Reviews List
        if (widget.loading)
          const Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (widget.reviews.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Text(t.bookNoReviews, style: theme.textTheme.bodyLarge),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _sortedReviews.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, thickness: 1, color: theme.dividerColor),
            itemBuilder: (context, index) {
              return _MSStoreReviewCard(review: _sortedReviews[index]);
            },
          ),
      ],
    );
  }
}

class _ReviewComposer extends StatefulWidget {
  const _ReviewComposer({required this.userReview, required this.onSubmit});

  final BookReview? userReview;
  final Function(int rating, String? comment) onSubmit;

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

    setState(() => _submitting = true);

    try {
      // For now, only pass comment (title support needs backend update)
      await widget.onSubmit(_rating, _commentController.text.trim());
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          t.bookReviewComposerTitle,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Rating selector
        Text(t.bookReviewRatingLabel, style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        RatingSelector(
          rating: _rating,
          onRatingChanged: (value) => setState(() => _rating = value),
        ),

        const SizedBox(height: 16),

        // Title field (optional for now, needs backend support)
        TextField(
          controller: _titleController,
          decoration: InputDecoration(
            labelText: 'Title (optional)',
            hintText: 'Summarize your review',
            border: const OutlineInputBorder(),
          ),
          enabled: false, // Disable until backend supports it
        ),

        const SizedBox(height: 16),

        // Comment field
        TextField(
          controller: _commentController,
          maxLines: 4,
          textAlignVertical: TextAlignVertical.top,
          decoration: InputDecoration(
            labelText: t.bookReviewCommentLabel,
            hintText: t.bookReviewCommentHint,
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),

        const SizedBox(height: 16),

        // Submit button
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.icon(
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send),
            label: Text(
              isUpdate ? t.bookReviewUpdateButton : t.bookReviewSubmitButton,
            ),
          ),
        ),
      ],
    );
  }
}

class _RatingBreakdown extends StatelessWidget {
  const _RatingBreakdown({
    required this.ratingBreakdown,
    required this.totalReviews,
  });

  final Map<int, int> ratingBreakdown;
  final int totalReviews;

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
                  ),
                ),

                const SizedBox(width: 8),

                // Count
                SizedBox(
                  width: 32,
                  child: Text(
                    '${ratingBreakdown[star] ?? 0}',
                    style: theme.textTheme.bodySmall,
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
  const _RatingBar({required this.count, required this.total});

  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final percentage = total > 0 ? count / total : 0.0;

    return Stack(
      children: [
        // Background
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(4),
          ),
        ),

        // Filled portion
        FractionallySizedBox(
          widthFactor: percentage,
          child: Container(
            height: 8,
            decoration: BoxDecoration(
              color: Colors.amber,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ],
    );
  }
}

class _MSStoreReviewCard extends StatelessWidget {
  const _MSStoreReviewCard({required this.review});

  final BookReview review;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final theme = Theme.of(context);
    final userName = review.user?['name']?.toString();
    final displayName = userName?.isNotEmpty == true
        ? userName!
        : t.bookReviewAnonymous;
    final title = review.title?.trim().isNotEmpty == true
        ? review.title!
        : t.bookReviewNoTitle;

    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ✅ Title (bold)
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 8),

          // ✅ Rating stars
          RatingStars(rating: review.rating.toDouble(), size: 16),

          const SizedBox(height: 12),

          // ✅ Review content
          if (review.comment != null && review.comment!.isNotEmpty) ...[
            Text(review.comment!, style: theme.textTheme.bodyMedium),
            const SizedBox(height: 16),
          ],

          // ✅ Footer: Author, Date, Actions
          Row(
            children: [
              // Author
              Expanded(
                child: Row(
                  children: [
                    Text(
                      displayName,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '•',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(review.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.textTheme.bodySmall?.color?.withOpacity(
                          0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ✅ Helpful buttons
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Yes button
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Implement helpful vote
                    },
                    icon: const Icon(Icons.thumb_up_outlined, size: 16),
                    label: const Text('7'), // Placeholder count
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // No button
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Implement not helpful vote
                    },
                    icon: const Icon(Icons.thumb_down_outlined, size: 16),
                    label: const Text('0'), // Placeholder count
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Report button
                  IconButton(
                    onPressed: () {
                      // TODO: Implement report
                    },
                    icon: const Icon(Icons.flag_outlined, size: 16),
                    tooltip: t.bookReviewReport,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
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
      return months == 1 ? 'About a month ago' : 'About $months months ago';
    } else if (diff.inDays > 7) {
      final weeks = (diff.inDays / 7).floor();
      return weeks == 1 ? 'About a week ago' : 'About $weeks weeks ago';
    } else if (diff.inDays > 0) {
      return diff.inDays == 1
          ? 'About a day ago'
          : 'About ${diff.inDays} days ago';
    } else if (diff.inHours > 0) {
      return diff.inHours == 1
          ? 'About an hour ago'
          : 'About ${diff.inHours} hours ago';
    } else {
      return 'Just now';
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
