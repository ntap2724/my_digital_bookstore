import 'package:flutter/material.dart';
import 'package:my_flutter_app/book_detail.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/cart_service.dart';
import 'package:my_flutter_app/services/catalog_service.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/widgets/app_navigation_menu.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _bookCardInfoHeight = 160;
  static const double _bookCoverAspectRatio = 3 / 4;

  final CatalogService _catalogService = CatalogService.instance;
  final CartService _cartService = CartService.instance;
  final OrderService _orderService = OrderService.instance;

  final Set<int> _addingToCart = <int>{};
  final Set<int> _purchasingBooks = <int>{};

  String? _displayName;
  String? _email;
  List<Book> _books = const [];
  bool _loadingBooks = true;
  String? _bookError;

  @override
  void initState() {
    super.initState();
    _cartService.ensureLoaded();
    _cartService.addListener(_handleCartChanged);
    _loadProfile();
    _loadBooks();
  }

  @override
  void dispose() {
    _cartService.removeListener(_handleCartChanged);
    super.dispose();
  }

  Future<void> _loadProfile({bool showSpinner = true}) async {
    AccountInfo? active;
    Map<String, dynamic>? profile;

    try {
      active = await AuthService.instance.getActiveAccount();
    } catch (_) {}

    try {
      profile = await AuthService.instance.me();
    } catch (_) {}

    if (!mounted) {
      return;
    }

    final name = _extractName(active, profile);
    final email = _extractEmail(active, profile);

    setState(() {
      _displayName = name;
      _email = email;
    });
  }

  Future<void> _loadBooks({bool showSpinner = true}) async {
    if (mounted) {
      setState(() {
        _loadingBooks = true;
        _bookError = null;
      });
    }

    try {
      final books = await _catalogService.getAllBooks(auth: true);
      if (!mounted) return;
      setState(() {
        _books = books.take(16).toList(growable: false);
        _bookError = null;
        _loadingBooks = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bookError = e.toString();
        _loadingBooks = false;
      });
    }
  }

  void _handleCartChanged() {
    if (!mounted) return;
    setState(() {});
  }

  String? _extractName(AccountInfo? account, Map<String, dynamic>? profile) {
    final fromAccount = account?.name;
    if (fromAccount != null && fromAccount.trim().isNotEmpty) {
      return fromAccount.trim();
    }
    final raw = profile?['name']?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return null;
  }

  Future<void> _handleAddToCart(Book book, AppLocalizations t) async {
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
    if (_addingToCart.contains(book.id)) return;
    setState(() => _addingToCart.add(book.id));
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
      if (mounted) {
        setState(() => _addingToCart.remove(book.id));
      }
    }
  }

  Future<void> _handleQuickPurchase(Book book, AppLocalizations t) async {
    if (book.owned) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.bookAlreadyOwned)));
      return;
    }
    if (_purchasingBooks.contains(book.id)) return;
    setState(() => _purchasingBooks.add(book.id));
    try {
      await _orderService.placeOrder(
        items: [
          {'book_id': book.id, 'quantity': 1},
        ],
      );
      _catalogService.markBookOwned(book.id);
      if (_cartService.itemFor(book.id) != null) {
        await _cartService.remove(book.id);
      }
      if (!mounted) return;
      setState(() {
        _books = _books
            .map((b) => b.id == book.id ? b.copyWith(owned: true) : b)
            .toList(growable: false);
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.purchaseWithCredits)));
    } on ApiException catch (e) {
      final message = e.message.isNotEmpty ? e.message : t.notEnoughCredits;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) {
        setState(() => _purchasingBooks.remove(book.id));
      }
    }
  }

  String? _extractEmail(AccountInfo? account, Map<String, dynamic>? profile) {
    final fromAccount = account?.email;
    if (fromAccount != null && fromAccount.trim().isNotEmpty) {
      return fromAccount.trim();
    }
    final raw = profile?['email']?.toString();
    if (raw != null && raw.trim().isNotEmpty) {
      return raw.trim();
    }
    return null;
  }

  Future<void> _handleRefresh() async {
    await Future.wait([
      _loadProfile(showSpinner: false),
      _loadBooks(showSpinner: false),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(t.home)),
      drawer: const AppNavigationMenu(currentRoute: '/home'),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _buildHeader(context, t),
            const SizedBox(height: 24),
            Text(
              t.bookExplorerTitle,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              t.catalogSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            _buildBooksSection(context, t),
          ],
        ),
      ),
    );
  }

  Widget _buildBooksSection(BuildContext context, AppLocalizations t) {
    if (_bookError != null) {
      return _buildErrorNotice(context, t, _bookError!);
    }
    if (_loadingBooks) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 48),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_books.isEmpty) {
      return _buildEmptyState(context, t);
    }
    return _buildBookGrid(context, t);
  }

  Widget _buildBookGrid(BuildContext context, AppLocalizations t) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var crossAxisCount = 1;
        if (width >= 1100) {
          crossAxisCount = 4;
        } else if (width >= 820) {
          crossAxisCount = 3;
        } else if (width >= 560) {
          crossAxisCount = 2;
        }

        const spacing = 16.0;
        final availableWidth = width - spacing * (crossAxisCount - 1);
        final itemWidth = availableWidth / crossAxisCount;
        final cardHeight =
            itemWidth / _bookCoverAspectRatio + _bookCardInfoHeight;
        final childAspectRatio = itemWidth / cardHeight;

        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _books.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) =>
              _buildBookCard(context, t, _books[index]),
        );
      },
    );
  }

  Widget _buildBookCard(BuildContext context, AppLocalizations t, Book book) {
    final theme = Theme.of(context);
    final categoryName = book.category?.name;
    final trimmedCategory = categoryName?.trim();
    final isOwned = book.owned;
    final isInCart = _cartService.itemFor(book.id) != null;
    final adding = _addingToCart.contains(book.id);
    final purchasing = _purchasingBooks.contains(book.id);

    Widget buildFallbackCover() => Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.menu_book_outlined,
        size: 42,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    final hasCover =
        book.coverImageUrl != null && book.coverImageUrl!.trim().isNotEmpty;

    final coverImage = hasCover
        ? Image.network(
            book.coverImageUrl!,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) return child;
              return buildFallbackCover();
            },
            errorBuilder: (context, error, stackTrace) => buildFallbackCover(),
          )
        : buildFallbackCover();

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () {
        Navigator.of(context).pushNamed(
          BookDetailPage.routeName,
          arguments: BookDetailArgs(bookId: book.id, initial: book),
        );
      },
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: _bookCoverAspectRatio,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  coverImage,
                  Positioned(
                    top: 12,
                    left: 12,
                    child: _buildCategoryChip(theme, trimmedCategory),
                  ),
                  if (book.owned)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: _buildOwnedChip(theme, t),
                    ),
                ],
              ),
            ),
            SizedBox(
              height: _bookCardInfoHeight,
              child: Padding(
                padding: const EdgeInsets.all(
                  12,
                ), // ✅ Padding đều 12px tất cả phía
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. TITLE (fixed height với maxLines)
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium,
                    ),

                    const SizedBox(height: 8), // ✅ Spacing đều 8px
                    // 2. CATEGORY/DESCRIPTION (fixed height)
                    SizedBox(
                      height: 16, // ✅ Fixed height để spacing consistent
                      child:
                          trimmedCategory != null && trimmedCategory.isNotEmpty
                          ? Text(
                              trimmedCategory,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall,
                            )
                          : const SizedBox.shrink(),
                    ),

                    const SizedBox(height: 8), // ✅ Spacing đều 8px
                    // 3. PRICE
                    Text(
                      t.bookPrice(book.creditPrice.toString()),
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 8), // ✅ Spacing đều 8px

                    const Spacer(), // ✅ Đẩy buttons xuống dưới
                    // 4. BUTTONS
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ), // ✅ Giảm padding ngang
                            ),
                            onPressed: adding || isOwned || isInCart
                                ? null
                                : () => _handleAddToCart(book, t),
                            icon: adding
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    isInCart
                                        ? Icons.check_circle_outline
                                        : Icons.add_shopping_cart_outlined,
                                    size: 18, // ✅ Icon nhỏ hơn một chút
                                  ),
                            label: Text(
                              adding
                                  ? t.loading
                                  : isInCart
                                  ? t.cartAlreadyContains
                                  : t.addToCart,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                              ), // ✅ Font nhỏ hơn
                            ),
                          ),
                        ),
                        const SizedBox(width: 8), // ✅ Spacing giữa buttons
                        Expanded(
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(44),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ), // ✅ Giảm padding ngang
                            ),
                            onPressed: purchasing || isOwned
                                ? null
                                : () => _handleQuickPurchase(book, t),
                            icon: purchasing
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : Icon(
                                    isOwned
                                        ? Icons.check_circle
                                        : Icons.shopping_cart_checkout_outlined,
                                    size: 18, // ✅ Icon nhỏ hơn một chút
                                  ),
                            label: Text(
                              purchasing
                                  ? t.loading
                                  : isOwned
                                  ? t.bookOwnedTag
                                  : t.purchase,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 13,
                              ), // ✅ Font nhỏ hơn
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryChip(ThemeData theme, String? category) {
    final display = category?.trim();
    if (display == null || display.isEmpty) {
      return const SizedBox.shrink();
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        display,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildOwnedChip(ThemeData theme, AppLocalizations t) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            t.bookOwnedTag,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorNotice(
    BuildContext context,
    AppLocalizations t,
    String message,
  ) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              t.errorPrefix(message),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => _loadBooks(),
                icon: const Icon(Icons.refresh),
                label: Text(t.tryAgain),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.catalogEmpty, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            Text(t.refresh, style: theme.textTheme.bodyMedium),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    final rawName = _displayName?.trim() ?? '';
    final rawEmail = _email?.trim() ?? '';
    final label = rawName.isNotEmpty ? rawName : rawEmail;
    final greeting = label.isNotEmpty ? t.helloUser(label) : t.welcome;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: theme.textTheme.titleMedium),
            if (rawEmail.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  t.emailLabel(rawEmail),
                  style: theme.textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
