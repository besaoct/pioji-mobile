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
import '../../../core/widgets/status_badge.dart';
import '../../masters/data/masters_repository.dart';
import '../../masters/presentation/master_picker.dart';
import '../data/contracts_repository.dart';

class ContractsListScreen extends StatelessWidget {
  const ContractsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListScreen<Contract>(
      title: 'Contracts',
      inTabs: false,
      listProvider: contractsListProvider,
      queryProvider: contractsQueryProvider,
      searchHint: 'Search title, number or seller',
      emptyIcon: CupertinoIcons.doc_plaintext,
      emptyTitle: 'Create your first contract',
      emptyBody: 'Supply contracts with their grades, prices and validity show up here.',
      newLabel: 'New contract',
      onNew: () => context.pushNamed(Routes.contractNew),
      actions: [AddButton(semanticLabel: 'New contract', onPressed: () => context.pushNamed(Routes.contractNew))],
      segments: SegmentConfig(param: 'status', options: {'': 'All', for (final s in ContractStatus.values) s.api: s.label}),
      filters: const [DateFilter('date_from', 'Effective from'), DateFilter('date_to', 'Expires by')],
      itemBuilder: (context, k) => AppListRow(
        title: k.title,
        subtitle: [k.number, k.sellerName, '${Fmt.dayShort(k.effective)} – ${Fmt.day(k.expiry)}'].whereType<String>().join(' · '),
        onTap: () => context.pushNamed(Routes.contractDetail, pathParameters: {'id': '${k.id}'}, extra: k),
        trailing: k.expiringSoon ? const StatusBadge('Expiring', tone: Tone.warning) : StatusBadge(k.status.label, tone: k.status.tone),
      ),
    );
  }
}

class _ItemDraft {
  _ItemDraft([ContractItem? from])
      : grade = from?.grade,
        price = TextEditingController(text: Fmt.editable(from?.pricePerKg)),
        qty = TextEditingController(text: Fmt.editable(from?.quantity));

  String? grade;
  final TextEditingController price;
  final TextEditingController qty;

  void dispose() {
    price.dispose();
    qty.dispose();
  }

  ContractItem toItem() => ContractItem(grade: grade, pricePerKg: Fmt.parse(price.text), quantity: Fmt.parse(qty.text));
}

class ContractFormScreen extends ConsumerStatefulWidget {
  const ContractFormScreen({super.key, this.editing});

  /// The contract to edit; null creates a new one.
  final Contract? editing;

  @override
  ConsumerState<ContractFormScreen> createState() => _ContractFormScreenState();
}

class _ContractFormScreenState extends ConsumerState<ContractFormScreen> with FormSubmit {
  late final Contract? _e = widget.editing;
  late MasterItem? _seller = _e?.sellerId == null ? null : MasterItem(_e!.sellerId!, _e.sellerName ?? '#${_e.sellerId}');
  late MasterItem? _buyer = _e?.buyerId == null ? null : MasterItem(_e!.buyerId!, _e.buyerName ?? '#${_e.buyerId}');
  late DateTime _effective = _e?.effective ?? DateTime.now();
  late DateTime _expiry = _e?.expiry ?? DateTime.now().add(const Duration(days: 30));
  late ContractStatus _status = _e?.status ?? ContractStatus.draft;
  late final _title = TextEditingController(text: _e?.title);
  late final _number = TextEditingController(text: _e?.number);
  late final _prompt = TextEditingController(text: _e?.promptDays?.toString());
  late final _discount = TextEditingController(text: Fmt.editable(_e?.discount));
  late final _terms = TextEditingController(text: _e?.terms);
  late final _items = <_ItemDraft>[
    if (_e != null && _e.items.isNotEmpty) for (final i in _e.items) _ItemDraft(i) else _ItemDraft(),
  ];

  @override
  void dispose() {
    for (final c in [_title, _number, _prompt, _discount, _terms]) {
      c.dispose();
    }
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final items = _items.map((d) => d.toItem()).where((i) => i.grade != null || i.pricePerKg != null).toList();
    final ok = await submit<bool>(
      () async {
        final repo = ref.read(contractsRepositoryProvider);
        final body = <String, Object?>{
          'seller_id': _seller?.id,
          'buyer_id': _buyer?.id,
          'contract_title': _title.text.trim(),
          'contract_number': _number.text.trim(),
          'effective_date': Fmt.api(_effective),
          'expiry_date': Fmt.api(_expiry),
          'prompt_days': int.tryParse(_prompt.text),
          'discount': Fmt.parse(_discount.text),
          'status': _status.api,
          'terms_and_conditions': _terms.text.trim(),
          'contract_items': [for (final i in items) i.toJson()],
        };
        if (_e == null) {
          await repo.create(body);
        } else {
          await repo.update(_e.id, body);
        }
        return true;
      },
      clientErrors: {
        if (_seller == null) 'seller_id': 'Choose a seller.',
        if (_title.text.trim().isEmpty) 'contract_title': 'Enter a title.',
        if (_expiry.isBefore(_effective)) 'expiry_date': "Expiry can't be before the effective date.",
        for (final (n, d) in _items.indexed)
          if (d.grade != null && (Fmt.parse(d.price.text) ?? 0) <= 0) 'contract_items.$n.price_per_kg': 'Enter a price.',
      },
    );
    if (ok == true && mounted) {
      ref.invalidate(contractsListProvider);
      refreshSummaries(ref);
      context.toast(_e == null ? 'Contract saved' : 'Contract updated');
      if (_e == null) {
        context.pop();
      } else {
        context.goNamed(Routes.contracts);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final items = _items.map((d) => d.toItem()).toList();
    final qty = items.fold<double>(0, (s, i) => s + (i.quantity ?? 0));
    final value = items.fold<double>(0, (s, i) => s + i.value);
    return FormScaffold(
      title: _e == null ? 'New contract' : 'Edit contract',
      submitLabel: _e == null ? 'Save contract' : 'Save changes',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (banner != null) FormBanner(banner!),
        GroupedSection(
          label: 'Parties',
          children: [
            MasterPickerRow(label: 'Seller', provider: sellersProvider, value: _seller, onChanged: (s) => setState(() => _seller = s), error: err('seller_id')),
            MasterPickerRow(label: 'Buyer', provider: buyersProvider, value: _buyer, placeholder: 'Optional', onChanged: (b) => setState(() => _buyer = b), error: err('buyer_id')),
          ],
        ),
        GroupedSection(
          label: 'Contract',
          children: [
            FieldInput(label: 'Title', hint: 'Tea supply contract 2026', controller: _title, error: err('contract_title'), textCapitalization: TextCapitalization.sentences),
            FieldInput(label: 'Contract number', hint: 'Generated automatically if empty', controller: _number, error: err('contract_number')),
            DateRow(label: 'Effective', value: _effective, onChanged: (d) => setState(() => _effective = d), error: err('effective_date')),
            DateRow(label: 'Expires', value: _expiry, minimum: _effective, onChanged: (d) => setState(() => _expiry = d), error: err('expiry_date')),
            Row(children: [
              Expanded(child: FieldInput(label: 'Prompt days', hint: '14', controller: _prompt, keyboardType: TextInputType.number, inputFormatters: digitsOnly)),
              Expanded(child: FieldInput(label: 'Discount', hint: '0', controller: _discount, suffix: '%', keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: decimalOnly)),
            ]),
            ValueRow(
              label: 'Status',
              value: _status.label,
              onTap: () async {
                final s = await showPickerSheet<ContractStatus>(context,
                    title: 'Status', selected: _status, searchable: false, options: [for (final s in ContractStatus.values) PickOption(s, s.label)]);
                if (s != null) setState(() => _status = s);
              },
            ),
          ],
        ),
        for (var i = 0; i < _items.length; i++)
          GroupedSection(
            label: 'Item ${i + 1}',
            trailingLabel: _items.length > 1
                ? GestureDetector(
                    onTap: () => setState(() => _items.removeAt(i).dispose()),
                    child: Text('Remove', style: AppText.footnote.copyWith(color: c.danger)),
                  )
                : null,
            children: [
              GradePickerRow(value: _items[i].grade, onChanged: (g) => setState(() => _items[i].grade = g)),
              Row(children: [
                Expanded(child: FieldInput(label: 'Price per kg', hint: '320.00', suffix: '₹', controller: _items[i].price, error: err('contract_items.$i.price_per_kg'), onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: decimalOnly)),
                Expanded(child: FieldInput(label: 'Quantity', hint: '5000', suffix: 'kg', controller: _items[i].qty, onChanged: (_) => setState(() {}), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: decimalOnly)),
              ]),
            ],
          ),
        Row(
          children: [
            SecondaryButton(label: 'Add item', icon: CupertinoIcons.add, onPressed: () => setState(() => _items.add(_ItemDraft()))),
            const Spacer(),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(Fmt.money(value), style: AppText.headline),
              Text(Fmt.kg(qty), style: AppText.footnote.copyWith(color: c.textTertiary)),
            ]),
          ],
        ),
        GroupedSection(label: 'Terms', children: [FieldInput(label: 'Terms and conditions', hint: 'Payment within prompt days', controller: _terms, maxLines: 5)]),
      ],
    );
  }
}

class ContractDetailScreen extends StatelessWidget {
  const ContractDetailScreen({super.key, required this.contract});
  final Contract? contract;

  @override
  Widget build(BuildContext context) {
    final k = contract;
    if (k == null) return const MissingItemScreen(what: 'contract');
    final c = context.colors;
    final total = k.items.fold<double>(0, (s, i) => s + i.value);
    final qty = k.items.fold<double>(0, (s, i) => s + (i.quantity ?? 0));
    return DetailScaffold(
      title: k.title,
      actions: [
        LinkButton(label: 'Edit', onPressed: () => context.pushNamed(Routes.contractEdit, pathParameters: {'id': '${k.id}'}, extra: k)),
      ],
      children: [
        GroupedSection(
          children: [
            InfoRow('Number', k.number),
            InfoRow('Status', k.expiringSoon ? 'Expiring soon' : k.status.label, valueColor: k.expiringSoon ? c.warning : null),
            InfoRow('Seller', k.sellerName),
            InfoRow('Buyer', k.buyerName),
            InfoRow('Valid', '${Fmt.day(k.effective)} – ${Fmt.day(k.expiry)}'),
            InfoRow('Prompt days', k.promptDays?.toString()),
            InfoRow('Discount', k.discount == null ? null : '${Fmt.editable(k.discount)}%'),
          ],
        ),
        if (k.items.isNotEmpty)
          GroupedSection(
            label: 'Items',
            footer: Text('Total ${Fmt.kg(qty)} · ${Fmt.money(total)}'),
            children: [
              for (final i in k.items)
                AppListRow(
                  title: i.grade ?? '–',
                  subtitle: '${Fmt.kg(i.quantity)} × ${Fmt.money(i.pricePerKg)}',
                  trailing: Text(Fmt.money(i.value), style: AppText.callout),
                ),
            ],
          ),
        if (k.terms != null) AppCard(child: InfoBlock('Terms and conditions', k.terms!)),
        DeleteRecordButton(
          what: 'contract',
          name: [k.number, k.title].whereType<String>().join(' · '),
          onDelete: (ref) => ref.read(contractsRepositoryProvider).delete(k.id),
          onDeleted: (ref) => ref.invalidate(contractsListProvider),
        ),
      ],
    );
  }
}
