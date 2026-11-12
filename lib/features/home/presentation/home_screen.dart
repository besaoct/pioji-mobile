import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/list/list_query.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_row.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/one_line_text.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../sales_register/data/sales_repository.dart';
import '../../samples/presentation/samples_list_screen.dart';
import '../application/home_providers.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/widgets/controls.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    String count(AsyncValue<int> v) => v.when(data: Fmt.number, loading: () => '–', error: (_, _) => '–');
    final dash = ref.watch(dashboardProvider);
    final d = dash.value;
    String dashCount(int? Function(DashboardSummary d) pick) => dash.hasValue ? Fmt.number(pick(dash.value!)) : '–';
    final unbatched = ref.watch(unbatchedTodayProvider);
    final awaiting = ref.watch(awaitingBidsCountProvider);
    final unallocated = ref.watch(unallocatedTodayProvider);
    final recent = ref.watch(recentSamplesProvider);
    final mismatches = d?.exMismatched ?? 0;
    final unregistered = d?.exUnregistered ?? 0;
    final pendingSales = d?.salesPending ?? 0;

    final checklist = <Widget>[
      if ((unbatched.value ?? 0) > 0)
        _CheckRow(
          icon: AppIcons.batches,
          text: "${unbatched.value} ${unbatched.value == 1 ? "sample isn't" : "samples aren't"} in a batch yet",
          action: 'Auto-batch',
          onTap: () => context.pushNamed(Routes.batchAuto),
        ),
      if ((unallocated.value ?? 0) > 0)
        _CheckRow(
          icon: AppIcons.people,
          text: '${unallocated.value} ${unallocated.value == 1 ? 'lot' : 'lots'} offered today ${unallocated.value == 1 ? 'has' : 'have'} no buyers',
          action: 'Allocate',
          onTap: () => context.pushNamed(Routes.offeredToday),
        ),
      if ((awaiting.value ?? 0) > 0)
        _CheckRow(
          icon: AppIcons.bids,
          text: '${awaiting.value} ${awaiting.value == 1 ? 'bid is' : 'bids are'} awaiting allocation',
          action: 'Review',
          onTap: () => context.goNamed(Routes.bids),
        ),
      if (pendingSales > 0)
        _CheckRow(
          icon: AppIcons.approval,
          text: '$pendingSales ${pendingSales == 1 ? 'sale is' : 'sales are'} waiting for approval',
          action: 'Review',
          onTap: () {
            ref.read(salesQueryProvider.notifier).replace(const ListQuery(params: {'status': 'pending'}));
            context.pushNamed(Routes.sales);
          },
        ),
      if (unregistered > 0)
        _CheckRow(
          icon: AppIcons.exFactory,
          text: '$unregistered ex-factory ${unregistered == 1 ? 'bill is' : 'bills are'} unregistered',
          action: 'Open',
          onTap: () => context.pushNamed(Routes.exFactory),
        ),
    ];
    final checklistLoading = unbatched.isLoading || unallocated.isLoading || awaiting.isLoading || dash.isLoading;

    return PageScaffold(
      title: 'Today',
      caption: Fmt.longDay(DateTime.now()),
      onRefresh: () async {
        refreshHome(ref);
        await ref.read(dashboardProvider.future).catchError((_) => const DashboardSummary());
      },
      slivers: [
        SliverList.list(
          children: [
            GridView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 84,
              ),
              children: [
                MetricCard(
                  label: 'Samples today',
                  value: dashCount((d) => d.samplesToday),
                  hint: d?.samplesTotal == null ? null : '${Fmt.number(d!.samplesTotal)} in all',
                  loading: dash.isLoading,
                  onTap: () => context.goNamed(Routes.samples),
                ),
                MetricCard(label: 'Unbatched', value: count(unbatched), loading: unbatched.isLoading, onTap: () => context.pushNamed(Routes.batchAuto)),
                MetricCard(label: 'Open bids', value: dashCount((d) => d.openBids), loading: dash.isLoading, onTap: () => context.goNamed(Routes.bids)),
                MetricCard(
                  label: 'Ex-factory mismatches',
                  value: dashCount((d) => d.exMismatched),
                  loading: dash.isLoading,
                  valueColor: mismatches > 0 ? c.warning : null,
                  onTap: () => context.pushNamed(Routes.exFactory),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _SalesCard(dash: dash),
            const SizedBox(height: AppSpace.xl),
            _Label('Quick actions'),
            Row(
              children: [
                _Quick(icon: AppIcons.samples, label: 'New sample', onTap: () => context.pushNamed(Routes.sampleNew)),
                _Quick(icon: AppIcons.offers, label: 'New offer', onTap: () => context.pushNamed(Routes.offerNew)),
                _Quick(icon: AppIcons.personAdd, label: 'Allocate', onTap: () => context.pushNamed(Routes.offeredToday)),
                _Quick(icon: AppIcons.courier, label: 'Courier', onTap: () => context.pushNamed(Routes.courierNew)),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            _Label("Today's checklist"),
            if (checklist.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  AppIcon(checklistLoading ? AppIcons.clock : AppIcons.allDone, color: checklistLoading ? c.textTertiary : c.success, size: 20),
                  const SizedBox(width: 10),
                  Text(checklistLoading ? 'Checking…' : "You're all caught up.", style: AppText.callout),
                ]),
              )
            else
              GroupedSection(dividerIndent: 54, children: checklist),
            const SizedBox(height: AppSpace.xl),
            _Label('Recent samples'),
            recent.when(
              loading: () => const AppCard(child: SizedBox(height: 112, child: Center(child: AppSpinner()))),
              error: (e, _) => AppCard(
                padding: const EdgeInsets.all(14),
                child: Text("Couldn't load recent samples.", style: AppText.callout.copyWith(color: c.textTertiary)),
              ),
              data: (list) => list.isEmpty
                  ? AppCard(
                      padding: const EdgeInsets.all(14),
                      child: Text('New samples will show up here.', style: AppText.callout.copyWith(color: c.textTertiary)),
                    )
                  : GroupedSection(children: [for (final s in list) SampleRow(sample: s)]),
            ),
          ],
        ),
      ],
    );
  }
}

/// Sales value, kg and pending approvals, across all time.
class _SalesCard extends StatelessWidget {
  const _SalesCard({required this.dash});
  final AsyncValue<DashboardSummary> dash;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = dash.value;
    final pending = d?.salesPending;
    return AppCard(
      onTap: () => context.pushNamed(Routes.sales),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text('Sales', style: AppText.footnote.copyWith(color: c.textTertiary))),
            Text('All time', style: AppText.footnote.copyWith(color: c.textTertiary)),
          ]),
          const SizedBox(height: 4),
          SizedBox(
            height: 30,
            child: dash.isLoading && d == null
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: Container(width: 120, height: 20, decoration: BoxDecoration(color: c.fill, borderRadius: BorderRadius.circular(6))),
                  )
                : FitText(d == null ? '–' : Fmt.money(d.salesAmount), style: AppText.metric),
          ),
          const SizedBox(height: 2),
          Text(
            [
              Fmt.kg(d?.salesKg),
              if (pending != null) pending == 0 ? 'nothing pending' : '${Fmt.number(pending)} pending approval',
            ].join(' · '),
            style: AppText.footnote.copyWith(color: pending != null && pending > 0 ? c.warning : c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 0, 4, 7),
        child: Text(text, style: AppText.footnote.copyWith(color: context.colors.textTertiary)),
      );
}

class _Quick extends StatelessWidget {
  const _Quick({required this.icon, required this.label, required this.onTap});
  final AppIcons icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Expanded(
      child: Semantics(
        button: true,
        label: label,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Column(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: ShapeDecoration(
                  color: c.surface,
                  shadows: c.cardShadow,
                  shape: const RoundedSuperellipseBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
                ),
                child: AppIcon(icon, color: c.accent, size: 24),
              ),
              const SizedBox(height: 6),
              OneLineText(label, style: AppText.caption.copyWith(color: c.textSecondary, fontWeight: FontWeight.w400)),
            ],
          ),
        ),
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.icon, required this.text, required this.action, required this.onTap});
  final AppIcons icon;
  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AppListRow(
      title: text,
      titleStyle: AppText.callout,
      minHeight: 52,
      leading: IconTile(icon: icon, size: 28, color: c.warning, background: c.warning.withValues(alpha: 0.13)),
      trailing: Text(action, style: AppText.callout.copyWith(color: c.accent)),
      onTap: onTap,
    );
  }
}
