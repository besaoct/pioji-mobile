import 'package:flutter/material.dart';

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

class SampleDetailScreen extends StatelessWidget {
  const SampleDetailScreen({super.key, required this.sample});
  final Sample? sample;

  @override
  Widget build(BuildContext context) {
    final s = sample;
    if (s == null) return const MissingItemScreen(what: 'sample');
    final c = context.colors;
    return DetailScaffold(
      title: s.gardenName ?? 'Sample',
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
            InfoRow('Batch', s.batchId == null ? 'Not batched' : '#${s.batchId}'),
            if (s.remarks != null) InfoBlock('Remarks', s.remarks!),
          ],
        ),
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
