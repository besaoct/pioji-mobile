import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/design/context_ext.dart';
import '../../../core/design/tokens.dart';
import '../../../core/design/typography.dart';
import '../../../core/errors/app_failure.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_row.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/search_field.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/utils/formatters.dart';
import '../data/masters_repository.dart';
import '../../../core/design/app_icons.dart';
import '../../../core/widgets/controls.dart';

/// Opens the full garden list to pick a mark (used by list filters).
Future<String?> pickMark(BuildContext context) async {
  final g = await showModalBottomSheet<MasterItem>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _RemoteSearchSheet(title: 'Mark', path: '/gardens', initial: gardensProvider),
  );
  return g?.name;
}

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
  /// The full list when it loaded; searched on the phone.
  List<MasterItem>? _all;
  List<MasterItem>? _results;
  bool _loading = true;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    ref.read(widget.initial.future).then((v) {
      if (!mounted) return;
      setState(() => (_all = v.isEmpty ? null : v, _results = v, _loading = false));
    });
  }

  Future<void> _search(String q) async {
    final all = _all;
    if (all != null) {
      final t = q.trim().toLowerCase();
      setState(() => _results = t.isEmpty
          ? all
          : [
              ...all.where((i) => i.name.toLowerCase().startsWith(t)),
              ...all.where((i) => !i.name.toLowerCase().startsWith(t) && i.name.toLowerCase().contains(t)),
            ]);
      return;
    }
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
              if (_all != null) ...[
                const SizedBox(height: AppSpace.xs),
                Text(
                  '${Fmt.number(items.length)} of ${Fmt.number(_all!.length)}',
                  style: AppText.footnote.copyWith(color: c.textTertiary),
                ),
              ],
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: _loading && items.isEmpty
                    ? const Center(child: AppSpinner())
                    : items.isEmpty
                        ? Center(child: Text('No matches', style: AppText.callout.copyWith(color: c.textTertiary)))
                        : Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(color: c.surface, borderRadius: BorderRadius.circular(AppRadius.control)),
                            child: ListView.separated(
                              padding: EdgeInsets.zero,
                              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                              itemCount: items.length,
                              separatorBuilder: (_, _) => const Divider(height: 0.5),
                              itemBuilder: (_, n) {
                                final i = items[n];
                                return AppListRow(
                                  title: i.name,
                                  subtitle: i.subtitle,
                                  minHeight: 48,
                                  titleStyle: AppText.body,
                                  onTap: () => Navigator.pop(context, i),
                                  trailing: i.id == widget.selectedId
                                      ? AppIcon(AppIcons.check, color: c.accent, size: 20)
                                      : null,
                                );
                              },
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
        final creatable = _creatable[provider];
        if (items.isEmpty && creatable == null) {
          final id = await _askId(context, label, value?.id);
          if (id != null) onChanged(MasterItem(id, '#$id'));
          return;
        }
        final picked = creatable != null
            ? await showModalBottomSheet<MasterItem>(
                context: context,
                isScrollControlled: true,
                builder: (_) => _CreatableSheet(title: label, provider: provider, kind: creatable, selectedId: value?.id),
              )
            : await showPickerSheet<MasterItem>(
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

/// Lists whose picker can add a new record by name.
final _creatable = <FutureProvider<List<MasterItem>>, ({String noun, String path, String nameKey})>{
  buyersProvider: (noun: 'buyer', path: '/buyers', nameKey: 'buyer_name'),
  sellersProvider: (noun: 'seller', path: '/sellers', nameKey: 'seller_name'),
};

/// Search a buyer or seller list, or add the typed name as a new one.
class _CreatableSheet extends ConsumerStatefulWidget {
  const _CreatableSheet({required this.title, required this.provider, required this.kind, this.selectedId});

  final String title;
  final FutureProvider<List<MasterItem>> provider;
  final ({String noun, String path, String nameKey}) kind;
  final int? selectedId;

  @override
  ConsumerState<_CreatableSheet> createState() => _CreatableSheetState();
}

class _CreatableSheetState extends ConsumerState<_CreatableSheet> {
  String _q = '';
  bool _creating = false;

  Future<void> _create(String name) async {
    final noun = widget.kind.noun;
    final ok = await confirm(
      context,
      title: 'Add a new $noun?',
      body: '“$name” will be added to the ${noun}s list. Other details can be filled in later from the admin panel.',
      action: 'Add $noun',
    );
    if (!ok || !mounted) return;
    setState(() => _creating = true);
    try {
      final item = await ref.read(mastersRepositoryProvider).create(widget.kind.path, widget.kind.nameKey, name);
      ref.invalidate(widget.provider);
      if (mounted) Navigator.pop(context, item);
    } on AppFailure catch (f) {
      if (mounted) {
        setState(() => _creating = false);
        context.toast(f.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _creating = false);
        context.toast("Couldn't add the $noun. Try again.");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final noun = widget.kind.noun;
    final list = ref.watch(widget.provider);
    final q = _q.trim();
    final all = list.value ?? const <MasterItem>[];
    final matches = q.isEmpty ? all : all.where((b) => b.name.toLowerCase().contains(q.toLowerCase())).toList();
    // The server accepts duplicate names, so only offer "add" when nothing matches exactly.
    final exact = all.any((b) => b.name.toLowerCase() == q.toLowerCase());
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
              SearchField(hint: 'Search ${noun}s or type a new name', onChanged: (s) => setState(() => _q = s)),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (q.isNotEmpty && !exact)
                        GroupedSection(
                          children: [
                            AppListRow(
                              title: 'Add “$q” as a new $noun',
                              minHeight: 48,
                              titleStyle: AppText.body.copyWith(color: c.accent),
                              leading: _creating
                                  ? const AppSpinner()
                                  : AppIcon(AppIcons.addCircle, color: c.accent, size: 20),
                              onTap: _creating ? null : () => _create(q),
                            ),
                          ],
                        ),
                      if (list.isLoading && all.isEmpty)
                        const Padding(padding: EdgeInsets.all(AppSpace.xl), child: Center(child: AppSpinner()))
                      else if (matches.isNotEmpty)
                        GroupedSection(
                          children: [
                            for (final i in matches)
                              AppListRow(
                                title: i.name,
                                subtitle: i.subtitle,
                                minHeight: 48,
                                titleStyle: AppText.body,
                                onTap: () => Navigator.pop(context, i),
                                trailing: i.id == widget.selectedId ? AppIcon(AppIcons.check, color: c.accent, size: 20) : null,
                              ),
                          ],
                        )
                      else if (q.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpace.xl),
                          child: Center(child: Text('No ${noun}s yet. Type a name above to add one.', style: AppText.callout.copyWith(color: c.textTertiary))),
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
  return showAppDialog<int>(
    context,
    builder: (ctx) => AppDialog(
      title: '$label ID',
      body: "The list isn't available yet. Enter the ID from the admin panel.",
      content: AppCard(
        child: FieldInput(label: 'ID', controller: ctl, keyboardType: TextInputType.number, inputFormatters: digitsOnly),
      ),
      actions: [
        AppDialogAction('Cancel', () => Navigator.pop(ctx)),
        AppDialogAction('Use', () => Navigator.pop(ctx, int.tryParse(ctl.text.trim())), primary: true),
      ],
    ),
  );
}

/// A party is a buyer's name: pick one from `GET /buyers` or type any name
/// (the offer API stores parties as text). Returns '' to clear.
class PartyPickerRow extends ConsumerWidget {
  const PartyPickerRow({super.key, required this.label, required this.value, required this.onChanged});

  final String label;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final v = value?.trim();
    return ValueRow(
      label: label,
      value: v == null || v.isEmpty ? null : v,
      placeholder: 'Buyer or name',
      onTap: () async {
        final picked = await showModalBottomSheet<String>(
          context: context,
          isScrollControlled: true,
          builder: (_) => _PartySheet(title: label, current: v),
        );
        if (picked != null) onChanged(picked.isEmpty ? null : picked);
      },
    );
  }
}

class _PartySheet extends ConsumerStatefulWidget {
  const _PartySheet({required this.title, this.current});
  final String title;
  final String? current;

  @override
  ConsumerState<_PartySheet> createState() => _PartySheetState();
}

class _PartySheetState extends ConsumerState<_PartySheet> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final buyers = ref.watch(buyersProvider);
    final q = _q.trim();
    final all = buyers.value ?? const <MasterItem>[];
    final matches = q.isEmpty ? all : all.where((b) => b.name.toLowerCase().contains(q.toLowerCase())).toList();
    final exact = all.any((b) => b.name.toLowerCase() == q.toLowerCase());
    final hasCurrent = widget.current != null && widget.current!.isNotEmpty;
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
              SearchField(hint: 'Search buyers or type a name', onChanged: (s) => setState(() => _q = s)),
              const SizedBox(height: AppSpace.md),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (q.isNotEmpty && !exact || hasCurrent)
                        GroupedSection(
                          children: [
                            if (q.isNotEmpty && !exact)
                              AppListRow(
                                title: 'Use “$q”',
                                subtitle: 'Not in the buyers list',
                                minHeight: 48,
                                titleStyle: AppText.body.copyWith(color: c.accent),
                                leading: AppIcon(AppIcons.edit, color: c.accent, size: 20),
                                onTap: () => Navigator.pop(context, q),
                              ),
                            if (hasCurrent)
                              AppListRow(
                                title: 'Clear',
                                minHeight: 48,
                                titleStyle: AppText.body.copyWith(color: c.danger),
                                onTap: () => Navigator.pop(context, ''),
                              ),
                          ],
                        ),
                      if (buyers.isLoading && all.isEmpty)
                        const Padding(padding: EdgeInsets.all(AppSpace.xl), child: Center(child: AppSpinner()))
                      else if (matches.isNotEmpty)
                        GroupedSection(
                          label: 'Buyers',
                          children: [
                            for (final b in matches)
                              AppListRow(
                                title: b.name,
                                subtitle: b.subtitle,
                                minHeight: 48,
                                titleStyle: AppText.body,
                                onTap: () => Navigator.pop(context, b.name),
                                trailing: b.name == widget.current ? AppIcon(AppIcons.check, color: c.accent, size: 20) : null,
                              ),
                          ],
                        )
                      else if (q.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(AppSpace.xl),
                          child: Center(child: Text('No buyers yet. Type a name above.', style: AppText.callout.copyWith(color: c.textTertiary))),
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
