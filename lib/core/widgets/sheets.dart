import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_card.dart';
import 'app_list_row.dart';
import 'search_field.dart';

class PickOption<T> {
  const PickOption(this.value, this.label, {this.subtitle});
  final T value;
  final String label;
  final String? subtitle;
}

/// Searchable single-choice sheet.
Future<T?> showPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickOption<T>> options,
  T? selected,
  bool searchable = true,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _PickerSheet<T>(title: title, options: options, selected: selected, searchable: searchable),
  );
}

class _PickerSheet<T> extends StatefulWidget {
  const _PickerSheet({required this.title, required this.options, this.selected, required this.searchable});

  final String title;
  final List<PickOption<T>> options;
  final T? selected;
  final bool searchable;

  @override
  State<_PickerSheet<T>> createState() => _PickerSheetState<T>();
}

class _PickerSheetState<T> extends State<_PickerSheet<T>> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visible = widget.options
        .where((o) => _q.isEmpty || o.label.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.72,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpace.lg,
            right: AppSpace.lg,
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: AppText.title),
              const SizedBox(height: AppSpace.md),
              if (widget.searchable && widget.options.length > 6) ...[
                SearchField(hint: 'Search', onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: AppSpace.md),
              ],
              Expanded(
                child: visible.isEmpty
                    ? Center(child: Text('No matches', style: AppText.callout.copyWith(color: c.textTertiary)))
                    : SingleChildScrollView(
                        child: GroupedSection(
                          children: [
                            for (final o in visible)
                              AppListRow(
                                title: o.label,
                                subtitle: o.subtitle,
                                minHeight: 48,
                                titleStyle: AppText.body,
                                onTap: () => Navigator.pop(context, o.value),
                                trailing: o.value == widget.selected
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

/// Multi-select sheet with a live count and optional cap.
Future<Set<T>?> showMultiPickerSheet<T>(
  BuildContext context, {
  required String title,
  required List<PickOption<T>> options,
  Set<T> selected = const {},
  int? max,
}) {
  return showModalBottomSheet<Set<T>>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => _MultiSheet<T>(title: title, options: options, initial: selected, max: max),
  );
}

class _MultiSheet<T> extends StatefulWidget {
  const _MultiSheet({required this.title, required this.options, required this.initial, this.max});

  final String title;
  final List<PickOption<T>> options;
  final Set<T> initial;
  final int? max;

  @override
  State<_MultiSheet<T>> createState() => _MultiSheetState<T>();
}

class _MultiSheetState<T> extends State<_MultiSheet<T>> {
  late final Set<T> _sel = {...widget.initial};
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final visible = widget.options
        .where((o) => _q.isEmpty || o.label.toLowerCase().contains(_q.toLowerCase()))
        .toList();
    final atCap = widget.max != null && _sel.length >= widget.max!;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: Text(widget.title, style: AppText.title)),
                  Text(
                    widget.max == null ? '${_sel.length} selected' : '${_sel.length} / ${widget.max}',
                    style: AppText.callout.copyWith(color: atCap ? c.warning : c.textTertiary),
                  ),
                ],
              ),
              const SizedBox(height: AppSpace.md),
              if (widget.options.length > 6) ...[
                SearchField(hint: 'Search', onChanged: (v) => setState(() => _q = v)),
                const SizedBox(height: AppSpace.md),
              ],
              Expanded(
                child: SingleChildScrollView(
                  child: GroupedSection(
                    children: [
                      for (final o in visible)
                        AppListRow(
                          title: o.label,
                          subtitle: o.subtitle,
                          minHeight: 48,
                          titleStyle: AppText.body,
                          onTap: () => setState(() {
                            if (_sel.contains(o.value)) {
                              _sel.remove(o.value);
                            } else if (!atCap) {
                              _sel.add(o.value);
                            }
                          }),
                          trailing: Icon(
                            _sel.contains(o.value) ? CupertinoIcons.checkmark_circle_fill : CupertinoIcons.circle,
                            color: _sel.contains(o.value) ? c.accent : c.textTertiary,
                            size: 22,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppSpace.md),
              SizedBox(
                height: 50,
                child: FilledButton(onPressed: () => Navigator.pop(context, _sel), child: const Text('Done')),
              ),
              const SizedBox(height: AppSpace.sm),
            ],
          ),
        ),
      ),
    );
  }
}

Future<bool> confirm(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  bool destructive = false,
}) async {
  final ok = await showCupertinoDialog<bool>(
    context: context,
    builder: (ctx) => CupertinoAlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        CupertinoDialogAction(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        CupertinoDialogAction(
          isDestructiveAction: destructive,
          isDefaultAction: !destructive,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Action sheet with several named choices. Returns the chosen key.
Future<String?> chooseAction(
  BuildContext context, {
  required String title,
  String? message,
  required Map<String, String> actions,
  Set<String> destructive = const {},
}) {
  return showCupertinoModalPopup<String>(
    context: context,
    builder: (ctx) => CupertinoActionSheet(
      title: Text(title),
      message: message == null ? null : Text(message),
      actions: [
        for (final e in actions.entries)
          CupertinoActionSheetAction(
            isDestructiveAction: destructive.contains(e.key),
            onPressed: () => Navigator.pop(ctx, e.key),
            child: Text(e.value),
          ),
      ],
      cancelButton: CupertinoActionSheetAction(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
    ),
  );
}
