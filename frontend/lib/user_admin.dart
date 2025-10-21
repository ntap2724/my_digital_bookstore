import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:my_flutter_app/l10n/app_localizations.dart';
import 'package:my_flutter_app/models/author.dart';
import 'package:my_flutter_app/models/book.dart';
import 'package:my_flutter_app/models/category.dart';
import 'package:my_flutter_app/models/user.dart';
import 'package:my_flutter_app/models/wallet.dart';
import 'package:my_flutter_app/services/api_client.dart';
import 'package:my_flutter_app/services/auth_service.dart';
import 'package:my_flutter_app/services/catalog_service.dart';
import 'package:my_flutter_app/services/order_service.dart';
import 'package:my_flutter_app/services/user_service.dart';
import 'package:my_flutter_app/services/wallet_service.dart';
import 'package:my_flutter_app/widgets/responsive_navigation_wrapper.dart';

class UserAdminPage extends StatefulWidget {
  const UserAdminPage({super.key});

  @override
  State<UserAdminPage> createState() => _UserAdminPageState();
}

class _UserAdminPageState extends State<UserAdminPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final GlobalKey<_UserAdminViewState> _userKey =
      GlobalKey<_UserAdminViewState>();
  final GlobalKey<_BookAdminViewState> _bookKey =
      GlobalKey<_BookAdminViewState>();
  final GlobalKey<_AuthorAdminViewState> _authorKey =
      GlobalKey<_AuthorAdminViewState>();
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  void _handleTabChanged() {
    if (_tabController.indexIsChanging) return;
    if (!mounted) return;
    setState(() => _currentTab = _tabController.index);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  bool get _isUserLoading => _userKey.currentState?.isLoading ?? false;
  bool get _isBookLoading => _bookKey.currentState?.isLoading ?? false;
  bool get _isAuthorLoading => _authorKey.currentState?.isLoading ?? false;

  void _refreshCurrentTab() {
    if (_currentTab == 0) {
      _userKey.currentState?.refreshUsers();
    } else if (_currentTab == 1) {
      _bookKey.currentState?.refreshBooks();
    } else {
      _authorKey.currentState?.refreshAuthors();
    }
  }

  void _createBook() {
    _bookKey.currentState?.createBook();
  }

  void _createAuthor() {
    _authorKey.currentState?.createAuthor();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;
    final isBookTab = _currentTab == 1;
    final isAuthorTab = _currentTab == 2;
    final isLoading = _currentTab == 0
        ? _isUserLoading
        : _currentTab == 1
            ? _isBookLoading
            : _isAuthorLoading;

    return ResponsiveNavigationWrapper(
      currentRoute: '/admin',
      appBar: AppBar(
        title: Text(t.adminPanel),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: t.refresh,
            onPressed: isLoading ? null : _refreshCurrentTab,
            icon: const Icon(Icons.refresh),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              icon: const Icon(Icons.people_alt_outlined),
              text: t.adminTabUsers,
            ),
            Tab(
              icon: const Icon(Icons.menu_book_outlined),
              text: t.adminTabBooks,
            ),
            Tab(
              icon: const Icon(Icons.person_outlined),
              text: t.adminTabAuthors,
            ),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          UserAdminView(key: _userKey),
          BookAdminView(key: _bookKey),
          AuthorAdminView(key: _authorKey),
        ],
      ),
      floatingActionButton: isBookTab
          ? FloatingActionButton(
              onPressed: _createBook,
              tooltip: t.bookAdd,
              child: const Icon(Icons.add),
            )
          : isAuthorTab
              ? FloatingActionButton(
                  onPressed: _createAuthor,
                  tooltip: t.authorAdd,
                  child: const Icon(Icons.add),
                )
              : null,
    );
  }
}

class UserAdminView extends StatefulWidget {
  const UserAdminView({super.key});

  @override
  State<UserAdminView> createState() => _UserAdminViewState();
}

class _UserAdminViewState extends State<UserAdminView> {
  static const _allRolesValue = '__all__';

  final UserService _userService = UserService.instance;
  final WalletService _walletService = WalletService.instance;

  final List<User> _allUsers = [];
  final List<User> _users = [];
  final TextEditingController _searchController = TextEditingController();

  bool _loading = true;
  String? _error;
  String? _roleFilter;
  int? _currentUserId;

  final Map<int, Wallet> _wallets = {};
  final Map<int, String> _walletErrors = {};
  final Map<int, bool> _walletNotFound = {};
  final Set<int> _walletLoading = {};
  final Set<int> _deletingUsers = {};

  @override
  void initState() {
    super.initState();
    _loadCurrentUser();
    _searchController.addListener(_onSearchChanged);
    _loadUsers();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_loading && _allUsers.isEmpty) return;
    _applyFilters();
  }

  Future<void> _loadUsers({bool forceBackend = false}) async {
    setState(() {
      _loading = true;
      if (forceBackend) {
        _error = null;
        _wallets.clear();
        _walletErrors.clear();
        _walletNotFound.clear();
        _walletLoading.clear();
        _deletingUsers.clear();
      }
    });

    try {
      final users = await _userService.getAllUsers(forceRefresh: forceBackend);
      if (!mounted) return;

      setState(() {
        _error = null;
        _allUsers
          ..clear()
          ..addAll(users);
      });

      _applyFilters();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _allUsers.clear();
        _users.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _allUsers.clear();
        _users.clear();
      });
    }
  }

  Future<void> _loadCurrentUser() async {
    try {
      final me = await AuthService.instance.me();
      if (!mounted) return;
      final id = (me?['id'] as num?)?.toInt();
      setState(() => _currentUserId = id);
    } catch (_) {}
  }

  bool get isLoading => _loading;

  Future<void> refreshUsers() => _refreshUsers();

  Future<void> _refreshUsers() async {
    CatalogService.instance.invalidateCache();
    WalletService.instance.invalidateCache();
    OrderService.instance.invalidateCache();
    _userService.invalidateCache();
    await _loadUsers(forceBackend: true);
  }

  void _prefetchWallets(Iterable<User> users) {
    for (final user in users) {
      final id = user.id;
      if (_wallets.containsKey(id) ||
          _walletErrors.containsKey(id) ||
          _walletNotFound.containsKey(id) ||
          _walletLoading.contains(id)) {
        continue;
      }
      unawaited(_loadWallet(user));
    }
  }

  List<DataColumn> _buildColumns(AppLocalizations t) => [
        DataColumn(label: Text(t.userColumnIndex), numeric: true),
        DataColumn(label: Text(t.userColumnEmail)),
        DataColumn(label: Text(t.userColumnName)),
        DataColumn(label: Text(t.userColumnRole)),
        DataColumn(label: Text(t.userColumnDob)),
        DataColumn(label: Text(t.userColumnBalance)),
        DataColumn(label: Text(t.userColumnActions)),
      ];

  List<DataRow> _buildRows(BuildContext context, AppLocalizations t) {
    final theme = Theme.of(context);

    return List<DataRow>.generate(_users.length, (index) {
      final user = _users[index];
      final wallet = _wallets[user.id];
      final walletError = _walletErrors[user.id];
      final walletNotFound = _walletNotFound[user.id] ?? false;
      final loadingWallet = _walletLoading.contains(user.id);

      return DataRow.byIndex(
        index: index,
        cells: [
          DataCell(Text('${index + 1}')),
          DataCell(SelectableText(user.email)),
          DataCell(
            SelectableText(user.name.isNotEmpty ? user.name : '-'),
          ),
          DataCell(Text(_roleLabel(user.role, t))),
          DataCell(Text(_formatDate(user.dob))),
          DataCell(
            _buildBalanceCell(
              context,
              t,
              theme,
              user,
              wallet,
              walletError,
              walletNotFound,
              loadingWallet,
            ),
          ),
          DataCell(
            _buildActionsCell(
              context,
              t,
              user,
              loadingWallet,
              _deletingUsers.contains(user.id),
              _isCurrentUser(user),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildBalanceCell(
    BuildContext context,
    AppLocalizations t,
    ThemeData theme,
    User user,
    Wallet? wallet,
    String? walletError,
    bool walletNotFound,
    bool loadingWallet,
  ) {
    if (loadingWallet) {
      return const SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (walletNotFound) {
      return Text(
        t.userWalletMissing,
        style: theme.textTheme.bodySmall,
      );
    }

    if (walletError != null) {
      return ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 200),
        child: Text(
          walletError,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      );
    }

    final walletInfo = wallet;
    if (walletInfo != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            t.creditUnit(walletInfo.balance.toString()),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (walletInfo.updatedAt != null)
            Text(
              t.walletUpdatedAt(_formatDateTime(walletInfo.updatedAt)),
              style: theme.textTheme.bodySmall,
            ),
        ],
      );
    }

    return TextButton(
      onPressed: () => _loadWallet(user),
      child: Text(t.userWalletLoad),
    );
  }

  Widget _buildActionsCell(
    BuildContext context,
    AppLocalizations t,
    User user,
    bool loadingWallet,
    bool deleting,
    bool isCurrentUser,
  ) {
    final theme = Theme.of(context);

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: loadingWallet || deleting
              ? null
              : () => _handleManageWallet(user),
          icon: const Icon(Icons.account_balance_wallet_outlined),
          label: Text(t.userWalletManage),
        ),
        OutlinedButton.icon(
          onPressed: loadingWallet || deleting
              ? null
              : () => _loadWallet(user, force: true),
          icon: const Icon(Icons.refresh),
          label: Text(t.userWalletRefresh),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.errorContainer,
            foregroundColor: theme.colorScheme.onErrorContainer,
          ),
          onPressed: deleting || isCurrentUser
              ? null
              : () => _confirmDeleteUser(user),
          icon: deleting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.delete_outline),
          label: Text(
            deleting ? t.userDeleteInProgress : t.userDeleteAction,
          ),
        ),
      ],
    );
  }


  Future<void> _confirmDeleteUser(User user) async {
    final t = context.l10n;
    final email = user.email;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.userDeleteTitle),
        content: Text(t.userDeleteMessage(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(t.userDeleteConfirm),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    setState(() => _deletingUsers.add(user.id));

    try {
      await _userService.deleteUser(user.id);
      if (!mounted) return;

      setState(() {
        _users.removeWhere((u) => u.id == user.id);
        _allUsers.removeWhere((u) => u.id == user.id);
        _wallets.remove(user.id);
        _walletErrors.remove(user.id);
        _walletNotFound.remove(user.id);
        _walletLoading.remove(user.id);
      });
      _showSnack(t.userDeleteSuccess);
    } on ApiException catch (e) {
      if (!mounted) return;
      final message = e.message.isNotEmpty ? e.message : t.userDeleteFailure;
      _showSnack(message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(t.userDeleteFailure);
    } finally {
      if (mounted) {
        setState(() => _deletingUsers.remove(user.id));
      }
    }
  }

  bool _isCurrentUser(User user) =>
      _currentUserId != null && user.id == _currentUserId;

  String _formatDate(DateTime? value) {
    if (value == null) return '-';
    final dt = value.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${dt.year}-${two(dt.month)}-${two(dt.day)}';
  }

  Future<Wallet?> _loadWallet(User user, {bool force = false}) async {
    final id = user.id;
    final t = context.l10n;

    if (!force && _wallets.containsKey(id) && !_walletErrors.containsKey(id)) {
      return _wallets[id];
    }

    setState(() {
      _walletLoading.add(id);
      if (force) {
        _walletErrors.remove(id);
        _walletNotFound.remove(id);
      }
    });

    try {
      final wallet = await _walletService.getWallet(id);
      if (!mounted) return wallet;

      setState(() {
        _wallets[id] = wallet;
        _walletErrors.remove(id);
        _walletNotFound.remove(id);
      });
      return wallet;
    } on ApiException catch (e) {
      if (!mounted) return null;

      final notFound = e.statusCode == 404;
      final message = notFound
          ? t.walletsEmpty
          : (e.message.isNotEmpty ? e.message : t.walletAdjustFailed);

      setState(() {
        _wallets.remove(id);
        _walletErrors[id] = message;
        _walletNotFound[id] = notFound;
      });

      if (!notFound) {
        _showSnack(message);
      }
      return null;
    } catch (e) {
      if (!mounted) return null;

      final message = e.toString();
      setState(() {
        _wallets.remove(id);
        _walletErrors[id] = message;
        _walletNotFound[id] = false;
      });
      _showSnack(message);
      return null;
    } finally {
      if (mounted) {
        setState(() => _walletLoading.remove(id));
      }
    }
  }

  Future<void> _handleManageWallet(User user) async {
    var wallet = _wallets[user.id];
    wallet ??= await _loadWallet(user);
    if (!mounted || wallet == null) return;

    await _showWalletSheet(user, wallet);
  }

  Future<void> _showWalletSheet(User user, Wallet wallet) async {
    final t = context.l10n;
    Wallet? currentWallet = wallet;
    var localLoading = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          Future<void> refresh() async {
            setDialogState(() => localLoading = true);
            final updated = await _loadWallet(user, force: true);
            if (!mounted) return;
            if (updated != null) {
              currentWallet = updated;
            }
            setDialogState(() => localLoading = false);
          }

          Future<void> adjust() async {
            final success = await _showAdjustDialog(user);
            if (!mounted) return;
            if (success) {
              final updated = await _loadWallet(user, force: true);
              if (updated != null) {
                currentWallet = updated;
              }
              setDialogState(() {});
            }
          }

          final theme = Theme.of(ctx);
          final walletInfo = currentWallet;

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: 24 + MediaQuery.of(ctx).viewInsets.bottom,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          t.wallet,
                          style: theme.textTheme.titleLarge,
                        ),
                        IconButton(
                          tooltip: t.close,
                          onPressed: () => Navigator.of(ctx).pop(),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user.name.isNotEmpty ? user.name : user.email,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(user.email),
                    const SizedBox(height: 16),
                    if (localLoading)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      )
                    else if (walletInfo == null)
                      Text(
                        t.walletsEmpty,
                        style: theme.textTheme.bodyMedium,
                      )
                    else ...[
                      Text(
                        t.walletBalance(
                          t.creditUnit(walletInfo.balance.toString()),
                        ),
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        t.walletUpdatedAt(
                          _formatDateTime(walletInfo.updatedAt),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: localLoading ? null : refresh,
                          icon: const Icon(Icons.refresh),
                          label: Text(t.refresh),
                        ),
                        FilledButton.icon(
                          onPressed: localLoading || currentWallet == null
                              ? null
                              : adjust,
                          icon: const Icon(Icons.tune_outlined),
                          label: Text(t.walletAdjust),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Future<bool> _showAdjustDialog(User user) async {
    final t = context.l10n;
    final amountController = TextEditingController();
    final noteController = TextEditingController();
    var selectedType = 'credit';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(t.walletAdjust),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownMenu<String>(
                initialSelection: selectedType,
                label: Text(t.walletAdjustType),
                onSelected: (value) => setDialogState(
                  () => selectedType = value ?? 'credit',
                ),
                dropdownMenuEntries: [
                  DropdownMenuEntry(
                    value: 'credit',
                    label: t.transactionTypeCredit,
                  ),
                  DropdownMenuEntry(
                    value: 'debit',
                    label: t.transactionTypeDebit,
                  ),
                  DropdownMenuEntry(
                    value: 'adjustment',
                    label: t.transactionTypeAdjustment,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: t.walletAdjustAmount),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: noteController,
                decoration: InputDecoration(labelText: t.walletAdjustNote),
                maxLines: 3,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(t.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(t.confirm),
            ),
          ],
        ),
      ),
    );

    if (confirmed != true) {
      return false;
    }

    final amount = int.tryParse(amountController.text.trim());
    if (amount == null || amount < 0) {
      _showSnack(t.walletAdjustFailed);
      return false;
    }

    if (selectedType != 'adjustment' && amount == 0) {
      _showSnack(t.walletAdjustFailed);
      return false;
    }

    try {
      await _walletService.adjustWallet(
        user.id,
        type: selectedType,
        amount: amount,
        description: noteController.text.trim().isNotEmpty
            ? noteController.text.trim()
            : null,
      );
      if (!mounted) return true;

      _showSnack(t.walletAdjustSuccess);
      await _loadWallet(user, force: true);
      return true;
    } on ApiException catch (e) {
      if (!mounted) return false;
      final message =
          e.message.isNotEmpty ? e.message : t.walletAdjustFailed;
      _showSnack(message);
      return false;
    } catch (e) {
      if (!mounted) return false;
      _showSnack(e.toString());
      return false;
    }
  }

  void _applyFilters() {
    final search = _searchController.text.trim().toLowerCase();
    final role = _roleFilter?.trim().toLowerCase();

    final filtered = _allUsers.where((user) {
      final matchesRole =
          role == null || role.isEmpty || user.role.toLowerCase() == role;
      if (!matchesRole) return false;

      if (search.isEmpty) return true;
      final name = user.name.toLowerCase();
      final email = user.email.toLowerCase();
      return name.contains(search) || email.contains(search);
    }).toList(growable: false);

    setState(() {
      _users
        ..clear()
        ..addAll(filtered);
      _loading = false;
    });

    _prefetchWallets(filtered);
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
  }

  void _showSnack(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: () => _refreshUsers(),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _UserFilters(
            searchController: _searchController,
            selectedRole: _roleFilter ?? _allRolesValue,
            loading: _loading,
            onClearSearch: _clearSearch,
            onSubmitted: (_) => _applyFilters(),
            onRoleChanged: (value) {
              final role = value == _allRolesValue ? null : value;
              if (role == _roleFilter) return;
              setState(() => _roleFilter = role);
              _applyFilters();
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _refreshUsers(),
            child: _users.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 48,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Text(t.usersEmpty),
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              headingTextStyle:
                                  Theme.of(context).textTheme.labelLarge,
                              columnSpacing: 24,
                              dataRowMinHeight: 68,
                              dataRowMaxHeight: 120,
                              columns: _buildColumns(t),
                              rows: _buildRows(context, t),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class BookAdminView extends StatefulWidget {
  const BookAdminView({super.key});

  @override
  State<BookAdminView> createState() => _BookAdminViewState();
}

class _BookAdminViewState extends State<BookAdminView> {
  static const _allStatusesValue = '__all__';

  final CatalogService _catalogService = CatalogService.instance;
  final TextEditingController _searchController = TextEditingController();

  final List<Book> _allBooks = [];
  final List<Book> _books = [];
  final Set<int> _deleting = {};

  bool _loading = true;
  String? _error;
  String? _statusFilter;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadBooks();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  bool get isLoading => _loading;

  Future<void> refreshBooks() => _loadBooks(forceBackend: true);

  void createBook() => _openEditor();

  void _onSearchChanged() {
    if (_loading && _allBooks.isEmpty) return;
    _applyFilters();
  }

  Future<void> _loadBooks({bool forceBackend = false}) async {
    setState(() {
      _loading = true;
      if (forceBackend) {
        _error = null;
      }
    });

    try {
      final books = await _catalogService.getAllBooks(
        auth: true,
        forceRefresh: forceBackend,
      );
      if (!mounted) return;
      setState(() {
        _allBooks
          ..clear()
          ..addAll(books);
      });
      _applyFilters();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _allBooks.clear();
        _books.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _allBooks.clear();
        _books.clear();
      });
    }
  }

  void _applyFilters() {
    final search = _searchController.text.trim().toLowerCase();
    final status = _statusFilter?.trim().toLowerCase();

    final filtered = _allBooks
        .where((book) {
          final matchesStatus = status == null ||
              status.isEmpty ||
              book.status.toLowerCase() == status;
          if (!matchesStatus) return false;

          if (search.isEmpty) return true;

          bool contains(String? value) =>
              value != null && value.toLowerCase().contains(search);

          return contains(book.title) ||
              contains(book.subtitle) ||
              contains(book.slug) ||
              contains(book.isbn);
        })
        .toList(growable: false)
      ..sort(
        (a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()),
      );

    setState(() {
      _books
        ..clear()
        ..addAll(filtered);
      _loading = false;
    });
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
  }

  Future<void> _openEditor([Book? book]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _BookEditorDialog(book: book),
    );
    if (result == null) return;

    try {
      if (book == null) {
        final created = await _catalogService.createBook(result);
        if (!mounted) return;
        setState(() {
          _allBooks.add(created);
        });
        _applyFilters();
        _showSnack(context.l10n.bookCreateSuccess);
      } else {
        final updated = await _catalogService.updateBook(book.id, result);
        if (!mounted) return;
        setState(() {
          final index = _allBooks.indexWhere((b) => b.id == book.id);
          if (index >= 0) {
            _allBooks[index] = updated;
          }
        });
        _applyFilters();
        _showSnack(context.l10n.bookUpdateSuccess);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString());
    }
  }

  Future<void> _deleteBook(Book book) async {
    final t = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.bookDeleteTitle),
        content: Text(t.bookDeleteMessage(book.title)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.bookDeleteAction),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting.add(book.id));

    try {
      await _catalogService.deleteBook(book.id);
      if (!mounted) return;
      setState(() {
        _allBooks.removeWhere((b) => b.id == book.id);
      });
      _applyFilters();
      _showSnack(t.bookDeleteSuccess);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _deleting.remove(book.id));
      }
    }
  }

  void _showSnack(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<DataColumn> _buildColumns(AppLocalizations t) => [
        DataColumn(label: Text(t.bookColumnIndex), numeric: true),
        DataColumn(label: Text(t.bookColumnTitle)),
        DataColumn(label: Text(t.bookColumnPrice)),
        DataColumn(label: Text(t.bookColumnCopies)),
        DataColumn(label: Text(t.bookColumnStatus)),
        DataColumn(label: Text(t.bookColumnCategory)),
        DataColumn(label: Text(t.bookColumnActions)),
      ];

  List<DataRow> _buildRows(BuildContext context, AppLocalizations t) {
    return List<DataRow>.generate(_books.length, (index) {
      final book = _books[index];
      final isDeleting = _deleting.contains(book.id);
      return DataRow(
        cells: [
          DataCell(Text('${index + 1}')),
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    book.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (book.subtitle != null && book.subtitle!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        book.subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      book.slug,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).hintColor),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DataCell(Text(t.creditUnit(book.creditPrice.toString()))),
          DataCell(Text('${book.availableCopies}')),
          DataCell(Text(_bookStatusLabel(book.status, t))),
          DataCell(Text(book.category?.name ?? t.bookCategoryUnassigned)),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: t.bookEdit,
                  onPressed: () => _openEditor(book),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip:
                      isDeleting ? t.bookDeleteInProgress : t.bookDelete,
                  onPressed: isDeleting ? null : () => _deleteBook(book),
                  icon: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: () => _loadBooks(forceBackend: true),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _BookFilters(
            searchController: _searchController,
            selectedStatus: _statusFilter ?? _allStatusesValue,
            loading: _loading,
            onClearSearch: _clearSearch,
            onSubmitted: (_) => _applyFilters(),
            onStatusChanged: (value) {
              final status = value == _allStatusesValue ? null : value;
              if (status == _statusFilter) return;
              setState(() => _statusFilter = status);
              _applyFilters();
            },
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadBooks(forceBackend: true),
            child: _books.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 48,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Text(t.bookListEmpty),
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              headingTextStyle:
                                  Theme.of(context).textTheme.labelLarge,
                              columnSpacing: 24,
                              dataRowMinHeight: 72,
                              dataRowMaxHeight: 140,
                              columns: _buildColumns(t),
                              rows: _buildRows(context, t),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _BookFilters extends StatelessWidget {
  const _BookFilters({
    required this.searchController,
    required this.selectedStatus,
    required this.loading,
    required this.onClearSearch,
    required this.onSubmitted,
    required this.onStatusChanged,
  });

  final TextEditingController searchController;
  final String selectedStatus;
  final bool loading;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String?> onStatusChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Column(
      children: [
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          enabled: !loading,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: t.bookSearchLabel,
            hintText: t.bookSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: t.clear,
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(selectedStatus),
          initialValue: selectedStatus,
          decoration: InputDecoration(labelText: t.bookStatusFilter),
          items: [
            DropdownMenuItem(
              value: _BookAdminViewState._allStatusesValue,
              child: Text(t.bookStatusAll),
            ),
            DropdownMenuItem(
              value: 'draft',
              child: Text(t.bookStatusDraft),
            ),
            DropdownMenuItem(
              value: 'published',
              child: Text(t.bookStatusPublished),
            ),
            DropdownMenuItem(
              value: 'archived',
              child: Text(t.bookStatusArchived),
            ),
          ],
          onChanged: loading ? null : onStatusChanged,
        ),
      ],
    );
  }
}

String _bookStatusLabel(String status, AppLocalizations t) {
  switch (status.toLowerCase()) {
    case 'draft':
      return t.bookStatusDraft;
    case 'published':
      return t.bookStatusPublished;
    case 'archived':
      return t.bookStatusArchived;
    default:
      return status;
  }
}

class _BookEditorDialog extends StatefulWidget {
  const _BookEditorDialog({this.book});

  final Book? book;

  @override
  State<_BookEditorDialog> createState() => _BookEditorDialogState();
}

class _BookEditorDialogState extends State<_BookEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _titleController;
  late final TextEditingController _slugController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _creditPriceController;
  late final TextEditingController _availableCopiesController;
  late final TextEditingController _isbnController;
  late final TextEditingController _languageController;
  late final TextEditingController _coverUrlController;
  late final TextEditingController _fileUrlController;
  late final TextEditingController _publishedAtController;

  List<Category> _categories = [];
  List<Author> _authors = [];
  int? _selectedCategoryId;
  Set<int> _selectedAuthorIds = {};
  String _status = 'draft';
  DateTime? _publishedAt;

  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final book = widget.book;
    _titleController = TextEditingController(text: book?.title ?? '');
    _slugController = TextEditingController(text: book?.slug ?? '');
    _subtitleController = TextEditingController(text: book?.subtitle ?? '');
    _descriptionController =
        TextEditingController(text: book?.description ?? '');
    _creditPriceController = TextEditingController(
      text: book != null ? book.creditPrice.toString() : '0',
    );
    _availableCopiesController = TextEditingController(
      text: book != null ? book.availableCopies.toString() : '0',
    );
    _isbnController = TextEditingController(text: book?.isbn ?? '');
    _languageController = TextEditingController(text: book?.language ?? '');
    _coverUrlController =
        TextEditingController(text: book?.coverImageUrl ?? '');
    _fileUrlController = TextEditingController(text: book?.fileUrl ?? '');
    _publishedAt = book?.publishedAt;
    _publishedAtController = TextEditingController(
      text: book?.publishedAt != null
          ? DateFormat('yyyy-MM-dd').format(book!.publishedAt!.toLocal())
          : '',
    );
    _selectedCategoryId = book?.category?.id;
    _selectedAuthorIds = {
      if (book != null) ...book.authors.map((a) => a.id),
    };
    _status = book?.status ?? 'draft';
    _loadMetadata();
  }

  Future<void> _loadMetadata() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final categories = await CatalogService.instance.fetchCategories(
        auth: true,
      );
      final authors = await CatalogService.instance.fetchAuthors(auth: true);
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _authors = authors;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _slugController.dispose();
    _subtitleController.dispose();
    _descriptionController.dispose();
    _creditPriceController.dispose();
    _availableCopiesController.dispose();
    _isbnController.dispose();
    _languageController.dispose();
    _coverUrlController.dispose();
    _fileUrlController.dispose();
    _publishedAtController.dispose();
    super.dispose();
  }

  void _toggleAuthor(int id, bool selected) {
    setState(() {
      if (selected) {
        _selectedAuthorIds.add(id);
      } else {
        _selectedAuthorIds.remove(id);
      }
    });
  }

  Future<void> _pickPublishedDate() async {
    final now = DateTime.now();
    final initialDate = _publishedAt ?? DateTime(now.year, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    setState(() {
      _publishedAt = picked;
      _publishedAtController.text =
          DateFormat('yyyy-MM-dd').format(picked.toLocal());
    });
  }

  void _clearPublishedDate() {
    setState(() {
      _publishedAt = null;
      _publishedAtController.clear();
    });
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _submitting = true);

    final t = context.l10n;

    try {
      final title = _titleController.text.trim();
      final slug = _slugController.text.trim();
      final subtitle = _subtitleController.text.trim();
      final description = _descriptionController.text.trim();
      final creditPrice = int.parse(_creditPriceController.text.trim());
      final availableCopies =
          int.parse(_availableCopiesController.text.trim());
      final isbn = _isbnController.text.trim();
      final language = _languageController.text.trim();
      final coverUrl = _coverUrlController.text.trim();
      final fileUrl = _fileUrlController.text.trim();

      final payload = <String, dynamic>{
        'title': title,
        'credit_price': creditPrice,
        'available_copies': availableCopies,
        'status': _status,
        'authors': _selectedAuthorIds.toList(),
      };

      if (slug.isNotEmpty) payload['slug'] = slug;
      if (subtitle.isNotEmpty) payload['subtitle'] = subtitle;
      if (description.isNotEmpty) payload['description'] = description;
      if (_selectedCategoryId != null) {
        payload['category_id'] = _selectedCategoryId;
      }
      if (isbn.isNotEmpty) payload['isbn'] = isbn;
      if (language.isNotEmpty) payload['language'] = language;
      if (coverUrl.isNotEmpty) payload['cover_image_url'] = coverUrl;
      if (fileUrl.isNotEmpty) payload['file_url'] = fileUrl;
      if (_publishedAt != null) {
        payload['published_at'] =
            DateFormat('yyyy-MM-dd').format(_publishedAt!.toLocal());
      } else if (widget.book?.publishedAt != null &&
          _publishedAtController.text.trim().isEmpty) {
        payload['published_at'] = null;
      }

      Navigator.of(context).pop(payload);
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.bookFormUnexpectedError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return AlertDialog(
      title: Text(
        widget.book == null
            ? t.bookFormCreateTitle
            : t.bookFormEditTitle(widget.book!.title),
      ),
      content: SizedBox(
        width: 480,
        child: _loading
            ? const SizedBox(
                height: 220,
                child: Center(child: CircularProgressIndicator()),
              )
            : _error != null
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(t.errorPrefix(_error!)),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _loadMetadata,
                        child: Text(t.tryAgain),
                      ),
                    ],
                  )
                : SingleChildScrollView(
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextFormField(
                            controller: _titleController,
                            decoration: InputDecoration(
                              labelText: t.bookTitleLabel,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return t.bookTitleRequired;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _slugController,
                            decoration: InputDecoration(
                              labelText: t.bookSlugLabel,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _subtitleController,
                            decoration: InputDecoration(
                              labelText: t.bookSubtitleLabel,
                            ),
                            textCapitalization: TextCapitalization.sentences,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _descriptionController,
                            decoration: InputDecoration(
                              labelText: t.bookDescriptionLabel,
                            ),
                            maxLines: 4,
                            minLines: 3,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _creditPriceController,
                            decoration: InputDecoration(
                              labelText: t.bookCreditPriceLabel,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return t.bookCreditPriceRequired;
                              }
                              final number = int.tryParse(text);
                              if (number == null || number < 0) {
                                return t.bookCreditPriceInvalid;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _availableCopiesController,
                            decoration: InputDecoration(
                              labelText: t.bookAvailableCopiesLabel,
                            ),
                            keyboardType: TextInputType.number,
                            validator: (value) {
                              final text = value?.trim() ?? '';
                              if (text.isEmpty) {
                                return t.bookAvailableCopiesRequired;
                              }
                              final number = int.tryParse(text);
                              if (number == null || number < 0) {
                                return t.bookAvailableCopiesInvalid;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            initialValue: _status,
                            decoration: InputDecoration(
                              labelText: t.bookStatusLabel,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: 'draft',
                                child: Text(t.bookStatusDraft),
                              ),
                              DropdownMenuItem(
                                value: 'published',
                                child: Text(t.bookStatusPublished),
                              ),
                              DropdownMenuItem(
                                value: 'archived',
                                child: Text(t.bookStatusArchived),
                              ),
                            ],
                            onChanged: (value) {
                              if (value == null) return;
                              setState(() => _status = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<int?>(
                            initialValue: _selectedCategoryId,
                            decoration: InputDecoration(
                              labelText: t.bookCategory,
                            ),
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(t.bookCategoryNone),
                              ),
                              ..._categories.map(
                                (category) => DropdownMenuItem(
                                  value: category.id,
                                  child: Text(category.name),
                                ),
                              ),
                            ],
                            onChanged: (value) {
                              setState(() => _selectedCategoryId = value);
                            },
                          ),
                          const SizedBox(height: 12),
                          FormField<Set<int>>(
                            initialValue: _selectedAuthorIds,
                            builder: (state) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    t.bookAuthors,
                                    style:
                                        Theme.of(context).textTheme.bodyMedium,
                                  ),
                                  const SizedBox(height: 8),
                                  if (_authors.isEmpty)
                                    Text(
                                      t.bookAuthorsEmpty,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    )
                                  else
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 8,
                                      children: _authors.map((author) {
                                        final selected = _selectedAuthorIds
                                            .contains(author.id);
                                        return FilterChip(
                                          label: Text(author.name),
                                          selected: selected,
                                          onSelected: (value) =>
                                              _toggleAuthor(author.id, value),
                                        );
                                      }).toList(),
                                    ),
                                ],
                              );
                            },
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _isbnController,
                            decoration: InputDecoration(
                              labelText: t.bookIsbnLabel,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _languageController,
                            decoration: InputDecoration(
                              labelText: t.bookLanguageLabel,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _coverUrlController,
                            decoration: InputDecoration(
                              labelText: t.bookCoverUrlLabel,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _fileUrlController,
                            decoration: InputDecoration(
                              labelText: t.bookFileUrlLabel,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _publishedAtController,
                            readOnly: true,
                            decoration: InputDecoration(
                              labelText: t.bookPublishedAtLabel,
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_publishedAt != null)
                                    IconButton(
                                      tooltip: t.clear,
                                      onPressed: _clearPublishedDate,
                                      icon: const Icon(Icons.clear),
                                    ),
                                  IconButton(
                                    tooltip: t.selectDate,
                                    onPressed: _pickPublishedDate,
                                    icon: const Icon(
                                      Icons.calendar_today_outlined,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            onTap: _pickPublishedDate,
                          ),
                        ],
                      ),
                    ),
                  ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(
            widget.book == null
                ? t.bookFormCreateAction
                : t.bookFormUpdateAction,
          ),
        ),
      ],
    );
  }
}

class _UserFilters extends StatelessWidget {
  const _UserFilters({
    required this.searchController,
    required this.selectedRole,
    required this.loading,
    required this.onClearSearch,
    required this.onSubmitted,
    required this.onRoleChanged,
  });

  final TextEditingController searchController;
  final String selectedRole;
  final bool loading;
  final VoidCallback onClearSearch;
  final ValueChanged<String> onSubmitted;
  final ValueChanged<String> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return Column(
      children: [
        TextField(
          controller: searchController,
          textInputAction: TextInputAction.search,
          enabled: !loading,
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            labelText: t.userSearchLabel,
            hintText: t.userSearchHint,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: searchController.text.isEmpty
                ? null
                : IconButton(
                    tooltip: t.clear,
                    onPressed: onClearSearch,
                    icon: const Icon(Icons.clear),
                  ),
          ),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          key: ValueKey(selectedRole),
          initialValue: selectedRole,
          decoration: InputDecoration(labelText: t.userRoleFilter),
          items: [
            DropdownMenuItem(
              value: _UserAdminViewState._allRolesValue,
              child: Text(t.userRoleAll),
            ),
            DropdownMenuItem(
              value: 'admin',
              child: Text(t.userRoleAdmin),
            ),
            DropdownMenuItem(
              value: 'user',
              child: Text(t.userRoleUser),
            ),
          ],
          onChanged: loading
              ? null
              : (value) {
                  if (value == null) return;
                  onRoleChanged(value);
                },
        ),
      ],
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

String _roleLabel(String role, AppLocalizations t) {
  switch (role.toLowerCase()) {
    case 'admin':
      return t.userRoleAdmin;
    case 'user':
      return t.userRoleUser;
    default:
      return role;
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) return '-';
  final dt = value.toLocal();
  String two(int v) => v.toString().padLeft(2, '0');
  return '${dt.year}-${two(dt.month)}-${two(dt.day)} ${two(dt.hour)}:${two(dt.minute)}';
}

// ==================== AUTHOR ADMIN ====================

class AuthorAdminView extends StatefulWidget {
  const AuthorAdminView({super.key});

  @override
  State<AuthorAdminView> createState() => _AuthorAdminViewState();
}

class _AuthorAdminViewState extends State<AuthorAdminView> {
  final CatalogService _catalogService = CatalogService.instance;
  final TextEditingController _searchController = TextEditingController();

  final List<Author> _allAuthors = [];
  final List<Author> _authors = [];
  final Set<int> _deleting = {};

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    _loadAuthors();
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  bool get isLoading => _loading;

  Future<void> refreshAuthors() => _loadAuthors(forceBackend: true);

  void createAuthor() => _openEditor();

  void _onSearchChanged() {
    if (_loading && _allAuthors.isEmpty) return;
    _applyFilters();
  }

  Future<void> _loadAuthors({bool forceBackend = false}) async {
    setState(() {
      _loading = true;
      if (forceBackend) {
        _error = null;
      }
    });

    try {
      final authors = await _catalogService.fetchAuthors(
        auth: true,
        forceRefresh: forceBackend,
      );
      if (!mounted) return;
      setState(() {
        _allAuthors
          ..clear()
          ..addAll(authors);
      });
      _applyFilters();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
        _allAuthors.clear();
        _authors.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
        _allAuthors.clear();
        _authors.clear();
      });
    }
  }

  void _applyFilters() {
    final search = _searchController.text.trim().toLowerCase();

    final filtered = _allAuthors
        .where((author) {
          if (search.isEmpty) return true;

          bool contains(String? value) =>
              value != null && value.toLowerCase().contains(search);

          return contains(author.name) || contains(author.slug);
        })
        .toList(growable: false)
      ..sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

    setState(() {
      _authors
        ..clear()
        ..addAll(filtered);
      _loading = false;
    });
  }

  void _clearSearch() {
    if (_searchController.text.isEmpty) return;
    _searchController.clear();
  }

  Future<void> _openEditor([Author? author]) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _AuthorEditorDialog(author: author),
    );
    if (result == null) return;

    try {
      if (author == null) {
        final created = await _catalogService.createAuthor(result);
        if (!mounted) return;
        setState(() {
          _allAuthors.add(created);
        });
        _applyFilters();
        _showSnack(context.l10n.authorCreateSuccess);
      } else {
        final updated = await _catalogService.updateAuthor(author.id, result);
        if (!mounted) return;
        setState(() {
          final index = _allAuthors.indexWhere((a) => a.id == author.id);
          if (index >= 0) {
            _allAuthors[index] = updated;
          }
        });
        _applyFilters();
        _showSnack(context.l10n.authorUpdateSuccess);
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString());
    }
  }

  Future<void> _deleteAuthor(Author author) async {
    final t = context.l10n;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(t.authorDeleteTitle),
        content: Text(t.authorDeleteMessage(author.name)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(t.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(t.authorDeleteAction),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _deleting.add(author.id));

    try {
      await _catalogService.deleteAuthor(author.id);
      if (!mounted) return;
      setState(() {
        _allAuthors.removeWhere((a) => a.id == author.id);
      });
      _applyFilters();
      _showSnack(t.authorDeleteSuccess);
    } on ApiException catch (e) {
      if (!mounted) return;
      _showSnack(e.message);
    } catch (e) {
      if (!mounted) return;
      _showSnack(e.toString());
    } finally {
      if (mounted) {
        setState(() => _deleting.remove(author.id));
      }
    }
  }

  void _showSnack(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  List<DataColumn> _buildColumns(AppLocalizations t) => [
        DataColumn(label: Text(t.authorColumnIndex), numeric: true),
        DataColumn(label: Text(t.authorColumnName)),
        DataColumn(label: Text(t.authorColumnSlug)),
        DataColumn(label: Text(t.authorColumnBooksCount), numeric: true),
        DataColumn(label: Text(t.authorColumnActions)),
      ];

  List<DataRow> _buildRows(BuildContext context, AppLocalizations t) {
    return List<DataRow>.generate(_authors.length, (index) {
      final author = _authors[index];
      final isDeleting = _deleting.contains(author.id);
      return DataRow(
        cells: [
          DataCell(Text('${index + 1}')),
          DataCell(
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 260),
              child: Text(
                author.name,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ),
          DataCell(
            Text(
              author.slug,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).hintColor),
            ),
          ),
          DataCell(Text('${author.booksCount}')),
          DataCell(
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: t.authorEdit,
                  onPressed: () => _openEditor(author),
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip:
                      isDeleting ? t.authorDeleteInProgress : t.authorDelete,
                  onPressed: isDeleting ? null : () => _deleteAuthor(author),
                  icon: isDeleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline),
                ),
              ],
            ),
          ),
        ],
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return _ErrorView(
        message: _error!,
        onRetry: () => _loadAuthors(forceBackend: true),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            enabled: !_loading,
            onSubmitted: (_) => _applyFilters(),
            decoration: InputDecoration(
              labelText: t.authorSearchLabel,
              hintText: t.authorSearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: t.clear,
                      onPressed: _clearSearch,
                      icon: const Icon(Icons.clear),
                    ),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () => _loadAuthors(forceBackend: true),
            child: _authors.isEmpty
                ? ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 48,
                          horizontal: 16,
                        ),
                        child: Center(
                          child: Text(t.authorListEmpty),
                        ),
                      ),
                    ],
                  )
                : LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: SizedBox(
                            width: constraints.maxWidth,
                            child: DataTable(
                              headingRowColor: WidgetStateProperty.all(
                                Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest,
                              ),
                              headingTextStyle:
                                  Theme.of(context).textTheme.labelLarge,
                              columnSpacing: 24,
                              dataRowMinHeight: 68,
                              dataRowMaxHeight: 120,
                              columns: _buildColumns(t),
                              rows: _buildRows(context, t),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ),
      ],
    );
  }
}

class _AuthorEditorDialog extends StatefulWidget {
  const _AuthorEditorDialog({this.author});

  final Author? author;

  @override
  State<_AuthorEditorDialog> createState() => _AuthorEditorDialogState();
}

class _AuthorEditorDialogState extends State<_AuthorEditorDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _slugController;
  late final TextEditingController _bioController;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final author = widget.author;
    _nameController = TextEditingController(text: author?.name ?? '');
    _slugController = TextEditingController(text: author?.slug ?? '');
    _bioController = TextEditingController(text: author?.bio ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _slugController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_submitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() => _submitting = true);

    final t = context.l10n;

    try {
      final name = _nameController.text.trim();
      final slug = _slugController.text.trim();
      final bio = _bioController.text.trim();

      final payload = <String, dynamic>{
        'name': name,
      };

      if (slug.isNotEmpty) payload['slug'] = slug;
      if (bio.isNotEmpty) payload['bio'] = bio;

      Navigator.of(context).pop(payload);
    } catch (e) {
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.bookFormUnexpectedError)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.l10n;

    return AlertDialog(
      title: Text(
        widget.author == null
            ? t.authorFormCreateTitle
            : t.authorFormEditTitle(widget.author!.name),
      ),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: t.authorNameLabel,
                ),
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  final text = value?.trim() ?? '';
                  if (text.isEmpty) {
                    return t.authorNameRequired;
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _slugController,
                decoration: InputDecoration(
                  labelText: t.authorSlugLabel,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                decoration: InputDecoration(
                  labelText: t.authorBioLabel,
                ),
                maxLines: 4,
                minLines: 3,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: Text(t.cancel),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: Text(
            widget.author == null
                ? t.authorFormCreateAction
                : t.authorFormUpdateAction,
          ),
        ),
      ],
    );
  }
}
