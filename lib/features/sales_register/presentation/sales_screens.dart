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
import '../../../core/widgets/states.dart';
import '../../../core/widgets/status_badge.dart';
import '../../ex_factory/data/ex_factory_repository.dart';
import '../../masters/data/masters_repository.dart';
import '../../masters/presentation/master_picker.dart';
import '../data/sales_repository.dart';

class SalesListScreen extends StatelessWidget {
  const SalesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ModuleListScreen<SaleEntry>(
      title: 'Sales register',
      inTabs: false,
      listProvider: salesListProvider,
      queryProvider: salesQueryProvider,
      searchHint: 'Search mark, invoice, buyer or entry',
      emptyIcon: CupertinoIcons.cart,
      emptyTitle: 'Record your first sale',
      emptyBody: 'Deals with buyers show up here and are matched against ex-factory bills.',
      newLabel: 'New entry',
      onNew: () => context.pushNamed(Routes.salesNew),
      actions: [AddButton(semanticLabel: 'New sales entry', onPressed: () => context.pushNamed(Routes.salesNew))],
      segments: SegmentConfig(param: 'status', options: {'': 'All', for (final s in SaleStatus.values) s.api: s.label}),
      filters: [
        const DateFilter('start_date', 'From'),
        const DateFilter('end_date', 'To'),
        ChoiceFilter('tea_grade', 'Grade', {for (final g in kTeaGrades) g: g}),
      ],
      itemBuilder: (context, s) => AppListRow(
        title: [s.mark ?? 'Mark –', ?s.grade].join(' · '),
        subtitle: [s.buyerName, Fmt.invoice(s.invoicePrefix, s.invoiceNo), '${Fmt.kg(s.quantity)} × ${Fmt.money(s.rate)}']
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .join(' · '),
        onTap: () => context.pushNamed(Routes.salesDetail, pathParameters: {'id': '${s.id}'}, extra: s),
        trailing: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(Fmt.money(s.amount), style: AppText.callout.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            StatusBadge(s.status.label, tone: s.status.tone),
          ],
        ),
      ),
    );
  }
}

class SalesFormScreen extends ConsumerStatefulWidget {
  const SalesFormScreen({super.key, this.editing});

  /// The sale being edited, or null for a new one.
  final SaleEntry? editing;

  @override
  ConsumerState<SalesFormScreen> createState() => _SalesFormScreenState();
}

class _SalesFormScreenState extends ConsumerState<SalesFormScreen> with FormSubmit {
  late final SaleEntry? _e = widget.editing;
  late MasterItem? _buyer = _e?.buyerId == null ? null : MasterItem(_e!.buyerId!, _e.buyerName ?? '#${_e.buyerId}');
  late String? _grade = _e?.grade;
  late DateTime _deal = _e?.dealDate ?? DateTime.now();
  late DateTime? _cnDate = _e?.cnDate;
  late final _rate = TextEditingController(text: Fmt.editable(_e?.rate));
  late final _mark = TextEditingController(text: _e?.mark);
  late final _prefix = TextEditingController(text: _e?.invoicePrefix);
  late final _inv = TextEditingController(text: _e?.invoiceNo);
  late final _pkgs = TextEditingController(text: _e?.pkgs?.toString());
  late final _qty = TextEditingController(text: Fmt.editable(_e?.quantity));
  late final _cn = TextEditingController(text: _e?.cnNumber);
  late final _transport = TextEditingController(text: _e?.transport);
  late final _discount = TextEditingController(text: Fmt.editable(_e?.discount));
  late final _remarks = TextEditingController(text: _e?.remarks);

  @override
  void dispose() {
    for (final c in [_rate, _mark, _prefix, _inv, _pkgs, _qty, _cn, _transport, _discount, _remarks]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final ok = await submit<bool>(
      () async {
        final body = {
          'buyer_id': _buyer?.id,
          'tea_grade': _grade,
          'rate_per_kg': Fmt.parse(_rate.text),
          'pkgs': int.tryParse(_pkgs.text),
          'quantity_kg': Fmt.parse(_qty.text),
          'mark': _mark.text.trim(),
          'invoice_prefix': _prefix.text.trim(),
          'invoice_no': _inv.text.trim(),
          'deal_date': Fmt.api(_deal),
          'cn_number': _cn.text.trim(),
          'cn_date': _cnDate == null ? null : Fmt.api(_cnDate!),
          'transport': _transport.text.trim(),
          'discount': Fmt.parse(_discount.text),
          'remarks': _remarks.text.trim(),
        };
        final repo = ref.read(salesRepositoryProvider);
        if (_e == null) {
          await repo.create(body);
        } else {
          await repo.update(_e.id, body);
        }
        return true;
      },
      clientErrors: {
        if (_buyer == null) 'buyer_id': 'Choose a buyer.',
        if (_grade == null) 'tea_grade': 'Choose a grade.',
        if (Fmt.parse(_rate.text) == null) 'rate_per_kg': 'Enter the rate per kg.',
      },
    );
    if (ok == true && mounted) {
      ref.invalidate(salesListProvider);
      ref.invalidate(exFactoryListProvider);
      refreshSummaries(ref);
      context.toast(_e == null ? 'Sale saved' : 'Sale updated');
      if (_e == null) {
        context.pop();
      } else {
        context.goNamed(Routes.sales);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rate = Fmt.parse(_rate.text);
    final qty = Fmt.parse(_qty.text);
    final amount = rate == null || qty == null ? null : rate * qty - (Fmt.parse(_discount.text) ?? 0);
    TextInputType dec() => const TextInputType.numberWithOptions(decimal: true);
    return FormScaffold(
      title: _e == null ? 'New sale' : 'Edit sale',
      submitLabel: _e == null ? 'Save sale' : 'Save changes',
      submitting: submitting,
      onSubmit: _save,
      children: [
        if (banner != null) FormBanner(banner!),
        GroupedSection(
          label: 'Deal',
          children: [
            MasterPickerRow(label: 'Buyer', provider: buyersProvider, value: _buyer, onChanged: (b) => setState(() => _buyer = b), error: err('buyer_id')),
            GradePickerRow(value: _grade, onChanged: (g) => setState(() => _grade = g), error: err('tea_grade')),
            FieldInput(label: 'Rate per kg', hint: '310.00', suffix: '₹', controller: _rate, error: err('rate_per_kg'), onChanged: (_) => setState(() {}), keyboardType: dec(), inputFormatters: decimalOnly),
            DateRow(label: 'Deal date', value: _deal, onChanged: (d) => setState(() => _deal = d)),
          ],
        ),
        GroupedSection(
          label: 'Lot',
          children: [
            FieldInput(label: 'Mark', hint: 'Assam Valley Mark', controller: _mark, error: err('mark')),
            Row(children: [
              SizedBox(width: 120, child: FieldInput(label: 'Prefix', hint: 'IVP', controller: _prefix, textCapitalization: TextCapitalization.characters)),
              Expanded(child: FieldInput(label: 'Invoice no', hint: '9812', controller: _inv, error: err('invoice_no'))),
            ]),
            Row(children: [
              Expanded(child: FieldInput(label: 'Packages', hint: '25', controller: _pkgs, error: err('pkgs'), keyboardType: TextInputType.number, inputFormatters: digitsOnly)),
              Expanded(child: FieldInput(label: 'Quantity', hint: '875', suffix: 'kg', controller: _qty, onChanged: (_) => setState(() {}), keyboardType: dec(), inputFormatters: decimalOnly)),
            ]),
          ],
        ),
        GroupedSection(
          label: 'Dispatch',
          children: [
            FieldInput(label: 'CN number', hint: 'CN-44129', controller: _cn),
            DateRow(label: 'CN date', value: _cnDate, onChanged: (d) => setState(() => _cnDate = d)),
            FieldInput(label: 'Transport', hint: 'V-Trans Logistics', controller: _transport),
          ],
        ),
        GroupedSection(
          label: 'Other',
          footer: Text('Amount ${Fmt.money(amount)}'),
          children: [
            FieldInput(label: 'Discount', hint: '0', suffix: '₹', controller: _discount, onChanged: (_) => setState(() {}), keyboardType: dec(), inputFormatters: decimalOnly),
            FieldInput(label: 'Remarks', hint: 'Dispatched directly from factory', controller: _remarks, maxLines: 3),
          ],
        ),
      ],
    );
  }
}

class SalesDetailScreen extends StatelessWidget {
  const SalesDetailScreen({super.key, required this.entry});
  final SaleEntry? entry;

  @override
  Widget build(BuildContext context) {
    final s = entry;
    if (s == null) return const MissingItemScreen(what: 'sale');
    final c = context.colors;
    return DetailScaffold(
      title: s.mark ?? 'Sale',
      actions: [
        LinkButton(label: 'Edit', onPressed: () => context.pushNamed(Routes.salesEdit, pathParameters: {'id': '${s.id}'}, extra: s)),
      ],
      children: [
        AppCard(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(Fmt.money(s.amount), style: AppText.metric),
                Text('${Fmt.kg(s.quantity)} × ${Fmt.money(s.rate)}', style: AppText.footnote.copyWith(color: c.textTertiary)),
              ]),
            ),
            StatusBadge(s.status.label, tone: s.status.tone),
          ]),
        ),
        GroupedSection(
          children: [
            InfoRow('Buyer', s.buyerName),
            InfoRow('Grade', s.grade),
            InfoRow('Invoice', Fmt.invoice(s.invoicePrefix, s.invoiceNo)),
            InfoRow('Packages', s.pkgs?.toString()),
            InfoRow('Deal date', Fmt.day(s.dealDate)),
            InfoRow('CN', [s.cnNumber, if (s.cnDate != null) Fmt.day(s.cnDate)].whereType<String>().join(' · ')),
            InfoRow('Transport', s.transport),
            InfoRow('Discount', Fmt.money(s.discount)),
            if (s.remarks != null) InfoBlock('Remarks', s.remarks!),
          ],
        ),
        DeleteRecordButton(
          what: 'sale',
          name: [s.mark, Fmt.invoice(s.invoicePrefix, s.invoiceNo)].whereType<String>().where((e) => e.isNotEmpty).join(' · '),
          onDelete: (ref) => ref.read(salesRepositoryProvider).delete(s.id),
          onDeleted: (ref) {
            ref.invalidate(salesListProvider);
            ref.invalidate(exFactoryListProvider);
          },
        ),
      ],
    );
  }
}
