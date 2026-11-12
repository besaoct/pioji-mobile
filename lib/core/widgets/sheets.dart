import 'package:flutter/material.dart';

import '../design/context_ext.dart';
import '../design/tokens.dart';
import '../design/typography.dart';
import 'app_card.dart';
import 'app_list_row.dart';
import 'buttons.dart';
import 'search_field.dart';
import '../design/app_icons.dart';

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
                                    ? AppIcon(AppIcons.check, color: c.accent, size: 20)
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
                          trailing: AppIcon(
                            _sel.contains(o.value) ? AppIcons.checkCircleFill : AppIcons.circle,
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

/// Opens [builder] as a centred dialog with a fade and slight scale.
Future<T?> showAppDialog<T>(BuildContext context, {required WidgetBuilder builder, bool dismissible = true}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: dismissible,
    barrierLabel: 'Close',
    barrierColor: const Color(0x66000000),
    transitionDuration: const Duration(milliseconds: 180),
    pageBuilder: (ctx, _, _) => builder(ctx),
    transitionBuilder: (ctx, a, _, child) {
      final curved = CurvedAnimation(parent: a, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween<double>(begin: 0.96, end: 1).animate(curved), child: child),
      );
    },
  );
}

class AppDialogAction {
  const AppDialogAction(this.label, this.onPressed, {this.primary = false, this.destructive = false});
  final String label;
  final VoidCallback? onPressed;
  final bool primary;
  final bool destructive;
}

/// Card-style dialog: title, optional body text or content, buttons on the right.
class AppDialog extends StatelessWidget {
  const AppDialog({super.key, required this.title, this.body, this.content, required this.actions});

  final String title;
  final String? body;
  final Widget? content;
  final List<AppDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return AnimatedPadding(
      duration: const Duration(milliseconds: 120),
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Material(
              color: c.surfaceRaised,
              shape: AppRadius.cardBorder,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.xl, AppSpace.xl, AppSpace.md, AppSpace.sm),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.sm),
                      child: Text(title, style: AppText.headline.copyWith(color: c.textPrimary)),
                    ),
                    if (body != null) ...[
                      const SizedBox(height: AppSpace.sm),
                      Padding(
                        padding: const EdgeInsets.only(right: AppSpace.sm),
                        child: Text(body!, style: AppText.callout.copyWith(color: c.textSecondary)),
                      ),
                    ],
                    if (content != null) ...[
                      const SizedBox(height: AppSpace.md),
                      Padding(padding: const EdgeInsets.only(right: AppSpace.sm), child: content!),
                    ],
                    const SizedBox(height: AppSpace.md),
                    Wrap(
                      alignment: WrapAlignment.end,
                      children: [
                        for (final a in actions)
                          LinkButton(
                            label: a.label,
                            onPressed: a.onPressed,
                            color: a.destructive ? c.danger : (a.primary ? c.accent : c.textSecondary),
                            style: AppText.callout.copyWith(fontWeight: a.primary || a.destructive ? FontWeight.w600 : FontWeight.w500),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
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
  final ok = await showAppDialog<bool>(
    context,
    builder: (ctx) => AppDialog(
      title: title,
      body: body,
      actions: [
        AppDialogAction('Cancel', () => Navigator.pop(ctx, false)),
        AppDialogAction(action, () => Navigator.pop(ctx, true), primary: !destructive, destructive: destructive),
      ],
    ),
  );
  return ok ?? false;
}

/// Bottom sheet with several named choices. Returns the chosen key.
Future<String?> chooseAction(
  BuildContext context, {
  required String title,
  String? message,
  required Map<String, String> actions,
  Set<String> destructive = const {},
}) {
  return showModalBottomSheet<String>(
    context: context,
    builder: (ctx) {
      final c = ctx.colors;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, 0, AppSpace.lg, AppSpace.sm),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: AppText.headline),
              if (message != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(message, style: AppText.footnote.copyWith(color: c.textTertiary)),
              ],
              const SizedBox(height: AppSpace.md),
              GroupedSection(
                children: [
                  for (final e in actions.entries)
                    AppListRow(
                      title: e.value,
                      minHeight: 50,
                      titleStyle: AppText.body.copyWith(color: destructive.contains(e.key) ? c.danger : c.textPrimary),
                      onTap: () => Navigator.pop(ctx, e.key),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.sm),
              Center(child: LinkButton(label: 'Cancel', color: c.textSecondary, onPressed: () => Navigator.pop(ctx))),
            ],
          ),
        ),
      );
    },
  );
}
