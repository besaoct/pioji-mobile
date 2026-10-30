import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/fields.dart';
import '../../../core/widgets/sheets.dart';
import '../data/masters_repository.dart';

/// Picker row for a master record. Uses the list endpoint when it has data,
/// otherwise asks for the numeric ID so forms keep working before the
/// backend adds lookup endpoints.
class MasterPickerRow extends ConsumerWidget {
  const MasterPickerRow({
    super.key,
    required this.label,
    required this.provider,
    required this.value,
    required this.onChanged,
    this.error,
    this.placeholder = 'Select',
  });

  final String label;
  final FutureProvider<List<MasterItem>> provider;
  final MasterItem? value;
  final ValueChanged<MasterItem?> onChanged;
  final String? error;
  final String placeholder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueRow(
      label: label,
      value: value?.name,
      placeholder: placeholder,
      error: error,
      onTap: () async {
        final items = await ref.read(provider.future);
        if (!context.mounted) return;
        if (items.isEmpty) {
          final id = await _askId(context, label, value?.id);
          if (id != null) onChanged(MasterItem(id, '#$id'));
          return;
        }
        final picked = await showPickerSheet<MasterItem>(
          context,
          title: label,
          selected: value == null ? null : items.where((i) => i.id == value!.id).firstOrNull,
          options: [for (final i in items) PickOption(i, i.name, subtitle: i.subtitle)],
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

/// Grade picker from `GET /grades`, falling back to the built-in list.
class GradePickerRow extends ConsumerWidget {
  const GradePickerRow({super.key, required this.value, required this.onChanged, this.error, this.label = 'Grade'});

  final String? value;
  final ValueChanged<String> onChanged;
  final String? error;
  final String label;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueRow(
      label: label,
      value: value,
      error: error,
      onTap: () async {
        final grades = await ref.read(gradesProvider.future);
        if (!context.mounted) return;
        final picked = await showPickerSheet<String>(
          context,
          title: label,
          selected: value,
          options: [for (final g in grades) PickOption(g, g)],
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

Future<int?> _askId(BuildContext context, String label, int? current) {
  final ctl = TextEditingController(text: current?.toString() ?? '');
  return showCupertinoDialog<int>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text('$label ID'),
      content: Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Column(
          children: [
            const Text("The list isn't available yet. Enter the ID from the admin panel."),
            const SizedBox(height: 10),
            CupertinoTextField(controller: ctl, keyboardType: TextInputType.number, autofocus: true, placeholder: 'ID'),
          ],
        ),
      ),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        CupertinoDialogAction(
          isDefaultAction: true,
          onPressed: () => Navigator.pop(ctx, int.tryParse(ctl.text.trim())),
          child: const Text('Use'),
        ),
      ],
    ),
  );
}
