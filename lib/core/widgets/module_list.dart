import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import '../list/list_query.dart';
import '../list/paged_notifier.dart';
import '../utils/formatters.dart';
import 'app_card.dart';
import 'fields.dart';
import 'scaffolds.dart';
import 'search_field.dart';
import 'states.dart';
import '../design/app_icons.dart';
import 'controls.dart';

/// A status segment bar bound to one query parameter. The first option
/// should have an empty value ("All").
class SegmentConfig {
  const SegmentConfig({required this.param, required this.options});
  final String param;
  final Map<String, String> options;
}

/// A filter the user can set from the filter sheet.
sealed class FilterConfig {
  const FilterConfig(this.param, this.label);
  final String param;
  final String label;
}

class DateFilter extends FilterConfig {
  const DateFilter(super.param, super.label);
}

class ChoiceFilter extends FilterConfig {
  const ChoiceFilter(super.param, super.label, this.options);
  final Map<String, String> options;
}

/// A value picked from a sheet the screen provides (e.g. a mark from the
/// garden list). [pick] returns the value to filter by.
class PickerFilter extends FilterConfig {
  const PickerFilter(super.param, super.label, this.pick);
  final Future<String?> Function(BuildContext context) pick;
}

/// Groups list rows: a heading per [section], then rows sorted by
/// [subgroup] (shown as a small header) and [order].
class ListGrouping<T> {
  const ListGrouping({required this.section, this.subgroup, this.order});
  final String Function(T item) section;
  final String? Function(T item)? subgroup;
  final String? Function(T item)? order;
}

/// The list screen every module shares: large title, search, status
/// segments, filter chips, pagination, and every loading/empty/error state.
class ModuleListScreen<T> extends ConsumerStatefulWidget {
  const ModuleListScreen({
    super.key,
    required this.title,
    required this.listProvider,
    required this.queryProvider,
    required this.itemBuilder,
    required this.searchHint,
    required this.emptyTitle,
    required this.emptyBody,
    required this.emptyIcon,
    this.newLabel,
    this.onNew,
    this.segments,
    this.filters = const [],
    this.actions = const [],
    this.header = const [],
    this.inTabs = true,
    this.asCards = false,
    this.grouping,
    this.sortable = false,
  });

  final String title;
  final PagedProvider<T> listProvider;
  final ListQueryProvider queryProvider;
  final Widget Function(BuildContext, T) itemBuilder;
  final String searchHint;
  final String emptyTitle;
  final String emptyBody;
  final AppIcons emptyIcon;
  final String? newLabel;
  final VoidCallback? onNew;
  final SegmentConfig? segments;
  final List<FilterConfig> filters;
  final List<Widget> actions;
  final List<Widget> header;
  final bool inTabs;

  /// Each item is its own card instead of rows in one grouped card.
  final bool asCards;

  final ListGrouping<T>? grouping;

  /// Shows a Latest first / Earliest first switch.
  final bool sortable;

  @override
  ConsumerState<ModuleListScreen<T>> createState() => _ModuleListScreenState<T>();
}

class _ModuleListScreenState<T> extends ConsumerState<ModuleListScreen<T>> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.extentAfter < 300) ref.read(widget.listProvider.notifier).loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final query = ref.watch(widget.queryProvider);
    final queryCtl = ref.read(widget.queryProvider.notifier);
    final list = ref.watch(widget.listProvider);
    final seg = widget.segments;

    final header = <Widget>[
      ...widget.header,
      SearchField(hint: widget.searchHint, initial: query.search, onChanged: queryCtl.setSearch),
      const SizedBox(height: AppSpace.md),
      if (seg != null) ...[
        // Up to 4 options fill the width; more scroll sideways at their
        // natural width (a stretched bar can't sit in a scroll view).
        if (seg.options.length > 4)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Segmented<String>(
              compact: true,
              options: seg.options,
              selected: query.params[seg.param] ?? '',
              onChanged: (v) => queryCtl.setParam(seg.param, v),
            ),
          )
        else
          Segmented<String>(
            options: seg.options,
            selected: query.params[seg.param] ?? '',
            onChanged: (v) => queryCtl.setParam(seg.param, v),
          ),
        const SizedBox(height: AppSpace.md),
      ],
      if (widget.filters.isNotEmpty || list.hasValue) _filterBar(context, c, query, queryCtl, list.value),
      const SizedBox(height: AppSpace.md),
    ];

    final List<Widget> body = list.when(
      skipLoadingOnRefresh: true,
      loading: () => [const SliverToBoxAdapter(child: SkeletonList())],
      error: (e, _) => [
        SliverToBoxAdapter(child: ErrorState(error: e, onRetry: () => ref.invalidate(widget.listProvider))),
      ],
      data: (s) {
        if (s.items.isEmpty) {
          final filtered = query.hasFilters || query.search.isNotEmpty;
          return [
            SliverToBoxAdapter(
              child: filtered
                  ? EmptyState(
                      icon: AppIcons.search,
                      title: 'Nothing matches',
                      body: 'Try a different search or clear the filters.',
                      actionLabel: 'Clear filters',
                      onAction: () => queryCtl.replace(const ListQuery()),
                    )
                  : EmptyState(
                      icon: widget.emptyIcon,
                      title: widget.emptyTitle,
                      body: widget.emptyBody,
                      actionLabel: widget.newLabel,
                      onAction: widget.onNew,
                    ),
            ),
          ];
        }
        // Earliest first: the API can't sort yet, so load every page and
        // reverse it here.
        if (query.oldestFirst && s.hasMore) {
          if (!s.loadingMore && s.loadMoreError == null) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) ref.read(widget.listProvider.notifier).loadMore();
            });
          }
          if (s.loadMoreError == null) return [const SliverToBoxAdapter(child: SkeletonList())];
        }
        final shown = query.oldestFirst ? s.items.reversed.toList() : s.items;
        if (widget.grouping != null && !widget.asCards) {
          return [..._grouped(c, shown), SliverToBoxAdapter(child: _footer(c, s))];
        }
        final items = widget.asCards
            ? SliverList.separated(
                itemCount: shown.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                itemBuilder: (ctx, i) => widget.itemBuilder(ctx, shown[i]),
              )
            : SliverToBoxAdapter(
                child: AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < shown.length; i++) ...[
                        if (i > 0) const Divider(height: 0.5),
                        widget.itemBuilder(context, shown[i]),
                      ],
                    ],
                  ),
                ),
              );
        return [
          items,
          SliverToBoxAdapter(child: _footer(c, s)),
        ];
      },
    );

    return PageScaffold(
      title: widget.title,
      controller: _scroll,
      inTabs: widget.inTabs,
      onRefresh: () => ref.read(widget.listProvider.notifier).refresh(),
      actions: widget.actions,
      header: header,
      slivers: body,
    );
  }

  static int _compare(String? a, String? b) {
    final x = a ?? '', y = b ?? '';
    final nx = int.tryParse(x), ny = int.tryParse(y);
    if (nx != null && ny != null) return nx.compareTo(ny);
    return x.toLowerCase().compareTo(y.toLowerCase());
  }

  List<Widget> _grouped(AppColors c, List<T> items) {
    final g = widget.grouping!;
    final sections = <String, List<T>>{};
    for (final it in items) {
      sections.putIfAbsent(g.section(it), () => []).add(it);
    }
    final out = <Widget>[];
    for (final e in sections.entries) {
      final rows = [...e.value]..sort((a, b) {
          final bySub = g.subgroup == null ? 0 : _compare(g.subgroup!(a), g.subgroup!(b));
          return bySub != 0 ? bySub : (g.order == null ? 0 : _compare(g.order!(a), g.order!(b)));
        });
      final children = <Widget>[];
      String? lastSub;
      for (var i = 0; i < rows.length; i++) {
        final sub = g.subgroup?.call(rows[i]);
        if (g.subgroup != null && (i == 0 || sub != lastSub)) {
          final count = rows.where((r) => g.subgroup!(r) == sub).length;
          if (i > 0) children.add(const Divider(height: 0.5));
          children.add(Container(
            color: c.background,
            padding: const EdgeInsets.fromLTRB(AppSpace.lg - 2, 6, AppSpace.lg - 2, 6),
            child: Text('${sub ?? 'No mark'} · $count',
                style: AppText.caption.copyWith(color: c.textSecondary, fontWeight: FontWeight.w600)),
          ));
        } else if (i > 0) {
          children.add(const Divider(height: 0.5));
        }
        lastSub = sub;
        children.add(widget.itemBuilder(context, rows[i]));
      }
      out.add(SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.only(bottom: AppSpace.lg),
          child: GroupedSection(
            label: '${e.key} · ${rows.length}',
            children: [Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)],
          ),
        ),
      ));
    }
    return out;
  }

  Widget _filterBar(BuildContext context, AppColors c, ListQuery q, ListQueryNotifier ctl, PagedState<T>? s) {
    final chips = <Widget>[];
    for (final f in widget.filters) {
      final v = q.params[f.param];
      if (v == null) continue;
      final shown = switch (f) {
        DateFilter() => Fmt.day(DateTime.tryParse(v)),
        ChoiceFilter(:final options) => options[v] ?? v,
        PickerFilter() => v,
      };
      chips.add(_Chip(label: '${f.label}: $shown', onRemove: () => ctl.setParam(f.param, null)));
    }
    return Row(
      children: [
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (final ch in chips) Padding(padding: const EdgeInsets.only(right: 8), child: ch),
              if (widget.sortable)
                GestureDetector(
                  onTap: () => ctl.setParam(kOrderParam, q.oldestFirst ? null : 'asc'),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(children: [
                      AppIcon(AppIcons.chevronDown, size: 16, color: c.accent),
                      const SizedBox(width: 4),
                      Text(q.oldestFirst ? 'Earliest first' : 'Latest first', style: AppText.footnote.copyWith(color: c.accent)),
                      const SizedBox(width: 10),
                    ]),
                  ),
                ),
              if (widget.filters.isNotEmpty)
                GestureDetector(
                  onTap: () => _openFilters(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(children: [
                      AppIcon(AppIcons.filter, size: 16, color: c.accent),
                      const SizedBox(width: 4),
                      Text('Filters', style: AppText.footnote.copyWith(color: c.accent)),
                    ]),
                  ),
                ),
            ]),
          ),
        ),
        if (s != null)
          Text('${Fmt.number(s.total)} ${s.total == 1 ? 'item' : 'items'}',
              style: AppText.footnote.copyWith(color: c.textTertiary)),
      ],
    );
  }

  Future<void> _openFilters(BuildContext context) async {
    final q = ref.read(widget.queryProvider);
    final ctl = ref.read(widget.queryProvider.notifier);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => _FilterSheet(filters: widget.filters, initial: q, onApply: ctl.replace),
    );
  }

  Widget _footer(AppColors c, PagedState<T> s) {
    if (s.loadingMore) {
      return const Padding(padding: EdgeInsets.all(AppSpace.lg), child: Center(child: AppSpinner()));
    }
    if (s.loadMoreError != null) {
      return Padding(
        padding: const EdgeInsets.all(AppSpace.md),
        child: Center(
          child: GestureDetector(
            onTap: () => ref.read(widget.listProvider.notifier).loadMore(),
            child: Text("Couldn't load more. Tap to retry",
                style: AppText.footnote.copyWith(color: c.accent)),
          ),
        ),
      );
    }
    return const SizedBox(height: AppSpace.sm);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onRemove});
  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      height: 30,
      padding: const EdgeInsets.only(left: 10),
      decoration: ShapeDecoration(
        color: c.accentTint,
        shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(9))),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppText.footnote.copyWith(color: c.accent)),
          Semantics(
            button: true,
            label: 'Remove filter',
            child: GestureDetector(
              onTap: onRemove,
              child: SizedBox(width: 30, height: 30, child: AppIcon(AppIcons.close, size: 12, color: c.accent)),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.filters, required this.initial, required this.onApply});
  final List<FilterConfig> filters;
  final ListQuery initial;
  final ValueChanged<ListQuery> onApply;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late ListQuery _q = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(child: Text('Filters', style: AppText.title)),
                TextButton(
                  onPressed: () => setState(() => _q = ListQuery(
                        search: _q.search,
                        params: {if (_q.oldestFirst) kOrderParam: 'asc'},
                      )),
                  child: const Text('Reset'),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            GroupedSection(
              children: [
                for (final f in widget.filters)
                  switch (f) {
                    DateFilter() => DateRow(
                        label: f.label,
                        placeholder: 'Any',
                        value: DateTime.tryParse(_q.params[f.param] ?? ''),
                        onChanged: (d) => setState(() => _q = _q.withParam(f.param, Fmt.api(d))),
                      ),
                    ChoiceFilter(:final options) => ValueRow(
                        label: f.label,
                        placeholder: 'Any',
                        value: options[_q.params[f.param]],
                        onTap: () async {
                          final picked = await showModalBottomSheet<String>(
                            context: context,
                            builder: (ctx) => SafeArea(
                              child: ListView(
                                shrinkWrap: true,
                                children: [
                                  for (final e in {'': 'Any', ...options}.entries)
                                    ListTile(title: Text(e.value), onTap: () => Navigator.pop(ctx, e.key)),
                                ],
                              ),
                            ),
                          );
                          if (picked != null) setState(() => _q = _q.withParam(f.param, picked));
                        },
                      ),
                    PickerFilter(:final pick) => ValueRow(
                        label: f.label,
                        placeholder: 'Any',
                        value: _q.params[f.param],
                        onTap: () async {
                          final picked = await pick(context);
                          if (picked != null) setState(() => _q = _q.withParam(f.param, picked));
                        },
                      ),
                  },
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            SizedBox(
              height: 50,
              child: FilledButton(
                onPressed: () {
                  widget.onApply(_q);
                  Navigator.pop(context);
                },
                child: const Text('Show results'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
