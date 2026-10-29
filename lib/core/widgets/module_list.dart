import 'package:flutter/cupertino.dart';
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
  });

  final String title;
  final PagedProvider<T> listProvider;
  final ListQueryProvider queryProvider;
  final Widget Function(BuildContext, T) itemBuilder;
  final String searchHint;
  final String emptyTitle;
  final String emptyBody;
  final IconData emptyIcon;
  final String? newLabel;
  final VoidCallback? onNew;
  final SegmentConfig? segments;
  final List<FilterConfig> filters;
  final List<Widget> actions;
  final List<Widget> header;
  final bool inTabs;

  /// Each item is its own card instead of rows in one grouped card.
  final bool asCards;

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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Segmented<String>(
            compact: seg.options.length > 4,
            options: seg.options,
            selected: query.params[seg.param] ?? '',
            onChanged: (v) => queryCtl.setParam(seg.param, v),
          ),
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
                      icon: CupertinoIcons.search,
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
        final items = widget.asCards
            ? SliverList.separated(
                itemCount: s.items.length,
                separatorBuilder: (_, _) => const SizedBox(height: AppSpace.md),
                itemBuilder: (ctx, i) => widget.itemBuilder(ctx, s.items[i]),
              )
            : SliverToBoxAdapter(
                child: AppCard(
                  child: Column(
                    children: [
                      for (var i = 0; i < s.items.length; i++) ...[
                        if (i > 0) const Divider(indent: AppSpace.lg - 2, height: 0.5),
                        widget.itemBuilder(context, s.items[i]),
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

    return LargeTitleScaffold(
      title: widget.title,
      controller: _scroll,
      inTabs: widget.inTabs,
      onRefresh: () => ref.read(widget.listProvider.notifier).refresh(),
      actions: widget.actions,
      header: header,
      slivers: body,
    );
  }

  Widget _filterBar(BuildContext context, AppColors c, ListQuery q, ListQueryNotifier ctl, PagedState<T>? s) {
    final chips = <Widget>[];
    for (final f in widget.filters) {
      final v = q.params[f.param];
      if (v == null) continue;
      final shown = switch (f) {
        DateFilter() => Fmt.day(DateTime.tryParse(v)),
        ChoiceFilter(:final options) => options[v] ?? v,
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
              if (widget.filters.isNotEmpty)
                GestureDetector(
                  onTap: () => _openFilters(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(children: [
                      Icon(CupertinoIcons.slider_horizontal_3, size: 16, color: c.accent),
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
      return const Padding(padding: EdgeInsets.all(AppSpace.lg), child: Center(child: CupertinoActivityIndicator()));
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
              child: SizedBox(width: 30, height: 30, child: Icon(CupertinoIcons.xmark, size: 12, color: c.accent)),
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
                  onPressed: () => setState(() => _q = ListQuery(search: _q.search)),
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
