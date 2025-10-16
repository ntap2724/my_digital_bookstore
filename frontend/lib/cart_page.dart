import 'package:flutter/material.dart';

import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/cart_item.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/cart_service.dart';
import 'package:my_flutter_app/services/library_service.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/widgets/app_navigation_menu.dart';

class CartPage extends StatefulWidget {
  const CartPage({super.key});

  @override
  State<CartPage> createState() => _CartPageState();
}

class _CartPageState extends State<CartPage> {
  final CartService _cartService = CartService.instance;
  final OrderService _orderService = OrderService.instance;

  final Set<int> _updatingItems = <int>{};

  bool _checkingOut = false;

  @override
  void initState() {
    super.initState();
    _cartService.ensureLoaded();
  }

  Future<void> _removeItem(CartItem item) async {
    if (_updatingItems.contains(item.bookId)) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _updatingItems.add(item.bookId);
    });

    final t = context.l10n;

    try {
      await _cartService.remove(item.bookId);
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(t.cartUpdateFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _updatingItems.remove(item.bookId);
        });
      }
    }
  }

  Future<void> _checkout(BuildContext context) async {
    if (_checkingOut || _cartService.isEmpty) return;

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final t = context.l10n;

    setState(() {
      _checkingOut = true;
    });

    try {
      final payload = _cartService.items
          .map((item) => {'book_id': item.bookId, 'quantity': 1})
          .toList(growable: false);

      await _orderService.placeOrder(items: payload);
      await _cartService.clear();
      LibraryService.instance.invalidateCache();

      messenger.showSnackBar(
        SnackBar(
          content: Text(t.cartCheckoutSuccess),
          action: SnackBarAction(
            label: t.orders,
            onPressed: () {
              navigator.pushNamed('/orders');
            },
          ),
        ),
      );
    } on ApiException catch (e) {
      final message = e.message.isNotEmpty ? e.message : t.cartCheckoutFailed;
      messenger.showSnackBar(SnackBar(content: Text(message)));
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(t.cartCheckoutFailed)));
    } finally {
      if (mounted) {
        setState(() {
          _checkingOut = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(t.cart)),
      drawer: const AppNavigationMenu(currentRoute: '/cart'),
      body: AnimatedBuilder(
        animation: _cartService,
        builder: (context, _) {
          if (!_cartService.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }
          if (_cartService.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  t.cartEmpty,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            );
          }

          final items = _cartService.items;

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 144),
            itemCount: items.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final item = items[index];
              final loading = _updatingItems.contains(item.bookId);
              return _CartItemTile(
                item: item,
                t: t,
                loading: loading,
                onRemove: () => _removeItem(item),
              );
            },
          );
        },
      ),
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    final theme = Theme.of(context);
    final t = context.l10n;
    return AnimatedBuilder(
      animation: _cartService,
      builder: (context, _) {
        if (!_cartService.isLoaded || _cartService.isEmpty) {
          return const SizedBox.shrink();
        }

        final total = _cartService.totalCredits;
        final quantity = _cartService.totalQuantity;

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            boxShadow: const [
              BoxShadow(
                blurRadius: 6,
                color: Colors.black12,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        t.orderTotal(total.toString()),
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        '${t.quantity}: $quantity',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _checkingOut ? null : () => _checkout(context),
                    child: _checkingOut
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(t.cartCheckout),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({
    required this.item,
    required this.t,
    required this.loading,
    required this.onRemove,
  });

  final CartItem item;
  final AppLocalizations t;
  final bool loading;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final avatarText = item.title.isNotEmpty
        ? item.title[0].toUpperCase()
        : '?';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(child: Text(avatarText)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(item.title, style: theme.textTheme.titleMedium),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  tooltip: t.remove,
                  onPressed: loading ? null : onRemove,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  t.bookPrice(item.creditPrice.toString()),
                  style: theme.textTheme.bodyMedium,
                ),
                Text(
                  t.creditUnit(item.totalCredit.toString()),
                  style: theme.textTheme.titleMedium,
                ),
              ],
            ),
            if (loading) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
