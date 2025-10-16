import 'package:flutter/material.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/cart_service.dart';
import 'package:my_flutter_app/services/catalog_service.dart';
import 'package:my_flutter_app/services/order_service.dart';

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
      _loadBook(args?.bookId ?? _book?.id ?? 0);
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

  Future<void> _addToCart(Book book, AppLocalizations t) async {
    if (_addingToCart) return;
    if (book.owned) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.bookAlreadyOwned)));
      return;
    }
    if (_cartService.itemFor(book.id) != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.cartAlreadyContains)));
      return;
    }
    setState(() => _addingToCart = true);
    try {
      await _cartService.addBook(book);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.addedToCart)));
    } on CartItemAlreadyExistsException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.cartAlreadyContains)));
    } on BookAlreadyOwnedException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.bookAlreadyOwned)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.cartUpdateFailed)));
    } finally {
      if (mounted) setState(() => _addingToCart = false);
    }
  }

  Future<void> _purchase(Book book, AppLocalizations t) async {
    if (_purchasing) return;
    if (book.owned) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.bookAlreadyOwned)),
      );
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
          : _BookDetailBody(
              book: book,
              purchasing: _purchasing,
              addingToCart: _addingToCart,
              isInCart: _cartService.itemFor(book.id) != null,
              onPurchase: () => _purchase(book, t),
              onAddToCart: () => _addToCart(book, t),
            ),
    );
  }
}

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
          Expanded(
            child: SingleChildScrollView(
              child: Text(
                book.description?.trim().isNotEmpty == true
                    ? book.description!
                    : t.bookNoDescription,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
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
