import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:my_flutter_app/book_detail.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/models/user_book.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/library_service.dart';
import 'package:my_flutter_app/widgets/responsive_navigation_wrapper.dart';

class MyBooksPage extends StatefulWidget {
  const MyBooksPage({super.key});

  @override
  State<MyBooksPage> createState() => _MyBooksPageState();
}

class _MyBooksPageState extends State<MyBooksPage> {
  final LibraryService _libraryService = LibraryService.instance;

  final List<UserBook> _books = [];
  PaginatedResult<UserBook>? _page;

  bool _loading = true;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadLibrary(reset: true);
  }

  Future<void> _loadLibrary({bool reset = false}) async {
    final nextPage = reset || _page == null ? 1 : _page!.currentPage + 1;

    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _books.clear();
        _page = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final result = await _libraryService.fetchLibrary(
        page: nextPage,
        forceRefresh: reset,
      );
      if (!mounted) return;

      setState(() {
        _page = result;
        if (reset) {
          _books
            ..clear()
            ..addAll(result.data);
        } else {
          _books.addAll(result.data);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (reset) {
        setState(() => _error = e.message);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) return;
      if (reset) {
        setState(() => _error = e.toString());
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) {
        if (reset) {
          setState(() => _loading = false);
        } else {
          setState(() => _loadingMore = false);
        }
      }
    }
  }

  bool get _hasMore {
    final page = _page;
    if (page == null) return false;
    return page.currentPage < page.lastPage;
  }

  Future<void> _refresh() => _loadLibrary(reset: true);

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) {
      return;
    }
    await _loadLibrary();
  }

  void _openBook(UserBook entry) {
    final navigator = Navigator.of(context);
    final initial = entry.book;

    _libraryService
        .markOpened(entry.bookId)
        .then((updated) {
          if (!mounted) return;
          final index = _books.indexWhere(
            (element) => element.bookId == updated.bookId,
          );
          if (index >= 0) {
            setState(() {
              _books[index] = updated;
            });
          }
        })
        .catchError((_) {
          // ignore errors for mark opened; the user can still read the book.
        });

    navigator.pushNamed(
      BookDetailPage.routeName,
      arguments: BookDetailArgs(bookId: entry.bookId, initial: initial),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return ResponsiveNavigationWrapper(
      currentRoute: '/my-books',
      appBar: AppBar(
        title: Text(t.myBooks),
        automaticallyImplyLeading: false,
      ),
      // Removed drawer - now using ResponsiveNavigationWrapper
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!, onRetry: _refresh)
          : RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    t.myBooksSubtitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),
                  if (_books.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 48),
                      child: Center(child: Text(t.myBooksEmpty)),
                    )
                  else ...[
                    for (final entry in _books) ...[
                      _LibraryBookCard(
                        entry: entry,
                        onOpen: () => _openBook(entry),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_hasMore)
                      Center(
                        child: TextButton.icon(
                          onPressed: _loadingMore ? null : _loadMore,
                          icon: _loadingMore
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.more_horiz),
                          label: Text(_loadingMore ? t.loading : t.viewAll),
                        ),
                      ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _LibraryBookCard extends StatelessWidget {
  const _LibraryBookCard({required this.entry, required this.onOpen});

  final UserBook entry;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final book = entry.book;
    final theme = Theme.of(context);
    final rawTitle = book != null ? book.title.trim() : '';
    final displayTitle = rawTitle.isNotEmpty
        ? rawTitle
        : 'Book #${entry.bookId}';
    final authors = (book == null || book.authors.isEmpty)
        ? null
        : book.authors.map((a) => a.name).join(', ');

    final lastPurchased = entry.lastPurchasedAt != null
        ? t.myBooksLastPurchased(_formatDate(entry.lastPurchasedAt!))
        : null;
    final lastOpened = entry.lastOpenedAt != null
        ? t.myBooksLastOpened(_formatDate(entry.lastOpenedAt!))
        : t.myBooksLastOpened('-');

    final trimmedTitle = displayTitle.trim();
    final coverLetter = trimmedTitle.isNotEmpty
        ? trimmedTitle[0].toUpperCase()
        : '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(child: Text(coverLetter)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(displayTitle, style: theme.textTheme.titleMedium),
                      if (authors != null) ...[
                        const SizedBox(height: 4),
                        Text(authors),
                      ],
                      const SizedBox(height: 8),
                      if (lastPurchased != null) ...[
                        const SizedBox(height: 4),
                        Text(lastPurchased),
                      ],
                      const SizedBox(height: 4),
                      Text(lastOpened),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.menu_book_outlined),
                label: Text(t.openBook),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
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
            Text(t.errorPrefix(message), textAlign: TextAlign.center),
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

String _formatDate(DateTime value) {
  final local = value.toLocal();
  return DateFormat.yMMMd().add_Hm().format(local);
}
