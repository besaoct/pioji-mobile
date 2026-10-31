import '../utils/json.dart';

/// One page of a paginated list. The API uses two shapes:
///
/// - Most modules: `{data: {<items_key>: [...], pagination: {current_page, last_page, per_page, total}}}`
///   where `<items_key>` is `offer_lists`, `samples`, `lots`, `bills`, `gardens`, …
/// - A few (sellers): Laravel's paginator, `{data: {data: [...], current_page, last_page, total}}`.
///
/// A plain list in `data` is treated as a single page.
class Page<T> {
  const Page({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    required this.total,
    this.extra = const {},
  });

  final List<T> items;
  final int currentPage;
  final int lastPage;
  final int total;

  /// Other keys returned next to the items (e.g. ex-factory `metrics`).
  final Map<String, dynamic> extra;

  bool get hasMore => currentPage < lastPage;

  static Page<T> parse<T>(Object? body, T Function(Map<String, dynamic>) fromJson) {
    final data = unwrap(body);
    List<dynamic> list = const [];
    Map<String, dynamic>? meta;
    var extra = const <String, dynamic>{};

    if (data is List) {
      list = data;
    } else if (data is Map<String, dynamic>) {
      if (data['pagination'] is Map<String, dynamic>) {
        meta = data['pagination'] as Map<String, dynamic>;
      } else if (data['meta'] is Map<String, dynamic>) {
        meta = data['meta'] as Map<String, dynamic>;
      } else if (data.containsKey('current_page')) {
        meta = data;
      }
      final listKey = data['data'] is List
          ? 'data'
          : data.entries.firstWhere((e) => e.value is List, orElse: () => const MapEntry('', null)).key;
      if (listKey.isNotEmpty) list = data[listKey] as List;
      extra = {
        for (final e in data.entries)
          if (e.key != listKey && e.key != 'pagination' && e.key != 'meta') e.key: e.value,
      };
    }

    final items = list.whereType<Map<String, dynamic>>().map(fromJson).toList();
    final current = J.intOr(meta?['current_page'], 1);
    final last = J.intOr(meta?['last_page'], current);
    final total = J.intOr(meta?['total'], items.length);
    return Page(items: items, currentPage: current, lastPage: last, total: total, extra: extra);
  }
}
