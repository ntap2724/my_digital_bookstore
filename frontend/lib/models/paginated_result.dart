class PaginatedResult<T> {
  final List<T> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  const PaginatedResult({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  static PaginatedResult<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) factory,
  ) {
    final dataJson = json['data'];
    final meta = json['meta'];

    final items = dataJson is List
        ? dataJson
              .whereType<Map<String, dynamic>>()
              .map(factory)
              .toList(growable: false)
        : List<T>.unmodifiable(const []);

    int page = 1;
    int lastPage = 1;
    int perPage = items.length;
    int total = items.length;
    if (meta is Map<String, dynamic>) {
      page = (meta['current_page'] as num?)?.toInt() ?? page;
      lastPage = (meta['last_page'] as num?)?.toInt() ?? lastPage;
      perPage = (meta['per_page'] as num?)?.toInt() ?? perPage;
      total = (meta['total'] as num?)?.toInt() ?? total;
    }

    return PaginatedResult(
      data: items,
      currentPage: page,
      lastPage: lastPage,
      perPage: perPage,
      total: total,
    );
  }
}
