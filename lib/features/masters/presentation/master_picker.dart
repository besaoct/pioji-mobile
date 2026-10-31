import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_row.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/sheets.dart';
import '../data/masters_repository.dart';

class _RemoteSearchSheet extends ConsumerStatefulWidget {
  const _RemoteSearchSheet({required this.title, required this.path, required this.initial, this.selectedId});

  final String title;
  final String path;
  final FutureProvider<List<MasterItem>> initial;
  final int? selectedId;

  @override
  ConsumerState<_RemoteSearchSheet> createState() => _RemoteSearchSheetState();
}

class _RemoteSearchSheetState extends ConsumerState<_RemoteSearchSheet> {
  List<MasterItem>? _results;
  bool _loading = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    ref.read(widget.initial.future).then((v) {
      if (mounted && _seq == 0) setState(() => (_results = v, _loading = false));
    });
  }

  Future<void> _search(String q) async {
    final seq = ++_seq;
    setState(() => _loading = true);
    final r = await ref.read(mastersRepositoryProvider).search(widget.path, q);
    if (!mounted || seq != _seq) return;
    setState(() => (_results = r, _loading = false));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = _results ?? const <MasterItem>[];
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppText.title),
              const SizedBox(height: AppSpace.md),
              SearchField(hint: 'Search by name', onChanged: _search),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: _loading && items.isEmpty
                    ? const Center(child: CupertinoActivityIndicator())
                    : items.isEmpty
                        ? Center(child: Text('No matches', style: AppText.callout.copyWith(color: c.textTertiary)))
                        : SingleChildScrollView(
                            child: GroupedSection(
                              children: [
                                for (final i in items)
                                  AppListRow(
                                    title: i.name,
                                    subtitle: i.subtitle,
                                    minHeight: 48,
                                    titleStyle: AppText.body,
                                    onTap: () => Navigator.pop(context, i),
                                    trailing: i.id == widget.selectedId
                                        ? Icon(CupertinoIcons.checkmark_alt, color: c.accent, size: 20)
                                        : null,
                                  ),
                              ],
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

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
    this.searchPath,
  });

  final String label;
  final FutureProvider<List<MasterItem>> provider;
  final MasterItem? value;
  final ValueChanged<MasterItem?> onChanged;
  final String? error;
  final String placeholder;

  /// For large lists: search this endpoint on the server as the user types.
  final String? searchPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ValueRow(
      label: label,
      value: value?.name,
      placeholder: placeholder,
      error: error,
      onTap: () async {
        if (searchPath != null) {
          final picked = await showModalBottomSheet<MasterItem>(
            context: context,
            isScrollControlled: true,
            builder: (_) => _RemoteSearchSheet(title: label, path: searchPath!, initial: provider, selectedId: value?.id),
          );
          if (picked != null) onChanged(picked);
          return;
        }
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
