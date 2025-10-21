import 'package:flutter/material.dart';

import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/order.dart';
import 'package:my_flutter_app/models/order_item.dart';
import 'package:my_flutter_app/models/paginated_result.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/widgets/responsive_navigation_wrapper.dart';

class OrderHistoryPage extends StatefulWidget {
  const OrderHistoryPage({super.key});

  @override
  State<OrderHistoryPage> createState() => _OrderHistoryPageState();
}

class _OrderHistoryPageState extends State<OrderHistoryPage> {
  final OrderService _orderService = OrderService.instance;

  final List<Order> _orders = [];

  PaginatedResult<Order>? _page;

  bool _loading = true;

  bool _loadingMore = false;

  String? _error;

  @override
  void initState() {
    super.initState();

    _loadOrders(reset: true);
  }

  Future<void> _loadOrders({bool reset = false}) async {
    final nextPage = reset || _page == null ? 1 : _page!.currentPage + 1;

    if (reset) {
      setState(() {
        _loading = true;

        _error = null;

        _orders.clear();

        _page = null;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final page = await _orderService.fetchOrders(page: nextPage, forceRefresh: reset);

      if (!mounted) {
        return;
      }

      setState(() {
        _page = page;

        if (reset) {
          _orders
            ..clear()
            ..addAll(page.data);
        } else {
          _orders.addAll(page.data);
        }
      });
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      if (reset) {
        setState(() => _error = e.message);
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (!mounted) {
        return;
      }

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

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) {
      return;
    }

    await _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return ResponsiveNavigationWrapper(
      currentRoute: '/orders',
      appBar: AppBar(
        title: Text(t.orderHistory),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: t.refresh,

            onPressed: _loading ? null : () => _loadOrders(reset: true),

            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      // Removed drawer - now using ResponsiveNavigationWrapper

      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(
              message: _error!,

              onRetry: () => _loadOrders(reset: true),
            )
          : RefreshIndicator(
              onRefresh: () => _loadOrders(reset: true),

              child: ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  if (_orders.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),

                      child: Center(child: Text(t.orderEmpty)),
                    )
                  else ...[
                    for (final order in _orders) ...[
                      _OrderCard(order: order),

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

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final Order order;

  String _itemTitle(OrderItem item) {
    final title = item.book?.title;
    if (title != null && title.isNotEmpty) {
      return title;
    }
    return 'Book #\${item.bookId}';
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,

              children: [
                Text(
                  t.orderId(order.id),

                  style: Theme.of(context).textTheme.titleMedium,
                ),

                Chip(label: Text(_statusLabel(t, order.status))),
              ],
            ),

            const SizedBox(height: 8),

            Text(t.orderTotal(order.totalCredit.toString())),

            const SizedBox(height: 4),

            Text(t.orderPlacedAt(_formatDateTime(order.placedAt))),

            if (order.note?.isNotEmpty == true) ...[
              const SizedBox(height: 4),

              Text(order.note!),
            ],

            const SizedBox(height: 12),

            if (order.items.isEmpty)
              Text(t.orderNoItems)
            else
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,

                children: [
                  for (final item in order.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),

                      child: Text(
                        t.orderItemLine(
                          _itemTitle(item),
                          item.quantity.toString(),
                          t.creditUnit(item.unitCredit.toString()),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations t, String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return t.orderStatusCompleted;

      case 'cancelled':
        return t.orderStatusCancelled;

      default:
        return t.orderStatusPending;
    }
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

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';

  final dt = value.toLocal();

  String two(int v) => v.toString().padLeft(2, '0');

  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}
