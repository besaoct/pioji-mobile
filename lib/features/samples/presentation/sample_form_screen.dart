import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/design/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/form_submit.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/weight_fields.dart';
import '../../masters/data/masters_repository.dart';
import '../../masters/presentation/master_picker.dart';
import '../data/samples_repository.dart';
import '../domain/sample.dart';

class SampleFormScreen extends ConsumerStatefulWidget {
  const SampleFormScreen({super.key});

  @override
  ConsumerState<SampleFormScreen> createState() => _SampleFormScreenState();
}

class _SampleFormScreenState extends ConsumerState<SampleFormScreen> with FormSubmit {
  DateTime _arrival = DateTime.now();
  MasterItem? _garden;
  String? _grade;
  String _type = 'Original';
  SampleStatus _status = SampleStatus.received;
  final _prefix = TextEditingController();
  final _inv = TextEditingController();
  final _pkgs = TextEditingController();
  final _nett = TextEditingController();
  final _total = TextEditingController();
  final _remarks = TextEditingController();

  @override
  void dispose() {
    for (final c in [_prefix, _inv, _pkgs, _nett, _total, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _body({bool duplicate = false}) => {
        'arrival_date': Fmt.api(_arrival),
        'garden_id': _garden?.id,
        'grade': _grade,
        'invoice_prefix': _prefix.text.trim(),
        'inv_no': _inv.text.trim(),
        'packages': int.tryParse(_pkgs.text),
        'weight': Fmt.parse(_nett.text),
        'total_kgs': Fmt.parse(_total.text),
        'sample_type': _type,
        'status': _status.api,
        'remarks': _remarks.text.trim(),
        if (duplicate) 'is_duplicate': true,
      };

  Future<void> _save() async {
    final repo = ref.read(samplesRepositoryProvider);
    final ok = await submit<bool>(
      () async {
        await repo.create(_body());
        return true;
      },
      onDuplicate: (f) async {
        final again = await confirm(
          context,
          title: 'This invoice already exists',
          body: '${f.serverMessage}\n\nSave this sample anyway?',
          action: 'Save anyway',
        );
        if (!again) return null;
        return submit<bool>(() async {
          await repo.create(_body(duplicate: true));
          return true;
        });
      },
    );
    if (ok == true && mounted) {
      ref.invalidate(samplesListProvider);
      refreshSummaries(ref);
      context.toast('Sample saved');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'New sample',
      submitLabel: 'Save sample',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (banner != null) FormBanner(banner!),
        GroupedSection(
          label: 'Lot',
          children: [
            DateRow(label: 'Arrival date', value: _arrival, onChanged: (d) => setState(() => _arrival = d), error: err('arrival_date')),
            MasterPickerRow(label: 'Garden', provider: gardensProvider, value: _garden, onChanged: (g) => setState(() => _garden = g), error: err('garden_id')),
            GradePickerRow(value: _grade, onChanged: (g) => setState(() => _grade = g), error: err('grade')),
            Row(
              children: [
                SizedBox(
                  width: 120,
                  child: FieldInput(label: 'Prefix', hint: 'SMP', controller: _prefix, error: err('invoice_prefix'), textCapitalization: TextCapitalization.characters),
                ),
                Expanded(child: FieldInput(label: 'Invoice no', hint: '2048', controller: _inv, error: err('inv_no'))),
              ],
            ),
          ],
        ),
        WeightFields(
          pkgs: _pkgs,
          nett: _nett,
          total: _total,
          errors: errors,
          keys: (pkgs: 'packages', nett: 'weight', total: 'total_kgs'),
        ),
        GroupedSection(
          label: 'Details',
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  const Expanded(child: Text('Sample type')),
                  Segmented<String>(
                    compact: true,
                    options: const {'Original': 'Original', 'Standard': 'Standard'},
                    selected: _type,
                    onChanged: (v) => setState(() => _type = v),
                  ),
                ],
              ),
            ),
            ValueRow(
              label: 'Status',
              value: _status.label,
              onTap: () async {
                final s = await showPickerSheet<SampleStatus>(
                  context,
                  title: 'Status',
                  selected: _status,
                  options: [for (final s in SampleStatus.pickable) PickOption(s, s.label)],
                );
                if (s != null) setState(() => _status = s);
              },
            ),
            FieldInput(label: 'Remarks', hint: 'Clean liquor sample', controller: _remarks, maxLines: 3, error: err('remarks')),
          ],
        ),
      ],
    );
  }
}
