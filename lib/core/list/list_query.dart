import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Search text plus filter parameters for one list screen. Values are already
/// in the API's query format (dates as `yyyy-MM-dd`).
@immutable
class ListQuery {
  const ListQuery({this.search = '', this.params = const {}});

  final String search;
  final Map<String, String> params;

  bool get hasFilters => params.isNotEmpty;

  ListQuery withSearch(String value) => ListQuery(search: value, params: params);

  ListQuery withParam(String key, String? value) {
    final next = Map<String, String>.of(params);
    if (value == null || value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return ListQuery(search: search, params: next);
  }

  ListQuery cleared() => ListQuery(search: search);

  Map<String, Object?> toQuery() => {'search': search, ...params};

  @override
  bool operator ==(Object other) =>
      other is ListQuery && other.search == search && mapEquals(other.params, params);

  @override
  int get hashCode => Object.hash(search, Object.hashAllUnordered(params.entries.map((e) => '${e.key}=${e.value}')));
}

class ListQueryNotifier extends Notifier<ListQuery> {
  ListQueryNotifier([this.initial = const ListQuery()]);
  final ListQuery initial;

  @override
  ListQuery build() => initial;

  void setSearch(String value) {
    if (value != state.search) state = state.withSearch(value);
  }

  void setParam(String key, String? value) => state = state.withParam(key, value);

  void replace(ListQuery query) => state = query;

  void clearFilters() => state = state.cleared();
}

typedef ListQueryProvider = NotifierProvider<ListQueryNotifier, ListQuery>;
