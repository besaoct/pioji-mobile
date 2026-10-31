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
            Text(Fmt.money(o.price), style: AppText.callout.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(Fmt.dayShort(o.date), style: AppText.footnote.copyWith(color: context.colors.textTertiary)),
          ],
        ),
      ),
    );
  }
}

class OfferFormScreen extends ConsumerStatefulWidget {
  const OfferFormScreen({super.key});

  @override
  ConsumerState<OfferFormScreen> createState() => _OfferFormScreenState();
}

class _OfferFormScreenState extends ConsumerState<OfferFormScreen> with FormSubmit {
  DateTime _date = DateTime.now();
  DateTime? _packing;
  MasterItem? _garden;
  String? _grade;
  final _prefix = TextEditingController();
  final _inv = TextEditingController();
  final _pkgs = TextEditingController();
  final _nett = TextEditingController();
  final _total = TextEditingController();
  final _gross = TextEditingController();
  final _price = TextEditingController();
  final _prompt = TextEditingController();
  final _p1 = TextEditingController();
  final _p2 = TextEditingController();

  @override
  void dispose() {
    for (final c in [_prefix, _inv, _pkgs, _nett, _total, _gross, _price, _prompt, _p1, _p2]) {
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
        'party_1': _p1.text.trim(),
        'party_2': _p2.text.trim(),
        'duplicate_action': duplicateAction,
      };

  Future<void> _save() async {
    final repo = ref.read(offerListsRepositoryProvider);
    final ok = await submit<bool>(
      () async {
        await repo.create(_body());
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
      context.toast('Offer saved');
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormScaffold(
      title: 'New offer',
      submitLabel: 'Save offer',
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
          children: [
            FieldInput(label: 'Party 1', hint: 'Tata Tea', controller: _p1),
            FieldInput(label: 'Party 2', hint: 'Wagh Bakri', controller: _p2, textInputAction: TextInputAction.done),
          ],
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
            InfoRow('Party 1', o.party1),
            InfoRow('Party 2', o.party2),
          ],
        ),
        if (o.buyers.isNotEmpty)
          GroupedSection(label: 'Allocated buyers', children: [for (final b in o.buyers) InfoRow(b, null)]),
      ],
    );
  }
}
