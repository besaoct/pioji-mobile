import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/sheets.dart';
import '../data/samples_repository.dart';

import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/detail.dart';
import '../../../core/widgets/one_line_text.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../../core/widgets/status_badge.dart';
import '../domain/sample.dart';

class SampleDetailScreen extends ConsumerStatefulWidget {
  const SampleDetailScreen({super.key, required this.sample});
  final Sample? sample;

  @override
  ConsumerState<SampleDetailScreen> createState() => _SampleDetailScreenState();
}

class _SampleDetailScreenState extends ConsumerState<SampleDetailScreen> {
  bool _deleting = false;

  Future<void> _delete(Sample s) async {
    final ok = await confirm(
      context,
      title: 'Delete this sample?',
      body: '${s.title} (${Fmt.invoice(s.invoicePrefix, s.invoiceNo)}) will be removed. This can’t be undone.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _deleting = true);
    try {
      await ref.read(samplesRepositoryProvider).delete(s.id);
      if (!mounted) return;
      ref.invalidate(samplesListProvider);
      refreshSummaries(ref);
      context.toast('Sample deleted');
      context.pop();
    } on AppFailure catch (f) {
      if (mounted) context.toast(f.message);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sample;
    if (s == null) return const MissingItemScreen(what: 'sample');
    final c = context.colors;
    return DetailScaffold(
      title: s.gardenName ?? 'Sample',
      actions: [
        LinkButton(
          label: 'Edit',
          onPressed: () => context.pushNamed(Routes.sampleEdit, pathParameters: {'id': '${s.id}'}, extra: s),
        ),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: OneLineText(s.title, style: AppText.headline)),
                  StatusBadge(s.statusLabel, tone: s.status.tone),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${Fmt.invoice(s.invoicePrefix, s.invoiceNo)} · Arrived ${Fmt.day(s.arrivalDate)}',
                style: AppText.footnote.copyWith(color: c.textTertiary),
              ),
              const SizedBox(height: AppSpace.md),
              const Divider(),
              const SizedBox(height: AppSpace.md),
              Row(
                children: [
                  _Stat('Packages', Fmt.number(s.packages)),
                  _Stat('Per package', Fmt.kg(s.weight)),
                  _Stat('Total', Fmt.kg(s.totalKgs)),
                ],
              ),
            ],
          ),
        ),
        GroupedSection(
          label: 'Details',
          children: [
            InfoRow('Sample type', s.sampleType),
            InfoRow('Grade', s.grade),
            InfoRow('Batch', s.batchRef ?? 'Not batched'),
            if (s.remarks != null) InfoBlock('Remarks', s.remarks!),
          ],
        ),
        PrimaryButton(label: 'Delete sample', destructive: true, loading: _deleting, onPressed: () => _delete(s)),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppText.caption.copyWith(color: context.colors.textTertiary, fontWeight: FontWeight.w400)),
          const SizedBox(height: 2),
          FitText(value, style: AppText.headline),
        ],
      ),
    );
  }
}
