import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../errors/app_failure.dart';
import '../network/paginated.dart';
import 'list_query.dart';

class PagedState<T> {
  const PagedState({
    this.items = const [],
    this.page = 1,
    this.total = 0,
    this.hasMore = false,
    this.loadingMore = false,
    this.loadMoreError,
  });

  final List<T> items;
  final int page;
  final int total;
  final bool hasMore;
  final bool loadingMore;
  final AppFailure? loadMoreError;

  PagedState<T> copyWith({
    List<T>? items,
    int? page,
    int? total,
    bool? hasMore,
    bool? loadingMore,
    AppFailure? loadMoreError,
    bool clearError = false,
  }) {
    return PagedState(
      items: items ?? this.items,
      page: page ?? this.page,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      loadingMore: loadingMore ?? this.loadingMore,
      loadMoreError: clearError ? null : (loadMoreError ?? this.loadMoreError),
    );
  }
}

typedef PageFetcher<T> = Future<Page<T>> Function(Ref ref, ListQuery query, int page);

/// One paginated list that refetches whenever its [ListQuery] changes.
class PagedNotifier<T> extends AsyncNotifier<PagedState<T>> {
  PagedNotifier({required this.queryProvider, required this.fetch});

  final ListQueryProvider queryProvider;
  final PageFetcher<T> fetch;
  late ListQuery _query;

  @override
  Future<PagedState<T>> build() async {
    _query = ref.watch(queryProvider);
    final first = await fetch(ref, _query, 1);
    return PagedState(items: first.items, total: first.total, hasMore: first.hasMore);
  }

  Future<void> loadMore() async {
    final s = state.value;
    if (s == null || !s.hasMore || s.loadingMore || state.isLoading) return;
    state = AsyncData(s.copyWith(loadingMore: true, clearError: true));
    final query = _query;
    try {
      final next = await fetch(ref, query, s.page + 1);
      if (!ref.mounted || query != _query) return;
      state = AsyncData(s.copyWith(
        items: [...s.items, ...next.items],
        page: s.page + 1,
        total: next.total,
        hasMore: next.hasMore,
        loadingMore: false,
      ));
    } on AppFailure catch (f) {
      if (!ref.mounted) return;
      state = AsyncData(s.copyWith(loadingMore: false, loadMoreError: f));
    }
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

typedef PagedProvider<T> = AsyncNotifierProvider<PagedNotifier<T>, PagedState<T>>;

PagedProvider<T> pagedProvider<T>(ListQueryProvider query, PageFetcher<T> fetch) =>
    AsyncNotifierProvider<PagedNotifier<T>, PagedState<T>>(
      () => PagedNotifier<T>(queryProvider: query, fetch: fetch),
    );
