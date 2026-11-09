import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/application/invalidation.dart';
import '../../../core/design/context_ext.dart';
import '../../../core/design/typography.dart';
import '../../../core/router/routes.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_list_row.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/delete_record_button.dart';
import '../../../core/widgets/detail.dart';
import '../../../core/widgets/fields.dart';
import '../../../core/widgets/form_submit.dart';
import '../../../core/widgets/module_list.dart';
import '../../../core/widgets/scaffolds.dart';
import '../../../core/widgets/sheets.dart';
import '../../../core/widgets/states.dart';
import '../../../core/widgets/weight_fields.dart';
import '../../masters/data/masters_repository.dart';
import '../../masters/presentation/master_picker.dart';
import '../data/offer_lists_repository.dart';

class OfferListsScreen extends StatelessWidget {
  const OfferListsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListScreen<OfferList>(
      title: 'Offer lists',
      listProvider: offerListsListProvider,
      queryProvider: offerListsQueryProvider,
      searchHint: 'Search garden, grade, AWR no or key',
      emptyIcon: CupertinoIcons.doc_text,
      emptyTitle: 'Add your first offer',
      emptyBody: 'Lots offered to buyers show up here with their price.',
      newLabel: 'New offer',
      onNew: () => context.pushNamed(Routes.offerNew),
      actions: [
        LinkButton(label: 'Offered today', onPressed: () => context.pushNamed(Routes.offeredToday)),
        AddButton(semanticLabel: 'New offer', onPressed: () => context.pushNamed(Routes.offerNew)),
      ],
      filters: [
        const DateFilter('date_from', 'From'),
        const DateFilter('date_to', 'To'),
        ChoiceFilter('grade', 'Grade', {for (final g in kTeaGrades) g: g}),
        const ChoiceFilter('type', 'Type', {'Tea': 'Tea'}),
      ],
      itemBuilder: (context, o) => AppListRow(
        title: o.title,
        subtitle: [
          Fmt.invoice(o.invPrefix, o.invNo),
          if (o.pkgs != null && o.nett != null) '${Fmt.editable(o.pkgs)} × ${Fmt.editable(o.nett)} kg',
        ].where((e) => e.isNotEmpty).join(' · '),
        onTap: () => context.pushNamed(Routes.offerDetail, pathParameters: {'id': '${o.id}'}, extra: o),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(o.price != null ? Fmt.money(o.price) : Fmt.kg(o.totalKgs), style: AppText.callout.copyWith(fontWeight: o.price != null ? FontWeight.w600 : FontWeight.w400)),
            const SizedBox(height: 2),
            Text(Fmt.dayShort(o.date), style: AppText.footnote.copyWith(color: context.colors.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class OfferFormScreen extends ConsumerStatefulWidget {
  const OfferFormScreen({super.key, this.editing});

  /// The offer being edited, or null for a new one.
  final OfferList? editing;

  @override
  ConsumerState<OfferFormScreen> createState() => _OfferFormScreenState();
}

class _OfferFormScreenState extends ConsumerState<OfferFormScreen> with FormSubmit {
  late final OfferList? _e = widget.editing;
  late DateTime _date = _e?.date ?? DateTime.now();
  late DateTime? _packing = _e?.packingDate;
  late MasterItem? _garden = _e?.gardenId == null ? null : MasterItem(_e!.gardenId!, _e.gardenName ?? '#${_e.gardenId}');
  late String? _grade = _e?.grade;
  late final _prefix = TextEditingController(text: _e?.invPrefix);
  late final _inv = TextEditingController(text: _e?.invNo);
  late final _pkgs = TextEditingController(text: Fmt.editable(_e?.pkgs));
  late final _nett = TextEditingController(text: Fmt.editable(_e?.nett));
  late final _total = TextEditingController(text: Fmt.editable(_e?.totalKgs));
  late final _gross = TextEditingController(text: Fmt.editable(_e?.grossWeight));
  late final _price = TextEditingController(text: Fmt.editable(_e?.price));
  late final _prompt = TextEditingController(text: _e?.promptDays?.toString());
  /// The offer API has party_1 … party_10.
  static const _maxParties = 10;
  late final _parties = <String?>[...?_e?.parties, if (_e == null || _e.parties.isEmpty) null];

  @override
  void dispose() {
    for (final c in [_prefix, _inv, _pkgs, _nett, _total, _gross, _price, _prompt]) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, Object?> _body([String? duplicateAction]) => {
        'date': Fmt.api(_date),
        'garden_id': _garden?.id,
        'garden_name': _garden?.name.startsWith('#') == true ? null : _garden?.name,
        'grade': _grade,
        'inv_prefix': _prefix.text.trim(),
        'inv_no': _inv.text.trim(),
        'pkgs': Fmt.parse(_pkgs.text),
        'nett': Fmt.parse(_nett.text),
        'ttl_kgs': Fmt.parse(_total.text),
        'gross_weight': Fmt.parse(_gross.text),
        'd_o_packing': _packing == null ? null : Fmt.api(_packing!),
        'type': 'Tea',
        'price': Fmt.parse(_price.text),
        'currency': 'INR',
        'prompt_days': int.tryParse(_prompt.text),
        for (final (i, p) in _parties.whereType<String>().where((p) => p.trim().isNotEmpty).indexed) 'party_${i + 1}': p.trim(),
        if (_e == null) 'duplicate_action': duplicateAction,
      };

  Future<void> _save() async {
    final repo = ref.read(offerListsRepositoryProvider);
    final ok = await submit<bool>(
      () async {
        if (_e == null) {
          await repo.create(_body());
        } else {
          await repo.update(_e.id, _body());
        }
        return true;
      },
      clientErrors: {
        if (_garden == null) 'garden_id': 'Choose a garden.',
        if (_inv.text.trim().isEmpty) 'inv_no': 'Enter the invoice number.',
      },
      onDuplicate: (f) async {
        final choice = await chooseAction(
          context,
          title: 'This invoice already exists',
          message: f.serverMessage,
          actions: const {'override': 'Override the existing offer', 'reoffer': 'Re-offer and keep both'},
        );
        if (choice == null) return null;
        return submit<bool>(() async {
          await repo.create(_body(choice));
          return true;
        });
      },
    );
    if (ok == true && mounted) {
      ref.invalidate(offerListsListProvider);
      refreshSummaries(ref);
      context.toast(_e == null ? 'Offer saved' : 'Offer updated');
      if (_e == null) {
        context.pop();
      } else {
        context.goNamed(Routes.offers);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: _e == null ? 'New offer' : 'Edit offer',
      submitLabel: _e == null ? 'Save offer' : 'Save changes',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (banner != null) FormBanner(banner!),
        GroupedSection(
          label: 'Lot',
          children: [
            DateRow(label: 'Date', value: _date, onChanged: (d) => setState(() => _date = d), error: err('date')),
            MasterPickerRow(label: 'Garden', provider: gardensProvider, searchPath: '/gardens', value: _garden, onChanged: (g) => setState(() => _garden = g), error: err('garden_id')),
            GradePickerRow(value: _grade, onChanged: (g) => setState(() => _grade = g), error: err('grade')),
            Row(children: [
              SizedBox(width: 120, child: FieldInput(label: 'Prefix', hint: 'IVP', controller: _prefix, textCapitalization: TextCapitalization.characters, error: err('inv_prefix'))),
              Expanded(child: FieldInput(label: 'Invoice no', hint: '1045', controller: _inv, error: err('inv_no'))),
            ]),
          ],
        ),
        WeightFields(pkgs: _pkgs, nett: _nett, total: _total, errors: errors),
        GroupedSection(
          children: [
            FieldInput(label: 'Gross weight', hint: '720', controller: _gross, suffix: 'kg', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: decimalOnly),
            DateRow(label: 'Date of packing', value: _packing, onChanged: (d) => setState(() => _packing = d)),
          ],
        ),
        GroupedSection(
          label: 'Price',
          children: [
            FieldInput(label: 'Price per kg', hint: '280.00', controller: _price, suffix: '₹', error: err('price'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: decimalOnly),
            FieldInput(label: 'Prompt days', hint: '14', controller: _prompt, keyboardType: TextInputType.number, inputFormatters: digitsOnly),
          ],
        ),
        GroupedSection(
          label: 'Parties',
          footer: const Text('Pick a buyer or type any name. Up to $_maxParties.'),
          children: [
            for (var i = 0; i < _parties.length; i++)
              PartyPickerRow(
                label: 'Party ${i + 1}',
                value: _parties[i],
                onChanged: (v) => setState(() {
                  if (v == null && _parties.length > 1) {
                    _parties.removeAt(i);
                  } else {
                    _parties[i] = v;
                  }
                }),
              ),
          ],
        ),
        if (_parties.length < _maxParties)
          Align(
            alignment: Alignment.centerLeft,
            child: SecondaryButton(
              label: 'Add party',
              icon: CupertinoIcons.add,
              onPressed: () => setState(() => _parties.add(null)),
            ),
          ),
      ],
    );
  }
}

class OfferDetailScreen extends StatelessWidget {
  const OfferDetailScreen({super.key, required this.offer});
  final OfferList? offer;

  @override
  Widget build(BuildContext context) {
    final o = offer;
    if (o == null) return const MissingItemScreen(what: 'offer');
    return DetailScaffold(
      title: o.gardenName ?? 'Offer',
      actions: [
        LinkButton(label: 'Edit', onPressed: () => context.pushNamed(Routes.offerEdit, pathParameters: {'id': '${o.id}'}, extra: o)),
      ],
      children: [
        GroupedSection(
          label: 'Lot',
          children: [
            InfoRow('Date', Fmt.day(o.date)),
            InfoRow('Grade', o.grade),
            InfoRow('Invoice', Fmt.invoice(o.invPrefix, o.invNo)),
            InfoRow('Type', o.type),
          ],
        ),
        GroupedSection(
          label: 'Weight',
          children: [
            InfoRow('Packages', Fmt.number(o.pkgs)),
            InfoRow('Nett per package', Fmt.kg(o.nett)),
            InfoRow('Total', Fmt.kg(o.totalKgs)),
            InfoRow('Gross weight', Fmt.kg(o.grossWeight)),
            InfoRow('Date of packing', Fmt.day(o.packingDate)),
          ],
        ),
        GroupedSection(
          label: 'Price',
          children: [
            InfoRow('Price per kg', Fmt.money(o.price)),
            InfoRow('Prompt days', o.promptDays?.toString()),
          ],
        ),
        if (o.parties.isNotEmpty)
          GroupedSection(label: 'Parties', children: [for (final (i, p) in o.parties.indexed) InfoRow('Party ${i + 1}', p)]),
        if (o.buyers.isNotEmpty)
          GroupedSection(label: 'Allocated buyers', children: [for (final b in o.buyers) InfoRow(b, null)]),
        DeleteRecordButton(
          what: 'offer',
          name: '${o.title} (${Fmt.invoice(o.invPrefix, o.invNo)})',
          onDelete: (ref) => ref.read(offerListsRepositoryProvider).delete(o.id),
          onDeleted: (ref) => ref.invalidate(offerListsListProvider),
        ),
      ],
    );
  }
}
