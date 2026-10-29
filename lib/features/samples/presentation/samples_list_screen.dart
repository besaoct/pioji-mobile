import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../../core/design/context_ext.dart';
import '../../../core/design/typography.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_list_row.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/module_list.dart';
import '../../../core/widgets/status_badge.dart';
import '../data/samples_repository.dart';
import '../domain/sample.dart';

class SamplesListScreen extends StatelessWidget {
  const SamplesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListScreen<Sample>(
      title: 'Samples',
      listProvider: samplesListProvider,
      queryProvider: samplesQueryProvider,
      searchHint: 'Search garden, grade or invoice',
      emptyIcon: CupertinoIcons.lab_flask,
      emptyTitle: 'Add your first sample',
      emptyBody: 'Samples you receive show up here with their grade and weight.',
      newLabel: 'New sample',
      onNew: () => context.pushNamed(Routes.sampleNew),
      actions: [
        LinkButton(label: 'Batches', onPressed: () => context.pushNamed(Routes.batches)),
        AddButton(semanticLabel: 'New sample', onPressed: () => context.pushNamed(Routes.sampleNew)),
      ],
      segments: SegmentConfig(param: 'status', options: {
        '': 'All',
        for (final s in SampleStatus.pickable) s.api: s.label,
      }),
      filters: const [DateFilter('arrival_date', 'Arrival')],
      itemBuilder: (context, s) => SampleRow(sample: s),
    );
  }
}

class SampleRow extends StatelessWidget {
  const SampleRow({super.key, required this.sample});
  final Sample sample;

  @override
  Widget build(BuildContext context) {
    final s = sample;
    final sub = [
      Fmt.invoice(s.invoicePrefix, s.invoiceNo),
      if (s.packages != null && s.weight != null) '${s.packages} × ${Fmt.editable(s.weight)} kg',
    ].where((e) => e.isNotEmpty).join(' · ');
    return AppListRow(
      title: s.title,
      subtitle: sub.isEmpty ? Fmt.day(s.arrivalDate) : sub,
      minHeight: 64,
      onTap: () => context.pushNamed(Routes.sampleDetail, pathParameters: {'id': '${s.id}'}, extra: s),
      trailing: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(Fmt.kg(s.totalKgs), style: AppText.callout.copyWith(fontFeatures: const [FontFeature.tabularFigures()], color: context.colors.textPrimary)),
          const SizedBox(height: 4),
          StatusBadge(s.statusLabel, tone: s.status.tone),
        ],
      ),
    );
  }
}
