import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../application/invalidation.dart';
import '../design/context_ext.dart';
import '../errors/app_failure.dart';
import 'buttons.dart';
import 'sheets.dart';

/// Red "Delete …" button for detail screens: confirms with the record's
/// name, deletes, refreshes the list and Home, then goes back.
class DeleteRecordButton extends ConsumerStatefulWidget {
  const DeleteRecordButton({
    super.key,
    required this.what,
    required this.name,
    required this.onDelete,
    required this.onDeleted,
  });

  /// Lower-case noun: "batch", "courier entry".
  final String what;

  /// What the user recognises the record by, shown in the confirmation.
  final String name;
  final Future<void> Function(WidgetRef ref) onDelete;

  /// Invalidate the module's providers here.
  final void Function(WidgetRef ref) onDeleted;

  @override
  ConsumerState<DeleteRecordButton> createState() => _DeleteRecordButtonState();
}

class _DeleteRecordButtonState extends ConsumerState<DeleteRecordButton> {
  bool _busy = false;

  Future<void> _delete() async {
    final ok = await confirm(
      context,
      title: 'Delete this ${widget.what}?',
      body: '${widget.name} will be removed. This can’t be undone.',
      action: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.onDelete(ref);
      if (!mounted) return;
      widget.onDeleted(ref);
      refreshSummaries(ref);
      final what = widget.what;
      context.toast('${what[0].toUpperCase()}${what.substring(1)} deleted');
      context.pop();
    } on AppFailure catch (f) {
      if (mounted) context.toast(f.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final what = widget.what;
    return PrimaryButton(
      label: 'Delete $what',
      destructive: true,
      loading: _busy,
      onPressed: _delete,
    );
  }
}
