import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_row.dart';
import '../../../core/widgets/metric_card.dart';
import '../../../core/widgets/one_line_text.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../ex_factory/data/ex_factory_repository.dart';
import '../../samples/presentation/samples_list_screen.dart';
import '../application/home_providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    String count(AsyncValue<int> v) => v.when(data: Fmt.number, loading: () => '–', error: (_, _) => '–');
    final samples = ref.watch(samplesTodayCountProvider);
    final unbatched = ref.watch(unbatchedTodayProvider);
    final open = ref.watch(openBidsCountProvider);
    final awaiting = ref.watch(awaitingBidsCountProvider);
    final ex = ref.watch(exMetricsHomeProvider);
    final unallocated = ref.watch(unallocatedTodayProvider);
    final recent = ref.watch(recentSamplesProvider);
    final mismatches = ex.whenData((m) => (m[RegisterStatus.priceMismatch] ?? 0) + (m[RegisterStatus.qtyMismatch] ?? 0));
    final unregistered = ex.value?[RegisterStatus.unregistered] ?? 0;

    final checklist = <Widget>[
      if ((unbatched.value ?? 0) > 0)
        _CheckRow(
          icon: CupertinoIcons.square_stack_3d_up,
          text: "${unbatched.value} ${unbatched.value == 1 ? "sample isn't" : "samples aren't"} in a batch yet",
          action: 'Auto-batch',
          onTap: () => context.pushNamed(Routes.batchAuto),
        ),
      if ((unallocated.value ?? 0) > 0)
        _CheckRow(
          icon: CupertinoIcons.person_2,
          text: '${unallocated.value} ${unallocated.value == 1 ? 'lot' : 'lots'} offered today ${unallocated.value == 1 ? 'has' : 'have'} no buyers',
          action: 'Allocate',
          onTap: () => context.pushNamed(Routes.offeredToday),
        ),
      if ((awaiting.value ?? 0) > 0)
        _CheckRow(
          icon: CupertinoIcons.hammer,
          text: '${awaiting.value} ${awaiting.value == 1 ? 'bid is' : 'bids are'} awaiting allocation',
          action: 'Review',
          onTap: () => context.goNamed(Routes.bids),
        ),
      if (unregistered > 0)
        _CheckRow(
          icon: CupertinoIcons.doc_chart,
          text: '$unregistered ex-factory ${unregistered == 1 ? 'bill is' : 'bills are'} unregistered',
          action: 'Open',
          onTap: () => context.pushNamed(Routes.exFactory),
        ),
    ];
    final checklistLoading = unbatched.isLoading || unallocated.isLoading || awaiting.isLoading || ex.isLoading;

    return LargeTitleScaffold(
      title: 'Today',
      caption: Fmt.longDay(DateTime.now()),
      onRefresh: () async {
        refreshHome(ref);
        await ref.read(samplesTodayCountProvider.future).catchError((_) => 0);
      },
      slivers: [
        SliverList.list(
          children: [
            GridView.count(
              crossAxisCount: MediaQuery.of(context).size.width > 600 ? 4 : 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                MetricCard(label: 'Samples received', value: count(samples), loading: samples.isLoading, onTap: () => context.goNamed(Routes.samples)),
                MetricCard(label: 'Unbatched', value: count(unbatched), loading: unbatched.isLoading, onTap: () => context.pushNamed(Routes.batchAuto)),
                MetricCard(label: 'Open bids', value: count(open), loading: open.isLoading, onTap: () => context.goNamed(Routes.bids)),
                MetricCard(
                  label: 'Ex-factory mismatches',
                  value: count(mismatches),
                  loading: ex.isLoading,
                  valueColor: (mismatches.value ?? 0) > 0 ? c.warning : null,
                  onTap: () => context.pushNamed(Routes.exFactory),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            _Label('Quick actions'),
            Row(
              children: [
                _Quick(icon: CupertinoIcons.lab_flask, label: 'New sample', onTap: () => context.pushNamed(Routes.sampleNew)),
                _Quick(icon: CupertinoIcons.doc_on_doc, label: 'New offer', onTap: () => context.pushNamed(Routes.offerNew)),
                _Quick(icon: CupertinoIcons.person_add, label: 'Allocate', onTap: () => context.pushNamed(Routes.offeredToday)),
                _Quick(icon: CupertinoIcons.cube_box, label: 'Courier', onTap: () => context.pushNamed(Routes.courierNew)),
              ],
            ),
            const SizedBox(height: AppSpace.xl),
            _Label("Today's checklist"),
            if (checklist.isEmpty)
              AppCard(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Icon(checklistLoading ? CupertinoIcons.clock : CupertinoIcons.checkmark_seal, color: checklistLoading ? c.textTertiary : c.success, size: 20),
                  const SizedBox(width: 10),
                  Text(checklistLoading ? 'Checking…' : "You're all caught up.", style: AppText.callout),
                ]),
              )
            else
              GroupedSection(dividerIndent: 54, children: checklist),
            const SizedBox(height: AppSpace.xl),
            _Label('Recent samples'),
            recent.when(
              loading: () => const AppCard(child: SizedBox(height: 112, child: Center(child: CupertinoActivityIndicator()))),
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
  final IconData icon;
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
                child: Icon(icon, color: c.accent, size: 24),
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
  final IconData icon;
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
