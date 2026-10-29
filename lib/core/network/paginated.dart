import '../utils/json.dart';

/// One page of a Laravel paginated list. Handles both the plain paginator
/// (`data: {data: [...], current_page, last_page, total}`) and API resources
/// (`data: [...], meta: {...}`), wrapped or not in `{success, data}`.
class Page<T> {
  const Page({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  bool get hasMore => currentPage < lastPage;

  static Page<T> parse<T>(Object? body, T Function(Map<String, dynamic>) fromJson) {
    Object? node = body;
    Map<String, dynamic>? meta;

    if (node is Map<String, dynamic>) {
      if (node['meta'] is Map<String, dynamic>) meta = node['meta'] as Map<String, dynamic>;
      if (node.containsKey('data')) node = node['data'];
    }
    if (node is Map<String, dynamic>) {
      meta ??= node;
      if (node['meta'] is Map<String, dynamic>) meta = node['meta'] as Map<String, dynamic>;
      node = node['data'] ?? node['items'] ?? const [];
    }

    final list = node is List ? node : const [];
    final items = list.whereType<Map<String, dynamic>>().map(fromJson).toList();
    final current = J.intOr(meta?['current_page'], 1);
    final last = J.intOr(meta?['last_page'], current);
    final total = J.intOr(meta?['total'], items.length);
    return Page(items: items, currentPage: current, lastPage: last, total: total);
  }
}
