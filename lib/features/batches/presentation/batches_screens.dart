import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_row.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/detail.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/form_submit.dart';
import '../../../core/widgets/module_list.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../samples/data/samples_repository.dart';
import '../../samples/domain/sample.dart';
import '../../samples/presentation/samples_list_screen.dart';
import '../data/batches_repository.dart';

class BatchesListScreen extends StatelessWidget {
  const BatchesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListScreen<Batch>(
      title: 'Batches',
      inTabs: false,
      listProvider: batchesListProvider,
      queryProvider: batchesQueryProvider,
      searchHint: 'Search batches',
      emptyIcon: CupertinoIcons.square_stack_3d_up,
      emptyTitle: 'Group samples into batches',
      emptyBody: 'Each batch holds up to 48 samples for one tasting session.',
      newLabel: 'Auto-batch a date',
      onNew: () => context.pushNamed(Routes.batchAuto),
      actions: [
        LinkButton(label: 'Auto-batch', onPressed: () => context.pushNamed(Routes.batchAuto)),
        AddButton(semanticLabel: 'New batch', onPressed: () => context.pushNamed(Routes.batchNew)),
      ],
      segments: const SegmentConfig(param: 'status', options: {'': 'All', 'open': 'Open', 'closed': 'Closed'}),
      filters: const [DateFilter('date', 'Date')],
      itemBuilder: (context, b) => AppListRow(
        title: b.name,
        subtitle: Fmt.day(b.date),
        onTap: () => context.pushNamed(Routes.batchDetail, pathParameters: {'id': '${b.id}'}, extra: b),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${b.count} / $kBatchCap', style: AppText.callout.copyWith(color: context.colors.textSecondary)),
            const SizedBox(height: 4),
            StatusBadge(b.open ? 'Open' : 'Closed', tone: b.open ? Tone.accent : Tone.neutral),
          ],
        ),
      ),
    );
  }
}

class BatchFormScreen extends ConsumerStatefulWidget {
  const BatchFormScreen({super.key});

  @override
  ConsumerState<BatchFormScreen> createState() => _BatchFormScreenState();
}

class _BatchFormScreenState extends ConsumerState<BatchFormScreen> with FormSubmit {
  final _name = TextEditingController();
  final _notes = TextEditingController();
  DateTime _date = DateTime.now();
  bool _open = true;
  Set<int> _ids = {};
  List<Sample> _picked = const [];

  @override
  void dispose() {
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _pickSamples() async {
    try {
      final samples = await ref.read(unbatchedProvider(DateUtils.dateOnly(_date)).future);
      if (!mounted) return;
      if (samples.isEmpty) {
        context.toast('No unbatched samples for ${Fmt.day(_date)}.');
        return;
      }
      final sel = await showMultiPickerSheet<int>(
        context,
        title: 'Add samples',
        max: kBatchCap,
        selected: _ids,
        options: [for (final s in samples) PickOption(s.id, s.title, subtitle: Fmt.invoice(s.invoicePrefix, s.invoiceNo))],
      );
      if (sel != null) {
        setState(() {
          _ids = sel;
          _picked = samples.where((s) => sel.contains(s.id)).toList();
        });
      }
    } on AppFailure catch (f) {
      if (mounted) context.toast(f.message);
    }
  }

  Future<void> _save() async {
    final ok = await submit<bool>(() async {
      await ref.read(batchesRepositoryProvider).create(
            name: _name.text.trim(),
            date: _date,
            open: _open,
            notes: _notes.text.trim(),
            sampleIds: _ids.toList(),
          );
      return true;
    });
    if (ok == true && mounted) {
      ref.invalidate(batchesListProvider);
      ref.invalidate(unbatchedProvider);
      ref.invalidate(samplesListProvider);
      refreshSummaries(ref);
      context.toast('Batch created');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'New batch',
      submitLabel: 'Create batch',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (banner != null) FormBanner(banner!),
        GroupedSection(
          label: 'Batch',
          children: [
            FieldInput(label: 'Name', hint: 'Generated automatically if empty', controller: _name, error: err('batch_name')),
            DateRow(
              label: 'Date',
              value: _date,
              onChanged: (d) => setState(() {
                _date = d;
                _ids = {};
                _picked = const [];
              }),
            ),
            SwitchRow(label: 'Open', value: _open, onChanged: (v) => setState(() => _open = v)),
            FieldInput(label: 'Notes', hint: 'Testing premium BOP lots', controller: _notes, maxLines: 3),
          ],
        ),
        GroupedSection(
          label: 'Samples',
          trailingLabel: Text('${_ids.length} / $kBatchCap', style: AppText.footnote.copyWith(color: context.colors.textTertiary)),
          footer: err('sample_ids') == null ? null : Text(err('sample_ids')!, style: TextStyle(color: context.colors.danger)),
          children: [
            for (final s in _picked) SampleRow(sample: s),
            ValueRow(label: _picked.isEmpty ? 'Add samples' : 'Change samples', value: null, placeholder: '', onTap: _pickSamples),
          ],
        ),
      ],
    );
  }
}

class AutoBatchScreen extends ConsumerStatefulWidget {
  const AutoBatchScreen({super.key});

  @override
  ConsumerState<AutoBatchScreen> createState() => _AutoBatchScreenState();
}

class _AutoBatchScreenState extends ConsumerState<AutoBatchScreen> with FormSubmit {
  DateTime _date = DateUtils.dateOnly(DateTime.now());

  Future<void> _run() async {
    final made = await submit<List<Batch>>(() => ref.read(batchesRepositoryProvider).createForDate(_date));
    if (made != null && mounted) {
      ref.invalidate(batchesListProvider);
      ref.invalidate(unbatchedProvider);
      ref.invalidate(samplesListProvider);
      refreshSummaries(ref);
      context.toast(made.isEmpty ? 'Batches created' : '${made.length} ${made.length == 1 ? 'batch' : 'batches'} created');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final unbatched = ref.watch(unbatchedProvider(_date));
    final count = unbatched.value?.length;
    final batches = count == null ? null : (count / kBatchCap).ceil();
    return FormScaffold(
      title: 'Auto-batch',
      submitLabel: count == 0 ? 'Nothing to batch' : 'Create batches',
      submitting: submitting,
      onSubmit: count == 0 ? null : _run,
      children: [
        if (banner != null) FormBanner(banner!),
        GroupedSection(
          label: 'Date',
          footer: const Text('Groups every unbatched sample from this date into batches of up to 48.'),
          children: [DateRow(label: 'Samples from', value: _date, onChanged: (d) => setState(() => _date = DateUtils.dateOnly(d)))],
        ),
        AppCard(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: unbatched.when(
            loading: () => const Center(child: CupertinoActivityIndicator()),
            error: (e, _) => Text(e is AppFailure ? e.message : 'Couldn’t load samples.', style: AppText.callout.copyWith(color: c.danger)),
            data: (list) => Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${list.length}', style: AppText.metric),
                      Text('Unbatched samples', style: AppText.footnote.copyWith(color: c.textTertiary)),
                    ],
                  ),
                ),
                Icon(CupertinoIcons.arrow_right, color: c.textTertiary),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('${batches ?? 0}', style: AppText.metric.copyWith(color: c.accent)),
                      Text((batches ?? 0) == 1 ? 'Batch' : 'Batches', style: AppText.footnote.copyWith(color: c.textTertiary)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class BatchDetailScreen extends StatelessWidget {
  const BatchDetailScreen({super.key, required this.batch});
  final Batch? batch;

  @override
  Widget build(BuildContext context) {
    final b = batch;
    if (b == null) return const MissingItemScreen(what: 'batch');
    return DetailScaffold(
      title: b.name,
      children: [
        GroupedSection(
          children: [
            InfoRow('Date', Fmt.day(b.date)),
            InfoRow('Status', b.open ? 'Open' : 'Closed'),
            InfoRow('Samples', '${b.count} / $kBatchCap'),
            if (b.notes != null) InfoBlock('Notes', b.notes!),
          ],
        ),
        if (b.samples.isNotEmpty)
          GroupedSection(label: 'Samples', children: [for (final s in b.samples) SampleRow(sample: s)]),
      ],
    );
  }
}
