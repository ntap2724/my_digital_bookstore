import 'dart:async';

import 'package:flutter/material.dart';
import 'package:my_flutter_app/book_detail.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/author.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/models/category.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/cart_service.dart';
import 'package:my_flutter_app/services/catalog_service.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/widgets/responsive_navigation_wrapper.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  static const double _bookCardInfoHeight = 172;
  static const double _bookCoverAspectRatio = 3 / 4;

  final CatalogService _catalogService = CatalogService.instance;
  final CartService _cartService = CartService.instance;
  final OrderService _orderService = OrderService.instance;

  final Set<int> _addingToCart = <int>{};
  final Set<int> _purchasingBooks = <int>{};
  VoidCallback? _catalogCacheListener;

  String? _displayName;
  String? _email;
  List<Book> _books = const [];
  bool _loadingBooks = true;
  String? _bookError;

  // Search, Sort, and Filter state
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _sortBy = 'title_asc';
  final Set<int> _selectedCategoryIds = {};
  final Set<int> _selectedAuthorIds = {};
  List<Category> _categories = [];
  List<Author> _authors = [];
  bool _loadingCategories = false;
  bool _loadingAuthors = false;
  Timer? _searchDebounce;
  bool _showSuggestions = false;
  
  // Filter state (for bottom sheet/dialog)
  bool _categoriesExpanded = true;
  bool _authorsExpanded = false;

  @override
  void initState() {
    super.initState();
    _cartService.ensureLoaded();
    _cartService.addListener(_handleCartChanged);
    _searchController.addListener(_onSearchChanged);
    _catalogCacheListener = () {
      if (!mounted) return;
      _loadBooks(showSpinner: false);
    };
    _catalogService.addCacheListener(_catalogCacheListener!);
    _loadProfile();
    _loadBooks();
    _loadCategories();
    _loadAuthors();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _searchFocusNode.dispose();
    _searchDebounce?.cancel();
    _cartService.removeListener(_handleCartChanged);
    if (_catalogCacheListener != null) {
      _catalogService.removeCacheListener(_catalogCacheListener!);
    }
    super.dispose();
  }

  void _onSearchChanged() {
    if (!mounted) return;
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _searchQuery = _searchController.text.trim().toLowerCase();
        });
      }
    });
  }

  Future<void> _loadCategories() async {
    setState(() => _loadingCategories = true);
    try {
      final categories = await _catalogService.getCategories();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loadingCategories = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingCategories = false);
    }
  }

  Future<void> _loadAuthors() async {
    setState(() => _loadingAuthors = true);
    try {
      final authors = await _catalogService.fetchAuthors(auth: true);
      if (!mounted) return;
      setState(() {
        _authors = authors;
        _loadingAuthors = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loadingAuthors = false);
    }
  }

  List<Book> _getFilteredAndSortedBooks() {
    if (_books.isEmpty) return [];
    
    var filtered = _books.toList();

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((book) {
        try {
          final titleMatch = book.title.toLowerCase().contains(_searchQuery);
          final authorMatch = book.authors.isNotEmpty &&
              book.authors.any((author) => author.name.toLowerCase().contains(_searchQuery));
          final descMatch = book.description?.toLowerCase().contains(_searchQuery) ?? false;
          final categoryMatch = book.category?.name.toLowerCase().contains(_searchQuery) ?? false;
          return titleMatch || authorMatch || descMatch || categoryMatch;
        } catch (e) {
          // If there's any error accessing book properties, exclude it from results
          return false;
        }
      }).toList();
    }

    // Filter by category
    if (_selectedCategoryIds.isNotEmpty) {
      filtered = filtered.where((book) {
        final categoryId = book.category?.id;
        return categoryId != null && _selectedCategoryIds.contains(categoryId);
      }).toList();
    }

    // Filter by author
    if (_selectedAuthorIds.isNotEmpty) {
      filtered = filtered.where((book) {
        return book.authors.any((author) => _selectedAuthorIds.contains(author.id));
      }).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'title_asc':
        filtered.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
        break;
      case 'title_desc':
        filtered.sort((a, b) => b.title.toLowerCase().compareTo(a.title.toLowerCase()));
        break;
      case 'price_asc':
        filtered.sort((a, b) => a.creditPrice.compareTo(b.creditPrice));
        break;
      case 'price_desc':
        filtered.sort((a, b) => b.creditPrice.compareTo(a.creditPrice));
        break;
      case 'rating_desc':
        filtered.sort((a, b) => b.averageRating.compareTo(a.averageRating));
        break;
      case 'rating_asc':
        filtered.sort((a, b) => a.averageRating.compareTo(b.averageRating));
        break;
      default:
        break;
    }

    return filtered;
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
        if (showSpinner) {
          _loadingBooks = true;
        }
        _bookError = null;
      });
    }

    try {
      final books = await _catalogService.getAllBooks(
        auth: true,
        forceRefresh: false, // Use smart caching instead of force refresh
      );
      if (!mounted) return;
      setState(() {
        _books = books;
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
      final updatedCopies =
          book.availableCopies > 0 ? book.availableCopies - 1 : 0;
      _catalogService.markBookOwned(
        book.id,
        availableCopies: updatedCopies,
      );
      if (_cartService.itemFor(book.id) != null) {
        await _cartService.remove(book.id);
      }
      if (!mounted) return;
      setState(() {
        _books = _books
            .map(
              (b) => b.id == book.id
                  ? b.copyWith(
                      owned: true,
                      availableCopies: updatedCopies,
                    )
                  : b,
            )
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
    return ResponsiveNavigationWrapper(
      currentRoute: '/home',
      appBar: AppBar(
        title: Text(t.home),
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Sticky search bar
            SliverPersistentHeader(
              pinned: true,
              delegate: _StickySearchDelegate(
                child: _buildSearchBarSection(context, t),
                height: 80.0,
              ),
            ),
            // Search suggestions (non-sticky, appears below sticky header)
            if (_showSuggestions && _searchController.text.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: _buildSearchSuggestions(context, t),
                ),
              ),
            // Content
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHeader(context, t),
                    const SizedBox(height: 20),
                    const Divider(height: 1),
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
            ),
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

    final filteredBooks = _getFilteredAndSortedBooks();

    final activeFilterCount = _selectedCategoryIds.length + _selectedAuthorIds.length + (_searchQuery.isNotEmpty ? 1 : 0);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Active filter chips - always show if filters are active
        if (activeFilterCount > 0)
          _buildActiveFilterChips(context, t),
        
        if (activeFilterCount > 0)
          const SizedBox(height: 16),
        
        // Result count with icon
        Row(
          children: [
            Icon(
              Icons.menu_book,
              size: 20,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              filteredBooks.length == 1 
                  ? t.showingBooksCount.replaceAll('{count}', filteredBooks.length.toString())
                  : t.showingBooksCountPlural.replaceAll('{count}', filteredBooks.length.toString()),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (filteredBooks.isEmpty)
          _buildNoResultsState(context, t)
        else
          _buildBookGrid(context, t, filteredBooks),
      ],
    );
  }

  Widget _buildSearchBarSection(BuildContext context, AppLocalizations t) {
    final activeFilterCount = _selectedCategoryIds.length + _selectedAuthorIds.length + (_searchQuery.isNotEmpty ? 1 : 0);
    final theme = Theme.of(context);
    
    return Container(
      height: 80.0, // Fixed height to match delegate extent
      color: theme.colorScheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextField(
              controller: _searchController,
              focusNode: _searchFocusNode,
              onChanged: (value) {
                setState(() {
                  _showSuggestions = value.isNotEmpty;
                });
              },
              decoration: InputDecoration(
                hintText: t.searchBooksPlaceholder,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _showSuggestions = false;
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Filter toggle button - always opens bottom sheet/dialog
          Badge(
            label: Text(activeFilterCount.toString()),
            isLabelVisible: activeFilterCount > 0,
            child: FilledButton.tonalIcon(
              onPressed: () {
                _showFilterBottomSheet(context, t);
              },
              icon: const Icon(Icons.filter_alt_outlined),
              label: Text(t.filtersButton),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChips(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.filter_alt, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  t.activeFiltersLabel,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _selectedCategoryIds.clear();
                      _selectedAuthorIds.clear();
                    });
                  },
                  child: Text(t.clearAllFilters),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Search query chip
                if (_searchQuery.isNotEmpty)
                  Chip(
                    avatar: const Icon(Icons.search, size: 18),
                    label: Text(_searchQuery),
                    onDeleted: () {
                      setState(() {
                        _searchController.clear();
                      });
                    },
                  ),
                // Category chips
                ..._selectedCategoryIds.map((id) {
                  final category = _categories.firstWhere((c) => c.id == id);
                  return Chip(
                    avatar: const Icon(Icons.category, size: 18),
                    label: Text(category.name),
                    onDeleted: () {
                      setState(() {
                        _selectedCategoryIds.remove(id);
                      });
                    },
                  );
                }),
                // Author chips
                ..._selectedAuthorIds.map((id) {
                  final author = _authors.firstWhere((a) => a.id == id);
                  return Chip(
                    avatar: const Icon(Icons.person, size: 18),
                    label: Text(author.name),
                    onDeleted: () {
                      setState(() {
                        _selectedAuthorIds.remove(id);
                      });
                    },
                  );
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterBottomSheet(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => StatefulBuilder(
          builder: (context, setModalState) => Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.filter_alt, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    Text(
                      t.filtersButton,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Filter content
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSortAndCategoryFilters(context, t, inBottomSheet: true, setModalState: setModalState),
                  ],
                ),
              ),
              // Footer buttons
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () {
                          setState(() {
                            _searchController.clear();
                            _selectedCategoryIds.clear();
                            _selectedAuthorIds.clear();
                            _sortBy = 'title_asc';
                          });
                          setModalState(() {});
                        },
                        child: Text(t.clearAllFilters),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.pop(context);
                        },
                        child: Text(t.applyFilters),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchSuggestions(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    final query = _searchController.text.trim().toLowerCase();
    
    if (query.isEmpty) return const SizedBox.shrink();

    // Find matching results
    final titleMatches = <Book>[];
    final categoryMatches = <Book>[];
    final descMatches = <Book>[];

    for (final book in _books) {
      if (book.title.toLowerCase().contains(query)) {
        titleMatches.add(book);
      }
      if (book.category?.name.toLowerCase().contains(query) ?? false) {
        categoryMatches.add(book);
      }
      if (book.description?.toLowerCase().contains(query) ?? false) {
        descMatches.add(book);
      }
    }

    // Find matching categories
    final matchingCategories = _categories
        .where((cat) => cat.name.toLowerCase().contains(query))
        .toList();

    // Check if we have any matching authors from _authors list
    final hasMatchingAuthors = _authors.any((author) => 
        author.name.toLowerCase().contains(query));

    final hasResults = titleMatches.isNotEmpty ||
        categoryMatches.isNotEmpty ||
        descMatches.isNotEmpty ||
        matchingCategories.isNotEmpty ||
        hasMatchingAuthors;

    if (!hasResults) return const SizedBox.shrink();

    return Card(
      margin: const EdgeInsets.only(top: 8),
      elevation: 4,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 400),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Category suggestions
              if (matchingCategories.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.category, size: 16, color: theme.colorScheme.primary),
                      const SizedBox(width: 8),
                      Text(
                        t.suggestionsCategories,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ...matchingCategories.take(3).map((category) {
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.label_outline, size: 20, color: theme.colorScheme.primary),
                    title: Text(category.name),
                    subtitle: Text(t.filterByThisCategory),
                    onTap: () {
                      setState(() {
                        _selectedCategoryIds.clear();
                        _selectedCategoryIds.add(category.id);
                        _searchController.clear();
                        _showSuggestions = false;
                      });
                      _searchFocusNode.unfocus();
                    },
                  );
                }),
              ],
              // Title matches
              if (titleMatches.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(Icons.menu_book, size: 16, color: theme.colorScheme.secondary),
                      const SizedBox(width: 8),
                      Text(
                        '${t.suggestionsTitles} (${titleMatches.length})',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ...titleMatches.take(3).map((book) {
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.book_outlined, size: 20, color: theme.colorScheme.secondary),
                    title: Text(
                      book.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      book.authors.isNotEmpty ? book.authors[0].name : '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        BookDetailPage.routeName,
                        arguments: BookDetailArgs(bookId: book.id, initial: book),
                      );
                    },
                  );
                }),
              ],
              // Author matches - search directly from _authors list
              () {
                final matchingAuthors = _authors
                    .where((author) => author.name.toLowerCase().contains(query))
                    .take(5)
                    .toList();

                if (matchingAuthors.isEmpty) return const SizedBox.shrink();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Row(
                        children: [
                          Icon(Icons.person, size: 16, color: theme.colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Text(
                            '${t.suggestionsAuthors} (${matchingAuthors.length})',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.tertiary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...matchingAuthors.map((author) {
                      return ListTile(
                        dense: true,
                        leading: Icon(Icons.person_outline, size: 20, color: theme.colorScheme.tertiary),
                        title: Text(author.name),
                        subtitle: Text(t.filterByThisAuthor),
                        onTap: () {
                          setState(() {
                            _selectedAuthorIds.clear();
                            _selectedAuthorIds.add(author.id);
                            _searchController.clear();
                            _showSuggestions = false;
                          });
                          _searchFocusNode.unfocus();
                        },
                      );
                    }),
                  ],
                );
              }(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortAndCategoryFilters(BuildContext context, AppLocalizations t, {bool inBottomSheet = false, Function(VoidCallback)? setModalState}) {
    final theme = Theme.of(context);
    final stateUpdater = inBottomSheet ? setModalState! : setState;
    
    return Card(
      elevation: inBottomSheet ? 0 : 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Sort section
            Row(
              children: [
                Icon(Icons.sort, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  t.sortByLabel,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownMenu<String>(
              initialSelection: _sortBy,
              expandedInsets: EdgeInsets.zero,
              inputDecorationTheme: InputDecorationTheme(
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
              dropdownMenuEntries: [
                DropdownMenuEntry(value: 'title_asc', label: t.sortTitleAsc),
                DropdownMenuEntry(value: 'title_desc', label: t.sortTitleDesc),
                DropdownMenuEntry(value: 'price_asc', label: t.sortPriceAsc),
                DropdownMenuEntry(value: 'price_desc', label: t.sortPriceDesc),
                DropdownMenuEntry(value: 'rating_desc', label: t.sortRatingDesc),
                DropdownMenuEntry(value: 'rating_asc', label: t.sortRatingAsc),
              ],
              onSelected: (value) {
                if (value != null) {
                  stateUpdater(() => _sortBy = value);
                }
              },
            ),
            
            const SizedBox(height: 24),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // Category filter section (collapsible)
            if (_loadingCategories)
              const Center(child: CircularProgressIndicator())
            else if (_categories.isNotEmpty)
              _buildCollapsibleFilterSection(
                context: context,
                t: t,
                title: t.categoriesCount(_categories.length.toString()),
                icon: Icons.category,
                isExpanded: _categoriesExpanded,
                onToggle: () {
                  stateUpdater(() {
                    _categoriesExpanded = !_categoriesExpanded;
                  });
                },
                selectedCount: _selectedCategoryIds.length,
                content: _buildCategoryChips(t, stateUpdater),
              ),
            
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 16),
            
            // Author filter section (collapsible)
            if (_loadingAuthors)
              const Center(child: CircularProgressIndicator())
            else if (_authors.isNotEmpty)
              _buildCollapsibleFilterSection(
                context: context,
                t: t,
                title: t.authorsCount(_authors.length.toString()),
                icon: Icons.person,
                isExpanded: _authorsExpanded,
                onToggle: () {
                  stateUpdater(() {
                    _authorsExpanded = !_authorsExpanded;
                  });
                },
                selectedCount: _selectedAuthorIds.length,
                content: _buildAuthorChips(t, stateUpdater),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCollapsibleFilterSection({
    required BuildContext context,
    required AppLocalizations t,
    required String title,
    required IconData icon,
    required bool isExpanded,
    required VoidCallback onToggle,
    required int selectedCount,
    required Widget content,
  }) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (selectedCount > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      t.categoriesSelected(selectedCount.toString()),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
        if (isExpanded) ...[
          const SizedBox(height: 12),
          content,
        ],
      ],
    );
  }

  Widget _buildCategoryChips(AppLocalizations t, Function(VoidCallback) stateUpdater) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text(t.allCategories),
          selected: _selectedCategoryIds.isEmpty,
          onSelected: (selected) {
            stateUpdater(() {
              _selectedCategoryIds.clear();
            });
          },
        ),
        ..._categories.map((category) {
          return FilterChip(
            label: Text(category.name),
            selected: _selectedCategoryIds.contains(category.id),
            onSelected: (selected) {
              stateUpdater(() {
                if (selected) {
                  _selectedCategoryIds.add(category.id);
                } else {
                  _selectedCategoryIds.remove(category.id);
                }
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildAuthorChips(AppLocalizations t, Function(VoidCallback) stateUpdater) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilterChip(
          label: Text(t.allAuthors),
          selected: _selectedAuthorIds.isEmpty,
          onSelected: (selected) {
            stateUpdater(() {
              _selectedAuthorIds.clear();
            });
          },
        ),
        ..._authors.map((author) {
          return FilterChip(
            label: Text(author.name),
            selected: _selectedAuthorIds.contains(author.id),
            onSelected: (selected) {
              stateUpdater(() {
                if (selected) {
                  _selectedAuthorIds.add(author.id);
                } else {
                  _selectedAuthorIds.remove(author.id);
                }
              });
            },
          );
        }),
      ],
    );
  }

  Widget _buildNoResultsState(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);
    
    // Check if filtering by author with no results
    final isAuthorFilter = _selectedAuthorIds.isNotEmpty;
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                isAuthorFilter 
                    ? Icons.library_books_outlined 
                    : Icons.search_off,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 16),
              Text(
                isAuthorFilter
                    ? t.noBooksByAuthor
                    : t.noBooksFound,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                isAuthorFilter
                    ? t.checkBackLater
                    : t.tryAdjustingFilters,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  setState(() {
                    _searchController.clear();
                    _selectedCategoryIds.clear();
                    _selectedAuthorIds.clear();
                    _sortBy = 'title_asc';
                  });
                },
                icon: const Icon(Icons.refresh),
                label: Text(t.clearFilters),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBookGrid(BuildContext context, AppLocalizations t, List<Book> books) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        var crossAxisCount = 1;
        if (width >= 1200) {
          crossAxisCount = 4;
        } else if (width >= 900) {
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
          itemCount: books.length,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: spacing,
            crossAxisSpacing: spacing,
            childAspectRatio: childAspectRatio,
          ),
          itemBuilder: (context, index) =>
              _buildBookCard(context, t, books[index]),
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

    final coverUrl = book.resolvedCoverImageUrl;

    final coverImage = coverUrl != null
        ? Image.network(
            coverUrl,
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
                    // 2. AVERAGE RATING (fixed height)
                    SizedBox(
                      height: 16, // ✅ Fixed height để spacing consistent
                      child: Row(
                        children: [
                          const Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            book.averageRating > 0
                                ? book.averageRating.toStringAsFixed(1)
                                : '0.0',
                            style: theme.textTheme.bodySmall,
                          ),
                        ],
                      ),
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
    final isMobile = MediaQuery.of(context).size.width < 600;
    final rawName = _displayName?.trim() ?? '';
    final rawEmail = _email?.trim() ?? '';
    final label = rawName.isNotEmpty ? rawName : rawEmail;
    final greeting = label.isNotEmpty ? t.helloUser(label) : t.welcome;

    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              greeting, 
              style: isMobile 
                  ? theme.textTheme.titleSmall 
                  : theme.textTheme.titleMedium,
            ),
            if (rawEmail.isNotEmpty && MediaQuery.of(context).size.width >= 400)
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

// Sticky search bar delegate for pinned header
class _StickySearchDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;

  _StickySearchDelegate({
    required this.child,
    this.height = 80.0,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Material(
      elevation: overlapsContent ? 2 : 0,
      child: child,
    );
  }

  @override
  bool shouldRebuild(_StickySearchDelegate oldDelegate) {
    return child != oldDelegate.child || height != oldDelegate.height;
  }
}
