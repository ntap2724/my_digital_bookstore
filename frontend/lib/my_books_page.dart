import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/book_detail.dart';
import 'package:my_flutter_app/config.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/models/user_book.dart';
import 'package:my_flutter_app/pdf_viewer_page.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/library_service.dart';
import 'package:my_flutter_app/widgets/responsive_navigation_wrapper.dart';
import 'package:universal_html/html.dart' as html;

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

  void _openBookDetails(UserBook entry) {
    final navigator = Navigator.of(context);
    final initial = entry.book;

    navigator.pushNamed(
      BookDetailPage.routeName,
      arguments: BookDetailArgs(bookId: entry.bookId, initial: initial),
    );
  }

  Future<void> _readBook(UserBook entry) async {
    final book = entry.book;

    if (book == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Book not found')),
      );
      return;
    }

    if (!book.hasPdf) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.pdfNotAvailable)),
      );
      return;
    }

    // Mark as opened
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

    // Web: Download PDF and open in new tab
    if (kIsWeb) {
      if (!mounted) return;
      
      // Show loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
              const SizedBox(width: 16),
              Text(context.l10n.downloadingPdf),
            ],
          ),
          duration: const Duration(seconds: 30),
        ),
      );

      try {
        final token = await AuthService.instance.getToken();
        if (token == null || token.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).clearSnackBars();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication required')),
          );
          return;
        }

        // Fetch PDF with authorization
        final response = await html.HttpRequest.request(
          '${AppConfig.apiBaseUrl}/api/books/${book.id}/pdf',
          method: 'GET',
          requestHeaders: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/pdf',
          },
          responseType: 'blob',
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();

        // Create blob URL and open in new tab
        final blob = response.response as html.Blob;
        final url = html.Url.createObjectUrlFromBlob(blob);
        html.window.open(url, '_blank');
        
        // Clean up blob URL after a delay
        Future.delayed(const Duration(seconds: 1), () {
          html.Url.revokeObjectUrl(url);
        });
        
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to open PDF: $e')),
        );
      }
      return;
    }

    // Mobile/Desktop: Use in-app PDF viewer
    Navigator.of(context).pushNamed(
      PdfViewerPage.routeName,
      arguments: book,
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return ResponsiveNavigationWrapper(
      currentRoute: '/my-books',
      appBar: AppBar(
        title: Text(t.myBooks),
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
                        onOpenDetails: () => _openBookDetails(entry),
                        onReadBook: () => _readBook(entry),
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
  const _LibraryBookCard({
    required this.entry,
    required this.onOpenDetails,
    required this.onReadBook,
  });

  final UserBook entry;
  final VoidCallback onOpenDetails;
  final VoidCallback onReadBook;

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
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: onOpenDetails,
                  icon: const Icon(Icons.info_outline),
                  label: Text(t.seeDetails),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: book != null && book.hasPdf ? onReadBook : null,
                  icon: const Icon(Icons.menu_book),
                  label: Text(t.readBook),
                ),
              ],
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
