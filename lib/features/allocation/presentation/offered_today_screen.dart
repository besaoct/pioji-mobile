import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/one_line_text.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../offer_lists/data/offer_lists_repository.dart';
import '../data/allocation_repository.dart';
import '../../../core/design/app_icons.dart';

class OfferedTodayScreen extends ConsumerStatefulWidget {
  const OfferedTodayScreen({super.key});

  @override
  ConsumerState<OfferedTodayScreen> createState() => _OfferedTodayScreenState();
}

class _OfferedTodayScreenState extends ConsumerState<OfferedTodayScreen> {
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  ItemType _tab = ItemType.offerList;
  bool _selecting = false;
  final _selected = <String, OfferedItem>{};
  bool _busy = false;

  void _shift(int days) => setState(() {
        _date = _date.add(Duration(days: days));
        _selected.clear();
      });

  Future<void> _allocate(List<OfferedItem> items, OfferedToday data) async {
    if (items.isEmpty || _busy) return;
    if (data.buyers.isEmpty) {
      context.toast('No buyers are available for this date.');
      return;
    }
    final picked = await showMultiPickerSheet<int>(
      context,
      title: items.length == 1 ? 'Allocate buyers' : 'Allocate buyers to ${items.length} lots',
      options: [for (final b in data.buyers) PickOption(b.id, b.name, subtitle: b.subtitle)],
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(allocationRepositoryProvider).allocate(items, picked.toList());
      if (!mounted) return;
      ref.invalidate(offeredTodayProvider(_date));
      ref.invalidate(offerListsListProvider);
      refreshSummaries(ref);
      setState(() {
        _selected.clear();
        _selecting = false;
      });
      context.toast(items.length == 1 ? 'Buyers allocated' : 'Buyers allocated to ${items.length} lots');
    } on AppFailure catch (f) {
      if (mounted) context.toast(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final async = ref.watch(offeredTodayProvider(_date));
    final data = async.value;
    final items = data == null ? const <OfferedItem>[] : (_tab == ItemType.offerList ? data.offers : data.samples);

    final body = Stack(
      children: [
        PageScaffold(
          title: 'Offered today',
          inTabs: false,
          showBack: true,
          onRefresh: () => ref.refresh(offeredTodayProvider(_date).future),
          actions: [
            LinkButton(
              label: _selecting ? 'Done' : 'Select',
              onPressed: () => setState(() {
                _selecting = !_selecting;
                _selected.clear();
              }),
            ),
          ],
          header: [
            AppCard(
              child: Row(
                children: [
                  _ArrowButton(icon: AppIcons.chevronLeft, label: 'Previous day', onTap: () => _shift(-1)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        final d = await pickDate(context, initial: _date);
                        if (d != null) setState(() => _date = DateUtils.dateOnly(d));
                      },
                      child: Text(Fmt.longDay(_date), textAlign: TextAlign.center, style: AppText.callout),
                    ),
                  ),
                  _ArrowButton(icon: AppIcons.chevronRight, label: 'Next day', onTap: () => _shift(1)),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.md),
            Segmented<ItemType>(
              options: {
                ItemType.offerList: 'Offer lists${data == null ? '' : ' (${data.offers.length})'}',
                ItemType.sample: 'Samples${data == null ? '' : ' (${data.samples.length})'}',
              },
              selected: _tab,
              onChanged: (t) => setState(() => _tab = t),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          slivers: [
            async.when(
              skipLoadingOnRefresh: true,
              loading: () => const SliverToBoxAdapter(child: SkeletonList(rows: 4, rowHeight: 76)),
              error: (e, _) => SliverToBoxAdapter(child: ErrorState(error: e, onRetry: () => ref.invalidate(offeredTodayProvider(_date)))),
              data: (d) => items.isEmpty
                  ? const SliverToBoxAdapter(
                      child: EmptyState(
                        icon: AppIcons.calendar,
                        title: 'Nothing offered on this day',
                        body: 'Lots offered for this date show up here, ready for buyer allocation.',
                      ),
                    )
                  : SliverList.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: AppSpace.sm + 2),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        final on = _selected.containsKey(it.key);
                        return _OfferedCard(
                          item: it,
                          selecting: _selecting,
                          selected: on,
                          onTap: () {
                            if (_selecting) {
                              setState(() => on ? _selected.remove(it.key) : _selected[it.key] = it);
                            } else {
                              _allocate([it], d);
                            }
                          },
                          onLongPress: () => setState(() {
                            _selecting = true;
                            _selected[it.key] = it;
                          }),
                        );
                      },
                    ),
            ),
            if (_selecting) const SliverToBoxAdapter(child: SizedBox(height: 80)),
          ],
        ),
        if (_selecting && data != null)
          Positioned(
            left: AppSpace.screenH,
            right: AppSpace.screenH,
            bottom: MediaQuery.of(context).padding.bottom + AppSpace.md,
            child: PrimaryButton(
              label: _selected.isEmpty ? 'Select lots to allocate' : 'Allocate buyers (${_selected.length})',
              loading: _busy,
              onPressed: _selected.isEmpty ? null : () => _allocate(_selected.values.toList(), data),
            ),
          ),
      ],
    );
    return ColoredBox(color: c.background, child: body);
  }
}

class _ArrowButton extends StatelessWidget {
  const _ArrowButton({required this.icon, required this.label, required this.onTap});
  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(width: 48, height: 48, child: AppIcon(icon, size: 18, color: context.colors.accent)),
      ),
    );
  }
}

class _OfferedCard extends StatelessWidget {
  const _OfferedCard({required this.item, required this.selecting, required this.selected, required this.onTap, required this.onLongPress});

  final OfferedItem item;
  final bool selecting;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return GestureDetector(
      onLongPress: onLongPress,
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            if (selecting) ...[
              AppIcon(selected ? AppIcons.checkCircleFill : AppIcons.circle,
                  color: selected ? c.accent : c.textTertiary, size: 22),
              const SizedBox(width: AppSpace.md),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  OneLineText(item.title, style: AppText.body.copyWith(fontWeight: FontWeight.w500)),
                  if (item.invoice?.isNotEmpty == true)
                    OneLineText(item.invoice!, style: AppText.footnote.copyWith(color: c.textTertiary)),
                  const SizedBox(height: AppSpace.sm),
                  if (item.buyers.isEmpty)
                    Text('No buyers yet', style: AppText.footnote.copyWith(color: c.warning))
                  else
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final b in item.buyers)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: ShapeDecoration(color: c.fill, shape: AppRadius.controlBorder),
                            child: Text(b, style: AppText.caption.copyWith(color: c.textSecondary)),
                          ),
                      ],
                    ),
                ],
              ),
            ),
            if (!selecting) AppIcon(AppIcons.personAdd, color: c.accent, size: 20),
          ],
        ),
      ),
    );
  }
}
