import 'package:flutter/material.dart';

import 'package:my_flutter_app/l10n/app_localizations.dart';

import 'package:my_flutter_app/models/paginated_result.dart';

import 'package:my_flutter_app/models/wallet.dart';
import 'package:my_flutter_app/models/wallet_topup_request.dart';
import 'package:my_flutter_app/models/wallet_transaction.dart';

import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/wallet_service.dart';
import 'package:my_flutter_app/services/wallet_topup_service.dart';
import 'package:my_flutter_app/widgets/app_navigation_menu.dart';

class WalletPage extends StatefulWidget {
  const WalletPage({super.key});

  @override
  State<WalletPage> createState() => _WalletPageState();
}

class _WalletPageState extends State<WalletPage> {
  final _walletService = WalletService.instance;
  final _topUpService = WalletTopUpService.instance;

  Wallet? _wallet;

  final List<WalletTransaction> _transactions = [];

  PaginatedResult<WalletTransaction>? _page;

  bool _loading = true;

  bool _loadingMore = false;

  bool _isAdmin = false;

  String? _error;

  final List<WalletTopUpRequest> _topUps = [];
  PaginatedResult<WalletTopUpRequest>? _topUpPage;
  bool _loadingTopUps = true;
  String? _topUpError;
  bool _topUpLoadingMore = false;
  final Set<int> _topUpActioning = <int>{};

  @override
  void initState() {
    super.initState();

    _loadProfile();

    _loadWallet(reset: true);

    _loadTopUps(reset: true);
  }

  Future<void> _loadProfile() async {
    try {
      final me = await AuthService.instance.me();

      if (!mounted) return;

      setState(() {
        _isAdmin = me?['role']?.toString().toLowerCase() == 'admin';
      });
    } catch (_) {}
  }

  Future<void> _loadWallet({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _wallet = null;
        _transactions.clear();
        _page = null;
      });
    }

    try {
      final wallet = await _walletService.getCurrentWallet(forceRefresh: reset);
      final txPage = await _walletService.getCurrentTransactions(
        forceRefresh: reset,
      );

      if (!mounted) return;

      setState(() {
        _wallet = wallet;
        _page = txPage;
        _transactions
          ..clear()
          ..addAll(txPage.data);
        _error = null;
      });
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

  Future<void> _loadTopUps({bool reset = false}) async {
    if (reset) {
      setState(() {
        _loadingTopUps = true;
        _topUpError = null;
        _topUps.clear();
        _topUpPage = null;
      });
    }

    try {
      final page = await _topUpService.fetch(forceRefresh: reset);
      if (!mounted) return;
      setState(() {
        _topUpPage = page;
        _topUps
          ..clear()
          ..addAll(page.data);
        _topUpError = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _topUpError = e.message);
    } catch (e) {
      if (!mounted) return;
      setState(() => _topUpError = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loadingTopUps = false);
      }
    }
  }

  bool get _hasMoreTopUps {
    final page = _topUpPage;
    if (page == null) return false;
    return page.currentPage < page.lastPage;
  }

  Future<void> _loadMoreTopUps() async {
    if (_topUpLoadingMore || !_hasMoreTopUps) return;

    setState(() => _topUpLoadingMore = true);

    try {
      final next = await _topUpService.fetch(
        page: (_topUpPage?.currentPage ?? 1) + 1,
      );
      if (!mounted) return;
      setState(() {
        _topUpPage = next;
        _topUps.addAll(next.data);
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() => _topUpLoadingMore = false);
      }
    }
  }

  Future<void> _showTopUpDialog() async {
    final t = context.l10n;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    String? error;
    var submitting = false;

    final success = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateDialog) {
            return AlertDialog(
              title: Text(t.walletTopUpRequest),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: amountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: t.walletTopUpAmountLabel,
                      errorText: error,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: t.walletTopUpNoteLabel,
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: submitting
                      ? null
                      : () {
                          Navigator.of(ctx).pop(false);
                        },
                  child: Text(t.cancel),
                ),
                FilledButton(
                  onPressed: submitting
                      ? null
                      : () async {
                          final rawAmount = amountController.text.trim();
                          final amount = int.tryParse(rawAmount);
                          if (amount == null || amount <= 0) {
                            setStateDialog(
                              () => error = t.walletTopUpAmountInvalid,
                            );
                            return;
                          }

                          setStateDialog(() {
                            submitting = true;
                            error = null;
                          });

                          try {
                            await _topUpService.create(
                              amount: amount,
                              note: noteController.text.trim().isEmpty
                                  ? null
                                  : noteController.text.trim(),
                            );
                            if (!ctx.mounted) return;
                            Navigator.of(ctx).pop(true);
                          } on ApiException catch (e) {
                            if (!ctx.mounted) return;
                            setStateDialog(() {
                              error = e.message.isNotEmpty
                                  ? e.message
                                  : t.walletTopUpAmountInvalid;
                              submitting = false;
                            });
                          } catch (e) {
                            if (!ctx.mounted) return;
                            setStateDialog(() {
                              error = e.toString();
                              submitting = false;
                            });
                          }
                        },
                  child: submitting
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(t.walletTopUpSubmit),
                ),
              ],
            );
          },
        );
      },
    );

    amountController.dispose();
    noteController.dispose();

    if (success == true) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(t.walletTopUpSuccess)));
      await _loadTopUps(reset: true);
    }
  }

  Future<void> _processTopUp(
    WalletTopUpRequest request, {
    required bool approve,
  }) async {
    if (_topUpActioning.contains(request.id)) return;

    setState(() {
      _topUpActioning.add(request.id);
    });

    final t = context.l10n;
    final messenger = ScaffoldMessenger.of(context);

    try {
      final updated = approve
          ? await _topUpService.approve(request.id)
          : await _topUpService.reject(request.id);

      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            approve ? t.walletTopUpApproveSuccess : t.walletTopUpRejectSuccess,
          ),
        ),
      );

      await _loadTopUps(reset: true);

      if (approve) {
        _walletService.invalidateWallet(updated.userId);
        if (_wallet?.userId == updated.userId) {
          await _loadWallet(reset: true);
        }
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _topUpActioning.remove(request.id);
        });
      }
    }
  }

  Widget _buildTopUpSection(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                t.walletTopUpRequests,
                style: theme.textTheme.titleMedium,
              ),
            ),
            if (!_isAdmin)
              FilledButton.icon(
                onPressed: _loadingTopUps ? null : _showTopUpDialog,
                icon: const Icon(Icons.add_circle_outline),
                label: Text(t.walletTopUp),
              )
            else
              IconButton(
                tooltip: t.refresh,
                onPressed: _loadingTopUps
                    ? null
                    : () => _loadTopUps(reset: true),
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (_loadingTopUps)
          const Center(child: CircularProgressIndicator())
        else if (_topUpError != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(t.errorPrefix(_topUpError!)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => _loadTopUps(reset: true),
                      child: Text(t.tryAgain),
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (_topUps.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(t.walletTopUpNoRequests),
          )
        else ...[
          for (final request in _topUps) ...[
            _TopUpCard(
              request: request,
              t: t,
              isAdmin: _isAdmin,
              loading: _topUpActioning.contains(request.id),
              onApprove: !_isAdmin || !request.isPending
                  ? null
                  : () => _processTopUp(request, approve: true),
              onReject: !_isAdmin || !request.isPending
                  ? null
                  : () => _processTopUp(request, approve: false),
            ),
            const SizedBox(height: 12),
          ],
          if (_hasMoreTopUps)
            Center(
              child: TextButton.icon(
                onPressed: _topUpLoadingMore ? null : _loadMoreTopUps,
                icon: _topUpLoadingMore
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.more_horiz),
                label: Text(_topUpLoadingMore ? t.loading : t.viewAll),
              ),
            ),
        ],
      ],
    );
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;

    setState(() => _loadingMore = true);

    try {
      final next = await _walletService.getCurrentTransactions(
        page: (_page?.currentPage ?? 1) + 1,
      );

      if (!mounted) return;

      setState(() {
        _page = next;

        _transactions.addAll(next.data);
      });
    } on ApiException catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  bool get _hasMore {
    final page = _page;

    if (page == null) return false;

    return page.currentPage < page.lastPage;
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    final wallet = _wallet;

    return Scaffold(
      appBar: AppBar(
        title: Text(t.wallet),

        actions: [
          IconButton(
            tooltip: t.refresh,

            onPressed: _loading ? null : () => _loadWallet(reset: true),

            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      drawer: const AppNavigationMenu(currentRoute: '/wallet'),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(
              message: _error!,

              onRetry: () => _loadWallet(reset: true),
            )
          : wallet == null
          ? Center(child: Text(t.walletsEmpty))
          : RefreshIndicator(
              onRefresh: () => _loadWallet(reset: true),

              child: ListView(
                padding: const EdgeInsets.all(16),

                children: [
                  _buildWalletHeader(context, t, wallet),

                  const SizedBox(height: 16),

                  _buildTopUpSection(context, t),

                  const SizedBox(height: 24),

                  Text(
                    t.walletTransactions,

                    style: Theme.of(context).textTheme.titleMedium,
                  ),

                  const SizedBox(height: 8),

                  if (_transactions.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 32),

                      child: Center(child: Text(t.walletNoTransactions)),
                    )
                  else ...[
                    for (final tx in _transactions) ...[
                      _TransactionTile(transaction: tx),

                      const Divider(height: 1),
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

      floatingActionButton: _isAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).pushNamed('/admin');
              },
              icon: const Icon(Icons.admin_panel_settings_outlined),
              label: Text(t.adminPanel),
            )
          : FloatingActionButton.extended(
              onPressed: _loadingTopUps ? null : _showTopUpDialog,
              icon: const Icon(Icons.add),
              label: Text(t.walletTopUp),
            ),
    );
  }

  Widget _buildWalletHeader(
    BuildContext context,

    AppLocalizations t,

    Wallet wallet,
  ) {
    final balance = wallet.balance.toString();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Text(
              t.walletBalance(t.creditUnit(balance)),

              style: Theme.of(context).textTheme.titleLarge,
            ),

            const SizedBox(height: 8),

            Text(t.walletUpdatedAt(_formatDateTime(wallet.updatedAt))),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    final theme = Theme.of(context);

    final isCredit = transaction.type == 'credit';

    final isDebit = transaction.type == 'debit';

    final amountPrefix = isCredit
        ? '+'
        : isDebit
        ? '-'
        : '';

    final amountColor = isCredit
        ? Colors.green
        : isDebit
        ? theme.colorScheme.error
        : theme.colorScheme.primary;

    String typeLabel;

    switch (transaction.type) {
      case 'credit':
        typeLabel = t.transactionTypeCredit;

        break;

      case 'debit':
        typeLabel = t.transactionTypeDebit;

        break;

      default:
        typeLabel = t.transactionTypeAdjustment;
    }

    return ListTile(
      leading: Icon(
        isCredit
            ? Icons.arrow_downward
            : isDebit
            ? Icons.arrow_upward
            : Icons.sync_alt,

        color: amountColor,
      ),

      title: Text(typeLabel),

      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Text(
            '${_formatDateTime(transaction.createdAt)} - ${t.creditUnit(transaction.balanceAfter.toString())}',
          ),

          if (transaction.description?.isNotEmpty == true)
            Text(transaction.description!),
        ],
      ),

      trailing: Text(
        '$amountPrefix${t.creditUnit(transaction.amount.abs().toString())}',

        style: theme.textTheme.titleMedium?.copyWith(color: amountColor),
      ),
    );
  }
}

class _TopUpCard extends StatelessWidget {
  const _TopUpCard({
    required this.request,
    required this.t,
    required this.isAdmin,
    required this.loading,
    this.onApprove,
    this.onReject,
  });

  final WalletTopUpRequest request;
  final AppLocalizations t;
  final bool isAdmin;
  final bool loading;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final statusLabel = _statusLabel(t, request.status);
    final statusColor = _statusColor(theme, request.status);
    final userName = request.user?['name']?.toString();

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
                  t.creditUnit(request.amount.toString()),
                  style: theme.textTheme.titleMedium,
                ),
                Chip(
                  label: Text(statusLabel),
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                  labelStyle: theme.textTheme.bodySmall?.copyWith(
                    color: statusColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (isAdmin && userName != null)
              Text(userName, style: theme.textTheme.bodyMedium),
            if (request.note != null && request.note!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(request.note!),
            ],
            if (request.responseNote != null &&
                request.responseNote!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(request.responseNote!),
            ],
            const SizedBox(height: 8),
            Text(
              t.lastUpdated(_formatDateTime(request.createdAt)),
              style: theme.textTheme.bodySmall,
            ),
            if (request.respondedAt != null)
              Text(
                _formatDateTime(request.respondedAt),
                style: theme.textTheme.bodySmall,
              ),
            if (isAdmin && request.isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: loading ? null : onReject,
                      icon: const Icon(Icons.close),
                      label: Text(t.walletTopUpReject),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: loading ? null : onApprove,
                      icon: const Icon(Icons.check),
                      label: Text(t.walletTopUpApprove),
                    ),
                  ),
                ],
              ),
              if (loading) ...[
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  String _statusLabel(AppLocalizations t, String status) {
    switch (status) {
      case 'approved':
        return t.walletTopUpStatusApproved;
      case 'rejected':
        return t.walletTopUpStatusRejected;
      default:
        return t.walletTopUpStatusPending;
    }
  }

  Color _statusColor(ThemeData theme, String status) {
    switch (status) {
      case 'approved':
        return Colors.green;
      case 'rejected':
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.primary;
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
